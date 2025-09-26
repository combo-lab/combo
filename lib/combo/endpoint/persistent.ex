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

  def config_change(endpoint, safe_config) do
    warmup(endpoint, safe_config)
    :ok
  end

  def stop(endpoint) do
    key = build_key(endpoint)
    true = :persistent_term.erase(key)
    :ok
  end

  def fetch!(endpoint, key) do
    persistent =
      :persistent_term.get(build_key(endpoint), nil) ||
        raise "could not find persistent term for endpoint #{inspect(endpoint)}"

    Map.fetch!(persistent, key)
  end

  defp warmup(endpoint, safe_config) do
    url_config = safe_config[:url]
    static_url_config = safe_config[:static_url] || url_config

    %{scheme: scheme, host: host, port: port, path: path} =
      resolve_url_config(endpoint, url_config, safe_config)

    base_url = build_base_url(scheme, host, port)
    base_url_struct = build_base_url_struct(scheme, host, port)
    script_name = String.split(path, "/", trim: true)

    %{scheme: static_scheme, host: static_host, port: static_port, path: static_path} =
      resolve_url_config(endpoint, static_url_config, safe_config)

    static_base_url = build_base_url(static_scheme, static_host, static_port)

    :persistent_term.put(build_key(endpoint), %{
      url: base_url,
      url_struct: base_url_struct,
      host: host,
      path: path,
      script_name: script_name,

      # for static
      static_url: static_base_url,
      static_path: static_path
    })
  end

  defp resolve_url_config(endpoint, url_config, safe_config) do
    https_config = safe_config[:https]
    http_config = safe_config[:http]

    {scheme, port} =
      cond do
        https_config -> {"https", https_config[:port] || 443}
        http_config -> {"http", http_config[:port] || 80}
        true -> {"http", 80}
      end

    scheme = url_config[:scheme] || scheme
    host = to_host(url_config[:host] || "localhost")
    port = to_port(url_config[:port] || port)
    path = to_path(url_config[:path] || "/")

    if host =~ ~r"[^:]:\d" do
      Logger.warning(
        "url: [host: ...] configuration value #{inspect(host)} for #{inspect(endpoint)} is invalid"
      )
    end

    %{scheme: scheme, host: host, port: port, path: path}
  end

  defp build_base_url(scheme, host, port) do
    to_string(%URI{scheme: scheme, host: host, port: port})
  end

  defp build_base_url_struct(scheme, host, port) do
    %URI{scheme: scheme, host: host, port: port}
  end

  defp to_host(host) when is_binary(host), do: host

  defp to_port(port) when is_binary(port), do: String.to_integer(port)
  defp to_port(port) when is_integer(port), do: port

  defp to_path("/"), do: ""
  defp to_path(other), do: other

  defp build_key(endpoint), do: {__MODULE__, endpoint}
end
