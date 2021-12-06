defmodule Firehose.Manager do
  require Logger

  alias Firehose.Emitter

  def emit(stream, data) when is_binary(stream) do
    Firehose.Supervisor
    |> Supervisor.which_children()
    |> route_event(Firehose.Supervisor, stream, data)
  end

  def emit(pid, stream, data) when is_binary(stream) do
    pid
    |> Supervisor.which_children()
    |> route_event(pid, stream, data)
  end

  defp route_event(streams, pid, stream, data) do
    case Enum.find(streams, fn {id, _, _, _} -> id == stream end) do
      nil ->
        {:ok, child_pid} =
          Supervisor.start_child(pid, %{
            id: stream,
            start: {Emitter, :start_link, [stream, Supervisor]}
          })

        Emitter.emit(child_pid, stream, data)

      {_, pid, _, _} ->
        Emitter.emit(pid, stream, data)
    end
  end
end
