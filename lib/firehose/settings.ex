defmodule Firehose.Settings do
  @default [flush_interval: 1_000, retries: 5, serializer: Poison, delimiter: "\n", debug: false]

  def debug, do: settings(:debug) || false
  def retries, do: settings(:retries) || @default[:retries]
  def flush_interval, do: settings(:flush_interval) || @default[:flush_interval]
  def handlers, do: settings(:handlers) || @default[:handlers] || []
  def delimiter, do: settings(:delimiter) || @default[:delimiter]
  def serializer, do: settings(:serializer) || @default[:serializer]
  def backend, do: settings(:backend) || Firehose.Backend.Aws

  defp settings(key) do
    env = Application.get_env(:firehose, Firehose.Manager) || []
    Keyword.get(env, key)
  end
end
