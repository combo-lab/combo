defmodule Combo.Proxy do
  @moduledoc """
  Proxy requests to other plugs.

  ## Features

    * Multiple adatpers support
    * Plug support
      * general plugs
      * Combo endpoints
    * WebSocket support

  ## Usage

  A `Combo.Proxy` instance is an isolated supervision tree and you can include it in
  application's supervisor:

      # lib/my_app/application.ex
      def start(_type, _args) do
        children = [
          # ...
          {Combo.Proxy, Application.fetch_env!(:my_app, MyApp.Proxy)}
        ]

        opts = [strategy: :one_for_one, name: MyApp.Supervisor]
        Supervisor.start_link(children, opts)
      end

  Above code requires a piece of configuration:

      config :my_app, MyApp.Proxy,
        server: true,
        adapter: Combo.Proxy.BanditAdapter,
        scheme: :http,
        ip: {127, 0, 0, 1},
        port: 4000,
        backends: [
          %{
            plug: HealthCheckPlug,
            path: "/health-check"
          },
          %{
            plug: MyApp.AdminWeb.Endpoint,
            path: "/admin"
          },
          %{
            plug: MyApp.UserWeb.Endpoint,
            path: "/"
          }
        ]

  When using `Combo.Proxy` with Combo endpoints, it's required to configure the
  path of endpoints to a proper value. And it's better to configure `:server`
  option of endpoints to `false`, which avoids them serving requests bypassing
  `Combo.Proxy`. For example:

      config :my_app, MyApp.UserWeb.Endpoint,
        url: [path: "/"],
        server: false

      config :my_app, MyApp.AdminWeb.Endpoint,
        url: [path: "/admin"],
        server: false

  ## Options

    * `:server` - start the web server or not. It is aware of Combo startup
      arguments, if the application is started with `mix combo.serve` or
      `iex -S mix combo.serve`, this option will be set to `true`.
      Default to `false`.
    * `:backends` - the list of backends.  See following section for more details.
      Default to `[]`.
    * `:adapter` - the adapter for web server, `Combo.Proxy.Cowboy2Adapter` and
      `Combo.Proxy.BanditAdapter` are available.
      Default to `Combo.Proxy.Cowboy2Adapter`.
    * adapter options - all other options will be put into an keyword list and
      passed as the options of the adapter. See following section for more details.

  ## About `:backends`

  A valid `:backends` option is a list of maps, and the keys of maps are:

    * `:plug`:
      * required
      * typespec: `module() | {module(), keyword()}`
      * examples:
        * `HealthCheckPlug`
        * `{HealthCheckPlug, []}`
        * ...
    * `:method`:
      * optional
      * typespec: `String.t()`
      * examples:
        * `"GET"`
        * `"POST"`
        * ...
    * `:host`:
      * optional
      * typespec: `String.t()` | `Regex.t()`
      * examples:
        * `"example.com"`
        * ...
    * `:path`:
      * optional
      * typespec: `String.t()`
      * examples:
        * `"/admin"`
        * `"/api"`
        * ...
    * `:rewrite_path_info`:
      * optional
      * typespec: `boolean()`
      * default: `true`
      * examples:
        * `true`
        * `false`

  ### The order of backends matters

  If you configure the backends like this:

      config :my_app, MyApp.Proxy,
        backends: [
          %{
            plug: MyApp.UserWeb.Endpoint,
            path: "/"
          },
          %{
            plug: MyApp.AdminWeb.Endpoint,
            path: "/admin"
          },
          %{
            plug: HealthCheck,
            path: "/health"
          }
        ]

  The first backend will always match, which may not what you expected.

  If you want all backends to have a chance to match, you should configure them like this:

      config :my_app, MyApp.Proxy,
        backends: [
          %{
            plug: HealthCheck,
            path: "/health"
          },
          %{
            plug: MyApp.AdminWeb.Endpoint,
            path: "/admin"
          },
          %{
            plug: MyApp.UserWeb.Endpoint,
            path: "/"
          }
        ]

  ## About adapter options

  In the section of Options, we said:

  > all other options will be put into an keyword list and passed as the
  > options of the adapter.

  It means the all options except `:server`, `:backends`, `:adapter` will be
  passed as the the options of an adapter.

  Take `Combo.Proxy.Cowboy2Adapter` adapter as an example. If we declare the
  options like:

      config :my_app, MyApp.Proxy,
        backends: [
          # ...
        ],
        adapter: Combo.Proxy.Cowboy2Adapter,
        scheme: :http,
        ip: {127, 0, 0, 1},
        port: 4000,
        transport_options: [num_acceptors: 2]

  Then following options will be passed to the underlying `Plug.Cowboy` when
  initializing `Combo.Proxy`:

      [
        scheme: :http,
        ip: {127, 0, 0, 1},
        port: 4000,
        transport_options: [num_acceptors: 2]
      ]

  For more available adapter options:
    
    * `Combo.Proxy.Bandit` - checkout [Bandit options](https://hexdocs.pm/bandit/Bandit.html#t:options/0).
    * `Combo.Proxy.Cowboy2Adapter` - checkout [Plug.Cowboy options](https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html#module-options).

  """

  use Supervisor
  require Logger
  alias Combo.Proxy.Config
  alias Combo.Proxy.Dispatcher

  def start_link(opts) do
    {name, rest} = Keyword.pop(opts, :name)

    init_arg = rest
    options = [name: name] |> Enum.reject(fn {_k, v} -> v == nil end)
    Supervisor.start_link(__MODULE__, init_arg, options)
  end

  @impl true
  def init(init_arg) do
    {server, rest_arg} = Keyword.pop(init_arg, :server, false)
    {adapter, rest_arg} = Keyword.pop(rest_arg, :adapter, Plug.Cowboy)
    {backends, rest_arg} = Keyword.pop(rest_arg, :backends, [])

    adapter_config =
      rest_arg
      |> Keyword.delete(:plug)
      |> Keyword.put_new(:scheme, :http)
      |> Keyword.put_new(:ip, {127, 0, 0, 1})
      |> put_new_port()

    config =
      Config.new!(%{
        server: server,
        adapter: adapter,
        adapter_config: adapter_config,
        backends: backends
      })

    check_adapter_module!(config.adapter)

    start_server? = config.server || mix_combo_serve?()

    children =
      if start_server?,
        do: [build_child(config)],
        else: []

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp put_new_port(adapter_config) do
    Keyword.put_new_lazy(adapter_config, :port, fn ->
      scheme = Keyword.fetch!(adapter_config, :scheme)
      get_default_port(scheme)
    end)
  end

  # Same as the default ports of Plug.Cowboy and Bandit
  defp get_default_port(:http = _scheme), do: 4000
  defp get_default_port(:https = _scheme), do: 4040

  defp check_adapter_module!(Combo.Proxy.BanditAdapter) do
    unless Code.ensure_loaded?(Bandit) do
      Logger.error("""
      Could not find Bandit dependency. Please add :bandit to your dependencies:

          {:bandit, "~> 1.0"}

      """)

      raise "missing Bandit dependency"
    end

    :ok
  end

  defp check_adapter_module!(Combo.Proxy.Cowboy2Adapter) do
    unless Code.ensure_loaded?(Plug.Cowboy) do
      Logger.error("""
      Could not find Plug.Cowboy dependency. Please add :plug_cowboy to your dependencies:

          {:plug_cowboy, "~> 2.6"}

      """)

      raise "missing Plug.Cowboy dependency"
    end

    :ok
  end

  defp check_adapter_module!(adapter) do
    raise "unknown adapter #{inspect(adapter)}"
  end

  # Consinder Combo should serve when meets following cases:
  #
  # + run `iex -S mix combo.serve`
  # + run `mix combo.serve`
  #
  defp mix_combo_serve?() do
    Application.get_env(:combo, :serve_endpoints, false)
  end

  defp build_child(%Config{} = config) do
    %{adapter: adapter, adapter_config: adapter_config, backends: backends} = config

    Logger.info(fn -> gen_listen_line(adapter_config) end)

    {
      fetch_adapter_plug!(adapter),
      [plug: {Dispatcher, [backends: backends]}] ++ build_adapter_opts(adapter, adapter_config)
    }
  end

  defp fetch_adapter_plug!(Combo.Proxy.BanditAdapter), do: Bandit
  defp fetch_adapter_plug!(Combo.Proxy.Cowboy2Adapter), do: Plug.Cowboy

  defp build_adapter_opts(Combo.Proxy.BanditAdapter = _adapter, adapter_config) do
    adapter_config
  end

  defp build_adapter_opts(Combo.Proxy.Cowboy2Adapter = _adapter, adapter_config) do
    {scheme, options} = Keyword.pop!(adapter_config, :scheme)
    [scheme: scheme, options: options]
  end

  defp gen_listen_line(adapter_config) do
    scheme = Keyword.fetch!(adapter_config, :scheme)
    ip = Keyword.fetch!(adapter_config, :ip)
    port = Keyword.fetch!(adapter_config, :port)
    "#{inspect(__MODULE__)} is listening on #{scheme}://#{format_ip(ip)}:#{port}"
  end

  defp format_ip(ip) do
    if is_tuple(ip) do
      :inet.ntoa(ip)
    else
      inspect(ip)
    end
  end
end
