defmodule Firehose.Manager do
  use GenServer
  require Logger

  def emit(stream, data), do: emit(__MODULE__, stream, data)

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  def start_link(name, options) do
    GenServer.start_link(__MODULE__, options, name: name)
  end

  def init(_opts) do
    Process.flag(:trap_exit, true)

    {:ok, %{}}
  end

  def emit(pid, stream, data) when is_binary(stream) do
    GenServer.call(pid, {:emit, stream, data})
  end

  def handle_call({:emit, stream, data}, _from, state) do
    case state[stream] do
      nil ->
        {pid, state} = create_emitter_for(stream, state)
        Firehose.Emitter.emit(pid, stream, data)

        {:reply, :ok, state}

      pid when is_pid(pid) ->
        if Process.alive?(pid) do
          Firehose.Emitter.emit(pid, stream, data)
          {:reply, :ok, state}
        else
          {pid, state} = create_emitter_for(stream, state)
          Firehose.Emitter.emit(pid, stream, data)

          {:reply, :ok, state}
        end
    end
  end

  def terminate(_) do
    Logger.info("#{__MODULE__} terminating...")

    :ok
  end

  defp create_emitter_for(stream, state) do
    {:ok, pid} = Firehose.Emitter.start_link(stream, __MODULE__)
    {pid, Map.put(state, stream, pid)}
  end
end
