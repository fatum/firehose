defmodule FirehoseTest do
  use ExUnit.Case

  setup do
    {:ok, pid} = Supervisor.start_link(Firehose.Supervisor, [])

    [pid: pid]
  end

  test "it create event emitter", %{pid: pid} do
    Firehose.emit(pid, "topic", "test")

    assert [{"topic", _pid, _type, [Firehose.Emitter]}] = Supervisor.which_children(pid)
  end

  test "it respawn event emitter", %{pid: pid} do
    Firehose.emit(pid, "topic1", "test1")
    Firehose.emit(pid, "topic2", "test2")

    [
      {"topic2", child_pid1, _, [Firehose.Emitter]},
      {"topic1", _child_pid2, _, [Firehose.Emitter]}
    ] = Supervisor.which_children(pid)

    # Killing emitter process
    Process.exit(child_pid1, :normal)

    assert [
      {"topic2", _, _, [Firehose.Emitter]},
      {"topic1", _, _, [Firehose.Emitter]}
    ] = Supervisor.which_children(pid)
  end
end
