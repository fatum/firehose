defmodule FirehoseTest do
  use ExUnit.Case

  import Mox

  setup do
    {:ok, pid} = Supervisor.start_link(Firehose.Supervisor, [])

    [pid: pid]
  end

  test "it create event emitter", %{pid: pid} do
    Firehose.emit(pid, "topic", "test")

    assert [{"topic", _pid, _type, [Firehose.Emitter]}] = Supervisor.which_children(pid)
  end
end
