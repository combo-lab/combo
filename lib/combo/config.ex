defmodule Combo.Config do
  @moduledoc false

  require Logger
  use GenServer

  @doc """
  Starts a configuration handler.
  """
  def start_link({module, config, permanent_keys, opts}) do
    GenServer.start_link(__MODULE__, {module, config, permanent_keys}, opts)
  end

  @doc """
  Returns all key-value pairs.
  """
  @spec get_all(module()) :: keyword()
  def get_all(module) do
    pid = :ets.lookup_element(module, :__pid__, 2)
    GenServer.call(pid, :get_all)
  end

  @doc """
  Gets a value by given key.
  """
  @spec get(module(), any(), any()) :: any()
  def get(module, key, default) do
    case :ets.lookup(module, key) do
      [{^key, val}] -> val
      [] -> default
    end
  end

  @doc """
  Puts a given key-value pair into config.
  """
  @spec put(module(), any(), any()) :: :ok
  def put(module, key, value) do
    pid = :ets.lookup_element(module, :__pid__, 2)
    GenServer.call(pid, {:put, key, value})
  end

  def config_change(module, changed_config) do
    pid = :ets.lookup_element(module, :__pid__, 2)
    GenServer.call(pid, {:config_change, changed_config})
  end

  def stop(module) do
    pid = :ets.lookup_element(module, :__pid__, 2)
    GenServer.call(pid, :stop)
  end

  @doc """
  Reads the configuration for module from the given OTP app.

  Useful to read a particular value at compilation time.
  """
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
  def init({module, config, permanent_keys}) do
    :ets.new(module, [:named_table, :public, read_concurrency: true])
    update(module, config, [])
    :ets.insert(module, {:__pid__, self()})
    {:ok, {module, [:__pid__ | permanent_keys]}}
  end

  @impl true
  def handle_call(:get_all, _from, {module, permanent_keys}) do
    config =
      :ets.tab2list(module)
      |> Enum.filter(fn
        {:__pid__, _} -> false
        {_, _} -> true
      end)

    {:reply, config, {module, permanent_keys}}
  end

  @impl true
  def handle_call({:put, key, value}, _from, {module, permanent_keys}) do
    :ets.insert(module, {key, value})
    {:reply, :ok, {module, permanent_keys}}
  end

  @impl true
  def handle_call({:config_change, changed_config}, _from, {module, permanent_keys}) do
    update(module, changed_config, permanent_keys)
    {:reply, :ok, {module, permanent_keys}}
  end

  @impl true
  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  defp update(module, config, permanent_keys) do
    old_keys = :ets.select(module, [{{:"$1", :_}, [], [:"$1"]}])
    new_keys = Enum.map(config, &elem(&1, 0))

    :ets.insert(module, config)

    old_useless_keys = (old_keys -- new_keys) -- permanent_keys
    Enum.each(old_useless_keys, &:ets.delete(module, &1))
  end
end
