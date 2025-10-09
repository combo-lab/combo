defmodule Combo.Conn do
  @moduledoc """
  Function plugs and `%Plug.Conn{}` helpers in the scope of Combo.
  """

  require Logger

  import Plug.Conn,
    only: [
      assign: 3,
      put_private: 3,
      get_session: 2,
      put_session: 3,
      get_req_header: 2,
      delete_session: 2,
      get_resp_header: 2,
      put_resp_header: 3,
      merge_resp_headers: 2,
      put_resp_content_type: 3,
      send_resp: 3,
      send_file: 5,
      resp: 3,
      register_before_send: 2
    ]

  alias Plug.Conn

  ## Endpoints

  @doc """
  Gets the endpoint module as an atom, or raises if unavailable.
  """
  @spec endpoint_module!(Conn.t()) :: atom()
  def endpoint_module!(conn), do: conn.private.combo_endpoint

  ## Routers

  @doc """
  Gets the router module as an atom, or raises if unavailable.
  """
  @spec router_module!(Conn.t()) :: atom()
  def router_module!(conn), do: conn.private.combo_router

  ## Controllers

  @doc """
  Gets the controller module as an atom, or raises if unavailable.
  """
  @spec controller_module!(Conn.t()) :: atom()
  def controller_module!(conn), do: conn.private.combo_controller

  @doc """
  Gets the action name as an atom, or raises if unavailable.
  """
  @spec action_name!(Conn.t()) :: atom()
  def action_name!(conn), do: conn.private.combo_action

  ## Formats

  @type format :: atom() | binary()

  defguard is_format(format) when is_atom(format) or is_binary(format)

  @doc """
  Performs content negotiation according to the given formats.

  It receives a connection, a list of formats that the server is capable of
  processing, and then performs content negotiation based on the request
  information:

    1. request parameter `"_format"`. If it is present, it is considered to
       be the format desired by the client.

    2. request header `"accept"`. Fallback to parse this header and find a
       matching format accordingly.

  It is important to notice that browsers have historically sent bad accept
  headers. For this reason, this function will default to "html" format
  whenever:

    * the accepted list of arguments contains the "html" format.

    * the accept header specified more than one media type preceded or
      followed by the wildcard media type `"*/*"`.

  When the server cannot serve a response in any of the formats expected by
  the client, this function raises `Combo.NotAcceptableError`, which is
  rendered with status 406.

  ## Examples

  `accepts/2` can be invoked as a function:

      iex> accepts(conn, ["html", "json"])

  or used as a plug:

      plug :accepts, ["html", "json"]

  ## Use `put_format/2`

  `accepts/2` is useful when you may want to serve different content-types
  (such as HTML and JSON) from the same routes. However, if you always have
  distinct routes, you can simply hardcode the format in your route pipelines:

      plug :put_format, "html"

  ## Custom media types

  It is possible to add custom media types to your application.

  The first step is to configure new media types in your `config/config.exs`:

      config :mime, :types, %{
        "application/vnd.api+json" => ["json-api"]
      }

  The key is the media type, the value is a list of formats the media type can
  be identified with. For example, by using `"json-api"`, you will be able to
  use templates with extension `"index.json-api"` or to force a particular
  format in a given URL by sending `"?_format=json-api"`.

  After this change, you must recompile mime:

      $ mix deps.clean mime --build
      $ mix deps.get

  And now you can use it in accepts too:

      plug :accepts, ["html", "json-api"]

  """
  @spec accepts(Conn.t(), [binary()]) :: Conn.t()
  def accepts(conn, [_ | _] = accepted) do
    case conn.params do
      %{"_format" => format} ->
        handle_params_accept(conn, format, accepted)

      %{} ->
        format = get_req_header(conn, "accept")
        handle_header_accept(conn, format, accepted)
    end
  end

  defp handle_params_accept(conn, format, accepted) do
    if format in accepted do
      put_format(conn, format)
    else
      raise Combo.NotAcceptableError,
        message: "unknown format #{inspect(format)}, expected one of #{inspect(accepted)}",
        accepts: accepted
    end
  end

  # In case there is no accept header or the header is */*, we use the first
  # format specified in the accepts list.
  defp handle_header_accept(conn, header, [first | _]) when header == [] or header == ["*/*"] do
    put_format(conn, first)
  end

  # In case there is a header, we need to parse it. But, before we check for
  # */*, because if one exists and we serve html, we unfortunately need to
  # assume it is a browser sending us a request.
  defp handle_header_accept(conn, [header | _], accepted) do
    if header =~ "*/*" and "html" in accepted do
      put_format(conn, "html")
    else
      parse_header_accept(conn, String.split(header, ","), [], accepted)
    end
  end

  defp parse_header_accept(conn, [h | t], acc, accepted) do
    case Plug.Conn.Utils.media_type(h) do
      {:ok, type, subtype, args} ->
        exts = parse_exts(type, subtype)
        q = parse_q(args)

        if format = q === 1.0 && find_format(exts, accepted) do
          put_format(conn, format)
        else
          parse_header_accept(conn, t, [{-q, h, exts} | acc], accepted)
        end

      :error ->
        parse_header_accept(conn, t, acc, accepted)
    end
  end

  defp parse_header_accept(conn, [], acc, accepted) do
    acc
    |> Enum.sort()
    |> Enum.find_value(&parse_header_accept(conn, &1, accepted))
    |> Kernel.||(refuse(conn, acc, accepted))
  end

  defp parse_header_accept(conn, {_, _, exts}, accepted) do
    if format = find_format(exts, accepted) do
      put_format(conn, format)
    end
  end

  defp parse_q(args) do
    case Map.fetch(args, "q") do
      {:ok, float} ->
        case Float.parse(float) do
          {float, _} -> float
          :error -> 1.0
        end

      :error ->
        1.0
    end
  end

  defp parse_exts("*", "*"), do: "*/*"
  defp parse_exts(type, "*"), do: type
  defp parse_exts(type, subtype), do: MIME.extensions(type <> "/" <> subtype)

  defp find_format("*/*", accepted), do: Enum.fetch!(accepted, 0)
  defp find_format(exts, accepted) when is_list(exts), do: Enum.find(exts, &(&1 in accepted))
  defp find_format(_type_range, []), do: nil

  defp find_format(type_range, [h | t]) do
    mime_type = MIME.type(h)

    case Plug.Conn.Utils.media_type(mime_type) do
      {:ok, accepted_type, _subtype, _args} when type_range === accepted_type -> h
      _ -> find_format(type_range, t)
    end
  end

  @spec refuse(term(), [tuple()], [binary()]) :: no_return()
  defp refuse(_conn, given, accepted) do
    raise Combo.NotAcceptableError,
      accepts: accepted,
      message: """
      no supported media type in accept header.

      Expected one of #{inspect(accepted)} but got the following formats:

        * #{Enum.map_join(given, "\n  ", fn {_, header, exts} -> inspect(header) <> " with extensions: " <> inspect(exts) end)}

      To accept custom formats, register them under the :mime library
      in your config/config.exs file:

          config :mime, :types, %{
            "application/xml" => ["xml"]
          }

      And then run `mix deps.clean --build mime` to force it to be recompiled.
      """
  end

  @doc """
  Sets the given format into the connection.

  This format is used when rendering a template which is specifed by an atom.
  For example, `render(conn, :show)` will render `"show.<format>"` where the
  `"<format>"` is the one set here.

  The default format is typically set from the negotiation done in `accepts/2`.
  """
  @spec put_format(Conn.t(), format()) :: Conn.t()
  def put_format(conn, format) when is_format(format) do
    put_private(conn, :combo_format, to_string(format))
  end

  @doc """
  Gets the request format, such as "json", "html".
  """
  @spec get_format(Conn.t()) :: String.t() | nil
  def get_format(conn) do
    conn.private[:combo_format]
  end

  defp put_private_formats(conn, priv_key, kind, formats) when kind in [:new, :replace] do
    update_in(conn.private, fn private ->
      existing = Map.get(private, priv_key, %{})

      new_formats =
        case kind do
          :new -> Map.merge(formats, existing)
          :replace -> Map.merge(existing, formats)
        end

      Map.put(private, priv_key, new_formats)
    end)
  end

  defp get_private_formats(conn, priv_key) do
    Map.get(conn.private, priv_key, %{})
  end

  defp get_private_format_value(_conn, _priv_key, format) when is_nil(format) do
    false
  end

  defp get_private_format_value(conn, priv_key, format) when is_atom(format) do
    get_private_format_value(conn, priv_key, to_string(format))
  end

  defp get_private_format_value(conn, priv_key, format) when is_binary(format) do
    case conn.private[priv_key] do
      %{^format => value} -> value
      _ -> false
    end
  end

  ## Layouts

  @unsent [:unset, :set, :set_chunked, :set_file]

  @typedoc """
  Layout can be:

    * `{module, layout}`, where the `module` is the layout module, and the
      `layout` is the function name as an atom in the layout module. For
      example: `{DemoLayout, :app}`.

    * `false`, which means disabling the layout.

  """
  @type layout :: {module :: module(), name :: atom() | String.t()} | false
  @type layout_formats :: [{format(), layout()}]

  @type view :: module() | false
  @type view_formats :: [{format(), view()}]

  defguard is_layout_formats(formats) when is_list(formats)
  defguard is_view_formats(formats) when is_list(formats)

  @doc """
  Sets the layout for rendering.

  Raises `Plug.Conn.AlreadySentError` if `conn` is already sent.

  ## Examples

      iex> layout(conn)
      false

      iex> conn = put_layout(conn, html: {Demo.Web.Layouts, :app})
      iex> layout(conn)
      {Demo.Web.Layouts, :app}

      iex> conn = put_layout(conn, html: {Demo.Web.Layouts, :print})
      iex> layout(conn)
      {Demo.Web.Layouts, :print}

  """
  @spec put_layout(Conn.t(), layout_formats()) :: Conn.t()
  def put_layout(%Plug.Conn{state: state} = conn, formats)
      when state in @unsent and is_layout_formats(formats) do
    put_private_layout(conn, :combo_layout, :replace, formats)
  end

  def put_layout(%Plug.Conn{state: state}, formats)
      when state in @unsent do
    raise_layout_bad_formats(formats)
  end

  def put_layout(%Plug.Conn{} = conn, formats) do
    raise Conn.AlreadySentError, """
    the response was already sent.

        Status code: #{conn.status}
        Request path: #{conn.request_path}
        Method: #{conn.method}
        Layout formats: #{inspect(formats)}
    """
  end

  @doc """
  Sets the layout for rendering if one was not set yet.

  Raises `Plug.Conn.AlreadySentError` if `conn` is already sent.

  See `put_layout/2` for more information.
  """
  @spec put_new_layout(Conn.t(), layout_formats()) :: Conn.t()
  def put_new_layout(%Plug.Conn{state: state} = conn, formats)
      when state in @unsent and is_layout_formats(formats) do
    put_private_layout(conn, :combo_layout, :new, formats)
  end

  def put_new_layout(%Plug.Conn{state: state}, formats)
      when state in @unsent do
    raise_layout_bad_formats(formats)
  end

  def put_new_layout(%Plug.Conn{} = conn, formats) do
    raise Conn.AlreadySentError, """
    the response was already sent.

        Status code: #{conn.status}
        Request path: #{conn.request_path}
        Method: #{conn.method}
        Layout formats: #{inspect(formats)}
    """
  end

  @doc """
  Gets the current layout for the given format.

  If no format is given, takes the current one from the connection.
  """
  @spec layout(Conn.t(), format() | nil) :: layout() | nil
  def layout(conn, format \\ nil) do
    format = format || get_format(conn)
    get_private_format_value(conn, :combo_layout, format)
  end

  defp put_private_layout(conn, priv_key, kind, formats) when is_list(formats) do
    formats =
      Map.new(formats, fn
        {format, false} ->
          {to_string(format), false}

        {format, {mod, layout}} when is_atom(mod) and is_atom(layout) ->
          {to_string(format), {mod, layout}}

        _ ->
          raise_layout_bad_formats(formats)
      end)

    put_private_formats(conn, priv_key, kind, formats)
  end

  @compile {:inline, raise_layout_bad_formats: 1}
  defp raise_layout_bad_formats(formats) do
    raise ArgumentError, """
    expected formats to be a keyword list following this spec:

        [{format(), layout()}]

    Got:

        #{inspect(formats)}
    """
  end

  ## Views

  @doc """
  Sets the view for rendering.

  Raises `Plug.Conn.AlreadySentError` if `conn` is already sent.

  ## Examples

      iex> put_view(conn, html: PageHTML, json: PageJSON)

  """
  @spec put_view(Conn.t(), view_formats()) :: Conn.t()
  def put_view(%Plug.Conn{state: state} = conn, formats)
      when state in @unsent and is_view_formats(formats) do
    put_private_view(conn, :combo_view, :replace, formats)
  end

  def put_view(%Plug.Conn{state: state}, formats)
      when state in @unsent do
    raise_view_bad_formats(formats)
  end

  def put_view(%Plug.Conn{} = conn, formats) do
    raise Conn.AlreadySentError, """
    the response was already sent.

        Status code: #{conn.status}
        Request path: #{conn.request_path}
        Method: #{conn.method}
        View formats: #{inspect(formats)}
    """
  end

  @doc """
  Sets the view for rendering if one was not set yet.

  Raises `Plug.Conn.AlreadySentError` if `conn` is already sent.
  """
  @spec put_new_view(Conn.t(), view_formats()) :: Conn.t()
  def put_new_view(%Plug.Conn{state: state} = conn, formats)
      when state in @unsent and is_view_formats(formats) do
    put_private_view(conn, :combo_view, :new, formats)
  end

  def put_new_view(%Plug.Conn{state: state}, formats)
      when state in @unsent do
    raise_view_bad_formats(formats)
  end

  def put_new_view(%Plug.Conn{} = conn, formats) do
    raise Conn.AlreadySentError, """
    the response was already sent.

        Status code: #{conn.status}
        Request path: #{conn.request_path}
        Method: #{conn.method}
        View formats: #{inspect(formats)}
    """
  end

  @doc """
  Gets the current view for the given format.

  If no format is given, takes the current one from the connection.
  """
  @spec view_module(Conn.t(), format() | nil) :: view()
  def view_module(conn, format \\ nil) do
    format = format || get_format(conn)
    get_private_format_value(conn, :combo_view, format)
  end

  @doc """
  Gets the current view for the given format, or raises if no view was found.

  If no format is given, takes the current one from the connection.
  """
  @spec view_module!(Conn.t(), format() | nil) :: view()
  def view_module!(conn, format \\ nil) do
    format = format || get_format(conn)

    if format do
      if view_module = get_private_format_value(conn, :combo_view, format) do
        view_module
      else
        supported_formats = Map.keys(get_private_formats(conn, :combo_view))

        raise "no view was found for the format: #{inspect(format)}. " <>
                "The supported formats are: #{inspect(supported_formats)}"
      end
    else
      raise "no format was given, and no format was inferred from the connection"
    end
  end

  @doc """
  Returns the template name rendered in the view as a string, or `nil` if
  no template was rendered.
  """
  @spec view_template(Conn.t()) :: String.t() | nil
  def view_template(conn), do: conn.private[:combo_template]

  @doc """
  Returns the template name rendered in the view as a string, or raises if
  no template was rendered.
  """
  @spec view_template!(Conn.t()) :: String.t()
  def view_template!(conn) do
    conn.private[:combo_template] || raise "no template was rendered"
  end

  defp put_private_view(conn, priv_key, kind, formats) when is_list(formats) do
    formats =
      Map.new(formats, fn
        {format, false} ->
          {to_string(format), false}

        {format, mod} when is_atom(mod) ->
          {to_string(format), mod}

        _ ->
          raise_view_bad_formats(formats)
      end)

    put_private_formats(conn, priv_key, kind, formats)
  end

  @compile {:inline, raise_view_bad_formats: 1}
  defp raise_view_bad_formats(formats) do
    raise ArgumentError, """
    expected formats to be a keyword list following this spec:

        [{format(), view()}]

    Got:

        #{inspect(formats)}
    """
  end

  ## Responses - by sending responses directly

  @doc """
  Sends text response.

  ## Examples

      iex> text(conn, "hello")

      iex> text(conn, :implements_to_string)

  """
  @spec text(Conn.t(), String.Chars.t()) :: Conn.t()
  def text(conn, data) do
    send_resp(conn, conn.status || 200, "text/plain", to_string(data))
  end

  @doc """
  Sends HTML response.

  ## Examples

      iex> html(conn, "<html><head>...")

  """
  @spec html(Conn.t(), iodata()) :: Conn.t()
  def html(conn, data) do
    send_resp(conn, conn.status || 200, "text/html", data)
  end

  @doc """
  Sends redirect response to the given url.

  For security, `:to` only accepts paths. Use the `:external` option to
  redirect to any URL.

  The response will be sent with the status code defined within the connection
  , via `Plug.Conn.put_status/2`. If no status code is set, a 302 response is
  sent.

  ## Examples

      iex> redirect(conn, to: "/login")

      iex> redirect(conn, external: "https://example.com")

  """
  @spec redirect(Conn.t(), keyword()) :: Conn.t()
  def redirect(conn, opts) when is_list(opts) do
    url = url(opts)
    html = Plug.HTML.html_escape(url)
    body = "<html><body>You are being <a href=\"#{html}\">redirected</a>.</body></html>"

    conn
    |> put_resp_header("location", url)
    |> send_resp(conn.status || 302, "text/html", body)
  end

  defp url(opts) do
    cond do
      to = opts[:to] -> validate_local_url(to)
      external = opts[:external] -> external
      true -> raise ArgumentError, "expected :to or :external option in redirect/2"
    end
  end

  @invalid_local_url_chars ["\\", "/%09", "/\t"]
  defp validate_local_url("//" <> _ = to), do: raise_invalid_url(to)

  defp validate_local_url("/" <> _ = to) do
    if String.contains?(to, @invalid_local_url_chars) do
      raise ArgumentError, "unsafe characters detected for local redirect in URL #{inspect(to)}"
    else
      to
    end
  end

  defp validate_local_url(to), do: raise_invalid_url(to)

  defp raise_invalid_url(url) do
    raise ArgumentError, "the :to option in redirect expects a path but was #{inspect(url)}"
  end

  @doc """
  Sends the given file or binary as a download.

  The second argument must be `{:binary, contents}`, where
  `contents` will be sent as download, or`{:file, path}`,
  where `path` is the filesystem location of the file to
  be sent. Be careful to not interpolate the path from
  external parameters, as it could allow traversal of the
  filesystem.

  The download is achieved by setting "content-disposition"
  to attachment. The "content-type" will also be set based
  on the extension of the given filename but can be customized
  via the `:content_type` and `:charset` options.

  ## Options

    * `:filename` - the filename to be presented to the user
      as download
    * `:content_type` - the content type of the file or binary
      sent as download. It is automatically inferred from the
      filename extension
    * `:disposition` - specifies disposition type
      (`:attachment` or `:inline`). If `:attachment` was used,
      user will be prompted to save the file. If `:inline` was used,
      the browser will attempt to open the file.
      Defaults to `:attachment`.
    * `:charset` - the charset of the file, such as "utf-8".
      Defaults to none
    * `:offset` - the bytes to offset when reading. Defaults to `0`
    * `:length` - the total bytes to read. Defaults to `:all`
    * `:encode` - encodes the filename using `URI.encode/2`.
      Defaults to `true`. When `false`, disables encoding. If you
      disable encoding, you need to guarantee there are no special
      characters in the filename, such as quotes, newlines, etc.
      Otherwise you can expose your application to security attacks

  ## Examples

  To send a file that is stored inside your application priv
  directory:

      path = Application.app_dir(:my_app, "priv/example.pdf")
      send_download(conn, {:file, path})

  When using `{:file, path}`, the filename is inferred from the
  given path but may also be set explicitly.

  To allow the user to download contents that are in memory as
  a binary or string:

      send_download(conn, {:binary, "world"}, filename: "hello.txt")

  See `Plug.Conn.send_file/3` and `Plug.Conn.send_resp/3` if you
  would like to access the low-level functions used to send files
  and responses via Plug.
  """
  def send_download(conn, kind, opts \\ [])

  def send_download(conn, {:file, path}, opts) do
    filename = opts[:filename] || Path.basename(path)
    offset = opts[:offset] || 0
    length = opts[:length] || :all

    conn
    |> prepare_send_download(filename, opts)
    |> send_file(conn.status || 200, path, offset, length)
  end

  def send_download(conn, {:binary, contents}, opts) do
    filename =
      opts[:filename] || raise ":filename option is required when sending binary download"

    conn
    |> prepare_send_download(filename, opts)
    |> send_resp(conn.status || 200, contents)
  end

  defp prepare_send_download(conn, filename, opts) do
    content_type = opts[:content_type] || MIME.from_path(filename)
    encoded_filename = encode_filename(filename, Keyword.get(opts, :encode, true))
    disposition_type = get_disposition_type(Keyword.get(opts, :disposition, :attachment))
    warn_if_ajax(conn)

    disposition = ~s[#{disposition_type}; filename="#{encoded_filename}"]

    disposition =
      if encoded_filename != filename do
        disposition <> "; filename*=utf-8''#{encoded_filename}"
      else
        disposition
      end

    conn
    |> put_resp_content_type(content_type, opts[:charset])
    |> put_resp_header("content-disposition", disposition)
  end

  defp encode_filename(filename, false), do: filename
  defp encode_filename(filename, true), do: URI.encode(filename, &URI.char_unreserved?/1)

  defp get_disposition_type(:attachment), do: "attachment"
  defp get_disposition_type(:inline), do: "inline"

  defp get_disposition_type(other),
    do:
      raise(
        ArgumentError,
        "expected :disposition to be :attachment or :inline, got: #{inspect(other)}"
      )

  defp ajax?(conn) do
    case get_req_header(conn, "x-requested-with") do
      [value] -> value in ["XMLHttpRequest", "xmlhttprequest"]
      [] -> false
    end
  end

  defp warn_if_ajax(conn) do
    if ajax?(conn) do
      Logger.warning(
        "send_download/3 has been invoked during an AJAX request. " <>
          "The download may not work as expected under XMLHttpRequest"
      )
    end
  end

  @doc """
  Sends JSON response.

  ## Examples

      iex> json(conn, %{id: 123})

  """
  @spec json(Conn.t(), term()) :: Conn.t()
  def json(conn, data) do
    response = Combo.json_library().encode_to_iodata!(data)
    send_resp(conn, conn.status || 200, "application/json", response)
  end

  ## Responses - by rendering templates

  @type template :: atom() | String.t()
  @type assigns :: keyword() | map()

  defguard is_template(template) when is_atom(template) or is_binary(template)
  defguard is_assigns(assigns) when is_list(assigns) or is_map(assigns)

  @doc """
  Render the given template or the default template specified by the current
  action with the given assigns.

  See `render/3` for more information.
  """
  @spec render(Conn.t(), template() | assigns()) :: Conn.t()
  def render(conn, template_or_assigns \\ [])

  def render(conn, template) when is_template(template) do
    render(conn, template, [])
  end

  def render(conn, assigns) when is_assigns(assigns) do
    render(conn, action_name!(conn), assigns)
  end

  @doc """
  Renders the given `template` and `assigns` based on the `conn` information.

  Once the template is rendered, the template format is set as the response
  content type (for example, an HTML template will set "text/html" as response
  content type) and the data is sent to the client with default status of 200.

  ## Arguments

    * `conn` - a `%Plug.Conn{}` struct.

    * `template` - an atom or a string. If an atom, like `:index`, it will
      render a template with the same format as the one returned by
      `get_format/1`. For example, for an HTML request, it will render the
      "index.html" template. If the template is a string, it must contain the
      extension too, like "index.html".

    * `assigns` - a keyword list or a map. It's merged into `conn.assigns` and
      have higher precedence than `conn.assigns`. The merged assigns will be
      used in the template.

  ## Examples

  Before rendering a template, you must configure the view modules to be used.
  There are multiple ways to do that:

    * use `use Combo.Controller`, which infers the view modules at compile-time.
    * use `Combo.Conn.put_view/2`, which sets the view modules at runtime.

  ### `use Combo.Controller`

  After the viets set, you can render in two ways, either passing a string
  with the template name and explicit format:

      defmodule Demo.Web.UserController do
        use Combo.Controller, formats: [:html, :json]

        def show(conn, _params) do
          render(conn, "show.html", message: "Hello")
        end
      end

  The example above renders a template "show.html" from the `Demo.Web.UserHTML`
  and sets the response content type to "text/html".

  Or, if you want the template format to be set dynamically based on the request,
  you can pass an atom instead:

      def show(conn, _params) do
        render(conn, :show, message: "Hello")
      end

  ### `Combo.Conn.put_view/2`

  If the formats are not known at compile-time, you can call `put_view/2` at
  runtime:

      defmodule Demo.Web.UserController do
        use Combo.Controller

        def show(conn, _params) do
          conn
          |> put_view(html: Demo.Web.UserHTML)
          |> render("show.html", message: "Hello")
        end
      end

  """
  @spec render(Conn.t(), template(), assigns()) :: Conn.t()
  def render(conn, template, assigns) when is_atom(template) and is_assigns(assigns) do
    format =
      get_format(conn) ||
        raise """
        cannot render template #{inspect(template)} because the format is not set. \
        Please set format via `plug :accepts, ["html", "json", ...]`, \
        or `Combo.Conn.put_format/2`, etc.\
        """

    render_and_send(conn, format, Atom.to_string(template), assigns)
  end

  def render(conn, template, assigns) when is_binary(template) and is_assigns(assigns) do
    {base, format} = split_template(template)
    conn = put_format(conn, format)
    render_and_send(conn, format, base, assigns)
  end

  defp render_and_send(conn, format, template, assigns) do
    view = view_module!(conn, format)
    conn = prepare_assigns(conn, assigns, template, format)
    data = render_with_layout(conn, view, template, format)

    conn
    |> ensure_resp_content_type(MIME.type(format))
    |> send_resp(conn.status || 200, data)
  end

  defp prepare_assigns(conn, assigns, template, format) do
    assigns = to_map(assigns)

    conn
    |> put_private(:combo_template, template <> "." <> format)
    |> Map.update!(:assigns, fn prev -> Map.merge(prev, assigns) end)
  end

  defp to_map(assigns) when is_map(assigns), do: assigns
  defp to_map(assigns) when is_list(assigns), do: :maps.from_list(assigns)

  defp render_with_layout(conn, view, template, format) do
    assigns = Map.put(conn.assigns, :conn, conn)

    case layout(conn, format) do
      {layout_mod, layout_template} ->
        {layout_base, _} = split_template(layout_template)
        inner_content = template_render(view, template, format, assigns)
        layout_assigns = Map.put(assigns, :inner_content, inner_content)
        template_render_to_iodata(layout_mod, layout_base, format, layout_assigns)

      false ->
        template_render_to_iodata(view, template, format, assigns)
    end
  end

  defp template_render(view, template, format, assigns) do
    metadata = %{view: view, template: template, format: format}

    :telemetry.span([:combo, :controller, :render], metadata, fn ->
      {Combo.Template.render(view, template, format, assigns), metadata}
    end)
  end

  defp template_render_to_iodata(view, template, format, assigns) do
    metadata = %{view: view, template: template, format: format}

    :telemetry.span([:combo, :controller, :render], metadata, fn ->
      {Combo.Template.render_to_iodata(view, template, format, assigns), metadata}
    end)
  end

  defp split_template(name) when is_atom(name), do: {Atom.to_string(name), nil}

  defp split_template(name) when is_binary(name) do
    case :binary.split(name, ".") do
      [base, format] ->
        {base, format}

      [^name] ->
        raise """
        cannot render template #{inspect(name)} without format. Use an atom if the \
        template format is meant to be set dynamically based on the request format\
        """

      [base | formats] ->
        {base, List.last(formats)}
    end
  end

  defp send_resp(conn, default_status, default_content_type, body) do
    conn
    |> ensure_resp_content_type(default_content_type)
    |> send_resp(conn.status || default_status, body)
  end

  defp ensure_resp_content_type(%Plug.Conn{resp_headers: resp_headers} = conn, content_type) do
    if List.keyfind(resp_headers, "content-type", 0) do
      conn
    else
      content_type = content_type <> "; charset=utf-8"
      %{conn | resp_headers: [{"content-type", content_type} | resp_headers]}
    end
  end

  @doc """
  Generates a status message from the template name.

  ## Examples

      iex> status_message_from_template("404.html")
      "Not Found"

      iex> status_message_from_template("whatever.html")
      "Internal Server Error"

  """
  @spec status_message_from_template(String.t()) :: String.t()
  def status_message_from_template(template) do
    template
    |> String.split(".")
    |> hd()
    |> String.to_integer()
    |> Plug.Conn.Status.reason_phrase()
  rescue
    _ -> "Internal Server Error"
  end

  ## Flash

  @doc """
  Fetches the flash, and puts it into assigns.
  """
  @spec fetch_flash(Conn.t(), keyword()) :: Conn.t()
  def fetch_flash(conn, _opts \\ []) do
    if Map.get(conn.assigns, :flash) do
      conn
    else
      session_flash = get_session(conn, "combo_flash")
      conn = persist_flash(conn, session_flash || %{})

      register_before_send(conn, fn conn ->
        flash = conn.assigns.flash
        flash_size = map_size(flash)

        cond do
          is_nil(session_flash) and flash_size == 0 ->
            conn

          flash_size > 0 and conn.status in 300..308 ->
            put_session(conn, "combo_flash", flash)

          true ->
            delete_session(conn, "combo_flash")
        end
      end)
    end
  end

  @doc """
  Merges a enumerable into the flash.

  ## Examples

      iex> conn = merge_flash(conn, info: "Welcome Back!")
      iex> Combo.Flash.get(conn.assigns.flash, :info)
      "Welcome Back!"

  """
  @spec merge_flash(Conn.t(), Enum.t()) :: Conn.t()
  def merge_flash(conn, enumerable) do
    map = for {k, v} <- enumerable, into: %{}, do: {flash_key(k), v}
    persist_flash(conn, Map.merge(Map.get(conn.assigns, :flash, %{}), map))
  end

  @doc """
  Puts a message under the key into flash.

  `key` can be any atom or binary value. Combo does not enforce which keys
  are stored in the flash, as long as the values are internally consistent.
  In general, keys like `:info` and `:error` are good ones.

  ## Examples

      iex> conn = put_flash(conn, :info, "Welcome Back!")
      iex> Combo.Flash.get(conn.assigns.flash, :info)
      "Welcome Back!"

  """
  @spec put_flash(Conn.t(), atom() | binary(), binary()) :: Conn.t()
  def put_flash(conn, key, message) do
    flash =
      Map.get(conn.assigns, :flash) ||
        raise ArgumentError, message: "flash not fetched, call fetch_flash/2"

    persist_flash(conn, Map.put(flash, flash_key(key), message))
  end

  @doc """
  Clears flash.
  """
  @spec clear_flash(Conn.t()) :: Conn.t()
  def clear_flash(conn) do
    persist_flash(conn, %{})
  end

  defp flash_key(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp flash_key(binary) when is_binary(binary), do: binary

  defp persist_flash(conn, value), do: assign(conn, :flash, value)

  ## JSONP

  @doc """
  A plug that may convert a JSON response into a JSONP one.

  In case a JSON response is returned, it will be converted to a JSONP as
  long as the callback field is present in the query string. The callback
  field itself defaults to "callback", but may be configured with the
  `:callback` option.

  In case there is no callback or the response is not encoded in JSON format,
  it is a no-op.

  Only alphanumeric characters and underscore are allowed in the
  callback name. Otherwise an exception is raised.

  ## Examples

      # Will convert JSON to JSONP if callback=someFunction is given
      plug :allow_jsonp

      # Will convert JSON to JSONP if cb=someFunction is given
      plug :allow_jsonp, callback: "cb"

  """
  @spec allow_jsonp(Conn.t(), keyword()) :: Conn.t()
  def allow_jsonp(conn, opts \\ []) do
    callback = Keyword.get(opts, :callback, "callback")

    case Map.fetch(conn.query_params, callback) do
      :error ->
        conn

      {:ok, ""} ->
        conn

      {:ok, cb} ->
        validate_jsonp_callback!(cb)

        register_before_send(conn, fn conn ->
          if json_response?(conn) do
            conn
            |> put_resp_header("content-type", "application/javascript")
            |> resp(conn.status, jsonp_body(conn.resp_body, cb))
          else
            conn
          end
        end)
    end
  end

  defp json_response?(conn) do
    case get_resp_header(conn, "content-type") do
      ["application/json;" <> _] -> true
      ["application/json"] -> true
      _ -> false
    end
  end

  defp jsonp_body(data, callback) do
    body =
      data
      |> IO.iodata_to_binary()
      |> String.replace(<<0x2028::utf8>>, "\\u2028")
      |> String.replace(<<0x2029::utf8>>, "\\u2029")

    "/**/ typeof #{callback} === 'function' && #{callback}(#{body});"
  end

  defp validate_jsonp_callback!(<<h, t::binary>>)
       when h in ?0..?9 or h in ?A..?Z or h in ?a..?z or h == ?_,
       do: validate_jsonp_callback!(t)

  defp validate_jsonp_callback!(<<>>), do: :ok

  defp validate_jsonp_callback!(_),
    do: raise(ArgumentError, "the JSONP callback name contains invalid characters")

  ## Security

  @doc """
  Enables CSRF protection.

  Currently used as a wrapper function for `Plug.CSRFProtection`.

  Check `get_csrf_token/0` and `delete_csrf_token/0` for retrieving and
  deleting CSRF tokens.
  """
  def protect_from_forgery(conn, opts \\ []) do
    Plug.CSRFProtection.call(conn, Plug.CSRFProtection.init(opts))
  end

  @doc """
  Gets or generates a CSRF token.

  If a token exists, it is returned, otherwise it is generated and stored in
  the process dictionary.
  """
  defdelegate get_csrf_token(), to: Plug.CSRFProtection

  @doc """
  Deletes the CSRF token from the process dictionary.

  *Note*: The token is deleted only after a response has been sent.
  """
  defdelegate delete_csrf_token(), to: Plug.CSRFProtection

  @doc """
  Puts headers that improve browser security.

  It sets the following headers, if they are not already set:

    * `content-security-policy` - sets `frame-ancestors` and `base-uri` to
      `self`, restricting embedding and the use of `<base>` element to same
      origin respectively. It is equivalent to setting
      `"base-uri 'self'; frame-ancestors 'self';"`.

    * `referrer-policy` - only send origin on cross origin requests.

    * `x-content-type-options` - sets to `nosniff`. This requires script and
      style tags to be sent with proper content type.

    * `x-permitted-cross-domain-policies` - sets to `none` to restrict
      Adobe Flash Player's access to data.

  A custom headers map may also be given to be merged with defaults.

  It is recommended for custom header keys to be in lowercase, to avoid sending
  duplicate keys or invalid responses.
  """
  def put_secure_browser_headers(conn, headers \\ %{})

  def put_secure_browser_headers(conn, []) do
    put_secure_defaults(conn)
  end

  def put_secure_browser_headers(conn, headers) when is_map(headers) do
    conn
    |> put_secure_defaults()
    |> merge_resp_headers(headers)
  end

  defp put_secure_defaults(%Plug.Conn{resp_headers: resp_headers} = conn) do
    headers = [
      {"referrer-policy", "strict-origin-when-cross-origin"},
      {"content-security-policy", "base-uri 'self'; frame-ancestors 'self';"},
      {"x-content-type-options", "nosniff"},
      {"x-permitted-cross-domain-policies", "none"}
    ]

    resp_headers =
      Enum.reduce(headers, resp_headers, fn {key, _} = pair, acc ->
        case :lists.keymember(key, 1, acc) do
          true -> acc
          false -> [pair | acc]
        end
      end)

    %{conn | resp_headers: resp_headers}
  end

  ## URL generation

  @doc """
  Sets the URL string or `%URI{}` to be used for URL generation.

  ## Examples

  Imagine your application is configured to run on "example.com" but after the
  user signs in, you want all links to use "some_user.example.com". You can do
  so by setting the proper router url configuration:

      def put_router_url_by_user(conn) do
        # user = ...
        put_router_url(conn, user.account_name <> ".example.com")
      end

  > Following docs should be fixed.

  Now when you call `Routes.some_route_url(conn, ...)`, it will use the router
  url set above. Keep in mind that, if you want to generate routes to the
  current domain, it is preferred to use `Routes.some_route_path` helpers,
  as those are always relative.
  """
  def put_router_url(conn, %URI{} = uri) do
    put_private(conn, :combo_router_url, URI.to_string(uri))
  end

  def put_router_url(conn, url) when is_binary(url) do
    put_private(conn, :combo_router_url, url)
  end

  @doc """
  Sets the URL string or `%URI{}` to be used for the URL generation of statics.

  > Following docs should be fixed.

  Using this function on a `%Plug.Conn{}` struct tells `static_url/2` to use
  the given information for URL generation instead of the `%Plug.Conn{}`'s
  endpoint configuration (much like `put_router_url/2` but for static URLs).
  """
  def put_static_url(conn, %URI{} = uri) do
    put_private(conn, :combo_static_url, URI.to_string(uri))
  end

  def put_static_url(conn, url) when is_binary(url) do
    put_private(conn, :combo_static_url, url)
  end

  @doc """
  Returns the current request path with its default query params.

  See `current_path/2` to override the default query params.

  The path is normalized based on the `conn.script_name` and `conn.path_info`.
  For example, "/foo//bar/" will become "/foo/bar". If you want the original
  path, use `conn.request_path` instead.

  ## Examples

      iex> current_path(conn)
      "/users/123?existing=param"

  """
  def current_path(%Plug.Conn{query_string: ""} = conn) do
    normalized_request_path(conn)
  end

  def current_path(%Plug.Conn{query_string: query_string} = conn) do
    normalized_request_path(conn) <> "?" <> query_string
  end

  @doc """
  Returns the current request path with the given query params.

  You may also retrieve only the request path by passing an empty map of params.

  The path is normalized based on the `conn.script_name` and `conn.path_info`.
  For example, "/foo//bar/" will become "/foo/bar". If you want the original
  path, use `conn.request_path` instead.

  ## Examples

      iex> current_path(conn)
      "/users/123?existing=param"

      iex> current_path(conn, %{new: "param"})
      "/users/123?new=param"

      iex> current_path(conn, %{filter: %{status: ["draft", "published"]}})
      "/users/123?filter[status][]=draft&filter[status][]=published"

      iex> current_path(conn, %{})
      "/users/123"

  """
  def current_path(%Plug.Conn{} = conn, params) when params == %{} do
    normalized_request_path(conn)
  end

  def current_path(%Plug.Conn{} = conn, params) do
    normalized_request_path(conn) <> "?" <> Plug.Conn.Query.encode(params)
  end

  defp normalized_request_path(%{path_info: info, script_name: script}) do
    "/" <> Enum.join(script ++ info, "/")
  end

  @doc """
  Returns the current request url with its default query params.

  See `current_url/2` to override the default query params.

  ## Examples

      iex> current_url(conn)
      "https://www.example.com/users/123?existing=param"

  """
  def current_url(%Plug.Conn{} = conn) do
    Combo.VerifiedRoutes.unverified_url(conn, current_path(conn))
  end

  @doc ~S"""
  Returns the current request URL with the given query params.

  The path will be retrieved from the currently requested path via
  `current_path/1`. The scheme, host and others will be received from the URL
  configuration in your endpoint. The reason we don't use the host and scheme
  information in the request is because most applications are behind proxies
  and the host and scheme may not actually reflect the host and scheme accessed
  by the client. If you want to access the url precisely as requested by the
  client, see `Plug.Conn.request_url/1`.

  ## Examples

      iex> current_url(conn)
      "https://www.example.com/users/123?existing=param"

      iex> current_url(conn, %{new: "param"})
      "https://www.example.com/users/123?new=param"

      iex> current_url(conn, %{})
      "https://www.example.com/users/123"

  ## Custom URL Generation

  In some cases, you'll need to generate a request's URL, but using a different
  scheme, different host, etc. This can be accomplished in two ways.

  If you want to do so in a case-by-case basis, you can define a custom
  function that gets the endpoint URI configuration and changes it accordingly.
  For example, to get the current URL always in HTTPS format:

      def current_secure_url(conn, params \\ %{}) do
        current_uri = MyAppWeb.Endpoint.url_struct()
        current_path = Combo.Controller.current_path(conn, params)
        Combo.VerifiedRoutes.unverified_url(%URI{current_uri | scheme: "https"}, current_path)
      end

  If you want all generated URLs to always have a certain schema, host, etc,
  you may use `put_router_url/2`.
  """
  def current_url(%Plug.Conn{} = conn, %{} = params) do
    Combo.VerifiedRoutes.unverified_url(conn, current_path(conn, params))
  end
end
