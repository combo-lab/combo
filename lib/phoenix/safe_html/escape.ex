defmodule Combo.SafeHTML.Escape do
  @moduledoc false

  alias Combo.SafeHTML.Safe

  @doc false
  def escape_html(bin) when is_binary(bin) do
    escape_html(bin, 0, bin, [])
  end

  escapes = [
    {?<, "&lt;"},
    {?>, "&gt;"},
    {?&, "&amp;"},
    {?", "&quot;"},
    {?', "&#39;"}
  ]

  for {match, insert} <- escapes do
    defp escape_html(<<unquote(match), rest::bits>>, skip, original, acc) do
      escape_html(rest, skip + 1, original, [acc | unquote(insert)])
    end
  end

  defp escape_html(<<_char, rest::bits>>, skip, original, acc) do
    escape_html(rest, skip, original, acc, 1)
  end

  defp escape_html(<<>>, _skip, _original, acc) do
    acc
  end

  for {match, insert} <- escapes do
    defp escape_html(<<unquote(match), rest::bits>>, skip, original, acc, len) do
      part = binary_part(original, skip, len)
      escape_html(rest, skip + len + 1, original, [acc, part | unquote(insert)])
    end
  end

  defp escape_html(<<_char, rest::bits>>, skip, original, acc, len) do
    escape_html(rest, skip, original, acc, len + 1)
  end

  defp escape_html(<<>>, 0, original, _acc, _len) do
    original
  end

  defp escape_html(<<>>, skip, original, acc, len) do
    [acc | binary_part(original, skip, len)]
  end

  @doc false
  def escape_attrs(attrs) when is_list(attrs) do
    build_attrs(attrs)
  end

  def escape_attrs(attrs) do
    attrs |> Enum.to_list() |> build_attrs()
  end

  defp build_attrs([{k, true} | t]),
    do: [?\s, escape_key(k) | build_attrs(t)]

  defp build_attrs([{_, false} | t]),
    do: build_attrs(t)

  defp build_attrs([{_, nil} | t]),
    do: build_attrs(t)

  defp build_attrs([{k, v} | t]),
    do: [?\s, escape_key(k), ?=, ?", escape_value(v), ?" | build_attrs(t)]

  defp build_attrs([]), do: []

  @doc false
  def escape_key({:safe, data}), do: data
  def escape_key(nil), do: []
  def escape_key(value), do: Safe.to_iodata(value)

  @doc false
  def escape_value({:safe, data}), do: data
  def escape_value(nil), do: []
  def escape_value(value) when is_list(value), do: value |> encode_list() |> Safe.to_iodata()
  def escape_value(value), do: Safe.to_iodata(value)

  defp encode_list(value) do
    value
    |> Enum.flat_map(fn
      nil -> []
      false -> []
      inner when is_list(inner) -> [encode_list(inner)]
      other -> [other]
    end)
    |> Enum.join(" ")
  end
end
