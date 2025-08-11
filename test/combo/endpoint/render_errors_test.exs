defmodule Combo.Endpoint.RenderErrorsTest do
  use ExUnit.Case, async: true
  use RouterHelper

  Application.put_env(:combo, __MODULE__.Endpoint, [])

  import ExUnit.CaptureLog
  error_view = __MODULE__

  def render("app.html", assigns) do
    "Layout: " <> assigns.inner_content
  end

  def render("404.html", %{
        kind: kind,
        reason: _reason,
        stack: _stack,
        status: 404,
        conn: conn
      }) do
    "Got 404 from #{kind} with #{conn.method}"
  end

  def render("404.json", %{
        kind: kind,
        reason: _reason,
        stack: _stack,
        status: 404,
        conn: conn
      }) do
    %{error: "Got 404 from #{kind} with #{conn.method}"}
  end

  def render("415.html", %{
        kind: kind,
        reason: _reason,
        stack: _stack,
        status: 415,
        conn: conn
      }) do
    "Got 415 from #{kind} with #{conn.method}"
  end

  def render("500.html", %{
        kind: kind,
        reason: _reason,
        stack: _stack,
        status: 500,
        conn: conn
      }) do
    "Got 500 from #{kind} with #{conn.method}"
  end

  def render("500.text", _) do
    "500 in TEXT"
  end

  defmodule Router do
    use Plug.Router
    use Combo.Endpoint.RenderErrors, formats: [html: error_view, json: error_view]

    plug :match
    plug :dispatch

    get "/boom" do
      resp(conn, 200, "oops")
      raise "oops"
    end

    get "/send_and_boom" do
      send_resp(conn, 200, "oops")
      raise "oops"
    end

    get "/send_and_wrapped" do
      stack =
        try do
          raise "oops"
        rescue
          _ -> __STACKTRACE__
        end

      # Those are always ignored and must be explicitly opted-in.
      conn =
        conn
        |> Combo.Controller.put_layout({Unknown, "layout"})
        |> Combo.Controller.put_root_layout({Unknown, "root"})

      reason = ArgumentError.exception("oops")
      raise Plug.Conn.WrapperError, conn: conn, kind: :error, stack: stack, reason: reason
    end

    match _ do
      raise Combo.Router.NoRouteError, conn: conn, router: __MODULE__
    end
  end

  defmodule Endpoint do
    use Combo.Endpoint, otp_app: :combo
  end

  setup do
    Logger.disable(self())
    :ok
  end

  test "call/2 is overridden" do
    assert_raise RuntimeError, "oops", fn ->
      call(Router, :get, "/boom")
    end

    assert_received {:plug_conn, :sent}
  end

  test "call/2 is overridden but is a no-op when response is already sent" do
    assert_raise RuntimeError, "oops", fn ->
      call(Router, :get, "/send_and_boom")
    end

    assert_received {:plug_conn, :sent}
  end

  test "call/2 is overridden with no route match as HTML and does not reraise" do
    call(Router, :get, "/unknown")

    assert_received {:plug_conn, :sent}
  end

  test "call/2 is overridden with no route match as JSON and does not reraise" do
    call(Router, :get, "/unknown?_format=json")

    assert_received {:plug_conn, :sent}
  end

  @tag :capture_log
  test "call/2 is overridden with no route match while malformed format and does not reraise" do
    call(Router, :get, "/unknown?_format=unknown")

    assert_received {:plug_conn, :sent}
  end

  test "call/2 is overridden and unwraps wrapped errors" do
    assert_raise ArgumentError, "oops", fn ->
      conn(:get, "/send_and_wrapped") |> Router.call([])
    end

    assert_received {:plug_conn, :sent}
  end

  test "logs converted errors if response has not yet been sent" do
    Logger.enable(self())
    conn = put_endpoint(conn(:get, "/"))

    assert capture_log(fn ->
             assert_render(500, conn, [], fn -> throw(:hello) end)
           end) =~ "Converted throw :hello to 500"

    assert capture_log(fn ->
             assert_render(500, conn, [], fn -> raise "boom" end)
           end) =~ "Converted error RuntimeError to 500"

    assert capture_log(fn ->
             assert_render(500, conn, [], fn -> exit(:timeout) end)
           end) =~ "Converted exit :timeout to 500"
  end

  test "does not log converted errors if response already sent" do
    conn = put_endpoint(conn(:get, "/"))

    try do
      try do
        Plug.Conn.send_resp(conn, 200, "hello")
        throw(:hello)
      catch
        kind, reason ->
          stack = __STACKTRACE__
          opts = [html: __MODULE__]
          Combo.Endpoint.RenderErrors.__catch__(conn, kind, reason, stack, opts)
      else
        _ -> flunk("function should have failed")
      end
    catch
      :throw, :hello -> :ok
    end
  end

  defp put_endpoint(conn) do
    Plug.Conn.put_private(conn, :combo_endpoint, Endpoint)
  end

  defp assert_render(status, conn, opts, func) do
    opts =
      if opts[:formats] do
        opts
      else
        opts |> Keyword.put_new(:formats, html: __MODULE__)
      end

    {^status, _, body} =
      Combo.ConnTest.assert_error_sent(status, fn ->
        try do
          func.()
        catch
          kind, reason ->
            stack = __STACKTRACE__
            Combo.Endpoint.RenderErrors.__catch__(conn, kind, reason, stack, opts)
        else
          _ -> flunk("function should have failed")
        end
      end)

    body
  end

  test "exception page for throws" do
    body =
      assert_render(500, conn(:get, "/"), [], fn ->
        throw(:hello)
      end)

    assert body == "Got 500 from throw with GET"
  end

  test "exception page for errors" do
    body =
      assert_render(500, conn(:get, "/"), [], fn ->
        :erlang.error(:badarg)
      end)

    assert body == "Got 500 from error with GET"
  end

  test "exception page for exceptions" do
    body =
      assert_render(415, conn(:get, "/"), [], fn ->
        raise Plug.Parsers.UnsupportedMediaTypeError, media_type: "foo/bar"
      end)

    assert body == "Got 415 from error with GET"
  end

  test "exception page for exits" do
    body =
      assert_render(500, conn(:get, "/"), [], fn ->
        exit({:timedout, {GenServer, :call, [:foo, :bar]}})
      end)

    assert body == "Got 500 from exit with GET"
  end

  test "exception page ignores params _format" do
    conn = conn(:get, "/", _format: "text")

    body =
      assert_render(500, conn, [formats: [html: __MODULE__, text: __MODULE__]], fn ->
        throw(:hello)
      end)

    assert body == "500 in TEXT"
  end

  test "exception page uses stored _format" do
    conn = conn(:get, "/") |> put_private(:combo_format, "text")

    body =
      assert_render(500, conn, [formats: [html: __MODULE__, text: __MODULE__]], fn ->
        throw(:hello)
      end)

    assert body == "500 in TEXT"
  end

  test "exception page with custom format" do
    body =
      assert_render(500, conn(:get, "/"), [formats: [text: __MODULE__]], fn ->
        throw(:hello)
      end)

    assert body == "500 in TEXT"
  end

  test "exception page with layout" do
    body =
      assert_render(500, conn(:get, "/"), [layout: {__MODULE__, :app}], fn ->
        throw(:hello)
      end)

    assert body == "Layout: Got 500 from throw with GET"
  end

  test "exception page with root layout" do
    body =
      assert_render(500, conn(:get, "/"), [root_layout: {__MODULE__, :app}], fn ->
        throw(:hello)
      end)

    assert body == "Layout: Got 500 from throw with GET"
  end

  test "exception page with formats" do
    body =
      assert_render(500, conn(:get, "/"), [formats: [text: __MODULE__]], fn ->
        throw(:hello)
      end)

    assert body == "500 in TEXT"
  end

  test "exception page is shown even with invalid format" do
    conn = conn(:get, "/") |> put_req_header("accept", "unknown/unknown")
    body = assert_render(500, conn, [], fn -> throw(:hello) end)
    assert body == "Got 500 from throw with GET"
  end

  test "exception page is shown even with invalid query parameters" do
    body = assert_render(500, conn(:get, "/?q=%{"), [], fn -> throw(:hello) end)

    assert body == "Got 500 from throw with GET"
  end

  test "captures warning when format is not supported" do
    Logger.enable(self())

    assert capture_log(fn ->
             conn = conn(:get, "/") |> put_req_header("accept", "unknown/unknown")
             assert_render(500, conn, [], fn -> throw(:hello) end)
           end) =~ "Could not render errors due to no supported media type in accept header"
  end

  test "captures warning when format does not match error view" do
    Logger.enable(self())

    assert capture_log(fn ->
             conn = conn(:get, "/?_format=unknown")
             assert_render(500, conn, [], fn -> throw(:hello) end)
           end) =~ "Could not render errors due to unknown format \"unknown\""
  end

  test "exception page for NoRouteError with plug_status 404 renders and does not reraise" do
    conn = call(Router, :get, "/unknown")
    assert Combo.ConnTest.response(conn, 404) =~ "Got 404 from error with GET"
  end
end
