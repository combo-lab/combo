defmodule Combo.Router.Route do
  @moduledoc false

  alias Combo.Router.ModuleAttr
  alias Combo.Router.Scope
  alias Combo.Router.Util

  defstruct [
    :line,
    :kind,
    :verb,
    :path,
    :plug,
    :plug_opts,
    :helper,
    :pipe_through,
    :private,
    :assigns,
    :metadata
  ]

  @type t :: %__MODULE__{
          line: non_neg_integer(),
          kind: :match | :forward,
          verb: atom(),
          path: String.t(),
          plug: atom(),
          plug_opts: atom(),
          helper: binary() | nil,
          pipe_through: [atom()],
          private: map(),
          assigns: map(),
          metadata: map()
        }

  def setup(module) do
    ModuleAttr.register(module, :routes, accumulate: true)
  end

  def add_route(kind, verb, path, plug, plug_opts, options) do
    route =
      quote do
        unquote(__MODULE__).build_route(
          __ENV__.line,
          __ENV__.module,
          unquote(kind),
          unquote(verb),
          unquote(path),
          unquote(plug),
          unquote(plug_opts),
          unquote(options)
        )
      end

    quote do
      ModuleAttr.put(__MODULE__, :routes, unquote(route))
    end
  end

  def build_route(line, module, kind, verb, path, plug, plug_opts, opts) do
    if not is_atom(plug) do
      raise ArgumentError,
            "routes expect a module plug as second argument, got: #{inspect(plug)}"
    end

    scope = Scope.get_top_scope(module)
    path = Util.validate_route_path!(path)

    alias? = Keyword.get(opts, :alias, true)
    as = Keyword.get_lazy(opts, :as, fn -> Combo.Naming.resource_name(plug, "Controller") end)
    private = Keyword.get(opts, :private, %{})
    assigns = Keyword.get(opts, :assigns, %{})
    log = Keyword.get(opts, :log, scope.log)

    if to_string(as) == "static" do
      raise ArgumentError,
            "`static` is a reserved route name derived from #{inspect(plug)} or `:as` option"
    end

    {path, plug, as, private, assigns} = join(scope, path, plug, alias?, as, private, assigns)

    metadata =
      opts
      |> Keyword.get(:metadata, %{})
      |> Map.put(:log, log)

    metadata =
      if kind == :forward do
        Map.put(metadata, :forward, validate_forward_path!(path))
      else
        metadata
      end

    build(
      line,
      kind,
      verb,
      path,
      plug,
      plug_opts,
      as,
      scope.pipes,
      private,
      assigns,
      metadata
    )
  end

  def build(
        line,
        kind,
        verb,
        path,
        plug,
        plug_opts,
        helper,
        pipe_through,
        private,
        assigns,
        metadata
      )
      when kind in [:match, :forward] and
             is_atom(verb) and
             is_binary(path) and
             is_atom(plug) and
             (is_binary(helper) or is_nil(helper)) and
             is_list(pipe_through) and
             is_map(private) and
             is_map(assigns) and
             is_map(metadata) do
    %__MODULE__{
      line: line,
      kind: kind,
      verb: verb,
      path: path,
      plug: plug,
      plug_opts: plug_opts,
      helper: helper,
      pipe_through: pipe_through,
      private: private,
      assigns: assigns,
      metadata: metadata
    }
  end

  @doc false
  def build_exprs(route) do
    method_match = build_method_match(route.verb)
    {path_info_match, path_info_binding} = build_path_info_match_and_binding(route)

    %{
      method_match: method_match,
      path_info_match: path_info_match,
      path_params: build_path_params(path_info_binding),
      prepare: build_prepare(route),
      dispatch: build_dispatch(route),
      binding: path_info_binding
    }
  end

  defp build_method_match(:*), do: Macro.var(:_method, nil)
  defp build_method_match(verb), do: verb |> to_string() |> String.upcase()

  defp build_path_info_match_and_binding(%__MODULE__{path: path} = route) do
    {_params, segments} =
      case route.kind do
        :match -> Plug.Router.Utils.build_path_match(path)
        :forward -> Plug.Router.Utils.build_path_match(path <> "/*_forward_path_info")
      end

    rewrite_segments(segments)
  end

  defp rewrite_segments(segments) do
    {segments, binding} =
      Macro.prewalk(segments, [], fn
        {name, _meta, nil}, binding when is_atom(name) and name != :_forward_path_info ->
          var = Macro.var(name, __MODULE__)
          {var, [{Atom.to_string(name), var} | binding]}

        other, binding ->
          {other, binding}
      end)

    {segments, Enum.reverse(binding)}
  end

  defp build_prepare(route) do
    {match_params, merged_params} = build_params_expr()
    {match_private, merged_private} = build_map_data_expr(:private, route.private)
    {match_assigns, merged_assigns} = build_map_data_expr(:assigns, route.assigns)

    match_all = match_params ++ match_private ++ match_assigns
    merged_all = merged_params ++ merged_private ++ merged_assigns

    quote do
      fn var!(conn, :conn), %{path_params: var!(path_params, :conn)} ->
        %{unquote_splicing(match_all)} = var!(conn, :conn)
        %{var!(conn, :conn) | unquote_splicing(merged_all)}
      end
    end
  end

  defp build_params_expr do
    params = Macro.var(:params, :conn)
    path_params = Macro.var(:path_params, :conn)

    merged_params =
      quote do
        unquote(__MODULE__).__merge_params__(
          unquote(params),
          unquote(path_params)
        )
      end

    {
      [{:params, params}],
      [{:params, merged_params}, {:path_params, path_params}]
    }
  end

  @doc false
  def __merge_params__(%Plug.Conn.Unfetched{}, path_params), do: path_params
  def __merge_params__(params, path_params), do: Map.merge(params, path_params)

  defp build_map_data_expr(_key, data) when data == %{} do
    {[], []}
  end

  defp build_map_data_expr(key, data) do
    var = Macro.var(key, :conn)
    merge = quote(do: Map.merge(unquote(var), unquote(Macro.escape(data))))
    {[{key, var}], [{key, merge}]}
  end

  defp build_dispatch(%__MODULE__{
         kind: :match,
         plug: plug,
         plug_opts: plug_opts
       }) do
    quote do
      {unquote(plug), unquote(Macro.escape(plug_opts))}
    end
  end

  defp build_dispatch(%__MODULE__{
         kind: :forward,
         plug: plug,
         plug_opts: plug_opts,
         metadata: metadata
       }) do
    quote do
      {
        Combo.Router.Forward,
        {unquote(metadata.forward), unquote(plug), unquote(Macro.escape(plug_opts))}
      }
    end
  end

  defp build_path_params(binding), do: {:%{}, [], binding}

  defp validate_forward_path!(path) do
    case Plug.Router.Utils.build_path_match(path) do
      {[], path_segments} ->
        path_segments

      _ ->
        raise ArgumentError,
              "dynamic segment \"#{path}\" not allowed when forwarding. Use a static path instead"
    end
  end

  defp join(scope, path, plug, alias?, as, private, assigns) do
    path = join_path(scope, path)
    plug = if alias?, do: join_alias(scope, plug), else: plug
    as = join_as(scope, as)
    private = Map.merge(scope.private, private)
    assigns = Map.merge(scope.assigns, assigns)
    {path, plug, as, private, assigns}
  end

  defp join_alias(scope, alias) when is_atom(alias) do
    Module.concat(scope.alias ++ [alias])
  end

  defp join_as(_scope, nil), do: nil
  defp join_as(scope, as) when is_atom(as) or is_binary(as), do: Enum.join(scope.as ++ [as], "_")

  defp join_path(scope, path) do
    "/" <> Enum.join(scope.path ++ String.split(path, "/", trim: true), "/")
  end
end
