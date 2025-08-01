defmodule Combo.SafeHTMLTest do
  use ExUnit.Case, async: true

  import Combo.SafeHTML
  doctest Combo.SafeHTML

  describe "escape/1" do
    test "escapes entities" do
      assert escape("foo") == "foo"
      assert escape("<foo>") == [[[] | "&lt;"], "foo" | "&gt;"]
      assert escape("\" & \'") == [[[[] | "&quot;"], " " | "&amp;"], " " | "&#39;"]
    end
  end

  describe "escape_attrs/1" do
    test "key as atom" do
      assert escape_attrs([{:title, "the title"}]) |> IO.iodata_to_binary() ==
               ~s( title="the title")
    end

    test "key as string" do
      assert escape_attrs([{"title", "the title"}]) |> IO.iodata_to_binary() ==
               ~s( title="the title")
    end

    test "keep the case style of keys unchanged" do
      assert escape_attrs([{:my_attr, "value"}]) |> IO.iodata_to_binary() == ~s( my_attr="value")
      assert escape_attrs([{"my_attr", "value"}]) |> IO.iodata_to_binary() == ~s( my_attr="value")

      assert escape_attrs([{:"my-attr", "value"}]) |> IO.iodata_to_binary() ==
               ~s( my-attr="value")

      assert escape_attrs([{"my-attr", "value"}]) |> IO.iodata_to_binary() ==
               ~s( my-attr="value")
    end

    test "value as string" do
      assert escape_attrs([{:class, "btn"}]) |> IO.iodata_to_binary() == ~s( class="btn")

      assert escape_attrs([{:class, "<active>"}]) |> IO.iodata_to_binary() ==
               ~s( class="&lt;active&gt;")
    end

    test "value as list" do
      assert escape_attrs([{:class, ["btn", nil, false, "<active>"]}]) |> IO.iodata_to_binary() ==
               ~s( class="btn &lt;active&gt;")

      assert escape_attrs([{:style, ["background-color: red;", nil, false, "font-size: 40px;"]}])
             |> IO.iodata_to_binary() ==
               ~s( style="background-color: red; font-size: 40px;")
    end

    test "value as nested list" do
      assert escape_attrs([{:class, ["btn", nil, false, ["<active>", "small"]]}])
             |> IO.iodata_to_binary() ==
               ~s( class="btn &lt;active&gt; small")

      assert escape_attrs([{:class, ["btn", nil, [false, ["<active>", "small"]]]}])
             |> IO.iodata_to_binary() ==
               ~s( class="btn &lt;active&gt; small")
    end

    test "suppress value when value is true" do
      assert escape_attrs([{"required", true}]) |> IO.iodata_to_binary() == ~s( required)
      assert escape_attrs([{"selected", true}]) |> IO.iodata_to_binary() == ~s( selected)
    end

    test "suppress attribute when value is falsy" do
      assert escape_attrs([{"title", nil}]) |> IO.iodata_to_binary() == ~s()
      assert escape_attrs([{"title", false}]) |> IO.iodata_to_binary() == ~s()
    end

    test "multiple attributes" do
      assert escape_attrs([{:title, "the title"}, {:id, "the id"}]) |> IO.iodata_to_binary() ==
               ~s( title="the title" id="the id")
    end

    test "handle nested value" do
      assert escape_attrs([{"data", [{"a", "1"}, {"b", "2"}]}]) |> IO.iodata_to_binary() ==
               ~s( data-a="1" data-b="2")

      assert escape_attrs([{:data, [a: "1", b: "2"]}]) |> IO.iodata_to_binary() ==
               ~s( data-a="1" data-b="2")

      assert escape_attrs([{:data, [a: false, b: true, c: nil]}]) |> IO.iodata_to_binary() ==
               ~s( data-b)

      assert escape_attrs([{"aria", [{"a", "1"}, {"b", "2"}]}]) |> IO.iodata_to_binary() ==
               ~s( aria-a="1" aria-b="2")

      assert escape_attrs([{:aria, [a: "1", b: "2"]}]) |> IO.iodata_to_binary() ==
               ~s( aria-a="1" aria-b="2")
    end

    test "raises on number id" do
      assert_raise ArgumentError, ~r/attempting to set id attribute to 3/, fn ->
        escape_attrs([{"id", 3}])
      end
    end
  end

  test "escape_js/1" do
    assert escape_js("") == ""
    assert escape_js("\\Double backslash") == "\\\\Double backslash"
    assert escape_js("\"Double quote\"") == "\\\"Double quote\\\""
    assert escape_js("'Single quote'") == "\\'Single quote\\'"
    assert escape_js("`Backtick`") == "\\`Backtick\\`"
    assert escape_js("New line\r") == "New line\\n"
    assert escape_js("New line\n") == "New line\\n"
    assert escape_js("New line\r\n") == "New line\\n"
    assert escape_js("</close>") == "<\\/close>"
    assert escape_js("Line separator\u2028") == "Line separator\\u2028"
    assert escape_js("Paragraph separator\u2029") == "Paragraph separator\\u2029"
    assert escape_js("Null character\u0000") == "Null character\\u0000"
  end

  describe "escape_css/1" do
    test "null character" do
      assert escape_css(<<0>>) == <<0xFFFD::utf8>>
      assert escape_css("a\u0000") == "a\ufffd"
      assert escape_css("\u0000b") == "\ufffdb"
      assert escape_css("a\u0000b") == "a\ufffdb"
    end

    test "replacement character" do
      assert escape_css(<<0xFFFD::utf8>>) == <<0xFFFD::utf8>>
      assert escape_css("a\ufffd") == "a\ufffd"
      assert escape_css("\ufffdb") == "\ufffdb"
      assert escape_css("a\ufffdb") == "a\ufffdb"
    end

    test "invalid input" do
      assert_raise FunctionClauseError, fn -> escape_css(nil) end
    end

    test "control characters" do
      assert escape_css(<<0x01, 0x02, 0x1E, 0x1F>>) == "\\1 \\2 \\1E \\1F "
    end

    test "leading digit" do
      for {digit, expected} <- Enum.zip(0..9, ~w(30 31 32 33 34 35 36 37 38 39)) do
        assert escape_css("#{digit}a") == "\\#{expected} a"
      end
    end

    test "non-leading digit" do
      for digit <- 0..9 do
        assert escape_css("a#{digit}b") == "a#{digit}b"
      end
    end

    test "leading hyphen and digit" do
      for {digit, expected} <- Enum.zip(0..9, ~w(30 31 32 33 34 35 36 37 38 39)) do
        assert escape_css("-#{digit}a") == "-\\#{expected} a"
      end
    end

    test "hyphens" do
      assert escape_css("-") == "\\-"
      assert escape_css("-a") == "-a"
      assert escape_css("--") == "--"
      assert escape_css("--a") == "--a"
    end

    test "non-ASCII and special characters" do
      assert escape_css("🤷🏻‍♂️-_©") == "🤷🏻‍♂️-_©"

      assert escape_css(
               <<0x7F,
                 "\u0080\u0081\u0082\u0083\u0084\u0085\u0086\u0087\u0088\u0089\u008a\u008b\u008c\u008d\u008e\u008f\u0090\u0091\u0092\u0093\u0094\u0095\u0096\u0097\u0098\u0099\u009a\u009b\u009c\u009d\u009e\u009f">>
             ) ==
               "\\7F \u0080\u0081\u0082\u0083\u0084\u0085\u0086\u0087\u0088\u0089\u008a\u008b\u008c\u008d\u008e\u008f\u0090\u0091\u0092\u0093\u0094\u0095\u0096\u0097\u0098\u0099\u009a\u009b\u009c\u009d\u009e\u009f"

      assert escape_css("\u00a0\u00a1\u00a2") == "\u00a0\u00a1\u00a2"
    end

    test "alphanumeric characters" do
      assert escape_css("a0123456789b") == "a0123456789b"
      assert escape_css("abcdefghijklmnopqrstuvwxyz") == "abcdefghijklmnopqrstuvwxyz"
      assert escape_css("ABCDEFGHIJKLMNOPQRSTUVWXYZ") == "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    end

    test "space and exclamation mark" do
      assert escape_css(<<0x20, 0x21, 0x78, 0x79>>) == "\\ \\!xy"
    end

    test "Unicode characters" do
      # astral symbol (U+1D306 TETRAGRAM FOR CENTRE)
      assert escape_css(<<0x1D306::utf8>>) == <<0x1D306::utf8>>
    end
  end
end
