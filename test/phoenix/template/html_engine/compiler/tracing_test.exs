defmodule Phoenix.Template.HTMLEngine.Compiler.TracingTest do
  use ExUnit.Case, async: true

  import Phoenix.Template.HTMLEngine.CompilerTest.Component, warn: false
  alias Phoenix.Template.HTMLEngine.CompilerTest.Component, as: C, warn: false

  defp eval_string(source, assigns, opts) do
    alias Phoenix.Template.HTMLEngine.Compiler

    {env, opts} = Keyword.pop(opts, :env, __ENV__)
    opts = Keyword.merge([caller: env, file: env.file], opts)
    compiled = Compiler.compile_string(source, opts)
    {result, _} = Code.eval_quoted(compiled, [assigns: assigns], env)
    result
  end

  defmodule Tracer do
    def trace(event, _env)
        when elem(event, 0) in [
               :alias_expansion,
               :alias_reference,
               :imported_function,
               :remote_function
             ] do
      send(self(), event)
      :ok
    end

    def trace(_event, _env), do: :ok
  end

  defp tracer_eval(line, content) do
    eval_string(content, %{},
      env: %{__ENV__ | tracers: [Tracer], lexical_tracker: self(), line: line + 1},
      line: line + 1,
      indentation: 4
    )
  end

  test "handles remote calls" do
    tracer_eval(__ENV__.line, """
    <Phoenix.Template.HTMLEngine.CompilerTest.Component.link>OK</Phoenix.Template.HTMLEngine.CompilerTest.Component.link>
    """)

    assert_receive {:alias_reference, meta, Phoenix.Template.HTMLEngine.CompilerTest.Component}
    assert meta[:line] == __ENV__.line - 4
    assert meta[:column] == 5

    assert_receive {:remote_function, meta, Phoenix.Template.HTMLEngine.CompilerTest.Component, :link, 1}
    assert meta[:line] == __ENV__.line - 8
    assert meta[:column] == 57
  end

  test "handles imports" do
    tracer_eval(__ENV__.line, """
    <.link>OK</.link>
    """)

    assert_receive {:imported_function, meta, Phoenix.Template.HTMLEngine.CompilerTest.Component, :link, 1}
    assert meta[:line] == __ENV__.line - 4
    assert meta[:column] == 5
  end

  test "handles aliases" do
    tracer_eval(__ENV__.line, """
    <C.link>Ok</C.link>
    """)

    assert_receive {:alias_expansion, meta, Elixir.C, Phoenix.Template.HTMLEngine.CompilerTest.Component}
    assert meta[:line] == __ENV__.line - 4
    assert meta[:column] == 5

    assert_receive {:alias_reference, meta, Phoenix.Template.HTMLEngine.CompilerTest.Component}
    assert meta[:line] == __ENV__.line - 8
    assert meta[:column] == 5

    assert_receive {:remote_function, meta, Phoenix.Template.HTMLEngine.CompilerTest.Component, :link, 1}
    assert meta[:line] == __ENV__.line - 12
    assert meta[:column] == 8
  end
end
