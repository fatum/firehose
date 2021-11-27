ExUnit.start()

# Mox.defmock(Firehose.Backend.Dummy, for: Firehose.Backend)

Application.put_env(:firehose, Firehose.Manager, [backend: Firehose.Backend.Dummy])
