defmodule Combo.Template.CEExEngine.Compiler.Assigns do
  @moduledoc false

  @doc """
  Traverses `@key` calls as  `assigns.key` calls.

  It's implemented based on
  <https://github.com/elixir-lang/elixir/blob/175c8243b23c4cfcaaa99e60b030085bfef8e9a0/lib/eex/lib/eex/engine.ex#L129>.
  """
  def traverse(quoted) do
    Macro.prewalk(quoted, &handle_assign/1)
  end

  defp handle_assign({:@, meta, [{name, _, atom}]}) when is_atom(name) and is_atom(atom) do
    line = meta[:line] || 0

    quote line: line do
      unquote(__MODULE__).fetch_assign!(var!(assigns), unquote(name))
    end
  end

  defp handle_assign(quoted), do: quoted

  @doc false
  @spec fetch_assign!(Access.t(), Access.key()) :: term()
  def fetch_assign!(assigns, key) do
    case Access.fetch(assigns, key) do
      {:ok, value} ->
        value

      :error ->
        keys = Enum.map(assigns, &elem(&1, 0))

        raise KeyError, """
        assign @#{key} not available in template.

        Available assigns: #{inspect(keys)}
        """
    end
  end
end
