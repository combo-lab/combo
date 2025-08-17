defmodule Combo.LiveReloaderTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  defmodule Endpoint do
    use Combo.Endpoint, otp_app: :combo

    socket "/socket", Combo.LiveReloader.Socket
  end

  Application.put_env(:combo, Endpoint,
    live_reloader: [
      patterns: [
        ~r"priv/static/.*(js|css|png|jpeg|jpg|gif)$"
      ]
    ]
  )

  defmodule EndpointWithScriptConfig do
    use Combo.Endpoint, otp_app: :combo

    socket "/socket", Combo.LiveReloader.Socket
  end

  Application.put_env(:combo, EndpointWithScriptConfig,
    url: [path: "/prefix"],
    live_reloader: [
      patterns: [
        ~r"priv/static/.*(js|css|png|jpeg|jpg|gif)$"
      ]
    ]
  )

  defmodule EndpointWithTargetWindowConfig do
    use Combo.Endpoint, otp_app: :combo

    socket "/socket", Combo.LiveReloader.Socket
  end

  Application.put_env(:combo, EndpointWithTargetWindowConfig,
    live_reloader: [
      patterns: [
        ~r"priv/static/.*(js|css|png|jpeg|jpg|gif)$"
      ],
      target_window: :top
    ]
  )

  defp build_conn(path, endpoint) do
    conn(:get, path)
    |> Plug.Conn.put_private(:combo_endpoint, endpoint)
  end

  setup_all do
    children = [
      Endpoint,
      EndpointWithScriptConfig,
      EndpointWithTargetWindowConfig
    ]

    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)
    :ok
  end

  describe "iframe injection" do
    test "applied for HTML responses whose body contains <body> tag" do
      opts = Combo.LiveReloader.init([])

      conn =
        build_conn("/", Endpoint)
        |> put_resp_content_type("text/html")
        |> Combo.LiveReloader.call(opts)
        |> send_resp(200, "<html><body><h1>Demo</h1></body></html>")

      assert to_string(conn.resp_body) ==
               "<html><body><h1>Demo</h1><iframe hidden height=\"0\" width=\"0\" src=\"/combo/live_reload/iframe\"></iframe></body></html>"
    end

    test "applied for HTML responses whose body contains multiple <body> tags" do
      opts = Combo.LiveReloader.init([])

      conn =
        build_conn("/", Endpoint)
        |> put_resp_content_type("text/html")
        |> Combo.LiveReloader.call(opts)
        |> send_resp(200, "<html><body><h1><body>Demo</body></h1></body></html>")

      assert to_string(conn.resp_body) ==
               "<html><body><h1><body>Demo</body></h1><iframe hidden height=\"0\" width=\"0\" src=\"/combo/live_reload/iframe\"></iframe></body></html>"
    end

    test "skipped for HTML responses whose body missing <body> tag" do
      opts = Combo.LiveReloader.init([])

      conn =
        build_conn("/", Endpoint)
        |> put_resp_content_type("text/html")
        |> Combo.LiveReloader.call(opts)
        |> send_resp(200, "<h1>Demo</h1>")

      assert to_string(conn.resp_body) == "<h1>Demo</h1>"
    end

    test "skipped for HTML responses whose body is empty" do
      opts = Combo.LiveReloader.init([])

      conn =
        build_conn("/", Endpoint)
        |> put_resp_content_type("text/html")
        |> Combo.LiveReloader.call(opts)
        |> send_file(200, Path.join(__DIR__, "../fixtures/example-download-file"))

      assert conn.status == 200
      assert to_string(conn.resp_body) == "Example download file.\n"
    end

    test "skipped for non-HTML responses" do
      opts = Combo.LiveReloader.init([])

      conn =
        build_conn("/", Endpoint)
        |> put_resp_content_type("application/json")
        |> Combo.LiveReloader.call(opts)
        |> send_resp(200, "{}")

      assert to_string(conn.resp_body) == "{}"
    end

    test "works for HTML responses whose body is an iolist" do
      opts = Combo.LiveReloader.init([])

      conn =
        build_conn("/", Endpoint)
        |> put_resp_content_type("text/html")
        |> Combo.LiveReloader.call(opts)
        |> send_resp(200, [
          "<html>",
          ~c"<bo",
          [?d, ?y | ">"],
          "<h1>Demo</h1>",
          "</b",
          ?o,
          ~c"dy>",
          "</html>"
        ])

      assert to_string(conn.resp_body) ==
               "<html><body><h1>Demo</h1><iframe hidden height=\"0\" width=\"0\" src=\"/combo/live_reload/iframe\"></iframe></body></html>"
    end
  end

  test "default iframe content" do
    conn =
      build_conn("/combo/live_reload/iframe", Endpoint)
      |> Combo.LiveReloader.call([])

    assert conn.status == 200

    assert to_string(conn.resp_body) =~
             ~s[var path = "/combo/live_reload/socket";\n]

    assert to_string(conn.resp_body) =~
             ~s[var debounceTime = 100;\n]

    assert to_string(conn.resp_body) =~
             ~s[var targetWindow = "parent";\n]

    assert to_string(conn.resp_body) =~
             ~s[var fullReloadOnCssChanges = false;\n]

    refute to_string(conn.resp_body) =~
             ~s[<iframe]
  end

  test "works with script config" do
    opts = Combo.LiveReloader.init([])

    conn =
      build_conn("/", EndpointWithScriptConfig)
      |> put_resp_content_type("text/html")
      |> Combo.LiveReloader.call(opts)
      |> send_resp(200, "<html><body><h1>Demo</h1></body></html>")

    assert to_string(conn.resp_body) ==
             "<html><body><h1>Demo</h1><iframe hidden height=\"0\" width=\"0\" src=\"/prefix/combo/live_reload/iframe\"></iframe></body></html>"
  end
end
