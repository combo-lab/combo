defmodule Combo.Router.Scope do
  @moduledoc false

  alias Combo.Router.ModuleAttr
  alias Combo.Router.Util

  defstruct path: [],
            alias: [],
            as: [],
            pipes: [],
            private: %{},
            assigns: %{},
            log: :debug

  def setup(router) do
    ModuleAttr.put(router, :scopes, [%__MODULE__{}])
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

  def add_pipe_through(router, new_pipes) do
    %{pipes: pipes} = get_top_scope(router)
    new_pipes = List.wrap(new_pipes)

    if pipe = Enum.find(new_pipes, &(&1 in pipes)) do
      raise ArgumentError,
            "duplicate pipe_through for #{inspect(pipe)}. " <>
              "A plug can only be used once inside a scoped pipe_through"
    end

    ModuleAttr.update(router, :scopes, fn [top | rest] ->
      [%{top | pipes: pipes ++ new_pipes} | rest]
    end)
  end

  @doc false
  def build_scope(router, args) do
    scope = get_top_scope(router)
    opts = normalize_scope_args(args)

    path =
      if path = Keyword.get(opts, :path) do
        path |> Util.validate_path!() |> Util.split_path()
      else
        []
      end

    path = scope.path ++ path
    alias = append_if_not_false(scope, opts, :alias, &Atom.to_string(&1))
    as = append_if_not_false(scope, opts, :as, & &1)

    pipes = scope.pipes
    private = Map.merge(scope.private, Keyword.get(opts, :private, %{}))
    assigns = Map.merge(scope.assigns, Keyword.get(opts, :assigns, %{}))
    log = Keyword.get(opts, :log, scope.log)

    %__MODULE__{
      path: path,
      alias: alias,
      as: as,
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

  defp append_if_not_false(scope, opts, key, fun) do
    case opts[key] do
      false -> []
      nil -> Map.fetch!(scope, key)
      other -> Map.fetch!(scope, key) ++ [fun.(other)]
    end
  end

  @doc false
  def push_scope(router, scope) do
    ModuleAttr.update(router, :scopes, fn scopes -> [scope | scopes] end)
  end

  @doc false
  def pop_scope(router) do
    ModuleAttr.update(router, :scopes, fn [_top | scopes] -> scopes end)
  end

  @doc false
  def expand_alias(router, alias) do
    scope = get_top_scope(router)
    Module.concat(scope.alias ++ [alias])
  end

  @doc false
  def get_top_scope(router) do
    router
    |> ModuleAttr.get(:scopes)
    |> hd()
  end
end
