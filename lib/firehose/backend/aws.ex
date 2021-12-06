defmodule Firehose.Backend.Aws do
  @behaviour Firehose.Backend

  require Logger

  alias Firehose.{Batch, Emitter, Settings}

  @impl Firehose.Backend
  def sync(%Emitter{batch: %Batch{size: 0}}, _), do: {:ok, :nothing}
  def sync(%Emitter{batch: %Batch{size: nil}}, _), do: {:ok, :nothing}

  def sync(%Emitter{} = state, 0) do
    Logger.error("[Firehose] [#{state.stream}] Cannot flush batch")

    for handler <- Settings.handlers() do
      apply(handler, :subscribe, [:failed, state.batch])
    end
  end

  def sync(%Emitter{} = state, tries) do
    %Batch{stream: stream, current_record: record, records: records} = state.batch

    records = records || []
    records = [record | records]

    case send_records(state, stream, for(record <- records, do: %{data: record.data})) do
      {:error, _, _} ->
        Process.sleep(1_000)
        sync(state, tries - 1)

      {:ok, _} = result ->
        result
    end
  end

  defp send_records(state, stream, records) do
    if Settings.debug() do
      Logger.debug("[Firehose] [#{stream}] Send records #{inspect(records)}")
      {:ok, :synced}
    else
      send_records_to_firehose(state, stream, records)
    end
  end

  defp send_records_to_firehose(state, stream, records) do
    result =
      stream
      |> ExAws.Firehose.put_record_batch(records)
      |> ExAws.request()

    Logger.debug("[Firehose] [#{stream}] AWS response: #{inspect(result)}")

    case result do
      {:ok, %{"FailedPutCount" => failed, "RequestResponses" => responses}} when failed > 0 ->
        # We should resend failed records
        failed_record =
          for {record, index} <- Enum.with_index(responses),
              Map.get(record, "ErrorCode") != nil do
            Logger.debug("[Firehose] [#{stream}] failed record #{inspect(record)}")
            Enum.at(records, index)
          end

        send_records(state, stream, failed_record)

      {:ok, %{"FailedPutCount" => 0}} ->
        Logger.info("[Firehose] [#{stream}] Batch was successfully flushed")

        for handler <- Settings.handlers() do
          apply(handler, :subscribe, [:completed, state.batch])
        end

        {:ok, :synced}

      response ->
        Logger.error("[Firehose] [#{stream}] Batch was not flushed due error. Retry later...")

        for handler <- Settings.handlers() do
          apply(handler, :subscribe, [:error, state.batch, response])
        end

        {:error, :failure, response}
    end
  end
end
