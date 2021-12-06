defmodule Firehose.Backend.Dummy do
  @behaviour Firehose.Backend
  require Logger

  @impl Firehose.Backend
  def sync(_, _), do: {:ok, :nothing}
end
