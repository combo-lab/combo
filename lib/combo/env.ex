defmodule Combo.Env do
  @moduledoc false

  def get_all_env(namespace) do
    get_all(namespace)
  end

  def get_env(namespace, key, default \\ nil) do
    get(namespace, []) |> Keyword.get(key, default)
  end

  def fetch_env(namespace, key) do
    get(namespace, []) |> Keyword.fetch(key)
  end

  def put_env(namespace, key, value) when is_atom(namespace) and is_atom(key) do
    existing_opts = get(namespace, [])

    [{_namespace, new_opts}] =
      Config.__merge__(
        [{namespace, existing_opts}],
        [{namespace, [{key, value}]}]
      )

    put(namespace, new_opts)
  end

  @app :phoenix
  defp get_all(key), do: Application.get_env(@app, key, [])
  defp get(key, default), do: Application.get_env(@app, key, default)
  defp put(key, value), do: Application.put_env(@app, key, value)
end
