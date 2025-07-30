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

  alias Combo.SafeHTML

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
    ast = quote do: unquote(var) = unquote(to_safe(expr))

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

  ## Safe conversion

  defp to_safe(expr), do: to_safe(expr, line_from_expr(expr))

  # do the conversion at compile time
  defp to_safe(literal, _line)
       when is_binary(literal) or is_atom(literal) or is_number(literal) do
    literal
    |> SafeHTML.to_iodata()
    |> IO.iodata_to_binary()
  end

  # do the conversion at runtime
  defp to_safe(list, line) when is_list(list) do
    quote line: line, do: Phoenix.HTML.Safe.List.to_iodata(unquote(list))
  end

  # do the convertion at runtime, and optimize common cases
  defp to_safe(expr, line) do
    # keep stacktraces for protocol dispatch and coverage
    safe_return = quote line: line, do: data
    bin_return = quote line: line, do: Combo.SafeHTML.escape(bin)
    other_return = quote line: line, do: Combo.SafeHTML.to_iodata(other)

    # prevent warnings of generated clauses
    quote generated: true do
      case unquote(expr) do
        {:safe, data} -> unquote(safe_return)
        bin when is_binary(bin) -> unquote(bin_return)
        other -> unquote(other_return)
      end
    end
  end

  defp line_from_expr({_, meta, _}) when is_list(meta), do: Keyword.get(meta, :line, 0)
  defp line_from_expr(_), do: 0
end
