defmodule Combo.SafeHTML.Escape do
  @moduledoc false

  escapes = [
    {?<, "&lt;"},
    {?>, "&gt;"},
    {?&, "&amp;"},
    {?", "&quot;"},
    {?', "&#39;"}
  ]

  # Escaping binaries

  @doc false
  def escape_binary(binary) when is_binary(binary), do: escape_binary(binary, 0, binary, [])

  for {match, insert} <- escapes do
    defp escape_binary(<<unquote(match), rest::bits>>, skip, original, acc) do
      escape_binary(rest, skip + 1, original, [acc, unquote(insert)])
    end
  end

  defp escape_binary(<<_char, rest::bits>>, skip, original, acc) do
    escape_binary(rest, skip, original, acc, 1)
  end

  defp escape_binary(<<>>, _skip, _original, acc) do
    acc
  end

  for {match, insert} <- escapes do
    defp escape_binary(<<unquote(match), rest::bits>>, skip, original, acc, len) do
      part = binary_part(original, skip, len)
      escape_binary(rest, skip + len + 1, original, [acc, part, unquote(insert)])
    end
  end

  defp escape_binary(<<_char, rest::bits>>, skip, original, acc, len) do
    escape_binary(rest, skip, original, acc, len + 1)
  end

  defp escape_binary(<<>>, 0, original, _acc, _len) do
    original
  end

  defp escape_binary(<<>>, skip, original, acc, len) do
    [acc, binary_part(original, skip, len)]
  end

  # Escaping lists

  @doc false
  def escape_list(list) when is_list(list), do: escape_list_elem(list)

  ## bytes
  for {match, insert} <- escapes do
    defp escape_list_elem(unquote(match)), do: unquote(insert)
  end

  defp escape_list_elem(h) when is_integer(h) and h >= 0 and h <= 255 do
    h
  end

  ## binaries
  defp escape_list_elem(h) when is_binary(h) do
    escape_binary(h)
  end

  ## lists
  defp escape_list_elem([h | t]), do: [escape_list_elem(h) | escape_list_elem(t)]
  defp escape_list_elem([]), do: []

  ## safe data
  defp escape_list_elem({:safe, data}) do
    data
  end

  ## fallback
  defp escape_list_elem(other) do
    raise ArgumentError,
          "expected list element to be a byte (0-255), binary, list or {:safe, data}, " <>
            "got: #{inspect(other)}"
  end
end
