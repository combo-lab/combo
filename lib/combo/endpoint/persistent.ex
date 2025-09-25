defmodule Combo.Endpoint.Persistent do
  @moduledoc false
  # To prevent a race condition where the socket listener is already started
  # but the cache is not ready, this module should be started as a child in
  # the supervision tree of endpoint.

  require Logger

  def child_spec(arg) do
    %{
      id: make_ref(),
      start: {__MODULE__, :start_link, [arg]}
    }
  end

  def start_link({endpoint, safe_config}) do
    warmup(endpoint, safe_config)

    # As we don't actually want to start a process, we return :ignore here.
    :ignore
  end

  def reload(endpoint, safe_config) do
    warmup(endpoint, safe_config)
  end

  def fetch!(endpoint, key) do
    persistent =
      :persistent_term.get(build_key(endpoint), nil) ||
        raise "could not find persistent term for endpoint #{inspect(endpoint)}. Make sure your endpoint is started and note you cannot access endpoint functions at compile-time"

    Map.fetch!(persistent, key)
  end

  defp warmup(endpoint, _safe_config) do
    url_config = endpoint.config(:url)
    static_url_config = endpoint.config(:static_url) || url_config

    struct_url = build_url(endpoint, url_config)
    host = host_to_binary(url_config[:host] || "localhost")
    path = empty_string_if_root(url_config[:path] || "/")
    script_name = String.split(path, "/", trim: true)

    static_url = build_url(endpoint, static_url_config) |> String.Chars.URI.to_string()
    static_path = empty_string_if_root(static_url_config[:path] || "/")

    :persistent_term.put(build_key(endpoint), %{
      struct_url: struct_url,
      url: String.Chars.URI.to_string(struct_url),
      host: host,
      path: path,
      script_name: script_name,
      static_path: static_path,
      static_url: static_url
    })
  end

  defp build_url(endpoint, url) do
    https = endpoint.config(:https)
    http = endpoint.config(:http)

    {scheme, port} =
      cond do
        https -> {"https", https[:port] || 443}
        http -> {"http", http[:port] || 80}
        true -> {"http", 80}
      end

    scheme = url[:scheme] || scheme
    host = host_to_binary(url[:host] || "localhost")
    port = port_to_integer(url[:port] || port)

    if host =~ ~r"[^:]:\d" do
      Logger.warning(
        "url: [host: ...] configuration value #{inspect(host)} for #{inspect(endpoint)} is invalid"
      )
    end

    %URI{scheme: scheme, port: port, host: host}
  end

  defp empty_string_if_root("/"), do: ""
  defp empty_string_if_root(other), do: other

  defp host_to_binary(host), do: host

  defp port_to_integer(port) when is_binary(port), do: String.to_integer(port)
  defp port_to_integer(port) when is_integer(port), do: port

  defp build_key(endpoint), do: {__MODULE__, endpoint}
end
