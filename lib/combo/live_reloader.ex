defmodule Combo.LiveReloader do
  @moduledoc """
  Live reloader for development.

  ## Usage

  Add the `Combo.LiveReloader` plug within a `live_reloading?` block in your
  endpoint. For example:

      if live_reloading? do
        socket "/combo/live_reload/socket", Combo.LiveReloader.Socket
        plug Combo.LiveReloader
      end

  ## Configuration

  LiveReloader is configured via the `:live_reloader` option of your endpoint
  configuration. And, in general, the configuration is added to
  `config/dev.exs`. For example:

      config :demo, Demo.Web.Endpoint,
        live_reloader: [
          patterns: [
            ~r"lib/demo/web/(?:router|controllers|layouts|components)(?:/.*)?\.(ex|ceex)$",
            ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$"
          ]
        ]

  The following options are supported:

    * `:patterns` - a list of patterns to trigger the live reloading. This
      option is required to enable any live reloading.

    * `:interval` - Default to `100`ms. It's useful when you think the live
      reloading is triggering too fast.

    * `:debounce` - an integer in milliseconds to wait before sending live
      reload events to the browser. Defaults to `0`.

    * `:iframe_attrs` - attrs to be given to the iframe injected by live
      reload. Expects a keyword list of atom keys and string values.

    * `:path` - the path of socket's mount-point.
      Defaults to `/combo/live_reload/socket`.

    * `:target_window` - the window that will be reloaded.
      Valid values are `:top` and `:parent`. Defaults to `:parent`.

    * `:reload_page_on_css_changes` - If true, CSS changes will trigger a full
      page reload like other asset types instead of the default hot reload.
      Useful when class names are determined at runtime, for example when
      working with CSS modules. Defaults to `false`.

  In an umbrella app, if you want to enable live reloading based on code
  changes in sibling applications, set the `:reloadable_apps` option on your
  endpoint to ensure the code will be recompiled, then add the dirs to
  `:live_reloader` to trigger page reloads:

      # in config/dev.exs
      root_path =
        __ENV__.file
        |> Path.dirname()
        |> Path.join("..")
        |> Path.expand()

      config :combo, :live_reloader, dirs: [
        Path.join([root_path, "apps", "app1"]),
        Path.join([root_path, "apps", "app2"]),
      ]

  You'll also want to be sure that the configured `:patterns` will match files
  in the sibling application.

  ## About `:target_window` option

  Change the default target window to `:parent` to not reload the whole page
  if a Combo app is shown inside an iframe. You can get the old behavior back
  by setting the `:target_window` option to `:top`:

      config :phoenix_live_reload, DemoWeb.Endpoint,
        target_window: :top

  ## Backends

  This module uses [`FileSystem`](https://github.com/falood/file_system) to
  watch the filesystem changes. It supports the following backends:

    * `:fs_inotify` - available on Linux and BSD. It requires installing an
      extra package, check out [the wiki of inotify-tools](https://github.com/rvoicilas/inotify-tools/wiki)
      for more details.
    * `:fs_mac` - available on macOS.
    * `:fs_windows` - available on Windows.
    * `:fs_poll` - available on all operating systems.

  In general, you don't need to configure it. But if you want, do it like:

      config :combo, :live_reloader, backend: :fs_poll

  By default the entire application directory is watched by the backend.
  However, with some environments and backends, this may be inefficient,
  resulting in slow response times to file modifications. To account for
  this, it's possible to explicitly declare a list of directories for the
  backend to watch (they must be relative to the project root, otherwise
  they are just ignored), and additional options for the backend:

      config :combo, :live_reloader,
        dirs: [
          "priv/static",
          "priv/gettext",
          "lib/demo/web/live",
          "lib/demo/web/views",
          "lib/demo/web/templates",
          "../another_project/priv/static", # Contents of this directory is not watched
          "/another_project/priv/static",   # Contents of this directory is not watched
        ],
        backend: :fs_poll,
        backend_opts: [
          interval: 500
        ]

  ## Skipping remote CSS reload

  All stylesheets are reloaded without a page refresh anytime a style is
  detected as having changed. In certain cases such as serving stylesheets
  from a remote host, you may wish to prevent unnecessary reload of these
  stylesheets during development. For this, you can include a `data-no-reload`
  attribute on the link tag. For example:

  ```html
  <link rel="stylesheet" href="https://example.com/style.css" data-no-reload>
  ```

  ## Differences between `Combo.CodeReloader`

  `Combo.CodeReloader` recompiles code in the `lib/` directory. It means that
  if you change anything in the `lib/` directory, then the Elixir code will be
  reloaded and used on your next request.

  `Combo.LiveReloader` injects JavaScript code into web page. Then injected
  JavaScript code will create a WebSocket connection to the server. When a
  specified file changed, the server will sent a message to the web page, and
  the web page will be reloaded in response. If the change was to an Elixir
  file then it will be recompiled and served when the page is reloaded. If
  it is JavaScript or CSS, then only assets are reloaded, without triggering
  a full page load.
  """

  ## Setup

  @doc false
  def enabled?(config) do
    match?([_ | _], config[:patterns])
  end

  @doc false
  def child_specs(endpoint) do
    [{Combo.LiveReloader.FileSystemListener, endpoint}]
  end

  ## Plug

  import Combo.SafeHTML, only: [escape_attrs: 1]
  import Combo.Conn, only: [endpoint_module!: 1]
  import Plug.Conn

  @behaviour Plug

  live_reloader_js = Application.app_dir(:combo, "priv/static/live_reloader.js")
  @live_reloader_js File.read!(live_reloader_js)
  @external_resource live_reloader_js

  live_reloader_js_map = Application.app_dir(:combo, "priv/static/live_reloader.js.map")
  @live_reloader_js_map File.read!(live_reloader_js_map)
  @external_resource live_reloader_js_map

  def init(opts) do
    opts
  end

  def call(%Plug.Conn{path_info: ["combo", "live_reload", "live_reloader.js"]} = conn, _) do
    conn
    |> put_resp_content_type("text/javascript")
    |> send_resp(200, @live_reloader_js)
    |> halt()
  end

  def call(%Plug.Conn{path_info: ["combo", "live_reload", "live_reloader.js.map"]} = conn, _) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, @live_reloader_js_map)
    |> halt()
  end

  def call(%Plug.Conn{path_info: ["combo", "live_reload", "iframe"]} = conn, _) do
    endpoint = endpoint_module!(conn)
    config = endpoint.config(:live_reloader)

    path = endpoint.path(config[:path] || "/combo/live_reload/socket")
    interval = config[:interval] || 100
    target_window = get_target_window(config[:target_window] || :parent)
    reload_page_on_css_changes? = config[:reload_page_on_css_changes] || false

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, """
    <!DOCTYPE html>
    <html><body>
    <script src="#{endpoint.path("/combo/live_reload/live_reloader.js")}"></script>
    <script>
      (function() {
        var url = "#{path}";
        var interval = #{interval};
        var targetWindow = "#{target_window}";
        var reloadPageOnCssChanges = #{reload_page_on_css_changes?};
        Combo.LiveReloader.init(url, interval, targetWindow, reloadPageOnCssChanges);
      })();
    </script>
    </body></html>
    """)
    |> halt()
  end

  def call(conn, _) do
    endpoint = endpoint_module!(conn)
    config = endpoint.config(:live_reloader)

    if enabled?(config) do
      before_send_inject_reloader(conn, endpoint, config)
    else
      conn
    end
  end

  defp before_send_inject_reloader(conn, endpoint, config) do
    register_before_send(conn, fn conn ->
      if conn.resp_body != nil and html?(conn) do
        resp_body = IO.iodata_to_binary(conn.resp_body)

        if has_body?(resp_body) and :code.is_loaded(endpoint) do
          {head, [last]} = Enum.split(String.split(resp_body, "</body>"), -1)
          head = Enum.intersperse(head, "</body>")
          body = [head, reload_assets_tag(conn, config), "</body>" | last]
          put_in(conn.resp_body, body)
        else
          conn
        end
      else
        conn
      end
    end)
  end

  defp html?(conn) do
    case get_resp_header(conn, "content-type") do
      [] -> false
      [type | _] -> String.starts_with?(type, "text/html")
    end
  end

  defp has_body?(resp_body), do: String.contains?(resp_body, "<body")

  defp reload_assets_tag(conn, config) do
    endpoint = endpoint_module!(conn)
    path = endpoint.path("/combo/live_reload/iframe")

    attrs =
      Keyword.merge(
        [hidden: true, height: 0, width: 0, src: path],
        Keyword.get(config, :iframe_attrs, [])
      )

    IO.iodata_to_binary(["<iframe", escape_attrs(attrs), "></iframe>"])
  end

  defp get_target_window(:parent), do: "parent"
  defp get_target_window(_), do: "top"
end
