defmodule Combo.Endpoint.RenderErrors do
  @moduledoc false
  # This module is used to catch failures and render them using views.
  #
  # This module is automatically used in `Combo.Endpoint` where it overrides
  # `call/2` to provide rendering. Once the error is rendered, the error is
  # reraised unless it is a `NoRouteError`.
  #
  # ## Options
  #
  #   * `:layout`  - optional, it will be passed to `put_layout/2`
  #   * `:formats` - required, it will be passed to `put_view/2`
  #   * `:log` - optional, the `t:Logger.level/0` or `false` to disable
  #     logging rendered errors

  import Plug.Conn,
    only: [
      fetch_query_params: 1,
      put_status: 2
    ]

  import Combo.Conn,
    only: [
      accepts: 2,
      put_format: 2,
      get_format: 1,
      put_layout: 2,
      put_view: 2,
      view_module: 2,
      render: 3
    ]

  require Logger

  alias Combo.Router.NoRouteError

  @already_sent {:plug_conn, :sent}

  @doc false
  defmacro __using__(opts) do
    quote do
      @before_compile Combo.Endpoint.RenderErrors
      @combo_endpoint_render_errors_opts unquote(opts)
    end
  end

  @doc false
  defmacro __before_compile__(_) do
    quote location: :keep do
      defoverridable call: 2

      def call(conn, opts) do
        try do
          super(conn, opts)
        rescue
          e in Plug.Conn.WrapperError ->
            %{conn: conn, kind: kind, reason: reason, stack: stack} = e

            unquote(__MODULE__).__catch__(
              conn,
              kind,
              reason,
              stack,
              @combo_endpoint_render_errors_opts
            )
        catch
          kind, reason ->
            stack = __STACKTRACE__

            unquote(__MODULE__).__catch__(
              conn,
              kind,
              reason,
              stack,
              @combo_endpoint_render_errors_opts
            )
        end
      end
    end
  end

  @doc false
  def __catch__(%Plug.Conn{} = conn, kind, reason, stack, opts) do
    conn =
      receive do
        @already_sent ->
          send(self(), @already_sent)
          %{conn | state: :sent}
      after
        0 ->
          instrument_render_and_send(conn, kind, reason, stack, opts)
      end

    maybe_raise(kind, reason, stack)
    conn
  end

  defp instrument_render_and_send(conn, kind, reason, stack, opts) do
    level = Keyword.get(opts, :log, :debug)
    status = status(kind, reason)
    conn = error_conn(conn, kind, reason)
    start = System.monotonic_time()

    metadata = %{
      conn: conn,
      status: status,
      kind: kind,
      reason: reason,
      stacktrace: stack,
      log: level
    }

    try do
      render(conn, status, kind, reason, stack, opts)
    after
      duration = System.monotonic_time() - start
      :telemetry.execute([:combo, :error_rendered], %{duration: duration}, metadata)
    end
  end

  defp maybe_raise(:error, %NoRouteError{}, _stack), do: :ok
  defp maybe_raise(kind, reason, stack), do: :erlang.raise(kind, reason, stack)

  defp status(:error, error), do: Plug.Exception.status(error)
  defp status(:throw, _throw), do: 500
  defp status(:exit, _exit), do: 500

  defp error_conn(_conn, :error, %NoRouteError{conn: conn}), do: conn
  defp error_conn(conn, _kind, _reason), do: conn

  ## Rendering

  @doc false
  def __debugger_banner__(_conn, _status, _kind, %NoRouteError{router: router}, _stack) do
    """
    <h3>Available routes</h3>
    <pre>#{Combo.Router.ConsoleFormatter.format(router)}</pre>
    """
  end

  def __debugger_banner__(_conn, _status, _kind, _reason, _stack), do: nil

  defp render(conn, status, kind, reason, stack, opts) do
    layout = opts[:layout] || []
    formats = opts[:formats]

    case formats do
      [_ | _] ->
        :pass

      _ ->
        raise ArgumentError, """
        expected :formats option of :render_errors to be:

            [{format(), view()}, ...]

        Got:

            #{inspect(formats)}
        """
    end

    conn =
      conn
      |> maybe_fetch_query_params()
      |> put_layout(layout)
      |> put_view(formats)
      |> detect_format(formats)
      |> put_status(status)

    format = get_format(conn)
    reason = Exception.normalize(kind, reason, stack)
    template = "#{conn.status}.#{format}"
    assigns = %{kind: kind, reason: reason, stack: stack, status: conn.status}

    render(conn, template, assigns)
  end

  defp maybe_fetch_query_params(%Plug.Conn{} = conn) do
    fetch_query_params(conn)
  rescue
    Plug.Conn.InvalidQueryError ->
      case conn.params do
        %Plug.Conn.Unfetched{} -> %{conn | query_params: %{}, params: %{}}
        params -> %{conn | query_params: %{}, params: params}
      end
  end

  defp detect_format(conn, formats) do
    try do
      conn =
        if get_format(conn) do
          conn
        else
          accepted = Enum.map(formats, &to_string(elem(&1, 0)))
          accepts(conn, accepted)
        end

      format = get_format(conn)
      supported_format? = !!view_module(conn, format)

      if supported_format? do
        conn
      else
        [{fallback_format, _} | _] = formats

        Logger.debug("""
        Could not render errors due unsupported format #{inspect(format)}. \
        Errors will be rendered using the first accepted format #{inspect(fallback_format)} \
        as fallback. If you want to support other formats or choose another fallback, please \
        customize the :formats option under the :render_errors configuration in your endpoint \
        """)

        put_format(conn, fallback_format)
      end
    rescue
      e in Combo.NotAcceptableError ->
        [{fallback_format, _} | _] = formats

        Logger.debug("""
        Could not render errors due to #{Exception.message(e)}. \
        Errors will be rendered using the first accepted format #{inspect(fallback_format)} \
        as fallback. If you want to support other formats or choose another fallback, please \
        customize the :formats option under the :render_errors configuration in your endpoint \
        """)

        put_format(conn, fallback_format)
    end
  end
end
