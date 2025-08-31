defmodule Combo.Template.CEExEngine do
  @moduledoc """
  The template engine that handles CEEx templates.

  > CEEx is a template language forked from Phoenix's HEEx, which strips out
  > code related to LiveView, aiming solely at static template rendering.
  >
  > CEEx stands for "Combo EEx". Maybe the name isn't very descriptive, but
  > at least it clearly distinguishes itself from HEEx.

  ## Features

    * syntax checking
    * `assigns` enhancement:
      - `@` syntax
      - declarative assigns
    * component system
    * protection on XSS
    * code formatter

  ## Modules

  The core feature is implemented by `Combo.Template.CEExEngine.Compiler`.

  And, other additional features are implemented by following modules:

    * `Combo.Template.CEExEngine.Slot`
    * `Combo.Template.CEExEngine.Sigil`
    * `Combo.Template.CEExEngine.Assigns`
    * `Combo.Template.CEExEngine.DeclarativeAssigns`

  In practice, we rarely use these modules directly. Instead, we use
  `Combo.HTML` which is built on top of them.
  """

  @doc """
  Quick setup for using this engine.
  """
  defmacro __using__(opts \\ []) do
    quote bind_quoted: [opts: opts] do
      import Combo.Template.CEExEngine.Slot
      import Combo.Template.CEExEngine.Sigil
      import Combo.Template.CEExEngine.Assigns
      use Combo.Template.CEExEngine.DeclarativeAssigns, opts
    end
  end

  @behaviour Combo.Template.Engine

  @impl true
  def compile(path, _name) do
    # We need access for the caller, so we return a call to a macro.
    quote do
      require Combo.Template.CEExEngine.Compiler
      Combo.Template.CEExEngine.Compiler.compile_file(unquote(path))
    end
  end
end
