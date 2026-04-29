defprotocol Combo.SafeHTML.Safe do
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

alias Combo.SafeHTML.Escape

defimpl Combo.SafeHTML.Safe, for: Atom do
  def to_iodata(nil), do: ""
  def to_iodata(atom), do: Escape.escape_binary(Atom.to_string(atom))
end

defimpl Combo.SafeHTML.Safe, for: BitString do
  def to_iodata(""), do: ""
  defdelegate to_iodata(data), to: Escape, as: :escape_binary
end

defimpl Combo.SafeHTML.Safe, for: Integer do
  defdelegate to_iodata(data), to: Integer, as: :to_string
end

defimpl Combo.SafeHTML.Safe, for: Float do
  defdelegate to_iodata(data), to: Float, as: :to_string
end

defimpl Combo.SafeHTML.Safe, for: Tuple do
  def to_iodata({:safe, iodata}), do: iodata
  def to_iodata(value), do: raise(Protocol.UndefinedError, protocol: @protocol, value: value)
end

defimpl Combo.SafeHTML.Safe, for: List do
  defdelegate to_iodata(list), to: Escape, as: :escape_list
end

defimpl Combo.SafeHTML.Safe, for: Time do
  defdelegate to_iodata(data), to: Time, as: :to_iso8601
end

defimpl Combo.SafeHTML.Safe, for: Date do
  defdelegate to_iodata(data), to: Date, as: :to_iso8601
end

defimpl Combo.SafeHTML.Safe, for: NaiveDateTime do
  defdelegate to_iodata(data), to: NaiveDateTime, as: :to_iso8601
end

defimpl Combo.SafeHTML.Safe, for: DateTime do
  def to_iodata(data) do
    # Call escape in case someone can inject reserved
    # characters in the timezone or its abbreviation
    Escape.escape_binary(DateTime.to_iso8601(data))
  end
end

if Code.ensure_loaded?(Duration) do
  defimpl Combo.SafeHTML.Safe, for: Duration do
    defdelegate to_iodata(data), to: Duration, as: :to_iso8601
  end
end

defimpl Combo.SafeHTML.Safe, for: URI do
  def to_iodata(data), do: Escape.escape_binary(URI.to_string(data))
end

if Code.ensure_loaded?(Decimal) do
  defimpl Combo.SafeHTML.Safe, for: Decimal do
    def to_iodata(t) do
      @for.to_string(t, :normal)
    end
  end
end
