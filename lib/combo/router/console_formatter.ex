defmodule Combo.Router.ConsoleFormatter do
  @moduledoc false

  @socket_verb "WS"
  @longpoll_verbs ["GET", "POST"]

  @doc """
  Format the routes for printing.
  """
  def format(router, endpoint \\ nil) do
    routes = Combo.Router.routes(router)
    column_widths = calculate_column_widths(router, routes, endpoint)

    IO.iodata_to_binary([
      Enum.map(routes, &format_route(&1, router, column_widths)),
      format_endpoint(endpoint, column_widths)
    ])
  end

  defp format_endpoint(nil, _router), do: ""

  defp format_endpoint(endpoint, widths) do
    case endpoint.__sockets__() do
      [] ->
        ""

      sockets ->
        Enum.map(sockets, fn socket ->
          [format_websocket(socket, widths), format_longpoll(socket, widths)]
        end)
    end
  end

  defp format_websocket({_path, Combo.LiveReloader.Socket, _opts}, _), do: ""

  defp format_websocket({path, module, opts}, widths) do
    if opts[:websocket] != false do
      {name_len, verb_len, path_len} = widths

      String.duplicate(" ", name_len) <>
        "  " <>
        String.pad_trailing(@socket_verb, verb_len) <>
        "  " <>
        String.pad_trailing(path <> "/websocket", path_len) <>
        "  " <>
        inspect(module) <>
        "\n"
    else
      ""
    end
  end

  defp format_longpoll({_path, Combo.LiveReloader.Socket, _opts}, _), do: ""

  defp format_longpoll({path, module, opts}, widths) do
    if opts[:longpoll] != false do
      for method <- @longpoll_verbs, into: "" do
        {name_len, verb_len, path_len} = widths

        String.duplicate(" ", name_len) <>
          "  " <>
          String.pad_trailing(method, verb_len) <>
          "  " <>
          String.pad_trailing(path <> "/longpoll", path_len) <>
          "  " <>
          inspect(module) <>
          "\n"
      end
    else
      ""
    end
  end

  defp calculate_column_widths(router, routes, endpoint) do
    sockets = (endpoint && endpoint.__sockets__()) || []

    widths =
      Enum.reduce(routes, {0, 0, 0}, fn route, {name_len, verb_len, path_len} ->
        %{name: name, verb: verb, path: path} = route
        name = build_name(name)
        verb = build_verb(verb)

        {
          max(name_len, String.length(name)),
          max(verb_len, String.length(verb)),
          max(path_len, String.length(path))
        }
      end)

    Enum.reduce(sockets, widths, fn {path, _mod, opts}, {name_len, verb_len, path_len} ->
      current_verb_len =
        socket_verbs(opts)
        |> Enum.map(&String.length/1)
        |> Enum.max(&>=/2, fn -> 0 end)

      current_path_len = String.length(path <> "/websocket")

      {
        name_len,
        max(verb_len, current_verb_len),
        max(path_len, current_path_len)
      }
    end)
  end

  defp format_route(route, router, column_widths) do
    %{
      name: name,
      verb: verb,
      path: path,
      plug: plug,
      plug_opts: plug_opts
    } = route

    name = build_name(name)
    verb = build_verb(verb)

    {name_len, verb_len, path_len} = column_widths

    String.pad_leading(name, name_len) <>
      "  " <>
      String.pad_trailing(verb, verb_len) <>
      "  " <>
      String.pad_trailing(path, path_len) <>
      "  " <>
      "#{inspect(plug)} #{inspect(plug_opts)}\n"
  end

  defp build_name(nil), do: ""
  defp build_name(name), do: name

  defp build_verb(verb), do: verb |> to_string() |> String.upcase()

  defp socket_verbs(socket_opts) do
    if socket_opts[:longpoll] != false do
      [@socket_verb | @longpoll_verbs]
    else
      [@socket_verb]
    end
  end
end
