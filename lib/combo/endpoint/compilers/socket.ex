defmodule Combo.Endpoint.Compilers.Socket do
  @moduledoc """
  Provides the socket DSL and compiles socket routes for endpoints.

  The `socket/3` macro is automatically imported by `use Combo.Endpoint`.
  """

  @behaviour Combo.Endpoint.Compiler

  @socket_acc :combo_sockets
  @socket_dispatcher :socket_dispatcher

  @doc false
  @impl true
  def setup do
    quote do
      Module.register_attribute(__MODULE__, unquote(@socket_acc), accumulate: true)
    end
  end

  @doc false
  @impl true
  def install do
    quote location: :keep do
      import unquote(__MODULE__), only: [socket: 2, socket: 3]

      plug unquote(@socket_dispatcher)
    end
  end

  @doc false
  @impl true
  def before_compile(endpoint) do
    sockets = fetch_sockets(endpoint)
    dispatches = expand_socket_dispatches(endpoint, sockets)
    code_reloading? = code_reloading?(endpoint)

    sockets_info = compile_sockets_info(sockets)
    socket_dispatcher = compile_socket_dispatcher(dispatches, code_reloading?)
    socket_matches = compile_socket_matches(dispatches)

    quote do
      unquote(sockets_info)
      unquote(socket_dispatcher)
      unquote_splicing(socket_matches)
    end
  end

  defp fetch_sockets(endpoint) do
    endpoint
    |> Module.get_attribute(@socket_acc)
    |> Enum.reverse()
  end

  defp code_reloading?(endpoint) do
    Module.get_attribute(endpoint, :combo_code_reloading?)
  end

  defp compile_sockets_info(sockets) do
    sockets = Macro.escape(sockets)

    quote do
      @doc false
      def __sockets__, do: unquote(sockets)
    end
  end

  defp expand_socket_dispatches(endpoint, sockets) do
    Enum.flat_map(sockets, fn {path, socket_module, config} ->
      expand_socket_dispatches(endpoint, path, socket_module, config)
    end)
  end

  @common_transport_config_keys [:check_origin, :check_csrf, :auth_token]
  @specific_transport_config_namespaces [:websocket, :longpoll]
  @socket_transports [
    {:websocket, Combo.Transports.WebSocket, true, "/websocket"},
    {:longpoll, Combo.Transports.LongPoll, false, "/longpoll"}
  ]
  defp expand_socket_dispatches(endpoint, socket_path, socket_module, config) do
    {common_transport_config, config} =
      Keyword.split(config, @common_transport_config_keys)

    {specific_transport_configs, socket_config} =
      Keyword.split(config, @specific_transport_config_namespaces)

    socket = {socket_path, socket_module, socket_config}

    Enum.flat_map(@socket_transports, fn {name, module, default_config, default_path} ->
      transport_config = Keyword.get(specific_transport_configs, name, default_config)

      case normalize_transport_config(transport_config) do
        :disabled ->
          []

        transport_config ->
          {transport_path, transport_config} = Keyword.pop(transport_config, :path, default_path)

          transport_module = module

          transport_config =
            common_transport_config
            |> Keyword.merge(transport_config)
            |> module.build_config()

          transport = {transport_path, transport_module, transport_config}

          [
            build_socket_dispatch(endpoint, socket, transport)
          ]
      end
    end)
  end

  defp build_socket_dispatch(
         endpoint,
         {socket_path, socket_module, socket_config},
         {transport_path, transport_module, transport_config}
       ) do
    {path_info_ast, conn_ast} = compile_socket_path_match(socket_path, transport_path)

    %{
      path_info_ast: path_info_ast,
      conn_ast: conn_ast,
      plug: transport_module,
      plug_opts: {endpoint, transport_config, socket_module, socket_config}
    }
  end

  defp normalize_transport_config(config) do
    cond do
      config == true ->
        []

      config == false ->
        :disabled

      Keyword.keyword?(config) ->
        config

      true ->
        raise ArgumentError,
              "expected :transport configuration to be true, false, or a keyword list, " <>
                "got: #{inspect(config)}"
    end
  end

  defp compile_socket_path_match(socket_path, transport_path) do
    {vars, path_info_ast} =
      String.split(socket_path <> "/" <> transport_path, "/", trim: true)
      |> Enum.join("/")
      |> Plug.Router.Utils.build_path_match()

    conn_ast = compile_socket_conn(vars)

    {path_info_ast, conn_ast}
  end

  defp compile_socket_conn([]) do
    quote do
      conn
    end
  end

  defp compile_socket_conn(vars) do
    params =
      for var <- vars,
          param = Atom.to_string(var),
          not match?("_" <> _, param),
          do: {param, Macro.var(var, nil)}

    quote do
      params = %{unquote_splicing(params)}
      %{conn | path_params: params, params: params}
    end
  end

  defp compile_socket_matches([]), do: []

  defp compile_socket_matches([_ | _] = dispatches) do
    socket_matches = Enum.map(dispatches, &compile_socket_match/1)
    socket_matches ++ [compile_socket_match_fallback()]
  end

  defp compile_socket_match(%{
         path_info_ast: path_info,
         conn_ast: conn_ast,
         plug: plug,
         plug_opts: plug_opts
       }) do
    quote do
      defp match_socket(unquote(path_info), conn) do
        {:match, {unquote(conn_ast), unquote(plug), unquote(Macro.escape(plug_opts))}}
      end
    end
  end

  defp compile_socket_match_fallback do
    quote do
      defp match_socket(_path, _conn), do: :nomatch
    end
  end

  defp compile_socket_dispatcher([], _code_reloading?) do
    quote do
      @doc false
      def unquote(@socket_dispatcher)(conn, _opts), do: conn
    end
  end

  defp compile_socket_dispatcher([_ | _], true) do
    code_reloader_opts = Macro.escape(Combo.CodeReloader.init([]))

    quote do
      @doc false
      def unquote(@socket_dispatcher)(%{path_info: path} = conn, _opts) do
        case match_socket(path, conn) do
          {:match, {conn, plug, plug_opts}} ->
            conn = Combo.CodeReloader.call(conn, unquote(code_reloader_opts))

            if conn.halted do
              conn
            else
              conn |> plug.call(plug_opts) |> halt()
            end

          :nomatch ->
            conn
        end
      end
    end
  end

  defp compile_socket_dispatcher([_ | _], false) do
    quote do
      @doc false
      def unquote(@socket_dispatcher)(%{path_info: path} = conn, _opts) do
        case match_socket(path, conn) do
          {:match, {conn, plug, plug_opts}} -> conn |> plug.call(plug_opts) |> halt()
          :nomatch -> conn
        end
      end
    end
  end

  @doc """
  Defines a websocket/longpoll mount-point for a `socket`.

  It expects a path, a socket module, and a set of options. The socket module
  is typically defined with `Combo.Socket`.

  Both websocket and longpolling connections are supported out of the box.

  ## Options

    * `:websocket` - the websocket configuration.
      May be a boolean or a keyword list of options.
      See ["Common configuration"](#socket/3-common-configuration)
      and ["WebSocket configuration"](`Combo.Transports.WebSocket`)
      for the whole list.
      Defaults to `true`.

    * `:longpoll` - the longpoll configuration.
      May be a boolean or a keyword list of options.
      See ["Common configuration"](#socket/3-common-configuration)
      and ["Longpoll configuration"](`Combo.Transports.LongPoll`)
      for the whole list.
      Defaults to `false`.

    * `:drainer` - a keyword list or an MFA function returning a keyword list.
      For example, `{MyApp.Web.Socket, :drainer_configuration, []}` configuring
      how to drain sockets on application shutdown. The goal is to notify all
      channels clients to reconnect. The supported options are:

      * `:batch_size` - the amount of clients to notify at once in a given
        batch. Defaults to `10000`.
      * `:batch_interval` - the amount of time in milliseconds given for a
        batch to terminate. Defaults to `2000`ms.
      * `:shutdown` - the maximum amount of time in milliseconds allowed to
        drain all batches. Defaults to `30000`ms.
      * `:log` - the log level for drain actions. Defaults the `:log` option
        passed to `use Combo.Socket` or `:info`. Set it to `false` to disable
        logging.

      For example, if you have 150k connections, the default values will split
      them into 15 batches of 10k connections. Each batch takes 2000ms before
      the next batch starts. In this case, we will do everything right under
      the maximum shutdown time of 30000ms. Therefore, as you increase the
      number of connections, remember to adjust the shutdown accordingly.
      Finally, after the socket drainer runs, the lower level HTTP/HTTPS
      connection drainer will still run, and apply to all connections.
      Set it to `false` to disable draining.

    * `:auth_token` - a boolean that enables the use of the channels client's
      `auth_token` option. The exact token exchange mechanism depends on the
      transport:

        * the websocket transport, this enables a token to be passed through
          the `Sec-WebSocket-Protocol` header.
        * the longpoll transport, this allows the token to be passed through
          the `Authorization` header.

      The token is available in the `connect_info` as `:auth_token`.

      Custom transports might implement their own mechanism.

    * `:serializers` - a list of serializers for messages that overrides the
      handler's defaults. See `Combo.Socket` for more information.

    * `:log` - the log level for handler connection events. Set it to `false`
      to disable logging.

  You can also pass the options below on `use Combo.Socket`.
  The values specified here override the value in `use Combo.Socket`.

  ## Examples

      socket "/ws", MyApp.Web.UserSocket

      socket "/ws/admin", MyApp.Web.AdminUserSocket,
        websocket: [compress: true],
        longpoll: true

  ## Path params

  It is possible to include variables in the path, these will be available in
  the `params` that are passed to the socket.

      socket "/ws/:user_id", MyApp.Web.UserSocket,
        websocket: [path: "/project/:project_id"]

  ## Common configuration

  The configuration below can be given to both `:websocket` and `:longpoll`
  options:

    * `:path` - the route suffix appended to the socket mount path.
      Defaults to `"/websocket"` or `"/longpoll"`.

    * `:log` - if the transport layer itself should log and, if so, the level.

    * `:check_origin` - if the transport should check the origin of requests
      when the `origin` header is present. May be a boolean, a list of URIs
      that are allowed, or a function provided as an MFA.
      Defaults to the `:check_origin` option in the endpoint's `:transport`
      configuration.

      If `true`, the header is checked against `:host` in
      `MyApp.Web.Endpoint.config(:url)[:host]`.

      If `false` and you do not validate the session in your socket, your app
      is vulnerable to Cross-Site WebSocket Hijacking (CSWSH) attacks. Only use
      in development, when the host is truly unknown or when serving clients
      that do not send the `origin` header, such as mobile apps.

      You can also specify a list of explicitly allowed origins. Each origin may include
      scheme, host, and port. Wildcards are supported.

          check_origin: [
            "https://example.com",
            "//another.com:888",
            "//*.other.com"
          ]

      Or to accept any origin matching the request connection's host, port, and scheme:

          check_origin: :conn

      Or a function provided as an MFA:

          check_origin: {MyApp.Web.Auth, :check_origin?, []}

      The MFA is invoked with the request `%URI{}` as the first argument,
      followed by arguments in the MFA, and must return a boolean.

    * `:check_csrf` - if the transport should perform CSRF check. To avoid
      "Cross-Site WebSocket Hijacking", you must have at least one of
      `check_origin` and `check_csrf` enabled. If you set both to `false`,
      Combo will raise, but it is still possible to disable both by passing
      an MFA to `check_origin`. In such cases, it is your responsibility to
      ensure at least one of them is enabled. Defaults to the `:check_csrf`
      option in the endpoint's `:transport` configuration.

    * `:connect_info` - a list of keys that represent data to be copied from
      the transport to be made available in the user socket `connect/3` callback.
      See the "Connect info" subsection for valid keys.

  ### Connect info

  The valid keys are:

    * `:peer_data` - the result of `Plug.Conn.get_peer_data/1`.

    * `:trace_context_headers` - a list of all trace context headers. Supported
      headers are defined by the [W3C Trace Context Specification](https://www.w3.org/TR/trace-context-1/).
      These headers are necessary for libraries such as [OpenTelemetry](https://opentelemetry.io/)
      to extract trace propagation information to know this request is part of a
      larger trace in progress.

    * `:x_headers` - all request headers that have an "x-" prefix.

    * `:uri` - a `%URI{}` with information from the conn.

    * `:user_agent` - the value of the "user-agent" request header.

    * `{:session, session_config}` - the session information from `Plug.Conn`.
      The `session_config` is typically an exact copy of the arguments given
      to `Plug.Session`. In order to validate the session, the "_csrf_token"
      must be given as request parameter when connecting the socket with the
      value of `URI.encode_www_form(Plug.CSRFProtection.get_csrf_token())`.
      The CSRF token request parameter can be modified via the `:csrf_token_key`
      option.

      Additionally, `session_config` may be an MFA, such as
      `{MyApp.Web.Auth, :get_session_config, []}`, to allow loading config in
      runtime.

  Arbitrary keywords may also appear following the above valid keys, which
  is useful for passing custom connection information to the socket.

  For example:

      socket "/socket", MyApp.Web.UserSocket,
        websocket: [
          connect_info: [:peer_data, :trace_context_headers, :x_headers, :uri, session: [store: :cookie]]
        ]

  With arbitrary keywords:

      socket "/socket", MyApp.Web.UserSocket,
        websocket: [
          connect_info: [:uri, custom_value: "abcdef"]
        ]

  > #### Where are my headers? {: .tip}
  >
  > Combo only gives you limited access to the connection headers for security
  > reasons. WebSockets are cross-domain, which means that, when a user "John Doe"
  > visits a malicious website, the malicious website can open up a WebSocket
  > connection to your application, and the browser will gladly submit John Doe's
  > authentication/cookie information. If you were to accept this information as is,
  > the malicious website would have full control of a WebSocket connection to your
  > application, authenticated on John Doe's behalf.
  >
  > To safe-guard your application, Combo limits and validates the connection
  > information your socket can access. This means your application is safe from
  > these attacks, but you can't access cookies and other headers in your socket.
  > You may access the session stored in the connection via the `:connect_info`
  > option, provided you also pass a csrf token when connecting over WebSocket.
  """
  defmacro socket(path, module, opts \\ []) do
    # Expand module in a function context to avoid a compile-time dependency.
    module = Macro.expand(module, %{__CALLER__ | function: {@socket_dispatcher, 2}})

    quote do
      Module.put_attribute(
        __MODULE__,
        unquote(@socket_acc),
        {unquote(path), unquote(module), unquote(opts)}
      )
    end
  end
end
