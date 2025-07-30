defmodule Phoenix.Template.CEExEngine do
  @moduledoc """
  The template engine that handles the `.ceex` extension.

  The core feature is implemented by `Phoenix.Template.CEExEngine.Compiler`.

  And, other additional features are implemented by following modules:

  - `Phoenix.Template.CEExEngine.Sigil`
  - `Phoenix.Template.CEExEngine.Assigns`
  - `Phoenix.Template.CEExEngine.DeclarativeAssigns`
  - `Phoenix.Template.CEExEngine.Slot`

  In practice, you don't use these modules directly. Instead, you use
  `Phoenix.HTML` which is built on top of them.
  """

  @doc """
  Quick setup for using this engine.
  """
  defmacro __using__(opts \\ []) do
    quote bind_quoted: [opts: opts] do
      import Phoenix.Template, only: [embed_templates: 1]

      import Phoenix.Template.CEExEngine.Sigil
      import Phoenix.Template.CEExEngine.Assigns
      use Phoenix.Template.CEExEngine.DeclarativeAssigns, opts
      import Phoenix.Template.CEExEngine.Slot
    end
  end

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
