# Firehose

This library helps to manage data sending to AWS Firehose dealing with its limitations:

> The maximum size of a record sent to Kinesis Data Firehose, before base64-encoding, is 1,000 KiB.
> The PutRecordBatch operation can take up to 500 records per call or 4 MiB per call, whichever is smaller...the size of each record rounded up to the nearest 5KB

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `firehose` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:firehose, "~> 1.0.0"}
  ]
end
```

## Usage

Create module which will handle callbacks:

```elixir
defmodule Event.Handler do
  def subscribe(:failed, %Firehose.Batch{} = batch, aws_response) do
    # This callback is triggered when retry count exhausted and batch not delivered.
    # You can add specific logic for this case (write data to queue or database etc) or
    # send metrics to monitoring service
  end

  def subscribe(:completed, %Firehose.Batch{stream: stream, size: batch_size, records: records}) do
    # This callback is triggered after each successfull delivery to Firehose.
    # You can use this callback to send metrics to monitoring service
  end
end
```

Add appropriate configurations for `ex_aws` and `firehose`:

```elixir
config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role]

config :firehose, Firehose.Manager,
  handlers: [Event.Handler],
  flush_interval: 1_000, # Flush batches every seconds or on batch size limit
  retries: 5,            # Retry count for failed requests
  serializer: Poison,    # Event serializer: should respond to `encode` and `decode` methods
  delimiter: "\n",       # Add delimiter after each event or add nothing if `false` or `nil` set
```

Add `Firehose.Supervisor` to your supervisor tree and thats it. You can emit events to AWS Firehose like this:

```elixir
Firehose.emit("logs", %{"name" => "pageview", "ua" => "..."})
```


Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/firehose](https://hexdocs.pm/firehose).

