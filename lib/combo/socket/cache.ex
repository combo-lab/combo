defmodule Combo.Socket.Cache do
  @moduledoc false
  # It's built on top of `Combo.Cache`.

  defdelegate get(endpoint, key, fun), to: Combo.Cache
  defdelegate get(endpoint, key), to: Combo.Cache
  defdelegate put_permanent(endpoint, key, value), to: Combo.Cache
end
