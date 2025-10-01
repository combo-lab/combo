defmodule Combo.LiveReloader do
  @moduledoc """
  Reloads web pages when files change during development.

  ## How does it work?

  `Combo.LiveReloader` injects JavaScript code into web pages.

  The injected JavaScript code will create a WebSocket connection to the server,
  and wait the messages sent from server.

  When a specified file changed, the server will sent a message to the web page
  , and the web page will be full-reloaded or hot-reloaded in response. By
  default:

    * CSS file changes are hot-reloaded.
    * other file changes are full-reloaded.

  ## Usage

  Add the `Combo.LiveReloader` plug within a `live_reloading?` block in your
  endpoint. For example:

      if live_reloading? do
        socket "/combo/live_reloader/socket", Combo.LiveReloader.Socket
        plug Combo.LiveReloader
      end

  ## Configuration

  `Combo.LiveReloader` is configured via the `:live_reloader` option of your
  endpoint configuration. The option accepts three types of values:

    * `true` - enable it with default options.
    * `false` - disable it.
    * a keyword list - enable it with customized options.

  In general, the configuration is added to `config/dev.exs`. For example:

      config :my_app, MyApp.Web.Endpoint,
        live_reloader: [
          patterns: [
            ~r"lib/my_app/web/router\.ex",
            ~r"lib/my_app/web/(controllers|layouts|components)/.*\.(ex|ceex)$",
            ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$"
          ]
        ]

  The following options are supported:

    * `:patterns` - a list of patterns to trigger the reloading.

    * `:path` - the path of socket's mount-point.
      Defaults to `/combo/live_reloader/socket`.

    * `:iframe_attrs` - the attrs to be given to the injected iframe. Expects
      a keyword list of atom keys and string values.

    * `:debounce` - an integer in milliseconds to wait before reloading web
      pages. This prevents rapid successive reloads when multiple files change
      simultaneously. Default to `100`.

    * `:target_window` - the window to be reloaded. Expects `:parent` or `:top`
      . Defaults to `:parent`.

    * `:full_reload_on_css_changes` - whether to trigger full reload on CSS
      changes. If `true`, CSS changes will trigger a full reload like other
      asset types instead of the default hot reload. Defaults to `false`.

  ### The `:target_window` option

    * If `:parent` is set, `window.parent` will be reloaded.
    * If `:top` is set, `window.top` will be reloaded.

  ## Skipping remote CSS reload

  In certain cases such as serving stylesheets from a remote host, you may wish
  to prevent unnecessary reload of these stylesheets during development. For
  this, you can include a `data-no-reload` attribute on the link tag.
  For example:

  ```html
  <link rel="stylesheet" href="https://example.com/style.css" data-no-reload>
  ```

  ## Backends

  This module uses [`FileSystem`](https://github.com/falood/file_system) to
  watch the file system changes. It supports the following backends:

    * `:fs_inotify` - available on Linux and BSD. It requires installing an
      extra package, check out [the wiki of inotify-tools](https://github.com/rvoicilas/inotify-tools/wiki)
      for more details.
    * `:fs_mac` - available on macOS.
    * `:fs_windows` - available on Windows.
    * `:fs_poll` - available on all operating systems.

  In general, the backend is set automatically. But if you want to set it
  manually, do it like:

      config :combo, :live_reloader, backend: :fs_poll

  By default the entire application directory is watched. However, with some
  environments and backends, this may be inefficient, resulting in slow response
  times to file modifications. To account for this, it's possible to explicitly
  declare a list of directories for the backend to watch (they must be relative
  to the project root, otherwise they are just ignored), and additional options
  for the backend:

      config :combo, :live_reloader,
        dirs: [
          "priv/static",
          "priv/gettext",
          "lib/my_app/web/layouts",
          "lib/my_app/web/controllers",
          "../another_project/priv/static", # Contents of this directory is not watched
          "/another_project/priv/static",   # Contents of this directory is not watched
        ],
        backend: :fs_poll,
        backend_opts: [
          interval: 500
        ]

  """

  import Plug.Conn
  import Combo.Conn, only: [endpoint_module!: 1]
  import Combo.SafeHTML, only: [escape_attrs: 1]

  @behaviour Plug

  live_reloader_min_js = Application.app_dir(:combo, "priv/static/live_reloader.min.js")
  @live_reloader_min_js File.read!(live_reloader_min_js)
  @external_resource live_reloader_min_js

  live_reloader_min_js_map = Application.app_dir(:combo, "priv/static/live_reloader.min.js.map")
  @live_reloader_min_js_map File.read!(live_reloader_min_js_map)
  @external_resource live_reloader_min_js_map

  def init(opts) do
    opts
  end

  def call(%Plug.Conn{path_info: ["combo", "live_reloader", "live_reloader.min.js"]} = conn, _) do
    conn
    |> put_resp_content_type("text/javascript")
    |> send_resp(200, @live_reloader_min_js)
    |> halt()
  end

  def call(%Plug.Conn{path_info: ["combo", "live_reloader", "live_reloader.min.js.map"]} = conn, _) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, @live_reloader_min_js_map)
    |> halt()
  end

  def call(%Plug.Conn{path_info: ["combo", "live_reloader", "iframe"]} = conn, _) do
    endpoint = endpoint_module!(conn)
    config = endpoint.config(:live_reloader)

    path = endpoint.path(config[:path] || "/combo/live_reloader/socket")
    debounce = config[:debounce] || 100
    target_window = config[:target_window] || :parent
    full_reload_on_css_changes? = config[:full_reload_on_css_changes] || false

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, """
    <!DOCTYPE html>
    <html><body>
    <script src="#{endpoint.path("/combo/live_reloader/live_reloader.min.js")}"></script>
    <script>
      (function() {
        var LiveReloader = Combo.LiveReloader.default;

        var path = "#{path}";
        var debounceTime = #{debounce};
        var targetWindow = "#{target_window}";
        var fullReloadOnCssChanges = #{full_reload_on_css_changes?};

        window.liveReloader = new LiveReloader(path, debounceTime, targetWindow, fullReloadOnCssChanges);
        window.liveReloader.enable();
      })();
    </script>
    </body></html>
    """)
    |> halt()
  end

  def call(conn, _) do
    endpoint = endpoint_module!(conn)

    config =
      case endpoint.config(:live_reloader) do
        true -> []
        other -> other
      end

    if config do
      conn
      |> put_private(:combo_live_reloader, true)
      |> inject_live_reloader(endpoint, config)
    else
      conn
    end
  end

  defp inject_live_reloader(conn, endpoint, config) do
    register_before_send(conn, fn conn ->
      if inject?(conn) do
        resp_body = IO.iodata_to_binary(conn.resp_body)

        if has_body?(resp_body) and :code.is_loaded(endpoint) do
          {head, [last]} = Enum.split(String.split(resp_body, "</body>"), -1)
          head = Enum.intersperse(head, "</body>")
          body = [head, iframe_tag(conn, config), "</body>" | last]
          put_in(conn.resp_body, body)
        else
          conn
        end
      else
        conn
      end
    end)
  end

  defp inject?(conn) do
    html? =
      case get_resp_header(conn, "content-type") do
        [] -> false
        [type | _] -> String.starts_with?(type, "text/html")
      end

    has_resp_body? = conn.resp_body != nil

    html? and has_resp_body?
  end

  defp has_body?(resp_body), do: String.contains?(resp_body, "<body")

  defp iframe_tag(conn, config) do
    endpoint = endpoint_module!(conn)
    path = endpoint.path("/combo/live_reloader/iframe")

    attrs =
      Keyword.merge(
        [hidden: true, height: 0, width: 0, src: path],
        Keyword.get(config, :iframe_attrs, [])
      )

    IO.iodata_to_binary(["<iframe", escape_attrs(attrs), "></iframe>"])
  end
end
