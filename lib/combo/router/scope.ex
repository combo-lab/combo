defmodule Combo.Router.Scope do
  @moduledoc false

  alias Combo.Router.ModuleAttr
  alias Combo.Router.Utils

  defstruct path_info: [],
            alias: [],
            as: [],
            pipes: [],
            private: %{},
            assigns: %{},
            log: :debug

  @doc false
  def setup(router) do
    ModuleAttr.put(router, :scopes, [%__MODULE__{}])
  end

  @doc false
  def add_scope(args, block) do
    scope =
      quote do
        unquote(__MODULE__).__build_scope__(__MODULE__, unquote(args))
      end

    quote do
      unquote(__MODULE__).__push_scope__(__MODULE__, unquote(scope))

      try do
        unquote(block)
      after
        unquote(__MODULE__).__pop_scope__(__MODULE__)
      end
    end
  end

  @doc false
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

  def __build_scope__(router, args) do
    scope = get_top_scope(router)
    opts = normalize_scope_args(args)

    path_info =
      if path = Keyword.get(opts, :path),
        do: path |> Utils.validate_path!() |> Utils.split_path(),
        else: []

    path_info = scope.path_info ++ path_info
    alias = append_value(scope.alias, Keyword.get(opts, :alias))
    as = append_value(scope.as, Keyword.get(opts, :as))
    pipes = scope.pipes
    private = Map.merge(scope.private, Keyword.get(opts, :private, %{}))
    assigns = Map.merge(scope.assigns, Keyword.get(opts, :assigns, %{}))
    log = Keyword.get(opts, :log, scope.log)

    %__MODULE__{
      path_info: path_info,
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

  defp append_value(values, value) do
    case value do
      false -> []
      nil -> values
      value -> values ++ [value]
    end
  end

  def __push_scope__(router, scope) do
    ModuleAttr.update(router, :scopes, fn scopes -> [scope | scopes] end)
  end

  def __pop_scope__(router) do
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
