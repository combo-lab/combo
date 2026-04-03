defmodule Combo.Router do
  defmodule NoRouteError do
    @moduledoc """
    Exception raised when no route is found.
    """
    defexception plug_status: 404, message: "no route found", conn: nil, router: nil

    def exception(opts) do
      conn = Keyword.fetch!(opts, :conn)
      router = Keyword.fetch!(opts, :router)
      path = conn.request_path

      %NoRouteError{
        message: "no route found for #{conn.method} #{path} (#{inspect(router)})",
        conn: conn,
        router: router
      }
    end
  end

  @moduledoc """
  Defines a router.

  The router provides a set of macros for defining routes which dispatch
  requests to specific plugs.

  ## Examples

      defmodule MyApp.Web.Router do
        use Combo.Router

        get "/health", MyApp.Web.HealthCheck, []
        get "/pages/:page", MyApp.Web.PageController, :show
      end

  ## Routes

  `get/3`, `post/3`, `put/3`, and other macros named after HTTP verbs are used
  to define routes. For example:

      get "/", MyApp.Web.PageController, :home

  defines a route that matches a `GET` request to `/` and dispatches the request
  to plug `MyApp.Web.PageController` with opts `:home`.

  ## Path parameters

  Path parameters capture values from the URL. There're several types of them:

    * segment parameters
    * partial segment parameters
    * catch-all parameters

  ### Segment parameters

  Segment parameters capture an entire path segment.

  Define them in the route path with `:` followed by a name. And, the captured
  values are strings, cast them yourself if you need other data types.

  For example:

      get "/pages/:page", MyApp.Web.PageController, :show

  When a request hits the route with the URL `"/pages/hello"`, the router
  populates `conn.path_params["page"]` with `"hello"`.

  ### Partial segment parameters

  Partial segment parameters capture a trailing portion from within a single
  path segment.

  Define them in the route path with `:` followed by a name. And, the captured
  values are strings, cast them yourself if you need other data types.

  For example:

      get "/user-:name", MyApp.Web.UserController, :show

  When a request hits the route with the URL `"/user-john"`, the router
  populates `conn.path_params["name"]` with `"john"`.

  ### Catch-all parameters

  Catch-all parameters capture one or more remaining path segments.

  Define them in the route path with `*` followed by a name. And, the captured
  values are a list of strings - one per path segment, cast them yourself if
  you need other data types.

  For example:

      get "/files/*path", MyApp.Web.FileController, :show

  When a request hits the route with the URL `"/files/images/logo.png"`, the
  router populates `conn.path_params["path"]` with `["images", "logo.png"]`.

  ### Accessing path parameters

  To access path parameters, use `conn.params` or `conn.path_params`.

  Or, pattern match directly in the controller's action:

      defmodule MyApp.Web.PageController do
        def show(conn, %{"page" => page}) do
          # ...
        end
      end

  ### Combining different types of path parameters

  All these types of path parameters can be combined, with the only restriction
  being that catch-all parameters must appear at the end.

  ## Ordering routes

  Routes are matched from top to bottom.

  For example, the request with the URL "/pages/hello" will never hit the
  second route, because it always hits the first route.

      get "/pages/:page", MyApp.Web.PageController, :show
      get "/pages/hello", MyApp.Web.PageController, :hello

  ## Route helpers

  Combo generates a `Helpers` module that provides helper functions for building
  paths or URLs from your routes.

  Helpers are automatically generated based on the module name of plug.
  For example, the route:

      get "/pages/:page", PageController, :show

  will generate the following helper:

      MyApp.Web.Router.Helpers.page_path(conn, :show, "hello")
      "/pages/hello"

      MyApp.Web.Router.Helpers.page_path(conn, :show, "hello", some: "query")
      "/pages/hello?some=query"

      MyApp.Web.Router.Helpers.page_url(conn, :show, "hello")
      "http://example.com/pages/hello"

      MyApp.Web.Router.Helpers.page_url(conn, :show, "hello", some: "query")
      "http://example.com/pages/hello?some=query"

  If the route contains catch-all parameters, parameters for those should be
  given as a list:

      MyApp.Web.Router.Helpers.file_path(conn, :show, ["images", "logo.png"])
      "/file/images/logo.png"

  The helper can also be customized with the `:as` option. Given the route:

      get "/pages/:page", PageController, :show, as: :special_page

  the helper will be:

      MyApp.Web.Router.Helpers.special_page_path(conn, :show, "hello")
      "/pages/hello"

  See the `Combo.Router.Helpers` for more information.

  ## Scopes

  It is very common to namespace routes under a scope. For example:

      scope "/", MyApp.Web do
        get "/users/:id", UserController, :show
        get "/posts/:id", PostController, :show
      end

  This syntax is convenient to use, since you don't have to repeat `MyApp.Web.`
  prefix on all routes.

  You can also use path parameters. For example:

      scope "/api/:version", MyApp.Web do
        get "/pages/:id", PageController, :show
      end

  Check `scope/2` for more information.

  ## Pipelines and plugs

  Once a request arrives at the router, it performs a series of transformations
  through pipelines until the request is dispatched to a desired route.

  > Pipelines are only invoked after a route is matched. If no route matches,
  > no pipeline is invoked.

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

  > We also imports `Combo.Conn` and `Plug.Conn` to help defining plugins.
  > `accepts/2` comes from `Combo.Conn`, while `fetch_session/2` comes from
  > `Plug.Conn`.

  ## Resources

  `Combo.Router` doesn't provide resources related macro that allows to generate
  "RESTful" routes to a given resource. For clarity, we recommend defining them
  explicitly.

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
  router. We can use it to list all routes included in the router.
  """

  alias Combo.Router.{Pipeline, Scope, Route, Helpers, Utils, ModuleAttr}

  @http_methods [:get, :post, :put, :patch, :delete, :options, :connect, :trace, :head]

  @doc false
  defmacro __using__(_) do
    quote do
      unquote(prelude())
      unquote(plug_impl())
      unquote(imports())
    end
  end

  defp prelude do
    quote do
      Pipeline.setup(__MODULE__)
      Scope.setup(__MODULE__)
      Route.setup(__MODULE__)

      @before_compile unquote(__MODULE__)
    end
  end

  defp plug_impl do
    quote location: :keep, generated: true do
      @behaviour Plug

      @impl true
      def init(opts) do
        opts
      end

      @impl true
      def call(conn, _opts) do
        %{method: method, path_info: encoded_path_info} = conn = put_router_info(conn)
        path_info = Enum.map(encoded_path_info, &URI.decode/1)

        case __match_route__(method, path_info) do
          {prepare, path_params, metadata, pipeline, dispatch} ->
            unquote(__MODULE__).__call__(conn, prepare, path_params, metadata, pipeline, dispatch)

          :error ->
            raise NoRouteError, conn: conn, router: __MODULE__
        end
      end

      defp put_router_info(conn) do
        Plug.Conn.merge_private(conn, [
          {:combo_router, __MODULE__},
          {{:combo_router, __MODULE__, :script_name}, conn.script_name}
        ])
      end

      defoverridable init: 1, call: 2
    end
  end

  defp imports do
    quote do
      import unquote(__MODULE__)
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    routes = env.module |> ModuleAttr.get(:routes) |> Enum.reverse()
    routes_with_exprs = Enum.map(routes, &{&1, Route.build_exprs(&1)})

    # check all plugs referenced by routes.
    checks =
      routes
      |> Enum.uniq_by(fn route -> {route.line, route.plug, route.plug_opts} end)
      |> Enum.map(&build_check/1)

    {matches, {pipe_throughs, _}} =
      Enum.map_reduce(routes_with_exprs, {[], %{}}, &build_match/2)

    helpers = Helpers.define(env, routes_with_exprs)

    match_catch_all =
      quote generated: true do
        @doc false
        def __match_route__(_method, _path_info), do: :error
      end

    forward_catch_all =
      quote generated: true do
        @doc false
        def __forward__(_), do: nil
      end

    quote do
      @doc false
      def __routes__, do: unquote(Macro.escape(routes))

      # It exists solely for compile-time checks. And, it is not meant to be called.
      @doc false
      def __checks__, do: unquote({:__block__, [], checks})

      @doc false
      def __helpers__, do: unquote(helpers)

      unquote(pipe_throughs)
      unquote(matches)
      unquote(match_catch_all)
      unquote(forward_catch_all)
    end
  end

  # TODO: check MFA better
  defp build_check(route) do
    %{line: line, plug: plug} = route
    module = plug
    function = :init
    arity = 1

    quote line: line do
      _ = &(unquote(module).unquote(function) / unquote(arity))
    end
  end

  defp build_match({route, expr}, {acc_pipes, known_pipes}) do
    %{
      method_match: method_match,
      path_info_match: path_info_match,
      path_params: path_params,
      prepare: prepare,
      dispatch: dispatch
    } = expr

    {pipe_name, acc_pipes, known_pipes} = build_match_pipes(route, acc_pipes, known_pipes)

    match =
      quote line: route.line do
        def __match_route__(unquote(method_match), unquote(path_info_match)) do
          {
            unquote(prepare),
            unquote(path_params),
            unquote(build_metadata(route, path_params)),
            &(unquote(Macro.var(pipe_name, __MODULE__)) / 1),
            unquote(dispatch)
          }
        end
      end

    {match, {acc_pipes, known_pipes}}
  end

  defp build_match_pipes(route, acc_pipes, known_pipes) do
    %{pipes: pipes} = route

    case known_pipes do
      %{^pipes => name} ->
        {name, acc_pipes, known_pipes}

      %{} ->
        id = map_size(known_pipes)
        name = :"__pipe_through#{id}__"
        acc_pipes = [build_pipes(name, pipes) | acc_pipes]
        known_pipes = Map.put(known_pipes, pipes, name)
        {name, acc_pipes, known_pipes}
    end
  end

  defp build_metadata(route, path_params) do
    route =
      Map.take(route, [
        :kind,
        :verb,
        :path,
        :path_info,
        :pipes,
        :plug,
        :plug_opts,
        :log,
        :metadata
      ])

    {:%{}, [],
     [
       conn: nil,
       route: Macro.escape(route),
       path_params: path_params
     ]}
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

  @doc false
  def __call__(
        %{private: %{combo_bypass: {router, pipes}}} = conn,
        prepare,
        path_params,
        _metadata,
        pipeline,
        _dispatch
      ) do
    conn = prepare.(conn, path_params)

    case pipes do
      :current ->
        pipeline.(conn)

      _ ->
        Enum.reduce(pipes, conn, fn pipe, acc -> apply(router, pipe, [acc, []]) end)
    end
  end

  def __call__(
        %{private: %{combo_bypass: :all}} = conn,
        prepare,
        path_params,
        _metadata,
        _pipeline,
        _dispatch
      ) do
    prepare.(conn, path_params)
  end

  def __call__(
        conn,
        prepare,
        path_params,
        metadata,
        pipeline,
        {plug, opts}
      ) do
    conn = prepare.(conn, path_params)
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
            exception = %{kind: :error, reason: e, stacktrace: __STACKTRACE__}
            new_metadata = %{conn: conn, exception: exception}
            metadata = Map.merge(metadata, new_metadata)
            :telemetry.execute([:combo, :router_dispatch, :exception], measurements, metadata)
            Plug.Conn.WrapperError.reraise(e)
        catch
          kind, reason ->
            measurements = %{duration: System.monotonic_time() - start}
            exception = %{kind: kind, reason: reason, stacktrace: __STACKTRACE__}
            new_metadata = %{conn: conn, exception: exception}
            metadata = Map.merge(metadata, new_metadata)
            :telemetry.execute([:combo, :router_dispatch, :exception], measurements, metadata)
            Plug.Conn.WrapperError.reraise(piped_conn, kind, reason, __STACKTRACE__)
        end
    end
  end

  # Pipeline #

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
    {plug, opts} = Utils.expand_plug_and_opts(plug, opts, __CALLER__)
    Pipeline.add_plug(plug, opts)
  end

  # Scope #

  @doc """
  Defines a scope.

  Scopes are for grouping routes under a common path prefix or a common module
  prefix.

  ## Examples

      scope path: "/api/v1", module: API.V1 do
        get "/pages/:id", PageController, :show
      end

  The generated route above will match on the path `"/api/v1/pages/:id"` and
  will dispatch requests to plug `API.V1.PageController` with opts `:show`.
  A named helper `api_v1_page_path` will also be generated.

  ## Options

    * `:path` - the path scope as a string.
    * `:module` - the module scope as a module name.
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
      the route is handled (which plug is called, what plug_opts are given,
      what parameters are available and which pipelines are used) and is
      separate from the plug level logging. To alter the plug log level, please
      see https://hexdocs.pm/combo/Combo.Logger.html#module-dynamic-log-level.

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
        Macro.prewalk(pipes, &Scope.expand_module(&1, __CALLER__))
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
      Scope.expand_module(__MODULE__, unquote(module))
    end
  end

  # Route #

  @doc """
  Defines a route based on an arbitrary HTTP method.

  Useful for defining routes not included in the built-in macros.

  The catch-all verb, `:*`, may also be used to match all HTTP methods.

  ## Options

    * `:scoped_module` - whether to apply the scoped module to the route.
      Defaults to `true`.
    * `:as` - the name as an atom or a string, to override the default naming
      for the route helpers.
      If `nil`, it will not generate route helpers for this route.
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
      Utils.expand_alias(plug, __CALLER__),
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
        Utils.expand_alias(plug, __CALLER__),
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
    {plug, plug_opts} = Utils.expand_plug_and_opts(plug, plug_opts, __CALLER__)
    router_opts = Keyword.put(router_opts, :as, nil)

    quote unquote: true, bind_quoted: [path: path, plug: plug] do
      unquote(Route.add_route(:forward, :*, path, plug, plug_opts, router_opts))
    end
  end

  # Others #

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
    path_info = Utils.split_path(path)
    route_info(router, method, path_info)
  end

  def route_info(router, method, path_info) when is_list(path_info) do
    with {_prepare, _path_params, metadata, _pipeline, _dispatch} <-
           router.__match_route__(method, path_info) do
      Map.delete(metadata, :conn)
    end
  end
end
