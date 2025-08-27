defmodule Combo.Template.CEExEngine.TokenizerTest do
  use ExUnit.Case, async: true

  alias Combo.Template.CEExEngine.SyntaxError
  alias Combo.Template.CEExEngine.Tokenizer

  defp tokenizer_state(source), do: Tokenizer.init(source, "nofile", 0)

  defp tokenize(source) do
    state = tokenizer_state(source)
    Tokenizer.tokenize(source, [], [], {:text, :enabled}, state)
  end

  defp finalize(source, tokens, cont) do
    Tokenizer.finalize(tokens, cont, "nofile", source)
  end

  defp fetch_tokens!(source) do
    state = tokenizer_state(source)
    {tokens, _cont} = Tokenizer.tokenize(source, [], [], {:text, :enabled}, state)
    Enum.reverse(tokens)
  end

  defp tokenize_attrs(text) do
    [{_, _, attrs, _}] = fetch_tokens!(text)
    attrs
  end

  ## Syntax checking
  # First, test syntax errors separately, then focus on testing valid syntax cases.

  describe "doctype - syntax checking" do
    test "raises on unclosed tag" do
      message = """
      nofile:1:15: expected closing `>` for doctype
        |
      1 | <!doctype html
        |               ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("<!doctype html")
      end
    end
  end

  describe "comment - syntax checking" do
    test "raises on unclosed tag" do
      message = """
      nofile:1:1: unexpected end of string inside tag
        |
      1 | <!-- comment
        | ^\
      """

      assert_raise SyntaxError, message, fn ->
        source = "<!-- comment"
        {tokens, cont} = tokenize(source)
        finalize(source, tokens, cont)
      end
    end
  end

  describe "opening tag - syntax checking" do
    ## handle tag open

    test "raises on missing tag name" do
      # reached end of input
      message = """
      nofile:1:2: expected tag name after <
        |
      1 | <
        |  ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("<")
      end

      # ecountered stop chars. note that the / is removed from @stop_chars
      for char <- ~c"\s\t\f\"'>=\r\n" do
        message = """
        nofile:2:4: expected tag name after <
          |
        1 | <div>
        2 |   <#{<<char>> |> String.trim("\n")}
          |    ^\
        """

        assert_raise SyntaxError, message, fn ->
          fetch_tokens!("""
          <div>
            <#{<<char>>}\
          """)
        end
      end
    end

    test "for remote component - raises on invalid tag name" do
      message = """
      nofile:1:2: expected valid remote component name
        |
      1 | <Invalid.Name>
        |  ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("<Invalid.Name>")
      end
    end

    test "for local component - raises on missing tag name" do
      message = """
      nofile:1:2: expected local component name after .
        |
      1 | <./local_component>
        |  ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("<./local_component>")
      end
    end

    test "for local component - raises on invalid tag name" do
      message = """
      nofile:1:2: expected valid local component name after .
        |
      1 | <.InvalidName>
        |  ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("<.InvalidName>")
      end
    end

    test "for slot - raises on missing tag name" do
      message = """
      nofile:1:2: expected slot name after :
        |
      1 | <:/slot>
        |  ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("<:/slot>")
      end
    end

    test "for slot - raises on invalid tag name" do
      message = """
      nofile:1:2: expected valid slot name after :
        |
      1 | <:InvalidName>
        |  ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("<:InvalidName>")
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
        fetch_tokens!("<:inner_block>")
      end
    end

    ## handle attributes

    test "for attribute name - raises on missing attribute name" do
      message = """
      nofile:2:8: expected attribute name
        |
      1 | <div>
      2 |   <div =\"panel\">
        |        ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("""
        <div>
          <div ="panel">\
        """)
      end

      message = """
      nofile:1:6: expected attribute name
        |
      1 | <div = >
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!(~S(<div = >))
      end

      message = """
      nofile:1:6: expected attribute name
        |
      1 | <div / >
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!(~S(<div / >))
      end
    end

    test "for attribute name - raises on invalid character in attribute name" do
      message = """
      nofile:1:5: expected valid character in attribute name, got: '
        |
      1 | <div'>
        |     ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!(~S(<div'>))
      end

      message = """
      nofile:1:5: expected valid character in attribute name, got: \"
        |
      1 | <div">
        |     ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!(~S(<div">))
      end

      message = """
      nofile:1:10: expected valid character in attribute name, got: '
        |
      1 | <div attr'>
        |          ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!(~S(<div attr'>))
      end

      message = """
      nofile:1:20: expected valid character in attribute name, got: \"
        |
      1 | <div class={"test"}">
        |                    ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!(~S(<div class={"test"}">))
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
        fetch_tokens!("<div class")
      end
    end

    test "for attribute value - raises on invalid attribute value" do
      message = """
      nofile:2:9: expected valid attribute value after `=`

      The attribute value can be a value between quotes (such as "value" or 'value') \
      or an Elixir expression between curly braces (such as `{expr}`).
        |
      1 | <div
      2 |   class=>
        |         ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("""
        <div
          class=>\
        """)
      end

      message = """
      nofile:1:13: expected valid attribute value after `=`

      The attribute value can be a value between quotes (such as "value" or 'value') \
      or an Elixir expression between curly braces (such as `{expr}`).
        |
      1 | <div class= >
        |             ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!(~S(<div class= >))
      end

      message = """
      nofile:1:12: expected valid attribute value after `=`

      The attribute value can be a value between quotes (such as "value" or 'value') \
      or an Elixir expression between curly braces (such as `{expr}`).
        |
      1 | <div class=
        |            ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("<div class=")
      end
    end

    test "for attribute value - raises on missing closing quotes" do
      message = ~r"nofile:2:15: expected closing `\"` for attribute value"

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("""
        <div
          class="panel\
        """)
      end

      message = ~r"nofile:2:15: expected closing `\'` for attribute value"

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("""
        <div
          class='panel\
        """)
      end
    end

    test "for attribute value - raises on missing closing braces" do
      message = """
      nofile:2:9: expected closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it using `&lbrace;` or using `<%= "{" %>`.
        |
      1 | <div
      2 |   class={panel
        |         ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("""
        <div
          class={panel\
        """)
      end
    end

    ## handle root attributes

    test "for root attributes - raises on missing closing braces" do
      message = """
      nofile:2:3: expected closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it using `&lbrace;` or using `<%= "{" %>`.
        |
      1 | <div
      2 |   {@attrs
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("""
        <div
          {@attrs\
        """)
      end
    end

    ## handle tag open end

    test "raises on unclosed tag" do
      message = ~r"nofile:1:5: expected closing `>` or `/>` for tag"

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("<foo")
      end
    end
  end

  describe "closing tag - syntax checking" do
    ## handle tag close

    test "raises on missing tag name" do
      message = """
      nofile:2:5: expected tag name after </
        |
      1 | <div>
      2 |   </>
        |     ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("""
        <div>
          </>\
        """)
      end
    end

    ## handle tag close end

    test "raises on unclosed tag" do
      message = """
      nofile:2:6: expected closing `>` for tag
        |
      1 | <div>
      2 | </div text
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("""
        <div>
        </div text\
        """)
      end
    end
  end

  ## Tokenizing

  describe "text" do
    test "is tokenized as {:text, value}" do
      assert fetch_tokens!("Hello") == [
               {:text, "Hello", %{line_end: 1, column_end: 6}}
             ]
    end

    test "can be declared with multiple lines" do
      assert fetch_tokens!("""
             first
             second
             third
             """) == [
               {:text, "first\nsecond\nthird\n", %{line_end: 4, column_end: 1}}
             ]
    end

    test "keeps line breaks unchanged" do
      assert fetch_tokens!("first\nsecond\r\nthird") == [
               {:text, "first\nsecond\r\nthird", %{line_end: 3, column_end: 6}}
             ]
    end
  end

  describe "doctype" do
    test "is tokenized as text" do
      assert fetch_tokens!("<!doctype html>") == [
               {:text, "<!doctype html>", %{line_end: 1, column_end: 16}}
             ]
    end

    test "can be declared as multiple lines" do
      assert fetch_tokens!("""
             <!DOCTYPE
             html
             >  <br />\
             """) == [
               {:text, "<!DOCTYPE\nhtml\n>  ", %{line_end: 3, column_end: 4}},
               {:htag, "br", [],
                %{
                  tag_name: "br",
                  void?: true,
                  line: 3,
                  column: 4,
                  inner_location: {3, 10},
                  self_closing?: true
                }}
             ]
    end
  end

  describe "comment" do
    test "is tokenized as text" do
      assert fetch_tokens!("Begin<!-- comment -->End") == [
               {:text, "Begin<!-- comment -->End",
                %{line_end: 1, column_end: 25, context: [:comment_start, :comment_end]}}
             ]
    end

    test "followed by curly" do
      assert fetch_tokens!("<!-- comment -->{hello}text") == [
               {:text, "<!-- comment -->",
                %{line_end: 1, column_end: 17, context: [:comment_start, :comment_end]}},
               {:body_expr, "hello", %{line: 1, column: 17}},
               {:text, "text", %{line_end: 1, column_end: 28}}
             ]
    end

    test "multiple lines and wrapped by tags" do
      assert fetch_tokens!("""
             <p>
             <!--
             <div>
             -->
             </p><br>\
             """) == [
               {:htag, "p", [],
                %{
                  tag_name: "p",
                  void?: false,
                  line: 1,
                  column: 1,
                  inner_location: {1, 4},
                  self_closing?: false
                }},
               {:text, "\n<!--\n<div>\n-->\n",
                %{line_end: 5, column_end: 1, context: [:comment_start, :comment_end]}},
               {:close, :htag, "p",
                %{tag_name: "p", void?: false, line: 5, column: 1, inner_location: {5, 1}}},
               {:htag, "br", [],
                %{
                  tag_name: "br",
                  void?: true,
                  line: 5,
                  column: 5,
                  inner_location: {5, 9},
                  self_closing?: false
                }}
             ]
    end

    test "adds comment_start and comment_end" do
      first_part = """
      <p>
      <!--
      <div>
      """

      {first_tokens, cont} =
        Tokenizer.tokenize(
          first_part,
          [],
          [],
          {:text, :enabled},
          tokenizer_state(first_part)
        )

      second_part = """
      </div>
      -->
      </p>
      <div>
        <p>Hello</p>
      </div>
      """

      {tokens, {:text, :enabled}} =
        Tokenizer.tokenize(second_part, [], first_tokens, cont, tokenizer_state(second_part))

      assert Enum.reverse(tokens) == [
               {:htag, "p", [],
                %{
                  tag_name: "p",
                  void?: false,
                  line: 1,
                  column: 1,
                  inner_location: {1, 4},
                  self_closing?: false
                }},
               {:text, "\n<!--\n<div>\n",
                %{line_end: 4, column_end: 1, context: [:comment_start]}},
               {:text, "</div>\n-->\n", %{line_end: 3, column_end: 1, context: [:comment_end]}},
               {:close, :htag, "p",
                %{
                  tag_name: "p",
                  void?: false,
                  line: 3,
                  column: 1,
                  inner_location: {3, 1}
                }},
               {:text, "\n", %{line_end: 4, column_end: 1}},
               {:htag, "div", [],
                %{
                  tag_name: "div",
                  void?: false,
                  line: 4,
                  column: 1,
                  inner_location: {4, 6},
                  self_closing?: false
                }},
               {:text, "\n  ", %{line_end: 5, column_end: 3}},
               {:htag, "p", [],
                %{
                  tag_name: "p",
                  void?: false,
                  line: 5,
                  column: 3,
                  inner_location: {5, 6},
                  self_closing?: false
                }},
               {:text, "Hello", %{line_end: 5, column_end: 11}},
               {:close, :htag, "p",
                %{
                  tag_name: "p",
                  void?: false,
                  line: 5,
                  column: 11,
                  inner_location: {5, 11}
                }},
               {:text, "\n", %{line_end: 6, column_end: 1}},
               {:close, :htag, "div",
                %{
                  tag_name: "div",
                  void?: false,
                  line: 6,
                  column: 1,
                  inner_location: {6, 1}
                }},
               {:text, "\n", %{line_end: 7, column_end: 1}}
             ]
    end

    test "two comments in a row" do
      first_part = """
      <p>
      <!--
      <%= "Hello" %>
      """

      {first_tokens, cont} =
        Tokenizer.tokenize(
          first_part,
          [],
          [],
          {:text, :enabled},
          tokenizer_state(first_part)
        )

      second_part = """
      -->
      <!--
      <p><%= "World"</p>
      """

      {second_tokens, cont} =
        Tokenizer.tokenize(second_part, [], first_tokens, cont, tokenizer_state(second_part))

      third_part = """
      -->
      <div>
        <p>Hi</p>
      </p>
      """

      {tokens, {:text, :enabled}} =
        Tokenizer.tokenize(third_part, [], second_tokens, cont, tokenizer_state(third_part))

      assert Enum.reverse(tokens) == [
               {:htag, "p", [],
                %{
                  tag_name: "p",
                  void?: false,
                  line: 1,
                  column: 1,
                  inner_location: {1, 4},
                  self_closing?: false
                }},
               {:text, "\n<!--\n<%= \"Hello\" %>\n",
                %{line_end: 4, column_end: 1, context: [:comment_start]}},
               {:text, "-->\n<!--\n<p><%= \"World\"</p>\n",
                %{line_end: 4, column_end: 1, context: [:comment_end, :comment_start]}},
               {:text, "-->\n", %{line_end: 2, column_end: 1, context: [:comment_end]}},
               {:htag, "div", [],
                %{
                  tag_name: "div",
                  void?: false,
                  line: 2,
                  column: 1,
                  inner_location: {2, 6},
                  self_closing?: false
                }},
               {:text, "\n  ", %{line_end: 3, column_end: 3}},
               {:htag, "p", [],
                %{
                  tag_name: "p",
                  void?: false,
                  line: 3,
                  column: 3,
                  inner_location: {3, 6},
                  self_closing?: false
                }},
               {:text, "Hi", %{line_end: 3, column_end: 8}},
               {:close, :htag, "p",
                %{
                  tag_name: "p",
                  void?: false,
                  line: 3,
                  column: 8,
                  inner_location: {3, 8}
                }},
               {:text, "\n", %{line_end: 4, column_end: 1}},
               {:close, :htag, "p",
                %{
                  tag_name: "p",
                  void?: false,
                  line: 4,
                  column: 1,
                  inner_location: {4, 1}
                }},
               {:text, "\n", %{line_end: 5, column_end: 1}}
             ]
    end
  end

  describe "handle opening tag" do
    test "represented as {:htag, name, attrs, meta}" do
      assert fetch_tokens!("<div>") == [
               {:htag, "div", [],
                %{
                  tag_name: "div",
                  void?: false,
                  line: 1,
                  column: 1,
                  inner_location: {1, 6},
                  self_closing?: false
                }}
             ]
    end

    test "with space after name" do
      assert fetch_tokens!("<div >") == [
               {:htag, "div", [],
                %{
                  tag_name: "div",
                  void?: false,
                  line: 1,
                  column: 1,
                  inner_location: {1, 7},
                  self_closing?: false
                }}
             ]
    end

    test "with line break after name" do
      assert fetch_tokens!("<div\n>") == [
               {:htag, "div", [],
                %{
                  tag_name: "div",
                  void?: false,
                  line: 1,
                  column: 1,
                  inner_location: {2, 2},
                  self_closing?: false
                }}
             ]
    end

    test "self close" do
      assert fetch_tokens!("<div/>") == [
               {:htag, "div", [],
                %{
                  tag_name: "div",
                  void?: false,
                  line: 1,
                  column: 1,
                  inner_location: {1, 7},
                  self_closing?: true
                }}
             ]

      assert fetch_tokens!("<div />") == [
               {:htag, "div", [],
                %{
                  tag_name: "div",
                  void?: false,
                  line: 1,
                  column: 1,
                  inner_location: {1, 8},
                  self_closing?: true
                }}
             ]
    end

    test "compute line and column" do
      tokens =
        fetch_tokens!("""
        <div>
          <span>

        <p/><br>\
        """)

      assert [
               {:htag, "div", [], %{line: 1, column: 1}},
               {:text, _, %{line_end: 2, column_end: 3}},
               {:htag, "span", [], %{line: 2, column: 3}},
               {:text, _, %{line_end: 4, column_end: 1}},
               {:htag, "p", [], %{line: 4, column: 1, self_closing?: true}},
               {:htag, "br", [], %{line: 4, column: 5}}
             ] = tokens
    end
  end

  describe "handle attributes" do
    test "represented as a list of {name, {type, value, v_meta} | nil, meta}" do
      assert tokenize_attrs(~S(<div class="panel" hidden style={@style}>)) == [
               {"class", {:string, "panel", %{delimiter: ?"}}, %{line: 1, column: 6}},
               {"hidden", nil, %{line: 1, column: 20}},
               {"style", {:expr, "@style", %{line: 1, column: 34}}, %{line: 1, column: 27}}
             ]
    end

    test "accepts spaces between the name and `=`" do
      assert [{"class", {:string, "panel", %{}}, %{}}] =
               tokenize_attrs(~S(<div class ="panel">))
    end

    test "accepts line breaks between the name and `=`" do
      assert [{"class", {:string, "panel", %{}}, %{}}] =
               tokenize_attrs("<div class\n=\"panel\">")

      assert [{"class", {:string, "panel", %{}}, %{}}] =
               tokenize_attrs("<div class\r\n=\"panel\">")
    end

    test "accepts spaces between `=` and the value" do
      assert [{"class", {:string, "panel", %{}}, %{}}] =
               tokenize_attrs(~S(<div class= "panel">))
    end

    test "accepts line breaks between `=` and the value" do
      assert [{"class", {:string, "panel", %{}}, %{}}] =
               tokenize_attrs("<div class=\n\"panel\">")

      assert [{"class", {:string, "panel", %{}}, %{}}] =
               tokenize_attrs("<div class=\r\n\"panel\">")
    end
  end

  describe "handle attributes - boolean attributes" do
    test "represented as {name, nil, meta}" do
      assert [{"hidden", nil, %{}}] = tokenize_attrs("<div hidden>")
    end

    test "multiple attributes" do
      assert [{"hidden", nil, %{}}, {"selected", nil, %{}}] =
               tokenize_attrs("<div hidden selected>")
    end

    test "with space after" do
      assert [{"hidden", nil, %{}}] = tokenize_attrs("<div hidden >")
    end

    test "in self close tag" do
      assert [{"hidden", nil, %{}}] = tokenize_attrs("<div hidden/>")
    end

    test "in self close tag with space after" do
      assert [{"hidden", nil, %{}}] = tokenize_attrs("<div hidden />")
    end
  end

  describe "handle attributes - double quoted attributes" do
    test "value is represented as {:string, value, meta}}" do
      assert [{"class", {:string, "panel", %{delimiter: ?"}}, %{}}] =
               tokenize_attrs(~S(<div class="panel">))
    end

    test "multiple attributes" do
      assert [
               {"class", {:string, "panel", %{delimiter: ?"}}, %{}},
               {"style", {:string, "margin: 0px;", %{delimiter: ?"}}, %{}}
             ] = tokenize_attrs(~S(<div class="panel" style="margin: 0px;">))
    end

    test "value containing single quotes" do
      assert [{"title", {:string, "i'd love to!", %{delimiter: ?"}}, %{}}] =
               tokenize_attrs(~S(<div title="i'd love to!">))
    end

    test "value containing line breaks" do
      tokens =
        fetch_tokens!("""
        <div title="first
          second
        third"><span>\
        """)

      assert [
               {:htag, "div", [{"title", {:string, "first\n  second\nthird", _meta}, %{}}], %{}},
               {:htag, "span", [], %{line: 3, column: 8}}
             ] = tokens
    end
  end

  describe "handle attributes - single quoted attributes" do
    test "value is represented as {:string, value, meta}}" do
      assert [{"class", {:string, "panel", %{delimiter: ?'}}, %{}}] =
               tokenize_attrs(~S(<div class='panel'>))
    end

    test "multiple attributes" do
      assert [
               {"class", {:string, "panel", %{delimiter: ?'}}, %{}},
               {"style", {:string, "margin: 0px;", %{delimiter: ?'}}, %{}}
             ] = tokenize_attrs(~S(<div class='panel' style='margin: 0px;'>))
    end

    test "value containing double quotes" do
      assert [{"title", {:string, ~S(Say "hi!"), %{delimiter: ?'}}, %{}}] =
               tokenize_attrs(~S(<div title='Say "hi!"'>))
    end

    test "value containing line breaks" do
      tokens =
        fetch_tokens!("""
        <div title='first
          second
        third'><span>\
        """)

      assert [
               {:htag, "div", [{"title", {:string, "first\n  second\nthird", _meta}, %{}}], %{}},
               {:htag, "span", [], %{line: 3, column: 8}}
             ] = tokens
    end
  end

  describe "handle attributes - braced attributes" do
    test "value is represented as {:expr, value, meta}" do
      assert [{"class", {:expr, "@class", %{line: 1, column: 13}}, %{}}] =
               tokenize_attrs(~S(<div class={@class}>))
    end

    test "multiple attributes" do
      assert [
               {"class", {:expr, "@class", %{}}, %{}},
               {"style", {:expr, "@style", %{}}, %{}}
             ] = tokenize_attrs(~S(<div class={@class} style={@style}>))
    end

    test "double quoted strings inside expression" do
      assert [{"class", {:expr, ~S("text"), %{}}, %{}}] =
               tokenize_attrs(~S(<div class={"text"}>))
    end

    test "value containing curly braces" do
      assert [{"class", {:expr, " [{:active, @active}] ", %{}}, %{}}] =
               tokenize_attrs(~S(<div class={ [{:active, @active}] }>))
    end

    test "ignore escaped curly braces inside elixir strings" do
      assert [{"class", {:expr, ~S("\{hi"), %{}}, %{}}] = tokenize_attrs(~S(<div class={"\{hi"}>))
      assert [{"class", {:expr, ~S("hi\}"), %{}}, %{}}] = tokenize_attrs(~S(<div class={"hi\}"}>))
    end

    test "compute line and columns" do
      attrs =
        tokenize_attrs("""
        <div
          class={@class}
            style={
              @style
            }
          title={@title}
        >\
        """)

      assert [
               {"class", {:expr, _, %{line: 2, column: 10}}, %{}},
               {"style", {:expr, _, %{line: 3, column: 12}}, %{}},
               {"title", {:expr, _, %{line: 6, column: 10}}, %{}}
             ] = attrs
    end
  end

  describe "handle root attributes" do
    test "represented as {:root, value, meta}" do
      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = tokenize_attrs("<div {@attrs}>")
    end

    test "with space after" do
      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = tokenize_attrs("<div {@attrs} >")
    end

    test "with line break after closing }" do
      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = tokenize_attrs("<div {@attrs}\n>")
    end

    test "in self close tag" do
      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = tokenize_attrs("<div {@attrs}/>")
    end

    test "in self close tag with space after closing }" do
      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = tokenize_attrs("<div {@attrs} />")
    end

    test "multiple values among other attributes" do
      attrs = tokenize_attrs("<div class={@class} {@attrs1} hidden {@attrs2}/>")

      assert [
               {"class", {:expr, "@class", %{}}, %{}},
               {:root, {:expr, "@attrs1", %{}}, %{}},
               {"hidden", nil, %{}},
               {:root, {:expr, "@attrs2", %{}}, %{}}
             ] = attrs
    end

    test "compute line and columns" do
      attrs =
        tokenize_attrs("""
        <div
          {@root1}
            {
              @root2
            }
          {@root3}
        >\
        """)

      assert [
               {:root, {:expr, "@root1", %{line: 2, column: 4}}, %{line: 2, column: 4}},
               {:root, {:expr, "\n      @root2\n    ", %{line: 3, column: 6}},
                %{line: 3, column: 6}},
               {:root, {:expr, "@root3", %{line: 6, column: 4}}, %{line: 6, column: 4}}
             ] = attrs
    end
  end

  describe "handle closing tag" do
    test "represented as {:close, :htag, name, meta}" do
      assert fetch_tokens!("</div>") == [
               {:close, :htag, "div",
                %{
                  tag_name: "div",
                  void?: false,
                  line: 1,
                  column: 1,
                  inner_location: {1, 1}
                }}
             ]
    end

    test "compute line and columns" do
      tokens =
        fetch_tokens!("""
        <div>
        </div><br>\
        """)

      assert [
               {:htag, "div", [], _meta},
               {:text, "\n", %{line_end: 2, column_end: 1}},
               {:close, :htag, "div", %{line: 2, column: 1}},
               {:htag, "br", [], %{line: 2, column: 7}}
             ] = tokens
    end
  end

  describe "script" do
    test "self-closing" do
      assert fetch_tokens!("""
             <script src="foo.js" />
             """) == [
               {:htag, "script",
                [{"src", {:string, "foo.js", %{delimiter: 34}}, %{column: 9, line: 1}}],
                %{
                  tag_name: "script",
                  column: 1,
                  line: 1,
                  inner_location: {1, 24},
                  self_closing?: true,
                  void?: false
                }},
               {:text, "\n", %{column_end: 1, line_end: 2}}
             ]
    end

    test "traverses until </script>" do
      assert fetch_tokens!("""
             <script>
               a = "<a>Link</a>"
             </script>
             """) == [
               {:htag, "script", [],
                %{
                  column: 1,
                  line: 1,
                  inner_location: {1, 9},
                  tag_name: "script",
                  void?: false,
                  self_closing?: false
                }},
               {:text, "\n  a = \"<a>Link</a>\"\n", %{column_end: 1, line_end: 3}},
               {:close, :htag, "script", %{column: 1, line: 3, inner_location: {3, 1}}},
               {:text, "\n", %{column_end: 1, line_end: 4}}
             ]
    end
  end

  describe "handle special tag - script" do
    test "self-closing" do
      assert fetch_tokens!("""
             <script src="foo.js" />
             """) == [
               {:htag, "script",
                [
                  {
                    "src",
                    {:string, "foo.js", %{delimiter: ?"}},
                    %{line: 1, column: 9}
                  }
                ],
                %{
                  tag_name: "script",
                  void?: false,
                  line: 1,
                  column: 1,
                  inner_location: {1, 24},
                  self_closing?: true
                }},
               {:text, "\n", %{line_end: 2, column_end: 1}}
             ]
    end

    test "traverses until </script>" do
      assert fetch_tokens!("""
             <script>
               a = "<a>Link</a>"
             </script>
             """) == [
               {:htag, "script", [],
                %{
                  tag_name: "script",
                  void?: false,
                  line: 1,
                  column: 1,
                  inner_location: {1, 9},
                  self_closing?: false
                }},
               {:text, "\n  a = \"<a>Link</a>\"\n", %{line_end: 3, column_end: 1}},
               {:close, :htag, "script", %{line: 3, column: 1, inner_location: {3, 1}}},
               {:text, "\n", %{line_end: 4, column_end: 1}}
             ]
    end
  end

  describe "local component" do
    test "self-closing" do
      assert fetch_tokens!("""
             <.live_component module={MyApp.WeatherComponent} id="thermostat" city="Kraków" />
             """) == [
               {:local_component, "live_component",
                [
                  {"module", {:expr, "MyApp.WeatherComponent", %{line: 1, column: 26}},
                   %{line: 1, column: 18}},
                  {"id", {:string, "thermostat", %{delimiter: 34}}, %{line: 1, column: 50}},
                  {"city", {:string, "Kraków", %{delimiter: 34}}, %{line: 1, column: 66}}
                ],
                %{
                  tag_name: ".live_component",
                  line: 1,
                  column: 1,
                  inner_location: {1, 82},
                  self_closing?: true,
                  void?: false
                }},
               {:text, "\n", %{line_end: 2, column_end: 1}}
             ]
    end

    test "traverses until </.link>" do
      assert fetch_tokens!("""
             <.link href="/">Regular anchor link</.link>
             """) == [
               {:local_component, "link",
                [{"href", {:string, "/", %{delimiter: 34}}, %{line: 1, column: 8}}],
                %{
                  tag_name: ".link",
                  line: 1,
                  column: 1,
                  inner_location: {1, 17},
                  void?: false,
                  self_closing?: false
                }},
               {:text, "Regular anchor link", %{line_end: 1, column_end: 36}},
               {:close, :local_component, "link",
                %{
                  tag_name: ".link",
                  line: 1,
                  column: 36,
                  inner_location: {1, 36},
                  void?: false
                }},
               {:text, "\n", %{line_end: 2, column_end: 1}}
             ]
    end
  end

  describe "remote component" do
    test "self-closing" do
      assert fetch_tokens!("""
             <MyAppWeb.CoreComponents.flash kind={:info} flash={@flash} />
             """) == [
               {
                 :remote_component,
                 "MyAppWeb.CoreComponents.flash",
                 [
                   {"kind", {:expr, ":info", %{column: 38, line: 1}}, %{column: 32, line: 1}},
                   {"flash", {:expr, "@flash", %{column: 52, line: 1}}, %{column: 45, line: 1}}
                 ],
                 %{
                   tag_name: "MyAppWeb.CoreComponents.flash",
                   line: 1,
                   column: 1,
                   inner_location: {1, 62},
                   self_closing?: true,
                   void?: false
                 }
               },
               {:text, "\n", %{column_end: 1, line_end: 2}}
             ]
    end

    test "traverses until </MyAppWeb.CoreComponents.modal>" do
      assert fetch_tokens!("""
             <MyAppWeb.CoreComponents.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
               This is another modal.
             </MyAppWeb.CoreComponents.modal>
             """) == [
               {
                 :remote_component,
                 "MyAppWeb.CoreComponents.modal",
                 [
                   {"id", {:string, "confirm", %{delimiter: 34}}, %{line: 1, column: 32}},
                   {"on_cancel", {:expr, "JS.navigate(~p\"/posts\")", %{line: 1, column: 56}},
                    %{line: 1, column: 45}}
                 ],
                 %{
                   tag_name: "MyAppWeb.CoreComponents.modal",
                   line: 1,
                   column: 1,
                   inner_location: {1, 81},
                   void?: false,
                   self_closing?: false
                 }
               },
               {:text, "\n  This is another modal.\n", %{line_end: 3, column_end: 1}},
               {:close, :remote_component, "MyAppWeb.CoreComponents.modal",
                %{
                  tag_name: "MyAppWeb.CoreComponents.modal",
                  line: 3,
                  column: 1,
                  inner_location: {3, 1},
                  void?: false
                }},
               {:text, "\n", %{line_end: 4, column_end: 1}}
             ]
    end
  end

  test "mixing text and tags" do
    tokens =
      fetch_tokens!("""
      text before
      <div>
        text
      </div>
      text after
      """)

    assert [
             {:text, "text before\n", %{line_end: 2, column_end: 1}},
             {:htag, "div", [], %{}},
             {:text, "\n  text\n", %{line_end: 4, column_end: 1}},
             {:close, :htag, "div", %{line: 4, column: 1}},
             {:text, "\ntext after\n", %{line_end: 6, column_end: 1}}
           ] = tokens
  end
end
