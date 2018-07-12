defmodule Firehose.RecordTest do
  use ExUnit.Case, async: true

  alias Firehose.Record

  test "#max_size" do
    assert Record.max_size() == 1_000_000
  end

  describe "#add" do
    test "puts small chunk into empty record" do
      binary_data = "test string"

      {:ok, %Record{size: size, data: data}} = Record.add(%Record{}, binary_data)

      assert size == byte_size(binary_data)
      assert data == binary_data
    end

    test "puts small chunk into not empty record" do
      binary_data = "test string"

      {:ok, record} = Record.add(%Record{}, binary_data)
      {:ok, %Record{size: size, data: data}} = Record.add(record, binary_data)

      assert size == byte_size(binary_data) * 2
      assert data == binary_data <> binary_data
    end

    test "puts chunk into full record" do
      binary_data = "test string"
      binary_size = byte_size(binary_data)

      iterations = (1_000_000.0 / binary_size) |> trunc()

      string =
        Enum.reduce(1..iterations, "", fn _i, acc ->
          acc <> binary_data
        end)

      {:ok, record} = Record.add(%Record{}, string)

      {error, reason} = Record.add(record, binary_data)

      assert error == :error
      assert reason == :full
    end
  end
end
