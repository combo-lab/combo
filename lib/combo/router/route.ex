defmodule Combo.Router.Route do
  @moduledoc false

  alias Combo.Router.ModuleAttr
  alias Combo.Router.Scope
  alias Combo.Router.Util

  @http_methods [:get, :post, :put, :patch, :delete, :options, :connect, :trace, :head]

  @doc false
  def setup(module) do
    ModuleAttr.register(module, :routes, accumulate: true)
  end

  @doc """
  Defines a route based on an arbitrary HTTP method.

  Useful for defining routes not included in the built-in macros.

  The catch-all verb, `:*`, may also be used to match all HTTP methods.

  ## Options

    * `:alias` - whether to apply the scope alias to the route.
      Defaults to `true`.
    * `:as` - the route name as an atom or a string.
      It's used for generating named route helpers. If `nil`, it does not generate
      named route helpers.
    * `:private` - the private data as a map to merge into the connection when
      a route matches.
      Default to `%{}`.
    * `:assigns` - the data as a map to merge into the connection when a route
      matches.
      Default to `%{}`.
    * `:log` - the level to log the route dispatching under.
      Defaults to `:debug`. Can be set to `false` to disable the logging.
      Route dispatching logging contains information about how the route is
      handled (which controller action is called, what parameters are available
      and which pipelines are used).
      It is separated from the plug level logging. To alter the plug log level,
      please see https://hexdocs.pm/combo/Combo.Logger.html#module-dynamic-log-level.
    * `:metadata` - the map of metadata used by the telemetry events and returned
      by `route_info/4`. The `:mfa` field is used by telemetry to print logs
      and by the router to emit compile time checks. Custom fields may be added.

  ## Examples

      # match the MOVE method, which is an extension specific to WebDAV
      match :move, "/events/:id", EventController, :move

      # match all HTTP methods
      match :*, "/any", CatchAllController, :any

  """
  defmacro match(verb, path, plug, plug_opts, options \\ []) do
    add_route(:match, verb, path, Util.expand_alias(plug, __CALLER__), plug_opts, options)
  end

  @doc """
  Forwards a request at the given path to a plug.

  This is commonly used to forward all subroutes to another Plug.
  For example:

      forward "/admin", SomeLib.AdminDashboard

  The above will allow `SomeLib.AdminDashboard` to handle `/admin`,
  `/admin/foo`, `/admin/bar/baz`, and so on. Furthermore,
  `SomeLib.AdminDashboard` does not to be aware of the prefix it
  is mounted in. From its point of view, the routes above are simply
  handled as `/`, `/foo`, and `/bar/baz`.

  A common use case for `forward` is for sharing a router between
  applications or breaking a big router into smaller ones.
  However, in other for route generation to route accordingly, you
  can only forward to a given `Combo.Router` once.

  The router pipelines will be invoked prior to forwarding the
  connection.

  ## Examples

      scope "/", MyApp do
        pipe_through [:browser, :admin]

        forward "/admin", SomeLib.AdminDashboard
        forward "/api", ApiRouter
      end

  """
  defmacro forward(path, plug, plug_opts \\ [], router_opts \\ []) do
    {plug, plug_opts} = Util.expand_plug_and_opts(plug, plug_opts, __CALLER__)
    router_opts = Keyword.put(router_opts, :as, nil)

    quote unquote: true, bind_quoted: [path: path, plug: plug] do
      unquote(add_route(:forward, :*, path, plug, plug_opts, router_opts))
    end
  end

  def add_route(kind, verb, path, plug, plug_opts, options) do
    quote do
      ModuleAttr.put(
        __MODULE__,
        :routes,
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
      )
    end
  end

  @doc """
  The `Combo.Router.Route` struct. It stores:

    * `:line` - the line the route was defined.
    * `:kind` - the kind of route as an atom, either `:match` or `:forward`.
    * `:verb` - the HTTP verb as an atom, such as `:get`, `:post` or `:*`.
    * `:path` - the normalized path as a string.
    * `:hosts` - the list of request hosts or host prefixes.
    * `:plug` - the plug module.
    * `:plug_opts` - the plug options.
    * `:helper` - the name of the helper as a string, or `nil`.
    * `:pipe_through` - the pipeline names as a list of atoms.
    * `:private` - the private route info as a map.
    * `:assigns` - the route info as a map.
    * `:metadata` - the metadata as a map, used on telemetry events and route info.

  """
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

  def build_route(line, module, kind, verb, path, plug, plug_opts, opts) do
    if not is_atom(plug) do
      raise ArgumentError,
            "routes expect a module plug as second argument, got: #{inspect(plug)}"
    end

    top = Scope.get_top_scope(module)
    path = Util.validate_route_path!(path)

    alias? = Keyword.get(opts, :alias, true)
    as = Keyword.get_lazy(opts, :as, fn -> Combo.Naming.resource_name(plug, "Controller") end)
    private = Keyword.get(opts, :private, %{})
    assigns = Keyword.get(opts, :assigns, %{})
    log = Keyword.get(opts, :log, top.log)

    if to_string(as) == "static" do
      raise ArgumentError,
            "`static` is a reserved route prefix generated from #{inspect(plug)} or `:as` option"
    end

    {path, plug, as, private, assigns} = join(top, path, plug, alias?, as, private, assigns)

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

    Combo.Router.Route.build(
      line,
      kind,
      verb,
      path,
      top.hosts,
      plug,
      plug_opts,
      as,
      top.pipes,
      private,
      assigns,
      metadata
    )
  end

  # ====================

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

  # ========
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
