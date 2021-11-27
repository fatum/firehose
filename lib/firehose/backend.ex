defmodule Firehose.Backend do
  @callback sync(Firehose.Emitter.t(), integer()) ::
              {:ok, :nothing | :synced} | {:error, :failure, String.t()}
end
