# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :firehose, SampleEventsManager,
  flush_interval: 1_000,
  retry_count: 5,
  serializer: Poison,
  delimiter: "\n"
