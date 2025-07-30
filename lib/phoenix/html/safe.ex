defprotocol Phoenix.HTML.Safe do
  @moduledoc """
  Defines the HTML safe protocol.

  In order to promote HTML safety, when converting data types to strings,
  Combo doesn't use `Kernel.to_string/1`. Instead, it uses this protocol
  which must be implemented by data structures and guarantee that an HTML
  safe representation is returned.

  Furthermore, this protocol relies on iodata, which provides better
  performance when sending or streaming data to the client.
  """

  def to_iodata(data)
end

defimpl Phoenix.HTML.Safe, for: Atom do
  def to_iodata(nil), do: ""
  def to_iodata(atom), do: Combo.HTML.Escape.escape_html(Atom.to_string(atom))
end

defimpl Phoenix.HTML.Safe, for: BitString do
  def to_iodata(""), do: ""
  defdelegate to_iodata(data), to: Combo.HTML.Escape, as: :escape_html
end

defimpl Phoenix.HTML.Safe, for: Integer do
  defdelegate to_iodata(data), to: Integer, as: :to_string
end

defimpl Phoenix.HTML.Safe, for: Float do
  defdelegate to_iodata(data), to: Float, as: :to_string
end

defimpl Phoenix.HTML.Safe, for: Tuple do
  def to_iodata({:safe, iodata}), do: iodata
  def to_iodata(value), do: raise(Protocol.UndefinedError, protocol: @protocol, value: value)
end

defimpl Phoenix.HTML.Safe, for: List do
  def to_iodata(list), do: recur(list)

  defp recur([h | t]), do: [recur(h) | recur(t)]
  defp recur([]), do: []

  defp recur(?<), do: "&lt;"
  defp recur(?>), do: "&gt;"
  defp recur(?&), do: "&amp;"
  defp recur(?"), do: "&quot;"
  defp recur(?'), do: "&#39;"

  defp recur(h) when is_integer(h) and h <= 255 do
    h
  end

  defp recur(h) when is_integer(h) do
    raise ArgumentError,
          "lists in Phoenix.HTML templates only support iodata, and not chardata. Integers may only represent bytes. " <>
            "It's likely you meant to pass a string with double quotes instead of a char list with single quotes."
  end

  defp recur(h) when is_binary(h) do
    Combo.HTML.Escape.escape_html(h)
  end

  defp recur({:safe, data}) do
    data
  end

  defp recur(other) do
    raise ArgumentError,
          "lists in Phoenix.HTML and templates may only contain integers representing bytes, binaries or other lists, " <>
            "got invalid entry: #{inspect(other)}"
  end
end

defimpl Phoenix.HTML.Safe, for: Time do
  defdelegate to_iodata(data), to: Time, as: :to_iso8601
end

defimpl Phoenix.HTML.Safe, for: Date do
  defdelegate to_iodata(data), to: Date, as: :to_iso8601
end

defimpl Phoenix.HTML.Safe, for: NaiveDateTime do
  defdelegate to_iodata(data), to: NaiveDateTime, as: :to_iso8601
end

defimpl Phoenix.HTML.Safe, for: DateTime do
  def to_iodata(data) do
    # Call escape in case someone can inject reserved
    # characters in the timezone or its abbreviation
    Combo.HTML.Escape.escape_html(DateTime.to_iso8601(data))
  end
end

if Code.ensure_loaded?(Duration) do
  defimpl Phoenix.HTML.Safe, for: Duration do
    defdelegate to_iodata(data), to: Duration, as: :to_iso8601
  end
end

defimpl Phoenix.HTML.Safe, for: URI do
  def to_iodata(data), do: Combo.HTML.Escape.escape_html(URI.to_string(data))
end
