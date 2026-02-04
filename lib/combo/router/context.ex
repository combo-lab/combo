defmodule Combo.Router.Context do
  @moduledoc false

  @available_names [
    :pipelines,
    :pipeline_plugs,
    :scopes
  ]

  @attr_prefix :combo_router

  def get(module, name) when name in @available_names do
    Module.get_attribute(module, build_attr(name))
  end

  def put(module, name, value) when name in @available_names do
    Module.put_attribute(module, build_attr(name), value)
  end

  def update(module, name, fun) when name in @available_names and is_function(fun, 1) do
    attr = build_attr(name)
    value = Module.get_attribute(module, attr)
    Module.put_attribute(module, attr, fun.(value))
  end

  defp build_attr(name), do: :"#{@attr_prefix}_#{name}"
end
