defmodule Phoenix.Template.HTMLEngine do
  @moduledoc """
  The engine that powers Combo HTML templates.
  """

  @behaviour Phoenix.Template.Engine

  @impl true
  def compile(path, _name) do
    # We need access for the caller, so we return a call to a macro.
    quote do
      require Phoenix.Template.HTMLEngine.Compiler
      Phoenix.Template.HTMLEngine.Compiler.compile_file(unquote(path))
    end
  end
end
