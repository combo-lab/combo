defmodule Combo.URLBuilder do
  @moduledoc """
  Builds url or path.
  """

  @doc """
  Builds an url.

  ## Examples

      iex> url(conn, "/posts")
      "https://example.com/posts"

      iex> url(conn, "/posts", page: 1)
      "https://example.com/posts?page=1"

  """
  def url(endpoint_or_conn_or_socket, path, params \\ %{})
      when is_binary(path) and (is_map(params) or is_list(params)) do
    guarded_url(endpoint_or_conn_or_socket, path, params)
  end

  defp guarded_url(%Plug.Conn{private: private}, path, params) do
    case private do
      %{combo_router_url: url} when is_binary(url) -> concat_url(url, path, params)
      %{combo_endpoint: endpoint} -> concat_url(endpoint.url(), path, params)
    end
  end

  defp guarded_url(%Combo.Socket{endpoint: endpoint}, path, params) do
    concat_url(endpoint.url(), path, params)
  end

  defp guarded_url(endpoint, path, params) when is_atom(endpoint) do
    concat_url(endpoint.url(), path, params)
  end

  defp guarded_url(other, path, _params) do
    raise ArgumentError, """
    expected a %Plug.Conn{}, a %Combo.Socket{} or a Combo.Endpoint \
    when building url at #{path}, got: #{inspect(other)}\
    """
  end

  @doc """
  Builds a path with relevant script name.

  ## Examples

      iex> path(conn, MyApp.Web.Router, "/posts")
      "/posts"

      iex> path(conn, MyApp.Web.Router, "/posts", page: 1)
      "/posts?page=1"

  """
  def path(endpoint_or_conn_or_socket, router, path, params \\ %{})
      when is_atom(router) and is_binary(path) and (is_map(params) or is_list(params)) do
    guarded_path(endpoint_or_conn_or_socket, router, path, params)
  end

  defp guarded_path(%Plug.Conn{} = conn, router, path, params) do
    conn
    |> build_own_forward_path(router, path)
    |> Kernel.||(build_conn_forward_path(conn, router, path))
    |> Kernel.||(path_with_script(path, conn.script_name))
    |> append_params(params)
  end

  defp guarded_path(%Combo.Socket{endpoint: endpoint}, _router, path, params) do
    endpoint.path(path) |> append_params(params)
  end

  defp guarded_path(endpoint, _router, path, params) when is_atom(endpoint) do
    endpoint.path(path) |> append_params(params)
  end

  defp guarded_path(other, router, _path, _params) do
    raise ArgumentError, """
    expected a %Plug.Conn{}, a %Combo.Socket{} or a Combo.Endpoint \
    when building path for #{inspect(router)}, got: #{inspect(other)}\
    """
  end

  defp build_own_forward_path(%Plug.Conn{} = conn, router, path) do
    case conn.private do
      %{^router => local_script} when is_list(local_script) ->
        path_with_script(path, local_script)

      %{} ->
        nil
    end
  end

  defp build_conn_forward_path(%Plug.Conn{} = conn, router, path) do
    with %{combo_router: combo_router} <- conn.private,
         %{^combo_router => script_name} when is_list(script_name) <- conn.private,
         local_script when is_list(local_script) <- combo_router.__forward__(router) do
      path_with_script(path, script_name ++ local_script)
    else
      _ -> nil
    end
  end

  defp path_with_script(path, []), do: path
  defp path_with_script(path, script), do: "/" <> Enum.join(script, "/") <> path

  @doc """
  Builds the url to a static asset given its file path.

  See `c:Combo.Endpoint.static_url/0` and `c:Combo.Endpoint.static_path/1` for
  more information.

  ## Examples

      iex> static_url(conn, "/assets/js/app.js")
      "https://example.com/assets/js/app-813dfe33b5c7f8388bccaaa38eec8382.js"

      iex> static_url(socket, "/assets/js/app.js")
      "https://example.com/assets/js/app-813dfe33b5c7f8388bccaaa38eec8382.js"

      iex> static_url(MyApp.Web.Endpoint, "/assets/js/app.js")
      "https://example.com/assets/js/app-813dfe33b5c7f8388bccaaa38eec8382.js"

  """
  def static_url(endpoint_or_conn_or_socket, path) when is_binary(path) do
    guarded_static_url(endpoint_or_conn_or_socket, path)
  end

  def guarded_static_url(%Plug.Conn{private: private}, path) do
    case private do
      %{combo_static_url: static_url} -> concat_url(static_url, path)
      %{combo_endpoint: endpoint} -> static_url(endpoint, path)
    end
  end

  def guarded_static_url(%Combo.Socket{endpoint: endpoint}, path) do
    static_url(endpoint, path)
  end

  def guarded_static_url(endpoint, path) when is_atom(endpoint) do
    endpoint.static_url() <> endpoint.static_path(path)
  end

  def guarded_static_url(other, path) do
    raise ArgumentError, """
    expected a %Plug.Conn{}, a %Combo.Socket{} or a Combo.Endpoint \
    when building static url for #{path}, got: #{inspect(other)}\
    """
  end

  @doc """
  Builds the path to a static asset given its file path.

  See `c:Combo.Endpoint.static_path/1` for more information.

  ## Examples

      iex> static_path(conn, "/assets/js/app.js")
      "/assets/js/app-813dfe33b5c7f8388bccaaa38eec8382.js"

      iex> static_path(socket, "assets/js/app.js")
      "/assets/js/app-813dfe33b5c7f8388bccaaa38eec8382.js"

      iex> static_path(MyApp.Web.Endpoint, "assets/js/app.js")
      "/assets/js/app-813dfe33b5c7f8388bccaaa38eec8382.js"

  """
  def static_path(endpoint_or_conn_or_socket, path) when is_binary(path) do
    guarded_static_path(endpoint_or_conn_or_socket, path)
  end

  defp guarded_static_path(%Plug.Conn{private: private}, path) do
    case private do
      %{combo_static_url: _} -> path
      %{combo_endpoint: endpoint} -> endpoint.static_path(path)
    end
  end

  defp guarded_static_path(%Combo.Socket{endpoint: endpoint}, path) do
    endpoint.static_path(path)
  end

  defp guarded_static_path(endpoint, path) when is_atom(endpoint) do
    endpoint.static_path(path)
  end

  defp guarded_static_path(other, path) do
    raise ArgumentError, """
    expected a %Plug.Conn{}, a %Combo.Socket{} or a Combo.Endpoint \
    when building static path for #{path}, got: #{inspect(other)}\
    """
  end

  @doc """
  Builds the integrity hash to a static asset given its file path.

  See `c:Combo.Endpoint.static_integrity/1` for more information.

  ## Examples

      iex> static_integrity(conn, "/assets/js/app.js")
      "813dfe33b5c7f8388bccaaa38eec8382"

      iex> static_integrity(socket, "/assets/js/app.js")
      "813dfe33b5c7f8388bccaaa38eec8382"

      iex> static_integrity(MyApp.Web.Endpoint, "/assets/js/app.js")
      "813dfe33b5c7f8388bccaaa38eec8382"

  """
  def static_integrity(endpoint_or_conn_or_socket, path) when is_binary(path) do
    guarded_static_integrity(endpoint_or_conn_or_socket, path)
  end

  def guarded_static_integrity(%Plug.Conn{private: %{combo_endpoint: endpoint}}, path) do
    endpoint.static_integrity(path)
  end

  def guarded_static_integrity(%Combo.Socket{endpoint: endpoint}, path) do
    endpoint.static_integrity(path)
  end

  def guarded_static_integrity(endpoint, path) when is_atom(endpoint) do
    endpoint.static_integrity(path)
  end

  def guarded_static_integrity(other, path) do
    raise ArgumentError, """
    expected a %Plug.Conn{}, a %Combo.Socket{} or a Combo.Endpoint \
    when building static integrity for #{path}, got: #{inspect(other)}\
    """
  end

  # Utils

  defp concat_url(url, path) when is_binary(path) do
    url <> path
  end

  defp concat_url(url, path, params) when is_binary(path) do
    append_params(url <> path, params)
  end

  defp append_params(url_or_path, params) when params == %{} or params == [] do
    url_or_path
  end

  defp append_params(url_or_path, params) when is_map(params) or is_list(params) do
    url_or_path <> "?" <> encode_query(params)
  end

  defp encode_query(dict) when is_list(dict) or (is_map(dict) and not is_struct(dict)) do
    case Plug.Conn.Query.encode(dict, &Combo.URLParam.to_param/1) do
      "" -> ""
      query_string -> query_string
    end
  end

  defp encode_query(data) do
    data
    |> Combo.URLParam.to_param()
    |> URI.encode_www_form()
  end
end
