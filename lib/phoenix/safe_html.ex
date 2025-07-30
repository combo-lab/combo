defmodule Combo.SafeHTML do
  @moduledoc """
  Provides HTML safety utilities.

  Its main functionality is to provide convenience functions for:

  - escaping HTML as iodata.
  - marking escaped HTML as safe tuple.
  - converting escaped iodata or safe tuple into string.
  - ...
  """

  alias Combo.SafeHTML.Safe
  alias Combo.SafeHTML.Escape

  @typedoc "May be safe or unsafe. To use it safely, conversion is required."
  @type unsafe :: Safe.t()

  @typedoc "Guaranteed to be safe."
  @type safe :: {:safe, iodata()}

  @doc """
  Converts arbitrary data into escaped iodata.

  ## Examples

      iex> to_iodata("<hello>")
      [[[] | "&lt;"], "hello" | "&gt;"]

      iex> to_iodata(~c"<hello>")
      ["&lt;", 104, 101, 108, 108, 111, "&gt;"]

      iex> to_iodata(1)
      "1"

      iex> to_iodata({:safe, "<hello>"})
      "<hello>"

  """
  @spec to_iodata(term()) :: iodata()
  def to_iodata(data), do: Safe.to_iodata(data)

  @doc """
  Converts unsafe into safe.

  ## Examples

      iex> to_safe("<hello>")
      {:safe, [[[] | "&lt;"], "hello" | "&gt;"]}

      iex> to_safe(~c"<hello>")
      {:safe, ["&lt;", 104, 101, 108, 108, 111, "&gt;"]}

      iex> to_safe(1)
      {:safe, "1"}

      iex> to_safe({:safe, "<hello>"})
      {:safe, "<hello>"}

  """
  @spec to_safe(unsafe()) :: safe()
  def to_safe({:safe, _} = safe), do: safe
  def to_safe(other), do: {:safe, Safe.to_iodata(other)}

  @doc """
  Converts a safe into a string.

  Fails if the result is not safe. In such cases, you can invoke `to_safe/1`
  or `raw/1` accordingly.

  You can combine `to_safe/1` and `safe_to_string/1` to convert a data
  structure to an escaped string:

      data |> to_safe() |> safe_to_string()

  """
  @spec safe_to_string(safe()) :: String.t()
  def safe_to_string({:safe, iodata} = _safe) do
    IO.iodata_to_binary(iodata)
  end

  @doc """
  Escapes given string for use as HTML content.

  ## Examples

      iex> escape("hello")
      "hello"

      iex> escape("<hello>")
      [[[] | "&lt;"], "hello" | "&gt;"]

  """
  @spec escape(String.t()) :: String.t()
  defdelegate escape(string), to: Escape, as: :escape_html

  @doc ~S"""
  Escapes an enumerable of attributes, returning iodata.

  The attributes are rendered in the given order. Note if
  a map is given, the key ordering is not guaranteed.

  The keys and values can be of any shape, as long as they
  implement the `Phoenix.HTML.Safe` protocol. In addition,
  if the key is an atom, it will be "dasherized". In other
  words, `:phx_value_id` will be converted to `phx-value-id`.

  Furthermore, the following attributes provide behaviour:

    * `:aria`, `:data`, and `:phx` - they accept a keyword list as
      value. `data: [confirm: "are you sure?"]` is converted to
      `data-confirm="are you sure?"`.

    * `:class` - it accepts a list of classes as argument. Each
      element in the list is separated by space. `nil` and `false`
      elements are discarded. `class: ["foo", nil, "bar"]` then
      becomes `class="foo bar"`.

    * `:id` - it is validated raise if a number is given as ID,
      which is not allowed by the HTML spec and leads to unpredictable
      behaviour.

  ## Examples

      iex> IO.iodata_to_binary escape_attrs(title: "the title", id: "the id", selected: true)
      " title=\"the title\" id=\"the id\" selected"

      iex> IO.iodata_to_binary escape_attrs(%{data: [confirm: "Are you sure?"]})
      " data-confirm=\"Are you sure?\""

      iex> IO.iodata_to_binary escape_attrs(%{phx: [value: [foo: "bar"]]})
      " phx-value-foo=\"bar\""

  """
  @spec escape_attrs(keyword() | map()) :: String.t()
  defdelegate escape_attrs(keyword_or_map), to: Escape

  @doc """
  Escapes given string for use as a JavaScript string.

  This function is useful in JavaScript responses when there is a need
  to escape HTML rendered from other templates, like in the following:

      $("#container").append("<%= escape_js(render("post.html", post: @post)) %>");

  It escapes quotes (double and single), double backslashes and others.
  """
  @spec escape_js(String.t()) :: String.t()
  defdelegate escape_js(string), to: Escape

  @doc """
  Escapes given string for use as a CSS identifier.

  ## Examples

      iex> escape_css("hello world")
      "hello\\\\ world"

      iex> escape_css("-123")
      "-\\\\31 23"

  """
  @spec escape_css(String.t()) :: String.t()
  defdelegate escape_css(string), to: Escape
end
