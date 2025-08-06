defmodule Combo.Logger do
  @moduledoc """
  Instrumenter to handle logging of various instrumentation events.

  ## Instrumentation

  Combo uses the `:telemetry` library for instrumentation. The following events
  are published by Combo with the following measurements and metadata:

    * `[:combo, :endpoint, :init]` - dispatched by `Combo.Endpoint` after your
      Endpoint supervision tree successfully starts
      * Measurement: `%{system_time: system_time}`
      * Metadata: `%{pid: pid(), config: Keyword.t(), module: module(), otp_app: atom()}`
      * Disable logging: This event is not logged

    * `[:combo, :endpoint, :start]` - dispatched by `Plug.Telemetry` in your endpoint,
      usually after code reloading
      * Measurement: `%{system_time: system_time}`
      * Metadata: `%{conn: Plug.Conn.t, options: Keyword.t}`
      * Options: `%{log: Logger.level | false}`
      * Disable logging: In your endpoint `plug Plug.Telemetry, ..., log: Logger.level | false`
      * Configure log level dynamically: `plug Plug.Telemetry, ..., log: {Mod, Fun, Args}`

    * `[:combo, :endpoint, :stop]` - dispatched by `Plug.Telemetry` in your
      endpoint whenever the response is sent
      * Measurement: `%{duration: native_time}`
      * Metadata: `%{conn: Plug.Conn.t, options: Keyword.t}`
      * Options: `%{log: Logger.level | false}`
      * Disable logging: In your endpoint `plug Plug.Telemetry, ..., log: Logger.level | false`
      * Configure log level dynamically: `plug Plug.Telemetry, ..., log: {Mod, Fun, Args}`

    * `[:combo, :router_dispatch, :start]` - dispatched by `Combo.Router`
      before dispatching to a matched route
      * Measurement: `%{system_time: System.system_time}`
      * Metadata: `%{conn: Plug.Conn.t, route: binary, plug: module, plug_opts: term, path_params: map, pipe_through: [atom], log: Logger.level | false}`
      * Disable logging: Pass `log: false` to the router macro, for example: `get("/page", PageController, :index, log: false)`
      * Configure log level dynamically: `get("/page", PageController, :index, log: {Mod, Fun, Args})`

    * `[:combo, :router_dispatch, :exception]` - dispatched by `Combo.Router`
      after exceptions on dispatching a route
      * Measurement: `%{duration: native_time}`
      * Metadata: `%{conn: Plug.Conn.t, kind: :throw | :error | :exit, reason: term(), stacktrace: Exception.stacktrace()}`
      * Disable logging: This event is not logged

    * `[:combo, :router_dispatch, :stop]` - dispatched by `Combo.Router`
      after successfully dispatching a matched route
      * Measurement: `%{duration: native_time}`
      * Metadata: `%{conn: Plug.Conn.t, route: binary, plug: module, plug_opts: term, path_params: map, pipe_through: [atom], log: Logger.level | false}`
      * Disable logging: This event is not logged

    * `[:combo, :error_rendered]` - dispatched at the end of an error view being rendered
      * Measurement: `%{duration: native_time}`
      * Metadata: `%{conn: Plug.Conn.t, status: Plug.Conn.status, kind: Exception.kind, reason: term, stacktrace: Exception.stacktrace}`
      * Disable logging: Set `render_errors: [log: false]` on your endpoint configuration

    * `[:combo, :socket_connected]` - dispatched by `Combo.Socket`, at the end of a socket connection
      * Measurement: `%{duration: native_time}`
      * Metadata: `%{endpoint: atom, transport: atom, params: term, connect_info: map, vsn: binary, user_socket: atom, result: :ok | :error, serializer: atom, log: Logger.level | false}`
      * Disable logging: `use Combo.Socket, log: false` or `socket "/foo", MySocket, websocket: [log: false]` in your endpoint

    * `[:combo, :socket_drain]` - dispatched by `Combo.Socket` when using the `:drainer` option
      * Measurement: `%{count: integer, total: integer, index: integer, rounds: integer}`
      * Metadata: `%{endpoint: atom, socket: atom, intervasl: integer, log: Logger.level | false}`
      * Disable logging: `use Combo.Socket, log: false` in your endpoint or pass `:log` option in the `:drainer` option

    * `[:combo, :channel_joined]` - dispatched at the end of a channel join
      * Measurement: `%{duration: native_time}`
      * Metadata: `%{result: :ok | :error, params: term, socket: Combo.Socket.t}`
      * Disable logging: This event cannot be disabled

    * `[:combo, :channel_handled_in]` - dispatched at the end of a channel handle in
      * Measurement: `%{duration: native_time}`
      * Metadata: `%{event: binary, params: term, socket: Combo.Socket.t}`
      * Disable logging: This event cannot be disabled

  ## Parameter filtering

  When logging parameters, Combo can filter out sensitive parameters such as
  passwords and tokens. Parameters to be filtered can be added via the
  `:filter_parameters` option:

      config :combo, :filter_parameters, ["password", "secret"]

  With the configuration above, Combo will filter any parameter that
  contains the terms `password` or `secret`. The match is case sensitive.

  Combo's default is `["password"]`.

  Combo can also filter all parameters by default and selectively keep
  parameters. This can be configured like:

      config :combo, :filter_parameters, {:keep, ["id", "order"]}

  With the configuration above, Combo will filter all parameters, except
  those that match exactly `id` or `order`. If a kept parameter matches,
  all parameters nested under that one will also be kept.

  ## Dynamic log level

  In some cases you may wish to set the log level dynamically on a
  per-request basis. To do so, set the `:log` option to a tuple,
  `{Mod, Fun, Args}`. The `Plug.Conn.t()` for the request will be
  prepended to the provided list of arguments.

  When invoked, your function must return a
  [`Logger.level()`](`t:Logger.level()/0`) or `false` to disable logging
  for the request.

  For example, in your Endpoint you might do something like this:

        # lib/demo_web/endpoint.ex
        plug Plug.Telemetry,
          event_prefix: [:combo, :endpoint],
          log: {__MODULE__, :log_level, []}

        # Disables logging for routes like /status/*
        def log_level(%{path_info: ["status" | _]}), do: false
        def log_level(_), do: :info

  ## Disabling

  When you are using custom logging system it is not always desirable to
  enable `#{inspect(__MODULE__)}` by default. You can always disable this
  in general by:

      config :combo, :logger, false

  """

  require Logger

  @doc false
  def install do
    handlers = %{
      [:combo, :endpoint, :start] => &__MODULE__.combo_endpoint_start/4,
      [:combo, :endpoint, :stop] => &__MODULE__.combo_endpoint_stop/4,
      [:combo, :router_dispatch, :start] => &__MODULE__.combo_router_dispatch_start/4,
      [:combo, :error_rendered] => &__MODULE__.combo_error_rendered/4,
      [:combo, :socket_connected] => &__MODULE__.combo_socket_connected/4,
      [:combo, :socket_drain] => &__MODULE__.combo_socket_drain/4,
      [:combo, :channel_joined] => &__MODULE__.combo_channel_joined/4,
      [:combo, :channel_handled_in] => &__MODULE__.combo_channel_handled_in/4
    }

    for {key, fun} <- handlers do
      :telemetry.attach({__MODULE__, key}, key, fun, :ok)
    end
  end

  @doc false
  def duration(duration) do
    duration = System.convert_time_unit(duration, :native, :microsecond)

    if duration > 1000 do
      [duration |> div(1000) |> Integer.to_string(), "ms"]
    else
      [Integer.to_string(duration), "µs"]
    end
  end

  @doc false
  def compile_filter({:compiled, _key, _value} = filter), do: filter
  def compile_filter({:discard, params}), do: compile_discard(params)
  def compile_filter({:keep, params}), do: {:keep, params}
  def compile_filter(params), do: compile_discard(params)

  defp compile_discard([]) do
    {:compiled, [], []}
  end

  defp compile_discard(params) when is_list(params) or is_binary(params) do
    key_match = :binary.compile_pattern(params)
    value_match = params |> List.wrap() |> Enum.map(&(&1 <> "=")) |> :binary.compile_pattern()
    {:compiled, key_match, value_match}
  end

  @doc false
  def filter_values(values, filter \\ Application.get_env(:phoenix, :filter_parameters, [])) do
    case compile_filter(filter) do
      {:compiled, key_match, value_match} -> discard_values(values, key_match, value_match)
      {:keep, match} -> keep_values(values, match)
    end
  end

  defp discard_values(%{__struct__: mod} = struct, _key_match, _value_match) when is_atom(mod) do
    struct
  end

  defp discard_values(%{} = map, key_match, value_match) do
    Enum.into(map, %{}, fn {k, v} ->
      cond do
        is_binary(k) and String.contains?(k, key_match) ->
          {k, "[FILTERED]"}

        is_binary(v) and String.contains?(v, value_match) ->
          {k, "[FILTERED]"}

        true ->
          {k, discard_values(v, key_match, value_match)}
      end
    end)
  end

  defp discard_values([_ | _] = list, key_match, value_match) do
    Enum.map(list, &discard_values(&1, key_match, value_match))
  end

  defp discard_values(other, _key_match, _value_match), do: other

  defp keep_values(%{__struct__: mod}, _match) when is_atom(mod), do: "[FILTERED]"

  defp keep_values(%{} = map, match) do
    Enum.into(map, %{}, fn {k, v} ->
      if is_binary(k) and k in match do
        {k, v}
      else
        {k, keep_values(v, match)}
      end
    end)
  end

  defp keep_values([_ | _] = list, match) do
    Enum.map(list, &keep_values(&1, match))
  end

  defp keep_values(_other, _match), do: "[FILTERED]"

  defp log_level(nil, _conn), do: :info
  defp log_level(level, _conn) when is_atom(level), do: level

  defp log_level({mod, fun, args}, conn) when is_atom(mod) and is_atom(fun) and is_list(args) do
    apply(mod, fun, [conn | args])
  end

  ## Event: [:combo, :endpoint, *]

  @doc false
  def combo_endpoint_start(_, _, %{conn: conn} = metadata, _) do
    case log_level(metadata[:options][:log], conn) do
      false ->
        :ok

      level ->
        Logger.log(level, fn ->
          %{method: method, request_path: request_path} = conn
          [method, ?\s, request_path]
        end)
    end
  end

  @doc false
  def combo_endpoint_stop(_, %{duration: duration}, %{conn: conn} = metadata, _) do
    case log_level(metadata[:options][:log], conn) do
      false ->
        :ok

      level ->
        Logger.log(level, fn ->
          %{status: status, state: state} = conn
          status = status_to_string(status)
          [connection_type(state), ?\s, status, " in ", duration(duration)]
        end)
    end
  end

  defp connection_type(:set_chunked), do: "Chunked"
  defp connection_type(_), do: "Sent"

  ## Event: [:combo, :error_rendered]

  @doc false
  def combo_error_rendered(_, _, %{log: false}, _), do: :ok

  def combo_error_rendered(_, _, %{log: level, status: status, kind: kind, reason: reason}, _) do
    Logger.log(level, fn ->
      [
        "Converted ",
        Atom.to_string(kind),
        ?\s,
        error_banner(kind, reason),
        " to ",
        status_to_string(status),
        " response"
      ]
    end)
  end

  defp status_to_string(status) do
    status |> Plug.Conn.Status.code() |> Integer.to_string()
  end

  defp error_banner(:error, %type{}), do: inspect(type)
  defp error_banner(_kind, reason), do: inspect(reason)

  ## Event: [:combo, :router_dispatch, :start]

  @doc false
  def combo_router_dispatch_start(_, _, %{log: false}, _), do: :ok

  def combo_router_dispatch_start(_, _, metadata, _) do
    %{log: level, conn: conn, plug: plug} = metadata
    level = log_level(level, conn)

    Logger.log(level, fn ->
      %{
        pipe_through: pipe_through,
        plug_opts: plug_opts
      } = metadata

      log_mfa =
        case metadata[:mfa] do
          {mod, fun, arity} -> mfa(mod, fun, arity)
          _ when is_atom(plug_opts) -> mfa(plug, plug_opts, 2)
          _ -> inspect(plug)
        end

      [
        "Processing with ",
        log_mfa,
        ?\n,
        "  Parameters: ",
        params(conn.params),
        ?\n,
        "  Pipelines: ",
        inspect(pipe_through)
      ]
    end)
  end

  defp mfa(mod, fun, arity),
    do: [inspect(mod), ?., Atom.to_string(fun), ?/, arity + ?0]

  defp params(%Plug.Conn.Unfetched{}), do: "[UNFETCHED]"
  defp params(params), do: params |> filter_values() |> inspect()

  ## Event: [:combo, :socket_connected]

  @doc false
  def combo_socket_connected(_, _, %{log: false}, _), do: :ok

  def combo_socket_connected(_, %{duration: duration}, %{log: level} = meta, _) do
    Logger.log(level, fn ->
      %{
        transport: transport,
        params: params,
        user_socket: user_socket,
        result: result,
        serializer: serializer
      } = meta

      [
        connect_result(result),
        inspect(user_socket),
        " in ",
        duration(duration),
        "\n  Transport: ",
        inspect(transport),
        "\n  Serializer: ",
        inspect(serializer),
        "\n  Parameters: ",
        inspect(filter_values(params))
      ]
    end)
  end

  defp connect_result(:ok), do: "CONNECTED TO "
  defp connect_result(:error), do: "REFUSED CONNECTION TO "

  @doc false
  def combo_socket_drain(_, _, %{log: false}, _), do: :ok

  def combo_socket_drain(
        _,
        %{count: count, total: total, index: index, rounds: rounds},
        %{log: level} = meta,
        _
      ) do
    Logger.log(level, fn ->
      %{socket: socket, interval: interval} = meta

      [
        "DRAINING #{count} of #{total} total connection(s) for socket ",
        inspect(socket),
        " every #{interval}ms - ",
        "round #{index} of #{rounds}"
      ]
    end)
  end

  ## Event: [:combo, :channel_joined]

  @doc false
  def combo_channel_joined(_, %{duration: duration}, %{socket: socket} = metadata, _) do
    channel_log(:log_join, socket, fn ->
      %{result: result, params: params} = metadata

      [
        join_result(result),
        socket.topic,
        " in ",
        duration(duration),
        "\n  Parameters: ",
        inspect(filter_values(params))
      ]
    end)
  end

  defp join_result(:ok), do: "JOINED "
  defp join_result(:error), do: "REFUSED JOIN "

  ## Event: [:combo, :channel_handle_in]

  @doc false
  def combo_channel_handled_in(_, %{duration: duration}, %{socket: socket} = metadata, _) do
    channel_log(:log_handle_in, socket, fn ->
      %{event: event, params: params} = metadata

      [
        "HANDLED ",
        event,
        " INCOMING ON ",
        socket.topic,
        " (",
        inspect(socket.channel),
        ") in ",
        duration(duration),
        "\n  Parameters: ",
        inspect(filter_values(params))
      ]
    end)
  end

  defp channel_log(_log_option, %{topic: "combo" <> _}, _fun), do: :ok

  defp channel_log(log_option, %{private: private}, fun) do
    if level = Map.get(private, log_option) do
      Logger.log(level, fun)
    end
  end
end
