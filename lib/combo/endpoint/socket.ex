defmodule Combo.Endpoint.Socket do
  @moduledoc false

  @socket_acc :combo_sockets
  @socket_dispatcher :socket_dispatcher

  # Collect socket declarations, then compile them once the endpoint is complete.
  # The generated functions live in the endpoint, which controls plug ordering.
  def setup do
    quote do
      Module.register_attribute(__MODULE__, unquote(@socket_acc), accumulate: true)
    end
  end

  def add_socket(path, module, opts, caller) do
    # Expand module in a function context to avoid a compile-time dependency.
    module = Macro.expand(module, %{caller | function: {@socket_dispatcher, 2}})

    quote do
      Module.put_attribute(
        __MODULE__,
        unquote(@socket_acc),
        {unquote(path), unquote(module), unquote(opts)}
      )
    end
  end

  def compile(endpoint) do
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

  def plug, do: @socket_dispatcher

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
end
