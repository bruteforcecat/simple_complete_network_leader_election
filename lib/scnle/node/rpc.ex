defmodule Scnle.RPC do
  @moduledoc """
  Handling communication between peers
  This allow abstraction of the communication beween peers
  Right now it expects another peer is also erlang node but we can support other nodes when we
  talk in say TCP
  """

  require Logger

  alias Scnle.Network

  @type message :: term()

  # assume all communication is async
  @spec send_message(list(node()), message) :: :ok
  def send_message(nodes, message) when is_list(nodes) do
    Enum.each(nodes, &send_message(&1, message))
  end

  @spec send_message(node, message) :: :ok
  def send_message(node, message) when is_atom(node) do
    self_node = Network.get_self_node()

    Logger.info(
      "Node #{self_node} send to Node #{inspect(node)} : send_message #{inspect(message)}"
    )

    GenServer.cast({Scnle.Node, node}, {message, self_node})
  end
end
