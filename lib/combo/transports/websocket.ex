defmodule Combo.Transports.WebSocket do
  @moduledoc """

  ## Options

    * `:timeout` - the number of milliseconds to wait after no client data is
      received before closing the connection
      Defaults to `60_000`.

    * `:compress` - whether to accept negotiation of a compression extension
      with the client.
      Defaults to `false`.

    * `:max_frame_size` - the maximum allowed frame size in bytes. If a frame size
      larger than this is received the connection will be closed
      Defaults to `10_000_000` (10MB).

    * `:fullsweep_after` - the maximum number of garbage collections before
      forcing a fullsweep of the WebSocket connection process.
      You can set it to `0` to force more frequent cleanups.

    * `:subprotocols` - a list of supported websocket subprotocols.
      Used for handshake `Sec-WebSocket-Protocol` response header.
      Defaults to `nil`.

      For example:

          subprotocols: ["sip", "mqtt"]

    * `:error_handler` - custom error handler for connecting errors.
      If `c:Combo.Transport.Handler.connect/3` returns an `{:error, reason}`
      tuple, the error handler will be called with the error reason.
      the error handler must be an MFA tuple that receives a `Plug.Conn`, the
      error reason, and returns a `Plug.Conn` with a response. For example:

          socket "/socket", MyApp.Web.UserSocket,
            websocket: [
              error_handler: {MyApp.Web.UserSocket, :handle_error, []}
            ]

      and a `{:error, :rate_limit}` return may be handled on `MyApp.Web.UserSocket` as:

          def handle_error(conn, :rate_limit) do
            Plug.Conn.send_resp(conn, 429, "Too many requests")
          end

  """

  # How WebSockets work in Combo
  #
  # WebSocket support is implemented on top of the `WebSockAdapter` library. Upgrade
  # requests from clients originate as regular HTTP requests that get routed to this module via
  # Plug. These requests are then upgraded to WebSocket connections via
  # `WebSockAdapter.upgrade/4`, which takes as an argument the handler for a given socket endpoint
  # as configured in the application's Endpoint. This handler module must implement the
  # transport-agnostic `Combo.Transport.Handler` behaviour (this same behaviour is also used for
  # other transports such as long polling). Because this behaviour is a superset of the `WebSock`
  # behaviour, the `WebSock` library is able to use the callbacks in the `WebSock` behaviour to
  # call this handler module directly for the rest of the WebSocket connection's lifetime.

  @behaviour Combo.Transport
  require Logger

  @connect_info_opts [:check_csrf]

  @auth_token_prefix "base64url.bearer.combo."

  import Plug.Conn

  alias Combo.Transport

  @impl true
  def default_config do
    [
      transport_log: false,
      error_handler: {__MODULE__, :handle_error, []},
      timeout: 60_000,
      compress: false
    ]
  end

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{method: "GET"} = conn, {endpoint, handler, opts}) do
    opts = Transport.merge_config(endpoint, opts)

    subprotocols =
      if opts[:auth_token] do
        # when using Sec-WebSocket-Protocol for passing an auth token
        # the server must reply with one of the subprotocols in the request;
        # therefore we include "combo" as allowed subprotocol and include it on the client
        ["combo" | Keyword.get(opts, :subprotocols, [])]
      else
        opts[:subprotocols]
      end

    conn
    |> fetch_query_params()
    |> Transport.code_reload(endpoint, opts)
    |> Transport.transport_log(opts[:transport_log])
    |> Transport.check_origin(handler, endpoint, opts)
    |> maybe_auth_token_from_header(opts[:auth_token])
    |> check_subprotocols(subprotocols)
    |> case do
      %{halted: true} = conn ->
        conn

      %{params: params} = conn ->
        keys = Keyword.get(opts, :connect_info, [])

        connect_info =
          Transport.connect_info(conn, endpoint, keys, Keyword.take(opts, @connect_info_opts))

        config = %{
          endpoint: endpoint,
          transport: :websocket,
          options: opts,
          params: params,
          connect_info: connect_info
        }

        case handler.connect(config) do
          {:ok, arg} ->
            try do
              conn
              |> WebSockAdapter.upgrade(handler, arg, opts)
              |> halt()
            rescue
              e in WebSockAdapter.UpgradeError -> send_resp(conn, 400, e.message)
            end

          :error ->
            send_resp(conn, 403, "")

          {:error, reason} ->
            {m, f, args} = opts[:error_handler]
            apply(m, f, [conn, reason | args])
        end
    end
  end

  def call(conn, _), do: send_resp(conn, 400, "")

  def handle_error(conn, _reason), do: send_resp(conn, 403, "")

  @doc false
  def check_subprotocols(conn, subprotocols)

  def check_subprotocols(%Plug.Conn{halted: true} = conn, _subprotocols), do: conn
  def check_subprotocols(conn, nil), do: conn

  def check_subprotocols(conn, subprotocols) when is_list(subprotocols) do
    case get_req_header(conn, "sec-websocket-protocol") do
      [] ->
        conn

      [subprotocols_header | _] ->
        request_subprotocols = Plug.Conn.Utils.list(subprotocols_header)

        subprotocol =
          Enum.find(subprotocols, fn elem ->
            Enum.find(request_subprotocols, &(&1 == elem))
          end)

        if subprotocol do
          put_resp_header(conn, "sec-websocket-protocol", subprotocol)
        else
          subprotocols_error_response(conn, subprotocols)
        end
    end
  end

  def check_subprotocols(conn, subprotocols) do
    subprotocols_error_response(conn, subprotocols)
  end

  defp subprotocols_error_response(conn, subprotocols) do
    request_headers = get_req_header(conn, "sec-websocket-protocol")

    Logger.error("""
    Could not negotiate a WebSocket subprotocol for a transport connection.

    Subprotocols of the request: #{inspect(request_headers)}
    Configured supported subprotocols: #{inspect(subprotocols)}

    This happens when the requested subprotocols do not match the ones
    configured for the transport, or when the supported subprotocols are
    not configured correctly.

    To fix this issue, you may either:

      1. update websocket: [subprotocols: [..]] to the subprotocols supported
         by your transport.

      2. check the correctness of the `sec-websocket-protocol` request header
         sent from the client.

      3. remove the `:subprotocols` option from your WebSocket transport
         configuration if you don't use WebSocket subprotocols.

    """)

    conn
    |> resp(:forbidden, "")
    |> send_resp()
    |> halt()
  end

  defp maybe_auth_token_from_header(conn, true) do
    case get_req_header(conn, "sec-websocket-protocol") do
      [] ->
        conn

      [subprotocols_header | _] ->
        request_subprotocols =
          subprotocols_header
          |> Plug.Conn.Utils.list()
          |> Enum.split_with(&String.starts_with?(&1, @auth_token_prefix))

        case request_subprotocols do
          {[@auth_token_prefix <> encoded_auth_token], actual_subprotocols} ->
            auth_token = Base.decode64!(encoded_auth_token, padding: false)

            conn
            |> put_private(:combo_transport_auth_token, auth_token)
            |> set_actual_subprotocols(actual_subprotocols)

          _ ->
            conn
        end
    end
  end

  defp maybe_auth_token_from_header(conn, _), do: conn

  defp set_actual_subprotocols(conn, []), do: delete_req_header(conn, "sec-websocket-protocol")

  defp set_actual_subprotocols(conn, subprotocols),
    do: put_req_header(conn, "sec-websocket-protocol", Enum.join(subprotocols, ", "))
end
