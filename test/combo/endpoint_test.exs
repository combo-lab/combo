defmodule Combo.EndpointTest do
  use ExUnit.Case
  use Support.RouterHelper
  import ExUnit.CaptureLog

  defmodule Endpoint do
    use Combo.Endpoint, otp_app: :combo

    # assert endpoint variables
    assert @otp_app == :combo
    assert live_reloading? == false
    assert code_reloading? == false
    assert debug_errors? == false
    assert force_ssl == nil
  end

  @manifest_file "../../../../test/fixtures/static/compile/manifest-new.digest.json"

  defp with_endpoint!(config, fun), do: with_endpoint!(Endpoint, config, fun)

  defp with_endpoint!(endpoint, config, fun)
       when is_atom(endpoint) and is_list(config) and is_function(fun, 1) do
    Application.put_env(:combo, endpoint, config)
    capture_log(fn -> start_supervised!(endpoint) end)
    fun.(endpoint)
    stop_supervised!(endpoint)
    Application.delete_env(:combo, endpoint)
  end

  defp with_config!(endpoint, config, fun)
       when is_atom(endpoint) and is_list(config) and is_function(fun, 1) do
    Application.put_env(:combo, endpoint, config)
    fun.(endpoint)
    Application.delete_env(:combo, endpoint)
  end

  test "injects pubsub functions" do
    start_supervised!({Phoenix.PubSub, name: :endpoint_pubsub})

    with_endpoint!([pubsub_server: :endpoint_pubsub], fn endpoint ->
      assert :ok = endpoint.subscribe("sometopic")

      some = spawn(fn -> :ok end)

      endpoint.broadcast_from(some, "sometopic", "event1", %{key: :val})

      assert_receive %Combo.Socket.Broadcast{
        event: "event1",
        payload: %{key: :val},
        topic: "sometopic"
      }

      endpoint.broadcast_from!(some, "sometopic", "event2", %{key: :val})

      assert_receive %Combo.Socket.Broadcast{
        event: "event2",
        payload: %{key: :val},
        topic: "sometopic"
      }

      endpoint.broadcast("sometopic", "event3", %{key: :val})

      assert_receive %Combo.Socket.Broadcast{
        event: "event3",
        payload: %{key: :val},
        topic: "sometopic"
      }

      endpoint.broadcast!("sometopic", "event4", %{key: :val})

      assert_receive %Combo.Socket.Broadcast{
        event: "event4",
        payload: %{key: :val},
        topic: "sometopic"
      }

      endpoint.local_broadcast_from(some, "sometopic", "event5", %{key: :val})

      assert_receive %Combo.Socket.Broadcast{
        event: "event5",
        payload: %{key: :val},
        topic: "sometopic"
      }

      endpoint.local_broadcast("sometopic", "event6", %{key: :val})

      assert_receive %Combo.Socket.Broadcast{
        event: "event6",
        payload: %{key: :val},
        topic: "sometopic"
      }

      assert :ok = endpoint.unsubscribe("sometopic")
    end)
  end

  test "defines child_spec/1" do
    assert Endpoint.child_spec([]) == %{
             id: Endpoint,
             start: {Endpoint, :start_link, [[]]},
             type: :supervisor
           }
  end

  test "warns if there is no configuration is given" do
    assert capture_log(fn ->
             Endpoint.start_link()
           end) =~ "no configuration"
  end

  test "config/1" do
    with_endpoint!(
      [
        url: [host: "example.com", path: "/api"],
        static_url: [host: "static.example.com"]
      ],
      fn endpoint ->
        assert is_binary(endpoint.config(:endpoint_id))
        assert endpoint.config(:url) == [host: "example.com", path: "/api"]
        assert endpoint.config(:static_url) == [host: "static.example.com"]
      end
    )
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

  describe "validates :check_origin and :check_csrf socket options" do
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
      with_config!(SocketEndpoint, [], fn _ ->
        assert_raise ArgumentError, ~r/one of :check_origin and :check_csrf must be set/, fn ->
          Combo.Endpoint.Supervisor.init({:combo, SocketEndpoint, []})
        end
      end)
    end

    defmodule SocketEndpointWithCheckOriginDisabled do
      use Combo.Endpoint, otp_app: :combo
      socket "/ws", TestSocket, websocket: [check_csrf: false]
    end

    test "fails when :check_origin is disabled in endpoint config and :check_csrf is disabled in transport config" do
      with_config!(SocketEndpointWithCheckOriginDisabled, [check_origin: false], fn _ ->
        assert_raise ArgumentError, ~r/one of :check_origin and :check_csrf must be set/, fn ->
          Combo.Endpoint.Supervisor.init({:combo, SocketEndpointWithCheckOriginDisabled, []})
        end
      end)
    end
  end

  # ================================================

  describe "url/0" do
    test "uses :url config" do
      with_endpoint!(
        [
          https: false,
          http: false,
          url: [host: "example.com"]
        ],
        fn endpoint ->
          assert endpoint.url() == "http://example.com"
        end
      )

      with_endpoint!(
        [
          https: false,
          http: false,
          url: [scheme: "http", host: "example.com"]
        ],
        fn endpoint ->
          assert endpoint.url() == "http://example.com"
        end
      )

      with_endpoint!(
        [
          https: false,
          http: false,
          url: [scheme: "arbitrary", host: "example.com"]
        ],
        fn endpoint ->
          assert endpoint.url() == "arbitrary://example.com:80"
        end
      )

      with_endpoint!(
        [
          https: false,
          http: false,
          url: [scheme: "arbitrary", host: "example.com", port: 1024]
        ],
        fn endpoint ->
          assert endpoint.url() == "arbitrary://example.com:1024"
        end
      )
    end

    test "infers scheme and port from :https config" do
      with_endpoint!(
        [
          https: [port: 443],
          http: false,
          url: [host: "example.com"]
        ],
        fn endpoint ->
          assert endpoint.url() == "https://example.com"
        end
      )

      with_endpoint!(
        [
          https: [port: 1024],
          http: false,
          url: [host: "example.com"]
        ],
        fn endpoint ->
          assert endpoint.url() == "https://example.com:1024"
        end
      )
    end

    test "infers scheme and port from :http config" do
      with_endpoint!(
        [
          https: false,
          http: [port: 80],
          url: [host: "example.com"]
        ],
        fn endpoint ->
          assert endpoint.url() == "http://example.com"
        end
      )

      with_endpoint!(
        [
          https: false,
          http: [port: 1024],
          url: [host: "example.com"]
        ],
        fn endpoint ->
          assert endpoint.url() == "http://example.com:1024"
        end
      )
    end
  end

  describe "url_struct/0" do
    test "returns the %URI{} conrrespoding to url/0" do
      with_endpoint!(
        [
          https: false,
          http: false,
          url: [host: "example.com"]
        ],
        fn endpoint ->
          assert endpoint.url_struct() == %URI{
                   scheme: "http",
                   userinfo: nil,
                   host: "example.com",
                   port: 80,
                   path: nil,
                   query: nil,
                   fragment: nil
                 }
        end
      )
    end
  end

  describe "host/0" do
    test "returns the host" do
      with_endpoint!(
        [
          https: false,
          http: false,
          url: [host: "example.com"]
        ],
        fn endpoint ->
          assert endpoint.host() == "example.com"
        end
      )
    end
  end

  describe "path/1" do
    test "builds path with :url config" do
      with_endpoint!([], fn endpoint ->
        assert endpoint.path("/users") == "/users"
      end)

      with_endpoint!([url: [path: ""]], fn endpoint ->
        assert endpoint.path("/users") == "/users"
      end)

      with_endpoint!([url: [path: "/"]], fn endpoint ->
        assert endpoint.path("/users") == "/users"
      end)

      with_endpoint!([url: [path: "/admin"]], fn endpoint ->
        assert endpoint.path("/users") == "/admin/users"
      end)
    end
  end

  describe "script_name/0" do
    test "uses the path of :url config as the source of script_name" do
      with_endpoint!([url: [host: "example.com", path: ""]], fn endpoint ->
        assert endpoint.script_name() == []
      end)

      with_endpoint!([url: [host: "example.com", path: "/"]], fn endpoint ->
        assert endpoint.script_name() == []
      end)

      with_endpoint!([url: [host: "example.com", path: "/api"]], fn endpoint ->
        assert endpoint.script_name() == ["api"]
      end)
    end
  end

  describe "static_url/0" do
    test "uses :static_url config" do
      with_endpoint!(
        [
          https: false,
          http: false,
          url: [host: "example.com"],
          static_url: [host: "static.example.com"]
        ],
        fn endpoint ->
          assert endpoint.static_url() == "http://static.example.com"
        end
      )

      with_endpoint!(
        [
          https: false,
          http: false,
          url: [host: "example.com"],
          static_url: [scheme: "http", host: "static.example.com"]
        ],
        fn endpoint ->
          assert endpoint.static_url() == "http://static.example.com"
        end
      )

      with_endpoint!(
        [
          https: false,
          http: false,
          url: [host: "example.com"],
          static_url: [scheme: "arbitrary", host: "static.example.com"]
        ],
        fn endpoint ->
          assert endpoint.static_url() == "arbitrary://static.example.com:80"
        end
      )

      with_endpoint!(
        [
          https: false,
          http: false,
          url: [host: "example.com"],
          static_url: [scheme: "arbitrary", host: "example.com", port: 1024]
        ],
        fn endpoint ->
          assert endpoint.static_url() == "arbitrary://example.com:1024"
        end
      )
    end

    test "infers scheme and port from :https config" do
      with_endpoint!(
        [
          https: [port: 443],
          http: false,
          static_url: [host: "static.example.com"]
        ],
        fn endpoint ->
          assert endpoint.static_url() == "https://static.example.com"
        end
      )

      with_endpoint!(
        [
          https: [port: 1024],
          http: false,
          static_url: [host: "static.example.com"]
        ],
        fn endpoint ->
          assert endpoint.static_url() == "https://static.example.com:1024"
        end
      )
    end

    test "infers scheme and port from :http config" do
      with_endpoint!(
        [
          https: false,
          http: [port: 80],
          static_url: [host: "static.example.com"]
        ],
        fn endpoint ->
          assert endpoint.static_url() == "http://static.example.com"
        end
      )

      with_endpoint!(
        [
          https: false,
          http: [port: 1024],
          static_url: [host: "static.example.com"]
        ],
        fn endpoint ->
          assert endpoint.static_url() == "http://static.example.com:1024"
        end
      )
    end

    test "fallbacks to use :url config when :static_url config is not set" do
      with_endpoint!(
        [
          https: false,
          http: [port: 80],
          url: [host: "example.com"]
        ],
        fn endpoint ->
          assert endpoint.static_url() == "http://example.com"
        end
      )
    end
  end

  describe "static_path/1" do
    test "validates path" do
      with_endpoint!([], fn endpoint ->
        safe_valid_path = "/safe_valid_path"
        assert endpoint.static_path(safe_valid_path) == safe_valid_path

        assert_raise ArgumentError, ~r|unsafe characters|, fn ->
          endpoint.static_path("/\\unsafe_path")
        end

        assert_raise ArgumentError, ~r|expected a path starting with a single /|, fn ->
          endpoint.static_path("//invalid_path")
        end
      end)
    end

    test "prefixes path with the path given by :static_url config" do
      with_endpoint!([], fn endpoint ->
        assert endpoint.static_path("/logo.png") == "/logo.png"
      end)

      with_endpoint!([static_url: [path: ""]], fn endpoint ->
        assert endpoint.static_path("/logo.png") == "/logo.png"
      end)

      with_endpoint!([static_url: [path: "/"]], fn endpoint ->
        assert endpoint.static_path("/logo.png") == "/logo.png"
      end)

      with_endpoint!([static_url: [path: "/static"]], fn endpoint ->
        assert endpoint.static_path("/logo.png") == "/static/logo.png"
      end)
    end

    test "falls back to use the path given by :url config" do
      with_endpoint!([url: [path: "/admin"]], fn endpoint ->
        assert endpoint.static_path("/logo.png") == "/admin/logo.png"
      end)
    end

    test "builds path with hashed name and ?vsd=d query string according to :static config" do
      with_endpoint!([static: []], fn endpoint ->
        assert endpoint.static_path("/assets/js/app.js") == "/assets/js/app.js"
      end)

      with_endpoint!([static: [manifest: nil]], fn endpoint ->
        assert endpoint.static_path("/assets/js/app.js") == "/assets/js/app.js"
      end)

      with_endpoint!([static: [manifest: @manifest_file]], fn endpoint ->
        assert endpoint.static_path("/assets/js/app.js") ==
                 "/assets/js/app-5ef562abd8514711de540eddaa53be19.js?vsn=d"
      end)

      # load manifest from specified OTP application
      with_endpoint!([static: [manifest: {:combo, @manifest_file}]], fn endpoint ->
        assert endpoint.static_path("/assets/js/app.js") ==
                 "/assets/js/app-5ef562abd8514711de540eddaa53be19.js?vsn=d"
      end)

      with_endpoint!([static: [manifest: @manifest_file, vsn: true]], fn endpoint ->
        assert endpoint.static_path("/assets/js/app.js") ==
                 "/assets/js/app-5ef562abd8514711de540eddaa53be19.js?vsn=d"

        assert endpoint.static_path("/assets/js/app.js#info") ==
                 "/assets/js/app-5ef562abd8514711de540eddaa53be19.js?vsn=d#info"

        # multiple presences of # are treated as a fragment
        assert endpoint.static_path("/assets/js/app.js#info#me") ==
                 "/assets/js/app-5ef562abd8514711de540eddaa53be19.js?vsn=d#info#me"
      end)

      with_endpoint!([static: [manifest: @manifest_file, vsn: false]], fn endpoint ->
        assert endpoint.static_path("/assets/js/app.js") ==
                 "/assets/js/app-5ef562abd8514711de540eddaa53be19.js"

        assert endpoint.static_path("/assets/js/app.js#info") ==
                 "/assets/js/app-5ef562abd8514711de540eddaa53be19.js#info"

        # multiple presences of # are treated as a fragment
        assert endpoint.static_path("/assets/js/app.js#info#me") ==
                 "/assets/js/app-5ef562abd8514711de540eddaa53be19.js#info#me"
      end)
    end
  end

  describe "static_integrity/1" do
    test "validates path" do
      with_endpoint!([], fn endpoint ->
        safe_valid_path = "/some_valid_path"
        assert is_nil(endpoint.static_integrity(safe_valid_path))

        assert_raise ArgumentError, ~r/unsafe characters/, fn ->
          endpoint.static_integrity("/\\unsafe_path")
        end

        assert_raise ArgumentError, ~r|expected a path starting with a single /|, fn ->
          endpoint.static_integrity("//invalid_path")
        end
      end)
    end

    test "gets the integrity when the static file exists" do
      with_endpoint!([static: [manifest: @manifest_file]], fn endpoint ->
        assert endpoint.static_integrity("/assets/js/app.js") ==
                 "sha512-ES089+qHBbaXGOcOQMF0odNcZgRL0T+093SQktfaVc2UO1WgghzPjgwNEeh57zymJRk1hBKqJhpwlHtCvbwiFw=="
      end)
    end

    test "gets nil when the static file exist, but the manifest is absent" do
      with_endpoint!([static: [manifest: nil]], fn endpoint ->
        assert endpoint.static_integrity("/assets/js/app.js") == nil
      end)
    end

    test "gets nil when the static file doesn't exist" do
      with_endpoint!([static: [manifest: @manifest_file]], fn endpoint ->
        assert endpoint.static_integrity("/assets/js/unknown.js") == nil
      end)
    end
  end

  describe "server_info/1" do
    test "returns the address and port that the server is listening on" do
      with_endpoint!(
        [
          http: [ip: {127, 0, 0, 1}, port: 0],
          server: true
        ],
        fn endpoint ->
          {:ok, {address, port}} = endpoint.server_info(:http)
          assert address == {127, 0, 0, 1}
          assert is_integer(port)
        end
      )
    end
  end

  describe "server?/2" do
    test "returns true when :server config is set to true", config do
      endpoint = Module.concat(__MODULE__, config.test)

      Application.put_env(:combo, endpoint, server: true)
      on_exit(fn -> Application.delete_env(:combo, endpoint) end)

      assert Combo.Endpoint.server?(:combo, endpoint)
    end

    test "returns false when :server config is set to false", config do
      endpoint = Module.concat(__MODULE__, config.test)

      Application.put_env(:combo, :serve_endpoints, true)
      Application.put_env(:combo, endpoint, server: false)
      on_exit(fn -> Application.delete_env(:combo, :serve_endpoints) end)
      on_exit(fn -> Application.delete_env(:combo, endpoint) end)

      refute Combo.Endpoint.server?(:combo, endpoint)
    end

    test "returns true when :serve_endpoints env is set to true", config do
      endpoint = Module.concat(__MODULE__, config.test)

      Application.put_env(:combo, :serve_endpoints, true)
      Application.put_env(:combo, endpoint, [])
      on_exit(fn -> Application.delete_env(:combo, :serve_endpoints) end)
      on_exit(fn -> Application.delete_env(:combo, endpoint) end)

      assert Combo.Endpoint.server?(:combo, endpoint)
    end

    test "returns false when no serve_endpoints is found", config do
      endpoint = Module.concat(__MODULE__, config.test)

      Application.delete_env(:combo, :serve_endpoints)
      Application.put_env(:combo, endpoint, [])
      on_exit(fn -> Application.delete_env(:combo, :serve_endpoints) end)
      on_exit(fn -> Application.delete_env(:combo, endpoint) end)

      refute Combo.Endpoint.server?(:combo, endpoint)
    end
  end

  test "logs info if :http or :https config is set but not :server when running inside release" do
    # simulate running inside release
    System.put_env("RELEASE_NAME", "app-test")

    on_exit(fn ->
      System.delete_env("RELEASE_NAME")
      Application.delete_env(:combo, Endpoint)
    end)

    message = "Configuration :server was not enabled"

    Application.put_env(:combo, Endpoint, server: false, http: [], https: [])
    assert capture_log(fn -> start_supervised(Endpoint) end) =~ message
    stop_supervised!(Endpoint)

    Application.put_env(:combo, Endpoint, server: false, http: [])
    assert capture_log(fn -> start_supervised(Endpoint) end) =~ message
    stop_supervised!(Endpoint)

    Application.put_env(:combo, Endpoint, server: false, https: [])
    assert capture_log(fn -> start_supervised(Endpoint) end) =~ message
    stop_supervised!(Endpoint)

    Application.put_env(:combo, Endpoint, server: false)
    refute capture_log(fn -> start_supervised(Endpoint) end) =~ message
    stop_supervised!(Endpoint)

    Application.put_env(:combo, Endpoint, server: true)
    refute capture_log(fn -> start_supervised(Endpoint) end) =~ message
    stop_supervised!(Endpoint)
  end

  describe "watchers" do
    @watchers [npm: ["run", "dev", cd: "."]]

    @tag :capture_log
    test "starts when :server config is true" do
      Application.put_env(:combo, Endpoint, server: true, watchers: @watchers)
      on_exit(fn -> Application.delete_env(:combo, Endpoint) end)

      pid = start_supervised!(Endpoint)
      children = Supervisor.which_children(pid)

      assert Enum.any?(children, fn
               {_, _, _, [Combo.Endpoint.Watcher]} -> true
               _ -> false
             end)
    end

    @tag :capture_log
    test "doesn't starts when :server config is true, but :watchers config is false" do
      Application.put_env(:combo, Endpoint, server: true, watchers: false)
      on_exit(fn -> Application.delete_env(:combo, Endpoint) end)

      pid = start_supervised!(Endpoint)
      children = Supervisor.which_children(pid)

      refute Enum.any?(children, fn
               {_, _, _, [Combo.Endpoint.Watcher]} -> true
               _ -> false
             end)
    end

    @tag :capture_log
    test "doesn't starts when :server config is false" do
      Application.put_env(:combo, Endpoint, server: false, watchers: @watchers)
      on_exit(fn -> Application.delete_env(:combo, Endpoint) end)

      pid = start_supervised!(Endpoint)
      children = Supervisor.which_children(pid)

      refute Enum.any?(children, fn
               {_, _, _, [Combo.Endpoint.Watcher]} -> true
               _ -> false
             end)
    end

    @tag :capture_log
    test "starts when :server config is false, but `mix combo.serve` is running" do
      Application.put_env(:combo, :serve_endpoints, true)
      Application.put_env(:combo, Endpoint, server: false, watchers: @watchers)

      on_exit(fn ->
        Application.delete_env(:combo, :serve_endpoints)
        Application.delete_env(:combo, Endpoint)
      end)

      pid = start_supervised!(Endpoint)
      children = Supervisor.which_children(pid)

      assert Enum.any?(children, fn
               {_, _, _, [Combo.Endpoint.Watcher]} -> true
               _ -> false
             end)
    end
  end

  test "sets script_name for conn when using path in :url config" do
    with_endpoint!([url: [path: "/api"]], fn endpoint ->
      conn = conn(:get, "https://example.com/")
      assert endpoint.call(conn, []).script_name == ["api"]

      conn = put_in(conn.script_name, ["foo"])
      assert endpoint.call(conn, []).script_name == ["api"]
    end)
  end

  describe ":force_ssl config" do
    Application.put_env(:combo, __MODULE__.ForceSSLEndpoint, force_ssl: [subdomains: true])

    defmodule ForceSSLEndpoint do
      use Combo.Endpoint, otp_app: :combo
    end

    test "redirects http requests to https on force_ssl" do
      with_endpoint!(ForceSSLEndpoint, [url: [host: "example.com"]], fn endpoint ->
        conn = endpoint.call(conn(:get, "/"), [])
        assert get_resp_header(conn, "location") == ["https://example.com/"]
        assert conn.halted
      end)
    end

    test "sends hsts on https requests on force_ssl" do
      with_endpoint!(ForceSSLEndpoint, [url: [host: "example.com"]], fn endpoint ->
        conn = endpoint.call(conn(:get, "https://example.com/"), [])

        assert get_resp_header(conn, "strict-transport-security") == [
                 "max-age=31536000; includeSubDomains"
               ]
      end)
    end
  end
end
