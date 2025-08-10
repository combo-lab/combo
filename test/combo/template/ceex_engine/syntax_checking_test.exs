defmodule Combo.Template.CEExEngine.SyntexCheckingTest do
  use ExUnit.Case, async: true

  alias Combo.Template.CEExEngine.Compiler
  alias Combo.Template.CEExEngine.Tokenizer.ParseError

  defp compile(template) do
    Compiler.compile_string(template, caller: __ENV__, file: __ENV__.file)
  end

  describe "invalid tag name" do
    test "for remote component" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:1: invalid tag <Foo>
        |
      1 | <Foo foo=\"bar\" />
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <Foo foo="bar" />
        """)
      end)

      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:2:3: invalid tag <Oops>
        |
      1 | <br>
      2 |   <Oops foo={@foo}>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <br>
          <Oops foo={@foo}>
            Bar
          </Oops>
        """)
      end)
    end
  end

  test "invalid attribute value" do
    message = """
    test/combo/template/ceex_engine/syntax_checking_test.exs:2:9: invalid attribute value after `=`. Expected either a value between quotes (such as \"value\" or 'value') or an Elixir expression between curly braces (such as `{expr}`)
      |
    1 | <div>Bar</div>
    2 | <div id=>Foo</div>
      |         ^\
    """

    assert_raise(ParseError, message, fn ->
      compile("""
      <div>Bar</div>
      <div id=>Foo</div>
      """)
    end)
  end

  describe "missing opening tag" do
    test "for HTML tags" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:2:3: missing opening tag for </span>
        |
      1 | text
      2 |   </span>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        text
          </span>
        """)
      end)
    end

    test "for remote components" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:2:3: missing opening tag for </Remote.component>
        |
      1 | text
      2 |   </Remote.component>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        text
          </Remote.component>
        """)
      end)
    end

    test "for local components" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:2:3: missing opening tag for </.local_component>
        |
      1 | text
      2 |   </.local_component>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        text
          </.local_component>
        """)
      end)
    end

    test "for slots"

    test "with void tag" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:11: missing opening tag for </link> (note <link> is a void tag and cannot have any content)
        |
      1 | <link>Text</link>
        |           ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <link>Text</link>
        """)
      end)
    end
  end

  describe "missing closing tag" do
    test "for HTML tags" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:2:1: end of template reached without closing tag for <div>
        |
      1 | <br>
      2 | <div foo={@foo}>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <br>
        <div foo={@foo}>
        """)
      end)

      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:2:3: end of template reached without closing tag for <span>
        |
      1 | text
      2 |   <span foo={@foo}>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        text
          <span foo={@foo}>
            text
        """)
      end)

      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:2:1: end of template reached without closing tag for <div>
        |
      1 | <div>Foo</div>
      2 | <div>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <div>Foo</div>
        <div>
        <div>Bar</div>
        """)
      end)
    end

    test "for remote components" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:1: end of template reached without closing tag for <.Remote.component>
        |
      1 | <.Remote.component>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <.Remote.component>
        """)
      end)

      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:2:3: end of do-block reached without closing tag for <.Remote.component>
        |
      1 | <%= if true do %>
      2 |   <.Remote.component>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <%= if true do %>
          <.Remote.component>
        <% end %>
        """)
      end)
    end

    test "for local components" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:1: end of template reached without closing tag for <.local_component>
        |
      1 | <.local_component>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <.local_component>
        """)
      end)

      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:2:3: end of do-block reached without closing tag for <.local_component>
        |
      1 | <%= if true do %>
      2 |   <.local_component>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <%= if true do %>
          <.local_component>
        <% end %>
        """)
      end)
    end

    test "for slots"
  end

  describe "unmatched opening/closing tags" do
    test "simply unmatched" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:4:1: unmatched closing tag. Expected </div> for <div> at line 2, got: </span>
        |
      1 | <br>
      2 | <div>
      3 |   text
      4 | </span>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <br>
        <div>
          text
        </span>
        """)
      end)
    end

    test "with nested tags" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:6:1: unmatched closing tag. Expected </div> for <div> at line 2, got: </span>
        |
      3 |   <p>
      4 |     text
      5 |   </p>
      6 | </span>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <br>
        <div>
          <p>
            text
          </p>
        </span>
        """)
      end)
    end

    test "with void tags" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:16: unmatched closing tag. Expected </div> for <div> at line 1, got: </link> (note <link> is a void tag and cannot have any content)
        |
      1 | <div><link>Text</link></div>
        |                ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("<div><link>Text</link></div>")
      end)
    end
  end

  test "missing --> for comment" do
    message = """
    test/combo/template/ceex_engine/syntax_checking_test.exs:1:6: expected closing `-->` for comment
      |
    1 | Begin<!-- <%= 123 %>
      |      ^\
    """

    assert_raise(ParseError, message, fn ->
      compile("Begin<!-- <%= 123 %>")
    end)
  end

  describe "curly-interpolation" do
    test "don't allow to mix curly-interpolation with EEx tags" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:10: expected closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it using `&lbrace;` or using `<%= "{" %>`
        |
      1 | <div foo={<%= @foo %>}>bar</div>
        |          ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <div foo={<%= @foo %>}>bar</div>
        """)
      end)

      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:2:3: expected closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it using `&lbrace;` or using `<%= "{" %>`
        |
      1 | <div foo=
      2 |   {<%= @foo %>}>bar</div>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <div foo=
          {<%= @foo %>}>bar</div>
        """)
      end)

      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:2:6: expected closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it using `&lbrace;` or using `<%= "{" %>`
        |
      1 |    <div foo=
      2 |      {<%= @foo %>}>bar</div>
        |      ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
           <div foo=
             {<%= @foo %>}>bar</div>
        """)
      end)
    end
  end

  describe "special attr - :let" do
    test "raises on using for HTML tags" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:6: unsupported attribute :let in tag: div
        |
      1 | <div :let={@user}>Content</div>
        |      ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <div :let={@user}>Content</div>
        """)
      end)
    end

    test "raises on using multiple ones" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:4:3: cannot define multiple :let attributes. Another :let has already been defined at line 3
        |
      1 | <br>
      2 | <Remote.component value='1'
      3 |   :let={var1}
      4 |   :let={var2}
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <br>
        <Remote.component value='1'
          :let={var1}
          :let={var2}
        >content</Remote.component>
        """)
      end)

      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:4:3: cannot define multiple :let attributes. Another :let has already been defined at line 3
        |
      1 | <br>
      2 | <.local_component value='1'
      3 |   :let={var1}
      4 |   :let={var2}
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <br>
        <.local_component value='1'
          :let={var1}
          :let={var2}
        >content</.local_component>
        """)
      end)
    end

    test "raises on invalid values" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:2:29: :let must be a pattern between {...} in remote component: Remote.component
        |
      1 | <br>
      2 | <Remote.component value='1' :let=\"1\" />
        |                             ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <br>
        <Remote.component value='1' :let="1" />
        """)
      end)

      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:2:29: :let must be a pattern between {...} in local component: local_component
        |
      1 | <br>
      2 | <.local_component value='1' :let=\"1\" />
        |                             ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <br>
        <.local_component value='1' :let="1" />
        """)
      end)
    end

    test "raises on using for self-closed components" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:19: cannot use :let on a remote component without inner content
        |
      1 | <Remote.component :let={var} />
        |                   ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <Remote.component :let={var} />
        """)
      end)

      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:19: cannot use :let on a local component without inner content
        |
      1 | <.local_component :let={var} />
        |                   ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <.local_component :let={var} />
        """)
      end)
    end

    test "raises on using for self-closed slots" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:2:19: cannot use :let on a slot without inner content
        |
      1 | <.local_component>
      2 |   <:sample id="1" :let={var} />
        |                   ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <.local_component>
          <:sample id="1" :let={var} />
        </.local_component>
        """)
      end)
    end
  end

  describe "special attr - :if" do
    test "raises on using multiple ones" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:17: cannot define multiple :if attributes. Another :if has already been defined at line 1
        |
      1 | <div :if={true} :if={true}>content</div>
        |                 ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <div :if={true} :if={true}>content</div>
        """)
      end)

      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:30: cannot define multiple :if attributes. Another :if has already been defined at line 1
        |
      1 | <Remote.component :if={true} :if={true}>content</Remote.component>
        |                              ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <Remote.component :if={true} :if={true}>content</Remote.component>
        """)
      end)

      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:30: cannot define multiple :if attributes. Another :if has already been defined at line 1
        |
      1 | <.local_component :if={true} :if={true}>content</.local_component>
        |                              ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <.local_component :if={true} :if={true}>content</.local_component>
        """)
      end)
    end

    test "raises on invalid values" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:6: :if must be an expression between {...} in tag: div
        |
      1 | <div :if=\"1\">content</div>
        |      ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <div :if="1">content</div>
        """)
      end)
    end
  end

  describe "special attr - :for" do
    test "raises on using multiple ones" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:28: cannot define multiple :for attributes. Another :for has already been defined at line 1
        |
      1 | <div :for={item <- [1, 2]} :for={item <- [1, 2]}>content</div>
        |                            ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <div :for={item <- [1, 2]} :for={item <- [1, 2]}>content</div>
        """)
      end)

      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:41: cannot define multiple :for attributes. Another :for has already been defined at line 1
        |
      1 | <Remote.component :for={item <- [1, 2]} :for={item <- [1, 2]}>content</Remote.component>
        |                                         ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <Remote.component :for={item <- [1, 2]} :for={item <- [1, 2]}>content</Remote.component>
        """)
      end)

      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:41: cannot define multiple :for attributes. Another :for has already been defined at line 1
        |
      1 | <.local_component :for={item <- [1, 2]} :for={item <- [1, 2]}>content</.local_component>
        |                                         ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <.local_component :for={item <- [1, 2]} :for={item <- [1, 2]}>content</.local_component>
        """)
      end)
    end

    test "raises on invalid values" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:6: :for must be an expression between {...} in tag: div
        |
      1 | <div :for=\"1\">content</div>
        |      ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <div :for="1">content</div>
        """)
      end)

      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:6: :for must be a generator expression (pattern <- enumerable) between {...} in tag: div
        |
      1 | <div :for={@user}>content</div>
        |      ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <div :for={@user}>content</div>
        """)
      end)
    end
  end

  describe "special attr" do
    test "unknown attributes" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:6: unsupported attribute :unknown in tag: div
        |
      1 | <div :unknown=\"something\" />
        |      ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <div :unknown="something" />
        """)
      end)
    end
  end

  describe "slot" do
    test "raises on if the slot is not a direct child of a component" do
      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:1: invalid slot entry <:slot>. A slot entry must be a direct child of a component
        |
      1 | <:slot>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <:slot>
          content
        </:slot>
        """)
      end)

      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:1:1: invalid slot entry <:slot>. A slot entry must be a direct child of a component
        |
      1 | <:slot>
        | ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <:slot>
          <p>content</p>
        </:slot>
        """)
      end)

      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:2:3: invalid slot entry <:slot>. A slot entry must be a direct child of a component
        |
      1 | <div>
      2 |   <:slot>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <div>
          <:slot>
            content
          </:slot>
        </div>
        """)
      end)

      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:3:3: invalid slot entry <:slot>. A slot entry must be a direct child of a component
        |
      1 | <Remote.component>
      2 | <%= if true do %>
      3 |   <:slot>
        |   ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <Remote.component>
        <%= if true do %>
          <:slot>
            <p>content</p>
          </:slot>
        <% end %>
        </Remote.component>
        """)
      end)

      message = """
      test/combo/template/ceex_engine/syntax_checking_test.exs:3:5: invalid slot entry <:inner_slot>. A slot entry must be a direct child of a component
        |
      1 | <Remote.component>
      2 |   <:slot>
      3 |     <:inner_slot>
        |     ^\
      """

      assert_raise(ParseError, message, fn ->
        compile("""
        <Remote.component>
          <:slot>
            <:inner_slot>
              content
            </:inner_slot>
          </:slot>
        </Remote.component>
        """)
      end)
    end
  end
end
