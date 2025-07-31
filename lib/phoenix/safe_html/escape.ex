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

  defp build_attrs([{:id, v} | t]),
    do: [" id=\"", id_value(v), ?" | build_attrs(t)]

  defp build_attrs([{"id", v} | t]),
    do: [" id=\"", id_value(v), ?" | build_attrs(t)]

  defp build_attrs([{:class, v} | t]),
    do: [" class=\"", class_value(v), ?" | build_attrs(t)]

  defp build_attrs([{"class", v} | t]),
    do: [" class=\"", class_value(v), ?" | build_attrs(t)]

  defp build_attrs([{:data, v} | t]) when is_list(v),
    do: nested_attrs(v, " data", t)

  defp build_attrs([{"data", v} | t]) when is_list(v),
    do: nested_attrs(v, " data", t)

  defp build_attrs([{:aria, v} | t]) when is_list(v),
    do: nested_attrs(v, " aria", t)

  defp build_attrs([{"aria", v} | t]) when is_list(v),
    do: nested_attrs(v, " aria", t)

  defp build_attrs([{k, v} | t]),
    do: [?\s, escape_key(k), ?=, ?", escape_attr(v), ?" | build_attrs(t)]

  defp build_attrs([]), do: []

  defp nested_attrs([{k, true} | kv], attr, t),
    do: [attr, ?-, escape_key(k) | nested_attrs(kv, attr, t)]

  defp nested_attrs([{_, falsy} | kv], attr, t) when falsy in [false, nil],
    do: nested_attrs(kv, attr, t)

  defp nested_attrs([{k, v} | kv], attr, t) when is_list(v),
    do: [nested_attrs(v, "#{attr}-#{escape_key(k)}", []) | nested_attrs(kv, attr, t)]

  defp nested_attrs([{k, v} | kv], attr, t),
    do: [attr, ?-, escape_key(k), ?=, ?", escape_attr(v), ?" | nested_attrs(kv, attr, t)]

  defp nested_attrs([], _attr, t),
    do: build_attrs(t)

  defp id_value(value) when is_number(value) do
    raise ArgumentError,
          "attempting to set id attribute to #{value}, " <>
            "but setting the DOM ID to a number can lead to unpredictable behaviour. " <>
            "Instead consider prefixing the id with a string, such as \"user-#{value}\" or similar"
  end

  defp id_value(value) do
    escape_attr(value)
  end

  defp class_value(value) when is_list(value) do
    value
    |> class_list_value()
    |> escape_attr()
  end

  defp class_value(value) do
    escape_attr(value)
  end

  defp class_list_value(value) do
    value
    |> Enum.flat_map(fn
      nil -> []
      false -> []
      inner when is_list(inner) -> [class_list_value(inner)]
      other -> [other]
    end)
    |> Enum.join(" ")
  end

  defp escape_key({:safe, data}), do: data
  defp escape_key(nil), do: []
  defp escape_key(other), do: Safe.to_iodata(other)

  defp escape_attr({:safe, data}), do: data
  defp escape_attr(nil), do: []
  defp escape_attr(other), do: Safe.to_iodata(other)

  @spec escape_js(String.t()) :: String.t()
  def escape_js(string) when is_binary(string),
    do: escape_js(string, "")

  defp escape_js(<<0x2028::utf8, t::binary>>, acc),
    do: escape_js(t, <<acc::binary, "\\u2028">>)

  defp escape_js(<<0x2029::utf8, t::binary>>, acc),
    do: escape_js(t, <<acc::binary, "\\u2029">>)

  defp escape_js(<<0::utf8, t::binary>>, acc),
    do: escape_js(t, <<acc::binary, "\\u0000">>)

  defp escape_js(<<"</", t::binary>>, acc),
    do: escape_js(t, <<acc::binary, ?<, ?\\, ?/>>)

  defp escape_js(<<"\r\n", t::binary>>, acc),
    do: escape_js(t, <<acc::binary, ?\\, ?n>>)

  defp escape_js(<<h, t::binary>>, acc) when h in [?", ?', ?\\, ?`],
    do: escape_js(t, <<acc::binary, ?\\, h>>)

  defp escape_js(<<h, t::binary>>, acc) when h in [?\r, ?\n],
    do: escape_js(t, <<acc::binary, ?\\, ?n>>)

  defp escape_js(<<h, t::binary>>, acc),
    do: escape_js(t, <<acc::binary, h>>)

  defp escape_js(<<>>, acc), do: acc

  @doc false
  def escape_css(string) when is_binary(string) do
    # This is a direct translation of
    # https://github.com/mathiasbynens/CSS.escape/blob/master/css.escape.js
    # into Elixir.
    string
    |> String.to_charlist()
    |> escape_css_chars()
    |> IO.iodata_to_binary()
  end

  defp escape_css_chars(chars) do
    case chars do
      # If the character is the first character and is a `-` (U+002D), and
      # there is no second character, […]
      [?- | []] -> ["\\-"]
      _ -> escape_css_chars(chars, 0, [])
    end
  end

  defp escape_css_chars([], _, acc), do: Enum.reverse(acc)

  defp escape_css_chars([char | rest], index, acc) do
    escaped =
      cond do
        # If the character is NULL (U+0000), then the REPLACEMENT CHARACTER
        # (U+FFFD).
        char == 0 ->
          <<0xFFFD::utf8>>

        # If the character is in the range [\1-\1F] (U+0001 to U+001F) or is
        # U+007F,
        # if the character is the first character and is in the range [0-9]
        # (U+0030 to U+0039),
        # if the character is the second character and is in the range [0-9]
        # (U+0030 to U+0039) and the first character is a `-` (U+002D),
        char in 0x0001..0x001F or char == 0x007F or
          (index == 0 and char in ?0..?9) or
            (index == 1 and char in ?0..?9 and hd(acc) == "-") ->
          # https://drafts.csswg.org/cssom/#escape-a-character-as-code-point
          ["\\", Integer.to_string(char, 16), " "]

        # If the character is not handled by one of the above rules and is
        # greater than or equal to U+0080, is `-` (U+002D) or `_` (U+005F), or
        # is in one of the ranges [0-9] (U+0030 to U+0039), [A-Z] (U+0041 to
        # U+005A), or [a-z] (U+0061 to U+007A), […]
        char >= 0x0080 or char in [?-, ?_] or char in ?0..?9 or char in ?A..?Z or char in ?a..?z ->
          # the character itself
          <<char::utf8>>

        true ->
          # Otherwise, the escaped character.
          # https://drafts.csswg.org/cssom/#escape-a-character
          ["\\", <<char::utf8>>]
      end

    escape_css_chars(rest, index + 1, [escaped | acc])
  end
end
