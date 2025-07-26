defmodule Phoenix.Template.HTMLEngine.Compiler.Assigns do
  @moduledoc false
  # Transform `@key` calls as  `assigns.key` calls.
  # It's implemented based on
  # https://github.com/elixir-lang/elixir/blob/175c8243b23c4cfcaaa99e60b030085bfef8e9a0/lib/eex/lib/eex/engine.ex#L129

  def handle_assigns({:__block__, _, _} = ast) do
    Macro.prewalk(ast, &handle_assign/1)
  end

  defp handle_assign({:@, meta, [{name, _, atom}]}) when is_atom(name) and is_atom(atom) do
    line = meta[:line] || 0

    quote line: line do
      unquote(__MODULE__).fetch_assign!(var!(assigns), unquote(name))
    end
  end

  defp handle_assign(arg) do
    arg
  end

  @spec fetch_assign!(Access.t(), Access.key()) :: term()
  def fetch_assign!(assigns, key) do
    case Access.fetch(assigns, key) do
      {:ok, val} ->
        val

      :error ->
        keys = Enum.map(assigns, &elem(&1, 0))

        raise KeyError,
              "assign @#{key} not available in HEEx template. " <>
                "Please ensure all assigns are given as options. " <>
                "Available assigns: #{inspect(keys)}"
    end
  end
end
