defmodule Phoenix.Template.CEExEngine do
  @moduledoc """
  The template engine that handles CEEx templates.

  > CEEx is a template language forked from Phoenix's HEEx, which strips out
  > code related to LiveView, aiming solely at traditional page rendering.
  >
  > CEEx stands for "Combo EEx". Maybe the name isn't very descriptive, but
  > at least it clearly distinguishes itself from HEEx.

  ## Features

    * syntax checking
    * protection on XSS
    * `assigns` enhancement:
      - `@` syntax
      - declarative API
    * declarative component system
    * code formatter

  ## Modules

  The core feature is implemented by `Phoenix.Template.CEExEngine.Compiler`.

  And, other additional features are implemented by following modules:

    * `Phoenix.Template.CEExEngine.Sigil`
    * `Phoenix.Template.CEExEngine.Slot`
    * `Phoenix.Template.CEExEngine.Assigns`
    * `Phoenix.Template.CEExEngine.DeclarativeAssigns`

  In practice, we rarely use these modules directly. Instead, we use
  `Combo.HTML` which is built on top of them.
  """

  @doc """
  Quick setup for using this engine.
  """
  defmacro __using__(opts \\ []) do
    quote bind_quoted: [opts: opts] do
      import Phoenix.Template.CEExEngine.Sigil
      import Phoenix.Template.CEExEngine.Slot
      import Phoenix.Template.CEExEngine.Assigns
      use Phoenix.Template.CEExEngine.DeclarativeAssigns, opts
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
