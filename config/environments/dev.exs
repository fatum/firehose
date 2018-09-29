use Mix.Config

config :firehose, Firehose.Manager, debug: true

config :ex_aws,
  region: "eu-west-1",
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role]

config :ex_aws, :hackney_opts,
  follow_redirect: true,
  connect_timeout: 1_000,
  recv_timeout: 30_000

config :logger,
  backends: [:console],
  level: :debug,
  compile_time_purge_matching: [
    [level_lower_than: :debug]
  ]
