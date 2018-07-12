defmodule Firehose.Emitter do
  use GenServer

  require Logger

  defstruct [:stream, :manager, :settings, :batch]

  @retries 3
  @flush_interval 1_000

  alias Firehose.{Emitter, Batch}

  def start_link(stream, manager) do
    GenServer.start_link(__MODULE__, {stream, manager}, [])
  end

  def init({stream, manager}) do
    Process.flag(:trap_exit, true)

    settings = %{
      manager.settings()
      | trigger: fn signature ->
          # If manager's submodule define
          if Keyword.has_key?(manager.__info__(:functions), :subscribe) do
            manager.subscribe(signature)
          end
        end
    }

    state = %Emitter{
      stream: stream,
      manager: manager,
      settings: settings,
      batch: %Batch{stream: stream}
    }

    interval = state.settings[:flush_interval] || @flush_interval
    Process.send_after(self(), :sync, interval)

    {:ok, state}
  end

  def emit(stream, data), do: emit(__MODULE__, stream, data)

  def emit(pid, stream, data) when is_binary(stream) do
    GenServer.call(pid, {:emit, stream, data})
  end

  def handle_call({:emit, stream, data}, _from, %Emitter{batch: batch, manager: manager} = state) do
    {:ok, data} = serialize(state.settings, data)

    case Batch.add(batch, data) do
      {:ok, new_batch} ->
        {:reply, :ok, %Emitter{state | batch: new_batch}}

      {:error, :record_limit} = error ->
        Logger.error("[Firehose] Data too big for record: #{byte_size(data)}")
        {:reply, error, state}

      {:error, reason} when reason in [:size_limit, :records_limit] ->
        flush(manager, batch, state.settings[:retries] || @retries)

        {:reply, :ok, %Emitter{state | batch: %Batch{stream: stream}}}
    end
  end

  def handle_info(:sync, %Emitter{batch: %Batch{size: 0}} = state), do: {:noreply, state}
  def handle_info(:sync, %Emitter{batch: %Batch{size: nil}} = state), do: {:noreply, state}

  def handle_info(:sync, %Emitter{stream: stream, manager: manager, batch: batch} = state) do
    flush(manager, batch, state.settings[:retries] || @retries)

    interval = state.settings[:flush_interval] || @flush_interval
    Process.send_after(self(), :sync, interval)

    {:noreply, %Emitter{state | batch: %Batch{stream: stream}}}
  end

  def terminate(reason, %Emitter{manager: manager, batch: batch}) do
    Logger.debug(
      "[Firehose] [#{batch.stream}] Terminiating due to #{inspect(reason)}. Pending batch (#{
        batch.size
      } bytes)"
    )

    # Flush events
    send_sync(manager, batch, @retries)

    :ok
  end

  defp serialize(settings, data) do
    delimiter =
      case settings[:delimiter] do
        nil -> ""
        delimiter -> delimiter
      end

    case settings[:serializer] do
      nil ->
        {:ok, data <> delimiter}

      serializer ->
        {:ok, data} = serializer.encode(data)
        {:ok, data <> delimiter}
    end
  end

  defp flush(manager, %Batch{stream: stream, size: size} = batch, tries) do
    Logger.debug("[Firehose] [#{stream}] Flushing pending batch (#{size || "na"} bytes)")

    spawn(fn -> send_sync(manager, batch, tries) end)
  end

  defp send_sync(_, %Batch{size: 0}, _), do: :ok
  defp send_sync(_, %Batch{size: nil}, _), do: :ok

  defp send_sync(manager, %Batch{stream: stream} = batch, 0) do
    Logger.error("[Firehose] [#{stream}] Cannot flush batch")

    # Replace with:
    #   settings.trigger.(status: :completed, batch: batch)
    #   settings.trigger.(status: :error, batch: batch, result: payload)
    #   settings.trigger.(status: :failed, batch: batch, result: payload)
    if Keyword.has_key?(manager.__info__(:functions), :subscribe) do
      manager.subscribe(:failed, batch, %{})
    end
  end

  defp send_sync(
         manager,
         %Batch{stream: stream, current_record: record, records: records} = batch,
         tries
       ) do
    records = records || []
    records = [record | records]

    # Convert records into firehose data structure
    records = for record <- records, do: %{data: record.data}

    result =
      stream
      |> ExAws.Firehose.put_record_batch(records)
      |> ExAws.request()

    case result do
      {:ok, _} ->
        Logger.debug("[Firehose] [#{stream}] Batch was successfully flushed")

        if Keyword.has_key?(manager.__info__(:functions), :subscribe) do
          manager.subscribe(:completed, batch)
        end

      response ->
        if Keyword.has_key?(manager.__info__(:functions), :subscribe) do
          manager.subscribe(:error, batch, response)
        end
    end
  end
end
