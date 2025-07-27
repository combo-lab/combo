defmodule Phoenix.Template.HTMLEngine.Sigil do
  @moduledoc """
  Provides sigils for working with `Phoenix.Template.HTMLEngine`.
  """

  alias Phoenix.Template.HTMLEngine.Compiler

  defmacro sigil_CH({:<<>>, meta, [expr]}, modifiers)
           when modifiers == [] or modifiers == ~c"noformat" do
    if not Macro.Env.has_var?(__CALLER__, {:assigns, nil}) do
      raise "~CH requires a variable named \"assigns\" to exist and be set to a map"
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
