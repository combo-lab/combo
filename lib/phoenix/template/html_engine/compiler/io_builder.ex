defmodule Phoenix.Template.HTMLEngine.Compiler.IOBuilder do
  @moduledoc false

  # The module for building IO data.
  #
  # This module is built based on:
  # - Phoenix.HTML.Engine
  # - Phoenix.LiveView.Engine
  #
  # TODO: the to_safe/1 is relatively simple, I will merge more code from
  #       above engines.

  defmodule Counter do
    @moduledoc false

    def new, do: :counters.new(1, [])
    def inc(counter), do: :counters.add(counter, 1, 1)
    def get(counter), do: :counters.get(counter, 1)
  end

  # Initialize a new state.
  def init do
    %{
      static: [],
      dynamic: [],
      # the engine evaluates slots in a non-linear order, which can
      # lead to variable conflicts. Therefore we use a counter to
      # ensure all variable names are unique.
      counter: Counter.new()
    }
  end

  # Reset a state.
  def reset(state) do
    %{state | static: [], dynamic: []}
  end

  # Dump state to AST.
  def dump(state) do
    %{static: static, dynamic: dynamic} = state
    safe = {:safe, Enum.reverse(static)}
    {:__block__, [], Enum.reverse([safe | dynamic])}
  end

  # Accumulate text into state.
  def acc_text(state, text) do
    %{static: static} = state
    %{state | static: [text | static]}
  end

  # Accumulate expr into state.
  def acc_expr(state, "=" = _marker, expr) do
    %{static: static, dynamic: dynamic, counter: counter} = state

    i = Counter.get(counter)
    var = Macro.var(:"v#{i}", __MODULE__)
    ast = quote do: unquote(var) = unquote(__MODULE__).to_safe(unquote(expr))

    Counter.inc(counter)
    %{state | dynamic: [ast | dynamic], static: [var | static]}
  end

  def acc_expr(state, "" = _marker, expr) do
    %{dynamic: dynamic} = state
    %{state | dynamic: [expr | dynamic]}
  end

  def acc_expr(state, marker, expr) do
    EEx.Engine.handle_expr(state, marker, expr)
  end

  @doc false
  def to_safe(value) do
    case value do
      {:safe, data} -> data
      bin when is_binary(bin) -> Phoenix.HTML.Engine.html_escape(bin)
      other -> Phoenix.HTML.Safe.to_iodata(other)
    end
  end
end
