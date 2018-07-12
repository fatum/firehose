defmodule Firehose.Batch do
  defstruct [:stream, :size, :records_size, :current_record, :records]

  # 4MiB
  @max_size 4_096_000
  @max_records 500

  alias Firehose.{Batch, Record}

  def add(%Batch{} = batch, data) when is_binary(data) do
    data_size = byte_size(data)
    batch_size = batch.size || 0

    records = batch.records || []
    # We set default value as 1 because we create the first record later if batch is empty
    records_size = batch.records_size || 1

    cond do
      data_size > Record.max_size() ->
        {:error, :record_limit}

      batch_size + data_size > @max_size ->
        {:error, :size_limit}

      records_size + 1 > @max_records ->
        {:error, :records_limit}

      record = batch.current_record || %Record{} ->
        batch =
          case Record.add(record, data) do
            {:ok, record} ->
              %Batch{
                stream: batch.stream,
                current_record: record,
                records_size: records_size,
                records: records,
                size: batch_size + data_size
              }

            {:error, :full} ->
              {:ok, new_record} = Record.add(%Record{}, data)

              %Batch{
                stream: batch.stream,
                current_record: new_record,
                size: batch_size + data_size,
                records_size: records_size + 1,
                records: [record | records]
              }
          end

        {:ok, batch}
    end
  end
end
