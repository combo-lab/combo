# I should use Combo.ConnTest as the module name, but it conflicts with
# the name of an existing module.
defmodule Combo.Conn.Test do
  use ExUnit.Case, async: true

  import Plug.Conn
  alias Plug.Conn
  import Plug.Test
  import Combo.Conn

  defp sent_conn do
    conn(:get, "/") |> send_resp(:ok, "")
  end

  defp get_resp_content_type(conn) do
    [header] = get_resp_header(conn, "content-type")
    header |> String.split(";") |> Enum.fetch!(0)
  end

  ## Endpoints

  test "endpoint_module!/1" do
    conn = put_private(%Conn{}, :combo_endpoint, Hello)
    assert endpoint_module!(conn) == Hello
  end

  ## Routers

  test "router_module!/1" do
    conn = put_private(%Conn{}, :combo_router, Hello)
    assert router_module!(conn) == Hello
  end

  ## Controllers

  test "controller_module!/1" do
    conn = put_private(%Conn{}, :combo_controller, Hello)
    assert controller_module!(conn) == Hello
  end

  test "controller_action_name!/1" do
    conn = put_private(%Conn{}, :combo_action, :show)
    assert controller_action_name!(conn) == :show
  end

  ## Formats

  describe "accepts/2" do
    defp with_accept(header) do
      conn(:get, "/", [])
      |> put_req_header("accept", header)
    end

    test "uses params[\"_format\"] when available" do
      conn = accepts(conn(:get, "/", _format: "json"), ~w(json))
      assert get_format(conn) == "json"
      assert conn.params["_format"] == "json"

      exception =
        assert_raise Combo.NotAcceptableError, ~r/unknown format "json"/, fn ->
          accepts(conn(:get, "/", _format: "json"), ~w(html))
        end

      assert Plug.Exception.status(exception) == 406
      assert exception.accepts == ["html"]
    end

    test "uses first accepts on empty or catch-all header" do
      conn = accepts(conn(:get, "/", []), ~w(json))
      assert get_format(conn) == "json"
      assert conn.params["_format"] == nil

      conn = accepts(with_accept("*/*"), ~w(json))
      assert get_format(conn) == "json"
      assert conn.params["_format"] == nil
    end

    test "uses first matching accepts on empty subtype" do
      conn = accepts(with_accept("text/*"), ~w(json text css))
      assert get_format(conn) == "text"
      assert conn.params["_format"] == nil
    end

    test "on non-empty */*" do
      # Fallbacks to HTML due to browsers behavior
      conn = accepts(with_accept("application/json, */*"), ~w(html json))
      assert get_format(conn) == "html"
      assert conn.params["_format"] == nil

      conn = accepts(with_accept("*/*, application/json"), ~w(html json))
      assert get_format(conn) == "html"
      assert conn.params["_format"] == nil

      # No HTML is treated normally
      conn = accepts(with_accept("*/*, text/plain, application/json"), ~w(json text))
      assert get_format(conn) == "json"
      assert conn.params["_format"] == nil

      conn = accepts(with_accept("text/plain, application/json, */*"), ~w(json text))
      assert get_format(conn) == "text"
      assert conn.params["_format"] == nil

      conn = accepts(with_accept("text/*, application/*, */*"), ~w(json text))
      assert get_format(conn) == "text"
      assert conn.params["_format"] == nil
    end

    test "ignores invalid media types" do
      conn = accepts(with_accept("foo/bar, bar baz, application/json"), ~w(html json))
      assert get_format(conn) == "json"
      assert conn.params["_format"] == nil

      conn = accepts(with_accept("foo/*, */bar, text/*"), ~w(json html))
      assert get_format(conn) == "html"
      assert conn.params["_format"] == nil
    end

    test "considers q params" do
      conn = accepts(with_accept("text/html; q=0.7, application/json"), ~w(html json))
      assert get_format(conn) == "json"
      assert conn.params["_format"] == nil

      conn = accepts(with_accept("application/json, text/html; q=0.7"), ~w(html json))
      assert get_format(conn) == "json"
      assert conn.params["_format"] == nil

      conn = accepts(with_accept("application/json; q=1.0, text/html; q=0.7"), ~w(html json))
      assert get_format(conn) == "json"
      assert conn.params["_format"] == nil

      conn = accepts(with_accept("application/json; q=0.8, text/html; q=0.7"), ~w(html json))
      assert get_format(conn) == "json"
      assert conn.params["_format"] == nil

      conn = accepts(with_accept("text/html; q=0.7, application/json; q=0.8"), ~w(html json))
      assert get_format(conn) == "json"
      assert conn.params["_format"] == nil

      conn = accepts(with_accept("text/*; q=0.7, application/json"), ~w(html json))
      assert get_format(conn) == "json"
      assert conn.params["_format"] == nil

      conn = accepts(with_accept("application/json; q=0.7, text/*; q=0.8"), ~w(json html))
      assert get_format(conn) == "html"
      assert conn.params["_format"] == nil

      exception =
        assert_raise Combo.NotAcceptableError, ~r/no supported media type in accept/, fn ->
          accepts(with_accept("text/html; q=0.7, application/json; q=0.8"), ~w(xml))
        end

      assert Plug.Exception.status(exception) == 406
      assert exception.accepts == ["xml"]
    end
  end

  ## Layouts

  describe "layout/_" do
    test "without setting root layout" do
      conn = conn(:get, "/")

      assert layout(conn) == false
      assert layout(conn, nil) == false

      assert layout(conn, :html) == false
      assert layout(conn, "html") == false

      assert layout(conn, :print) == false
      assert layout(conn, "print") == false

      conn = conn(:get, "/") |> put_format(:html)

      assert layout(conn) == false
      assert layout(conn, nil) == false

      assert layout(conn, :html) == false
      assert layout(conn, "html") == false

      assert layout(conn, :print) == false
      assert layout(conn, "print") == false
    end

    test "with setting root layout" do
      conn = conn(:get, "/") |> put_layout(html: {DemoLayout, :app})

      assert layout(conn) == false
      assert layout(conn, nil) == false

      assert layout(conn, :html) == {DemoLayout, :app}
      assert layout(conn, "html") == {DemoLayout, :app}

      assert layout(conn, :print) == false
      assert layout(conn, "print") == false

      conn =
        conn(:get, "/")
        |> put_layout(html: {DemoLayout, :app})
        |> put_format("html")

      assert layout(conn) == {DemoLayout, :app}
      assert layout(conn, nil) == {DemoLayout, :app}

      assert layout(conn, :html) == {DemoLayout, :app}
      assert layout(conn, "html") == {DemoLayout, :app}

      assert layout(conn, :print) == false
      assert layout(conn, "print") == false
    end
  end

  test "put_layout/2" do
    conn = conn(:get, "/")

    conn = put_layout(conn, html: {DemoLayout, :app})
    assert layout(conn, :html) == {DemoLayout, :app}

    conn = put_layout(conn, html: {DemoLayout, :app}, print: {DemoLayout, :print})
    conn = put_format(conn, :html)
    assert layout(conn) == {DemoLayout, :app}
    conn = put_format(conn, :print)
    assert layout(conn) == {DemoLayout, :print}

    conn = conn(:get, "/")

    conn = put_layout(conn, html: {DemoLayout, :app}, print: false)
    assert layout(conn, :html) == {DemoLayout, :app}
    assert layout(conn, :print) == false

    conn = put_layout(conn, html: false, print: {DemoLayout, :print})
    assert layout(conn, :html) == false
    assert layout(conn, :print) == {DemoLayout, :print}

    assert_raise ArgumentError,
                 """
                 expected formats to be a keyword list following this spec:

                     [{format(), layout()}]

                 Got:

                     [html: :bad]
                 """,
                 fn ->
                   put_layout(%Conn{}, html: :bad)
                 end

    assert_raise ArgumentError,
                 """
                 expected formats to be a keyword list following this spec:

                     [{format(), layout()}]

                 Got:

                     :bad
                 """,
                 fn ->
                   put_layout(%Conn{}, :bad)
                 end

    assert_raise Plug.Conn.AlreadySentError,
                 """
                 the response was already sent.

                     Status code: 200
                     Request path: /
                     Method: GET
                     Layout formats: [html: {DemoLayout, :app}]
                 """,
                 fn ->
                   put_layout(sent_conn(), html: {DemoLayout, :app})
                 end
  end

  test "put_new_layout/2" do
    conn = conn(:get, "/")

    conn = put_new_layout(conn, html: {DemoLayout, :app}, print: false)
    assert layout(conn, :html) == {DemoLayout, :app}
    assert layout(conn, :print) == false

    conn = put_new_layout(conn, html: false, print: {DemoLayout, :print})
    assert layout(conn, :html) == {DemoLayout, :app}
    assert layout(conn, :print) == false

    assert_raise ArgumentError,
                 """
                 expected formats to be a keyword list following this spec:

                     [{format(), layout()}]

                 Got:

                     [html: :bad]
                 """,
                 fn ->
                   put_new_layout(%Conn{}, html: :bad)
                 end

    assert_raise ArgumentError,
                 """
                 expected formats to be a keyword list following this spec:

                     [{format(), layout()}]

                 Got:

                     :bad
                 """,
                 fn ->
                   put_new_layout(%Conn{}, :bad)
                 end

    assert_raise Plug.Conn.AlreadySentError,
                 """
                 the response was already sent.

                     Status code: 200
                     Request path: /
                     Method: GET
                     Layout formats: [html: {DemoLayout, :app}]
                 """,
                 fn ->
                   put_new_layout(sent_conn(), html: {DemoLayout, :app})
                 end
  end

  ## Views

  test "put_view/2" do
    conn = conn(:get, "/")

    conn = put_view(conn, html: DemoHTML)
    assert view_module(conn, :html) == DemoHTML

    conn = put_view(conn, html: DemoHTML, print: DemoPrint)
    conn = put_format(conn, :html)
    assert view_module(conn) == DemoHTML
    conn = put_format(conn, :print)
    assert view_module(conn) == DemoPrint

    conn = conn(:get, "/")

    conn = put_view(conn, html: DemoHTML, print: false)
    assert view_module(conn, :html) == DemoHTML
    assert view_module(conn, :print) == false

    conn = put_view(conn, html: false, print: DemoPrint)
    assert view_module(conn, :html) == false
    assert view_module(conn, :print) == DemoPrint

    assert_raise ArgumentError,
                 """
                 expected formats to be a keyword list following this spec:

                     [{format(), view()}]

                 Got:

                     [html: "bad"]
                 """,
                 fn ->
                   put_view(%Conn{}, html: "bad")
                 end

    assert_raise ArgumentError,
                 """
                 expected formats to be a keyword list following this spec:

                     [{format(), view()}]

                 Got:

                     :bad
                 """,
                 fn ->
                   put_view(%Conn{}, :bad)
                 end

    assert_raise Plug.Conn.AlreadySentError,
                 """
                 the response was already sent.

                     Status code: 200
                     Request path: /
                     Method: GET
                     View formats: [html: DemoHTML]
                 """,
                 fn ->
                   put_view(sent_conn(), html: DemoHTML)
                 end
  end

  test "put_new_view/2" do
    conn = conn(:get, "/")

    conn = put_new_view(conn, html: DemoHTML, print: false)
    assert view_module(conn, :html) == DemoHTML
    assert view_module(conn, :print) == false

    conn = put_new_view(conn, html: false, print: DemoPrint)
    assert view_module(conn, :html) == DemoHTML
    assert view_module(conn, :print) == false

    assert_raise ArgumentError,
                 """
                 expected formats to be a keyword list following this spec:

                     [{format(), view()}]

                 Got:

                     [html: "bad"]
                 """,
                 fn ->
                   put_new_view(%Conn{}, html: "bad")
                 end

    assert_raise ArgumentError,
                 """
                 expected formats to be a keyword list following this spec:

                     [{format(), view()}]

                 Got:

                     :bad
                 """,
                 fn ->
                   put_new_view(%Conn{}, :bad)
                 end

    assert_raise Plug.Conn.AlreadySentError,
                 """
                 the response was already sent.

                     Status code: 200
                     Request path: /
                     Method: GET
                     View formats: [html: DemoHTML]
                 """,
                 fn ->
                   put_new_view(sent_conn(), html: DemoHTML)
                 end
  end

  describe "view_module/_ and view_module!/_" do
    @error_msg_no_format "no format was given, and no format was inferred from the connection"
    @error_msg_no_view ~r|no view was found for the format: |

    test "without setting view" do
      conn = conn(:get, "/")

      assert view_module(conn) == false
      assert view_module(conn, nil) == false
      assert_raise(RuntimeError, @error_msg_no_format, fn -> view_module!(conn) end)
      assert_raise(RuntimeError, @error_msg_no_format, fn -> view_module!(conn, nil) end)

      assert view_module(conn, :html) == false
      assert view_module(conn, "html") == false
      assert_raise(RuntimeError, @error_msg_no_view, fn -> view_module!(conn, :html) end)
      assert_raise(RuntimeError, @error_msg_no_view, fn -> view_module!(conn, "html") end)

      assert view_module(conn, :print) == false
      assert view_module(conn, "print") == false
      assert_raise(RuntimeError, @error_msg_no_view, fn -> view_module!(conn, :print) end)
      assert_raise(RuntimeError, @error_msg_no_view, fn -> view_module!(conn, "print") end)

      conn = conn(:get, "/") |> put_format(:html)

      assert view_module(conn) == false
      assert view_module(conn, nil) == false
      assert_raise(RuntimeError, @error_msg_no_view, fn -> view_module!(conn) end)
      assert_raise(RuntimeError, @error_msg_no_view, fn -> view_module!(conn, nil) end)

      assert view_module(conn, :html) == false
      assert view_module(conn, "html") == false
      assert_raise(RuntimeError, @error_msg_no_view, fn -> view_module!(conn, :html) end)
      assert_raise(RuntimeError, @error_msg_no_view, fn -> view_module!(conn, "html") end)

      assert view_module(conn, :print) == false
      assert view_module(conn, "print") == false
      assert_raise(RuntimeError, @error_msg_no_view, fn -> view_module!(conn, :print) end)
      assert_raise(RuntimeError, @error_msg_no_view, fn -> view_module!(conn, "print") end)
    end

    test "with setting view" do
      conn = conn(:get, "/") |> put_view(html: DemoHTML, print: DemoPrint)

      assert view_module(conn) == false
      assert view_module(conn, nil) == false
      assert_raise(RuntimeError, @error_msg_no_format, fn -> view_module!(conn) end)
      assert_raise(RuntimeError, @error_msg_no_format, fn -> view_module!(conn, nil) end)

      assert view_module(conn, :html) == DemoHTML
      assert view_module(conn, "html") == DemoHTML
      assert view_module!(conn, :html) == DemoHTML
      assert view_module!(conn, "html") == DemoHTML

      assert view_module(conn, :print) == DemoPrint
      assert view_module(conn, "print") == DemoPrint
      assert view_module!(conn, :print) == DemoPrint
      assert view_module!(conn, "print") == DemoPrint

      conn =
        conn(:get, "/")
        |> put_view(html: DemoHTML, print: DemoPrint)
        |> put_format(:html)

      assert view_module(conn) == DemoHTML
      assert view_module(conn, nil) == DemoHTML
      assert view_module!(conn) == DemoHTML
      assert view_module!(conn, nil) == DemoHTML

      assert view_module(conn, :html) == DemoHTML
      assert view_module(conn, "html") == DemoHTML
      assert view_module!(conn, :html) == DemoHTML
      assert view_module!(conn, "html") == DemoHTML

      assert view_module(conn, :print) == DemoPrint
      assert view_module(conn, "print") == DemoPrint
      assert view_module!(conn, :print) == DemoPrint
      assert view_module!(conn, "print") == DemoPrint
    end
  end

  test "view_template/1 and view_template!/1" do
    conn = %Conn{}
    assert view_template(conn) == nil
    assert_raise RuntimeError, "no template was rendered", fn -> view_template!(conn) end

    conn = put_private(%Conn{}, :combo_template, "hello.html")
    assert view_template(conn) == "hello.html"
    assert view_template!(conn) == "hello.html"
  end

  ## Responses - by sending responses directly

  describe "text/2" do
    test "sends the content as text" do
      conn = text(conn(:get, "/"), "foobar")
      assert conn.resp_body == "foobar"
      assert get_resp_content_type(conn) == "text/plain"
      refute conn.halted

      conn = text(conn(:get, "/"), :foobar)
      assert conn.resp_body == "foobar"
      assert get_resp_content_type(conn) == "text/plain"
      refute conn.halted
    end

    test "allows status injection on connection" do
      conn = conn(:get, "/") |> put_status(400)
      conn = text(conn, :foobar)
      assert conn.resp_body == "foobar"
      assert conn.status == 400
    end
  end

  describe "html/2" do
    test "sends the content as html" do
      conn = html(conn(:get, "/"), "foobar")
      assert conn.resp_body == "foobar"
      assert get_resp_content_type(conn) == "text/html"
      refute conn.halted
    end

    test "allows status injection on connection" do
      conn = conn(:get, "/") |> put_status(400)
      conn = html(conn, "foobar")
      assert conn.resp_body == "foobar"
      assert conn.status == 400
    end
  end

  describe "redirect/2" do
    test "with :to" do
      conn = redirect(conn(:get, "/"), to: "/foobar")
      assert conn.resp_body =~ "/foobar"
      assert get_resp_content_type(conn) == "text/html"
      assert get_resp_header(conn, "location") == ["/foobar"]
      refute conn.halted

      conn = redirect(conn(:get, "/"), to: "/<foobar>")
      assert conn.resp_body =~ "/&lt;foobar&gt;"

      assert_raise ArgumentError, ~r/the :to option in redirect expects a path/, fn ->
        redirect(conn(:get, "/"), to: "http://example.com")
      end

      assert_raise ArgumentError, ~r/the :to option in redirect expects a path/, fn ->
        redirect(conn(:get, "/"), to: "//example.com")
      end

      assert_raise ArgumentError, ~r/unsafe/, fn ->
        redirect(conn(:get, "/"), to: "/\\example.com")
      end

      assert_raise ArgumentError, ~r/expects a path/, fn ->
        redirect(conn(:get, "/"), to: "//\\example.com")
      end

      assert_raise ArgumentError, ~r/unsafe/, fn ->
        redirect(conn(:get, "/"), to: "/%09/example.com")
      end

      assert_raise ArgumentError, ~r/unsafe/, fn ->
        redirect(conn(:get, "/"), to: "/\t/example.com")
      end
    end

    test "with :external" do
      conn = redirect(conn(:get, "/"), external: "http://example.com")
      assert conn.resp_body =~ "http://example.com"
      assert get_resp_header(conn, "location") == ["http://example.com"]
      refute conn.halted
    end

    test "with put_status/2 uses previously set status or defaults to 302" do
      conn = conn(:get, "/") |> redirect(to: "/")
      assert conn.status == 302
      conn = conn(:get, "/") |> put_status(301) |> redirect(to: "/")
      assert conn.status == 301
    end
  end

  describe "send_download/3" do
    @hello_txt Path.expand("../fixtures/hello.txt", __DIR__)

    test "sends file for download" do
      conn = send_download(conn(:get, "/"), {:file, @hello_txt})
      assert conn.status == 200

      assert get_resp_header(conn, "content-disposition") ==
               ["attachment; filename=\"hello.txt\""]

      assert get_resp_header(conn, "content-type") ==
               ["text/plain"]

      assert conn.resp_body ==
               "world"
    end

    test "sends file for download with custom :filename" do
      conn = send_download(conn(:get, "/"), {:file, @hello_txt}, filename: "hello world.json")
      assert conn.status == 200

      assert get_resp_header(conn, "content-disposition") ==
               [
                 "attachment; filename=\"hello%20world.json\"; filename*=utf-8''hello%20world.json"
               ]

      assert get_resp_header(conn, "content-type") ==
               ["application/json"]

      assert conn.resp_body ==
               "world"
    end

    test "sends file for download for filename with unreserved characters" do
      conn = send_download(conn(:get, "/"), {:file, @hello_txt}, filename: "hello, world.json")
      assert conn.status == 200

      assert get_resp_header(conn, "content-disposition") ==
               [
                 "attachment; filename=\"hello%2C%20world.json\"; filename*=utf-8''hello%2C%20world.json"
               ]

      assert get_resp_header(conn, "content-type") ==
               ["application/json"]

      assert conn.resp_body ==
               "world"
    end

    test "sends file supports UTF-8" do
      conn = send_download(conn(:get, "/"), {:file, @hello_txt}, filename: "测 试.txt")
      assert conn.status == 200

      assert get_resp_header(conn, "content-disposition") ==
               [
                 "attachment; filename=\"%E6%B5%8B%20%E8%AF%95.txt\"; filename*=utf-8''%E6%B5%8B%20%E8%AF%95.txt"
               ]

      assert get_resp_header(conn, "content-type") ==
               ["text/plain"]

      assert conn.resp_body ==
               "world"
    end

    test "sends file for download with custom :filename and :encode false" do
      conn =
        send_download(conn(:get, "/"), {:file, @hello_txt},
          filename: "dev's hello world.json",
          encode: false
        )

      assert conn.status == 200

      assert get_resp_header(conn, "content-disposition") ==
               ["attachment; filename=\"dev's hello world.json\""]

      assert get_resp_header(conn, "content-type") ==
               ["application/json"]

      assert conn.resp_body ==
               "world"
    end

    test "sends file for download with custom :content_type and :charset" do
      conn =
        send_download(conn(:get, "/"), {:file, @hello_txt},
          content_type: "application/json",
          charset: "utf8"
        )

      assert conn.status == 200

      assert get_resp_header(conn, "content-disposition") ==
               ["attachment; filename=\"hello.txt\""]

      assert get_resp_header(conn, "content-type") ==
               ["application/json; charset=utf8"]

      assert conn.resp_body ==
               "world"
    end

    test "sends file for download with custom :disposition" do
      conn = send_download(conn(:get, "/"), {:file, @hello_txt}, disposition: :inline)
      assert conn.status == 200

      assert get_resp_header(conn, "content-disposition") ==
               ["inline; filename=\"hello.txt\""]

      assert conn.resp_body ==
               "world"
    end

    test "sends file for download with custom :offset" do
      conn = send_download(conn(:get, "/"), {:file, @hello_txt}, offset: 2)
      assert conn.status == 200

      assert conn.resp_body ==
               "rld"
    end

    test "sends file for download with custom :length" do
      conn = send_download(conn(:get, "/"), {:file, @hello_txt}, length: 2)
      assert conn.status == 200

      assert conn.resp_body ==
               "wo"
    end

    test "sends binary for download with :filename" do
      conn = send_download(conn(:get, "/"), {:binary, "world"}, filename: "hello.json")
      assert conn.status == 200

      assert get_resp_header(conn, "content-disposition") ==
               ["attachment; filename=\"hello.json\""]

      assert get_resp_header(conn, "content-type") ==
               ["application/json"]

      assert conn.resp_body ==
               "world"
    end

    test "sends binary as download with custom :content_type and :charset" do
      conn =
        send_download(conn(:get, "/"), {:binary, "world"},
          filename: "hello.txt",
          content_type: "application/json",
          charset: "utf8"
        )

      assert conn.status == 200

      assert get_resp_header(conn, "content-disposition") ==
               ["attachment; filename=\"hello.txt\""]

      assert get_resp_header(conn, "content-type") ==
               ["application/json; charset=utf8"]

      assert conn.resp_body ==
               "world"
    end

    test "sends binary for download with custom :disposition" do
      conn =
        send_download(conn(:get, "/"), {:binary, "world"},
          filename: "hello.txt",
          disposition: :inline
        )

      assert conn.status == 200

      assert get_resp_header(conn, "content-disposition") ==
               ["inline; filename=\"hello.txt\""]

      assert conn.resp_body ==
               "world"
    end

    test "raises ArgumentError for :disposition other than :attachment or :inline" do
      assert_raise(
        ArgumentError,
        ~r"expected :disposition to be :attachment or :inline, got: :foo",
        fn ->
          send_download(conn(:get, "/"), {:file, @hello_txt}, disposition: :foo)
        end
      )

      assert_raise(
        ArgumentError,
        ~r"expected :disposition to be :attachment or :inline, got: :foo",
        fn ->
          send_download(conn(:get, "/"), {:binary, "world"},
            filename: "hello.txt",
            disposition: :foo
          )
        end
      )
    end
  end

  describe "json/2" do
    test "encodes content to json" do
      conn = json(conn(:get, "/"), %{foo: :bar})
      assert conn.resp_body == "{\"foo\":\"bar\"}"
      assert get_resp_content_type(conn) == "application/json"
      refute conn.halted
    end

    test "allows status injection on connection" do
      conn = conn(:get, "/") |> put_status(400)
      conn = json(conn, %{foo: :bar})
      assert conn.resp_body == "{\"foo\":\"bar\"}"
      assert conn.status == 400
    end

    test "allows content-type injection on connection" do
      conn = conn(:get, "/") |> put_resp_content_type("application/vnd.api+json")
      conn = json(conn, %{foo: :bar})
      assert conn.resp_body == "{\"foo\":\"bar\"}"

      assert Conn.get_resp_header(conn, "content-type") ==
               ["application/vnd.api+json; charset=utf-8"]
    end
  end

  ## Responses - by rendering templates

  test "status_message_from_template/1" do
    assert status_message_from_template("404.html") == "Not Found"
    assert status_message_from_template("whatever.html") == "Internal Server Error"
  end

  ## Flash

  describe "flash" do
    alias Combo.Flash

    @session Plug.Session.init(
               store: :cookie,
               key: "_app",
               encryption_salt: "yadayada",
               signing_salt: "yadayada"
             )

    defp with_session(conn) do
      conn
      |> Map.put(:secret_key_base, String.duplicate("abcdefgh", 8))
      |> Plug.Session.call(@session)
      |> Plug.Conn.fetch_session()
    end

    test "does not fetch flash twice" do
      expected_flash = %{"foo" => "bar"}

      conn =
        conn(:get, "/")
        |> with_session()
        |> put_session("combo_flash", expected_flash)
        |> fetch_flash()
        |> put_session("combo_flash", %{"foo" => "baz"})
        |> fetch_flash()

      assert conn.assigns.flash == expected_flash
      assert conn.assigns.flash == expected_flash
    end

    test "flash is persisted when status is a redirect" do
      for status <- 300..308 do
        conn =
          conn(:get, "/")
          |> with_session
          |> fetch_flash()
          |> put_flash(:notice, "elixir")
          |> send_resp(status, "ok")

        assert Flash.get(conn.assigns.flash, :notice) == "elixir"
        assert get_resp_header(conn, "set-cookie") != []
        conn = conn(:get, "/") |> recycle_cookies(conn) |> with_session |> fetch_flash()
        assert Flash.get(conn.assigns.flash, :notice) == "elixir"
      end
    end

    test "flash is not persisted when status is not redirect" do
      for status <- [299, 309, 200, 404] do
        conn =
          conn(:get, "/")
          |> with_session
          |> fetch_flash()
          |> put_flash(:notice, "elixir")
          |> send_resp(status, "ok")

        assert Flash.get(conn.assigns.flash, :notice) == "elixir"
        assert get_resp_header(conn, "set-cookie") != []
        conn = conn(:get, "/") |> recycle_cookies(conn) |> with_session |> fetch_flash()
        assert Flash.get(conn.assigns.flash, :notice) == nil
      end
    end

    test "flash does not write to session when it is empty and no session exists" do
      conn =
        conn(:get, "/")
        |> with_session()
        |> fetch_flash()
        |> clear_flash()
        |> send_resp(302, "ok")

      assert get_resp_header(conn, "set-cookie") == []
    end

    test "flash writes to session when it is empty and a previous session exists" do
      persisted_flash_conn =
        conn(:get, "/")
        |> with_session()
        |> fetch_flash()
        |> put_flash(:info, "existing")
        |> send_resp(302, "ok")

      conn =
        conn(:get, "/")
        |> Plug.Test.recycle_cookies(persisted_flash_conn)
        |> with_session()
        |> fetch_flash()
        |> clear_flash()
        |> send_resp(200, "ok")

      assert ["_app=" <> _] = get_resp_header(conn, "set-cookie")
    end

    test "flash assigns contains the map of messages" do
      conn = conn(:get, "/") |> with_session |> fetch_flash([]) |> put_flash(:notice, "hi")
      assert conn.assigns.flash == %{"notice" => "hi"}
    end

    test "Flash.get/2 returns the message by key" do
      conn = conn(:get, "/") |> with_session |> fetch_flash([]) |> put_flash(:notice, "hi")
      assert Flash.get(conn.assigns.flash, :notice) == "hi"
      assert Flash.get(conn.assigns.flash, "notice") == "hi"
    end

    test "Flash.get/2 returns nil for missing key" do
      conn = conn(:get, "/") |> with_session |> fetch_flash([])
      assert Flash.get(conn.assigns.flash, :notice) == nil
      assert Flash.get(conn.assigns.flash, "notice") == nil
    end

    test "put_flash/3 raises ArgumentError when flash not previously fetched" do
      assert_raise ArgumentError, fn ->
        conn(:get, "/") |> with_session |> put_flash(:error, "boom!")
      end
    end

    test "Flash.get/2 with a map directly" do
      assert Flash.get(%{}, :info) == nil
      assert Flash.get(%{"info" => "hi"}, :info) == "hi"
      assert Flash.get(%{"info" => "hi", "error" => "ohno"}, :error) == "ohno"
    end

    test "Flash.get/2 with bad flash data" do
      assert_raise ArgumentError,
                   ~r/expected a map of flash data, but got a %Plug.Conn{}/,
                   fn ->
                     Flash.get(%Plug.Conn{}, :info)
                   end
    end

    test "put_flash/3 adds the key/message pair to the flash and updates assigns" do
      conn =
        conn(:get, "/")
        |> with_session
        |> fetch_flash([])

      assert conn.assigns.flash == %{}

      conn =
        conn
        |> put_flash(:error, "oh noes!")
        |> put_flash(:notice, "false alarm!")

      assert conn.assigns.flash == %{"error" => "oh noes!", "notice" => "false alarm!"}
      assert Flash.get(conn.assigns.flash, :error) == "oh noes!"
      assert Flash.get(conn.assigns.flash, "error") == "oh noes!"
      assert Flash.get(conn.assigns.flash, :notice) == "false alarm!"
      assert Flash.get(conn.assigns.flash, "notice") == "false alarm!"
    end

    test "clear_flash/1 clears the flash messages" do
      conn =
        conn(:get, "/")
        |> with_session
        |> fetch_flash([])
        |> put_flash(:error, "oh noes!")
        |> put_flash(:notice, "false alarm!")

      refute conn.assigns.flash == %{}
      conn = clear_flash(conn)
      assert conn.assigns.flash == %{}
    end

    test "merge_flash/2 adds kv-pairs to the flash" do
      conn =
        conn(:get, "/")
        |> with_session
        |> fetch_flash([])
        |> merge_flash(error: "oh noes!", notice: "false alarm!")

      assert Flash.get(conn.assigns.flash, :error) == "oh noes!"
      assert Flash.get(conn.assigns.flash, "error") == "oh noes!"
      assert Flash.get(conn.assigns.flash, :notice) == "false alarm!"
      assert Flash.get(conn.assigns.flash, "notice") == "false alarm!"
    end

    test "fetch_flash/2 raises ArgumentError when session not previously fetched" do
      assert_raise ArgumentError, fn ->
        conn(:get, "/") |> fetch_flash([])
      end
    end
  end

  ## Security

  test "protect_from_forgery/2 sets token" do
    conn(:get, "/")
    |> init_test_session(%{})
    |> protect_from_forgery([])

    assert is_binary(get_csrf_token())
    assert is_binary(delete_csrf_token())
  end

  describe "put_secure_browser_headers/2" do
    test "sets headers" do
      conn =
        conn(:get, "/")
        |> put_secure_browser_headers()

      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
      assert get_resp_header(conn, "x-permitted-cross-domain-policies") == ["none"]

      assert get_resp_header(conn, "content-security-policy") ==
               ["base-uri 'self'; frame-ancestors 'self';"]
    end

    test "only if not set headers" do
      custom_headers = %{"content-security-policy" => "custom", "foo" => "bar"}

      conn =
        conn(:get, "/")
        |> merge_resp_headers(custom_headers)
        |> put_secure_browser_headers()

      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
      assert get_resp_header(conn, "x-permitted-cross-domain-policies") == ["none"]
      assert get_resp_header(conn, "content-security-policy") == ["custom"]
      assert get_resp_header(conn, "foo") == ["bar"]
    end

    test "can be overridden" do
      custom_headers = %{"content-security-policy" => "custom", "foo" => "bar"}

      conn =
        conn(:get, "/")
        |> put_secure_browser_headers(custom_headers)

      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
      assert get_resp_header(conn, "x-permitted-cross-domain-policies") == ["none"]
      assert get_resp_header(conn, "content-security-policy") == ["custom"]
      assert get_resp_header(conn, "foo") == ["bar"]
    end
  end

  ## JSONP

  describe "jsonp/2" do
    test "with allow_jsonp/2 returns json when no callback param is present" do
      conn =
        conn(:get, "/")
        |> fetch_query_params()
        |> allow_jsonp()
        |> json(%{foo: "bar"})

      assert conn.resp_body == "{\"foo\":\"bar\"}"
      assert get_resp_content_type(conn) == "application/json"
      refute conn.halted
    end

    test "with allow_jsonp/2 returns json when callback name is left empty" do
      conn =
        conn(:get, "/?callback=")
        |> fetch_query_params()
        |> allow_jsonp()
        |> json(%{foo: "bar"})

      assert conn.resp_body == "{\"foo\":\"bar\"}"
      assert get_resp_content_type(conn) == "application/json"
      refute conn.halted
    end

    test "with allow_jsonp/2 returns javascript when callback param is present" do
      conn =
        conn(:get, "/?callback=cb")
        |> fetch_query_params
        |> allow_jsonp
        |> json(%{foo: "bar"})

      assert conn.resp_body == "/**/ typeof cb === 'function' && cb({\"foo\":\"bar\"});"
      assert get_resp_content_type(conn) == "application/javascript"
      refute conn.halted
    end

    test "with allow_jsonp/2 allows to override the callback param" do
      conn =
        conn(:get, "/?cb=cb")
        |> fetch_query_params
        |> allow_jsonp(callback: "cb")
        |> json(%{foo: "bar"})

      assert conn.resp_body == "/**/ typeof cb === 'function' && cb({\"foo\":\"bar\"});"
      assert get_resp_content_type(conn) == "application/javascript"
      refute conn.halted
    end

    test "with allow_jsonp/2 raises ArgumentError when callback contains invalid characters" do
      conn = conn(:get, "/?cb=_c*b!()[0]") |> fetch_query_params()

      assert_raise ArgumentError, "the JSONP callback name contains invalid characters", fn ->
        allow_jsonp(conn, callback: "cb")
      end
    end

    test "with allow_jsonp/2 escapes invalid javascript characters" do
      conn =
        conn(:get, "/?cb=cb")
        |> fetch_query_params
        |> allow_jsonp(callback: "cb")
        |> json(%{foo: <<0x2028::utf8, 0x2029::utf8>>})

      assert conn.resp_body ==
               "/**/ typeof cb === 'function' && cb({\"foo\":\"\\u2028\\u2029\"});"

      assert get_resp_content_type(conn) == "application/javascript"
      refute conn.halted
    end
  end

  ## URL generation

  describe "path and url generation" do
    def url(), do: "https://www.example.com"

    defp build_conn_for_path(path) do
      conn(:get, path)
      |> fetch_query_params()
      |> put_private(:combo_endpoint, __MODULE__)
      |> put_private(:combo_router, __MODULE__)
    end

    test "current_path/1 uses the conn's query params" do
      conn = build_conn_for_path("/")
      assert current_path(conn) == "/"

      conn = build_conn_for_path("/foo?one=1&two=2")
      assert current_path(conn) == "/foo?one=1&two=2"

      conn = build_conn_for_path("/foo//bar/")
      assert current_path(conn) == "/foo/bar"
    end

    test "current_path/2 allows custom query params" do
      conn = build_conn_for_path("/")
      assert current_path(conn, %{}) == "/"

      conn = build_conn_for_path("/foo?one=1&two=2")
      assert current_path(conn, %{}) == "/foo"

      conn = build_conn_for_path("/foo?one=1&two=2")
      assert current_path(conn, %{three: 3}) == "/foo?three=3"
    end

    test "current_path/2 allows custom nested query params" do
      conn = build_conn_for_path("/")
      assert current_path(conn, foo: [bar: [:baz], baz: :qux]) == "/?foo[bar][]=baz&foo[baz]=qux"
    end

    test "current_url/1 with root path includes trailing slash" do
      conn = build_conn_for_path("/")
      assert current_url(conn) == "https://www.example.com/"
    end

    test "current_url/1 users conn's endpoint and query params" do
      conn = build_conn_for_path("/?foo=bar")
      assert current_url(conn) == "https://www.example.com/?foo=bar"

      conn = build_conn_for_path("/foo?one=1&two=2")
      assert current_url(conn) == "https://www.example.com/foo?one=1&two=2"
    end

    test "current_url/2 allows custom query params" do
      conn = build_conn_for_path("/")
      assert current_url(conn, %{}) == "https://www.example.com/"

      conn = build_conn_for_path("/foo?one=1&two=2")
      assert current_url(conn, %{}) == "https://www.example.com/foo"

      conn = build_conn_for_path("/foo?one=1&two=2")
      assert current_url(conn, %{three: 3}) == "https://www.example.com/foo?three=3"
    end
  end
end
