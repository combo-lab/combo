defmodule Combo.Router.Context do
  @moduledoc false

  @available_names [
    :pipeline_plugs
  ]

  @attr_prefix :combo_router

  def init(module, name) when name in @available_names do
    Module.put_attribute(module, build_attr(name), nil)
  end

  def get(module, name) when name in @available_names do
    Module.get_attribute(module, build_attr(name))
  end

  def put(module, name, value) when name in @available_names do
    Module.put_attribute(module, build_attr(name), value)
  end

  defp build_attr(name), do: :"#{@attr_prefix}_#{name}"
end
