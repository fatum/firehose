defmodule Firehose.Utils do
  alias Firehose.Settings

  def serialize(data) do
    delimiter =
      case Settings.delimiter() do
        nil -> ""
        delimiter -> delimiter
      end

    case Settings.serializer() do
      nil ->
        {:ok, data <> delimiter}

      serializer ->
        case serializer.encode(data) do
          {:ok, data} ->
            {:ok, data <> delimiter}

          error ->
            error
        end
    end
  end
end
