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
        server_adapter: Combo.Proxy.ServerAdapters.Bandit,
        scheme: :http,
        ip: {127, 0, 0, 1},
        port: 4000,
        backends: [
          %{
            plug: HealthCheckPlug,
            path: "/health-check"
          },
          %{
            plug: MyApp.UserWeb.Endpoint,
            path: "/"
          },
          %{
            plug: MyApp.AdminWeb.Endpoint,
            path: "/admin"
          }
        ]

  > Before used for matching connections, the backends will be sorted by
  > specificity. So feel free to arrange them in whatever way you like.

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
    * `:server_adapter` - the server adapter.
      Default to `Combo.Proxy.ServerAdapters.Bandit`.
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

  ## About adapter options

  In the section of Options, we said:

  > all other options will be put into an keyword list and passed as the options
  > of the adapter.

  It means the all options except `:server`, `:backends`, `:server_adapter` will be
  passed as the the options of an adapter.

  Take `Combo.Proxy.ServerAdapters.Bandit` adapter as an example. If we declare the
  options like:

      config :my_app, MyApp.Proxy,
        backends: [
          # ...
        ],
        server_adapter: Combo.Proxy.ServerAdapters.Bandit,
        scheme: :http,
        ip: {127, 0, 0, 1},
        port: 4000,
        thousand_island_options: [num_acceptors: 2]

  Then following options will be passed to the underlying `Bandit` when
  initializing `Combo.Proxy`:

      [
        scheme: :http,
        ip: {127, 0, 0, 1},
        port: 4000,
        thousand_island_options: [num_acceptors: 2]
      ]

  For more available adapter options:
    
    * `Combo.Proxy.ServerAdapters.Bandit` - checkout [Bandit options](`t:Bandit.options/0`).

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

    {server_adapter, rest_arg} =
      Keyword.pop(rest_arg, :server_adapter, Combo.Proxy.ServerAdapters.Bandit)

    {backends, rest_arg} = Keyword.pop(rest_arg, :backends, [])

    server_adapter_config =
      rest_arg
      |> Keyword.delete(:plug)
      |> Keyword.put_new(:scheme, :http)
      |> Keyword.put_new(:ip, {127, 0, 0, 1})
      |> put_new_port()

    config =
      Config.new!(%{
        server: server,
        server_adapter: server_adapter,
        server_adapter_config: server_adapter_config,
        backends: backends
      })

    check_server_adapter_module!(config.server_adapter)

    start_server? = config.server || mix_combo_serve?()

    children =
      if start_server?,
        do: [build_child(config)],
        else: []

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp put_new_port(server_adapter_config) do
    Keyword.put_new_lazy(server_adapter_config, :port, fn ->
      scheme = Keyword.fetch!(server_adapter_config, :scheme)
      get_default_port(scheme)
    end)
  end

  defp get_default_port(:http = _scheme), do: 4000
  defp get_default_port(:https = _scheme), do: 4040

  defp check_server_adapter_module!(Combo.Proxy.ServerAdapters.Bandit) do
    unless Code.ensure_loaded?(Bandit) do
      Logger.error("""
      Could not find Bandit dependency. Please add :bandit to your dependencies:

          {:bandit, "~> 1.0"}

      """)

      raise "missing Bandit dependency"
    end

    :ok
  end

  defp check_server_adapter_module!(server_adapter) do
    raise "unknown server adapter #{inspect(server_adapter)}"
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
    %{
      server_adapter: server_adapter,
      server_adapter_config: server_adapter_config,
      backends: backends
    } = config

    Logger.info(fn -> gen_listen_line(server_adapter_config) end)

    {
      fetch_server_adapter_plug!(server_adapter),
      [plug: {Dispatcher, [backends: backends]}] ++
        build_server_adapter_opts(server_adapter, server_adapter_config)
    }
  end

  defp fetch_server_adapter_plug!(Combo.Proxy.ServerAdapters.Bandit), do: Bandit

  defp build_server_adapter_opts(
         Combo.Proxy.ServerAdapters.Bandit = _server_adapter,
         server_adapter_config
       ) do
    server_adapter_config
  end

  defp gen_listen_line(server_adapter_config) do
    scheme = Keyword.fetch!(server_adapter_config, :scheme)
    ip = Keyword.fetch!(server_adapter_config, :ip)
    port = Keyword.fetch!(server_adapter_config, :port)
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
