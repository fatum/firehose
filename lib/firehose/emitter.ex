defmodule Firehose.Emitter do
  use GenServer
  require Logger

  alias Firehose.{Emitter, Batch, Settings, Utils}
  defstruct [:stream, :manager, :settings, :batch]

  def start_link(stream, manager) do
    GenServer.start_link(__MODULE__, {stream, manager}, [])
  end

  def init({stream, manager}) do
    Process.flag(:trap_exit, true)

    Logger.info("[Firehose] [#{stream}] Initialize emitter")

    state = %Emitter{
      stream: stream,
      manager: manager,
      batch: %Batch{stream: stream}
    }

    Process.send_after(self(), :sync, Settings.flush_interval())

    {:ok, state}
  end

  def emit(stream, data), do: emit(__MODULE__, stream, data)

  def emit(pid, stream, data) when is_binary(stream) do
    case Utils.serialize(data) do
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
        flush(state, Settings.retries())
        handle_call(args, from, %Emitter{state | batch: %Batch{stream: stream}})
    end
  end

  def handle_info(:sync, %Emitter{batch: %Batch{size: 0}} = state) do
    Process.send_after(self(), :sync, Settings.flush_interval())
    {:noreply, state}
  end

  def handle_info(:sync, %Emitter{batch: %Batch{size: nil}} = state) do
    Process.send_after(self(), :sync, Settings.flush_interval())
    {:noreply, state}
  end

  def handle_info(:sync, %Emitter{stream: stream} = state) do
    flush(state, state.settings[:retries])

    Process.send_after(self(), :sync, Settings.flush_interval())

    {:noreply, %Emitter{state | batch: %Batch{stream: stream}}}
  end

  # we need this to catch termination
  def handle_info({:EXIT, _pid, _}, state), do: {:noreply, state}

  def terminate(reason, %Emitter{} = state) do
    Logger.info(
      "[Firehose] [#{state.batch.stream}] Terminating due to #{inspect(reason)}. Pending batch #{debug(state)}"
    )

    # Flush events
    Settings.backend().sync(state, Settings.retries())

    :ok
  end

  defp flush(%Emitter{} = state, tries) do
    Logger.info("[Firehose] [#{state.batch.stream}] Flushing pending batch #{debug(state)}")

    spawn(fn -> Settings.backend().sync(state, tries) end)
  end

  defp debug(state) do
    if state.batch.current_record == nil do
      "(#{state.batch.records_size} records, #{state.batch.size} bytes)"
    else
      "(#{state.batch.records_size} records, #{state.batch.size} bytes, current record: #{state.batch.current_record.size} bytes)"
    end
  end
end
