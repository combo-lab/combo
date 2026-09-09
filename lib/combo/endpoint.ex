defmodule Combo.Endpoint do
  @moduledoc ~S"""
  Defines an endpoint.

  The endpoint is the boundary where all requests to a web application start.
  It is also the interface of the underlying web server.

  Overall, an endpoint has three responsibilities:

    * to define an initial plug pipeline for requests to pass through

    * to provide a wrapper for starting and stopping the endpoint as part
      of a supervision tree

    * to host configuration for your web application

  ## Endpoints

  An endpoint is a module defined with the help of `Combo.Endpoint`. For example:

      defmodule MyApp.Web.Endpoint do
        use Combo.Endpoint, otp_app: :my_app

        # plug ...
        # plug ...

        plug MyApp.Web.Router
      end

  Endpoints can be added to the supervision tree as following:

      children = [
        MyApp.Web.Endpoint
      ]

  ## Endpoint configuration

  An endpoint is configured in your application environment. For example:

      config :my_app, MyApp.Web.Endpoint,
        key1: value1,
        # ...
        keyN: valueN

  Endpoint configuration is split into two categories:

    * Compile-time configuration
    * Runtime configuration

  Compile-time configuration means the configuration is read during compilation,
  and changing it at runtime has no effect.

  Runtime configuration means the configuration is read during runtime, and can
  be changed at runtime.

  ### Compile-time configuration

  The configuration below may be set on `config/dev.exs`, `config/prod.exs`
  and so on, but has no effect on `config/runtime.exs`.

    * `:live_reloader` - the configuration of `Combo.LiveReloader`.

    * `:code_reloader` - the configuration of `Combo.CodeReloader`.

    * `:debug_errors` - when `true`, uses `Plug.Debugger` functionality for
      debugging failures in the application. It is recommended to set it to
      `true` only in development as it allows listing of the application source
      code during debugging. Defaults to `false`.

  ### Runtime configuration

  The configuration below may be set on `config/dev.exs`, `config/prod.exs`
  and so on, as well as on `config/runtime.exs`.

  Typically, if you need to configure them with system environment variables,
  you set them in `config/runtime.exs`. These options may also be set when
  starting the endpoint in your supervision tree, such as
  `{MyApp.Web.Endpoint, opts}`.

    * `:adapter` - which web server adapter to use for serving web requests.
      See the "Adapter configuration" section below.

    * `:static` - the configuration of `Combo.Static`.

    * `:transport` - shared transport configuration. The `:check_origin` and
      `:check_csrf` options configure the default cross-origin request policy
      for transports. See `Combo.Endpoint.Compilers.Socket.socket/3` for details.
      Both default to `true`.

    * `:secret_key_base` - a secret key used as a base to generate secrets for
      encrypting and signing data. For example, cookies and tokens are signed
      by default, but they may also be encrypted if desired.
      Defaults to `nil` as it must be set per application.

    * `:server` - when `true`, starts the web server when the endpoint
      supervision tree starts. Defaults to `false`. The `mix combo.serve` task
      automatically sets this to `true`.

    * `:url` - a keyword list for generating URLs. Accepts the `:scheme`,
      `:host`, `:path` and `:port` options. All option except `:path` can be
      changed at runtime. Defaults to:

          [host: "localhost", path: "/"]

      The `:scheme` option accepts `"http"` and `"https"` values. Default value
      is inferred from top level `:http` or `:https` option. It is useful when
      hosting your web application behind a load balancer or reverse proxy and
      terminating SSL there.

      The `:host` option requires a string.

      The `:port` option requires either an integer or a string.

      The `:path` option requires a string. It can be used to override root
      path. It's useful when hosting your web application behind a reverse
      proxy with URL rewrite rules.

    * `:static_url` - a keyword list for generating URLs for static files.
      It will fallback to `:url` option if not set. Accepts the same value
      as `:url` option.

    * `:watchers` - a set of watchers to run alongside the server. It expects
      a list of tuples containing the executable and its arguments.
      Only when the server is enabled, or `mix combo.serve` runs, watchers
      will run. For example, the watcher below will run the "watch" mode of
      the webpack when the server starts. You can configure it to whatever
      build tool or command you want:

          [
            npx: [
              "webpack",
              "--mode",
              "development",
              "--watch",
              "--watch-options-stdin"
            ]
          ]

      The `:cd` and `:env` options can be given at the end of the list to
      customize the watcher:

          [node: [..., cd: "assets", env: [{"BUILD_MODE", "debug"}]]]

      A watcher can also be an MFA that will be invoked accordingly:

          [another: {Mod, :fun, [arg1, arg2]}]

      When `false`, watchers can be disabled.

    * `:pubsub_server` - the name of the pubsub server to use in channels and
      via the Endpoint broadcast functions. The pubsub server is typically
      started in your supervision tree.

    * `:render_errors` - responsible for rendering templates whenever there
      is a failure in your application. For example, if your application
      crashes with a 500 error during a HTML request,
      `render("500.html", assigns)` will be called in the view given to
      `:render_errors`. A `:formats` list can be provided to specify a module
      per format to handle error rendering. For example:

          [
            formats: [html: MyApp.Web.ErrorHTML, json: MyApp.Web.ErrorJSON],
            layout: false,
            log: :debug
          ]

    * `:log_access_url` - log the access url once the server boots.
      Default to `true`

  Note that you can also store your own configurations in the `Combo.Endpoint`.

  ### Adapter configuration

  Combo allows you to choose which web server adapter to use.

  The default adapter is `Combo.Endpoint.BanditAdapter`.

  Adapters are configured using the following two top-level options:

    * `:http` - the configuration for the HTTP server.

    * `:https` - the configuration for the HTTPS server.

  And, other config can be passed through to the adapter, too.

  ## Connection draining

  Connection draining should be implemented by the web server adapter.

  > Socket connections run their own drainer before the web server adapter's
  > children are shut down. That's because sockets are stateful and can be
  > gracefully notified, which allows us to stagger them over a longer period
  > of time. See `Combo.Endpoint.Compilers.Socket.socket/3` for more information.

  ## Endpoint API

  Here's a list of all the functions that are generated in your endpoint:

    * for configuration: `c:start_link/1`, `c:config/2`

    * for handling paths and URLs: `c:url/0`, `c:url_struct/0`, `c:path/1`,
      `c:static_url/0`,`c:static_path/1`, and `c:static_integrity/1`

    * for gathering runtime information about the address and port the
      endpoint is running on: `c:server_info/1`

    * for broadcasting to channels: `c:broadcast/3`, `c:broadcast!/3`,
      `c:broadcast_from/4`, `c:broadcast_from!/4`, `c:local_broadcast/3`,
      and `c:local_broadcast_from/4`

    * as required by the `Plug` behaviour: `c:Plug.init/1` and `c:Plug.call/2`

  """

  @type topic :: String.t()
  @type event :: String.t()
  @type msg :: map() | {:binary, binary()}

  # Configuration

  @doc """
  Starts the endpoint supervision tree.

  Starts endpoint's configuration cache and possibly the servers for handling
  requests.
  """
  @callback start_link(opts :: keyword()) :: Supervisor.on_start()

  @doc """
  Returns the endpoint configuration for `key`.
  """
  @callback config(key :: atom(), default :: term()) :: term()

  # Paths and URLs

  @doc """
  Generates the endpoint base URL, but as a `URI` struct.
  """
  @callback url_struct() :: URI.t()

  @doc """
  Generates the endpoint base URL without any path information.
  """
  @callback url() :: String.t()

  @doc """
  Generates the path information when routing to this endpoint.
  """
  @callback path(path :: String.t()) :: String.t()

  @doc """
  Generates the static URL without any path information.
  """
  @callback static_url() :: String.t()

  @doc """
  Generates a route to a static file in `priv/static`.
  """
  @callback static_path(path :: String.t()) :: String.t()

  @doc """
  Generates an integrity hash to a static file in `priv/static`.
  """
  @callback static_integrity(path :: String.t()) :: String.t() | nil

  @doc """
  Returns the host from the :url configuration.
  """
  @callback host() :: String.t()

  @doc """
  Returns the script name from the :url configuration.
  """
  @callback script_name() :: [String.t()]

  # Server information

  @doc """
  Returns the address and port that the server is running on
  """
  @callback server_info(Plug.Conn.scheme()) ::
              {:ok, {:inet.ip_address(), :inet.port_number()} | :inet.returned_non_ip_address()}
              | {:error, term()}

  # Channels

  @doc """
  Subscribes the caller to the given topic.

  See `Combo.PubSub.subscribe/3` for options.
  """
  @callback subscribe(topic, opts :: keyword()) :: :ok | {:error, term()}

  @doc """
  Unsubscribes the caller from the given topic.
  """
  @callback unsubscribe(topic) :: :ok | {:error, term()}

  @doc """
  Broadcasts a `msg` as `event` in the given `topic` to all nodes.
  """
  @callback broadcast(topic, event, msg) :: :ok | {:error, term()}

  @doc """
  Broadcasts a `msg` as `event` in the given `topic` to all nodes.

  Raises in case of failures.
  """
  @callback broadcast!(topic, event, msg) :: :ok

  @doc """
  Broadcasts a `msg` from the given `from` as `event` in the given `topic` to all nodes.
  """
  @callback broadcast_from(from :: pid(), topic, event, msg) :: :ok | {:error, term()}

  @doc """
  Broadcasts a `msg` from the given `from` as `event` in the given `topic` to all nodes.

  Raises in case of failures.
  """
  @callback broadcast_from!(from :: pid(), topic, event, msg) :: :ok

  @doc """
  Broadcasts a `msg` as `event` in the given `topic` within the current node.
  """
  @callback local_broadcast(topic, event, msg) :: :ok

  @doc """
  Broadcasts a `msg` from the given `from` as `event` in the given `topic` within the current node.
  """
  @callback local_broadcast_from(from :: pid(), topic, event, msg) :: :ok

  @compilers [
    Combo.Endpoint.Compilers.Debugger,
    Combo.Endpoint.Compilers.Socket
  ]

  @doc false
  defmacro __using__(opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)

    if not is_atom(otp_app) do
      raise ArgumentError, "expected :otp_app to be an atom, got: #{inspect(otp_app)}"
    end

    quote do
      @otp_app unquote(otp_app)

      @behaviour Combo.Endpoint

      import Combo.Endpoint

      unquote(compile_config())
      unquote(compile_server())
      unquote(compile_url_helpers())
      unquote(compile_pubsub())
      unquote(setup_plug())

      unquote(Combo.Endpoint.Compiler.setup(@compilers))
      unquote(Combo.Endpoint.Compiler.install(@compilers))

      @before_compile Combo.Endpoint
    end
  end

  defp compile_config do
    quote do
      # Compile-time configuration checking
      # This ensures that, if a compile-time configuration is overwritten at runtime,
      # the application won't boot.
      var!(live_reloading?) = !!Application.compile_env(@otp_app, [__MODULE__, :live_reloader])
      var!(code_reloading?) = !!Application.compile_env(@otp_app, [__MODULE__, :code_reloader])
      var!(debug_errors?) = Application.compile_env(@otp_app, [__MODULE__, :debug_errors], false)

      # Avoid unused variable warnings
      _ = var!(live_reloading?)
      _ = var!(code_reloading?)
      _ = var!(debug_errors?)

      @combo_live_reloading? var!(live_reloading?)
      @combo_code_reloading? var!(code_reloading?)
      @combo_debug_errors? var!(debug_errors?)
    end
  end

  defp compile_server do
    quote location: :keep, unquote: false do
      @doc """
      Returns the child specification to start the endpoint under a supervision tree.
      """
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      @doc """
      Starts the endpoint supervision tree.

      All other options are merged into the endpoint configuration.
      """
      def start_link(opts \\ []) do
        Combo.Endpoint.Supervisor.start_link(@otp_app, __MODULE__, opts)
      end

      @doc """
      Returns the endpoint configuration for `key`.

      Returns `default` if the key does not exist.
      """
      def config(key, default \\ nil) do
        Combo.Endpoint.Config.get(__MODULE__, key, default)
      end

      @doc """
      Returns the address and port that the server is listening on.
      """
      def server_info(scheme), do: config(:adapter).server_info(__MODULE__, scheme)
    end
  end

  defp compile_url_helpers do
    quote location: :keep, unquote: false do
      @doc """
      Returns the base URL of current endpoint, without any path information.

      It uses the configuration under `:url` to build such.
      """
      def url, do: Combo.Endpoint.Persistent.fetch!(__MODULE__, :url)

      @doc """
      Returns the `URI` struct for the base URL of current endpoint.

      It uses the configuration under `:url` to generate such.
      Useful for manipulating the URL data and passing it to URL helpers.
      """
      def url_struct, do: Combo.Endpoint.Persistent.fetch!(__MODULE__, :url_struct)

      @doc """
      Returns the host of current endpoint.
      """
      def host, do: Combo.Endpoint.Persistent.fetch!(__MODULE__, :host)

      @doc """
      Generates a path of current endpoint.
      """
      def path(path), do: Combo.Endpoint.Persistent.fetch!(__MODULE__, :path) <> path

      @doc """
      Returns the script name of current endpoint.
      """
      def script_name, do: Combo.Endpoint.Persistent.fetch!(__MODULE__, :script_name)

      @doc """
      Returns the base URL of static, without any path information.

      It uses the configuration under `:static_url` to build such.
      It falls back to `:url` if `:static_url` is not set.
      """
      def static_url, do: Combo.Endpoint.Persistent.fetch!(__MODULE__, :static_url)

      @doc """
      Generates a static path of current endpoint.
      """
      def static_path(path) do
        prefix = Combo.Endpoint.Persistent.fetch!(__MODULE__, :static_path)

        case :binary.split(path, "#") do
          [path, fragment] -> prefix <> elem(static_lookup(path), 0) <> "#" <> fragment
          [path] -> prefix <> elem(static_lookup(path), 0)
        end
      end

      @doc """
      Generates a base64-encoded cryptographic hash (sha512) to a static file.

      Meant to be used for Subresource Integrity with CDNs.
      """
      def static_integrity(path), do: elem(static_lookup(path), 1)

      defp static_lookup(path), do: Combo.Static.lookup(__MODULE__, path)
    end
  end

  defp compile_pubsub do
    quote generated: true do
      def subscribe(topic, opts \\ []) when is_binary(topic) do
        Combo.PubSub.subscribe(pubsub_server!(), topic, opts)
      end

      def unsubscribe(topic) do
        Combo.PubSub.unsubscribe(pubsub_server!(), topic)
      end

      def broadcast_from(from, topic, event, msg) do
        Combo.Channel.Server.broadcast_from(pubsub_server!(), from, topic, event, msg)
      end

      def broadcast_from!(from, topic, event, msg) do
        Combo.Channel.Server.broadcast_from!(pubsub_server!(), from, topic, event, msg)
      end

      def broadcast(topic, event, msg) do
        Combo.Channel.Server.broadcast(pubsub_server!(), topic, event, msg)
      end

      def broadcast!(topic, event, msg) do
        Combo.Channel.Server.broadcast!(pubsub_server!(), topic, event, msg)
      end

      def local_broadcast(topic, event, msg) do
        Combo.Channel.Server.local_broadcast(pubsub_server!(), topic, event, msg)
      end

      def local_broadcast_from(from, topic, event, msg) do
        Combo.Channel.Server.local_broadcast_from(pubsub_server!(), from, topic, event, msg)
      end

      defp pubsub_server! do
        config(:pubsub_server) ||
          raise ArgumentError, "no :pubsub_server configured for #{inspect(__MODULE__)}"
      end
    end
  end

  @doc false
  defmacro __before_compile__(%{module: endpoint}) do
    quote do
      unquote(Combo.Endpoint.Compiler.before_compile(@compilers, endpoint))
      unquote(compile_plug(endpoint))
    end
  end

  defp setup_plug() do
    quote location: :keep do
      use Plug.Builder, init_mode: Combo.plug_init_mode()
    end
  end

  defp compile_plug(endpoint) do
    quote do
      defoverridable call: 2

      # Inline render errors so we set the endpoint before calling it.
      def call(conn, opts) do
        conn = %{conn | script_name: script_name(), secret_key_base: config(:secret_key_base)}
        conn = Plug.Conn.put_private(conn, :combo_endpoint, unquote(endpoint))

        try do
          super(conn, opts)
        rescue
          e in Plug.Conn.WrapperError ->
            %{conn: conn, kind: kind, reason: reason, stack: stack} = e

            Combo.Endpoint.RenderErrors.__catch__(
              conn,
              kind,
              reason,
              stack,
              config(:render_errors)
            )
        catch
          kind, reason ->
            stack = __STACKTRACE__

            Combo.Endpoint.RenderErrors.__catch__(
              conn,
              kind,
              reason,
              stack,
              config(:render_errors)
            )
        end
      end
    end
  end

  ## API

  @doc """
  Checks if an endpoint's web server has been configured to start.

    * `otp_app` - The OTP application running the endpoint, such as `:my_app`.
    * `endpoint` - The endpoint module, such as `MyApp.Web.Endpoint`.

  ## Examples

      iex> Combo.Endpoint.server?(:my_app, MyApp.Web.Endpoint)
      true

  """
  def server?(otp_app, endpoint) when is_atom(otp_app) and is_atom(endpoint) do
    Combo.Endpoint.Supervisor.server?(otp_app, endpoint)
  end
end
