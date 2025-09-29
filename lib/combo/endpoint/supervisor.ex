defmodule Combo.Endpoint.Supervisor do
  @moduledoc false
  #
  # ## The Conventions
  #
  # ### The values of configurations
  #
  #   * `nil` - indicates undefined
  #   * `false` - indicates explicitly disabled
  #
  # And, all default values of configurations should be listed in `@default_config`.
  #

  use Supervisor
  require Logger

  @default_config [
    # compile-time config
    live_reloader: false,
    code_reloader: false,
    debug_errors: false,

    # runtime config
    http: false,
    https: false,
    adapter: Combo.Endpoint.BanditAdapter,
    url: [host: "localhost", path: "/"],
    static_url: nil,
    log_access_url: true,
    server: nil,
    check_origin: true,
    render_errors: [layout: false],
    secret_key_base: nil,
    static: [
      manifest: nil,
      vsn: true
    ],
    watchers: false
  ]

  @unsafe_config_keys [:secret_key_base]

  @doc """
  Starts the endpoint supervision tree.
  """
  def start_link(otp_app, module, opts \\ []) do
    with {:ok, pid} = ok <-
           Supervisor.start_link(__MODULE__, {otp_app, module, opts}, name: module) do
      config = Combo.Endpoint.Config.dump(module)
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

    server? = server?(safe_config)

    if server? and safe_config[:code_reloader] do
      Combo.CodeReloader.Server.check_symlinks()
    end

    children =
      Enum.concat([
        deps_children(module),
        config_children(module, config),
        persistent_children(module, safe_config),
        static_children(module, safe_config),
        socket_children(module, safe_config, :child_spec),
        server_children(module, safe_config, server?),
        socket_children(module, safe_config, :drainer_spec),
        watcher_children(module, safe_config, server?)
      ])

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp deps_children(module) do
    [{Combo.Cache, module}]
  end

  defp config_children(mod, config) do
    [{Combo.Endpoint.Config, {mod, config}}]
  end

  defp persistent_children(module, safe_config) do
    [{Combo.Endpoint.Persistent, {module, safe_config}}]
  end

  defp static_children(module, safe_config) do
    [{Combo.Static, {module, safe_config}}]
  end

  defp socket_children(endpoint, safe_config, fun) do
    for {_, socket, opts} <- Enum.uniq_by(endpoint.__sockets__(), &elem(&1, 1)),
        _ = check_origin_or_csrf_checked!(safe_config, opts),
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

  defp check_origin_or_csrf_checked!(endpoint_config, socket_opts) do
    check_origin = endpoint_config[:check_origin]

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

  defp server_children(mod, safe_config, server?) do
    cond do
      server? ->
        adapter = safe_config[:adapter]
        adapter.child_specs(mod, safe_config)

      safe_config[:http] || safe_config[:https] ->
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

  defp watcher_children(_mod, safe_config, server?) do
    case safe_config[:watchers] do
      false ->
        []

      watchers when is_list(watchers) ->
        if server? || mix_combo_serve?() do
          Enum.map(watchers, &{Combo.Endpoint.Watcher, &1})
        else
          []
        end
    end
  end

  @spec server?(atom(), module()) :: boolean()
  def server?(otp_app, endpoint) when is_atom(otp_app) and is_atom(endpoint) do
    server?(Application.get_env(otp_app, endpoint, []))
  end

  defp server?(config) when is_list(config) do
    case Keyword.get(config, :server, nil) do
      nil -> mix_combo_serve?()
      other -> !!other
    end
  end

  defp mix_combo_serve? do
    Application.get_env(:combo, :serve_endpoints, false)
  end

  defp log_access_url(endpoint, safe_config) do
    if Keyword.fetch!(safe_config, :log_access_url) && server?(safe_config) do
      Logger.info("Access #{inspect(endpoint)} at #{endpoint.url()}")
    end
  end
end
