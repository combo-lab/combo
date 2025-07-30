defmodule Phoenix.Template.CEExEngine do
  @moduledoc """
  The template engine that handles the `.ceex` extension.
  """

  @behaviour Phoenix.Template.Engine

  @impl true
  def compile(path, _name) do
    # We need access for the caller, so we return a call to a macro.
    quote do
      require Phoenix.Template.CEExEngine.Compiler
      Phoenix.Template.CEExEngine.Compiler.compile_file(unquote(path))
    end
  end
end
