defmodule Combo.Transport do
  @moduledoc """
  Provides utils shared by transports.

  See `Combo.Transport.Handler` for the interface implemented by transport
  handlers.
  """

  @callback default_config() :: Keyword.t()
  @callback init(Plug.opts()) :: Plug.opts()
  @callback call(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()

  require Logger

  @connect_info_keys [
    :peer_data,
    :trace_context_headers,
    :uri,
    :user_agent,
    :x_headers,
    :sec_websocket_headers,
    :auth_token
  ]

  @doc false
  def load_config(module, config) do
    module.default_config()
    |> Keyword.merge(config)
    |> load_config()
  end

  @doc false
  def load_config(config) do
    {connect_info, config} = Keyword.pop(config, :connect_info, [])

    connect_info =
      if config[:auth_token] do
        # auth_token is included by default when enabled
        [:auth_token | connect_info]
      else
        connect_info
      end

    connect_info =
      Enum.map(connect_info, fn
        key when key in @connect_info_keys ->
          key

        {:session, session} ->
          {:session, init_session(session)}

        {_, _} = pair ->
          pair

        other ->
          raise ArgumentError,
                ":connect_info keys are expected to be one of :peer_data, :trace_context_headers, :x_headers, :user_agent, :sec_websocket_headers, :uri, or {:session, config}, " <>
                  "optionally followed by custom keyword pairs, got: #{inspect(other)}"
      end)

    [connect_info: connect_info] ++ config
  end

  # The original session_config is returned in addition to init value so we can
  # access special config like :csrf_token_key downstream.
  defp init_session(session_config) when is_list(session_config) do
    key = Keyword.fetch!(session_config, :key)
    store = Plug.Session.Store.get(Keyword.fetch!(session_config, :store))
    init = store.init(Keyword.drop(session_config, [:store, :key]))
    csrf_token_key = Keyword.get(session_config, :csrf_token_key, "_csrf_token")
    {key, store, {csrf_token_key, init}}
  end

  defp init_session({_, _, _} = mfa) do
    {:mfa, mfa}
  end

  @doc """
  Runs the code reloader if enabled.
  """
  def code_reload(conn, endpoint, opts) do
    if Keyword.get(opts, :code_reloader, endpoint.config(:code_reloader)) do
      Combo.CodeReloader.reload(endpoint)
    end

    conn
  end

  @doc """
  Logs the transport request.

  Available for transports that generate a connection.
  """
  def transport_log(conn, level) do
    if level do
      Plug.Logger.call(conn, Plug.Logger.init(log: level))
    else
      conn
    end
  end

  @doc """
  Checks the origin request header against the list of allowed origins.

  Should be called by transports before connecting when appropriate.
  If the origin header matches the allowed origins, no origin header was
  sent or no origin was configured, it will return the given connection.

  Otherwise a 403 Forbidden response will be sent and the connection halted.
  It is a noop if the connection has been halted.
  """
  def check_origin(conn, handler, endpoint, opts, sender \\ &Plug.Conn.send_resp/1)

  def check_origin(%Plug.Conn{halted: true} = conn, _handler, _endpoint, _opts, _sender),
    do: conn

  def check_origin(conn, handler, endpoint, opts, sender) do
    import Plug.Conn
    origin = conn |> get_req_header("origin") |> List.first()
    check_origin = check_origin_config(handler, endpoint, opts)

    cond do
      is_nil(origin) or check_origin == false ->
        conn

      origin_allowed?(check_origin, URI.parse(origin), endpoint, conn) ->
        conn

      true ->
        Logger.error("""
        Could not check origin for Combo.Socket transport.

        Origin of the request: #{origin}

        This happens when you are attempting a socket connection to
        a different host than the one configured in your config/
        files. For example, in development the host is configured
        to "localhost" but you may be trying to access it from
        "127.0.0.1". To fix this issue, you may either:

          1. update [url: [host: ...]] to your actual host in the
             config file for your current environment (recommended)

          2. pass the :check_origin option when configuring your
             endpoint or when configuring the transport in your
             UserSocket module, explicitly outlining which origins
             are allowed:

                check_origin: ["https://example.com",
                               "//another.com:888", "//other.com"]

        """)

        resp(conn, :forbidden, "")
        |> sender.()
        |> halt()
    end
  end

  @doc """
  Checks the Websocket subprotocols request header against the allowed subprotocols.

  Should be called by transports before connecting when appropriate.
  If the sec-websocket-protocol header matches the allowed subprotocols,
  it will put sec-websocket-protocol response header and return the given connection.
  If no sec-websocket-protocol header was sent it will return the given connection.

  Otherwise a 403 Forbidden response will be sent and the connection halted.
  It is a noop if the connection has been halted.
  """
  def check_subprotocols(conn, subprotocols)

  def check_subprotocols(%Plug.Conn{halted: true} = conn, _subprotocols), do: conn
  def check_subprotocols(conn, nil), do: conn

  def check_subprotocols(conn, subprotocols) when is_list(subprotocols) do
    case Plug.Conn.get_req_header(conn, "sec-websocket-protocol") do
      [] ->
        conn

      [subprotocols_header | _] ->
        request_subprotocols = subprotocols_header |> Plug.Conn.Utils.list()

        subprotocol =
          Enum.find(subprotocols, fn elem -> Enum.find(request_subprotocols, &(&1 == elem)) end)

        if subprotocol do
          Plug.Conn.put_resp_header(conn, "sec-websocket-protocol", subprotocol)
        else
          subprotocols_error_response(conn, subprotocols)
        end
    end
  end

  def check_subprotocols(conn, subprotocols), do: subprotocols_error_response(conn, subprotocols)

  defp subprotocols_error_response(conn, subprotocols) do
    import Plug.Conn
    request_headers = get_req_header(conn, "sec-websocket-protocol")

    Logger.error("""
    Could not check Websocket subprotocols for Combo.Socket transport.

    Subprotocols of the request: #{inspect(request_headers)}
    Configured supported subprotocols: #{inspect(subprotocols)}

    This happens when you are attempting a socket connection to
    a different subprotocols than the one configured in your endpoint
    or when you incorrectly configured supported subprotocols.

    To fix this issue, you may either:

      1. update websocket: [subprotocols: [..]] to your actual subprotocols
         in your endpoint socket configuration.

      2. check the correctness of the `sec-websocket-protocol` request header
         sent from the client.

      3. remove `websocket` option from your endpoint socket configuration
         if you don't use Websocket subprotocols.
    """)

    resp(conn, :forbidden, "")
    |> send_resp()
    |> halt()
  end

  @doc """
  Extracts connection information from `conn` and returns a map.

  Keys are retrieved from the optional transport option `:connect_info`.
  This functionality is transport specific. Please refer to your transports'
  documentation for more information.

  The supported keys are:

    * `:peer_data` - the result of `Plug.Conn.get_peer_data/1`

    * `:trace_context_headers` - a list of all trace context headers

    * `:x_headers` - a list of all request headers that have an "x-" prefix

    * `:uri` - a `%URI{}` derived from the conn

    * `:user_agent` - the value of the "user-agent" request header

    * `:sec_websocket_headers` - a list of all request headers that have a
      "sec-websocket-" prefix

    * `:session` - the connection session information. The CSRF token in it is
      validated by default, set the `:check_csrf` option to `false` to disable
      this check.

  """
  def connect_info(conn, endpoint, keys, opts \\ []) do
    for key <- keys, into: %{} do
      case key do
        :peer_data ->
          {:peer_data, Plug.Conn.get_peer_data(conn)}

        :trace_context_headers ->
          {:trace_context_headers, fetch_trace_context_headers(conn)}

        :x_headers ->
          {:x_headers, fetch_headers(conn, "x-")}

        :uri ->
          {:uri, fetch_uri(conn)}

        :user_agent ->
          {:user_agent, fetch_user_agent(conn)}

        :sec_websocket_headers ->
          {:sec_websocket_headers, fetch_headers(conn, "sec-websocket-")}

        {:session, session} ->
          {:session, connect_session(conn, endpoint, session, opts)}

        :auth_token ->
          {:auth_token, conn.private[:combo_transport_auth_token]}

        {key, val} ->
          {key, val}
      end
    end
  end

  defp connect_session(conn, endpoint, {key, store, {csrf_token_key, init}}, opts) do
    conn = Plug.Conn.fetch_cookies(conn)
    check_csrf = Keyword.get(opts, :check_csrf, true)

    with cookie when is_binary(cookie) <- conn.cookies[key],
         conn = put_in(conn.secret_key_base, endpoint.config(:secret_key_base)),
         {_, session} <- store.get(conn, cookie, init),
         true <- not check_csrf or csrf_token_valid?(conn, session, csrf_token_key) do
      session
    else
      _ -> nil
    end
  end

  defp connect_session(conn, endpoint, {:mfa, {module, function, args}}, opts) do
    case apply(module, function, args) do
      session_config when is_list(session_config) ->
        connect_session(conn, endpoint, init_session(session_config), opts)

      other ->
        raise ArgumentError,
              "the MFA given to `session_config` must return a keyword list, got: #{inspect(other)}"
    end
  end

  defp fetch_headers(conn, prefix) do
    for {header, _} = pair <- conn.req_headers,
        String.starts_with?(header, prefix),
        do: pair
  end

  defp fetch_trace_context_headers(conn) do
    for {header, _} = pair <- conn.req_headers,
        header in ["traceparent", "tracestate"],
        do: pair
  end

  defp fetch_uri(conn) do
    %URI{
      scheme: to_string(conn.scheme),
      query: conn.query_string,
      port: conn.port,
      host: conn.host,
      authority: conn.host,
      path: conn.request_path
    }
  end

  defp fetch_user_agent(conn) do
    with {_, value} <- List.keyfind(conn.req_headers, "user-agent", 0) do
      value
    end
  end

  defp csrf_token_valid?(conn, session, csrf_token_key) do
    with csrf_token when is_binary(csrf_token) <- conn.params["_csrf_token"],
         csrf_state when is_binary(csrf_state) <-
           Plug.CSRFProtection.dump_state_from_session(session[csrf_token_key]) do
      Plug.CSRFProtection.valid_state_and_csrf_token?(csrf_state, csrf_token)
    end
  end

  defp check_origin_config(handler, endpoint, opts) do
    # The same handler may be mounted several times with different
    # :check_origin options, so the option must be part of the cache key.
    # Otherwise the first mount to be reached decides the policy for all
    # of them.
    key = {:socket, handler, :config, :check_origin, Keyword.get(opts, :check_origin)}

    Combo.Socket.Cache.get(endpoint, key, fn ->
      check_origin =
        case Keyword.get(opts, :check_origin, endpoint.config(:check_origin)) do
          origins when is_list(origins) ->
            Enum.map(origins, &parse_origin/1)

          boolean when is_boolean(boolean) ->
            boolean

          {module, function, arguments} ->
            {module, function, arguments}

          :conn ->
            :conn

          invalid ->
            raise ArgumentError,
                  ":check_origin expects a boolean, list of hosts, :conn, or MFA tuple, got: #{inspect(invalid)}"
        end

      {:ok, check_origin}
    end)
  end

  defp parse_origin(origin) do
    case URI.parse(origin) do
      %{host: nil} ->
        raise ArgumentError,
              "invalid :check_origin option: #{inspect(origin)}. " <>
                "Expected an origin with a host that is parsable by URI.parse/1. For example: " <>
                "[\"https://example.com\", \"//another.com:888\", \"//other.com\"]"

      %{scheme: scheme, port: port, host: host} ->
        {scheme, host, port}
    end
  end

  defp origin_allowed?({module, function, arguments}, uri, _endpoint, _conn),
    do: apply(module, function, [uri | arguments])

  defp origin_allowed?(:conn, uri, _endpoint, %Plug.Conn{} = conn) do
    uri.host == conn.host and
      uri.scheme == Atom.to_string(conn.scheme) and
      uri.port == conn.port
  end

  defp origin_allowed?(_check_origin, %{host: nil}, _endpoint, _conn),
    do: false

  defp origin_allowed?(true, uri, endpoint, _conn),
    do: compare?(uri.host, host_to_binary(endpoint.config(:url)[:host]))

  defp origin_allowed?(check_origin, uri, _endpoint, _conn) when is_list(check_origin),
    do: origin_allowed?(uri, check_origin)

  defp origin_allowed?(uri, allowed_origins) do
    %{scheme: origin_scheme, host: origin_host, port: origin_port} = uri

    Enum.any?(allowed_origins, fn {allowed_scheme, allowed_host, allowed_port} ->
      compare?(origin_scheme, allowed_scheme) and
        compare?(origin_port, allowed_port) and
        compare_host?(origin_host, allowed_host)
    end)
  end

  defp compare?(request_val, allowed_val) do
    is_nil(allowed_val) or request_val == allowed_val
  end

  defp compare_host?(_request_host, nil),
    do: true

  defp compare_host?(request_host, "*." <> allowed_host),
    do: request_host == allowed_host or String.ends_with?(request_host, "." <> allowed_host)

  defp compare_host?(request_host, allowed_host),
    do: request_host == allowed_host

  defp host_to_binary(host), do: host
end
