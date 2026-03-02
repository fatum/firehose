defmodule Firehose.Supervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    # we will add emitters on the fly
    children = []

    Supervisor.init(children, strategy: :one_for_one)
  end
end
