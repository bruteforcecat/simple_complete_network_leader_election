defmodule Scnle do
  @moduledoc """
  Documentation for Scnle.
  """

  alias Scnle.Node

  def get_leader(node) do
    node
  end

  def is_leader_elected?(nodes) do
    nodes
    |> Enum.map(&Node.get_leader/1)
    |> Enum.filter(&(&1 == nil))
    |> Enum.count()
    |> (&(&1 == 0)).()
  end
end
