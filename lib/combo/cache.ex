defmodule Combo.Cache do
  @moduledoc false

  use GenServer

  @type key :: term()
  @type value :: term()

  @spec start_link(module()) :: GenServer.on_start()
  def start_link(module) do
    opts = [name: build_process_name(module)]
    GenServer.start_link(__MODULE__, module, opts)
  end

  @spec get(module(), key()) :: value() | nil
  def get(module, key) do
    table_name = build_table_name(module)

    case :ets.lookup(table_name, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  @spec get(module(), key(), (... -> {:ok, value()} | :error)) :: value() | nil
  def get(module, key, fun) when is_function(fun, 0) do
    table_name = build_table_name(module)

    case :ets.lookup(table_name, key) do
      [{^key, value}] ->
        value

      [] ->
        case fun.() do
          {:ok, value} ->
            true = :ets.insert(table_name, {key, value})
            value

          :error ->
            nil
        end
    end
  end

  @spec put(module(), key(), value()) :: :ok
  def put(module, key, value) do
    table_name = build_table_name(module)
    true = :ets.insert(table_name, {key, value})
    :ok
  end

  @spec put(module(), [{key(), value()}]) :: :ok
  def put(_module, []), do: :ok

  def put(module, [{_, _} | _] = kvs) do
    table_name = build_table_name(module)
    true = :ets.insert(table_name, kvs)
    :ok
  end

  @spec delete(module(), key()) :: :ok
  def delete(module, key) do
    table_name = build_table_name(module)
    true = :ets.delete(table_name, key)
    :ok
  end

  @spec dump(module()) :: [{key(), value()}]
  def dump(module) do
    table_name = build_table_name(module)
    :ets.tab2list(table_name)
  end

  @spec get_keys(module()) :: [key()]
  def get_keys(module), do: get_keys(module, :"$1")

  @spec get_keys(module(), :ets.match_spec()) :: [key()]
  def get_keys(module, key_match_spec) do
    table_name = build_table_name(module)

    match_spec =
      case key_match_spec do
        key when is_atom(key) -> [{{key, :_}, [], [key]}]
        key when is_tuple(key) -> [{{key, :_}, [], [{key}]}]
      end

    :ets.select(table_name, match_spec)
  end

  @impl true
  def init(module) do
    table_name = build_table_name(module)
    :ets.new(table_name, [:named_table, :public, read_concurrency: true])
    {:ok, table_name}
  end

  defp build_process_name(module), do: Module.concat(module, "Cache")
  defp build_table_name(module), do: Module.concat(module, "Cache")
end
