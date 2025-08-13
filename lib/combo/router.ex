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

      defmodule Demo.Web.Router do
        use Combo.Router

        get "/pages/:page", Demo.Web.PageController, :show
      end

  Combo's router is extremely efficient, as it relies on pattern matching for
  matching routes.

  ## Routing

  `get/3`, `post/3`, `put/3`, and other macros named after HTTP verbs are used
  to create routes.

  The route:

      get "/pages", PageController, :index

  matches a `GET` request to `/pages` and dispatches it to the `index` action
  in `PageController`.

      get "/pages/:page", PageController, :show

  matches `/pages/hello` and dispatches to the `show` action in `PageController`
  with `%{"page" => "hello"}` in `params`.

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
  > Combo does its best to keep the usage of macros low. You may have noticed,
  > however, that the `Combo.Router` relies heavily on macros. Why is that?
  >
  > We use macros for two purposes:
  >
  > * To be faster. They define the routing engine, used on every request, to
  >   choose which controller to dispatch the request to. Thanks to macros,
  >   Combo compiles all of your routes to a single case-statement with pattern
  >   matching rules, which is heavily optimized by the Erlang VM.
  >
  > * To be safer. For each route you define, we also define metadata to
  >   implement `Combo.VerifiedRoutes`. As we will soon learn, verified routes
  >   allows us to reference any route as if it is a plain looking string,
  >   except it is verified by the compiler to be valid (making it much harder
  >   to ship broken links, forms, mails, etc to production). Also remember
  >   that macros in Elixir are compile-time only, which gives plenty of
  >   stability after the code is compiled.
  >
  > To summarize, the router relies on macros to build applications that are
  > faster and safer.

  ## Scopes and Resources

  It is very common to namespace routes under a scope. For example:

      scope "/", Demo.Web do
        get "/pages/:id", PageController, :show
      end

  The route above will dispatch to `Demo.Web.PageController`. This syntax is
  convenient to use, since you don't have to repeat `Demo.Web.` prefix on all
  routes.

  Like all paths, you can define dynamic segments that will be applied as
  parameters in the controller. For example:

      scope "/api/:version", Demo.Web do
        get "/pages/:id", PageController, :show
      end

  The route above will match on the path `"/api/v1/pages/1"` and in the
  controller the `params` argument be a map like
  `%{"version" => "v1", "id" => "1"}`.

  Combo also provides a `resources/4` macro that allows to generate "RESTful"
  routes to a given resource:

      defmodule Demo.Web.Router do
        use Combo.Router

        resources "/pages", PageController, only: [:show]
        resources "/users", UserController, except: [:delete]
      end

  Check `scope/2` and `resources/4` for more information.

  ## Listing routes

  Combo ships with a `mix combo.routes` task that formats all routes in a given
  router. We can use it to verify all routes included in the router above:

      $ mix combo.routes Demo.Web.Router
      GET    /pages/:id       PageController.show/2
      GET    /users           UserController.index/2
      GET    /users/:id/edit  UserController.edit/2
      GET    /users/new       UserController.new/2
      GET    /users/:id       UserController.show/2
      POST   /users           UserController.create/2
      PATCH  /users/:id       UserController.update/2
      PUT    /users/:id       UserController.update/2

  ## Pipelines and plugs

  Once a request arrives at the Combo router, it performs a series of
  transformations through pipelines until the request is dispatched to a
  desired route.

  Such transformations are defined via plugs, as defined in the
  [Plug](https://github.com/elixir-plug/plug) specification.

  Once a pipeline is defined, it can be piped through per scope.

  For example:

      defmodule Demo.Web.Router do
        use Combo.Router

        import Combo.Controller
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

  In the example above, we also imports `Combo.Controller` and `Plug.Conn` to
  help defining plugins. `accepts/2` comes from `Combo.Controller`, while
  `fetch_session/2` comes from `Plug.Conn`.

  Note that router pipelines are only invoked after a route is found.
  No plug is invoked in case no matches were found.

  ## Generating routes

  For generating routes inside your application, see the `Combo.VerifiedRoutes`
  documentation for `~p` based route generation which generates route paths and
  URLs with compile-time verification.

  ## Learn more

  See the [Routing](routing.md) guide for more information and examples within
  an actual application.
  """

  alias Combo.Router.{Resource, Scope, Route}

  @http_methods [:get, :post, :put, :patch, :delete, :options, :connect, :trace, :head]

  @doc false
  defmacro __using__(opts) do
    quote do
      unquote(prelude(opts))
      unquote(defs())
      unquote(match_dispatch())
      unquote(verified_routes())
    end
  end

  defp prelude(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :combo_routes, accumulate: true)

      import Combo.Router

      # Set up initial scope
      @combo_pipeline nil
      Combo.Router.Scope.init(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  # Because those macros are executed multiple times,
  # we end-up generating a huge scope that drastically
  # affects compilation. We work around it by defining
  # those functions only once and calling it over and
  # over again.
  defp defs() do
    quote unquote: false do
      var!(add_resources, Combo.Router) = fn resource ->
        path = resource.path
        ctrl = resource.controller
        opts = resource.route

        if resource.singleton do
          Enum.each(resource.actions, fn
            :show ->
              get path, ctrl, :show, opts

            :new ->
              get path <> "/new", ctrl, :new, opts

            :edit ->
              get path <> "/edit", ctrl, :edit, opts

            :create ->
              post path, ctrl, :create, opts

            :delete ->
              delete path, ctrl, :delete, opts

            :update ->
              patch path, ctrl, :update, opts
              put path, ctrl, :update, Keyword.put(opts, :as, nil)
          end)
        else
          param = resource.param

          Enum.each(resource.actions, fn
            :index ->
              get path, ctrl, :index, opts

            :show ->
              get path <> "/:" <> param, ctrl, :show, opts

            :new ->
              get path <> "/new", ctrl, :new, opts

            :edit ->
              get path <> "/:" <> param <> "/edit", ctrl, :edit, opts

            :create ->
              post path, ctrl, :create, opts

            :delete ->
              delete path <> "/:" <> param, ctrl, :delete, opts

            :update ->
              patch path <> "/:" <> param, ctrl, :update, opts
              put path <> "/:" <> param, ctrl, :update, Keyword.put(opts, :as, nil)
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

  defp match_dispatch() do
    quote location: :keep, generated: true do
      @behaviour Plug

      @doc """
      Callback required by Plug that initializes the router
      for serving web requests.
      """
      def init(opts) do
        opts
      end

      @doc """
      Callback invoked by Plug on every request.
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

  defp verified_routes() do
    quote location: :keep, generated: true do
      @behaviour Combo.VerifiedRoutes

      def formatted_routes(_) do
        Combo.Router.__formatted_routes__(__MODULE__)
      end

      def verified_route?(_, split_path) do
        Combo.Router.__verified_route__?(__MODULE__, split_path)
      end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    routes = env.module |> Module.get_attribute(:combo_routes) |> Enum.reverse()
    routes_with_exprs = Enum.map(routes, &{&1, Route.exprs(&1)})

    {matches, {pipelines, _}} =
      Enum.map_reduce(routes_with_exprs, {[], %{}}, &build_match/2)

    routes_per_path =
      routes_with_exprs
      |> Enum.group_by(&elem(&1, 1).path, &elem(&1, 0))

    verifies =
      routes_with_exprs
      |> Enum.map(&elem(&1, 1).path)
      |> Enum.uniq()
      |> Enum.map(&build_verify(&1, routes_per_path))

    verify_catch_all =
      quote generated: true do
        @doc false
        def __verify_route__(_path_info) do
          :error
        end
      end

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

    checks =
      routes
      |> Enum.map(fn %{line: line, metadata: metadata, plug: plug} ->
        {line, Map.get(metadata, :mfa, {plug, :init, 1})}
      end)
      |> Enum.uniq()
      |> Enum.map(fn {line, {module, function, arity}} ->
        quote line: line, do: _ = &(unquote(module).unquote(function) / unquote(arity))
      end)

    keys = [:verb, :path, :plug, :plug_opts, :helper, :metadata]
    routes = Enum.map(routes, &Map.take(&1, keys))

    quote do
      @doc false
      def __routes__, do: unquote(Macro.escape(routes))

      @doc false
      def __checks__, do: unquote({:__block__, [], checks})

      defp prepare(conn) do
        Plug.Conn.merge_private(conn, [
          {:combo_router, __MODULE__},
          {__MODULE__, conn.script_name}
        ])
      end

      unquote(pipelines)
      unquote(verifies)
      unquote(verify_catch_all)
      unquote(matches)
      unquote(match_catch_all)
      unquote(forward_catch_all)
    end
  end

  defp build_verify(path, routes_per_path) do
    routes = Map.get(routes_per_path, path)
    warn_on_verify? = Enum.all?(routes, & &1.warn_on_verify?)

    case Enum.find(routes, &(&1.kind == :forward)) do
      %{metadata: %{forward: forward}, plug: plug, plug_opts: plug_opts} ->
        quote generated: true do
          def __forward__(unquote(plug)) do
            unquote(forward)
          end

          def __verify_route__(unquote(path)) do
            {{unquote(plug), unquote(forward), unquote(Macro.escape(plug_opts))},
             unquote(warn_on_verify?)}
          end
        end

      _ ->
        quote generated: true do
          def __verify_route__(unquote(path)) do
            {nil, unquote(warn_on_verify?)}
          end
        end
    end
  end

  defp build_match({route, expr}, {acc_pipes, known_pipes}) do
    {pipe_name, acc_pipes, known_pipes} = build_match_pipes(route, acc_pipes, known_pipes)

    %{
      prepare: prepare,
      dispatch: dispatch,
      verb_match: verb_match,
      path_params: path_params,
      hosts: hosts,
      path: path
    } = expr

    clauses =
      for host <- hosts do
        quote line: route.line do
          def __match_route__(unquote(path), unquote(verb_match), unquote(host)) do
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
  Generates a route match based on an arbitrary HTTP method.

  Useful for defining routes not included in the built-in macros.

  The catch-all verb, `:*`, may also be used to match all HTTP methods.

  ## Options

    * `:as` - configures the named helper. If `nil`, does not generate
      a helper. Has no effect when using verified routes exclusively
    * `:alias` - configure if the scope alias should be applied to the route.
      Defaults to true, disables scoping if false.
    * `:log` - the level to log the route dispatching under, may be set to false. Defaults to
      `:debug`. Route dispatching contains information about how the route is handled (which controller
      action is called, what parameters are available and which pipelines are used) and is separate from
      the plug level logging. To alter the plug log level, please see
      https://hexdocs.pm/combo/Combo.Logger.html#module-dynamic-log-level.
    * `:private` - a map of private data to merge into the connection
      when a route matches
    * `:assigns` - a map of data to merge into the connection when a route matches
    * `:metadata` - a map of metadata used by the telemetry events and returned by
      `route_info/4`. The `:mfa` field is used by telemetry to print logs and by the
      router to emit compile time checks. Custom fields may be added.
    * `:warn_on_verify` - the boolean for whether matches to this route trigger
      an unmatched route warning for `Combo.VerifiedRoutes`. It is useful to ignore
      an otherwise catch-all route definition from being matched when verifying routes.
      Defaults `false`.

  ## Examples

      match(:move, "/events/:id", EventController, :move)

      match(:*, "/any", SomeController, :any)

  """
  defmacro match(verb, path, plug, plug_opts, options \\ []) do
    add_route(:match, verb, path, expand_alias(plug, __CALLER__), plug_opts, options)
  end

  for verb <- @http_methods do
    @doc """
    Generates a route to handle a #{verb} request to the given path.

        #{verb}("/events/:id", EventController, :action)

    See `match/5` for options.

    #{if verb == :head do
      """
      ## Compatibility with `Plug.Head`

      By default, Combo apps include `Plug.Head` in their endpoint,
      which converts HEAD requests into regular GET requests. Therefore, if
      you intend to use `head/4` in your router, you need to move `Plug.Head`
      to inside your router in a way it does not conflict with the paths given
      to `head/4`.
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

  @doc """
  Defines a plug pipeline.

  Pipelines are defined at the router root and can be used
  from any scope.

  ## Examples

      pipeline :api do
        plug :token_authentication
        plug :dispatch
      end

  A scope may then use this pipeline as:

      scope "/" do
        pipe_through :api
      end

  Every time `pipe_through/1` is called, the new pipelines
  are appended to the ones previously given.
  """
  defmacro pipeline(plug, do: block) do
    with true <- is_atom(plug),
         imports = __CALLER__.macros ++ __CALLER__.functions,
         {mod, _} <- Enum.find(imports, fn {_, imports} -> {plug, 2} in imports end) do
      raise ArgumentError,
            "cannot define pipeline named #{inspect(plug)} " <>
              "because there is an import from #{inspect(mod)} with the same name"
    end

    block =
      quote do
        plug = unquote(plug)
        @combo_pipeline []
        unquote(block)
      end

    compiler =
      quote unquote: false do
        Scope.pipeline(__MODULE__, plug)

        {conn, body} =
          Plug.Builder.compile(__ENV__, @combo_pipeline, init_mode: Combo.plug_init_mode())

        def unquote(plug)(unquote(conn), _) do
          try do
            unquote(body)
          rescue
            e in Plug.Conn.WrapperError ->
              Plug.Conn.WrapperError.reraise(e)
          catch
            :error, reason ->
              Plug.Conn.WrapperError.reraise(unquote(conn), :error, reason, __STACKTRACE__)
          end
        end

        @combo_pipeline nil
      end

    quote do
      try do
        unquote(block)
        unquote(compiler)
      after
        :ok
      end
    end
  end

  @doc """
  Defines a plug inside a pipeline.

  See `pipeline/2` for more information.
  """
  defmacro plug(plug, opts \\ []) do
    {plug, opts} = expand_plug_and_opts(plug, opts, __CALLER__)

    quote do
      if pipeline = @combo_pipeline do
        @combo_pipeline [{unquote(plug), unquote(opts), true} | pipeline]
      else
        raise "cannot define plug at the router level, plug must be defined inside a pipeline"
      end
    end
  end

  defp expand_plug_and_opts(plug, opts, caller) do
    runtime? = Combo.plug_init_mode() == :runtime

    plug =
      if runtime? do
        expand_alias(plug, caller)
      else
        plug
      end

    opts =
      if runtime? and Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, caller))
      else
        opts
      end

    {plug, opts}
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:init, 1}})

  defp expand_alias(other, _env), do: other

  @doc """
  Defines a list of plugs (and pipelines) to send the connection through.

  Plugs are specified using the atom name of any imported 2-arity function
  which takes a `Plug.Conn` and options and returns a `Plug.Conn`. For
  example, `:require_authenticated_user`.

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
      if pipeline = @combo_pipeline do
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
      is automatically derived from the controller name, i.e. `UserController` will
      have name `"user"`
    * `:as` - configures the named helper. If `nil`, does not generate
      a helper. Has no effect when using verified routes exclusively
    * `:singleton` - defines routes for a singleton resource that is looked up by
      the client without referencing an ID. Read below for more information

  ## Singleton resources

  When a resource needs to be looked up without referencing an ID, because
  it contains only a single entry in the given context, the `:singleton`
  option can be used to generate a set of routes that are specific to
  such single resource:

    * `GET /user` => `:show`
    * `GET /user/new` => `:new`
    * `POST /user` => `:create`
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
  user_post_path  GET     /users/:user_id/posts/:id/edit  PostController :edit
  user_post_path  GET     /users/:user_id/posts/new       PostController :new
  user_post_path  GET     /users/:user_id/posts/:id       PostController :show
  user_post_path  POST    /users/:user_id/posts           PostController :create
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
  Defines a scope in which routes can be nested.

  ## Examples

      scope path: "/api/v1", alias: API.V1 do
        get "/pages/:id", PageController, :show
      end

  The generated route above will match on the path `"/api/v1/pages/:id"`
  and will dispatch to `:show` action in `API.V1.PageController`. A named
  helper `api_v1_page_path` will also be generated.

  ## Options

  The supported options are:

    * `:path` - a string containing the path scope.
    * `:as` - a string or atom containing the named helper scope. When set to
      false, it resets the nested helper scopes. Has no effect when using verified
      routes exclusively
    * `:alias` - an alias (atom) containing the controller scope. When set to
      false, it resets all nested aliases.
    * `:host` - a string or list of strings containing the host scope, or prefix host scope,
      ie `"foo.bar.com"`, `"foo."`
    * `:private` - a map of private data to merge into the connection when a route matches
    * `:assigns` - a map of data to merge into the connection when a route matches
    * `:log` - the level to log the route dispatching under, may be set to false. Defaults to
      `:debug`. Route dispatching contains information about how the route is handled (which controller
      action is called, what parameters are available and which pipelines are used) and is separate from
      the plug level logging. To alter the plug log level, please see
      https://hexdocs.pm/combo/Combo.Logger.html#module-dynamic-log-level.

  """
  defmacro scope(options, do: context) do
    options =
      if Macro.quoted_literal?(options) do
        Macro.prewalk(options, &expand_alias(&1, __CALLER__))
      else
        options
      end

    do_scope(options, context)
  end

  @doc """
  Define a scope with the given path.

  This function is a shortcut for:

      scope path: path do
        ...
      end

  ## Examples

      scope "/v1", host: "api." do
        get "/pages/:id", PageController, :show
      end

  """
  defmacro scope(path, options, do: context) do
    options =
      if Macro.quoted_literal?(options) do
        Macro.prewalk(options, &expand_alias(&1, __CALLER__))
      else
        options
      end

    options =
      quote do
        path = unquote(path)

        case unquote(options) do
          alias when is_atom(alias) -> [path: path, alias: alias]
          options when is_list(options) -> Keyword.put(options, :path, path)
        end
      end

    do_scope(options, context)
  end

  @doc """
  Defines a scope with the given path and alias.

  This function is a shortcut for:

      scope path: path, alias: alias do
        ...
      end

  ## Examples

      scope "/v1", API.V1, host: "api." do
        get "/pages/:id", PageController, :show
      end

  """
  defmacro scope(path, alias, options, do: context) do
    alias = expand_alias(alias, __CALLER__)

    options =
      quote do
        unquote(options)
        |> Keyword.put(:path, unquote(path))
        |> Keyword.put(:alias, unquote(alias))
      end

    do_scope(options, context)
  end

  defp do_scope(options, context) do
    quote do
      Scope.push(__MODULE__, unquote(options))

      try do
        unquote(context)
      after
        Scope.pop(__MODULE__)
      end
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
  applications or even breaking a big router into smaller ones.
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
    {plug, plug_opts} = expand_plug_and_opts(plug, plug_opts, __CALLER__)
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

    * `:log` - the configured log level. For example `:debug`
    * `:path_params` - the map of runtime path params
    * `:pipe_through` - the list of pipelines for the route's scope, for example `[:browser]`
    * `:plug` - the plug to dispatch the route to, for example `AppWeb.PostController`
    * `:plug_opts` - the options to pass when calling the plug, for example: `:index`
    * `:route` - the string route pattern, such as `"/posts/:id"`

  ## Examples

      iex> Combo.Router.route_info(AppWeb.Router, "GET", "/posts/123", "myhost")
      %{
        log: :debug,
        path_params: %{"id" => "123"},
        pipe_through: [:browser],
        plug: AppWeb.PostController,
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

  @doc false
  def __verified_route__?(router, split_path) do
    case router.__verify_route__(split_path) do
      {_forward_plug, true = _warn_on_verify?} ->
        false

      {nil = _forward_plug, false = _warn_on_verify?} ->
        true

      {{router, script_name, plug_opts}, false = _warn_on_verify?} ->
        Code.ensure_loaded(router)

        if function_exported?(router, :verified_route?, 2) do
          router.verified_route?(plug_opts, split_path -- script_name)
        else
          true
        end

      :error ->
        false
    end
  end
end
