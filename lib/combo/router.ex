defmodule Combo.Router do
  defmodule NoRouteError do
    @moduledoc """
    Exception raised when no route is found.
    """
    defexception plug_status: 404, message: "no route found", conn: nil, router: nil

    def exception(opts) do
      conn = Keyword.fetch!(opts, :conn)
      router = Keyword.fetch!(opts, :router)
      path = "/" <> Enum.join(conn.path_info, "/")

      %NoRouteError{
        message: "no route found for #{conn.method} #{path} (#{inspect(router)})",
        conn: conn,
        router: router
      }
    end
  end

  defmodule MalformedURIError do
    @moduledoc """
    Exception raised when the URI is malformed on matching.
    """
    defexception [:message, plug_status: 400]
  end

  @moduledoc """
  Defines a router.

  The router provides a set of macros for defining routes which dispatch
  requests to specific controllers and actions.

  > Combo's router is extremely efficient, as it relies on pattern matching
  > for matching routes.

  ## Examples

      defmodule MyApp.Web.Router do
        use Combo.Router

        get "/pages/:page", MyApp.Web.PageController, :show
      end

  ## Routing

  `get/3`, `post/3`, `put/3`, and other macros named after HTTP verbs are used
  to define routes.

      get "/pages", MyApp.Web.PageController, :index

  defines a route matches a `GET` request to `/pages` and dispatches the request
  to the `index` action in `MyApp.Web.PageController`.

      get "/pages/:page", MyApp.Web.PageController, :show

  defines a route matches a `GET` request to `/pages/hello` and dispatches the
  request to the `show` action in `MyApp.Web.PageController` with
  `%{"page" => "hello"}` in `params`.

      defmodule MyApp.Web.PageController do
        def show(conn, params) do
          # %{"page" => "hello"} == params
        end
      end

  Partial and multiple segments can be matched. For example:

      get "/api/v:version/pages/:id", MyApp.Web.PageController, :show

  matches `/api/v1/pages/2` and puts `%{"version" => "1", "id" => "2"}` in
  `params`. Only the trailing part of a segment can be captured.

  Routes are matched from top to bottom. The second route here:

      get "/pages/:page", PageController, :show
      get "/pages/hello", PageController, :hello

  will never match `/pages/hello` because `/pages/:page` matches that first.

  Routes can use glob-like patterns to match trailing segments.

      get "/pages/*page", PageController, :show

  matches `/pages/hello/world` and puts the globbed segments in `params["page"]`.

      GET /pages/hello/world
      %{"page" => ["hello", "world"]} = params

  Globs cannot have prefixes nor suffixes, but can be mixed with variables:

      get "/pages/he:page/*rest", PageController, :show

  matches

      GET /pages/hello
      %{"page" => "llo", "rest" => []} = params

      GET /pages/hey/there/world
      %{"page" => "y", "rest" => ["there" "world"]} = params

  > #### Why the macros? {: .info}
  >
  > `Combo.Router` compiles all the routes to a single case-statement with
  > pattern matching rules, which is heavily optimized by the Erlang VM.
  >

  ### Route helpers

  Combo generates a module `Helpers` for your routes, which contains named
  helpers to help you generate and keep your routes up to date.

  Helpers are automatically generated based on the controller name.
  For example, the route:

      get "/pages/:page", PageController, :show

  will generate the following named helper:

      MyApp.Web.Router.Helpers.page_path(conn, :show, "hello")
      "/pages/hello"

      MyApp.Web.Router.Helpers.page_path(conn, :show, "hello", some: "query")
      "/pages/hello?some=query"

      MyApp.Web.Router.Helpers.page_url(conn, :show, "hello")
      "http://example.com/pages/hello"

      MyApp.Web.Router.Helpers.page_url(conn, :show, "hello", some: "query")
      "http://example.com/pages/hello?some=query"

  If the route contains glob-like patterns, parameters for those have to be
  given as list:

      MyApp.Web.Router.Helpers.page_path(conn, :show, ["hello", "world"])
      "/pages/hello/world"

  The named helper can also be customized with the `:as` option. Given
  the route:

      get "/pages/:page", PageController, :show, as: :special_page

  the named helper will be:

      MyApp.Web.Router.Helpers.special_page_path(conn, :show, "hello")
      "/pages/hello"

  See the `Combo.Router.Helpers` for more information.

  ## Scopes

  It is very common to namespace routes under a scope. For example:

      scope "/", MyApp.Web do
        get "/pages/:id", PageController, :show
      end

  The route above will dispatch to `MyApp.Web.PageController`. This syntax is
  convenient to use, since you don't have to repeat `MyApp.Web.` prefix on all
  routes.

  Like all paths, you can define dynamic segments that will be applied as
  parameters in the controller. For example:

      scope "/api/:version", MyApp.Web do
        get "/pages/:id", PageController, :show
      end

  The route above will match on the path `"/api/v1/pages/1"` and in the
  controller the `params` argument be a map like
  `%{"version" => "v1", "id" => "1"}`.

  Check `scope/2` for more information.

  ## Pipelines and plugs

  Once a request arrives at the Combo router, it performs a series of
  transformations through pipelines until the request is dispatched to a
  desired route.

  Such transformations are defined via plugs, as defined in the
  [Plug](https://github.com/elixir-plug/plug) specification.

  Once a pipeline is defined, it can be piped through per scope.

  For example:

      defmodule MyApp.Web.Router do
        use Combo.Router

        import Combo.Conn
        import Plug.Conn

        pipeline :browser do
          plug :accepts, ["html"]
          plug :fetch_session
        end

        scope "/" do
          pipe_through :browser

          # browser related routes
          # ...
        end
      end

  In the example above, we also imports `Combo.Conn` and `Plug.Conn` to
  help defining plugins. `accepts/2` comes from `Combo.Conn`, while
  `fetch_session/2` comes from `Plug.Conn`.

  Note that router pipelines are only invoked after a route is found.
  No plug is invoked in case no matches were found.

  ## Resources

  Combo doesn't provide resources related macro that allows to generate "RESTful"
  routes to a given resource. For clarity, we recommend defining routes explicitly.

  An example for resources:

      get "/users", UserController, :index
      get "/users/new", UserController, :new
      post "/users", UserController, :create
      get "/users/:id", UserController, :show
      get "/users/:id/edit", UserController, :edit
      patch "/users/:id", UserController, :update
      put "/users/:id", UserController, :update
      delete "/users/:id", UserController, :delete

  An example for singleton resources:

      get "/user/new", UserController, :new
      post "/user", UserController, :create
      get "/user", UserController, :show
      get "/user/edit", UserController, :edit
      patch "/user", UserController, :update
      put "/user", UserController, :update
      delete "/user", UserController, :delete

  ## Listing routes

  Combo ships with a `mix combo.routes` task that formats all routes in a given
  router. We can use it to verify all routes included in the router.
  """

  alias Combo.Router.{Pipeline, Scope, Route, Helpers, Util, ModuleAttr}

  @http_methods [:get, :post, :put, :patch, :delete, :options, :connect, :trace, :head]

  @doc false
  defmacro __using__(_) do
    quote do
      unquote(prelude())
      unquote(match_dispatch())
    end
  end

  defp prelude do
    quote do
      Pipeline.setup(__MODULE__)
      Scope.setup(__MODULE__)
      Route.setup(__MODULE__)

      import Combo.Router

      @before_compile Combo.Router
    end
  end

  @doc false
  def __call__(
        %{private: %{combo_router: router, combo_bypass: {router, pipes}}} = conn,
        metadata,
        prepare,
        pipeline,
        _
      ) do
    conn = prepare.(conn, metadata)

    case pipes do
      :current -> pipeline.(conn)
      _ -> Enum.reduce(pipes, conn, fn pipe, acc -> apply(router, pipe, [acc, []]) end)
    end
  end

  def __call__(%{private: %{combo_bypass: :all}} = conn, metadata, prepare, _, _) do
    prepare.(conn, metadata)
  end

  def __call__(conn, metadata, prepare, pipeline, {plug, opts}) do
    conn = prepare.(conn, metadata)
    start = System.monotonic_time()
    measurements = %{system_time: System.system_time()}
    metadata = %{metadata | conn: conn}
    :telemetry.execute([:combo, :router_dispatch, :start], measurements, metadata)

    case pipeline.(conn) do
      %Plug.Conn{halted: true} = halted_conn ->
        measurements = %{duration: System.monotonic_time() - start}
        metadata = %{metadata | conn: halted_conn}
        :telemetry.execute([:combo, :router_dispatch, :stop], measurements, metadata)
        halted_conn

      %Plug.Conn{} = piped_conn ->
        try do
          plug.call(piped_conn, plug.init(opts))
        else
          conn ->
            measurements = %{duration: System.monotonic_time() - start}
            metadata = %{metadata | conn: conn}
            :telemetry.execute([:combo, :router_dispatch, :stop], measurements, metadata)
            conn
        rescue
          e in Plug.Conn.WrapperError ->
            measurements = %{duration: System.monotonic_time() - start}
            new_metadata = %{conn: conn, kind: :error, reason: e, stacktrace: __STACKTRACE__}
            metadata = Map.merge(metadata, new_metadata)
            :telemetry.execute([:combo, :router_dispatch, :exception], measurements, metadata)
            Plug.Conn.WrapperError.reraise(e)
        catch
          kind, reason ->
            measurements = %{duration: System.monotonic_time() - start}
            new_metadata = %{conn: conn, kind: kind, reason: reason, stacktrace: __STACKTRACE__}
            metadata = Map.merge(metadata, new_metadata)
            :telemetry.execute([:combo, :router_dispatch, :exception], measurements, metadata)
            Plug.Conn.WrapperError.reraise(piped_conn, kind, reason, __STACKTRACE__)
        end
    end
  end

  defp match_dispatch do
    quote location: :keep, generated: true do
      @behaviour Plug

      @impl true
      def init(opts) do
        opts
      end

      @impl true
      def call(conn, _opts) do
        %{method: method, path_info: path_info} = conn = prepare(conn)
        path_info = Enum.map(path_info, &URI.decode/1)

        case __match_route__(method, path_info) do
          {metadata, prepare, pipeline, plug_opts} ->
            Combo.Router.__call__(conn, metadata, prepare, pipeline, plug_opts)

          :error ->
            raise NoRouteError, conn: conn, router: __MODULE__
        end
      end

      defp prepare(conn) do
        Plug.Conn.merge_private(conn, [
          {:combo_router, __MODULE__},
          {__MODULE__, conn.script_name}
        ])
      end

      defoverridable init: 1, call: 2
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    routes = env.module |> ModuleAttr.get(:routes) |> Enum.reverse()
    routes_with_exprs = Enum.map(routes, &{&1, Route.build_exprs(&1)})

    # check all controller modules and functions referenced by routes exist.
    checks =
      routes
      |> Enum.map(fn %{line: line, metadata: metadata, plug: plug} ->
        {line, Map.get(metadata, :mfa, {plug, :init, 1})}
      end)
      |> Enum.uniq()
      |> Enum.map(fn {line, {module, function, arity}} ->
        quote line: line, do: _ = &(unquote(module).unquote(function) / unquote(arity))
      end)

    helpers = Helpers.define(env, routes_with_exprs)

    {matches, {pipelines, _}} =
      Enum.map_reduce(routes_with_exprs, {[], %{}}, &build_match/2)

    match_catch_all =
      quote generated: true do
        @doc false
        def __match_route__(_method, _path_info) do
          :error
        end
      end

    forward_catch_all =
      quote generated: true do
        @doc false
        def __forward__(_), do: nil
      end

    quote do
      @doc false
      def __routes__, do: unquote(Macro.escape(routes))

      @doc false
      def __checks__, do: unquote({:__block__, [], checks})

      @doc false
      def __helpers__, do: unquote(helpers)

      unquote(pipelines)
      unquote(matches)
      unquote(match_catch_all)
      unquote(forward_catch_all)
    end
  end

  defp build_match({route, expr}, {acc_pipes, known_pipes}) do
    {pipe_name, acc_pipes, known_pipes} = build_match_pipes(route, acc_pipes, known_pipes)

    %{
      method_match: method_match,
      path_match: path_match,
      prepare: prepare,
      dispatch: dispatch,
      path_params: path_params
    } = expr

    clauses =
      quote line: route.line do
        def __match_route__(unquote(method_match), unquote(path_match)) do
          {unquote(build_metadata(route, path_params)),
           fn var!(conn, :conn), %{path_params: var!(path_params, :conn)} ->
             unquote(prepare)
           end, &(unquote(Macro.var(pipe_name, __MODULE__)) / 1), unquote(dispatch)}
        end
      end

    {clauses, {acc_pipes, known_pipes}}
  end

  defp build_match_pipes(route, acc_pipes, known_pipes) do
    %{pipe_through: pipe_through} = route

    case known_pipes do
      %{^pipe_through => name} ->
        {name, acc_pipes, known_pipes}

      %{} ->
        name = :"__pipe_through#{map_size(known_pipes)}__"
        acc_pipes = [build_pipes(name, pipe_through) | acc_pipes]
        known_pipes = Map.put(known_pipes, pipe_through, name)
        {name, acc_pipes, known_pipes}
    end
  end

  defp build_metadata(route, path_params) do
    %{
      path: path,
      plug: plug,
      plug_opts: plug_opts,
      pipe_through: pipe_through,
      metadata: metadata
    } = route

    pairs = [
      conn: nil,
      route: path,
      plug: plug,
      plug_opts: Macro.escape(plug_opts),
      path_params: path_params,
      pipe_through: pipe_through
    ]

    {:%{}, [], pairs ++ Macro.escape(Map.to_list(metadata))}
  end

  defp build_pipes(name, []) do
    quote do
      defp unquote(name)(conn), do: conn
    end
  end

  defp build_pipes(name, pipe_through) do
    plugs = pipe_through |> Enum.reverse() |> Enum.map(&{&1, [], true})
    opts = [init_mode: Combo.plug_init_mode(), log_on_halt: :debug]
    {conn, body} = Plug.Builder.compile(__ENV__, plugs, opts)

    quote do
      defp unquote(name)(unquote(conn)), do: unquote(body)
    end
  end

  @doc """
  Defines a pipeline.

  Pipelines are defined at the router root and can be used from any scope.

  ## Examples

      pipeline :api do
        plug :put_current_user
        plug :dispatch
      end

  A scope can use this pipeline as:

      scope "/" do
        pipe_through :api
      end

  See `pipe_through/1` for more information.
  """
  defmacro pipeline(name, [do: block] = _do_block) when is_atom(name) do
    with imports = __CALLER__.macros ++ __CALLER__.functions,
         {mod, _} <- Enum.find(imports, fn {_, imports} -> {name, 2} in imports end) do
      raise ArgumentError,
            "cannot define pipeline named #{inspect(name)} " <>
              "because there is an import from #{inspect(mod)} with the same name"
    end

    Pipeline.add_pipeline(name, block)
  end

  @doc """
  Defines a plug inside a pipeline.

  See `pipeline/2` for more information.
  """
  defmacro plug(plug, opts \\ []) do
    {plug, opts} = Util.expand_plug_and_opts(plug, opts, __CALLER__)
    Pipeline.add_plug(plug, opts)
  end

  @doc """
  Defines a scope.

  Scopes are for grouping routes.

  ## Examples

      scope path: "/api/v1", module: API.V1 do
        get "/pages/:id", PageController, :show
      end

  The generated route above will match on the path `"/api/v1/pages/:id"` and
  will dispatch to `:show` action in `API.V1.PageController`. A named helper
  `api_v1_page_path` will also be generated.

  ## Options

    * `:path` - the path scope as a string.
    * `:module` - the module scope as an atom.
      When set to `false`, it resets all nested `:module` options.
    * `:as` - the route naming scope as a string or an atom.
      When set to `false`, it resets all nested `:as` options.
    * `:private` - the private data as a map to merge into the connection when
      a route matches.
    * `:assigns` - the data as a map to merge into the connection when a route
      matches.
    * `:log` - the level to log the route dispatching under, may be set to
      `false`.
      Defaults to `:debug`. Route dispatching contains information about how
      the route is handled (which controller action is called, what parameters
      are available and which pipelines are used) and is separate from the plug
      level logging. To alter the plug log level, please see
      https://hexdocs.pm/combo/Combo.Logger.html#module-dynamic-log-level.

  ## Shortcuts

  A scope can also be defined with shortcuts.

      # specify path and module
      scope "/api/v1", API.V1 do
        get "/pages/:id", PageController, :show
      end

      # specify path, module and options
      scope "/api/v1", API.V1, as: :api, do
        get "/pages/:id", PageController, :show
      end

      # specify path only
      scope "/api/v1" do
        get "/pages/:id", API.V1.PageController, :show
      end

      # specify path and options
      scope "/api/v1", as: :api, do
        get "/pages/:id", API.V1.PageController, :show
      end

      # specify module only
      scope API.V1 do
        get "/pages/:id", PageController, :show
      end

      # specify module and options
      scope API.V1, as: :api, do
        get "/pages/:id", PageController, :show
      end

  """
  defmacro scope(arg, [do: block] = _do_block) do
    Scope.add_scope([arg], block)
  end

  @doc """
  See `scope/2` for more information.
  """
  defmacro scope(arg1, arg2, [do: block] = _do_block) do
    Scope.add_scope([arg1, arg2], block)
  end

  @doc """
  See `scope/2` for more information.
  """
  defmacro scope(arg1, arg2, arg3, [do: block] = _do_block) do
    Scope.add_scope([arg1, arg2, arg3], block)
  end

  @doc """
  Defines a list of plugs and pipelines to apply to the connection.

  Plugs are specified using the atom name of function plugs.
  Pipelines are specified using the atom name of pipelines. See `pipeline/2`
  for more information.

  ## Examples

      pipe_through [:browser, :require_authenticated_user]

  ## Multiple invocations

  `pipe_through/1` can be invoked multiple times within the same scope. Each
  invocation appends new plugs and pipelines, which are applied to all routes
  **after** the `pipe_through/1` invocation. For example:

      scope "/" do
        pipe_through [:browser]
        get "/", HomeController, :index

        pipe_through [:require_authenticated_user]
        get "/settings", UserController, :edit
      end

  In the example above, `/` applies `:browser` only, while `/settings` applies
  both `:browser` and `:require_authenticated_user`. To avoid confusion, we
  recommend to use a single `pipe_through` at the top of each scope:

      scope "/" do
        pipe_through [:browser]
        get "/", HomeController, :index
      end

      scope "/" do
        pipe_through [:browser, :require_authenticated_user]
        get "/settings", UserController, :edit
      end

  """
  defmacro pipe_through(pipes) do
    pipes =
      if Combo.plug_init_mode() == :runtime and Macro.quoted_literal?(pipes) do
        Macro.prewalk(pipes, &Scope.expand_alias(&1, __CALLER__))
      else
        pipes
      end

    quote do
      if pipeline = ModuleAttr.get(__MODULE__, :pipeline_plugs) do
        raise "cannot pipe_through inside a pipeline"
      else
        Scope.add_pipe_through(__MODULE__, unquote(pipes))
      end
    end
  end

  @doc """
  Expands a module with the current scope's module.

  It's useful when you need to reference scoped modules in other contexts,
  such as passing them as options.

  ## Examples

    scope "/admin", Admin do
      # UserController is expanded to Admin.UserController
      get "/users", ProxyPlug, handler: scoped_module(UserController)
    end

  """
  defmacro scoped_module(module) do
    quote do
      Scope.expand_alias(__MODULE__, unquote(module))
    end
  end

  @doc """
  Defines a route based on an arbitrary HTTP method.

  Useful for defining routes not included in the built-in macros.

  The catch-all verb, `:*`, may also be used to match all HTTP methods.

  ## Options

    * `:scoped_module` - whether to apply the scoped module to the route.
      Defaults to `true`.
    * `:as` - the name as an atom or a string, to override the default naming
      for the named route helpers.
      If `nil`, it will not generate named route helpers for this route.
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

      # match the GET method
      match :get, "/events/:id", EventController, :get

      # match all methods
      match :*, "/any", CatchAllController, :any

  """
  defmacro match(verb, path, plug, plug_opts, options \\ []) do
    Route.add_route(
      :match,
      verb,
      path,
      Util.expand_alias(plug, __CALLER__),
      plug_opts,
      options
    )
  end

  for verb <- @http_methods do
    @doc """
    Defines a route to handle a #{verb} request to the given path.

        #{verb} "/events/:id", EventController, :action

    See `match/5` for options.

    #{if verb == :head do
      """
      ## Compatibility with `Plug.Head`

      By default, Combo apps include `Plug.Head` in their endpoint, which converts
      HEAD requests into regular GET requests. Therefore, if you intend to use
      `head/4` in your router, you need to move `Plug.Head` to inside your router
      in a way it does not conflict with the paths given to `head/4`.
      """
    end}
    """
    defmacro unquote(verb)(path, plug, plug_opts, options \\ []) do
      Route.add_route(
        :match,
        unquote(verb),
        path,
        Util.expand_alias(plug, __CALLER__),
        plug_opts,
        options
      )
    end
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
      unquote(Route.add_route(:forward, :*, path, plug, plug_opts, router_opts))
    end
  end

  @doc """
  Returns all routes information from the given router.
  """
  def routes(router) do
    router.__routes__()
  end

  @doc """
  Returns the compile-time route info and runtime path params for a request.

  The `path` can be either a string or the `path_info` segments.

  A map of metadata is returned with the following keys:

    * `:log` - the configured log level, such as `:debug`.
    * `:path_params` - the map of runtime path params.
    * `:pipe_through` - the list of pipelines for the route's scope, such as `[:browser]`.
    * `:plug` - the plug to dispatch the route to, such as `MyApp.Web.PostController`.
    * `:plug_opts` - the options to pass when calling the plug, such as `:index`.
    * `:route` - the string route pattern, such as `"/posts/:id"`.

  ## Examples

      iex> Combo.Router.route_info(MyApp.Web.Router, "GET", "/posts/123")
      %{
        log: :debug,
        path_params: %{"id" => "123"},
        pipe_through: [:browser],
        plug: MyApp.Web.PostController,
        plug_opts: :show,
        route: "/posts/:id",
      }

      iex> Combo.Router.route_info(MyRouter, "GET", "/not-exists")
      :error

  """
  @doc type: :reflection
  def route_info(router, method, path) when is_binary(path) do
    path_info = for segment <- String.split(path, "/"), segment != "", do: segment
    route_info(router, method, path_info)
  end

  def route_info(router, method, path_info) when is_list(path_info) do
    with {metadata, _prepare, _pipeline, {_plug, _opts}} <-
           router.__match_route__(method, path_info) do
      Map.delete(metadata, :conn)
    end
  end

  @doc false
  def __formatted_routes__(router) do
    Enum.flat_map(router.__routes__(), fn route ->
      Code.ensure_loaded(route.plug)

      if function_exported?(route.plug, :formatted_routes, 1) do
        route.plug_opts
        |> route.plug.formatted_routes()
        |> Enum.map(fn nested_route ->
          route = %{
            route
            | path: Path.join(route.path, nested_route.path),
              verb: nested_route.verb
          }

          Map.put(route, :label, nested_route.label)
        end)
      else
        plug =
          case route.metadata[:mfa] do
            {module, _, _} -> module
            _ -> route.plug
          end

        label = "#{inspect(plug)} #{inspect(route.plug_opts)}"

        [
          %{
            helper: route.helper,
            verb: route.verb,
            path: route.path,
            label: label
          }
        ]
      end
    end)
  end
end
