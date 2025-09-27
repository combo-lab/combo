System.put_env("ENDPOINT_TEST_HOST", "example.com")
System.put_env("ENDPOINT_TEST_PORT", "80")
System.put_env("ENDPOINT_TEST_ASSET_HOST", "assets.example.com")
System.put_env("ENDPOINT_TEST_ASSET_PORT", "443")

defmodule Combo.EndpointTest do
  use ExUnit.Case
  use Support.RouterHelper

  import ExUnit.CaptureLog

  @config [
    url: [host: System.get_env("ENDPOINT_TEST_HOST"), path: "/api"],
    static_url: [host: "static.example.com"],
    server: false,
    http: [port: 80],
    https: [port: 443],
    force_ssl: [subdomains: true],
    static: [
      manifest: "../../../../test/fixtures/static/compile/cache_manifest.json",
      vsn: true
    ],
    pubsub_server: :endpoint_pub
  ]

  Application.put_env(:combo, __MODULE__.Endpoint, @config)

  defmodule Endpoint do
    use Combo.Endpoint, otp_app: :combo

    # Assert endpoint variables
    assert @otp_app == :combo
    assert code_reloading? == false
    assert debug_errors? == false
  end

  defmodule NoConfigEndpoint do
    use Combo.Endpoint, otp_app: :combo
  end

  defmodule SystemTupleEndpoint do
    use Combo.Endpoint, otp_app: :combo
  end

  defp apply_static_config(overrides \\ []) do
    default_config = [
      manifest: "../../../../test/fixtures/static/compile/manifest.json",
      vsn: true
    ]

    static_config = Keyword.merge(default_config, overrides)
    config = put_in(@config[:static], static_config)
    :ok = Endpoint.config_change([{Endpoint, config}], [])
  end

  setup_all do
    ExUnit.CaptureLog.capture_log(fn -> start_supervised!(Endpoint) end)
    start_supervised!({Phoenix.PubSub, name: :endpoint_pub})

    on_exit(fn -> Application.delete_env(:combo, :serve_endpoints) end)

    :ok
  end

  test "defines child_spec/1" do
    assert Endpoint.child_spec([]) == %{
             id: Endpoint,
             start: {Endpoint, :start_link, [[]]},
             type: :supervisor
           }
  end

  test "warns if there is no configuration for an endpoint" do
    assert ExUnit.CaptureLog.capture_log(fn ->
             NoConfigEndpoint.start_link()
           end) =~ "no configuration"
  end

  test "has reloadable configuration" do
    endpoint_id = Endpoint.config(:endpoint_id)
    assert Endpoint.config(:url) == [host: "example.com", path: "/api"]
    assert Endpoint.config(:static_url) == [host: "static.example.com"]
    assert Endpoint.url() == "https://example.com"
    assert Endpoint.url_struct() == %URI{scheme: "https", host: "example.com", port: 443}
    assert Endpoint.path("/") == "/api/"
    assert Endpoint.static_url() == "https://static.example.com"

    config =
      @config
      |> put_in([:url, :port], 1234)
      |> put_in([:static_url, :port], 456)

    assert Endpoint.config_change([{Endpoint, config}], []) == :ok

    assert Endpoint.config(:endpoint_id) == endpoint_id
    assert Endpoint.config(:url) |> Enum.sort() == [host: "example.com", path: "/api", port: 1234]
    assert Endpoint.config(:static_url) |> Enum.sort() == [host: "static.example.com", port: 456]

    assert Endpoint.url() == "https://example.com:1234"
    assert Endpoint.url_struct() == %URI{scheme: "https", host: "example.com", port: 1234}
    assert Endpoint.path("/") == "/api/"
    assert Endpoint.static_url() == "https://static.example.com:456"
  end

  test "sets script name when using path" do
    conn = conn(:get, "https://example.com/")
    assert Endpoint.call(conn, []).script_name == ~w"api"

    conn = put_in(conn.script_name, ~w(foo))
    assert Endpoint.call(conn, []).script_name == ~w"api"
  end

  @tag :capture_log
  test "redirects http requests to https on force_ssl" do
    conn = Endpoint.call(conn(:get, "/"), [])
    assert get_resp_header(conn, "location") == ["https://example.com/"]
    assert conn.halted
  end

  test "sends hsts on https requests on force_ssl" do
    conn = Endpoint.call(conn(:get, "https://example.com/"), [])

    assert get_resp_header(conn, "strict-transport-security") ==
             ["max-age=31536000; includeSubDomains"]
  end

  describe "static_path/1" do
    test "validates path" do
      safe_path = "/some_safe_path"
      assert Endpoint.static_path(safe_path) == safe_path

      assert_raise ArgumentError, ~r|unsafe characters|, fn ->
        Endpoint.static_path("/\\unsafe_path")
      end

      assert_raise ArgumentError, ~r|expected a path starting with a single /|, fn ->
        Endpoint.static_path("//invalid_path")
      end
    end

    test "generates path with hashed filename when [:static, :manifest] config is present" do
      apply_static_config()

      assert Endpoint.static_path("/assets/js/app.js") ==
               "/assets/js/app-5ef562abd8514711de540eddaa53be19.js?vsn=d"
    end

    test "generates path without hashed filename when [:static, :manifest] config is absent" do
      apply_static_config(manifest: nil)
      assert Endpoint.static_path("/assets/js/app.js") == "/assets/js/app.js"
    end

    test "generates path according to :vsn config" do
      apply_static_config(vsn: true)

      assert Endpoint.static_path("/assets/js/app.js") ==
               "/assets/js/app-5ef562abd8514711de540eddaa53be19.js?vsn=d"

      apply_static_config(vsn: false)

      assert Endpoint.static_path("/assets/js/app.js") ==
               "/assets/js/app-5ef562abd8514711de540eddaa53be19.js"
    end

    test "supports path with fragment identifier" do
      apply_static_config(vsn: true)

      assert Endpoint.static_path("/assets/js/app.js#info") ==
               "/assets/js/app-5ef562abd8514711de540eddaa53be19.js?vsn=d#info"

      # multiple presences of # are treated as a fragment
      assert Endpoint.static_path("/assets/js/app.js#info#me") ==
               "/assets/js/app-5ef562abd8514711de540eddaa53be19.js?vsn=d#info#me"

      apply_static_config(vsn: false)

      assert Endpoint.static_path("/assets/js/app.js#info") ==
               "/assets/js/app-5ef562abd8514711de540eddaa53be19.js#info"

      # multiple presences of # are treated as a fragment
      assert Endpoint.static_path("/assets/js/app.js#info#me") ==
               "/assets/js/app-5ef562abd8514711de540eddaa53be19.js#info#me"
    end
  end

  describe "static_integrity/1" do
    test "validates path" do
      safe_path = "/some_safe_path"
      assert is_nil(Endpoint.static_integrity(safe_path))

      assert_raise ArgumentError, ~r/unsafe characters/, fn ->
        Endpoint.static_integrity("/\\unsafe_path")
      end

      assert_raise ArgumentError, ~r|expected a path starting with a single /|, fn ->
        Endpoint.static_integrity("//invalid_path")
      end
    end

    test "gets the integrity when the static file exists" do
      apply_static_config()

      assert Endpoint.static_integrity("/assets/js/app.js") ==
               "sha512-ES089+qHBbaXGOcOQMF0odNcZgRL0T+093SQktfaVc2UO1WgghzPjgwNEeh57zymJRk1hBKqJhpwlHtCvbwiFw=="
    end

    test "gets nil when the static file doesn't exist" do
      apply_static_config()
      assert Endpoint.static_integrity("/assets/js/unknown.js") == nil
    end

    test "gets nil when the static file exist, but the manifest is absent" do
      apply_static_config(manifest: nil)
      assert Endpoint.static_integrity("/assets/js/app.js") == nil
    end
  end

  test "warms up caches on load and config change" do
    assert Endpoint.config_change([{Endpoint, @config}], []) == :ok

    assert Endpoint.static_path("/foo.css") == "/foo-d978852bea6530fcd197b5445ed008fd.css?vsn=d"

    # Trigger a config change and the cache should be warmed up again
    config =
      put_in(
        @config[:static][:manifest],
        "../../../../test/fixtures/static/compile/cache_manifest_upgrade.json"
      )

    assert Endpoint.config_change([{Endpoint, config}], []) == :ok
    assert Endpoint.static_path("/foo.css") == "/foo-ghijkl.css?vsn=d"
  end

  @tag :capture_log
  test "uses url configuration for static path" do
    Application.put_env(:combo, __MODULE__.UrlEndpoint, url: [path: "/admin"])

    defmodule UrlEndpoint do
      use Combo.Endpoint, otp_app: :combo
    end

    UrlEndpoint.start_link()
    assert UrlEndpoint.path("/users") == "/admin/users"
    assert UrlEndpoint.static_path("/logo.png") == "/admin/logo.png"
  after
    :code.purge(__MODULE__.UrlEndpoint)
    :code.delete(__MODULE__.UrlEndpoint)
  end

  @tag :capture_log
  test "uses static_url configuration for static path" do
    Application.put_env(:combo, __MODULE__.StaticEndpoint, static_url: [path: "/static"])

    defmodule StaticEndpoint do
      use Combo.Endpoint, otp_app: :combo
    end

    StaticEndpoint.start_link()
    assert StaticEndpoint.path("/users") == "/users"
    assert StaticEndpoint.static_path("/logo.png") == "/static/logo.png"
  after
    :code.purge(__MODULE__.StaticEndpoint)
    :code.delete(__MODULE__.StaticEndpoint)
  end

  @tag :capture_log
  test "can find the running address and port for an endpoint" do
    Application.put_env(:combo, __MODULE__.AddressEndpoint,
      http: [ip: {127, 0, 0, 1}, port: 0],
      server: true
    )

    defmodule AddressEndpoint do
      use Combo.Endpoint, otp_app: :combo
    end

    AddressEndpoint.start_link()
    assert {:ok, {{127, 0, 0, 1}, port}} = AddressEndpoint.server_info(:http)
    assert is_integer(port)
  after
    :code.purge(__MODULE__.AddressEndpoint)
    :code.delete(__MODULE__.AddressEndpoint)
  end

  test "injects pubsub broadcast with configured server" do
    Endpoint.subscribe("sometopic")
    some = spawn(fn -> :ok end)

    Endpoint.broadcast_from(some, "sometopic", "event1", %{key: :val})

    assert_receive %Combo.Socket.Broadcast{
      event: "event1",
      payload: %{key: :val},
      topic: "sometopic"
    }

    Endpoint.broadcast_from!(some, "sometopic", "event2", %{key: :val})

    assert_receive %Combo.Socket.Broadcast{
      event: "event2",
      payload: %{key: :val},
      topic: "sometopic"
    }

    Endpoint.broadcast("sometopic", "event3", %{key: :val})

    assert_receive %Combo.Socket.Broadcast{
      event: "event3",
      payload: %{key: :val},
      topic: "sometopic"
    }

    Endpoint.broadcast!("sometopic", "event4", %{key: :val})

    assert_receive %Combo.Socket.Broadcast{
      event: "event4",
      payload: %{key: :val},
      topic: "sometopic"
    }

    Endpoint.local_broadcast_from(some, "sometopic", "event1", %{key: :val})

    assert_receive %Combo.Socket.Broadcast{
      event: "event1",
      payload: %{key: :val},
      topic: "sometopic"
    }

    Endpoint.local_broadcast("sometopic", "event3", %{key: :val})

    assert_receive %Combo.Socket.Broadcast{
      event: "event3",
      payload: %{key: :val},
      topic: "sometopic"
    }
  end

  test "loads manifest from specified application" do
    config =
      put_in(
        @config[:static][:manifest],
        {:combo, "../../../../test/fixtures/static/compile/cache_manifest.json"}
      )

    assert Endpoint.config_change([{Endpoint, config}], []) == :ok
    assert Endpoint.static_path("/foo.css") == "/foo-d978852bea6530fcd197b5445ed008fd.css?vsn=d"
  end

  test "validates websocket and longpoll socket options" do
    assert_raise ArgumentError, ~r/unknown keys \[:invalid\]/, fn ->
      defmodule MyInvalidSocketEndpoint1 do
        use Combo.Endpoint, otp_app: :combo

        socket "/ws", UserSocket, websocket: [path: "/ws", check_origin: false, invalid: true]
      end
    end

    assert_raise ArgumentError, ~r/unknown keys \[:drainer\]/, fn ->
      defmodule MyInvalidSocketEndpoint2 do
        use Combo.Endpoint, otp_app: :combo

        socket "/ws", UserSocket, longpoll: [path: "/ws", check_origin: false, drainer: []]
      end
    end
  end

  describe "server?/2" do
    test "returns true for explicitly true server", config do
      endpoint = Module.concat(__MODULE__, config.test)
      Application.put_env(:combo, endpoint, server: true)
      on_exit(fn -> Application.delete_env(:combo, endpoint) end)
      assert Combo.Endpoint.server?(:combo, endpoint)
    end

    test "returns false for explicitly false server", config do
      Application.put_env(:combo, :serve_endpoints, true)
      endpoint = Module.concat(__MODULE__, config.test)
      Application.put_env(:combo, endpoint, server: false)
      on_exit(fn -> Application.delete_env(:combo, endpoint) end)
      refute Combo.Endpoint.server?(:combo, endpoint)
    end

    test "returns true for global serve_endpoints as true", config do
      Application.put_env(:combo, :serve_endpoints, true)
      endpoint = Module.concat(__MODULE__, config.test)
      Application.put_env(:combo, endpoint, [])
      on_exit(fn -> Application.delete_env(:combo, endpoint) end)
      assert Combo.Endpoint.server?(:combo, endpoint)
    end

    test "returns false for no global serve_endpoints config", config do
      Application.delete_env(:combo, :serve_endpoints)
      endpoint = Module.concat(__MODULE__, config.test)
      Application.put_env(:combo, endpoint, [])
      on_exit(fn -> Application.delete_env(:combo, endpoint) end)
      refute Combo.Endpoint.server?(:combo, endpoint)
    end
  end

  # config

  describe ":url and :static_url config" do
    defmodule URLEndpoint do
      use Combo.Endpoint, otp_app: :combo
    end

    # test ":https config is set" do
    #   Application.put_env(:combo, URLEndpoint,
    #     https: [port: 443],
    #     http: false,
    #     url: [host: "example.com"]
    #   )

    #   start_supervised!(URLEndpoint)
    #   assert URLEndpoint.url() == "https://example.com"
    # end

    @tag :capture_log
    test ":http config is set" do
      Application.put_env(:combo, URLEndpoint,
        https: false,
        http: [port: 80],
        url: [host: "example.com"]
      )

      start_supervised!(URLEndpoint)
      assert URLEndpoint.url() == "http://example.com"
    end

    @tag :capture_log
    test ":url config is set" do
      Application.put_env(:combo, URLEndpoint,
        https: false,
        http: false,
        url: [scheme: "random", host: "example.com", port: 678]
      )

      start_supervised!(URLEndpoint)
      assert URLEndpoint.url() == "random://example.com:678"
      assert URLEndpoint.static_url() == "random://example.com:678"
    end

    @tag :capture_log
    test ":static_url config is set" do
      Application.put_env(:combo, URLEndpoint,
        https: false,
        http: [port: 80],
        url: [host: "example.com"],
        static_url: [host: "static.example.com"]
      )

      start_supervised!(URLEndpoint)
      assert URLEndpoint.url() == "http://example.com"
      assert URLEndpoint.static_url() == "http://static.example.com"
    end

    @tag :capture_log
    test "static_url fallbacks to url when :static_url config is not set" do
      Application.put_env(:combo, URLEndpoint,
        https: false,
        http: [port: 80],
        url: [host: "example.com"]
      )

      start_supervised!(URLEndpoint)
      assert URLEndpoint.url() == "http://example.com"
      assert URLEndpoint.static_url() == "http://example.com"
    end
  end

  describe ":server config" do
    defmodule ServerEndpoint do
      use Combo.Endpoint, otp_app: :combo
    end

    test "logs info if :http or :https config is set but not :server when running inside release" do
      # simulate running inside release
      System.put_env("RELEASE_NAME", "app-test")

      message = "Configuration :server was not enabled"

      Application.put_env(:combo, ServerEndpoint, server: false, http: [], https: [])
      assert capture_log(fn -> start_supervised(ServerEndpoint) end) =~ message
      stop_supervised!(ServerEndpoint)

      Application.put_env(:combo, ServerEndpoint, server: false, http: [])
      assert capture_log(fn -> start_supervised(ServerEndpoint) end) =~ message
      stop_supervised!(ServerEndpoint)

      Application.put_env(:combo, ServerEndpoint, server: false, https: [])
      assert capture_log(fn -> start_supervised(ServerEndpoint) end) =~ message
      stop_supervised!(ServerEndpoint)

      Application.put_env(:combo, ServerEndpoint, server: false)
      refute capture_log(fn -> start_supervised(ServerEndpoint) end) =~ message
      stop_supervised!(ServerEndpoint)

      Application.put_env(:combo, ServerEndpoint, server: true)
      refute capture_log(fn -> start_supervised(ServerEndpoint) end) =~ message
      stop_supervised!(ServerEndpoint)

      on_exit(fn -> Application.delete_env(:combo, ServerEndpoint) end)
    end
  end

  describe ":watchers config" do
    defmodule WatchersEndpoint do
      use Combo.Endpoint, otp_app: :combo
    end

    @watchers [npm: ["run", "dev", cd: "."]]

    @tag :capture_log
    test "starts watchers when :server config is true" do
      Application.put_env(:combo, WatchersEndpoint, server: true, watchers: @watchers)
      on_exit(fn -> Application.delete_env(:combo, WatchersEndpoint) end)

      pid = start_supervised!(WatchersEndpoint)
      children = Supervisor.which_children(pid)

      assert Enum.any?(children, fn
               {_, _, _, [Combo.Endpoint.Watcher]} -> true
               _ -> false
             end)
    end

    @tag :capture_log
    test "doesn't starts watchers when :server config is true, but :watchers config is false" do
      Application.put_env(:combo, WatchersEndpoint, server: true, watchers: false)
      on_exit(fn -> Application.delete_env(:combo, WatchersEndpoint) end)

      pid = start_supervised!(WatchersEndpoint)
      children = Supervisor.which_children(pid)

      refute Enum.any?(children, fn
               {_, _, _, [Combo.Endpoint.Watcher]} -> true
               _ -> false
             end)
    end

    @tag :capture_log
    test "doesn't starts watchers when :server config is false" do
      Application.put_env(:combo, WatchersEndpoint, server: false, watchers: @watchers)
      on_exit(fn -> Application.delete_env(:combo, WatchersEndpoint) end)

      pid = start_supervised!(WatchersEndpoint)
      children = Supervisor.which_children(pid)

      refute Enum.any?(children, fn
               {_, _, _, [Combo.Endpoint.Watcher]} -> true
               _ -> false
             end)
    end

    @tag :capture_log
    test "starts watchers when :server config is false, but `mix combo.serve` is running" do
      Application.put_env(:combo, :serve_endpoints, true)
      Application.put_env(:combo, WatchersEndpoint, server: false, watchers: @watchers)

      on_exit(fn ->
        Application.delete_env(:combo, :serve_endpoints)
        Application.delete_env(:combo, WatchersEndpoint)
      end)

      pid = start_supervised!(WatchersEndpoint)
      children = Supervisor.which_children(pid)

      assert Enum.any?(children, fn
               {_, _, _, [Combo.Endpoint.Watcher]} -> true
               _ -> false
             end)
    end
  end

  describe ":check_origin and :check_csrf config" do
    defmodule TestSocket do
      @behaviour Combo.Socket.Transport

      def child_spec(_), do: :ignore
      def connect(_), do: {:ok, []}
      def init(state), do: {:ok, state}
      def handle_in(_, state), do: {:ok, state}
      def handle_info(_, state), do: {:ok, state}
      def terminate(_, _), do: :ok
    end

    defmodule SocketEndpoint do
      use Combo.Endpoint, otp_app: :combo
      socket "/ws", TestSocket, websocket: [check_csrf: false, check_origin: false]
    end

    test "fails when :check_csrf and :check_origin both disabled in transport config" do
      Application.put_env(:combo, SocketEndpoint, [])

      assert_raise ArgumentError, ~r/one of :check_origin and :check_csrf must be set/, fn ->
        Combo.Endpoint.Supervisor.init({:combo, SocketEndpoint, []})
      end

      Application.delete_env(:combo, SocketEndpoint)
    end

    defmodule SocketEndpointWithCheckOriginDisabled do
      use Combo.Endpoint, otp_app: :combo
      socket "/ws", TestSocket, websocket: [check_csrf: false]
    end

    test "fails when :check_origin is disabled in endpoint config and :check_csrf is disabled in transport config" do
      Application.put_env(:combo, SocketEndpointWithCheckOriginDisabled, check_origin: false)

      assert_raise ArgumentError, ~r/one of :check_origin and :check_csrf must be set/, fn ->
        Combo.Endpoint.Supervisor.init({:combo, SocketEndpointWithCheckOriginDisabled, []})
      end

      Application.delete_env(:combo, SocketEndpointWithCheckOriginDisabled)
    end
  end
end
