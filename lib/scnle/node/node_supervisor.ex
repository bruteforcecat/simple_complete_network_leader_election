defmodule Scnle.NodeSupervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    children = [
      %{
        id: Scnle.Node,
        start: {Scnle.Node, :start_link, []},
        type: :worker
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
