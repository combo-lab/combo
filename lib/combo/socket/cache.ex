defmodule Combo.Socket.Cache do
  @moduledoc false
  # It's built on top of `Combo.Cache`.

  def get(endpoint, key, fun) when is_function(fun, 0) do
    Combo.Cache.get(endpoint, key, fun)
  end
end
