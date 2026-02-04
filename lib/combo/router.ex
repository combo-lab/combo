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

  The router provides a set of macros for generating routes that dispatch to
  specific controllers and actions. Those macros are named after HTTP verbs.
  For example:

      defmodule MyApp.Web.Router do
        use Combo.Router

        get "/pages/:page", MyApp.Web.PageController, :show
      end

  Combo's router is extremely efficient, as it relies on pattern matching for
  matching routes.

  ## Routing

  `get/3`, `post/3`, `put/3`, and other macros named after HTTP verbs are used
  to create routes.

      get "/pages", PageController, :index

  creates a route matches a `GET` request to `/pages` and dispatches the request
  to the `index` action in `PageController`.

      get "/pages/:page", PageController, :show

  create a route matches a `GET` request to `/pages/hello` and dispatches the
  request to the `show` action in `PageController` with `%{"page" => "hello"}`
  in `params`.

      defmodule PageController do
        def show(conn, params) do
          # %{"page" => "hello"} == params
        end
      end

  Partial and multiple segments can be matched. For example:

      get "/api/v:version/pages/:id", PageController, :show

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

  ## Scopes and Resources

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

  Combo also provides a `resources/4` macro that allows to generate "RESTful"
  routes to a given resource:

      defmodule MyApp.Web.Router do
        use Combo.Router

        resources "/pages", PageController, only: [:show]
        resources "/users", UserController, except: [:delete]
      end

  Check `scope/2` and `resources/4` for more information.

  ## Listing routes

  Combo ships with a `mix combo.routes` task that formats all routes in a given
  router. We can use it to verify all routes included in the router.

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
  """

  alias Combo.Router.{Context, Route, Scope, Resource, Helpers, Util}

  @http_methods [:get, :post, :put, :patch, :delete, :options, :connect, :trace, :head]

  @doc false
  defmacro __using__(_) do
    quote do
      unquote(prelude())
      unquote(defs())
      unquote(match_dispatch())
    end
  end

  defp prelude do
    quote do
      Module.register_attribute(__MODULE__, :combo_routes, accumulate: true)

      import Combo.Router
      import Combo.Router.Pipeline, only: [pipeline: 2, plug: 1, plug: 2]
      import Combo.Router.Scope, only: [scope: 2, scope: 3, scope: 4]

      Combo.Router.Pipeline.init(__MODULE__)
      Combo.Router.Scope.init(__MODULE__)

      @before_compile unquote(__MODULE__)
    end
  end

  # Because those macros are executed multiple times, we end-up generating a
  # huge scope that drastically affects compilation. We work around it by
  # defining those functions only once and calling it over and over again.
  defp defs do
    quote unquote: false do
      var!(add_resources, Combo.Router) = fn resource ->
        path = resource.path
        controller = resource.controller
        opts = resource.route

        if resource.singleton do
          Enum.each(resource.actions, fn
            :new ->
              get path <> "/new", controller, :new, opts

            :create ->
              post path, controller, :create, opts

            :show ->
              get path, controller, :show, opts

            :edit ->
              get path <> "/edit", controller, :edit, opts

            :update ->
              patch path, controller, :update, opts
              put path, controller, :update, Keyword.put(opts, :as, nil)

            :delete ->
              delete path, controller, :delete, opts
          end)
        else
          param = resource.param

          Enum.each(resource.actions, fn
            :index ->
              get path, controller, :index, opts

            :new ->
              get path <> "/new", controller, :new, opts

            :create ->
              post path, controller, :create, opts

            :show ->
              get path <> "/:" <> param, controller, :show, opts

            :edit ->
              get path <> "/:" <> param <> "/edit", controller, :edit, opts

            :update ->
              patch path <> "/:" <> param, controller, :update, opts
              put path <> "/:" <> param, controller, :update, Keyword.put(opts, :as, nil)

            :delete ->
              delete path <> "/:" <> param, controller, :delete, opts
          end)
        end
      end
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

      @doc """
      Callback required by Plug that initializes the router.
      """
      def init(opts) do
        opts
      end

      @doc """
      Callback invoked by Plug on every request for matching routes.
      """
      def call(conn, _opts) do
        %{method: method, path_info: path_info, host: host} = conn = prepare(conn)
        decoded = Enum.map(path_info, &URI.decode/1)

        case __match_route__(decoded, method, host) do
          {metadata, prepare, pipeline, plug_opts} ->
            Combo.Router.__call__(conn, metadata, prepare, pipeline, plug_opts)

          :error ->
            raise NoRouteError, conn: conn, router: __MODULE__
        end
      end

      defoverridable init: 1, call: 2
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    routes = env.module |> Module.get_attribute(:combo_routes) |> Enum.reverse()
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
        def __match_route__(_path_info, _verb, _host) do
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

      defp prepare(conn) do
        Plug.Conn.merge_private(conn, [
          {:combo_router, __MODULE__},
          {__MODULE__, conn.script_name}
        ])
      end

      unquote(pipelines)
      unquote(matches)
      unquote(match_catch_all)
      unquote(forward_catch_all)
    end
  end

  defp build_match({route, expr}, {acc_pipes, known_pipes}) do
    {pipe_name, acc_pipes, known_pipes} = build_match_pipes(route, acc_pipes, known_pipes)

    %{
      prepare: prepare,
      dispatch: dispatch,
      verb: verb,
      path_params: path_params,
      hosts: hosts,
      path: path
    } = expr

    clauses =
      for host <- hosts do
        quote line: route.line do
          def __match_route__(unquote(path), unquote(verb), unquote(host)) do
            {unquote(build_metadata(route, path_params)),
             fn var!(conn, :conn), %{path_params: var!(path_params, :conn)} ->
               unquote(prepare)
             end, &(unquote(Macro.var(pipe_name, __MODULE__)) / 1), unquote(dispatch)}
          end
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
    add_route(:match, verb, path, expand_alias(plug, __CALLER__), plug_opts, options)
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
      add_route(:match, unquote(verb), path, expand_alias(plug, __CALLER__), plug_opts, options)
    end
  end

  defp add_route(kind, verb, path, plug, plug_opts, options) do
    quote do
      @combo_routes Scope.route(
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
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:init, 1}})

  defp expand_alias(other, _env), do: other

  @doc """
  Defines a list of plugs (and pipelines) to send the connection through.

  Plugs are specified using the atom name of any imported 2-arity function
  which takes a `Plug.Conn` struct and options and returns a `Plug.Conn` struct.
  For example, `:require_authenticated_user`.

  Pipelines are defined in the router, see `pipeline/2` for more information.

      pipe_through [:require_authenticated_user, :my_browser_pipeline]

  ## Multiple invocations

  `pipe_through/1` can be invoked multiple times within the same scope. Each
  invocation appends new plugs and pipelines to run, which are applied to all
  routes **after** the `pipe_through/1` invocation. For example:

      scope "/" do
        pipe_through [:browser]
        get "/", HomeController, :index

        pipe_through [:require_authenticated_user]
        get "/settings", UserController, :edit
      end

  In the example above, `/` pipes through `browser` only, while `/settings` pipes
  through both `browser` and `require_authenticated_user`. Therefore, to avoid
  confusion, we recommend a single `pipe_through` at the top of each scope:

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
        Macro.prewalk(pipes, &expand_alias(&1, __CALLER__))
      else
        pipes
      end

    quote do
      if pipeline = Context.get(__MODULE__, :pipeline_plugs) do
        raise "cannot pipe_through inside a pipeline"
      else
        Scope.pipe_through(__MODULE__, unquote(pipes))
      end
    end
  end

  @doc """
  Defines "RESTful" routes for a resource.

  The given definition:

      resources "/users", UserController

  will include routes to the following actions:

    * `GET /users` => `:index`
    * `GET /users/new` => `:new`
    * `POST /users` => `:create`
    * `GET /users/:id` => `:show`
    * `GET /users/:id/edit` => `:edit`
    * `PATCH /users/:id` => `:update`
    * `PUT /users/:id` => `:update`
    * `DELETE /users/:id` => `:delete`

  ## Options

  This macro accepts a set of options:

    * `:only` - a list of actions to generate routes for, for example: `[:show, :edit]`
    * `:except` - a list of actions to exclude generated routes from, for example: `[:delete]`
    * `:param` - the name of the parameter for this resource, defaults to `"id"`
    * `:name` - the prefix for this resource. This is used for the named helper
      and as the prefix for the parameter in nested resources. The default value
      is automatically derived from the controller name, i.e. `UserController`
       will have name `"user"`.
    * `:as` - configures the named helper. If `nil`, does not generate
      a helper.
    * `:singleton` - defines routes for a singleton resource.
      Read below for more information.

  ## Singleton resources

  When a resource needs to be looked up without referencing an ID, because
  it contains only a single entry in the given context, the `:singleton`
  option can be used to generate a set of routes that are specific to
  such single resource:

    * `GET /user/new` => `:new`
    * `POST /user` => `:create`
    * `GET /user` => `:show`
    * `GET /user/edit` => `:edit`
    * `PATCH /user` => `:update`
    * `PUT /user` => `:update`
    * `DELETE /user` => `:delete`

  Usage example:

      resources "/account", AccountController, only: [:show], singleton: true

  ## Nested Resources

  This macro also supports passing a nested block of route definitions.
  This is helpful for nesting children resources within their parents to
  generate nested routes.

  The given definition:

      resources "/users", UserController do
        resources "/posts", PostController
      end

  will include the following routes:

  ```console
  user_post_path  GET     /users/:user_id/posts           PostController :index
  user_post_path  GET     /users/:user_id/posts/new       PostController :new
  user_post_path  POST    /users/:user_id/posts           PostController :create
  user_post_path  GET     /users/:user_id/posts/:id       PostController :show
  user_post_path  GET     /users/:user_id/posts/:id/edit  PostController :edit
  user_post_path  PATCH   /users/:user_id/posts/:id       PostController :update
                  PUT     /users/:user_id/posts/:id       PostController :update
  user_post_path  DELETE  /users/:user_id/posts/:id       PostController :delete
  ```
  """
  defmacro resources(path, controller, opts, do: nested_context) do
    add_resources(path, controller, opts, do: nested_context)
  end

  @doc """
  See `resources/4`.
  """
  defmacro resources(path, controller, do: nested_context) do
    add_resources(path, controller, [], do: nested_context)
  end

  defmacro resources(path, controller, opts) do
    add_resources(path, controller, opts, do: nil)
  end

  @doc """
  See `resources/4`.
  """
  defmacro resources(path, controller) do
    add_resources(path, controller, [], do: nil)
  end

  defp add_resources(path, controller, options, do: context) do
    scope =
      if context do
        quote do
          scope(resource.member, do: unquote(context))
        end
      end

    quote do
      resource = Resource.build(unquote(path), unquote(controller), unquote(options))
      var!(add_resources, Combo.Router).(resource)
      unquote(scope)
    end
  end

  @doc """
  Returns the full alias with the current scope's aliased prefix.

  Useful for applying the same short-hand alias handling to
  other values besides the second argument in route definitions.

  ## Examples

      scope "/", MyPrefix do
        get "/", ProxyPlug, controller: scoped_alias(__MODULE__, MyController)
      end
  """
  @doc type: :reflection
  def scoped_alias(router_module, alias) do
    Scope.expand_alias(router_module, alias)
  end

  @doc """
  Returns the full path with the current scope's path prefix.
  """
  @doc type: :reflection
  def scoped_path(router_module, path) do
    Scope.full_path(router_module, path)
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

      iex> Combo.Router.route_info(MyApp.Web.Router, "GET", "/posts/123", "myhost")
      %{
        log: :debug,
        path_params: %{"id" => "123"},
        pipe_through: [:browser],
        plug: MyApp.Web.PostController,
        plug_opts: :show,
        route: "/posts/:id",
      }

      iex> Combo.Router.route_info(MyRouter, "GET", "/not-exists", "myhost")
      :error
  """
  @doc type: :reflection
  def route_info(router, method, path, host) when is_binary(path) do
    split_path = for segment <- String.split(path, "/"), segment != "", do: segment
    route_info(router, method, split_path, host)
  end

  def route_info(router, method, split_path, host) when is_list(split_path) do
    with {metadata, _prepare, _pipeline, {_plug, _opts}} <-
           router.__match_route__(split_path, method, host) do
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
