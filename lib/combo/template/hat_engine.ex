defmodule Combo.Template.HATEngine do
  @moduledoc """
  The template engine that handles HAT templates.
  """

  @behaviour Combo.Template.Engine

  def compile(path, _name) do
    # We need access for the caller, so we return a call to a macro.
    quote do
      require HAT.Compiler
      HAT.Compiler.compile_file(unquote(path))
    end
  end
end
