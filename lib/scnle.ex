defmodule Scnle do
  @moduledoc """
  Documentation for Scnle.
  """

  defdelegate get_role(node), to: Scnle.Node
  defdelegate get_leader(node), to: Scnle.Node

  @spec is_leader_elected?(list(node)) :: boolean()
  def is_leader_elected?(nodes) do
    nodes
    |> Enum.map(&get_leader/1)
    |> Enum.filter(&(&1 == nil))
    |> Enum.count()
    |> (&(&1 == 0)).()
  end
end
