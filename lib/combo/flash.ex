defmodule Combo.Flash do
  @moduledoc """
  Provides shared flash access.
  """

  @doc """
  Gets the key from the map of flash data.

  ## Examples

  ```heex
  <div id="info"><%= Combo.Flash.get(@flash, :info) %></div>
  <div id="error"><%= Combo.Flash.get(@flash, :error) %></div>
  ```
  """
  def get(%mod{}, key) when is_atom(key) or is_binary(key) do
    raise ArgumentError, """
    expected a map of flash data, but got a %#{inspect(mod)}{}

    Use the @flash assign set by the :fetch_flash plug instead:

        <%= Combo.Flash.get(@flash, :#{key}) %>
    """
  end

  def get(%{} = flash, key) when is_atom(key) or is_binary(key) do
    Map.get(flash, to_string(key))
  end
end
