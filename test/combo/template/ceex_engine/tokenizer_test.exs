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

  describe "text" do
    test "is tokenized as {:text, value}" do
      assert fetch_tokens!("Hello") == [{:text, "Hello", %{line_end: 1, column_end: 6}}]
    end

    test "can be declared with multiple lines" do
      tokens =
        fetch_tokens!("""
        first
        second
        third
        """)

      assert tokens == [{:text, "first\nsecond\nthird\n", %{line_end: 4, column_end: 1}}]
    end

    test "keeps line breaks unchanged" do
      assert fetch_tokens!("first\nsecond\r\nthird") == [
               {:text, "first\nsecond\r\nthird", %{line_end: 3, column_end: 6}}
             ]
    end
  end

  describe "doctype" do
    test "raises on incomplete tags" do
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

    test "is tokenized as text" do
      assert fetch_tokens!("<!doctype html>") == [
               {:text, "<!doctype html>", %{line_end: 1, column_end: 16}}
             ]
    end

    test "can be declared as multiple lines" do
      assert fetch_tokens!("<!DOCTYPE\nhtml\n>  <br />") == [
               {:text, "<!DOCTYPE\nhtml\n>  ", %{line_end: 3, column_end: 4}},
               {:htag, "br", [],
                %{
                  column: 4,
                  line: 3,
                  self_closing?: true,
                  void?: true,
                  tag_name: "br",
                  inner_location: {3, 10}
                }}
             ]
    end
  end

  describe "comment" do
    test "raises on incomplete tags" do
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

    test "is tokenized as text" do
      assert fetch_tokens!("Begin<!-- comment -->End") == [
               {:text, "Begin<!-- comment -->End",
                %{line_end: 1, column_end: 25, context: [:comment_start, :comment_end]}}
             ]
    end

    test "followed by curly" do
      assert fetch_tokens!("<!-- comment -->{hello}text") == [
               {:text, "<!-- comment -->",
                %{column_end: 17, context: [:comment_start, :comment_end], line_end: 1}},
               {:body_expr, "hello", %{line: 1, column: 17}},
               {:text, "text", %{line_end: 1, column_end: 28}}
             ]
    end

    test "multiple lines and wrapped by tags" do
      code = """
      <p>
      <!--
      <div>
      -->
      </p><br>\
      """

      assert [
               {:htag, "p", [], %{line: 1, column: 1}},
               {:text, "\n<!--\n<div>\n-->\n", %{line_end: 5, column_end: 1}},
               {:close, :htag, "p", %{line: 5, column: 1}},
               {:htag, "br", [], %{line: 5, column: 5}}
             ] = fetch_tokens!(code)
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
                  column: 1,
                  line: 1,
                  inner_location: {1, 4},
                  tag_name: "p",
                  void?: false,
                  self_closing?: false
                }},
               {:text, "\n<!--\n<div>\n",
                %{column_end: 1, context: [:comment_start], line_end: 4}},
               {:text, "</div>\n-->\n", %{column_end: 1, context: [:comment_end], line_end: 3}},
               {:close, :htag, "p",
                %{
                  column: 1,
                  line: 3,
                  inner_location: {3, 1},
                  tag_name: "p",
                  void?: false
                }},
               {:text, "\n", %{column_end: 1, line_end: 4}},
               {:htag, "div", [],
                %{
                  column: 1,
                  line: 4,
                  inner_location: {4, 6},
                  tag_name: "div",
                  void?: false,
                  self_closing?: false
                }},
               {:text, "\n  ", %{column_end: 3, line_end: 5}},
               {:htag, "p", [],
                %{
                  column: 3,
                  line: 5,
                  inner_location: {5, 6},
                  tag_name: "p",
                  void?: false,
                  self_closing?: false
                }},
               {:text, "Hello", %{column_end: 11, line_end: 5}},
               {:close, :htag, "p",
                %{
                  column: 11,
                  line: 5,
                  inner_location: {5, 11},
                  tag_name: "p",
                  void?: false
                }},
               {:text, "\n", %{column_end: 1, line_end: 6}},
               {:close, :htag, "div",
                %{
                  column: 1,
                  line: 6,
                  inner_location: {6, 1},
                  tag_name: "div",
                  void?: false
                }},
               {:text, "\n", %{column_end: 1, line_end: 7}}
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
                  column: 1,
                  line: 1,
                  inner_location: {1, 4},
                  tag_name: "p",
                  void?: false,
                  self_closing?: false
                }},
               {:text, "\n<!--\n<%= \"Hello\" %>\n",
                %{column_end: 1, context: [:comment_start], line_end: 4}},
               {:text, "-->\n<!--\n<p><%= \"World\"</p>\n",
                %{column_end: 1, context: [:comment_end, :comment_start], line_end: 4}},
               {:text, "-->\n", %{column_end: 1, context: [:comment_end], line_end: 2}},
               {:htag, "div", [],
                %{
                  column: 1,
                  line: 2,
                  inner_location: {2, 6},
                  tag_name: "div",
                  void?: false,
                  self_closing?: false
                }},
               {:text, "\n  ", %{column_end: 3, line_end: 3}},
               {:htag, "p", [],
                %{
                  column: 3,
                  line: 3,
                  inner_location: {3, 6},
                  tag_name: "p",
                  void?: false,
                  self_closing?: false
                }},
               {:text, "Hi", %{column_end: 8, line_end: 3}},
               {:close, :htag, "p",
                %{
                  column: 8,
                  line: 3,
                  inner_location: {3, 8},
                  tag_name: "p",
                  void?: false
                }},
               {:text, "\n", %{column_end: 1, line_end: 4}},
               {:close, :htag, "p",
                %{
                  column: 1,
                  line: 4,
                  inner_location: {4, 1},
                  tag_name: "p",
                  void?: false
                }},
               {:text, "\n", %{column_end: 1, line_end: 5}}
             ]
    end
  end

  describe "opening tag" do
    test "represented as {:htag, name, attrs, meta}" do
      tokens = fetch_tokens!("<div>")
      assert [{:htag, "div", [], %{}}] = tokens
    end

    test "with space after name" do
      tokens = fetch_tokens!("<div >")
      assert [{:htag, "div", [], %{}}] = tokens
    end

    test "with line break after name" do
      tokens = fetch_tokens!("<div\n>")
      assert [{:htag, "div", [], %{}}] = tokens
    end

    test "self close" do
      tokens = fetch_tokens!("<div/>")
      assert [{:htag, "div", [], %{self_closing?: true}}] = tokens
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
               {:htag, "p", [], %{column: 1, line: 4, self_closing?: true}},
               {:htag, "br", [], %{column: 5, line: 4}}
             ] = tokens
    end

    test "raise on missing/incomplete tag name" do
      message = """
      nofile:2:4: expected tag name after <
        |
      1 | <div>
      2 |   <>
        |    ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("""
        <div>
          <>\
        """)
      end

      message = """
      nofile:1:2: expected tag name after <
        |
      1 | <
        |  ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("<")
      end

      message = """
      nofile:1:2: a component name is required after .
        |
      1 | <./typo>
        |  ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("<./typo>")
      end

      assert_raise SyntaxError, ~r"nofile:1:5: expected closing `>` or `/>`", fn ->
        fetch_tokens!("<foo")
      end
    end
  end

  describe "attributes" do
    test "represented as a list of {name, tuple | nil, meta}, where tuple is the {type, value}" do
      attrs = tokenize_attrs(~S(<div class="panel" style={@style} hidden>))

      assert [
               {"class", {:string, "panel", %{}}, %{column: 6, line: 1}},
               {"style", {:expr, "@style", %{}}, %{column: 20, line: 1}},
               {"hidden", nil, %{column: 35, line: 1}}
             ] = attrs
    end

    test "accepts space between the name and `=`" do
      attrs = tokenize_attrs(~S(<div class ="panel">))

      assert [{"class", {:string, "panel", %{}}, %{}}] = attrs
    end

    test "accepts line breaks between the name and `=`" do
      attrs = tokenize_attrs("<div class\n=\"panel\">")

      assert [{"class", {:string, "panel", %{}}, %{}}] = attrs

      attrs = tokenize_attrs("<div class\r\n=\"panel\">")

      assert [{"class", {:string, "panel", %{}}, %{}}] = attrs
    end

    test "accepts space between `=` and the value" do
      attrs = tokenize_attrs(~S(<div class= "panel">))

      assert [{"class", {:string, "panel", %{}}, %{}}] = attrs
    end

    test "accepts line breaks between `=` and the value" do
      attrs = tokenize_attrs("<div class=\n\"panel\">")

      assert [{"class", {:string, "panel", %{}}, %{}}] = attrs

      attrs = tokenize_attrs("<div class=\r\n\"panel\">")

      assert [{"class", {:string, "panel", %{}}, %{}}] = attrs
    end

    test "raise on incomplete attribute" do
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

    test "raise on missing value" do
      message = """
      nofile:2:9: invalid attribute value after `=`. Expected either a value between quotes (such as \"value\" or 'value') or an Elixir expression between curly braces (such as `{expr}`)
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
      nofile:1:13: invalid attribute value after `=`. Expected either a value between quotes (such as \"value\" or 'value') or an Elixir expression between curly braces (such as `{expr}`)
        |
      1 | <div class= >
        |             ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!(~S(<div class= >))
      end

      message = """
      nofile:1:12: invalid attribute value after `=`. Expected either a value between quotes (such as \"value\" or 'value') or an Elixir expression between curly braces (such as `{expr}`)
        |
      1 | <div class=
        |            ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("<div class=")
      end
    end

    test "raise on missing attribute name" do
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

    test "raise on attribute names with quotes" do
      message = """
      nofile:1:5: invalid character in attribute name: '
        |
      1 | <div'>
        |     ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!(~S(<div'>))
      end

      message = """
      nofile:1:5: invalid character in attribute name: \"
        |
      1 | <div">
        |     ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!(~S(<div">))
      end

      message = """
      nofile:1:10: invalid character in attribute name: '
        |
      1 | <div attr'>
        |          ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!(~S(<div attr'>))
      end

      message = """
      nofile:1:20: invalid character in attribute name: \"
        |
      1 | <div class={"test"}">
        |                    ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!(~S(<div class={"test"}">))
      end
    end
  end

  describe "boolean attributes" do
    test "represented as {name, nil, meta}" do
      attrs = tokenize_attrs("<div hidden>")

      assert [{"hidden", nil, %{}}] = attrs
    end

    test "multiple attributes" do
      attrs = tokenize_attrs("<div hidden selected>")

      assert [{"hidden", nil, %{}}, {"selected", nil, %{}}] = attrs
    end

    test "with space after" do
      attrs = tokenize_attrs("<div hidden >")

      assert [{"hidden", nil, %{}}] = attrs
    end

    test "in self close tag" do
      attrs = tokenize_attrs("<div hidden/>")

      assert [{"hidden", nil, %{}}] = attrs
    end

    test "in self close tag with space after" do
      attrs = tokenize_attrs("<div hidden />")

      assert [{"hidden", nil, %{}}] = attrs
    end
  end

  describe "attributes as double quoted string" do
    test "value is represented as {:string, value, meta}}" do
      attrs = tokenize_attrs(~S(<div class="panel">))

      assert [{"class", {:string, "panel", %{delimiter: ?"}}, %{}}] = attrs
    end

    test "multiple attributes" do
      attrs = tokenize_attrs(~S(<div class="panel" style="margin: 0px;">))

      assert [
               {"class", {:string, "panel", %{delimiter: ?"}}, %{}},
               {"style", {:string, "margin: 0px;", %{delimiter: ?"}}, %{}}
             ] = attrs
    end

    test "value containing single quotes" do
      attrs = tokenize_attrs(~S(<div title="i'd love to!">))

      assert [{"title", {:string, "i'd love to!", %{delimiter: ?"}}, %{}}] = attrs
    end

    test "value containing line breaks" do
      tokens =
        fetch_tokens!("""
        <div title="first
          second
        third"><span>\
        """)

      assert [
               {:htag, "div", [{"title", {:string, "first\n  second\nthird", _meta}, %{}}],
                %{}},
               {:htag, "span", [], %{line: 3, column: 8}}
             ] = tokens
    end

    test "raise on incomplete attribute value (EOF)" do
      assert_raise SyntaxError, ~r"nofile:2:15: expected closing `\"` for attribute value", fn ->
        fetch_tokens!("""
        <div
          class="panel\
        """)
      end
    end
  end

  describe "attributes as single quoted string" do
    test "value is represented as {:string, value, meta}}" do
      attrs = tokenize_attrs(~S(<div class='panel'>))

      assert [{"class", {:string, "panel", %{delimiter: ?'}}, %{}}] = attrs
    end

    test "multiple attributes" do
      attrs = tokenize_attrs(~S(<div class='panel' style='margin: 0px;'>))

      assert [
               {"class", {:string, "panel", %{delimiter: ?'}}, %{}},
               {"style", {:string, "margin: 0px;", %{delimiter: ?'}}, %{}}
             ] = attrs
    end

    test "value containing double quotes" do
      attrs = tokenize_attrs(~S(<div title='Say "hi!"'>))

      assert [{"title", {:string, ~S(Say "hi!"), %{delimiter: ?'}}, %{}}] = attrs
    end

    test "value containing line breaks" do
      tokens =
        fetch_tokens!("""
        <div title='first
          second
        third'><span>\
        """)

      assert [
               {:htag, "div", [{"title", {:string, "first\n  second\nthird", _meta}, %{}}],
                %{}},
               {:htag, "span", [], %{line: 3, column: 8}}
             ] = tokens
    end

    test "raise on incomplete attribute value (EOF)" do
      assert_raise SyntaxError, ~r"nofile:2:15: expected closing `\'` for attribute value", fn ->
        fetch_tokens!("""
        <div
          class='panel\
        """)
      end
    end
  end

  describe "attributes as expressions" do
    test "value is represented as {:expr, value, meta}" do
      attrs = tokenize_attrs(~S(<div class={@class}>))

      assert [{"class", {:expr, "@class", %{line: 1, column: 13}}, %{}}] = attrs
    end

    test "multiple attributes" do
      attrs = tokenize_attrs(~S(<div class={@class} style={@style}>))

      assert [
               {"class", {:expr, "@class", %{}}, %{}},
               {"style", {:expr, "@style", %{}}, %{}}
             ] = attrs
    end

    test "double quoted strings inside expression" do
      attrs = tokenize_attrs(~S(<div class={"text"}>))

      assert [{"class", {:expr, ~S("text"), %{}}, %{}}] = attrs
    end

    test "value containing curly braces" do
      attrs = tokenize_attrs(~S(<div class={ [{:active, @active}] }>))

      assert [{"class", {:expr, " [{:active, @active}] ", %{}}, %{}}] = attrs
    end

    test "ignore escaped curly braces inside elixir strings" do
      attrs = tokenize_attrs(~S(<div class={"\{hi"}>))

      assert [{"class", {:expr, ~S("\{hi"), %{}}, %{}}] = attrs

      attrs = tokenize_attrs(~S(<div class={"hi\}"}>))

      assert [{"class", {:expr, ~S("hi\}"), %{}}, %{}}] = attrs
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

    test "raise on incomplete attribute expression (EOF)" do
      message = """
      nofile:2:9: expected closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it using `&lbrace;` or using `<%= "{" %>`
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
  end

  describe "root attributes" do
    test "represented as {:root, value, meta}" do
      attrs = tokenize_attrs("<div {@attrs}>")

      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = attrs
    end

    test "with space after" do
      attrs = tokenize_attrs("<div {@attrs} >")

      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = attrs
    end

    test "with line break after" do
      attrs = tokenize_attrs("<div {@attrs}\n>")

      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = attrs
    end

    test "in self close tag" do
      attrs = tokenize_attrs("<div {@attrs}/>")

      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = attrs
    end

    test "in self close tag with space after" do
      attrs = tokenize_attrs("<div {@attrs} />")

      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = attrs
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

    test "raise on incomplete expression (EOF)" do
      message = """
      nofile:2:3: expected closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it using `&lbrace;` or using `<%= "{" %>`
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
  end

  describe "closing tag" do
    test "represented as {:close, :htag, name, meta}" do
      tokens = fetch_tokens!("</div>")
      assert [{:close, :htag, "div", %{}}] = tokens
    end

    test "compute line and columns" do
      tokens =
        fetch_tokens!("""
        <div>
        </div><br>\
        """)

      assert [
               {:htag, "div", [], _meta},
               {:text, "\n", %{column_end: 1, line_end: 2}},
               {:close, :htag, "div", %{line: 2, column: 1}},
               {:htag, "br", [], %{line: 2, column: 7}}
             ] = tokens
    end

    test "raise on missing closing `>`" do
      message = """
      nofile:2:6: expected closing `>`
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

    test "raise on missing tag name" do
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

  describe "style" do
    test "self-closing" do
      assert fetch_tokens!("""
             <style src="foo.js" />
             """) == [
               {:htag, "style",
                [{"src", {:string, "foo.js", %{delimiter: 34}}, %{column: 8, line: 1}}],
                %{
                  column: 1,
                  line: 1,
                  self_closing?: true,
                  inner_location: {1, 23},
                  tag_name: "style",
                  void?: false
                }},
               {:text, "\n", %{column_end: 1, line_end: 2}}
             ]
    end

    test "traverses until </style>" do
      assert fetch_tokens!("""
             <style>
               a = "<a>Link</a>"
             </style>
             """) == [
               {:htag, "style", [],
                %{
                  tag_name: "style",
                  column: 1,
                  line: 1,
                  inner_location: {1, 8},
                  void?: false,
                  self_closing?: false
                }},
               {:text, "\n  a = \"<a>Link</a>\"\n", %{column_end: 1, line_end: 3}},
               {:close, :htag, "style", %{column: 1, line: 3, inner_location: {3, 1}}},
               {:text, "\n", %{column_end: 1, line_end: 4}}
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

  describe "reserved component" do
    test "raise on using reserved slot :inner_block" do
      message = """
      nofile:1:2: the slot name :inner_block is reserved
        |
      1 | <:inner_block>Inner</:inner_block>
        |  ^\
      """

      assert_raise SyntaxError, message, fn ->
        fetch_tokens!("<:inner_block>Inner</:inner_block>")
      end
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

  defp tokenize_attrs(code) do
    [{:htag, "div", attrs, %{}}] = fetch_tokens!(code)
    attrs
  end
end
