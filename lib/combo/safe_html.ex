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
      [[[], "&lt;"], "hello", "&gt;"]

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
      {:safe, [[[], "&lt;"], "hello", "&gt;"]}

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
      [[[], "&lt;"], "hello", "&gt;"]

  """
  @spec escape(String.t()) :: String.t()
  defdelegate escape(string), to: Escape, as: :escape_html

  @doc ~S"""
  Escapes an enumerable of attributes, returning iodata.

  The attributes are rendered in the given order. Note if a map is given,
  the key ordering is not guaranteed.

  The keys and values can be of any shape, as long as they implement the
  `Combo.SafeHTML.Safe` protocol.

  Additionally, there are values which have special meanings when they are
  used as the values of tag attributes:

    * if a value is `true`, the attribute is treated as boolean attribute,
      and it will be rendered with no value at all.

    * if a value is `false` or `nil`, the attribute is treated as boolean
      attribute, and it won't be rendered at all.

  ## Examples

      iex> IO.iodata_to_binary escape_attrs(title: "the title", id: "the id")
      " title=\"the title\" id=\"the id\""

      iex> IO.iodata_to_binary escape_attrs(selected: true)
      " selected"

      iex> IO.iodata_to_binary escape_attrs(hidden: false)
      ""

  """
  @spec escape_attrs([{term(), term()}] | map()) :: iodata()
  defdelegate escape_attrs(list_or_map), to: Escape

  @doc """
  Escapes a term as the key of an attribute.
  """
  @spec escape_attr_key(term()) :: iodata()
  defdelegate escape_attr_key(term), to: Escape, as: :escape_key

  @doc """
  Escapes a term as the value of an attribute.
  """
  @spec escape_attr_value(term()) :: iodata()
  defdelegate escape_attr_value(term), to: Escape, as: :escape_value
end
