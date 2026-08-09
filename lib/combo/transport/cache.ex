defmodule Combo.Transport.Cache do
  @moduledoc false

  @namespace :transport

  def get(endpoint, key, fun), do: Combo.Cache.get(endpoint, {@namespace, key}, fun)
end
