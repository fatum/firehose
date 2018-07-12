defmodule Firehose.Record do
  defstruct [:size, :data]

  # 1KiB
  @max_size 1_000_000

  alias Firehose.Record

  def max_size(), do: @max_size

  def add(%Record{} = record, data) when is_binary(data) do
    data_size = byte_size(data)
    record_size = record.size || 0

    if record_size + data_size > @max_size do
      {:error, :full}
    else
      {:ok, %Record{record | size: record_size + data_size, data: (record.data || "") <> data}}
    end
  end
end
