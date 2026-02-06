defmodule Combo.Router.Scope do
  @moduledoc false

  alias Combo.Router.ModuleAttr
  alias Combo.Router.Util

  defstruct path: [],
            alias: [],
            as: [],
            pipes: [],
            hosts: [],
            private: %{},
            assigns: %{},
            log: :debug

  def setup(module) do
    ModuleAttr.put(module, :scopes, [%__MODULE__{}])
  end

  def add_scope(args, block) do
    scope =
      quote do
        unquote(__MODULE__).build_scope(__MODULE__, unquote(args))
      end

    quote do
      unquote(__MODULE__).push_scope(__MODULE__, unquote(scope))

      try do
        unquote(block)
      after
        unquote(__MODULE__).pop_scope(__MODULE__)
      end
    end
  end

  def add_pipe_through(module, new_pipes) do
    %{pipes: pipes} = get_top_scope(module)
    new_pipes = List.wrap(new_pipes)

    if pipe = Enum.find(new_pipes, &(&1 in pipes)) do
      raise ArgumentError,
            "duplicate pipe_through for #{inspect(pipe)}. " <>
              "A plug can only be used once inside a scoped pipe_through"
    end

    ModuleAttr.update(module, :scopes, fn [top | rest] ->
      [%{top | pipes: pipes ++ new_pipes} | rest]
    end)
  end

  @doc false
  def build_scope(module, args) do
    scope = get_top_scope(module)
    opts = normalize_scope_args(args)

    path =
      if path = Keyword.get(opts, :path) do
        path |> Util.validate_route_path!() |> String.split("/", trim: true)
      else
        []
      end

    path = scope.path ++ path
    alias = append_if_not_false(scope, opts, :alias, &Atom.to_string(&1))
    as = append_if_not_false(scope, opts, :as, & &1)

    hosts =
      case Keyword.fetch(opts, :host) do
        {:ok, val} -> validate_hosts!(val)
        :error -> scope.hosts
      end

    pipes = scope.pipes
    private = Map.merge(scope.private, Keyword.get(opts, :private, %{}))
    assigns = Map.merge(scope.assigns, Keyword.get(opts, :assigns, %{}))
    log = Keyword.get(opts, :log, scope.log)

    %__MODULE__{
      path: path,
      alias: alias,
      as: as,
      hosts: hosts,
      pipes: pipes,
      private: private,
      assigns: assigns,
      log: log
    }
  end

  defp normalize_scope_args([path]) when is_binary(path) do
    [path: path]
  end

  defp normalize_scope_args([alias]) when is_atom(alias) do
    [alias: alias]
  end

  defp normalize_scope_args([opts]) when is_list(opts) do
    opts
  end

  defp normalize_scope_args([path, alias]) when is_binary(path) and is_atom(alias) do
    [path: path, alias: alias]
  end

  defp normalize_scope_args([path, opts]) when is_binary(path) and is_list(opts) do
    Keyword.put(opts, :path, path)
  end

  defp normalize_scope_args([alias, opts]) when is_atom(alias) and is_list(opts) do
    Keyword.put(opts, :alias, alias)
  end

  defp normalize_scope_args([path, alias, opts])
       when is_binary(path) and is_atom(alias) and is_list(opts) do
    opts
    |> Keyword.put(:path, path)
    |> Keyword.put(:alias, alias)
  end

  defp validate_hosts!(nil), do: []

  defp validate_hosts!(host) when is_binary(host), do: [host]

  defp validate_hosts!(hosts) when is_list(hosts) do
    for host <- hosts do
      if not is_binary(host), do: raise_invalid_host!(host)
      host
    end
  end

  defp validate_hosts!(invalid), do: raise_invalid_host!(invalid)

  defp raise_invalid_host!(value) do
    raise ArgumentError,
          """
          expected router scope :host to be compile-time string or list of strings, \
          got: #{inspect(value)}\
          """
  end

  defp append_if_not_false(scope, opts, key, fun) do
    case opts[key] do
      false -> []
      nil -> Map.fetch!(scope, key)
      other -> Map.fetch!(scope, key) ++ [fun.(other)]
    end
  end

  @doc false
  def push_scope(module, scope) do
    ModuleAttr.update(module, :scopes, fn scopes -> [scope | scopes] end)
  end

  @doc false
  def pop_scope(module) do
    ModuleAttr.update(module, :scopes, fn [_top | scopes] -> scopes end)
  end

  @doc false
  def expand_alias(module, alias) do
    join_alias(get_top_scope(module), alias)
  end

  @doc """
  Returns the full path in the current router scope.
  """
  def full_path(module, path) do
    split_path = String.split(path, "/", trim: true)
    prefix = get_top_scope(module).path

    cond do
      prefix == [] -> path
      split_path == [] -> "/" <> Enum.join(prefix, "/")
      true -> "/" <> Path.join(get_top_scope(module).path ++ split_path)
    end
  end

  defp join_alias(scope, plug) when is_atom(plug) do
    case Atom.to_string(plug) do
      <<head, _::binary>> when head in ?a..?z -> plug
      plug -> Module.concat(scope.alias ++ [plug])
    end
  end

  @doc false
  def get_top_scope(module) do
    module
    |> ModuleAttr.get(:scopes)
    |> hd()
  end
end
