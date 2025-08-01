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

  The attributes are rendered in the given order. Note if a map is given,
  the key ordering is not guaranteed.

  The keys and values can be of any shape, as long as they implement the
  `Combo.SafeHTML.Safe` protocol.

  Furthermore, the following attributes provide behaviour:

    * `:class` - it also accepts a list of classes as argument. Each element
      in the list is separated by space. `nil` and `false` elements are
      discarded. `class: ["foo", nil, "bar"]` is converted to
      `class="foo bar"`.

  ## Examples

      iex> IO.iodata_to_binary escape_attrs(title: "the title", id: "the id", selected: true)
      " title=\"the title\" id=\"the id\" selected"

  """
  @spec escape_attrs(keyword() | map()) :: String.t()
  defdelegate escape_attrs(keyword_or_map), to: Escape
end
