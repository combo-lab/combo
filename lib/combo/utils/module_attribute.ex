defmodule Combo.Utils.ModuleAttribute do
  @moduledoc false

  def register(module, name, opts \\ [])
      when is_atom(module) and is_atom(name) do
    Module.register_attribute(module, name, opts)
  end

  def get(module, name)
      when is_atom(module) and is_atom(name) do
    Module.get_attribute(module, name)
  end

  def put(module, name, value)
      when is_atom(module) and is_atom(name) do
    Module.put_attribute(module, name, value)
  end

  def update(module, name, fun)
      when is_atom(module) and is_atom(name) and is_function(fun, 1) do
    value = Module.get_attribute(module, name)
    new_value = fun.(value)
    Module.put_attribute(module, name, new_value)
  end
end
