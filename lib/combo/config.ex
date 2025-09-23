defmodule Combo.Config do
  @moduledoc false

  require Logger
  use GenServer

  @doc """
  Starts a configuration handler.
  """
  def start_link({module, config, defaults, opts}) do
    permanent_keys = Keyword.keys(defaults)
    GenServer.start_link(__MODULE__, {module, config, permanent_keys}, opts)
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

  @doc """
  Puts a given key-value pair into config, as permanent.

  Permanent configuration is not deleted on hot code reload.
  """
  @spec put_permanent(module(), any(), any()) :: :ok
  def put_permanent(module, key, value) do
    pid = :ets.lookup_element(module, :__pid__, 2)
    GenServer.call(pid, {:put_permanent, key, value})
  end

  @doc """
  Caches a value in configuration handler for the module.

  The given function needs to return a tuple with `:cache` if the value should
  be cached or `:nocache` if the value should not be cached because it can be
  consequently considered stale.

  Notice writes are not serialized to the server, we expect the function that
  generates the cache to be idempotent.
  """
  @spec cache(module, term, (module -> {:cache | :nocache, term})) :: term
  def cache(module, key, fun) do
    try do
      :ets.lookup(module, key)
    rescue
      e ->
        case :ets.info(module) do
          :undefined ->
            raise """
            could not find ets table for endpoint #{inspect(module)}. \
            Make sure your endpoint is started and note you cannot access endpoint functions \
            at compile-time\
            """

          _ ->
            reraise e, __STACKTRACE__
        end
    else
      [{^key, :cache, val}] ->
        val

      [] ->
        case fun.(module) do
          {:cache, val} ->
            :ets.insert(module, {key, :cache, val})
            val

          {:nocache, val} ->
            val
        end
    end
  end

  @doc """
  Clears all cached entries in the endpoint.
  """
  @spec clear_cache(module) :: :ok
  def clear_cache(module) do
    :ets.match_delete(module, {:_, :cache, :_})
    :ok
  end

  @doc """
  Changes the configuration for the given module.

  It receives a keyword list with changed config and another with removed ones.
  The changed config are updated while the removed ones stop the configuration
  server, effectively removing the table.
  """
  def config_change(module, changed, removed) do
    pid = :ets.lookup_element(module, :__pid__, 2)
    GenServer.call(pid, {:config_change, changed, removed})
  end

  @doc """
  Reads the configuration for module from the given OTP app.

  Useful to read a particular value at compilation time.
  """
  def from_env(otp_app, module, defaults) do
    config = fetch_config(otp_app, module)

    merge(defaults, config)
  end

  defp fetch_config(otp_app, module) do
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
  def handle_call({:put, key, value}, _from, {module, permanent_keys}) do
    :ets.insert(module, {key, value})
    {:reply, :ok, {module, permanent_keys}}
  end

  @impl true
  def handle_call({:put_permanent, key, value}, _from, {module, permanent_keys}) do
    :ets.insert(module, {key, value})
    {:reply, :ok, {module, [key | permanent_keys]}}
  end

  @impl true
  def handle_call({:config_change, changed, removed}, _from, {module, permanent_keys}) do
    cond do
      changed = changed[module] ->
        update(module, changed, permanent_keys)
        {:reply, :ok, {module, permanent_keys}}

      module in removed ->
        {:stop, :normal, :ok, {module, permanent_keys}}

      true ->
        clear_cache(module)
        {:reply, :ok, {module, permanent_keys}}
    end
  end

  defp update(module, config, permanent_keys) do
    old_keys = :ets.select(module, [{{:"$1", :_}, [], [:"$1"]}])
    new_keys = Enum.map(config, &elem(&1, 0))

    :ets.insert(module, config)

    old_useless_keys = (old_keys -- new_keys) -- permanent_keys
    Enum.each(old_useless_keys, &:ets.delete(module, &1))

    clear_cache(module)
  end
end
