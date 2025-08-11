defmodule Combo.Router.ConsoleFormatter do
  @moduledoc false

  @socket_verb "WS"
  @longpoll_verbs ["GET", "POST"]

  @doc """
  Format the routes for printing.
  """
  def format(router, endpoint \\ nil) do
    routes = router.formatted_routes([])

    column_widths = calculate_column_widths(routes, endpoint)

    IO.iodata_to_binary([
      Enum.map(routes, &format_route(&1, column_widths)),
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

  # TODO: change it to Combo.LiveReloader.Socket
  defp format_websocket({_path, Phoenix.LiveReloader.Socket, _opts}, _), do: ""

  defp format_websocket({path, module, opts}, widths) do
    if opts[:websocket] != false do
      {verb_len, path_len} = widths

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

  # TODO: change it to Combo.LiveReloader.Socket
  defp format_longpoll({_path, Phoenix.LiveReloader.Socket, _opts}, _), do: ""

  defp format_longpoll({path, module, opts}, widths) do
    if opts[:longpoll] != false do
      for method <- @longpoll_verbs, into: "" do
        {verb_len, path_len} = widths

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

  defp format_route(route, column_widths) do
    %{
      verb: verb,
      path: path,
      label: label
    } = route

    verb = verb_name(verb)

    {verb_len, path_len} = column_widths

    String.pad_trailing(verb, verb_len) <>
      "  " <>
      String.pad_trailing(path, path_len) <>
      "  " <>
      label <> "\n"
  end

  defp calculate_column_widths(routes, endpoint) do
    sockets = (endpoint && endpoint.__sockets__()) || []

    widths =
      Enum.reduce(routes, {0, 0}, fn route, acc ->
        %{verb: verb, path: path} = route
        verb = verb_name(verb)
        {verb_len, path_len} = acc

        {max(verb_len, String.length(verb)), max(path_len, String.length(path))}
      end)

    Enum.reduce(sockets, widths, fn {path, _mod, opts}, acc ->
      {verb_len, path_len} = acc

      verb_length =
        socket_verbs(opts)
        |> Enum.map(&String.length/1)
        |> Enum.max(&>=/2, fn -> 0 end)

      {max(verb_len, verb_length), max(path_len, String.length(path <> "/websocket"))}
    end)
  end

  defp verb_name(verb), do: verb |> to_string() |> String.upcase()

  defp socket_verbs(socket_opts) do
    if socket_opts[:longpoll] != false do
      [@socket_verb | @longpoll_verbs]
    else
      [@socket_verb]
    end
  end
end
