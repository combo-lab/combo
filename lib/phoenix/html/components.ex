defmodule Phoenix.HTML.Components do
  @moduledoc false

  use Phoenix.HTML

  @doc """
  Renders a link.

  [INSERT LVATTRDOCS]

  ## Examples

  ```ceex
  <.link href={~p"/"} class="underline">home</.link>
  ```

  ```ceex
  <.link href={URI.parse("https://elixir-lang.org")}>Elixir</.link>
  ```

  ```ceex
  <.link href="/the_world" method="delete" data-confirm="Really?">delete</.link>
  ```

  ## JavaScript dependency

  In order to support links where `:method` is not `"get"` or use the above data attributes,
  `Phoenix.HTML` relies on JavaScript. You can load `priv/static/phoenix_html.js` into your
  build tool.

  ### Data attributes

  Data attributes are added as a keyword list passed to the `data` key. The following data
  attributes are supported:

    * `data-confirm` - shows a confirmation prompt before generating and submitting the form when
      `:method` is not `"get"`.

  ### Overriding the default confirm behaviour

  `phoenix_html.js` does trigger a custom event `phoenix.link.click` on the clicked DOM element
  when a click happened. This allows you to intercept the event on its way bubbling up
  to `window` and do your own custom logic to enhance or replace how the `data-confirm`
  attribute is handled. You could for example replace the browsers `confirm()` behavior with
  a custom javascript implementation:

  ```javascript
  // Compared to a javascript window.confirm, the custom dialog does not block
  // javascript execution. Therefore to make this work as expected we store
  // the successful confirmation as an attribute and re-trigger the click event.
  // On the second click, the `data-confirm-resolved` attribute is set and we proceed.
  const RESOLVED_ATTRIBUTE = "data-confirm-resolved";
  // listen on document.body, so it's executed before the default of
  // phoenix_html, which is listening on the window object
  document.body.addEventListener('phoenix.link.click', function (e) {
    // Prevent default implementation
    e.stopPropagation();
    // Introduce alternative implementation
    var message = e.target.getAttribute("data-confirm");
    if(!message){ return; }

    // Confirm is resolved execute the click event
    if (e.target?.hasAttribute(RESOLVED_ATTRIBUTE)) {
      e.target.removeAttribute(RESOLVED_ATTRIBUTE);
      return;
    }

    // Confirm is needed, preventDefault and show your modal
    e.preventDefault();
    e.target?.setAttribute(RESOLVED_ATTRIBUTE, "");

    vex.dialog.confirm({
      message: message,
      callback: function (value) {
        if (value == true) {
          // Customer confirmed, re-trigger the click event.
          e.target?.click();
        } else {
          // Customer canceled
          e.target?.removeAttribute(RESOLVED_ATTRIBUTE);
        }
      }
    })
  }, false);
  ```

  Or you could attach your own custom behavior.

  ```javascript
  window.addEventListener('phoenix.link.click', function (e) {
    // Introduce custom behaviour
    var message = e.target.getAttribute("data-prompt");
    var answer = e.target.getAttribute("data-prompt-answer");
    if(message && answer && (answer != window.prompt(message))) {
      e.preventDefault();
    }
  }, false);
  ```

  The latter could also be bound to any `click` event, but this way you can be sure your custom
  code is only executed when the code of `phoenix_html.js` is run.

  ## CSRF Protection

  By default, CSRF tokens are generated through `Plug.CSRFProtection`.
  """
  @doc type: :component
  attr :href, :any,
    doc: """
    The new location to navigate to.
    """

  attr :method, :string,
    default: "get",
    doc: """
    The HTTP method to use with the link.

    In case the method is not `get`, the link is generated inside the form which sets the proper
    information. In order to submit the form, JavaScript must be enabled in the browser.
    """

  attr :csrf_token, :any,
    default: true,
    doc: """
    A boolean or custom token to use for links with an HTTP method other than `get`.
    """

  attr :rest, :global,
    include: ~w(download hreflang referrerpolicy rel target type),
    doc: """
    Additional attributes added to the `a` tag.
    """

  slot :inner_block,
    required: true,
    doc: """
    The content rendered inside of the `a` tag.
    """

  def link(%{href: href} = assigns) when href != "#" and not is_nil(href) do
    href = valid_destination!(href, "<.link>")
    assigns = assign(assigns, :href, href)

    ~CE"""
    <a
      href={@href}
      data-method={if @method != "get", do: @method}
      data-csrf={if @method != "get", do: csrf_token(@csrf_token, @href)}
      data-to={if @method != "get", do: @href}
      phx-no-format
      {@rest}
    >{render_slot(@inner_block)}</a>
    """
  end

  def link(%{} = assigns) do
    ~CE"""
    <a href="#" {@rest}>{render_slot(@inner_block)}</a>
    """
  end

  defp csrf_token(true, href), do: Plug.CSRFProtection.get_csrf_token_for(href)
  defp csrf_token(false, _href), do: nil
  defp csrf_token(csrf, _href) when is_binary(csrf), do: csrf

  defp valid_destination!(%URI{} = uri, context) do
    valid_destination!(URI.to_string(uri), context)
  end

  defp valid_destination!({:safe, to}, context) do
    {:safe, valid_string_destination!(IO.iodata_to_binary(to), context)}
  end

  defp valid_destination!({other, to}, _context) when is_atom(other) do
    IO.iodata_to_binary([Atom.to_string(other), ?:, to])
  end

  defp valid_destination!(to, context) do
    valid_string_destination!(IO.iodata_to_binary(to), context)
  end

  @valid_uri_schemes [
    "http:",
    "https:",
    "ftp:",
    "ftps:",
    "mailto:",
    "news:",
    "irc:",
    "gopher:",
    "nntp:",
    "feed:",
    "telnet:",
    "mms:",
    "rtsp:",
    "svn:",
    "tel:",
    "fax:",
    "xmpp:"
  ]

  for scheme <- @valid_uri_schemes do
    defp valid_string_destination!(unquote(scheme) <> _ = string, _context), do: string
  end

  defp valid_string_destination!(to, context) do
    if not match?("/" <> _, to) and String.contains?(to, ":") do
      raise ArgumentError, """
      unsupported scheme given to #{context}. In case you want to link to an
      unknown or unsafe scheme, such as javascript, use a tuple: {:javascript, rest}
      """
    else
      to
    end
  end
end
