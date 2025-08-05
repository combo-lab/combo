defmodule Combo.Template.CEExEngine.CompilerTest do
  use ExUnit.Case, async: true

  alias Combo.SafeHTML

  use Combo.Template.CEExEngine
  alias Combo.Template.CEExEngine.Compiler
  alias Combo.Template.CEExEngine.Tokenizer.ParseError

  # Helpers

  defmacrop compile_string(source) do
    opts = [caller: __CALLER__, file: __ENV__.file]
    Compiler.compile_string(source, opts)
  end

  defp eval_string(source, assigns, opts) do
    {env, opts} = Keyword.pop(opts, :env, __ENV__)
    opts = Keyword.merge([caller: env, file: env.file], opts)
    compiled = Compiler.compile_string(source, opts)
    {result, _} = Code.eval_quoted(compiled, [assigns: assigns], env)
    result
  end

  defp render(source, assigns \\ %{}, opts \\ []) do
    source
    |> eval_string(assigns, opts)
    |> SafeHTML.to_iodata()
    |> IO.iodata_to_binary()
  end

  defmacrop render_compiled(source) do
    opts = [
      caller: __CALLER__,
      file: __ENV__.file
    ]

    compiled = Compiler.compile_string(source, opts)

    quote do
      unquote(compiled)
      |> SafeHTML.to_iodata()
      |> IO.iodata_to_binary()
    end
  end

  # Tests

  def do_block(do: {:safe, _} = safe), do: safe

  def assigns_component(assigns) do
    compile_string("{inspect(Map.delete(assigns, :__changed__))}")
  end

  def textarea(assigns) do
    assigns = assign(assigns, :extra_assigns, assigns_to_attrs(assigns, []))
    compile_string("<textarea {@extra_assigns}><%= render_slot(@inner_block) %></textarea>")
  end

  def remote_component(assigns) do
    compile_string("REMOTE COMPONENT: Value: {@value}")
  end

  def remote_component_with_inner_block(assigns) do
    compile_string("REMOTE COMPONENT: Value: {@value}, Content: {render_slot(@inner_block)}")
  end

  def remote_component_with_inner_block_args(assigns) do
    compile_string("""
    REMOTE COMPONENT WITH ARGS: Value: {@value}
    {render_slot(@inner_block, %{
      upcase: String.upcase(@value),
      downcase: String.downcase(@value)
    })}
    """)
  end

  defp local_component(assigns) do
    compile_string("LOCAL COMPONENT: Value: {@value}")
  end

  defp local_component_with_inner_block(assigns) do
    compile_string("LOCAL COMPONENT: Value: {@value}, Content: {render_slot(@inner_block)}")
  end

  defp local_component_with_inner_block_args(assigns) do
    compile_string("""
    LOCAL COMPONENT WITH ARGS: Value: {@value}
    {render_slot(@inner_block, %{
      upcase: String.upcase(@value),
      downcase: String.downcase(@value)
    })}
    """)
  end

  describe "basic rendering" do
    test "text - static" do
      assert render("Hello world!") == "Hello world!"
    end

    test "text - dynamic content enclosed by EEx notation" do
      assert render(~S|Hello <%= "world!" %>|) == "Hello world!"
    end

    test "HTML elements - static" do
      assert render("<p>para.</p>") == "<p>para.</p>"
      assert render("<unknown>para.</unknown>") == "<unknown>para.</unknown>"
    end

    test "HTML elements - static - void" do
      assert render("<br>") == "<br>"
      assert render("<br />") == "<br>"
    end

    test "HTML elements - static - void with attributes" do
      assert render("<br>") == "<br>"
      assert render("<br />") == "<br>"
      assert render(~S|<br name="value">|) == ~S|<br name="value">|
      assert render(~S|<br name="value" />|) == ~S|<br name="value">|
    end

    test "HTML elements - static - self closed" do
      assert render("<p />") == "<p></p>"
      assert render("<unknown />") == "<unknown></unknown>"
    end

    test "HTML elements - static - self closed with attributes" do
      assert render(~S|<p name="value" />|) == ~S|<p name="value"></p>|
      assert render(~S|<unknown name="value" />|) == ~S|<unknown name="value"></unknown>|
    end

    test "HTML elements - dynamic content enclosed by EEx notation" do
      template = ~S|<div><%= "<p>para.</p>" %></div>|
      assert render(template) == "<div>&lt;p&gt;para.&lt;/p&gt;</div>"

      template = ~S|<div><%= {:safe, "<p>para.</p>"} %></div>|
      assert render(template) == "<div><p>para.</p></div>"
    end

    test "HTML elements - dynamic content enclosed by curly braces" do
      template = ~S|<div>{"<p>para.</p>"}</div>|
      assert render(template) == "<div>&lt;p&gt;para.&lt;/p&gt;</div>"

      template = ~S|<div>{{:safe, "<p>para.</p>"}}</div>|
      assert render(template) == "<div><p>para.</p></div>"
    end

    test "boolean attributes - static" do
      assert render("Hello <p hidden>world!</p>") == "Hello <p hidden>world!</p>"
    end

    test "string attributes - static" do
      assert render(~S|Hello <p name="value">world!</p>|) == ~S|Hello <p name="value">world!</p>|
    end

    test "string attributes - static - leave the quotation marks unchanged" do
      assert render(~S|Hello <p name="value">world!</p>|) == ~S|Hello <p name="value">world!</p>|
      assert render(~S|Hello <p name='value'>world!</p>|) == ~S|Hello <p name='value'>world!</p>|
    end

    test "string attributes - static - leave special chars unchanged" do
      assert render(~S|<p name="1 < 2">para.</p>|) == ~S|<p name="1 < 2">para.</p>|
      assert render(~S|<p name="1 < 2"/>|) == ~S|<p name="1 < 2"></p>|
    end

    test "string attributes - dynamic" do
      template = ~S|<p name={"string"}>para.</p>|
      assert render(template) == ~S|<p name="string">para.</p>|

      template = ~S|<p name={1024}>para.</p>|
      assert render(template) == ~S|<p name="1024">para.</p>|
    end

    test "string attributes - dynamic - handle expression with curly braces" do
      template = ~S|<p name={elem({"string"}, 0)}>para.</p>|
      assert render(template) == ~S|<p name="string">para.</p>|
    end

    test "string attributes - dynamic - escape special chars" do
      template = ~S|<p name={"<value>"}>para.</p>|
      assert render(template) == ~S|<p name="&lt;value&gt;">para.</p>|

      template = ~S|<p name={"1 < 2"}>para.</p>|
      assert render(template) == ~S|<p name="1 &lt; 2">para.</p>|
    end

    test "root attributes" do
      template = ~S|<p {assigns.attrs}>para.</p>|

      assert render(template, %{attrs: [string: "string", number: 1024]}) ==
               ~S|<p string="string" number="1024">para.</p>|
    end

    test "root attributes - leave underscores of attribute names unchanged" do
      template = ~S|<p {assigns.attrs}>para.</p>|

      assert render(template, %{attrs: [long_string: "string", big_number: 1024]}) ==
               ~S|<p long_string="string" big_number="1024">para.</p>|
    end

    test "root attributes - keep the order of attributes" do
      template = ~S|<div {assigns.attrs1} sd1={1} s1="1" {assigns.attrs2} s2="2" sd2={2} />|

      assert render(template, %{attrs1: [d1: "1"], attrs2: [d2: "2"]}) ==
               ~S|<div d1="1" sd1="1" s1="1" d2="2" s2="2" sd2="2"></div>|
    end

    test "do-block - static content in it is treated as safe" do
      template = """
      <%= __MODULE__.do_block do %>
        <p>para.</p>
      <% end %>
      """

      assert render(template) == "\n  <p>para.</p>\n"

      template = """
      <p><%= __MODULE__.do_block do %>para.<% end %></p>
      """

      assert render(template) == "<p>para.</p>"
    end

    test "do-block - dynamic content in it is treated as unsafe" do
      template = """
      <%= __MODULE__.do_block do %>
        <%= "<p>para.</p>" %>
      <% end %>
      """

      assert render(template) == "\n  &lt;p&gt;para.&lt;/p&gt;\n"
    end

    test "assigns support " do
      assert render("<%= assigns[:msg] %>", %{msg: "<hello>"}) == "&lt;hello&gt;"
      assert render("<%= assigns.msg %>", %{msg: "<hello>"}) == "&lt;hello&gt;"
      assert render("<%= Access.get(assigns, :msg) %>", %{msg: "<hello>"}) == "&lt;hello&gt;"
      assert render("<%= assigns[:missing] %>", %{msg: "<hello>"}) == ""
    end

    test "assigns support - @" do
      assert render("<%= @msg %>", %{msg: "<hello>"}) == "&lt;hello&gt;"
    end

    test "assigns support - raises KeyError for missing assigns" do
      assert_raise KeyError, fn ->
        render("<%= @msg %>", %{})
      end
    end
  end

  describe "special HTML elements" do
    test "style" do
      assert render("<style>a = '<a>';<%= :b %> = '<b>';</style>") ==
               "<style>a = '<a>';b = '<b>';</style>"
    end

    test "script" do
      assert render("<script>a = '<a>';<%= :b %> = '<b>';</script>") ==
               "<script>a = '<a>';b = '<b>';</script>"
    end

    test "comment" do
      assert render("Begin<!-- <%= 123 %> -->End") ==
               "Begin<!-- 123 -->End"
    end

    test "comment - raise on missing -->" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:1:6: expected closing `-->` for comment
        |
      1 | Begin<!-- <%= 123 %>
        |      ^\
      """

      assert_raise(ParseError, message, fn ->
        render("Begin<!-- <%= 123 %>")
      end)
    end
  end

  describe "handling attributes" do
    test "attributes" do
      assigns = %{
        true_assign: true,
        false_assign: false,
        nil_assign: nil,
        unsafe: "<foo>",
        safe: {:safe, "<foo>"},
        global: [
          {"key1", "value1"},
          {"key2", "<value2>"},
          {"key3", {:safe, "<value3>"}},
        ]
      }

      template = ~S(<div class={@true_assign} />)
      assert render(template, assigns) == ~S(<div class></div>)

      template = ~S(<div class={@false_assign} />)
      assert render(template, assigns) == ~S(<div></div>)

      template = ~S(<div class={@nil_assign} />)
      assert render(template, assigns) == ~S(<div></div>)

      template = ~S(<div class={@unsafe} />)
      assert render(template, assigns) == ~S(<div class="&lt;foo&gt;"></div>)

      template = ~S(<div class={@safe} />)
      assert render(template, assigns) == ~S(<div class="<foo>"></div>)

      template = ~S(<div {@global} />)

      assert render(template, assigns) ==
               ~S(<div key1="value1" key2="&lt;value2&gt;" key3="<value3>"></div>)
    end
  end

  describe "phx-* attributes" do
    test "phx-no-format for skipping the formatting" do
      assert render("<div phx-no-format>Content</div>") == "<div>Content</div>"
      assert render("<div phx-no-format />") == "<div></div>"

      assigns = %{}

      assert render_compiled("""
             <Combo.Template.CEExEngine.CompilerTest.textarea phx-no-format>
              Content
             </Combo.Template.CEExEngine.CompilerTest.textarea>
             """) == "<textarea>\n Content\n</textarea>"

      assert render_compiled("<.textarea phx-no-format>Content</.textarea>") ==
               "<textarea>Content</textarea>"
    end

    test "phx-no-curly-interpolation for disabling interpolation for content enclosed by curly braces" do
      assert render("""
             <div phx-no-curly-interpolation>{open}<%= :eval %>{close}</div>
             """) == "<div>{open}eval{close}</div>"

      assert render("""
             <div phx-no-curly-interpolation>{open}{<%= :eval %>}{close}</div>
             """) == "<div>{open}{eval}{close}</div>"

      assert render("""
             {:pre}<style phx-no-curly-interpolation>{css}</style>{:post}
             """) == "pre<style>{css}</style>post"

      assert render("""
             <div phx-no-curly-interpolation>{:pre}<style phx-no-curly-interpolation>{css}</style>{:post}</div>
             """) == "<div>{:pre}<style>{css}</style>{:post}</div>"
    end
  end

  describe "tag validations" do
    test "unmatched open/close tags" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:4:1: unmatched closing tag. Expected </div> for <div> at line 2, got: </span>
        |
      1 | <br>
      2 | <div>
      3 |  text
      4 | </span>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <br>
        <div>
         text
        </span>
        """)
      end)
    end

    test "unmatched open/close tags with nested tags" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:6:1: unmatched closing tag. Expected </div> for <div> at line 2, got: </span>
        |
      3 |   <p>
      4 |     text
      5 |   </p>
      6 | </span>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <br>
        <div>
          <p>
            text
          </p>
        </span>
        """)
      end)
    end

    test "unmatched open/close tags with void tags" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:1:16: unmatched closing tag. Expected </div> for <div> at line 1, got: </link> (note <link> is a void tag and cannot have any content)
        |
      1 | <div><link>Text</link></div>
        |                ^\
      """

      assert_raise(ParseError, message, fn ->
        render("<div><link>Text</link></div>")
      end)
    end

    test "invalid remote tag" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:1:1: invalid tag <Foo>
        |
      1 | <Foo foo=\"bar\" />
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <Foo foo="bar" />
        """)
      end)
    end

    test "missing open tag" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:2:3: missing opening tag for </span>
        |
      1 | text
      2 |   </span>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        text
          </span>
        """)
      end)
    end

    test "missing open tag with void tag" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:1:11: missing opening tag for </link> (note <link> is a void tag and cannot have any content)
        |
      1 | <link>Text</link>
        |           ^\
      """

      assert_raise(ParseError, message, fn ->
        render("<link>Text</link>")
      end)
    end

    test "missing closing tag" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:2:1: end of template reached without closing tag for <div>
        |
      1 | <br>
      2 | <div foo={@foo}>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <br>
        <div foo={@foo}>
        """)
      end)

      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:2:3: end of template reached without closing tag for <span>
        |
      1 | text
      2 |   <span foo={@foo}>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        text
          <span foo={@foo}>
            text
        """)
      end)
    end

    test "invalid tag name" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:2:3: invalid tag <Oops>
        |
      1 | <br>
      2 |   <Oops foo={@foo}>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <br>
          <Oops foo={@foo}>
            Bar
          </Oops>
        """)
      end)
    end

    test "invalid tag" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:1:10: expected closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it using `&lbrace;` or using `<%= "{" %>`
        |
      1 | <div foo={<%= @foo %>}>bar</div>
        |          ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <div foo={<%= @foo %>}>bar</div>
        """)
      end)

      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:2:3: expected closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it using `&lbrace;` or using `<%= "{" %>`
        |
      1 | <div foo=
      2 |   {<%= @foo %>}>bar</div>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        render(
          """
          <div foo=
            {<%= @foo %>}>bar</div>
          """,
          %{},
          indentation: 0
        )
      end)

      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:2:6: expected closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it using `&lbrace;` or using `<%= "{" %>`
        |
      1 |    <div foo=
      2 |      {<%= @foo %>}>bar</div>
        |      ^\
      """

      assert_raise(ParseError, message, fn ->
        render(
          """
          <div foo=
            {<%= @foo %>}>bar</div>

          """,
          %{},
          indentation: 3
        )
      end)
    end
  end

  describe "more EEx functionalities" do
    test "supports non-output expressions" do
      template = """
      <% content = @content %>
      <%= content %>
      """

      assert render(template, %{content: "<p>para.</p>"}) == "\n&lt;p&gt;para.&lt;/p&gt;"
    end

    test "supports mixed non-output expressions" do
      template = """
      prea
      <% @content %>
      posta
      <%= @content %>
      preb
      <% @content %>
      middleb
      <% @content %>
      postb
      """

      assert render(template, %{content: "<p>para.</p>"}) ==
               "prea\n\nposta\n&lt;p&gt;para.&lt;/p&gt;\npreb\n\nmiddleb\n\npostb\n"
    end
  end

  # describe "debug annotations" do
  #   alias Combo.Template.CEExEngine.Compiler.DebugAnnotation
  #   import Combo.Template.CEExEngine.Compiler.DebugAnnotation

  #   test "without root tag" do
  #     assigns = %{}

  #     assert render_compiled("<DebugAnnotation.remote value='1'/>") ==
  #              "<!-- <Combo.Template.CEExEngine.Compiler.DebugAnnotation.remote> test/support/phoenix/template/html_engine/compiler/debug_annotation.exs:7 () -->REMOTE COMPONENT: Value: 1<!-- </Combo.Template.CEExEngine.Compiler.DebugAnnotation.remote> -->"

  #     assert render_compiled("<.local value='1'/>") ==
  #              "<!-- <Combo.Template.CEExEngine.Compiler.DebugAnnotation.local> test/support/phoenix/template/html_engine/compiler/debug_annotation.exs:15 () -->LOCAL COMPONENT: Value: 1<!-- </Combo.Template.CEExEngine.Compiler.DebugAnnotation.local> -->"
  #   end

  #   test "with root tag" do
  #     assigns = %{}

  #     assert render_compiled("<DebugAnnotation.remote_with_root value='1'/>") ==
  #              "<!-- <Combo.Template.CEExEngine.Compiler.DebugAnnotation.remote_with_root> test/support/phoenix/template/html_engine/compiler/debug_annotation.exs:11 () --><div>REMOTE COMPONENT: Value: 1</div><!-- </Combo.Template.CEExEngine.Compiler.DebugAnnotation.remote_with_root> -->"

  #     assert render_compiled("<.local_with_root value='1'/>") ==
  #              "<!-- <Combo.Template.CEExEngine.Compiler.DebugAnnotation.local_with_root> test/support/phoenix/template/html_engine/compiler/debug_annotation.exs:19 () --><div>LOCAL COMPONENT: Value: 1</div><!-- </Combo.Template.CEExEngine.Compiler.DebugAnnotation.local_with_root> -->"
  #   end

  #   test "nesting" do
  #     assigns = %{}

  #     assert render_compiled("<DebugAnnotation.nested value='1'/>") ==
  #              "<!-- <Combo.Template.CEExEngine.Compiler.DebugAnnotation.nested> test/support/phoenix/template/html_engine/compiler/debug_annotation.exs:23 () --><div>\n  <!-- @caller test/support/phoenix/template/html_engine/compiler/debug_annotation.exs:25 () --><!-- <Combo.Template.CEExEngine.Compiler.DebugAnnotation.local_with_root> test/support/phoenix/template/html_engine/compiler/debug_annotation.exs:19 () --><div>LOCAL COMPONENT: Value: local</div><!-- </Combo.Template.CEExEngine.Compiler.DebugAnnotation.local_with_root> -->\n</div><!-- </Combo.Template.CEExEngine.Compiler.DebugAnnotation.nested> -->"
  #   end
  # end

  describe "handle function components" do
    test "remote call (self close)" do
      assigns = %{}

      assert render_compiled(
               "<Combo.Template.CEExEngine.CompilerTest.remote_component value='1'/>"
             ) ==
               "REMOTE COMPONENT: Value: 1"
    end

    test "remote call from alias (self close)" do
      alias Combo.Template.CEExEngine.CompilerTest
      assigns = %{}

      assert render_compiled("<CompilerTest.remote_component value='1'/>") ==
               "REMOTE COMPONENT: Value: 1"
    end

    test "remote call with inner content" do
      assigns = %{}

      assert render_compiled("""
             <Combo.Template.CEExEngine.CompilerTest.remote_component_with_inner_block value='1'>
               The inner content
             </Combo.Template.CEExEngine.CompilerTest.remote_component_with_inner_block>
             """) == "REMOTE COMPONENT: Value: 1, Content: \n  The inner content\n"
    end

    test "remote call with :let" do
      expected = """
      LOCAL COMPONENT WITH ARGS: Value: aBcD

        Upcase: ABCD
        Downcase: abcd
      """

      assigns = %{}

      assert render_compiled("""
             <.local_component_with_inner_block_args
               value="aBcD"
               :let={%{upcase: upcase, downcase: downcase}}
             >
               Upcase: <%= upcase %>
               Downcase: <%= downcase %>
             </.local_component_with_inner_block_args>
             """) =~ expected
    end

    test "remote call with inner content with args" do
      expected = """
      REMOTE COMPONENT WITH ARGS: Value: aBcD

        Upcase: ABCD
        Downcase: abcd
      """

      assigns = %{}

      assert render_compiled("""
             <Combo.Template.CEExEngine.CompilerTest.remote_component_with_inner_block_args
               value="aBcD"
               :let={%{upcase: upcase, downcase: downcase}}
             >
               Upcase: <%= upcase %>
               Downcase: <%= downcase %>
             </Combo.Template.CEExEngine.CompilerTest.remote_component_with_inner_block_args>
             """) =~ expected
    end

    test "raise on remote call with inner content passing non-matching args" do
      message = ~r"""
      cannot match arguments sent from render_slot/2 against the pattern in :let.

      Expected a value matching `%{wrong: _}`, got: %{downcase: "abcd", upcase: "ABCD"}\
      """

      assigns = %{}

      assert_raise(RuntimeError, message, fn ->
        render_compiled("""
        <Combo.Template.CEExEngine.CompilerTest.remote_component_with_inner_block_args
          {[value: "aBcD"]}
          :let={%{wrong: _}}
        >
          ...
        </Combo.Template.CEExEngine.CompilerTest.remote_component_with_inner_block_args>
        """)
      end)
    end

    test "raise on remote call passing args to self close components" do
      message = ~r".exs:2:68: cannot use :let on a remote component without inner content"

      assert_raise(ParseError, message, fn ->
        render("""
        <br>
        <Combo.Template.CEExEngine.CompilerTest.remote_component value='1' :let={var}/>
        """)
      end)
    end

    test "local call (self close)" do
      assigns = %{}

      assert render_compiled("<.local_component value='1'/>") ==
               "LOCAL COMPONENT: Value: 1"
    end

    test "local call with inner content" do
      assigns = %{}

      assert render_compiled("""
             <.local_component_with_inner_block value='1'>
               The inner content
             </.local_component_with_inner_block>
             """) == "LOCAL COMPONENT: Value: 1, Content: \n  The inner content\n"
    end

    test "local call with inner content with args" do
      expected = """
      LOCAL COMPONENT WITH ARGS: Value: aBcD

        Upcase: ABCD
        Downcase: abcd
      """

      assigns = %{}

      assert render_compiled("""
             <.local_component_with_inner_block_args
               value="aBcD"
               :let={%{upcase: upcase, downcase: downcase}}
             >
               Upcase: <%= upcase %>
               Downcase: <%= downcase %>
             </.local_component_with_inner_block_args>
             """) =~ expected

      assert render_compiled("""
             <.local_component_with_inner_block_args
               {[value: "aBcD"]}
               :let={%{upcase: upcase, downcase: downcase}}
             >
               Upcase: <%= upcase %>
               Downcase: <%= downcase %>
             </.local_component_with_inner_block_args>
             """) =~ expected
    end

    test "raise on local call with inner content passing non-matching args" do
      message = ~r"""
      cannot match arguments sent from render_slot/2 against the pattern in :let.

      Expected a value matching `%{wrong: _}`, got: %{downcase: "abcd", upcase: "ABCD"}\
      """

      assigns = %{}

      assert_raise(RuntimeError, message, fn ->
        render_compiled("""
        <.local_component_with_inner_block_args
          {[value: "aBcD"]}
          :let={%{wrong: _}}
        >
          ...
        </.local_component_with_inner_block_args>
        """)
      end)
    end

    test "raise on local call passing args to self close components" do
      message = ~r".exs:2:29: cannot use :let on a local component without inner content"

      assert_raise(ParseError, message, fn ->
        render("""
        <br>
        <.local_component value='1' :let={var}/>
        """)
      end)
    end

    test "raise on duplicated :let" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:4:3: cannot define multiple :let attributes. Another :let has already been defined at line 3
        |
      1 | <br>
      2 | <Combo.Template.CEExEngine.CompilerTest.remote_component value='1'
      3 |   :let={var1}
      4 |   :let={var2}
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <br>
        <Combo.Template.CEExEngine.CompilerTest.remote_component value='1'
          :let={var1}
          :let={var2}
        ></Combo.Template.CEExEngine.CompilerTest.remote_component>
        """)
      end)

      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:4:3: cannot define multiple :let attributes. Another :let has already been defined at line 3
        |
      1 | <br>
      2 | <.local_component value='1'
      3 |   :let={var1}
      4 |   :let={var2}
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <br>
        <.local_component value='1'
          :let={var1}
          :let={var2}
        ></.local_component>
        """)
      end)
    end

    test "invalid :let expr" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:2:68: :let must be a pattern between {...} in remote component: Combo.Template.CEExEngine.CompilerTest.remote_component
        |
      1 | <br>
      2 | <Combo.Template.CEExEngine.CompilerTest.remote_component value='1' :let=\"1\"
        |                                                                    ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <br>
        <Combo.Template.CEExEngine.CompilerTest.remote_component value='1' :let="1"
        />
        """)
      end)

      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:2:29: :let must be a pattern between {...} in local component: local_component
        |
      1 | <br>
      2 | <.local_component value='1' :let=\"1\"
        |                             ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <br>
        <.local_component value='1' :let="1"
        />
        """)
      end)
    end

    test "raise with invalid special attr" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:2:29: unsupported attribute :bar in local component: local_component
        |
      1 | <br>
      2 | <.local_component value='1' :bar=\"1\"}
        |                             ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <br>
        <.local_component value='1' :bar="1"}
        />
        """)
      end)
    end

    test "raise on unclosed local call" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:1:1: end of template reached without closing tag for <.local_component>
        |
      1 | <.local_component value='1' :let={var}>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <.local_component value='1' :let={var}>
        """)
      end)

      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:2:3: end of do-block reached without closing tag for <.local_component>
        |
      1 | <%= if true do %>
      2 |   <.local_component value='1' :let={var}>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <%= if true do %>
          <.local_component value='1' :let={var}>
        <% end %>
        """)
      end)
    end

    test "when tag is unclosed" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:2:1: end of template reached without closing tag for <div>
        |
      1 | <div>Foo</div>
      2 | <div>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <div>Foo</div>
        <div>
        <div>Bar</div>
        """)
      end)
    end

    test "when syntax error on HTML attributes" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:2:9: invalid attribute value after `=`. Expected either a value between quotes (such as \"value\" or 'value') or an Elixir expression between curly braces (such as `{expr}`)
        |
      1 | <div>Bar</div>
      2 | <div id=>Foo</div>
        |         ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <div>Bar</div>
        <div id=>Foo</div>
        """)
      end)
    end

    test "empty attributes" do
      assigns = %{}
      assert render_compiled("<.assigns_component />") == "%{}"
    end

    test "dynamic attributes" do
      assigns = %{attrs: [name: "1", phone: true]}

      assert render_compiled("<.assigns_component {@attrs} />") ==
               "%{name: &quot;1&quot;, phone: true}"
    end

    test "sorts attributes by group: static + dynamic" do
      assigns = %{attrs1: [d1: "1"], attrs2: [d2: "2", d3: "3"]}

      assert render_compiled(
               "<.assigns_component d1=\"one\" {@attrs1} d=\"middle\" {@attrs2} d2=\"two\" />"
             ) ==
               "%{d: &quot;middle&quot;, d1: &quot;one&quot;, d2: &quot;two&quot;, d3: &quot;3&quot;}"
    end
  end

  describe "named slots" do
    def component_with_single_slot(assigns) do
      compile_string("""
      BEFORE SLOT
      <%= render_slot(@sample) %>
      AFTER SLOT
      """)
    end

    def component_with_slots(assigns) do
      compile_string("""
      BEFORE HEADER
      <%= render_slot(@header) %>
      TEXT
      <%= render_slot(@footer) %>
      AFTER FOOTER
      """)
    end

    def component_with_slots_and_default(assigns) do
      compile_string("""
      BEFORE HEADER
      <%= render_slot(@header) %>
      TEXT:<%= render_slot(@inner_block) %>:TEXT
      <%= render_slot(@footer) %>
      AFTER FOOTER
      """)
    end

    def component_with_slots_and_args(assigns) do
      compile_string("""
      BEFORE SLOT
      <%= render_slot(@sample, 1) %>
      AFTER SLOT
      """)
    end

    def component_with_slot_attrs(assigns) do
      compile_string("""
      <%= for entry <- @sample do %>
      <%= entry.a %>
      <%= render_slot(entry) %>
      <%= entry.b %>
      <% end %>
      """)
    end

    def component_with_multiple_slots_entries(assigns) do
      compile_string("""
      <%= for entry <- @sample do %>
        <%= entry.id %>: <%= render_slot(entry, %{}) %>
      <% end %>
      """)
    end

    def component_with_self_close_slots(assigns) do
      compile_string("""
      <%= for entry <- @sample do %>
        <%= entry.id %>
      <% end %>
      """)
    end

    def render_slot_name(assigns) do
      compile_string("<%= for entry <- @sample do %>[<%= entry.__slot__ %>]<% end %>")
    end

    def render_inner_block_slot_name(assigns) do
      compile_string("<%= for entry <- @inner_block do %>[<%= entry.__slot__ %>]<% end %>")
    end

    test "single slot" do
      assigns = %{}

      expected = """
      COMPONENT WITH SLOTS:
      BEFORE SLOT

          The sample slot
        \

      AFTER SLOT
      """

      assert render_compiled("""
             COMPONENT WITH SLOTS:
             <.component_with_single_slot>
               <:sample>
                 The sample slot
               </:sample>
             </.component_with_single_slot>
             """) == expected

      assert render_compiled("""
             COMPONENT WITH SLOTS:
             <Combo.Template.CEExEngine.CompilerTest.component_with_single_slot>
               <:sample>
                 The sample slot
               </:sample>
             </Combo.Template.CEExEngine.CompilerTest.component_with_single_slot>
             """) == expected
    end

    test "raise when calling render_slot/2 on a slot without inner content" do
      message = ~r"attempted to render slot <:sample> but the slot has no inner content"

      assigns = %{}

      assert_raise(RuntimeError, message, fn ->
        render_compiled("""
        <.component_with_single_slot>
          <:sample/>
        </.component_with_single_slot>
        """)
      end)

      assert_raise(RuntimeError, message, fn ->
        render_compiled("""
        <.component_with_single_slot>
          <:sample/>
          <:sample/>
        </.component_with_single_slot>
        """)
      end)
    end

    test "multiple slot entries rendered by a single rende_slot/2 call" do
      assigns = %{}

      expected = """
      COMPONENT WITH SLOTS:
      BEFORE SLOT

          entry 1
        \

          entry 2
        \

      AFTER SLOT
      """

      assert render_compiled("""
             COMPONENT WITH SLOTS:
             <.component_with_single_slot>
               <:sample>
                 entry 1
               </:sample>
               <:sample>
                 entry 2
               </:sample>
             </.component_with_single_slot>
             """) == expected

      assert render_compiled("""
             COMPONENT WITH SLOTS:
             <Combo.Template.CEExEngine.CompilerTest.component_with_single_slot>
               <:sample>
                 entry 1
               </:sample>
               <:sample>
                 entry 2
               </:sample>
             </Combo.Template.CEExEngine.CompilerTest.component_with_single_slot>
             """) == expected
    end

    test "multiple slot entries handled by an explicit for comprehension" do
      assigns = %{}

      expected = """

        1: one

        2: two
      """

      assert render_compiled("""
             <.component_with_multiple_slots_entries>
               <:sample id="1">one</:sample>
               <:sample id="2">two</:sample>
             </.component_with_multiple_slots_entries>
             """) == expected

      assert render_compiled("""
             <Combo.Template.CEExEngine.CompilerTest.component_with_multiple_slots_entries>
               <:sample id="1">one</:sample>
               <:sample id="2">two</:sample>
             </Combo.Template.CEExEngine.CompilerTest.component_with_multiple_slots_entries>
             """) == expected
    end

    test "slot attrs" do
      assigns = %{a: "A"}
      expected = "\nA\n and \nB\n"

      assert render_compiled("""
             <.component_with_slot_attrs>
               <:sample a={@a} b="B"> and </:sample>
             </.component_with_slot_attrs>
             """) == expected

      assert render_compiled("""
             <Combo.Template.CEExEngine.CompilerTest.component_with_slot_attrs>
               <:sample a={@a} b="B"> and </:sample>
             </Combo.Template.CEExEngine.CompilerTest.component_with_slot_attrs>
             """) == expected
    end

    test "multiple slots" do
      assigns = %{}

      expected = """
      BEFORE COMPONENT
      BEFORE HEADER

          The header content
        \

      TEXT

          The footer content
        \

      AFTER FOOTER

      AFTER COMPONENT
      """

      assert render_compiled("""
             BEFORE COMPONENT
             <.component_with_slots>
               <:header>
                 The header content
               </:header>
               <:footer>
                 The footer content
               </:footer>
             </.component_with_slots>
             AFTER COMPONENT
             """) == expected

      assert render_compiled("""
             BEFORE COMPONENT
             <Combo.Template.CEExEngine.CompilerTest.component_with_slots>
               <:header>
                 The header content
               </:header>
               <:footer>
                 The footer content
               </:footer>
             </Combo.Template.CEExEngine.CompilerTest.component_with_slots>
             AFTER COMPONENT
             """) == expected
    end

    test "multiple slots with default" do
      assigns = %{middle: "middle"}

      expected = """
      BEFORE COMPONENT
      BEFORE HEADER

          The header content
        \

      TEXT:
        top
        foo middle bar
        bot
      :TEXT

          The footer content
        \

      AFTER FOOTER

      AFTER COMPONENT
      """

      assert render_compiled("""
             BEFORE COMPONENT
             <.component_with_slots_and_default>
               top
               <:header>
                 The header content
               </:header>
               foo <%= @middle %> bar
               <:footer>
                 The footer content
               </:footer>
               bot
             </.component_with_slots_and_default>
             AFTER COMPONENT
             """) == expected

      assert render_compiled("""
             BEFORE COMPONENT
             <Combo.Template.CEExEngine.CompilerTest.component_with_slots_and_default>
               top
               <:header>
                 The header content
               </:header>
               foo <%= @middle %> bar
               <:footer>
                 The footer content
               </:footer>
               bot
             </Combo.Template.CEExEngine.CompilerTest.component_with_slots_and_default>
             AFTER COMPONENT
             """) == expected
    end

    test "slots with args" do
      assigns = %{}

      expected = """
      COMPONENT WITH SLOTS:
      BEFORE SLOT

          The sample slot
          Arg: 1
        \

      AFTER SLOT
      """

      assert render_compiled("""
             COMPONENT WITH SLOTS:
             <.component_with_slots_and_args>
               <:sample :let={arg}>
                 The sample slot
                 Arg: <%= arg %>
               </:sample>
             </.component_with_slots_and_args>
             """) == expected

      assert render_compiled("""
             COMPONENT WITH SLOTS:
             <Combo.Template.CEExEngine.CompilerTest.component_with_slots_and_args>
               <:sample :let={arg}>
                 The sample slot
                 Arg: <%= arg %>
               </:sample>
             </Combo.Template.CEExEngine.CompilerTest.component_with_slots_and_args>
             """) == expected
    end

    test "nested calls with slots" do
      assigns = %{}

      expected = """
      BEFORE SLOT

         The outer slot
          BEFORE SLOT

            The inner slot
            \

      AFTER SLOT

        \

      AFTER SLOT
      """

      assert render_compiled("""
             <Combo.Template.CEExEngine.CompilerTest.component_with_single_slot>
               <:sample>
                The outer slot
                 <.component_with_single_slot>
                   <:sample>
                   The inner slot
                   </:sample>
                 </.component_with_single_slot>
               </:sample>
             </Combo.Template.CEExEngine.CompilerTest.component_with_single_slot>
             """) == expected

      assert render_compiled("""
             <.component_with_single_slot>
               <:sample>
                The outer slot
                 <.component_with_single_slot>
                   <:sample>
                   The inner slot
                   </:sample>
                 </.component_with_single_slot>
               </:sample>
             </.component_with_single_slot>
             """) == expected
    end

    test "self close slots" do
      assigns = %{}

      expected = """

        1

        2
      """

      assert render_compiled("""
             <.component_with_self_close_slots>
               <:sample id="1"/>
               <:sample id="2"/>
             </.component_with_self_close_slots>
             """) == expected

      assert render_compiled("""
             <Combo.Template.CEExEngine.CompilerTest.component_with_self_close_slots>
               <:sample id="1"/>
               <:sample id="2"/>
             </Combo.Template.CEExEngine.CompilerTest.component_with_self_close_slots>
             """) == expected
    end

    test "raise if self close slot uses :let" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:2:19: cannot use :let on a slot without inner content
        |
      1 | <.component_with_self_close_slots>
      2 |   <:sample id="1" :let={var}/>
        |                   ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <.component_with_self_close_slots>
          <:sample id="1" :let={var}/>
        </.component_with_self_close_slots>
        """)
      end)
    end

    test "store the slot name in __slot__" do
      assigns = %{}

      assert render_compiled("""
             <.render_slot_name>
               <:sample>
                 The sample slot
               </:sample>
             </.render_slot_name>
             """) == "[sample]"

      assert render_compiled("""
             <.render_slot_name>
               <:sample/>
               <:sample/>
             </.render_slot_name>
             """) == "[sample][sample]"
    end

    test "store the inner_block slot name in __slot__" do
      assigns = %{}

      assert render_compiled("""
             <.render_inner_block_slot_name>
                 The content
             </.render_inner_block_slot_name>
             """) == "[inner_block]"
    end

    test "raise if the slot entry is not a direct child of a component" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:2:3: invalid slot entry <:sample>. A slot entry must be a direct child of a component
        |
      1 | <div>
      2 |   <:sample>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <div>
          <:sample>
            Content
          </:sample>
        </div>
        """)
      end)

      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:3:3: invalid slot entry <:sample>. A slot entry must be a direct child of a component
        |
      1 | <Combo.Template.CEExEngine.CompilerTest.component_with_single_slot>
      2 | <%= if true do %>
      3 |   <:sample>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <Combo.Template.CEExEngine.CompilerTest.component_with_single_slot>
        <%= if true do %>
          <:sample>
            <p>Content</p>
          </:sample>
        <% end %>
        </Combo.Template.CEExEngine.CompilerTest.component_with_single_slot>
        """)
      end)

      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:3:5: invalid slot entry <:footer>. A slot entry must be a direct child of a component
        |
      1 | <.mydiv>
      2 |   <:sample>
      3 |     <:footer>
        |     ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <.mydiv>
          <:sample>
            <:footer>
              Content
            </:footer>
          </:sample>
        </.mydiv>
        """)
      end)

      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:1:1: invalid slot entry <:sample>. A slot entry must be a direct child of a component
        |
      1 | <:sample>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <:sample>
          Content
        </:sample>
        """)
      end)

      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:1:1: invalid slot entry <:sample>. A slot entry must be a direct child of a component
        |
      1 | <:sample>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <:sample>
          <p>Content</p>
        </:sample>
        """)
      end)
    end
  end

  describe "html validations" do
    test "raise on unsupported special attrs" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:1:6: unsupported attribute :let in tag: div
        |
      1 | <div :let={@user}>Content</div>
        |      ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <div :let={@user}>Content</div>
        """)
      end)

      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:1:6: unsupported attribute :foo in tag: div
        |
      1 | <div :foo=\"something\" />
        |      ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <div :foo="something" />
        """)
      end)
    end
  end

  describe "handle errors in expressions" do
    test "inside attribute values" do
      exception =
        assert_raise SyntaxError, fn ->
          opts = [line: 10, indentation: 8]

          render(
            """
            text
            <%= "interpolation" %>
            <div class={[,]}/>
            """,
            [],
            opts
          )
        end

      message = Exception.message(exception)
      assert message =~ "test/phoenix/template/ceex_engine/compiler_test.exs:12:22:"
      assert message =~ "syntax error before: ','"
    end

    test "inside root attribute value" do
      exception =
        assert_raise SyntaxError, fn ->
          opts = [line: 10, indentation: 8]

          render(
            """
            text
            <%= "interpolation" %>
            <div {[,]}/>
            """,
            [],
            opts
          )
        end

      message = Exception.message(exception)
      assert message =~ "test/phoenix/template/ceex_engine/compiler_test.exs:12:16:"
      assert message =~ "syntax error before: ','"
    end
  end

  describe ":for attr" do
    test "handle :for attr on HTML element" do
      expected = "<div>foo</div><div>bar</div><div>baz</div>"

      assigns = %{items: ["foo", "bar", "baz"]}

      assert render_compiled("""
               <div :for={item <- @items}><%= item %></div>
             """) =~ expected
    end

    test "handle :for attr on self closed HTML element" do
      expected = ~s(<div class="foo"></div><div class="foo"></div><div class="foo"></div>)

      assigns = %{items: ["foo", "bar", "baz"]}

      assert render_compiled("""
               <div class="foo" :for={_item <- @items} />
             """) =~ expected
    end

    test "raise on invalid :for expr" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:1:6: :for must be a generator expression (pattern <- enumerable) between {...} in tag: div
        |
      1 | <div :for={@user}>Content</div>
        |      ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <div :for={@user}>Content</div>
        """)
      end)

      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:1:6: :for must be an expression between {...} in tag: div
        |
      1 | <div :for=\"1\">Content</div>
        |      ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <div :for="1">Content</div>
        """)
      end)

      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:1:7: :for must be an expression between {...} in local component: div
        |
      1 | <.div :for=\"1\">Content</.div>
        |       ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <.div :for="1">Content</.div>
        """)
      end)
    end

    test ":for in components" do
      assigns = %{items: [1, 2]}

      assert render_compiled("""
             <.local_component :for={val <- @items} value={val} />
             """) == "LOCAL COMPONENT: Value: 1LOCAL COMPONENT: Value: 2"

      assert render_compiled("""
             <br>
             <Combo.Template.CEExEngine.CompilerTest.remote_component :for={val <- @items} value={val} />
             """) == "<br>\nREMOTE COMPONENT: Value: 1REMOTE COMPONENT: Value: 2"

      assert render_compiled("""
             <br>
             <Combo.Template.CEExEngine.CompilerTest.remote_component_with_inner_block :for={val <- @items} value={val}>inner<%= val %></Combo.Template.CEExEngine.CompilerTest.remote_component_with_inner_block>
             """) ==
               "<br>\nREMOTE COMPONENT: Value: 1, Content: inner1REMOTE COMPONENT: Value: 2, Content: inner2"

      assert render_compiled("""
             <.local_component_with_inner_block :for={val <- @items} value={val}>inner<%= val %></.local_component_with_inner_block>
             """) ==
               "LOCAL COMPONENT: Value: 1, Content: inner1LOCAL COMPONENT: Value: 2, Content: inner2"
    end

    test "raise on duplicated :for" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:1:28: cannot define multiple :for attributes. Another :for has already been defined at line 1
        |
      1 | <div :for={item <- [1, 2]} :for={item <- [1, 2]}>Content</div>
        |                            ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <div :for={item <- [1, 2]} :for={item <- [1, 2]}>Content</div>
        """)
      end)
    end

    test ":for in slots" do
      assigns = %{items: [1, 2, 3, 4]}

      assert render_compiled("""
             <Combo.Template.CEExEngine.CompilerTest.slot_if value={0}>
               <:slot :for={i <- @items}>slot<%= i %></:slot>
             </Combo.Template.CEExEngine.CompilerTest.slot_if>
             """) == "<div>0-slot1slot2slot3slot4</div>"
    end

    test ":for and :if in slots" do
      assigns = %{items: [1, 2, 3, 4]}

      assert render_compiled("""
             <Combo.Template.CEExEngine.CompilerTest.slot_if value={0}>
               <:slot :for={i <- @items} :if={rem(i, 2) == 0}>slot<%= i %></:slot>
             </Combo.Template.CEExEngine.CompilerTest.slot_if>
             """) == "<div>0-slot2slot4</div>"
    end

    test ":for and :if and :let in slots" do
      assigns = %{items: [1, 2, 3, 4]}

      assert render_compiled("""
             <Combo.Template.CEExEngine.CompilerTest.slot_if value={0}>
               <:slot :for={i <- @items} :if={rem(i, 2) == 0} :let={val}>slot<%= i %>(<%= val %>)</:slot>
             </Combo.Template.CEExEngine.CompilerTest.slot_if>
             """) == "<div>0-slot2(0)slot4(0)</div>"
    end

    test "multiple slot definitions with mixed regular/if/for" do
      assigns = %{items: [2, 3]}

      assert render_compiled("""
             <Combo.Template.CEExEngine.CompilerTest.slot_if value={0}>
               <:slot :if={false}>slot0</:slot>
               <:slot>slot1</:slot>
               <:slot :for={i <- @items}>slot<%= i %></:slot>
               <:slot>slot4</:slot>
             </Combo.Template.CEExEngine.CompilerTest.slot_if>
             """) == "<div>0-slot1slot2slot3slot4</div>"
    end
  end

  describe ":if attr" do
    test "handle :if attr on HTML element" do
      assigns = %{flag: true}

      assert render_compiled("""
               <div :if={@flag} id="test">yes</div>
             """) =~ "<div id=\"test\">yes</div>"

      assert render_compiled("""
               <div :if={!@flag} id="test">yes</div>
             """) == ""
    end

    test "handle :if attr on self closed HTML element" do
      assigns = %{flag: true}

      assert render_compiled("""
               <div :if={@flag} id="test" />
             """) =~ "<div id=\"test\"></div>"

      assert render_compiled("""
               <div :if={!@flag} id="test" />
             """) == ""
    end

    test "raise on invalid :if expr" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:1:6: :if must be an expression between {...} in tag: div
        |
      1 | <div :if=\"1\">test</div>
        |      ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <div :if="1">test</div>
        """)
      end)
    end

    test ":if in components" do
      assigns = %{flag: true}

      assert render_compiled("""
             <.local_component value="123" :if={@flag} />
             """) == "LOCAL COMPONENT: Value: 123"

      assert render_compiled("""
             <.local_component value="123" :if={!@flag}>test</.local_component>
             """) == ""

      assert render_compiled("""
             <Combo.Template.CEExEngine.CompilerTest.remote_component value="123" :if={@flag} />
             """) == "REMOTE COMPONENT: Value: 123"

      assert render_compiled("""
             <Combo.Template.CEExEngine.CompilerTest.remote_component value="123" :if={!@flag}>test</Combo.Template.CEExEngine.CompilerTest.remote_component>
             """) == ""
    end

    test "raise on duplicated :if" do
      message = """
      test/phoenix/template/ceex_engine/compiler_test.exs:1:17: cannot define multiple :if attributes. Another :if has already been defined at line 1
        |
      1 | <div :if={true} :if={false}>test</div>
        |                 ^\
      """

      assert_raise(ParseError, message, fn ->
        render("""
        <div :if={true} :if={false}>test</div>
        """)
      end)
    end

    def slot_if(assigns) do
      compile_string("""
      <div>{@value}-{render_slot(@slot, @value)}</div>
      """)
    end

    def slot_if_self_close(assigns) do
      compile_string("""
      <div><%= @value %>-<%= for slot <- @slot do %><%= slot.val %>-<% end %></div>
      """)
    end

    test ":if in slots" do
      assigns = %{flag: true}

      assert render_compiled("""
             <Combo.Template.CEExEngine.CompilerTest.slot_if value={0}>
               <:slot :if={@flag}>slot1</:slot>
               <:slot :if={!@flag}>slot2</:slot>
               <:slot :if={@flag}>slot3</:slot>
             </Combo.Template.CEExEngine.CompilerTest.slot_if>
             """) == "<div>0-slot1slot3</div>"

      assert render_compiled("""
             <Combo.Template.CEExEngine.CompilerTest.slot_if_self_close value={0}>
               <:slot :if={@flag} val={1} />
               <:slot :if={!@flag} val={2} />
               <:slot :if={@flag} val={3} />
             </Combo.Template.CEExEngine.CompilerTest.slot_if_self_close>
             """) == "<div>0-1-3-</div>"
    end
  end

  describe ":for and :if attr together" do
    test "handle attrs on HTML element" do
      assigns = %{items: [1, 2, 3, 4]}

      assert render_compiled("""
             <div :for={i <- @items} :if={rem(i, 2) == 0}><%= i %></div>
             """) =~ "<div>2</div><div>4</div>"

      assert render_compiled("""
             <div :for={i <- @items} :if={rem = rem(i, 2)}><%= i %>,<%= rem %></div>
             """) =~ "<div>1,1</div><div>2,0</div><div>3,1</div><div>4,0</div>"

      assert render_compiled("""
             <div :for={i <- @items} :if={false}><%= i %></div>
             """) == ""
    end

    test "handle attrs on self closed HTML element" do
      assigns = %{items: [1, 2, 3, 4]}

      assert render_compiled("""
             <div :for={i <- @items} :if={rem(i, 2) == 0} id={"post-" <> to_string(i)} />
             """) =~ "<div id=\"post-2\"></div><div id=\"post-4\"></div>"

      assert render_compiled("""
             <div :for={i <- @items} :if={false}><%= i %></div>
             """) == ""
    end

    test "handle attrs on components" do
      assigns = %{items: [1, 2, 3, 4]}

      assert render_compiled("""
             <.local_component  :for={i <- @items} :if={rem(i, 2) == 0} value={i}/>
             """) == "LOCAL COMPONENT: Value: 2LOCAL COMPONENT: Value: 4"

      assert render_compiled("""
             <Combo.Template.CEExEngine.CompilerTest.remote_component  :for={i <- @items} :if={rem(i, 2) == 0} value={i}/>
             """) == "REMOTE COMPONENT: Value: 2REMOTE COMPONENT: Value: 4"

      assert render_compiled("""
             <.local_component_with_inner_block  :for={i <- @items} :if={rem(i, 2) == 0} value={i}><%= i %></.local_component_with_inner_block>
             """) == "LOCAL COMPONENT: Value: 2, Content: 2LOCAL COMPONENT: Value: 4, Content: 4"

      assert render_compiled("""
             <Combo.Template.CEExEngine.CompilerTest.remote_component_with_inner_block :for={i <- @items} :if={rem(i, 2) == 0} value={i}><%= i %></Combo.Template.CEExEngine.CompilerTest.remote_component_with_inner_block>
             """) ==
               "REMOTE COMPONENT: Value: 2, Content: 2REMOTE COMPONENT: Value: 4, Content: 4"
    end
  end
end
