defmodule Combo.Endpoint.Config do
  @moduledoc false

  require Logger
  use GenServer

  @doc """
  Starts a configuration handler.
  """
  def start_link({module, config}) do
    opts = [name: Module.concat(module, "Config")]
    GenServer.start_link(__MODULE__, {module, config}, opts)
  end

  @spec get_all(module()) :: keyword()
  def get_all(module), do: :ets.tab2list(module)

  @spec get(module(), any(), any()) :: any()
  def get(module, key, default) do
    case :ets.lookup(module, key) do
      [{^key, val}] -> val
      [] -> default
    end
  end

  def from_env(otp_app, module) do
    case Application.fetch_env(otp_app, module) do
      {:ok, conf} ->
        conf

      :error ->
        Logger.warning(
          "no configuration found for otp_app #{inspect(otp_app)} and module #{inspect(module)}"
        )

        []
    end
  end

  @doc """
  Take 2 keyword lists and merge them recursively.

  Used to merge configuration values into defaults.
  """
  def merge(a, b), do: Keyword.merge(a, b, &merger/3)

  defp merger(_k, v1, v2) do
    if Keyword.keyword?(v1) and Keyword.keyword?(v2) do
      Keyword.merge(v1, v2, &merger/3)
    else
      v2
    end
  end

  @impl true
  def init({module, config}) do
    :ets.new(module, [:named_table, :public, read_concurrency: true])
    :ets.insert(module, config)
    {:ok, []}
  end
end
