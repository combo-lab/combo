defmodule Combo.Template.CEExEngine.SyntaxCheckingTest do
  use ExUnit.Case, async: true

  alias Combo.Template.CEExEngine.SyntaxError
  import ComboTest.Template.CEExEngine.Helper

  defp assert_compiled(source) do
    assert {:__block__, _, _} = compile_string(source)
  end

  describe "tokenizing > doctype >" do
    test "raises on unclosed tag" do
      message = """
      nofile:1:15: missing closing `>` for doctype
        |
      1 | <!doctype html
        |               ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("<!doctype html")
      end
    end
  end

  describe "tokenizing > comment >" do
    test "raises on unclosed tag" do
      message = """
      nofile:1:1: unexpected end of string inside tag
        |
      1 | <!-- comment
        | ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("<!-- comment")
      end
    end
  end

  describe "tokenizing > opening tag >" do
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
        compile_string("<")
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
          compile_string("""
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
        compile_string("<Invalid.Name>")
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
        compile_string("<./local_component>")
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
        compile_string("<.InvalidName>")
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
        compile_string("<:/slot>")
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
        compile_string("<:InvalidName>")
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
        compile_string("<:inner_block>")
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
        compile_string("""
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
        compile_string(~S(<div = >))
      end

      message = """
      nofile:1:6: missing attribute name
        |
      1 | <div / >
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string(~S(<div / >))
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
        compile_string(~S(<div'>))
      end

      message = """
      nofile:1:5: invalid character in attribute name, got: \"
        |
      1 | <div">
        |     ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string(~S(<div">))
      end

      message = """
      nofile:1:10: invalid character in attribute name, got: '
        |
      1 | <div attr'>
        |          ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string(~S(<div attr'>))
      end

      message = """
      nofile:1:20: invalid character in attribute name, got: \"
        |
      1 | <div class={"test"}">
        |                    ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string(~S(<div class={"test"}">))
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
        compile_string("<div class")
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
        compile_string("""
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
        compile_string(~S(<div class= >))
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
        compile_string("<div class=")
      end
    end

    test "for attribute value - raises on missing closing quotes" do
      message = ~r"nofile:2:15: missing closing `\"` for attribute value"

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <div
          class="panel\
        """)
      end

      message = ~r"nofile:2:15: missing closing `\'` for attribute value"

      assert_raise SyntaxError, message, fn ->
        compile_string("""
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
        compile_string("""
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
        compile_string("""
        <div
          {@attrs\
        """)
      end
    end

    ## handle tag open end

    test "raises on unclosed tag" do
      message = ~r"nofile:1:5: missing closing `>` or `/>` for tag"

      assert_raise SyntaxError, message, fn ->
        compile_string("<foo")
      end
    end
  end

  describe "tokenizing > closing tag >" do
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
        compile_string("""
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
        compile_string("""
        <div>
        </div text\
        """)
      end
    end
  end

  describe "parsing > HTML tags > supported attributes >" do
    test ":if is supported" do
      assert_compiled("""
      <div :if={true} />
      """)
    end

    test ":for is supported" do
      assert_compiled("""
      <div :for={i <- 1..3}>{i}</div>
      """)
    end

    test ":let is not supported" do
      message = """
      nofile:1:6: \
      unsupported attribute :let for <div />
        |
      1 | <div :let={user} />
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <div :let={user} />
        """)
      end
    end

    test "unknown :-prefixed attribute is not supported" do
      message = """
      nofile:1:6: \
      unsupported attribute :unknown for <div />
        |
      1 | <div :unknown=\"something\" />
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <div :unknown="something" />
        """)
      end
    end

    test "other attributes are supported" do
      assert_compiled("""
      <div other="something" />
      """)
    end
  end

  describe "parsing > remote components > supported attributes >" do
    test ":if is supported" do
      assert_compiled("""
      <Remote.component :if={true} />
      """)
    end

    test ":for is supported" do
      assert_compiled("""
      <Remote.component :for={i <- 1..3}></Remote.component>
      """)
    end

    test ":let is supported" do
      assert_compiled("""
      <Remote.component :let={@user}></Remote.component>
      """)
    end

    test "unknown :-prefixed attribute is not supported" do
      message = """
      nofile:1:19: \
      unsupported attribute :unknown for <Remote.component />
        |
      1 | <Remote.component :unknown=\"something\" />
        |                   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <Remote.component :unknown="something" />
        """)
      end
    end

    test "other atributes are supported" do
      assert_compiled("""
      <Remote.component other="something" />
      """)
    end
  end

  describe "parsing > local components > supported attributes >" do
    test ":if is supported" do
      assert_compiled("""
      <.local_component :if={true} />
      """)
    end

    test ":for is supported" do
      assert_compiled("""
      <.local_component :for={i <- 1..3}></.local_component>
      """)
    end

    test ":let is supported" do
      assert_compiled("""
      <.local_component :let={@user}></.local_component>
      """)
    end

    test "unknown :-prefixed attribute is not supported" do
      message = """
      nofile:1:19: \
      unsupported attribute :unknown for <.local_component />
        |
      1 | <.local_component :unknown=\"something\" />
        |                   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <.local_component :unknown="something" />
        """)
      end
    end

    test "other attributes are supported" do
      assert_compiled("""
      <.local_component other="something" />
      """)
    end
  end

  describe "parsing > slots > supported attributes >" do
    test ":if is supported" do
      assert_compiled("""
      <Remote.component>
        <:slot :if={true} />
      </Remote.component>
      """)
    end

    test ":for is supported" do
      assert_compiled("""
      <Remote.component>
        <:slot :for={i <- 1..3}></:slot>
      </Remote.component>
      """)
    end

    test ":let is supported" do
      assert_compiled("""
      <Remote.component>
      <:slot :let={@user}></:slot>
      </Remote.component>
      """)
    end

    test "unknown :-prefixed attribute is not supported" do
      message = """
      nofile:1:8: \
      unsupported attribute :unknown for <:slot />
        |
      1 | <:slot :unknown=\"something\" />
        |        ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <:slot :unknown="something" />
        """)
      end
    end

    test "other attributes are supported" do
      assert_compiled("""
      <Remote.component>
        <:slot other="something" />
      </Remote.component>
      """)
    end
  end

  describe "parsing > HTML tags > limitations >" do
    test "void tags can't have a closing tag" do
      message = """
      nofile:1:11: \
      <link> is a void element and cannot have a closing tag
        |
      1 | <link>Text</link>
        |           ^\
      """

      assert_raise SyntaxError, message, fn ->
        # flat tag
        compile_string("""
        <link>Text</link>
        """)
      end

      message = """
      nofile:1:16: \
      <link> is a void element and cannot have a closing tag
        |
      1 | <div><link>Text</link></div>
        |                ^\
      """

      assert_raise SyntaxError, message, fn ->
        # nested tags
        compile_string("<div><link>Text</link></div>")
      end
    end
  end

  describe "parsing > slots > limitations >" do
    test "raises on not declaring a slot entry as the direct child of a component" do
      message = """
      nofile:1:1: \
      invalid parent of slot entry <:slot>. \
      Expected a slot entry to be the direct child of a component
        |
      1 | <:slot>
        | ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <:slot>
          content
        </:slot>
        """)
      end

      message = """
      nofile:1:1: \
      invalid parent of slot entry <:slot>. \
      Expected a slot entry to be the direct child of a component
        |
      1 | <:slot>
        | ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <:slot>
          <p>content</p>
        </:slot>
        """)
      end

      message = """
      nofile:2:3: \
      invalid parent of slot entry <:slot>. \
      Expected a slot entry to be the direct child of a component
        |
      1 | <div>
      2 |   <:slot>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <div>
          <:slot>
            content
          </:slot>
        </div>
        """)
      end

      message = """
      nofile:3:3: \
      invalid parent of slot entry <:slot>. \
      Expected a slot entry to be the direct child of a component
        |
      1 | <Remote.component>
      2 | <%= if true do %>
      3 |   <:slot>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <Remote.component>
        <%= if true do %>
          <:slot>
            <p>content</p>
          </:slot>
        <% end %>
        </Remote.component>
        """)
      end

      message = """
      nofile:3:5: \
      invalid parent of slot entry <:inner_slot>. \
      Expected a slot entry to be the direct child of a component
        |
      1 | <Remote.component>
      2 |   <:slot>
      3 |     <:inner_slot>
        |     ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <Remote.component>
          <:slot>
            <:inner_slot>
              content
            </:inner_slot>
          </:slot>
        </Remote.component>
        """)
      end
    end
  end

  describe "parsing > attributes > :if >" do
    test "raises on multiple :if" do
      message = """
      nofile:4:3: \
      cannot define multiple :if attributes. \
      Another :if attribute has already been defined at line 3
        |
      1 | <br>
      2 | <Remote.component value='1'
      3 |   :if={true}
      4 |   :if={true}
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <br>
        <Remote.component value='1'
          :if={true}
          :if={true}
        >content</Remote.component>
        """)
      end
    end

    test "raises on invalid value" do
      message = """
      nofile:1:6: \
      invalid value for :if attribute. Expected an expression between {...}
        |
      1 | <div :if=\"1\">content</div>
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <div :if="1">content</div>
        """)
      end
    end
  end

  describe "parsing > attributes > :for >" do
    test "raises on multiple :for" do
      message = """
      nofile:4:3: \
      cannot define multiple :for attributes. \
      Another :for attribute has already been defined at line 3
        |
      1 | <br>
      2 | <Remote.component value='1'
      3 |   :for={i <- 1..3}
      4 |   :for={i <- 1..3}
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <br>
        <Remote.component value='1'
          :for={i <- 1..3}
          :for={i <- 1..3}
        >content</Remote.component>
        """)
      end
    end

    test "raises on invalid value" do
      message = """
      nofile:1:6: \
      invalid value for :for attribute. \
      Expected an expression between {...}
        |
      1 | <div :for=\"1\">content</div>
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <div :for="1">content</div>
        """)
      end

      message = """
      nofile:1:6: \
      invalid value for :for attribute. \
      Expected a generator expression (pattern <- enumerable) between {...}
        |
      1 | <div :for={@user}>content</div>
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <div :for={@user}>content</div>
        """)
      end
    end
  end

  describe "parsing > attributes > :let >" do
    test "raises on multiple :let" do
      message = """
      nofile:4:3: \
      cannot define multiple :let attributes. \
      Another :let attribute has already been defined at line 3
        |
      1 | <br>
      2 | <Remote.component value='1'
      3 |   :let={var1}
      4 |   :let={var2}
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <br>
        <Remote.component value='1'
          :let={var1}
          :let={var2}
        >content</Remote.component>
        """)
      end
    end

    test "raises on invalid value" do
      message = """
      nofile:2:29: \
      invalid value for :let attribute. Expected a pattern between {...}
        |
      1 | <br>
      2 | <Remote.component value='1' :let=\"1\" />
        |                             ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <br>
        <Remote.component value='1' :let="1" />
        """)
      end
    end

    test "raises on using for self-closing components or slots" do
      message = """
      nofile:1:19: \
      cannot use :let on a self-closing remote component
        |
      1 | <Remote.component :let={var} />
        |                   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <Remote.component :let={var} />
        """)
      end

      message = """
      nofile:1:19: \
      cannot use :let on a self-closing local component
        |
      1 | <.local_component :let={var} />
        |                   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <.local_component :let={var} />
        """)
      end

      message = """
      nofile:2:19: \
      cannot use :let on a self-closing slot
        |
      1 | <.local_component>
      2 |   <:sample id="1" :let={var} />
        |                   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <.local_component>
          <:sample id="1" :let={var} />
        </.local_component>
        """)
      end
    end
  end

  describe "parsing > unpaired tags > unmatched" do
    test "flat tags" do
      message = """
      nofile:4:1: \
      unmatched closing tag. Expected </div> for <div> at line 2, got: </span>
        |
      1 | <br>
      2 | <div>
      3 |   text
      4 | </span>
        | ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <br>
        <div>
          text
        </span>
        """)
      end
    end

    test "nested tags" do
      message = """
      nofile:6:1: \
      unmatched closing tag. Expected </div> for <div> at line 2, got: </span>
        |
      3 |   <p>
      4 |     text
      5 |   </p>
      6 | </span>
        | ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <br>
        <div>
          <p>
            text
          </p>
        </span>
        """)
      end
    end
  end

  describe "parsing > unpaired tags > missing opening tag" do
    test "for HTML tags" do
      message = """
      nofile:2:3: \
      missing opening tag for </span>
        |
      1 | text
      2 |   </span>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        text
          </span>
        """)
      end
    end

    test "for remote components" do
      message = """
      nofile:2:3: \
      missing opening tag for </Remote.component>
        |
      1 | text
      2 |   </Remote.component>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        text
          </Remote.component>
        """)
      end
    end

    test "for local components" do
      message = """
      nofile:2:3: \
      missing opening tag for </.local_component>
        |
      1 | text
      2 |   </.local_component>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        text
          </.local_component>
        """)
      end
    end

    test "for slots" do
      message = """
      nofile:2:3: \
      missing opening tag for </:slot>
        |
      1 | text
      2 |   </:slot>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        text
          </:slot>
        """)
      end
    end
  end

  describe "parsing > unpaired tags > missing closing tag" do
    test "for HTML tags" do
      message = """
      nofile:2:1: \
      end of template reached without closing tag for <div>
        |
      1 | <br>
      2 | <div foo={@foo}>
        | ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <br>
        <div foo={@foo}>
        """)
      end

      message = """
      nofile:2:3: \
      end of template reached without closing tag for <span>
        |
      1 | text
      2 |   <span foo={@foo}>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        text
          <span foo={@foo}>
            text
        """)
      end

      message = """
      nofile:2:1: \
      end of template reached without closing tag for <div>
        |
      1 | <div>Foo</div>
      2 | <div>
        | ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <div>Foo</div>
        <div>
        <div>Bar</div>
        """)
      end

      message = """
      nofile:2:3: \
      end of do-block reached without closing tag for <div>
        |
      1 | <%= if true do %>
      2 |   <div>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <%= if true do %>
          <div>
        <% end %>
        """)
      end
    end

    test "for remote components" do
      message = """
      nofile:1:1: \
      end of template reached without closing tag for <Remote.component>
        |
      1 | <Remote.component>
        | ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <Remote.component>
        """)
      end

      message = """
      nofile:2:3: \
      end of do-block reached without closing tag for <Remote.component>
        |
      1 | <%= if true do %>
      2 |   <Remote.component>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <%= if true do %>
          <Remote.component>
        <% end %>
        """)
      end
    end

    test "for local components" do
      message = """
      nofile:1:1: \
      end of template reached without closing tag for <.local_component>
        |
      1 | <.local_component>
        | ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <.local_component>
        """)
      end

      message = """
      nofile:2:3: \
      end of do-block reached without closing tag for <.local_component>
        |
      1 | <%= if true do %>
      2 |   <.local_component>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <%= if true do %>
          <.local_component>
        <% end %>
        """)
      end
    end

    test "for slots" do
      message = """
      nofile:2:3: \
      end of template reached without closing tag for <:slot>
        |
      1 | <Remote.component>
      2 |   <:slot :if={true}>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <Remote.component>
          <:slot :if={true}>
        """)
      end

      # Where is the test for end of do-block reached? Because slot entry can't
      # be placed in do-block, there's no test for the case.
    end
  end

  describe "parsing > misc > don't allow to mix curly-interpolation with EEx tags" do
    test "for attribute value" do
      message = """
      nofile:1:10: \
      missing closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it \
      using `&lbrace;` or using `<%= "{" %>`.
        |
      1 | <div foo={<%= @foo %>}>bar</div>
        |          ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <div foo={<%= @foo %>}>bar</div>
        """)
      end
    end

    test "for root attribute" do
      message = """
      nofile:1:6: \
      missing closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it \
      using `&lbrace;` or using `<%= "{" %>`.
        |
      1 | <div {<%= @foo %>}>bar</div>
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <div {<%= @foo %>}>bar</div>
        """)
      end
    end

    test "for body" do
      message = """
      nofile:1:6: \
      missing closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it \
      using `&lbrace;` or using `<%= "{" %>`.
        |
      1 | <div>{<%= @foo %>}</div>
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile_string("""
        <div>{<%= @foo %>}</div>
        """)
      end
    end
  end

  describe "parsing > misc > raises syntax error for bad expression" do
    test "in attribute value" do
      exception =
        assert_raise Elixir.SyntaxError, fn ->
          opts = [line: 10, indentation: 8]

          compile_string(
            """
            text
            <%= "interpolation" %>
            <div class={[,]} />
            """,
            opts
          )
        end

      message = Exception.message(exception)
      assert message =~ "nofile:12:22:"
      assert message =~ "syntax error before: ','"
    end

    test "in root attribute" do
      exception =
        assert_raise Elixir.SyntaxError, fn ->
          opts = [line: 10, indentation: 8]

          compile_string(
            """
            text
            <%= "interpolation" %>
            <div {[,]}/>
            """,
            opts
          )
        end

      message = Exception.message(exception)
      assert message =~ "nofile:12:16:"
      assert message =~ "syntax error before: ','"
    end

    test "in body" do
      exception =
        assert_raise Elixir.SyntaxError, fn ->
          opts = [line: 10, indentation: 8]

          compile_string(
            """
            text
            {[,]}
            """,
            opts
          )
        end

      message = Exception.message(exception)
      assert message =~ "nofile:11:10:"
      assert message =~ "syntax error before: ','"
    end
  end
end
