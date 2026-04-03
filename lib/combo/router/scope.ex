defmodule Combo.Router.Scope do
  @moduledoc false

  alias Combo.Router.ModuleAttr
  alias Combo.Router.Utils

  @struct_keys [:path, :path_info, :module, :as, :pipes, :private, :assigns, :log]
  @enforce_keys @struct_keys
  defstruct @struct_keys

  @type t :: %__MODULE__{
          path: String.t(),
          path_info: [String.t()],
          module: [module()],
          as: [atom() | String.t()],
          pipes: [atom()],
          private: map(),
          assigns: map(),
          log: Logger.level() | mfa() | false
        }

  @doc false
  def setup(router) do
    scope = %__MODULE__{
      path: "/",
      path_info: [],
      module: [],
      as: [],
      pipes: [],
      private: %{},
      assigns: %{},
      log: :debug
    }

    ModuleAttr.put(router, :scopes, [scope])
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
      opts
      |> Keyword.get(:path, "/")
      |> Utils.validate_path!()
      |> Utils.split_path()
      |> then(&Kernel.++(scope.path_info, &1))

    path = Utils.build_path(path_info)
    module = append_value(scope.module, Keyword.get(opts, :module))
    as = append_value(scope.as, Keyword.get(opts, :as))
    pipes = scope.pipes
    private = Map.merge(scope.private, Keyword.get(opts, :private, %{}))
    assigns = Map.merge(scope.assigns, Keyword.get(opts, :assigns, %{}))
    log = Keyword.get(opts, :log, scope.log)

    %__MODULE__{
      path: path,
      path_info: path_info,
      module: module,
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

  defp normalize_scope_args([module]) when is_atom(module) do
    [module: module]
  end

  defp normalize_scope_args([opts]) when is_list(opts) do
    opts
  end

  defp normalize_scope_args([path, module]) when is_binary(path) and is_atom(module) do
    [path: path, module: module]
  end

  defp normalize_scope_args([path, opts]) when is_binary(path) and is_list(opts) do
    Keyword.put(opts, :path, path)
  end

  defp normalize_scope_args([module, opts]) when is_atom(module) and is_list(opts) do
    Keyword.put(opts, :module, module)
  end

  defp normalize_scope_args([path, module, opts])
       when is_binary(path) and is_atom(module) and is_list(opts) do
    opts
    |> Keyword.put(:path, path)
    |> Keyword.put(:module, module)
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
  def expand_module(router, module) do
    scope = get_top_scope(router)
    Module.concat(scope.module ++ [module])
  end

  @doc false
  def get_top_scope(router) do
    router
    |> ModuleAttr.get(:scopes)
    |> hd()
  end
end
