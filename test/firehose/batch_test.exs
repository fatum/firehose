defmodule Firehose.BatchTest do
  use ExUnit.Case, async: true

  alias Firehose.{Batch, Record}

  describe "#add" do
    test "puts small chunk into empty batch" do
      binary_data = "test string"

      {:ok,
       %Batch{
         size: size,
         records_size: records_size,
         current_record: %Record{size: rsize, data: rdata}
       }} = Batch.add(%Batch{}, binary_data)

      assert size == byte_size(binary_data)
      assert records_size == 1
      assert rsize == byte_size(binary_data)
      assert rdata == binary_data
    end

    test "puts small chunk into not empty batch" do
      binary_data = "test string"

      {:ok, batch} = Batch.add(%Batch{}, binary_data)

      {:ok,
       %Batch{
         size: size,
         records_size: records_size,
         current_record: %Record{size: rsize, data: rdata}
       }} = Batch.add(batch, binary_data)

      assert size == byte_size(binary_data) * 2
      assert records_size == 1
      assert rsize == byte_size(binary_data) * 2
      assert rdata == binary_data <> binary_data
    end

    test "puts chunk into full record in batch" do
      binary_data = "test string"
      binary_size = byte_size(binary_data)

      iterations = (1_000_000.0 / binary_size) |> trunc()

      string =
        Enum.reduce(1..iterations, "", fn _i, acc ->
          acc <> binary_data
        end)

      {:ok, batch} = Batch.add(%Batch{}, string)

      {:ok,
       %Batch{
         size: size,
         records_size: records_size,
         current_record: %Record{size: rsize, data: rdata},
         records: [%Record{size: brsize}]
       }} = Batch.add(batch, binary_data)

      assert size == byte_size(string) + byte_size(binary_data)
      assert records_size == 2
      assert rsize == byte_size(binary_data)
      assert rdata == binary_data

      assert brsize == byte_size(string)
    end
  end
end
