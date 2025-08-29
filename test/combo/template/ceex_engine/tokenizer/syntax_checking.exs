defmodule Combo.Template.CEExEngine.Tokenizer.SyntaxCheckingTest do
  use ExUnit.Case, async: true

  alias Combo.Template.CEExEngine.SyntaxError
  alias Combo.Template.CEExEngine.Tokenizer

  defp tokens!(contents) do
    {tokens, _cont} = Tokenizer.tokenize(contents, [], [])
    Enum.reverse(tokens)
  end

  defp attrs!(text) do
    [{_, _, attrs, _}] = tokens!(text)
    attrs
  end

  describe "doctype" do
    test "raises on unclosed tag" do
      message = """
      nofile:1:15: missing closing `>` for doctype
        |
      1 | <!doctype html
        |               ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!("<!doctype html")
      end
    end
  end

  describe "comment" do
    test "raises on unclosed tag" do
      message = """
      nofile:1:1: unexpected end of string inside tag
        |
      1 | <!-- comment
        | ^\
      """

      assert_raise SyntaxError, message, fn ->
        source = "<!-- comment"
        {tokens, cont} = Tokenizer.tokenize(source)
        Tokenizer.finalize(tokens, cont, source)
      end
    end
  end

  describe "opening tag" do
    ## handle tag open

    test "raises on missing tag name" do
      # reached end of input
      message = """
      nofile:1:2: missing tag name after <
        |
      1 | <
        |  ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!("<")
      end

      # ecountered stop chars. note that the / is removed from @stop_chars
      for char <- ~c"\s\t\f\"'>=\r\n" do
        message = """
        nofile:2:4: missing tag name after <
          |
        1 | <div>
        2 |   <#{<<char>> |> String.trim("\n")}
          |    ^\
        """

        assert_raise SyntaxError, message, fn ->
          tokens!("""
          <div>
            <#{<<char>>}\
          """)
        end
      end
    end

    test "for remote component - raises on invalid tag name" do
      message = """
      nofile:1:2: invalid tag name
        |
      1 | <Invalid.Name>
        |  ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!("<Invalid.Name>")
      end
    end

    test "for local component - raises on missing tag name" do
      message = """
      nofile:1:2: missing local component name after .
        |
      1 | <./local_component>
        |  ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!("<./local_component>")
      end
    end

    test "for local component - raises on invalid tag name" do
      message = """
      nofile:1:2: invalid local component name after .
        |
      1 | <.InvalidName>
        |  ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!("<.InvalidName>")
      end
    end

    test "for slot - raises on missing tag name" do
      message = """
      nofile:1:2: missing slot name after :
        |
      1 | <:/slot>
        |  ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!("<:/slot>")
      end
    end

    test "for slot - raises on invalid tag name" do
      message = """
      nofile:1:2: invalid slot name after :
        |
      1 | <:InvalidName>
        |  ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!("<:InvalidName>")
      end
    end

    test "for slot - raises on reserved tag name" do
      message = """
      nofile:1:2: the slot name `:inner_block` is reserved
        |
      1 | <:inner_block>
        |  ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!("<:inner_block>")
      end
    end

    ## handle attributes

    test "for attribute name - raises on missing attribute name" do
      message = """
      nofile:2:8: missing attribute name
        |
      1 | <div>
      2 |   <div =\"panel\">
        |        ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!("""
        <div>
          <div ="panel">\
        """)
      end

      message = """
      nofile:1:6: missing attribute name
        |
      1 | <div = >
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!(~S(<div = >))
      end

      message = """
      nofile:1:6: missing attribute name
        |
      1 | <div / >
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!(~S(<div / >))
      end
    end

    test "for attribute name - raises on invalid character in attribute name" do
      message = """
      nofile:1:5: invalid character in attribute name, got: '
        |
      1 | <div'>
        |     ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!(~S(<div'>))
      end

      message = """
      nofile:1:5: invalid character in attribute name, got: \"
        |
      1 | <div">
        |     ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!(~S(<div">))
      end

      message = """
      nofile:1:10: invalid character in attribute name, got: '
        |
      1 | <div attr'>
        |          ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!(~S(<div attr'>))
      end

      message = """
      nofile:1:20: invalid character in attribute name, got: \"
        |
      1 | <div class={"test"}">
        |                    ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!(~S(<div class={"test"}">))
      end
    end

    test "for attribute name - raises on incomplete attribute" do
      message = """
      nofile:1:11: unexpected end of string inside tag
        |
      1 | <div class
        |           ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!("<div class")
      end
    end

    test "for attribute value - raises on invalid attribute value" do
      message = """
      nofile:2:9: invalid attribute value after `=`

      Expected a value between quotes (such as "value" or 'value') \
      or an Elixir expression between curly braces (such as `{expr}`).
        |
      1 | <div
      2 |   class=>
        |         ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!("""
        <div
          class=>\
        """)
      end

      message = """
      nofile:1:13: invalid attribute value after `=`

      Expected a value between quotes (such as "value" or 'value') \
      or an Elixir expression between curly braces (such as `{expr}`).
        |
      1 | <div class= >
        |             ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!(~S(<div class= >))
      end

      message = """
      nofile:1:12: invalid attribute value after `=`

      Expected a value between quotes (such as "value" or 'value') \
      or an Elixir expression between curly braces (such as `{expr}`).
        |
      1 | <div class=
        |            ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!("<div class=")
      end
    end

    test "for attribute value - raises on missing closing quotes" do
      message = ~r"nofile:2:15: missing closing `\"` for attribute value"

      assert_raise SyntaxError, message, fn ->
        tokens!("""
        <div
          class="panel\
        """)
      end

      message = ~r"nofile:2:15: missing closing `\'` for attribute value"

      assert_raise SyntaxError, message, fn ->
        tokens!("""
        <div
          class='panel\
        """)
      end
    end

    test "for attribute value - raises on missing closing braces" do
      message = """
      nofile:2:9: missing closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it using `&lbrace;` or using `<%= "{" %>`.
        |
      1 | <div
      2 |   class={panel
        |         ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!("""
        <div
          class={panel\
        """)
      end
    end

    ## handle root attributes

    test "for root attributes - raises on missing closing braces" do
      message = """
      nofile:2:3: missing closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it using `&lbrace;` or using `<%= "{" %>`.
        |
      1 | <div
      2 |   {@attrs
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!("""
        <div
          {@attrs\
        """)
      end
    end

    ## handle tag open end

    test "raises on unclosed tag" do
      message = ~r"nofile:1:5: missing closing `>` or `/>` for tag"

      assert_raise SyntaxError, message, fn ->
        tokens!("<foo")
      end
    end
  end

  describe "closing tag" do
    ## handle tag close

    test "raises on missing tag name" do
      message = """
      nofile:2:5: missing tag name after </
        |
      1 | <div>
      2 |   </>
        |     ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!("""
        <div>
          </>\
        """)
      end
    end

    ## handle tag close end

    test "raises on unclosed tag" do
      message = """
      nofile:2:6: missing closing `>` for tag
        |
      1 | <div>
      2 | </div text
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        tokens!("""
        <div>
        </div text\
        """)
      end
    end
  end
end
