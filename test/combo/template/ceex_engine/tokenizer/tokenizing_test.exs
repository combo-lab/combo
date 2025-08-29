defmodule Combo.Template.CEExEngine.Tokenizer.TokenizingTest do
  use ExUnit.Case, async: true

  alias Combo.Template.CEExEngine.Tokenizer

  defp tokens!(contents) do
    {tokens, _cont} = Tokenizer.tokenize(contents, [], [])
    Enum.reverse(tokens)
  end

  defp attrs!(text) do
    [{_, _, attrs, _}] = tokens!(text)
    attrs
  end

  describe "text" do
    test "is represented as {:text, value, meta}" do
      assert tokens!("Hello") == [
               {:text, "Hello", %{line_end: 1, column_end: 6}}
             ]
    end

    test "can be declared with multiple lines" do
      assert tokens!("""
             first
             second
             third
             """) == [
               {:text, "first\nsecond\nthird\n", %{line_end: 4, column_end: 1}}
             ]
    end

    test "keeps line breaks unchanged" do
      assert tokens!("first\nsecond\r\nthird") == [
               {:text, "first\nsecond\r\nthird", %{line_end: 3, column_end: 6}}
             ]
    end
  end

  describe "doctype" do
    test "is handled as text" do
      assert tokens!("<!doctype html>") == [
               {:text, "<!doctype html>", %{line_end: 1, column_end: 16}}
             ]
    end

    test "can be declared with multiple lines" do
      assert tokens!("""
             <!DOCTYPE
             html
             >  <br />\
             """) == [
               {:text, "<!DOCTYPE\nhtml\n>  ", %{line_end: 3, column_end: 4}},
               {:htag, "br", [],
                %{
                  tag_name: "br",
                  void?: true,
                  self_closing?: true,
                  line: 3,
                  column: 4,
                  inner_location: {3, 10}
                }}
             ]
    end
  end

  describe "comments" do
    test "are handled as text" do
      assert tokens!("Begin<!-- comment -->End") == [
               {:text, "Begin<!-- comment -->End",
                %{line_end: 1, column_end: 25, context: [:comment_start, :comment_end]}}
             ]
    end

    test "can be followed by curly interpolation" do
      assert tokens!("<!-- comment -->{hello}text") == [
               {:text, "<!-- comment -->",
                %{line_end: 1, column_end: 17, context: [:comment_start, :comment_end]}},
               {:body_expr, "hello", %{line: 1, column: 17}},
               {:text, "text", %{line_end: 1, column_end: 28}}
             ]
    end

    test "can be declared with multiple lines and wrapped by tags" do
      assert tokens!("""
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
                  self_closing?: false,
                  line: 1,
                  column: 1,
                  inner_location: {1, 4}
                }},
               {:text, "\n<!--\n<div>\n-->\n",
                %{line_end: 5, column_end: 1, context: [:comment_start, :comment_end]}},
               {:close, :htag, "p",
                %{tag_name: "p", void?: false, line: 5, column: 1, inner_location: {5, 1}}},
               {:htag, "br", [],
                %{
                  tag_name: "br",
                  void?: true,
                  self_closing?: false,
                  line: 5,
                  column: 5,
                  inner_location: {5, 9}
                }}
             ]
    end

    test "add comment_start and comment_end contexts" do
      first_part = """
      <p>
      <!--
      <div>
      """

      {first_tokens, cont} = Tokenizer.tokenize(first_part, [], [])

      second_part = """
      </div>
      -->
      </p>
      <div>
        <p>Hello</p>
      </div>
      """

      {tokens, {:text, :enabled}} = Tokenizer.tokenize(second_part, first_tokens, cont: cont)

      assert Enum.reverse(tokens) == [
               {:htag, "p", [],
                %{
                  tag_name: "p",
                  void?: false,
                  self_closing?: false,
                  line: 1,
                  column: 1,
                  inner_location: {1, 4}
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
                  self_closing?: false,
                  line: 4,
                  column: 1,
                  inner_location: {4, 6}
                }},
               {:text, "\n  ", %{line_end: 5, column_end: 3}},
               {:htag, "p", [],
                %{
                  tag_name: "p",
                  void?: false,
                  self_closing?: false,
                  line: 5,
                  column: 3,
                  inner_location: {5, 6}
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

    test "allow multiple comments" do
      first_part = """
      <p>
      <!--
      <%= "Hello" %>
      """

      {first_tokens, cont} = Tokenizer.tokenize(first_part, [], [])

      second_part = """
      -->
      <!--
      <p><%= "World"</p>
      """

      {second_tokens, cont} = Tokenizer.tokenize(second_part, first_tokens, cont: cont)

      third_part = """
      -->
      <div>
        <p>Hi</p>
      </p>
      """

      {tokens, {:text, :enabled}} = Tokenizer.tokenize(third_part, second_tokens, cont: cont)

      assert Enum.reverse(tokens) == [
               {:htag, "p", [],
                %{
                  tag_name: "p",
                  void?: false,
                  self_closing?: false,
                  line: 1,
                  column: 1,
                  inner_location: {1, 4}
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
                  self_closing?: false,
                  line: 2,
                  column: 1,
                  inner_location: {2, 6}
                }},
               {:text, "\n  ", %{line_end: 3, column_end: 3}},
               {:htag, "p", [],
                %{
                  tag_name: "p",
                  void?: false,
                  self_closing?: false,
                  line: 3,
                  column: 3,
                  inner_location: {3, 6}
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

  describe "opening tags" do
    test "are represented as {:htag, name, attrs, meta}" do
      assert tokens!("<div>") == [
               {:htag, "div", [],
                %{
                  tag_name: "div",
                  void?: false,
                  self_closing?: false,
                  line: 1,
                  column: 1,
                  inner_location: {1, 6}
                }}
             ]
    end

    test "accept space after name" do
      assert tokens!("<div >") == [
               {:htag, "div", [],
                %{
                  tag_name: "div",
                  void?: false,
                  self_closing?: false,
                  line: 1,
                  column: 1,
                  inner_location: {1, 7}
                }}
             ]
    end

    test "accept line break after name" do
      assert tokens!("<div\n>") == [
               {:htag, "div", [],
                %{
                  tag_name: "div",
                  void?: false,
                  self_closing?: false,
                  line: 1,
                  column: 1,
                  inner_location: {2, 2}
                }}
             ]
    end

    test "can be self-closed" do
      assert tokens!("<div/>") == [
               {:htag, "div", [],
                %{
                  tag_name: "div",
                  void?: false,
                  self_closing?: true,
                  line: 1,
                  column: 1,
                  inner_location: {1, 7}
                }}
             ]

      assert tokens!("<div />") == [
               {:htag, "div", [],
                %{
                  tag_name: "div",
                  void?: false,
                  self_closing?: true,
                  line: 1,
                  column: 1,
                  inner_location: {1, 8}
                }}
             ]
    end

    test "compute lines and columns" do
      tokens =
        tokens!("""
        <div>
          <span>

        <p/><br>\
        """)

      assert [
               {:htag, "div", [], %{line: 1, column: 1}},
               {:text, _, %{line_end: 2, column_end: 3}},
               {:htag, "span", [], %{line: 2, column: 3}},
               {:text, _, %{line_end: 4, column_end: 1}},
               {:htag, "p", [], %{self_closing?: true, line: 4, column: 1}},
               {:htag, "br", [], %{line: 4, column: 5}}
             ] = tokens
    end
  end

  describe "attributes" do
    test "are represented as a list of {name, {type, value, v_meta} | nil, meta}" do
      assert attrs!(~S(<div class="panel" hidden style={@style}>)) == [
               {"class", {:string, "panel", %{delimiter: ?"}}, %{line: 1, column: 6}},
               {"hidden", nil, %{line: 1, column: 20}},
               {"style", {:expr, "@style", %{line: 1, column: 34}}, %{line: 1, column: 27}}
             ]
    end

    test "accept spaces between the name and `=`" do
      assert [{"class", {:string, "panel", %{}}, %{}}] =
               attrs!(~S(<div class ="panel">))
    end

    test "accept line breaks between the name and `=`" do
      assert [{"class", {:string, "panel", %{}}, %{}}] =
               attrs!("<div class\n=\"panel\">")

      assert [{"class", {:string, "panel", %{}}, %{}}] =
               attrs!("<div class\r\n=\"panel\">")
    end

    test "accept spaces between `=` and the value" do
      assert [{"class", {:string, "panel", %{}}, %{}}] =
               attrs!(~S(<div class= "panel">))
    end

    test "accept line breaks between `=` and the value" do
      assert [{"class", {:string, "panel", %{}}, %{}}] =
               attrs!("<div class=\n\"panel\">")

      assert [{"class", {:string, "panel", %{}}, %{}}] =
               attrs!("<div class=\r\n\"panel\">")
    end
  end

  describe "attributes - boolean attributes" do
    test "is represented as {name, nil, meta}" do
      assert [{"hidden", nil, %{}}] = attrs!("<div hidden>")
    end

    test "can be used multiple times" do
      assert [{"hidden", nil, %{}}, {"selected", nil, %{}}] =
               attrs!("<div hidden selected>")
    end

    test "accept space after name" do
      assert [{"hidden", nil, %{}}] = attrs!("<div hidden >")
    end

    test "in self-closing tag" do
      assert [{"hidden", nil, %{}}] = attrs!("<div hidden/>")
    end

    test "accept space after name in self-closing tag" do
      assert [{"hidden", nil, %{}}] = attrs!("<div hidden />")
    end
  end

  describe "attributes - double quoted attributes" do
    test "are represented as {:string, value, meta}}" do
      assert [{"class", {:string, "panel", %{delimiter: ?"}}, %{}}] =
               attrs!(~S(<div class="panel">))
    end

    test "allow multiple attributes" do
      assert [
               {"class", {:string, "panel", %{delimiter: ?"}}, %{}},
               {"style", {:string, "margin: 0px;", %{delimiter: ?"}}, %{}}
             ] = attrs!(~S(<div class="panel" style="margin: 0px;">))
    end

    test "allow single quotes" do
      assert [{"title", {:string, "i'd love to!", %{delimiter: ?"}}, %{}}] =
               attrs!(~S(<div title="i'd love to!">))
    end

    test "allow line breaks" do
      tokens =
        tokens!("""
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

  describe "attributes - single quoted attributes" do
    test "are represented as {:string, value, meta}}" do
      assert [{"class", {:string, "panel", %{delimiter: ?'}}, %{}}] =
               attrs!(~S(<div class='panel'>))
    end

    test "allow multiple attributes" do
      assert [
               {"class", {:string, "panel", %{delimiter: ?'}}, %{}},
               {"style", {:string, "margin: 0px;", %{delimiter: ?'}}, %{}}
             ] = attrs!(~S(<div class='panel' style='margin: 0px;'>))
    end

    test "allow double quotes" do
      assert [{"title", {:string, ~S(Say "hi!"), %{delimiter: ?'}}, %{}}] =
               attrs!(~S(<div title='Say "hi!"'>))
    end

    test "allow line breaks" do
      tokens =
        tokens!("""
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

  describe "attributes - braced attributes" do
    test "are represented as {:expr, value, meta}" do
      assert [{"class", {:expr, "@class", %{line: 1, column: 13}}, %{}}] =
               attrs!(~S(<div class={@class}>))
    end

    test "allow multiple attributes" do
      assert [
               {"class", {:expr, "@class", %{}}, %{}},
               {"style", {:expr, "@style", %{}}, %{}}
             ] = attrs!(~S(<div class={@class} style={@style}>))
    end

    test "allow double quoted strings inside expression" do
      assert [{"class", {:expr, ~S("text"), %{}}, %{}}] =
               attrs!(~S(<div class={"text"}>))
    end

    test "allow curly braces" do
      assert [{"class", {:expr, " [{:active, @active}] ", %{}}, %{}}] =
               attrs!(~S(<div class={ [{:active, @active}] }>))
    end

    test "ignore escaped curly braces inside elixir strings" do
      assert [{"class", {:expr, ~S("\{hi"), %{}}, %{}}] = attrs!(~S(<div class={"\{hi"}>))
      assert [{"class", {:expr, ~S("hi\}"), %{}}, %{}}] = attrs!(~S(<div class={"hi\}"}>))
    end

    test "compute lines and columns" do
      attrs =
        attrs!("""
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

  describe "root attributes" do
    test "are represented as {:root, value, meta}" do
      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = attrs!("<div {@attrs}>")
    end

    test "allow space after closing }" do
      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = attrs!("<div {@attrs} >")
    end

    test "allow line breaks after closing }" do
      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = attrs!("<div {@attrs}\n>")
    end

    test "in self-closing tag" do
      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = attrs!("<div {@attrs}/>")
    end

    test "allow space after closing } in self-closing tag" do
      assert [{:root, {:expr, "@attrs", %{}}, %{}}] = attrs!("<div {@attrs} />")
    end

    test "allow multiple usage" do
      attrs = attrs!("<div class={@class} {@attrs1} hidden {@attrs2}/>")

      assert [
               {"class", {:expr, "@class", %{}}, %{}},
               {:root, {:expr, "@attrs1", %{}}, %{}},
               {"hidden", nil, %{}},
               {:root, {:expr, "@attrs2", %{}}, %{}}
             ] = attrs
    end

    test "compute lines and columns" do
      attrs =
        attrs!("""
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

  describe "closing tags" do
    test "are represented as {:close, :htag, name, meta}" do
      assert tokens!("</div>") == [
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

    test "compute lines and columns" do
      tokens =
        tokens!("""
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

  describe "special tag - style" do
    test "as paired tags" do
      assert tokens!("""
             <style>
               p {
                 color: #26b72b;
               }
             </style><br>
             """) == [
               {:htag, "style", [],
                %{
                  tag_name: "style",
                  void?: false,
                  self_closing?: false,
                  line: 1,
                  column: 1,
                  inner_location: {1, 8}
                }},
               {:text, "\n  p {\n    color: #26b72b;\n  }\n", %{line_end: 5, column_end: 1}},
               {:close, :htag, "style", %{line: 5, column: 1, inner_location: {5, 1}}},
               {:htag, "br", [],
                %{
                  tag_name: "br",
                  void?: true,
                  self_closing?: false,
                  line: 5,
                  column: 9,
                  inner_location: {5, 13}
                }},
               {:text, "\n", %{line_end: 6, column_end: 1}}
             ]
    end

    test "as self-closing tag" do
      assert tokens!("""
             <style blocking="render" /><br>
             """) == [
               {:htag, "style",
                [
                  {
                    "blocking",
                    {:string, "render", %{delimiter: ?"}},
                    %{line: 1, column: 8}
                  }
                ],
                %{
                  tag_name: "style",
                  void?: false,
                  self_closing?: true,
                  line: 1,
                  column: 1,
                  inner_location: {1, 28}
                }},
               {:htag, "br", [],
                %{
                  tag_name: "br",
                  void?: true,
                  self_closing?: false,
                  line: 1,
                  column: 28,
                  inner_location: {1, 32}
                }},
               {:text, "\n", %{line_end: 2, column_end: 1}}
             ]
    end
  end

  describe "special tag - script" do
    test "as paired tags" do
      assert tokens!("""
             <script>
               a = "<a>Link</a>"; b = {};
             </script><br>
             """) == [
               {:htag, "script", [],
                %{
                  tag_name: "script",
                  void?: false,
                  self_closing?: false,
                  line: 1,
                  column: 1,
                  inner_location: {1, 9}
                }},
               {:text, "\n  a = \"<a>Link</a>\"; b = {};\n", %{line_end: 3, column_end: 1}},
               {:close, :htag, "script", %{line: 3, column: 1, inner_location: {3, 1}}},
               {:htag, "br", [],
                %{
                  tag_name: "br",
                  void?: true,
                  self_closing?: false,
                  line: 3,
                  column: 10,
                  inner_location: {3, 14}
                }},
               {:text, "\n", %{line_end: 4, column_end: 1}}
             ]
    end

    test "as self-closing tag" do
      assert tokens!("""
             <script src="foo.js" /><br>
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
                  self_closing?: true,
                  line: 1,
                  column: 1,
                  inner_location: {1, 24}
                }},
               {:htag, "br", [],
                %{
                  tag_name: "br",
                  void?: true,
                  self_closing?: false,
                  line: 1,
                  column: 24,
                  inner_location: {1, 28}
                }},
               {:text, "\n", %{line_end: 2, column_end: 1}}
             ]
    end
  end

  describe "remote component" do
    test "as paired tags" do
      assert tokens!("""
             <Components.modal on_cancel={navigate(~p"/posts")}>
               This is another modal.
             </Components.modal>
             """) == [
               {
                 :remote_component,
                 "Components.modal",
                 [
                   {"on_cancel", {:expr, "navigate(~p\"/posts\")", %{line: 1, column: 30}},
                    %{line: 1, column: 19}}
                 ],
                 %{
                   tag_name: "Components.modal",
                   void?: false,
                   self_closing?: false,
                   line: 1,
                   column: 1,
                   inner_location: {1, 52}
                 }
               },
               {:text, "\n  This is another modal.\n", %{line_end: 3, column_end: 1}},
               {:close, :remote_component, "Components.modal",
                %{
                  tag_name: "Components.modal",
                  void?: false,
                  line: 3,
                  column: 1,
                  inner_location: {3, 1}
                }},
               {:text, "\n", %{line_end: 4, column_end: 1}}
             ]
    end

    test "as self-closing tag" do
      assert tokens!("""
             <Components.flash kind={:info} flash={@flash} />
             """) == [
               {
                 :remote_component,
                 "Components.flash",
                 [
                   {"kind", {:expr, ":info", %{line: 1, column: 25}}, %{line: 1, column: 19}},
                   {"flash", {:expr, "@flash", %{column: 39, line: 1}}, %{line: 1, column: 32}}
                 ],
                 %{
                   tag_name: "Components.flash",
                   void?: false,
                   self_closing?: true,
                   line: 1,
                   column: 1,
                   inner_location: {1, 49}
                 }
               },
               {:text, "\n", %{column_end: 1, line_end: 2}}
             ]
    end
  end

  describe "local component" do
    test "as paired tags" do
      assert tokens!("""
             <.link href="/">Regular anchor link</.link>
             """) == [
               {:local_component, "link",
                [{"href", {:string, "/", %{delimiter: ?"}}, %{line: 1, column: 8}}],
                %{
                  tag_name: ".link",
                  void?: false,
                  self_closing?: false,
                  line: 1,
                  column: 1,
                  inner_location: {1, 17}
                }},
               {:text, "Regular anchor link", %{line_end: 1, column_end: 36}},
               {:close, :local_component, "link",
                %{
                  tag_name: ".link",
                  void?: false,
                  line: 1,
                  column: 36,
                  inner_location: {1, 36}
                }},
               {:text, "\n", %{line_end: 2, column_end: 1}}
             ]
    end

    test "as self-closing tag" do
      assert tokens!("""
             <.inspect module={ExampleModule} type="recursive" />
             """) == [
               {:local_component, "inspect",
                [
                  {"module", {:expr, "ExampleModule", %{line: 1, column: 19}},
                   %{line: 1, column: 11}},
                  {"type", {:string, "recursive", %{delimiter: ?"}}, %{line: 1, column: 34}}
                ],
                %{
                  tag_name: ".inspect",
                  void?: false,
                  self_closing?: true,
                  line: 1,
                  column: 1,
                  inner_location: {1, 53}
                }},
               {:text, "\n", %{line_end: 2, column_end: 1}}
             ]
    end
  end

  describe "slot" do
    test "as paired tags" do
      assert tokens!("""
             <:item to="/">item 1</:item>
             """) == [
               {:slot, "item",
                [
                  {"to", {:string, "/", %{delimiter: ?"}}, %{line: 1, column: 8}}
                ],
                %{
                  tag_name: ":item",
                  void?: false,
                  self_closing?: false,
                  line: 1,
                  column: 1,
                  inner_location: {1, 15}
                }},
               {:text, "item 1", %{line_end: 1, column_end: 21}},
               {:close, :slot, "item",
                %{
                  tag_name: ":item",
                  void?: false,
                  line: 1,
                  column: 21,
                  inner_location: {1, 21}
                }},
               {:text, "\n", %{line_end: 2, column_end: 1}}
             ]
    end

    test "as self-closing tag" do
      assert tokens!("""
             <:item to="/" />
             """) == [
               {:slot, "item",
                [
                  {"to", {:string, "/", %{delimiter: ?"}}, %{line: 1, column: 8}}
                ],
                %{
                  tag_name: ":item",
                  void?: false,
                  self_closing?: true,
                  line: 1,
                  column: 1,
                  inner_location: {1, 17}
                }},
               {:text, "\n", %{line_end: 2, column_end: 1}}
             ]
    end
  end

  test "mixing text and tags" do
    assert tokens!("""
           text before
           <div>
             text
           </div>
           text after
           """) == [
             {:text, "text before\n", %{line_end: 2, column_end: 1}},
             {:htag, "div", [],
              %{
                tag_name: "div",
                void?: false,
                self_closing?: false,
                line: 2,
                column: 1,
                inner_location: {2, 6}
              }},
             {:text, "\n  text\n",
              %{
                line_end: 4,
                column_end: 1
              }},
             {:close, :htag, "div",
              %{
                tag_name: "div",
                void?: false,
                line: 4,
                column: 1,
                inner_location: {4, 1}
              }},
             {:text, "\ntext after\n", %{line_end: 6, column_end: 1}}
           ]
  end
end
