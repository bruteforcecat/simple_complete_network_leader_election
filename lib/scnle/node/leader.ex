defmodule Scnle.Leader do
  @moduledoc """
  Behaviour for modules that care about leader functions
  Not used for now but will be used for master-slaves pattern later
  """

  @doc """
  callback to nofiy a new leader is selected
  """
  @callback leader_selected(any()) :: :ok

  @doc """
  callback to notify a node is down
  """
  @callback node_down() :: :ok
end
