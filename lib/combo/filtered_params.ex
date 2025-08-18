defmodule Combo.FilteredParams do
  @moduledoc """
  Filtering sensitive parameters, such as passwords and tokens.

  ## Configuration

  Parameters to be filtered are specified by the `:rule` option.

      config :combo, :filtered_params, 
        rule: {:discard, ["password", "secret"]}
        replacement: "[FILTERED]"

  ## Rules

    * `{:discard, keys}`, filters paramaters specified by `keys`, and keep
      other parameters. For example: `{:discard, ["password", "secret"]}`.

    * `{:keep, keys}`, keeps paramaters specified by `keys`, and keep other
      parameters. For example: `{:keep, ["id", "order"]}`.

  And, the matching on keys is case sensitive.

  The default one is `{:discard, ["password"]}`.

  ## Replacements

  Common replacements are `"[FILTERED]"` or `"[REDACTED]"`. The default one is
  `"[FILTERED]"`.
  """

  @doc """
  Filters it.
  """
  def filter(value, rule \\ rule()) do
    case rule do
      {:discard, keys} -> discard(value, keys)
      {:keep, keys} -> keep(value, keys)
    end
  end

  defp discard(%{__struct__: mod} = struct, _keys) when is_atom(mod) do
    struct
  end

  defp discard(%{} = map, keys) do
    Enum.into(map, %{}, fn {k, v} ->
      if is_binary(k) and String.contains?(k, keys) do
        {k, replacement()}
      else
        {k, discard(v, keys)}
      end
    end)
  end

  defp discard(list, keys) when is_list(list) do
    Enum.map(list, &discard(&1, keys))
  end

  defp discard(other, _keys), do: other

  defp keep(%{__struct__: mod}, _match) when is_atom(mod), do: replacement()

  defp keep(%{} = map, keys) do
    Enum.into(map, %{}, fn {k, v} ->
      if is_binary(k) and k in keys do
        {k, v}
      else
        {k, keep(v, keys)}
      end
    end)
  end

  defp keep(list, keys) when is_list(list) do
    Enum.map(list, &keep(&1, keys))
  end

  defp keep(_other, _keys), do: replacement()

  @default_rule {:discard, ["password"]}
  defp rule do
    Combo.Env.get_env(:filtered_params, :rule, @default_rule)
  end

  defp replacement do
    Combo.Env.get_env(:filtered_params, :replacement, "[FILTERED]")
  end
end
