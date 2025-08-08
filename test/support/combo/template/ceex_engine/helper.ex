defmodule ComboTest.Template.CEExEngine.Helper do
  alias Combo.SafeHTML
  alias Combo.Template.CEExEngine.Compiler

  defmacro render_compiled(source) do
    opts = [
      caller: __CALLER__,
      file: __ENV__.file
    ]

    compiled = Compiler.compile_string(source, opts)

    quote do
      unquote(compiled)
      |> SafeHTML.to_iodata()
      |> IO.iodata_to_binary()
    end
  end
end
