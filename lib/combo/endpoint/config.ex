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

  @spec dump(module()) :: keyword()
  def dump(module), do: :ets.tab2list(module)

  @spec get(module(), any(), any()) :: any()
  def get(module, key, default) do
    case :ets.lookup(module, key) do
      [{^key, val}] -> val
      [] -> default
    end
  end

  @impl true
  def init({module, config}) do
    :ets.new(module, [:named_table, :public, read_concurrency: true])
    :ets.insert(module, config)
    {:ok, []}
  end
end
