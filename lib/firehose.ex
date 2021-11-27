defmodule Firehose do
  defdelegate emit(stream, data), to: Firehose.Manager
  defdelegate emit(pid, stream, data), to: Firehose.Manager
end
