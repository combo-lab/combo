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
    :hosts,
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
          hosts: [String.t()],
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
            "`static` is a reserved route prefix generated from #{inspect(plug)} or `:as` option"
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
      scope.hosts,
      plug,
      plug_opts,
      as,
      scope.pipes,
      private,
      assigns,
      metadata
    )
  end

  @doc "Used as a plug on forwarding."
  def init(opts), do: opts

  @doc "Used as a plug on forwarding."
  def call(%{path_info: path, script_name: script} = conn, {fwd_segments, plug, opts}) do
    new_path = path -- fwd_segments
    {base, ^new_path} = Enum.split(path, length(path) - length(new_path))
    conn = %{conn | path_info: new_path, script_name: script ++ base}
    conn = plug.call(conn, plug.init(opts))
    %{conn | path_info: path, script_name: script}
  end

  def build(
        line,
        kind,
        verb,
        path,
        hosts,
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
             is_list(hosts) and
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
      hosts: hosts,
      plug: plug,
      plug_opts: plug_opts,
      helper: helper,
      pipe_through: pipe_through,
      private: private,
      assigns: assigns,
      metadata: metadata
    }
  end

  @doc """
  Builds the compiled expressions of route.
  """
  def build_exprs(route) do
    {path, binding} = build_path_and_binding(route)

    %{
      verb: build_verb(route.verb),
      path: path,
      binding: binding,
      dispatch: build_dispatch(route),
      hosts: build_hosts(route.hosts),
      path_params: build_path_params(binding),
      prepare: build_prepare(route)
    }
  end

  defp build_path_and_binding(%__MODULE__{path: path} = route) do
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
        Combo.Router.Route,
        {unquote(metadata.forward), unquote(plug), unquote(Macro.escape(plug_opts))}
      }
    end
  end

  def build_hosts([]), do: [Plug.Router.Utils.build_host_match(nil)]

  def build_hosts([_ | _] = hosts) do
    for host <- hosts, do: Plug.Router.Utils.build_host_match(host)
  end

  defp build_verb(:*), do: Macro.var(:_verb, nil)
  defp build_verb(verb), do: verb |> to_string() |> String.upcase()

  defp build_path_params(binding), do: {:%{}, [], binding}

  defp build_prepare(route) do
    {match_params, merge_params} = build_params()
    {match_private, merge_private} = build_prepare_expr(:private, route.private)
    {match_assigns, merge_assigns} = build_prepare_expr(:assigns, route.assigns)

    match_all = match_params ++ match_private ++ match_assigns
    merge_all = merge_params ++ merge_private ++ merge_assigns

    quote do
      %{unquote_splicing(match_all)} = var!(conn, :conn)
      %{var!(conn, :conn) | unquote_splicing(merge_all)}
    end
  end

  defp build_params() do
    params = Macro.var(:params, :conn)
    path_params = Macro.var(:path_params, :conn)

    merge_params =
      quote(do: Combo.Router.Route.merge_params(unquote(params), unquote(path_params)))

    {
      [{:params, params}],
      [{:params, merge_params}, {:path_params, path_params}]
    }
  end

  defp build_prepare_expr(_key, data) when data == %{}, do: {[], []}

  defp build_prepare_expr(key, data) do
    var = Macro.var(key, :conn)
    merge = quote(do: Map.merge(unquote(var), unquote(Macro.escape(data))))
    {[{key, var}], [{key, merge}]}
  end

  @doc """
  Merges params from router.
  """
  def merge_params(%Plug.Conn.Unfetched{}, path_params), do: path_params
  def merge_params(params, path_params), do: Map.merge(params, path_params)

  defp validate_forward_path!(path) do
    case Plug.Router.Utils.build_path_match(path) do
      {[], path_segments} ->
        path_segments

      _ ->
        raise ArgumentError,
              "dynamic segment \"#{path}\" not allowed when forwarding. Use a static path instead"
    end
  end

  defp join(top, path, plug, alias?, as, private, assigns) do
    path = join_path(top, path)
    plug = if alias?, do: join_alias(top, plug), else: plug
    as = join_as(top, as)
    private = Map.merge(top.private, private)
    assigns = Map.merge(top.assigns, assigns)
    {path, plug, as, private, assigns}
  end

  defp join_alias(top, plug) when is_atom(plug) do
    case Atom.to_string(plug) do
      <<head, _::binary>> when head in ?a..?z -> plug
      plug -> Module.concat(top.alias ++ [plug])
    end
  end

  defp join_as(_top, nil), do: nil
  defp join_as(top, as) when is_atom(as) or is_binary(as), do: Enum.join(top.as ++ [as], "_")

  defp join_path(top, path) do
    "/" <> Enum.join(top.path ++ String.split(path, "/", trim: true), "/")
  end
end
