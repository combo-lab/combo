defmodule ComboTest.Template.CEExEngine.Helper do
  alias Combo.SafeHTML
  alias Combo.Template.CEExEngine.Compiler

  @doc """
  Prints the generated code.
  """
  def puts_compiled(source) do
    opts = [caller: __ENV__, file: __ENV__.file]

    Compiler.compile_string(source, opts)
    |> Macro.to_string()
    |> IO.puts()
  end

  @doc """
  At compile-time, compiles the source into template.
  """
  defmacro compile_string(source) do
    opts = [caller: __CALLER__, file: __CALLER__.file]
    Compiler.compile_string(source, opts)
  end

  @doc """
  At compile-time, compiles the source into template, and generates the
  code for rendering the template as a string.
  """
  defmacro render_string(source, assigns \\ {:%{}, [], []}) do
    opts = [caller: __CALLER__, file: __CALLER__.file]
    compiled = Compiler.compile_string(source, opts)

    quote do
      var!(assigns) = unquote(assigns)

      unquote(compiled)
      |> SafeHTML.to_iodata()
      |> IO.iodata_to_binary()
    end
  end
end
