defmodule Combo.Template.CEExEngine.Sigil do
  @moduledoc """
  Provides `~CE` sigil.
  """

  alias Combo.Template.CEExEngine.Compiler

  @doc """
  The `~CE` sigil for creating inline templates.
  """
  defmacro sigil_CE({:<<>>, meta, [expr]}, modifiers) do
    if not (modifiers == [] or modifiers == ~c"noformat") do
      raise ArgumentError, "~CE expected modifier to be empty or noformat, got: #{modifiers}"
    end

    if not Macro.Env.has_var?(__CALLER__, {:assigns, nil}) do
      raise RuntimeError, "~CE requires a variable named \"assigns\" to exist and be set to a map"
    end

    opts = [
      caller: __CALLER__,
      file: __CALLER__.file,
      line: __CALLER__.line + 1,
      indentation: meta[:indentation] || 0
    ]

    Compiler.compile_string(expr, opts)
  end
end
