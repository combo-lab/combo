defmodule Phoenix.HTML do
  @moduledoc """
  Building blocks for working with HTML.

  It provides following main functionalities:

    * Form handling
    * A tiny JavaScript library to enhance applications

  ## HTML safety

  It is to provide convenience functions for escaping and marking HTML code
  as safe.

  By default, interpolated data in templates is considered unsafe:

  ```ch
  <%= "<hello>" %>
  ```

  will be rendered as:

  ```html
  &lt;hello&gt;
  ```

  However, in some cases, you may want to tag it as safe and show its "raw"
  contents:

  ```ch
  <%= raw "<hello>" %>
  ```

  will be rendered as

  ```html
  <hello>
  ```

  ## Form handling

  See `Phoenix.HTML.Form`.

  ## JavaScript library

  This project ships with a tiny bit of JavaScript that listens
  to all click events to:

    * Support `data-confirm="message"` attributes, which shows
      a confirmation modal with the given message

    * Support `data-method="patch|post|put|delete"` attributes,
      which sends the current click as a PATCH/POST/PUT/DELETE
      HTTP request. You will need to add `data-to` with the URL
      and `data-csrf` with the CSRF token value

    * Dispatch a "phoenix.link.click" event. You can listen to this
      event to customize the behaviour above. Returning false from
      this event will disable `data-method`. Stopping propagation
      will disable `data-confirm`

  To use the functionality above, you must load `priv/static/phoenix_html.js`
  into your build tool.

  ### Overriding the default confirmation behaviour

  You can override the default implementation by hooking
  into `phoenix.link.click`. Here is an example:

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

  """

  @doc false
  defmacro __using__(_) do
    raise """
    use Phoenix.HTML is no longer supported in v4.0.

    To keep compatibility with previous versions, \
    add {:phoenix_html_helpers, "~> 1.0"} to your mix.exs deps
    and then, instead of "use Phoenix.HTML", you might:

        import Phoenix.HTML
        import Phoenix.HTML.Form
        use PhoenixHTMLHelpers

    """
  end


  @doc """
  Marks the given content as raw.

  This means any HTML code inside the given
  string won't be escaped.

      iex> raw({:safe, "<hello>"})
      {:safe, "<hello>"}

      iex> raw("<hello>")
      {:safe, "<hello>"}

      iex> raw(nil)
      {:safe, ""}

  """
  @spec raw(Combo.SafeHTML.safe() | iodata() | nil) :: Combo.SafeHTML.safe()
  def raw({:safe, _} = safe), do: safe
  def raw(nil), do: {:safe, ""}
  def raw(value) when is_binary(value) or is_list(value), do: {:safe, value}
end
