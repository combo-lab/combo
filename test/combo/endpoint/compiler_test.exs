defmodule Combo.Endpoint.CompilerTest do
  use ExUnit.Case, async: true

  alias Combo.Endpoint.Compiler

  defmodule StateCompiler do
    @behaviour Compiler

    def setup do
      quote do
        Module.register_attribute(__MODULE__, :compiler_events, accumulate: true)
        @compiler_events :setup
      end
    end

    def install do
      quote do
        @compiler_events :install
      end
    end

    def before_compile(endpoint) do
      events = endpoint |> Module.get_attribute(:compiler_events) |> Enum.reverse()

      quote do
        def compiler_events, do: unquote(events)
      end
    end
  end

  defmodule InstallOnlyCompiler do
    @behaviour Compiler

    def install do
      quote do
        @compiler_events :second_install
      end
    end
  end

  defmodule EndpointBuilder do
    defmacro __using__(_) do
      quote do
        unquote(Compiler.setup([StateCompiler, InstallOnlyCompiler]))
        unquote(Compiler.install([StateCompiler, InstallOnlyCompiler]))
        @before_compile EndpointBuilder
      end
    end

    defmacro __before_compile__(%{module: endpoint}) do
      Compiler.before_compile([StateCompiler, InstallOnlyCompiler], endpoint)
    end
  end

  defmodule Example do
    use EndpointBuilder
    @compiler_events :user_declaration
  end

  test "stages share module state, preserve compiler order, and include user declarations" do
    assert Example.compiler_events() == [:setup, :install, :second_install, :user_declaration]
  end

  test "an empty compiler list emits no code" do
    for ast <- [Compiler.setup([]), Compiler.install([]), Compiler.before_compile([], Example)] do
      assert {nil, []} = Code.eval_quoted(ast)
    end
  end

  test "an unavailable compiler fails instead of being treated as an optional callback" do
    assert_raise ArgumentError, fn ->
      Compiler.setup([__MODULE__.MissingCompiler])
    end
  end
end
