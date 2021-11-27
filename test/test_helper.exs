ExUnit.start()

Mox.defmock(Firehose.Backend.Mock, for: Firehose.Backend)
Application.put_env(:firehose, Firehose.Manager, backend: Firehose.Backend.Mock)
