defmodule Scnle.Network do
  @moduledoc """
  Handling peers discovery
  """

  @spec get_self_node() :: node()
  def get_self_node() do
    Node.self()
  end

  @spec get_node_list() :: list(node())
  def get_node_list() do
    Node.list()
  end
end
