defmodule Combo.Endpoint.Supervisor do
  @moduledoc false

  use Supervisor
  require Logger

  @default_config [
    live_reloader: false,
    code_reloader: false,
    debug_errors: false,
    render_errors: [layout: false],
    url: [host: "localhost", path: "/"],
    static_url: nil,
    adapter: Combo.Endpoint.BanditAdapter,
    http: false,
    https: false,
    check_origin: true,
    secret_key_base: nil,
    static: [
      manifest: nil,
      vsn: true
    ],
    watchers: [],
    log_access_url: true
  ]

  @unsafe_config_keys [:secret_key_base]

  @doc """
  Starts the endpoint supervision tree.
  """
  def start_link(otp_app, module, opts \\ []) do
    with {:ok, pid} = ok <-
           Supervisor.start_link(__MODULE__, {otp_app, module, opts}, name: module) do
      config = Combo.Config.get_all(module)
      safe_config = safe_config(config)

      log_access_url(module, safe_config)

      measurements = %{system_time: System.system_time()}
      metadata = %{otp_app: otp_app, module: module, config: safe_config, pid: pid}
      :telemetry.execute([:combo, :endpoint, :init], measurements, metadata)

      ok
    end
  end

  # remove secrets from the config to allow safe passing it everywhere.
  defp safe_config(config) do
    Keyword.drop(config, @unsafe_config_keys)
  end

  @doc false
  def init({otp_app, module, opts}) do
    from_opts = opts
    from_env = Combo.Config.from_env(otp_app, module)

    extra = [
      endpoint_id: :crypto.strong_rand_bytes(16) |> Base.encode64(padding: false)
    ]

    config =
      [otp_app: otp_app]
      |> Combo.Config.merge(@default_config)
      |> Combo.Config.merge(from_opts)
      |> Combo.Config.merge(from_env)
      |> Combo.Config.merge(extra)

    safe_config = safe_config(config)

    permanent_keys = Keyword.keys(config) -- Keyword.keys(from_env)

    server? = server?(safe_config)

    if server? and safe_config[:code_reloader] do
      Combo.CodeReloader.Server.check_symlinks()
    end

    children =
      Enum.concat([
        config_children(module, config, permanent_keys),
        cache_children(module),
        persistent_children(module, safe_config),
        static_children(module, safe_config),
        socket_children(module, safe_config, :child_spec),
        server_children(module, safe_config, server?),
        socket_children(module, safe_config, :drainer_spec),
        watcher_children(module, safe_config, server?)
      ])

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp config_children(mod, conf, default_conf) do
    args = {mod, conf, default_conf, name: Module.concat(mod, "Config")}
    [{Combo.Config, args}]
  end

  defp cache_children(module) do
    [{Combo.Cache, module}]
  end

  defp persistent_children(module, safe_config) do
    [{Combo.Endpoint.Persistent, {module, safe_config}}]
  end

  defp static_children(module, safe_config) do
    [{Combo.Static, {module, safe_config}}]
  end

  defp socket_children(endpoint, conf, fun) do
    for {_, socket, opts} <- Enum.uniq_by(endpoint.__sockets__(), &elem(&1, 1)),
        _ = check_origin_or_csrf_checked!(conf, opts),
        spec = apply_or_ignore(socket, fun, [[endpoint: endpoint] ++ opts]),
        spec != :ignore do
      spec
    end
  end

  defp apply_or_ignore(socket, fun, args) do
    # If the module is not loaded, we want to invoke and crash
    if not Code.ensure_loaded?(socket) or function_exported?(socket, fun, length(args)) do
      apply(socket, fun, args)
    else
      :ignore
    end
  end

  defp check_origin_or_csrf_checked!(endpoint_conf, socket_opts) do
    check_origin = endpoint_conf[:check_origin]

    for {transport, transport_opts} <- socket_opts, is_list(transport_opts) do
      check_origin = Keyword.get(transport_opts, :check_origin, check_origin)

      check_csrf = transport_opts[:check_csrf]

      if check_origin == false and check_csrf == false do
        raise ArgumentError,
              "one of :check_origin and :check_csrf must be set to non-false value for " <>
                "transport #{inspect(transport)}"
      end
    end
  end

  defp server_children(mod, config, server?) do
    cond do
      server? ->
        adapter = config[:adapter]
        adapter.child_specs(mod, config)

      config[:http] || config[:https] ->
        if System.get_env("RELEASE_NAME") do
          Logger.info(
            "Configuration :server was not enabled for #{inspect(mod)}, http/https services won't start"
          )
        end

        []

      true ->
        []
    end
  end

  defp watcher_children(_mod, conf, server?) do
    watchers = conf[:watchers] || []

    if server? || mix_combo_serve?() do
      Enum.map(watchers, &{Combo.Endpoint.Watcher, &1})
    else
      []
    end
  end

  @doc """
  Checks if Endpoint's web server has been configured to start.
  """
  def server?(otp_app, endpoint) when is_atom(otp_app) and is_atom(endpoint) do
    server?(Application.get_env(otp_app, endpoint, []))
  end

  defp server?(conf) when is_list(conf) do
    Keyword.get_lazy(conf, :server, fn -> mix_combo_serve?() end)
  end

  defp mix_combo_serve? do
    Application.get_env(:combo, :serve_endpoints, false)
  end

  @doc """
  Callback that changes the configuration from the app callback.
  """

  def config_change(endpoint, changed, removed) do
    cond do
      changed_config = changed[endpoint] ->
        :ok = Combo.Config.config_change(endpoint, changed_config)

        config = Combo.Config.get_all(endpoint)
        safe_config = safe_config(config)
        :ok = Combo.Endpoint.Persistent.config_change(endpoint, safe_config)

      endpoint in removed ->
        :ok = Combo.Config.stop(endpoint)
        :ok = Combo.Endpoint.Persistent.stop(endpoint)
    end

    :ok
  end

  defp log_access_url(endpoint, config) do
    if Keyword.fetch!(config, :log_access_url) && server?(config) do
      Logger.info("Access #{inspect(endpoint)} at #{endpoint.url()}")
    end
  end
end
