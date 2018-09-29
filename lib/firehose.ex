defmodule Firehose do
  defdelegate emit(stream, data), to: Firehose.Manager
end
