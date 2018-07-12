defmodule Firehose.SampleEventsManager do
  use Firehose.Manager

  @moduledoc """
  This module is an example of `firehose` usage patterns
  """

  @doc """
    This callback is triggered when retry count exhausted and batch isn't delivered to Firehose.
    You can add specific logic for this case (write data to queue or database etc) or
    send metrics to monitoring service
  """
  def subscribe(:failed, %Firehose.Batch{} = _batch, _aws_response) do
  end

  @doc """
    This callback is triggered after each successfull delivery to Firehose.
    You can use this callback to send metrics to monitoring service
  """
  def subscribe(:completed, %Firehose.Batch{stream: _stream, size: _batch_size, records: _records}) do
  end
end
