defmodule Scnle do
  @moduledoc """
  Documentation for Scnle.
  """

  alias Scnle.Node

  def get_leader(node) do
    node
  end

  defdelegate get_role(node), to: Scnle.Node

  def is_leader_elected?(nodes) do
    nodes
    |> Enum.map(&Node.get_leader/0)
    |> Enum.filter(&(&1 == nil))
    |> Enum.count()
    |> (&(&1 == 0)).()
  end
end
