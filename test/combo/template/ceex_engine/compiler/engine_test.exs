defmodule Combo.Template.CEExEngine.Compiler.EngineTest do
  use ExUnit.Case, async: true

  alias Combo.Template.CEExEngine.SyntaxError
  alias Combo.Template.CEExEngine.Compiler.Engine

  defp compile(source) do
    opts = [
      engine: Engine,
      caller: __ENV__,
      file: __ENV__.file,
      line: 1,
      indentation: 0,
      source: source
    ]

    EEx.compile_string(source, opts)
  end

  defp assert_compiled(source) do
    assert {:__block__, _, _} = compile(source)
  end

  ## Different tags have different supported attributes

  describe "tag - HTML tag" do
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
      test/combo/template/ceex_engine/compiler/engine_test.exs:1:6: \
      unsupported attribute :let for <div />
        |
      1 | <div :let={user} />
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <div :let={user} />
        """)
      end
    end

    test "unknown :-prefixed attribute is not supported" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:1:6: \
      unsupported attribute :unknown for <div />
        |
      1 | <div :unknown=\"something\" />
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
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

  describe "tag - remote component" do
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
      test/combo/template/ceex_engine/compiler/engine_test.exs:1:19: \
      unsupported attribute :unknown for <Remote.component />
        |
      1 | <Remote.component :unknown=\"something\" />
        |                   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
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

  describe "tag - local component" do
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
      test/combo/template/ceex_engine/compiler/engine_test.exs:1:19: \
      unsupported attribute :unknown for <.local_component />
        |
      1 | <.local_component :unknown=\"something\" />
        |                   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
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

  describe "tag - slot" do
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
      test/combo/template/ceex_engine/compiler/engine_test.exs:1:8: \
      unsupported attribute :unknown for <:slot />
        |
      1 | <:slot :unknown=\"something\" />
        |        ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
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

  ## Different tags have different limitations

  describe "slot" do
    test "raises on not using it as the direct child of a component" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:1:1: \
      invalid parent of slot entry <:slot>. \
      Expected a slot entry to be the direct child of a component
        |
      1 | <:slot>
        | ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <:slot>
          content
        </:slot>
        """)
      end

      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:1:1: \
      invalid parent of slot entry <:slot>. \
      Expected a slot entry to be the direct child of a component
        |
      1 | <:slot>
        | ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <:slot>
          <p>content</p>
        </:slot>
        """)
      end

      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:2:3: \
      invalid parent of slot entry <:slot>. \
      Expected a slot entry to be the direct child of a component
        |
      1 | <div>
      2 |   <:slot>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <div>
          <:slot>
            content
          </:slot>
        </div>
        """)
      end

      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:3:3: \
      invalid parent of slot entry <:slot>. \
      Expected a slot entry to be the direct child of a component
        |
      1 | <Remote.component>
      2 | <%= if true do %>
      3 |   <:slot>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
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
      test/combo/template/ceex_engine/compiler/engine_test.exs:3:5: \
      invalid parent of slot entry <:inner_slot>. \
      Expected a slot entry to be the direct child of a component
        |
      1 | <Remote.component>
      2 |   <:slot>
      3 |     <:inner_slot>
        |     ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
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

  ## Different attributes have different limitations

  describe "attribute - :if" do
    test "raises on multiple :if" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:4:3: \
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
        compile("""
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
      test/combo/template/ceex_engine/compiler/engine_test.exs:1:6: \
      invalid value for :if attribute. Expected an expression between {...}
        |
      1 | <div :if=\"1\">content</div>
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <div :if="1">content</div>
        """)
      end
    end
  end

  describe "attribute - :for" do
    test "raises on multiple :for" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:4:3: \
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
        compile("""
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
      test/combo/template/ceex_engine/compiler/engine_test.exs:1:6: \
      invalid value for :for attribute. \
      Expected an expression between {...}
        |
      1 | <div :for=\"1\">content</div>
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <div :for="1">content</div>
        """)
      end

      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:1:6: \
      invalid value for :for attribute. \
      Expected a generator expression (pattern <- enumerable) between {...}
        |
      1 | <div :for={@user}>content</div>
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <div :for={@user}>content</div>
        """)
      end
    end
  end

  describe ":let" do
    test "raises on multiple :let" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:4:3: \
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
        compile("""
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
      test/combo/template/ceex_engine/compiler/engine_test.exs:2:29: \
      invalid value for :let attribute. Expected a pattern between {...}
        |
      1 | <br>
      2 | <Remote.component value='1' :let=\"1\" />
        |                             ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <br>
        <Remote.component value='1' :let="1" />
        """)
      end
    end

    test "raises on using for self-closing components or slots" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:1:19: \
      cannot use :let on a self-closing remote component
        |
      1 | <Remote.component :let={var} />
        |                   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <Remote.component :let={var} />
        """)
      end

      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:1:19: \
      cannot use :let on a self-closing local component
        |
      1 | <.local_component :let={var} />
        |                   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <.local_component :let={var} />
        """)
      end

      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:2:19: \
      cannot use :let on a self-closing slot
        |
      1 | <.local_component>
      2 |   <:sample id="1" :let={var} />
        |                   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <.local_component>
          <:sample id="1" :let={var} />
        </.local_component>
        """)
      end
    end
  end

  describe "void tags" do
    test "flat tags" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:1:11: \
      <link> is a void element and cannot have a closing tag
        |
      1 | <link>Text</link>
        |           ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <link>Text</link>
        """)
      end
    end

    test "nested tags" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:1:16: \
      <link> is a void element and cannot have a closing tag
        |
      1 | <div><link>Text</link></div>
        |                ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("<div><link>Text</link></div>")
      end
    end
  end

  describe "unmatched" do
    test "flat tags" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:4:1: \
      unmatched closing tag. Expected </div> for <div> at line 2, got: </span>
        |
      1 | <br>
      2 | <div>
      3 |   text
      4 | </span>
        | ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <br>
        <div>
          text
        </span>
        """)
      end
    end

    test "nested tags" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:6:1: \
      unmatched closing tag. Expected </div> for <div> at line 2, got: </span>
        |
      3 |   <p>
      4 |     text
      5 |   </p>
      6 | </span>
        | ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
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

  describe "missing opening tag" do
    test "for HTML tags" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:2:3: \
      missing opening tag for </span>
        |
      1 | text
      2 |   </span>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        text
          </span>
        """)
      end
    end

    test "for remote components" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:2:3: \
      missing opening tag for </Remote.component>
        |
      1 | text
      2 |   </Remote.component>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        text
          </Remote.component>
        """)
      end
    end

    test "for local components" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:2:3: \
      missing opening tag for </.local_component>
        |
      1 | text
      2 |   </.local_component>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        text
          </.local_component>
        """)
      end
    end

    test "for slots" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:2:3: \
      missing opening tag for </:slot>
        |
      1 | text
      2 |   </:slot>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        text
          </:slot>
        """)
      end
    end
  end

  describe "missing closing tag" do
    test "for HTML tags" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:2:1: \
      end of template reached without closing tag for <div>
        |
      1 | <br>
      2 | <div foo={@foo}>
        | ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <br>
        <div foo={@foo}>
        """)
      end

      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:2:3: \
      end of template reached without closing tag for <span>
        |
      1 | text
      2 |   <span foo={@foo}>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        text
          <span foo={@foo}>
            text
        """)
      end

      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:2:1: \
      end of template reached without closing tag for <div>
        |
      1 | <div>Foo</div>
      2 | <div>
        | ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <div>Foo</div>
        <div>
        <div>Bar</div>
        """)
      end

      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:2:3: \
      end of do-block reached without closing tag for <div>
        |
      1 | <%= if true do %>
      2 |   <div>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <%= if true do %>
          <div>
        <% end %>
        """)
      end
    end

    test "for remote components" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:1:1: \
      end of template reached without closing tag for <Remote.component>
        |
      1 | <Remote.component>
        | ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <Remote.component>
        """)
      end

      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:2:3: \
      end of do-block reached without closing tag for <Remote.component>
        |
      1 | <%= if true do %>
      2 |   <Remote.component>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <%= if true do %>
          <Remote.component>
        <% end %>
        """)
      end
    end

    test "for local components" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:1:1: \
      end of template reached without closing tag for <.local_component>
        |
      1 | <.local_component>
        | ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <.local_component>
        """)
      end

      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:2:3: \
      end of do-block reached without closing tag for <.local_component>
        |
      1 | <%= if true do %>
      2 |   <.local_component>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <%= if true do %>
          <.local_component>
        <% end %>
        """)
      end
    end

    test "for slots" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:2:3: \
      end of template reached without closing tag for <:slot>
        |
      1 | <Remote.component>
      2 |   <:slot :if={true}>
        |   ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <Remote.component>
          <:slot :if={true}>
        """)
      end

      # Where is the test for end of do-block reached? Because slot entry can't
      # be placed in do-block, there's no test for the case.
    end
  end

  describe "don't allow to mix curly-interpolation with EEx tags" do
    test "for attribute value" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:1:10: \
      missing closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it \
      using `&lbrace;` or using `<%= "{" %>`.
        |
      1 | <div foo={<%= @foo %>}>bar</div>
        |          ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <div foo={<%= @foo %>}>bar</div>
        """)
      end
    end

    test "for root attribute" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:1:6: \
      missing closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it \
      using `&lbrace;` or using `<%= "{" %>`.
        |
      1 | <div {<%= @foo %>}>bar</div>
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <div {<%= @foo %>}>bar</div>
        """)
      end
    end

    test "for body" do
      message = """
      test/combo/template/ceex_engine/compiler/engine_test.exs:1:6: \
      missing closing `}` for expression

      In case you don't want `{` to begin a new interpolation, you may write it \
      using `&lbrace;` or using `<%= "{" %>`.
        |
      1 | <div>{<%= @foo %>}</div>
        |      ^\
      """

      assert_raise SyntaxError, message, fn ->
        compile("""
        <div>{<%= @foo %>}</div>
        """)
      end
    end
  end
end
