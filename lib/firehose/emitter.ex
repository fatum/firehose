defmodule Firehose.Emitter do
  use GenServer
  require Logger
  alias Firehose.{Emitter, Batch}

  @settings Application.get_env(:firehose, Firehose.Manager) || []
  @default [flush_interval: 1_000, retries: 5, serializer: Poison, delimiter: "\n", debug: false]

  defstruct [:stream, :manager, :settings, :batch]

  def start_link(stream, manager) do
    GenServer.start_link(__MODULE__, {stream, manager}, [])
  end

  def init({stream, manager}) do
    Process.flag(:trap_exit, true)

    Logger.info(
      "[Firehose] [#{stream}] Initialize emitter with settings: #{
        inspect(Keyword.merge(@default, @settings))
      }"
    )

    state = %Emitter{
      stream: stream,
      manager: manager,
      batch: %Batch{stream: stream}
    }

    Process.send_after(self(), :sync, flush_interval())

    {:ok, state}
  end

  def emit(stream, data), do: emit(__MODULE__, stream, data)

  def emit(pid, stream, data) when is_binary(stream) do
    case serialize(data) do
      {:ok, data} ->
        GenServer.call(pid, {:emit, stream, data})
        {:ok, :emitted}

      {:error, reason} = result ->
        Logger.error("Firehose [#{stream}] Error occured during serializing: #{inspect(reason)}")
        result
    end
  end

  def handle_call({:emit, stream, data} = args, from, %Emitter{batch: batch} = state) do
    case Batch.add(batch, data) do
      {:ok, new_batch} ->
        {:reply, :ok, %Emitter{state | batch: new_batch}}

      {:error, :record_limit} = error ->
        Logger.error("[Firehose] Data too big for record: #{byte_size(data)}")
        {:reply, error, state}

      {:error, reason} when reason in [:size_limit, :records_limit] ->
        flush(state, retries())
        handle_call(args, from, %Emitter{state | batch: %Batch{stream: stream}})
    end
  end

  def handle_info(:sync, %Emitter{batch: %Batch{size: 0}} = state) do
    Process.send_after(self(), :sync, flush_interval())
    {:noreply, state}
  end

  def handle_info(:sync, %Emitter{batch: %Batch{size: nil}} = state) do
    Process.send_after(self(), :sync, flush_interval())
    {:noreply, state}
  end

  def handle_info(:sync, %Emitter{stream: stream} = state) do
    flush(state, state.settings[:retries])

    Process.send_after(self(), :sync, flush_interval())

    {:noreply, %Emitter{state | batch: %Batch{stream: stream}}}
  end

  def terminate(reason, %Emitter{} = state) do
    Logger.info(
      "[Firehose] [#{state.batch.stream}] Terminating due to #{inspect(reason)}. Pending batch #{
        debug(state)
      }"
    )

    # Flush events
    send_sync(state, retries())

    :ok
  end

  defp retries do
    @settings[:retries] || @default[:retries]
  end

  defp flush_interval do
    @settings[:flush_interval] || @default[:flush_interval]
  end

  defp handlers do
    @settings[:handlers] || @default[:handlers] || []
  end

  defp delimiter do
    @settings[:delimiter] || @default[:delimiter]
  end

  defp serializer do
    @settings[:serializer] || @default[:serializer]
  end

  defp serialize(data) do
    delimiter =
      case delimiter() do
        nil -> ""
        delimiter -> delimiter
      end

    case serializer() do
      nil ->
        {:ok, data <> delimiter}

      serializer ->
        case serializer.encode(data) do
          {:ok, data} ->
            {:ok, data <> delimiter}

          error ->
            error
        end
    end
  end

  defp flush(%Emitter{} = state, tries) do
    Logger.info("[Firehose] [#{state.batch.stream}] Flushing pending batch #{debug(state)}")

    spawn(fn -> send_sync(state, tries) end)
  end

  defp send_sync(%Emitter{batch: %Batch{size: 0}}, _), do: :ok
  defp send_sync(%Emitter{batch: %Batch{size: nil}}, _), do: :ok

  defp send_sync(%Emitter{} = state, 0) do
    Logger.error("[Firehose] [#{state.stream}] Cannot flush batch")

    for handler <- handlers() do
      apply(handler, :subscribe, [:failed, state.batch])
    end
  end

  defp send_sync(%Emitter{} = state, tries) do
    %Batch{stream: stream, current_record: record, records: records} = state.batch

    records = records || []
    records = [record | records]

    case send_records(state, stream, for(record <- records, do: %{data: record.data})) do
      {:error, _, _} ->
        Process.sleep(1_000)
        send_sync(state, tries - 1)

      {:ok, _} = result ->
        result
    end
  end

  defp send_records(state, stream, records) do
    if @settings[:debug] do
      Logger.debug("[Firehose] [#{stream}] Send records #{inspect(records)}")
      {:ok, :sended}
    else
      send_records_to_firehose(state, stream, records)
    end
  end

  defp send_records_to_firehose(state, stream, records) do
    result =
      stream
      |> ExAws.Firehose.put_record_batch(records)
      |> ExAws.request()

    Logger.debug("[Firehose] [#{stream}] AWS response: #{inspect(result)}")

    case result do
      {:ok, %{"FailedPutCount" => failed, "RequestResponses" => responses}} when failed > 0 ->
        # We should resend failed records
        failed_record =
          for {record, index} <- Enum.with_index(responses),
              Map.get(record, "ErrorCode") != nil do
            Logger.debug("[Firehose] [#{stream}] failed record #{inspect(record)}")
            Enum.at(records, index)
          end

        send_records(state, stream, failed_record)

      {:ok, %{"FailedPutCount" => 0}} ->
        Logger.info("[Firehose] [#{stream}] Batch was successfully flushed")

        for handler <- handlers() do
          apply(handler, :subscribe, [:completed, state.batch])
        end

        {:ok, :sended}

      response ->
        Logger.error("[Firehose] [#{stream}] Batch was not flushed due error. Retry later...")

        for handler <- handlers() do
          apply(handler, :subscribe, [:error, state.batch, response])
        end

        {:error, :failure, response}
    end
  end

  defp debug(state) do
    if state.batch.current_record == nil do
      "(#{state.batch.records_size} records, #{state.batch.size} bytes)"
    else
      "(#{state.batch.records_size} records, #{state.batch.size} bytes, current record: #{
        state.batch.current_record.size
      } bytes)"
    end
  end
end
