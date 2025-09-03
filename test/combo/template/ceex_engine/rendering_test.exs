defmodule Combo.Template.CEExEngine.RenderingTest do
  use ExUnit.Case, async: true

  import Combo.Template.CEExEngine.Slot
  import ComboTest.Template.CEExEngine.Helper
  alias ComboTest.Template.CEExEngine.Helper

  defp escape(string) do
    string
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
    |> String.replace("\t", "\\t")
    |> String.replace("\r", "\\r")
  end

  describe "EEx - do-block" do
    defp do_block(do: {:safe, _} = safe), do: safe

    test "where static content is treated as safe" do
      assert render_string!("""
             <%= do_block do %>
               <p>content</p>
             <% end %>
             """) == "\n  <p>content</p>\n"

      assert render_string!("""
             <p><%= do_block do %>content<% end %></p>
             """) == "<p>content</p>"
    end

    test "where dynamic content is treated as unsafe" do
      assert render_string!("""
             <%= do_block do %>
               <%= "<p>content</p>" %>
             <% end %>
             """) == "\n  &lt;p&gt;content&lt;/p&gt;\n"
    end
  end

  describe "EEx - more" do
    test "supports non-output expressions" do
      assert render_string!(
               """
               <% content = @content %>
               <%= content %>
               """,
               %{content: "<p>content</p>"}
             ) == "\n&lt;p&gt;content&lt;/p&gt;"
    end

    test "supports mixed non-output expressions" do
      assert render_string!(
               """
               prea
               <% @content %>
               posta
               <%= @content %>
               preb
               <% @content %>
               middleb
               <% @content %>
               postb
               """,
               %{content: "<p>content</p>"}
             ) == "prea\n\nposta\n&lt;p&gt;content&lt;/p&gt;\npreb\n\nmiddleb\n\npostb\n"
    end
  end

  describe "text" do
    test "with static content" do
      assert render_string!("Hello world!") == "Hello world!"
    end

    test "with dynamic content enclosed by EEx notation" do
      assert render_string!("""
             Hello <%= "world!" %>
             """) == "Hello world!"
    end

    test "with dynamic content enclosed by curly braces" do
      assert render_string!("""
             Hello {"world!"}
             """) == "Hello world!"
    end
  end

  describe "HTML elements" do
    test "with static content" do
      assert render_string!("<p>content</p>") == "<p>content</p>"
      assert render_string!("<unknown>content</unknown>") == "<unknown>content</unknown>"
    end

    test "with static content and attrs" do
      assert render_string!("""
             <p name="value">content</p>
             """) == ~S|<p name="value">content</p>|

      assert render_string!("""
             <unknown name="value">content</unknown>
             """) == ~S|<unknown name="value">content</unknown>|
    end

    test "as self closed" do
      assert render_string!("<p />") == "<p></p>"
      assert render_string!("<unknown />") == "<unknown></unknown>"
    end

    test "as self closed with attrs" do
      assert render_string!("""
             <p name="value" />
             """) == ~S|<p name="value"></p>|

      assert render_string!("""
             <unknown name="value" />
             """) == ~S|<unknown name="value"></unknown>|
    end

    test "dynamic content enclosed by EEx notation" do
      assert render_string!("""
             <div><%= "<p>content</p>" %></div>
             """) == "<div>&lt;p&gt;content&lt;/p&gt;</div>"

      assert render_string!("""
             <div><%= {:safe, "<p>content</p>"} %></div>
             """) == "<div><p>content</p></div>"
    end

    test "dynamic content enclosed by curly braces" do
      assert render_string!("""
             <div>{"<p>content</p>"}</div>
             """) == "<div>&lt;p&gt;content&lt;/p&gt;</div>"

      assert render_string!("""
             <div>{{:safe, "<p>content</p>"}}</div>
             """) == "<div><p>content</p></div>"
    end
  end

  describe "HTML elements (void)" do
    test "with static content" do
      assert render_string!("<br>") == "<br>"
    end

    test "with static content and attrs" do
      assert render_string!("<br>") == "<br>"

      assert render_string!("""
             <br name="value">
             """) == ~S|<br name="value">|
    end

    test "as self-closed" do
      assert render_string!("<br />") == "<br>"
    end

    test "as self-closed with attrs" do
      assert render_string!("""
             <br name="value" />
             """) == ~S|<br name="value">|
    end
  end

  describe "special HTML elements" do
    test "curly interpolation is disabled for <style>" do
      assert render_string!("""
             <style>
               * {
                 background-color: <%= :red %>;
                 color: green;
               }
             </style>
             """) == """
             <style>
               * {
                 background-color: red;
                 color: green;
               }
             </style>\
             """
    end

    test "curly interpolation is disabled for <script>" do
      assert render_string!("""
             <script>
               function hi(name) { console.log("Hi, ${name}!") }
               hi("<%= "Charlie Brown" %>">)
             </script>
             """) == """
             <script>
               function hi(name) { console.log("Hi, ${name}!") }
               hi("Charlie Brown">)
             </script>\
             """
    end

    test "comment" do
      assert render_string!("""
             begin<!-- <%= 123 %> -->end
             """) == """
             begin<!-- 123 -->end
             """

      assert render_string!("""
             begin<!-- <div><%= 123 %></div> -->end
             """) == """
             begin<!-- <div>123</div> -->end
             """
    end
  end

  describe "attrs" do
    test "boolean - static" do
      assert render_string!("Hello <p hidden>world!</p>") == "Hello <p hidden>world!</p>"
    end

    test "boolean - dynamic" do
      assert render_string!("Hello <p hidden={true}>world!</p>") == "Hello <p hidden>world!</p>"
      assert render_string!("Hello <p hidden={false}>world!</p>") == "Hello <p>world!</p>"
      assert render_string!("Hello <p hidden={nil}>world!</p>") == "Hello <p>world!</p>"
    end

    test "string - static" do
      assert render_string!("""
             Hello <p name="value">world!</p>
             """) == ~S|Hello <p name="value">world!</p>|
    end

    test "string - static - leave the quotation marks unchanged" do
      assert render_string!("""
             Hello <p name="value">world!</p>
             """) == ~S|Hello <p name="value">world!</p>|

      assert render_string!("""
             Hello <p name='value'>world!</p>
             """) == ~S|Hello <p name='value'>world!</p>|
    end

    test "string - static - leave special chars unchanged" do
      assert render_string!("""
             <p name="1 < 2">content</p>
             """) == ~S|<p name="1 < 2">content</p>|

      assert render_string!("""
             <p name="1 < 2"/>
             """) == ~S|<p name="1 < 2"></p>|
    end

    test "string - dynamic" do
      assert render_string!("""
             <p name={"string"}>content</p>
             """) == ~S|<p name="string">content</p>|

      assert render_string!("""
             <p name={1024}>content</p>
             """) == ~S|<p name="1024">content</p>|
    end

    test "string - dynamic - escape unsafe values" do
      assert render_string!("""
             <p name={"<value>"}>content</p>
             """) == ~S|<p name="&lt;value&gt;">content</p>|

      assert render_string!("""
             <p name={"1 < 2"}>content</p>
             """) == ~S|<p name="1 &lt; 2">content</p>|
    end

    test "string - dynamic - keep safe values unchanged" do
      assert render_string!("""
             <p name={{:safe, "<value>"}}>content</p>
             """) == ~S|<p name="<value>">content</p>|

      assert render_string!("""
             <p name={{:safe, "1 < 2"}}>content</p>
             """) == ~S|<p name="1 < 2">content</p>|
    end

    test "root attrs" do
      assert render_string!(
               """
               <p {assigns.attrs}>content</p>
               """,
               %{attrs: %{}}
             ) ==
               ~S|<p>content</p>|

      assert render_string!(
               """
               <p {assigns.attrs}>content</p>
               """,
               %{attrs: [string: "string", number: 1024]}
             ) ==
               ~S|<p string="string" number="1024">content</p>|
    end

    test "root attrs - leave underscores of attr names unchanged" do
      assert render_string!(
               """
               <p {assigns.attrs}>content</p>
               """,
               %{attrs: [long_string: "string", big_number: 1024]}
             ) ==
               ~S|<p long_string="string" big_number="1024">content</p>|
    end

    test "root attrs - escape keys and values" do
      assert render_string!("<div {@rest} />", %{
               rest: [{"key1", "value1"}]
             }) == ~S|<div key1="value1"></div>|

      assert render_string!("<div {@rest} />", %{
               rest: [{"<key2>", "value2"}]
             }) == ~S|<div &lt;key2&gt;="value2"></div>|

      assert render_string!("<div {@rest} />", %{
               rest: [{"key3", "<value3>"}]
             }) == ~S|<div key3="&lt;value3&gt;"></div>|

      assert render_string!("<div {@rest} />", %{
               rest: [{{:safe, "<key4>"}, {:safe, "<value4>"}}]
             }) == ~S|<div <key4>="<value4>"></div>|
    end

    test "root attrs - keep the order of attrs" do
      assert render_string!(
               """
               <div {assigns.attrs1} sd1={1} s1="1" {assigns.attrs2} s2="2" sd2={2} />
               """,
               %{attrs1: [d1: "1"], attrs2: [d2: "2"]}
             ) ==
               ~S|<div d1="1" sd1="1" s1="1" d2="2" s2="2" sd2="2"></div>|
    end

    test "allows expression with curly braces" do
      assert render_string!("""
             <p name={elem({"string"}, 0)}>content</p>
             """) == ~S|<p name="string">content</p>|
    end
  end

  describe "assigns" do
    test "basic usage" do
      assert render_string!("<%= assigns[:msg] %>", %{msg: "<hello>"}) == "&lt;hello&gt;"
      assert render_string!("<%= assigns.msg %>", %{msg: "<hello>"}) == "&lt;hello&gt;"

      assert render_string!("<%= Access.get(assigns, :msg) %>", %{msg: "<hello>"}) ==
               "&lt;hello&gt;"

      assert render_string!("<%= assigns[:missing] %>", %{msg: "<hello>"}) == ""
    end

    test "sugar syntax - @" do
      assert render_string!("<%= @msg %>", %{msg: "<hello>"}) == "&lt;hello&gt;"
    end

    test "raises KeyError for missing assigns" do
      assert_raise KeyError,
                   "assign @msg not available in template.\n\nAvailable assigns: []\n",
                   fn ->
                     render_string!("<%= @msg %>", %{})
                   end
    end
  end

  describe "component" do
    test "with remote call" do
      assert render_string!("""
             <ComboTest.Template.CEExEngine.Helper.inspector key="1" />
             """) == ~S"""
             ---
             [ATTRS]
             key: "1"
             [SLOTS]
             n/a
             """

      assert render_string!("""
             <ComboTest.Template.CEExEngine.Helper.inspector key="1">
               content
             </ComboTest.Template.CEExEngine.Helper.inspector>
             """) == ~S"""
             ---
             [ATTRS]
             key: "1"
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "\n  content\n"
             """
    end

    test "with remote call via an alias" do
      assert render_string!("""
             <Helper.inspector key="1" />
             """) == ~S"""
             ---
             [ATTRS]
             key: "1"
             [SLOTS]
             n/a
             """

      assert render_string!("""
             <Helper.inspector key="1">
               content
             </Helper.inspector>
             """) == ~S"""
             ---
             [ATTRS]
             key: "1"
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "\n  content\n"
             """
    end

    test "with local call" do
      assert render_string!("""
             <.inspector key="1" />
             """) == ~S"""
             ---
             [ATTRS]
             key: "1"
             [SLOTS]
             n/a
             """

      assert render_string!("""
             <.inspector key="1">
               content
             </.inspector>
             """) == ~S"""
             ---
             [ATTRS]
             key: "1"
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "\n  content\n"
             """
    end
  end

  describe "default slot" do
    test "stores its name in __slot__" do
      assert render_string!("""
             <.inspector :let={entry}>{{:safe, inspect(entry.__slot__)}}</.inspector>
             """) == ~S"""
             ---
             [ATTRS]
             n/a
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: ":inner_block"
             """
    end

    test "without arg" do
      assert render_string!("""
             <.inspector>content</.inspector>
             """) == ~S"""
             ---
             [ATTRS]
             n/a
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "content"
             """
    end

    test "with arg" do
      assert render_string!("""
             <.inspector :let={inner_block}>
               {inner_block.__slot__ |> to_string() |> String.upcase()}
             </.inspector>
             """) == ~S"""
             ---
             [ATTRS]
             n/a
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "\n  INNER_BLOCK\n"
             """
    end
  end

  describe "named slot (self-closing)" do
    # Self-closing named slot doesn't support rendering inner_block, hence it's
    # not able to reuse inspector component, and this component is created for
    # this test.
    defp c_render_self_closing_slot_name(assigns) do
      compile_string!("<%= for entry <- @entry do %>[<%= entry.__slot__ %>]<% end %>")
    end

    test "stores its name in __slot__" do
      assert render_string!("""
             <.c_render_self_closing_slot_name>
               <:entry />
               <:entry />
             </.c_render_self_closing_slot_name>
             """) == "[entry][entry]"
    end

    test "with inner block" do
      # unsupported
    end

    test "with args" do
      # unsupported
    end

    test "with attrs" do
      assert render_string!("""
             <.inspector>
               <:sample id="1" />
               <:sample id="2" />
             </.inspector>
             """) == ~S"""
             ---
             [ATTRS]
             n/a
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "\n  "
             sample:
             * entry 1:
               - attrs:
                 id: "1"
               - rendered: n/a
             * entry 2:
               - attrs:
                 id: "2"
               - rendered: n/a
             """
    end
  end

  describe "named slot" do
    test "stores its name in __slot__" do
      assert render_string!("""
             <.inspector>
               <:entry :let={entry}>{{:safe, inspect(entry.__slot__)}}</:entry>
               <:entry :let={entry}>{{:safe, inspect(entry.__slot__)}}</:entry>
             </.inspector>
             """) == ~S"""
             ---
             [ATTRS]
             n/a
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "\n  "
             entry:
             * entry 1:
               - attrs: n/a
               - rendered: ":entry"
             * entry 2:
               - attrs: n/a
               - rendered: ":entry"
             """
    end

    test "with inner block" do
      assert render_string!("""
             <.inspector>
               <:sample>
                 content 1
               </:sample>
               <:sample>
                 content 2
               </:sample>
             </.inspector>
             """) == ~S"""
             ---
             [ATTRS]
             n/a
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "\n  "
             sample:
             * entry 1:
               - attrs: n/a
               - rendered: "\n    content 1\n  "
             * entry 2:
               - attrs: n/a
               - rendered: "\n    content 2\n  "
             """
    end

    test "with arg" do
      assert render_string!("""
             <.inspector>
               <:sample :let={entry}>
                 content 1
                 {to_string(entry.__slot__)}
               </:sample>
               <:sample :let={entry}>
                 content 2
                 {to_string(entry.__slot__)}
               </:sample>
             </.inspector>
             """) == ~S"""
             ---
             [ATTRS]
             n/a
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "\n  "
             sample:
             * entry 1:
               - attrs: n/a
               - rendered: "\n    content 1\n    sample\n  "
             * entry 2:
               - attrs: n/a
               - rendered: "\n    content 2\n    sample\n  "
             """
    end

    test "with attrs" do
      assert render_string!(
               """
               <.inspector>
                 <:sample a={@a} b="B">content</:sample>
               </.inspector>
               """,
               %{a: "A"}
             ) == ~S"""
             ---
             [ATTRS]
             n/a
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "\n  "
             sample:
             * entry 1:
               - attrs:
                 a: "A"
                 b: "B"
               - rendered: "content"
             """
    end

    test "with nesting components" do
      inner = ~S"""
      ---
      [ATTRS]
      n/a
      [SLOTS]
      inner_block:
      * entry 1:
        - attrs: n/a
        - rendered: "\n      "
      sample:
      * entry 1:
        - attrs: n/a
        - rendered: "\n        inner\n      "
      """

      assert render_string!("""
             <.inspector>
               <:sample>
                 outer
                 <.inspector>
                   <:sample>
                     inner
                   </:sample>
                 </.inspector>
               </:sample>
             </.inspector>
             """) == ~s"""
             ---
             [ATTRS]
             n/a
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "\\n  "
             sample:
             * entry 1:
               - attrs: n/a
               - rendered: "\\n    outer\\n    #{escape(inner)}\\n  "
             """
    end

    test "raises on slots without inner block" do
      message = ~r"attempted to render slot :sample but the slot has no inner block"

      assert_raise RuntimeError, message, fn ->
        render_string!("""
        <.inspector>
          <:sample render_inner_block={:force} />
        </.inspector>
        """)
      end

      assert_raise RuntimeError, message, fn ->
        render_string!("""
        <.inspector>
          <:sample render_inner_block={:force} />
          <:sample render_inner_block={:force} />
        </.inspector>

        """)
      end
    end

    test "raises on passing unmatched args to slot" do
      message = ~r"""
      cannot match arguments sent from render_slot/2 against the pattern in :let.

      Expected a value matching `%{wrong: _}`, got: %{.*}\
      """

      assert_raise RuntimeError, message, fn ->
        render_string!("""
        <.inspector :let={%{wrong: _}}>
          ...
        </.inspector>
        """)
      end
    end
  end

  test "multiple named slots" do
    assert render_string!("""
           BEGIN
           <.inspector>
             <:header>
               The header content
             </:header>
             <:footer>
               The footer content
             </:footer>
           </.inspector>
           END
           """) == ~S"""
           BEGIN
           ---
           [ATTRS]
           n/a
           [SLOTS]
           inner_block:
           * entry 1:
             - attrs: n/a
             - rendered: "\n  "
           footer:
           * entry 1:
             - attrs: n/a
             - rendered: "\n    The footer content\n  "
           header:
           * entry 1:
             - attrs: n/a
             - rendered: "\n    The header content\n  "

           END
           """
  end

  test "default and named slots" do
    assert render_string!(
             """
             BEGIN
             <.inspector>
               top
               <:header>
                 The header content
               </:header>
               foo <%= @middle %> bar
               <:footer>
                 The footer content
               </:footer>
               bottom
             </.inspector>
             END
             """,
             %{middle: "middle"}
           ) == ~S"""
           BEGIN
           ---
           [ATTRS]
           n/a
           [SLOTS]
           inner_block:
           * entry 1:
             - attrs: n/a
             - rendered: "\n  top\n  foo middle bar\n  bottom\n"
           footer:
           * entry 1:
             - attrs: n/a
             - rendered: "\n    The footer content\n  "
           header:
           * entry 1:
             - attrs: n/a
             - rendered: "\n    The header content\n  "

           END
           """
  end

  describe "special attr - :if" do
    test "for HTML tags" do
      assert render_string!(
               """
               <div :if={@flag} id="test" />
               """,
               %{flag: true}
             ) == """
             <div id="test"></div>\
             """

      assert render_string!(
               """
               <div :if={!@flag} id="test" />
               """,
               %{flag: true}
             ) == ""

      assert render_string!(
               """
               <div :if={@flag} id="test">content</div>
               """,
               %{flag: true}
             ) == """
             <div id=\"test\">content</div>\
             """

      assert render_string!(
               """
               <div :if={!@flag} id="test">content</div>
               """,
               %{flag: true}
             ) == ""
    end

    test "for components" do
      assert render_string!(
               """
               <.inspector attr="1" :if={@flag} />
               """,
               %{flag: true}
             ) == ~S"""
             ---
             [ATTRS]
             attr: "1"
             [SLOTS]
             n/a
             """

      assert render_string!(
               """
               <.inspector attr="1" :if={!@flag}>content</.inspector>
               """,
               %{flag: true}
             ) == ""
    end

    test "for slots" do
      assert render_string!(
               """
               <.inspector>
                 <:entry :if={@flag} attr="1" />
                 <:entry :if={!@flag} attr="2" />
                 <:entry :if={@flag} attr="3" />
               </.inspector>
               """,
               %{flag: true}
             ) == ~S"""
             ---
             [ATTRS]
             n/a
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "\n  "
             entry:
             * entry 1:
               - attrs:
                 attr: "1"
               - rendered: n/a
             * entry 2:
               - attrs:
                 attr: "3"
               - rendered: n/a
             """

      assert render_string!(
               """
               <.inspector>
                 <:entry :if={@flag}>content for slot entry 1</:entry>
                 <:entry :if={!@flag}>content for slot entry 2</:entry>
                 <:entry :if={@flag}>content for slot entry 3</:entry>
               </.inspector>
               """,
               %{flag: true}
             ) == ~S"""
             ---
             [ATTRS]
             n/a
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "\n  "
             entry:
             * entry 1:
               - attrs: n/a
               - rendered: "content for slot entry 1"
             * entry 2:
               - attrs: n/a
               - rendered: "content for slot entry 3"
             """
    end
  end

  describe "special attr - :for" do
    test "for HTML tags" do
      assert render_string!(
               """
               <div :for={i <- @items} id={"i" <> to_string(i)} />
               """,
               %{items: 1..3}
             ) == """
             <div id="i1"></div><div id="i2"></div><div id="i3"></div>\
             """

      assert render_string!(
               """
               <div :for={i <- @items} id={"i" <> to_string(i)}>c{i}</div>
               """,
               %{items: 1..3}
             ) == """
             <div id="i1">c1</div><div id="i2">c2</div><div id="i3">c3</div>\
             """
    end

    test "for components" do
      assert render_string!(
               """
               <.inspector :for={i <- @items} attr={i} />
               """,
               %{items: 1..3}
             ) == ~S"""
             ---
             [ATTRS]
             attr: 1
             [SLOTS]
             n/a
             ---
             [ATTRS]
             attr: 2
             [SLOTS]
             n/a
             ---
             [ATTRS]
             attr: 3
             [SLOTS]
             n/a
             """

      assert render_string!(
               """
               <.inspector :for={i <- @items} attr={i}>content for component {i}</.inspector>
               """,
               %{items: 1..3}
             ) == ~S"""
             ---
             [ATTRS]
             attr: 1
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "content for component 1"
             ---
             [ATTRS]
             attr: 2
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "content for component 2"
             ---
             [ATTRS]
             attr: 3
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "content for component 3"
             """
    end

    test "for slots" do
      assert render_string!(
               """
               <.inspector>
                 <:entry :for={i <- @items} attr={i}>content for slot entry {i}</:entry>
               </.inspector>
               """,
               %{items: 1..3}
             ) == ~S"""
             ---
             [ATTRS]
             n/a
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "\n  "
             entry:
             * entry 1:
               - attrs:
                 attr: 1
               - rendered: "content for slot entry 1"
             * entry 2:
               - attrs:
                 attr: 2
               - rendered: "content for slot entry 2"
             * entry 3:
               - attrs:
                 attr: 3
               - rendered: "content for slot entry 3"
             """
    end
  end

  describe "special attrs - :for and :if together" do
    test "for HTML tags" do
      assert render_string!(
               """
               <div :for={i <- @items} :if={rem(i, 2) == 0} id={"i" <> to_string(i)} />
               """,
               %{items: 1..4}
             ) == """
             <div id="i2"></div><div id="i4"></div>\
             """

      assert render_string!(
               """
               <div :for={i <- @items} :if={false} id={"i" <> to_string(i)} />
               """,
               %{items: 1..4}
             ) == ""

      assert render_string!(
               """
               <div :for={i <- @items} :if={rem(i, 2) == 0} id={"i" <> to_string(i)}>c{i}</div>
               """,
               %{items: 1..4}
             ) == """
             <div id="i2">c2</div><div id="i4">c4</div>\
             """

      assert render_string!(
               """
               <div :for={i <- @items} :if={false} id={"i" <> to_string(i)}>c{i}</div>
               """,
               %{items: 1..4}
             ) == ""
    end

    test "for components" do
      assert render_string!(
               """
               <.inspector :for={i <- @items} :if={rem(i, 2) == 0} attr={"i" <> to_string(i)} />
               """,
               %{items: 1..3}
             ) == ~S"""
             ---
             [ATTRS]
             attr: "i2"
             [SLOTS]
             n/a
             """

      assert render_string!(
               """
               <.inspector :for={i <- @items} :if={false} attr={"i" <> to_string(i)} />
               """,
               %{items: 1..3}
             ) == ""

      assert render_string!(
               """
               <.inspector :for={i <- @items} :if={rem(i, 2) == 0} attr={"i" <> to_string(i)}>
                 content for component {i}
               </.inspector>
               """,
               %{items: 1..3}
             ) == ~S"""
             ---
             [ATTRS]
             attr: "i2"
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "\n  content for component 2\n"
             """

      assert render_string!(
               """
               <.inspector :for={i <- @items} :if={false} attr={"i" <> to_string(i)}>
                 content for component {i}
               </.inspector>
               """,
               %{items: 1..3}
             ) == ""
    end

    test "for slots" do
      assert render_string!(
               """
               <.inspector>
                 <:entry :for={i <- @items} :if={rem(i, 2) == 0} attr={"i" <> to_string(i)} />
               </.inspector>
               """,
               %{items: 1..3}
             ) == ~S"""
             ---
             [ATTRS]
             n/a
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "\n  "
             entry:
             * entry 1:
               - attrs:
                 attr: "i2"
               - rendered: n/a
             """

      assert render_string!(
               """
               <.inspector>
                 <:entry :for={i <- @items} :if={false} attr={"i" <> to_string(i)} />
               </.inspector>
               """,
               %{items: 1..3}
             ) == ~S"""
             ---
             [ATTRS]
             n/a
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "\n  "
             """

      assert render_string!(
               """
               <.inspector>
                 <:entry :for={i <- @items} :if={rem(i, 2) == 0} attr={"i" <> to_string(i)}>
                   content for slot entry {i}
                 </:entry>
               </.inspector>
               """,
               %{items: 1..3}
             ) == ~S"""
             ---
             [ATTRS]
             n/a
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "\n  "
             entry:
             * entry 1:
               - attrs:
                 attr: "i2"
               - rendered: "\n    content for slot entry 2\n  "
             """

      assert render_string!(
               """
               <.inspector>
                 <:entry :for={i <- @items} :if={false} attr={"i" <> to_string(i)}>
                   content for slot entry {i}
                 </:entry>
               </.inspector>
               """,
               %{items: 1..3}
             ) == ~S"""
             ---
             [ATTRS]
             n/a
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "\n  "
             """
    end
  end

  describe "special attrs - :for, :if and :let together" do
    test "in one slot" do
      assert render_string!(
               """
               <.inspector>
                 <:entry :for={i <- @items} :if={rem(i, 2) == 0} :let={entry} attr={"i" <> to_string(i)}>
                   ({entry.__slot__}) content for slot entry {i}
                 </:entry>
               </.inspector>
               """,
               %{items: 1..3}
             ) == ~S"""
             ---
             [ATTRS]
             n/a
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "\n  "
             entry:
             * entry 1:
               - attrs:
                 attr: "i2"
               - rendered: "\n    (entry) content for slot entry 2\n  "
             """
    end

    test "in multiple slots, and in a mixed way" do
      assert render_string!(
               """
               <.inspector>
                 <:entry>content for slot entry 1</:entry>
                 <:entry :if={false}>c2</:entry>
                 <:entry :for={i <- @items} :if={rem(i, 2) == 0} attr={"i" <> to_string(i)}>
                   content for slot entry {i}
                 </:entry>
                 <:entry :for={i <- @items} :if={rem(i, 2) != 0} :let={entry} attr={"i" <> to_string(i)}>
                   ({entry.__slot__}) content for slot entry {i}
                 </:entry>
                 <:entry>content for slot entry 7</:entry>
               </.inspector>
               """,
               %{items: 3..6}
             ) == ~S"""
             ---
             [ATTRS]
             n/a
             [SLOTS]
             inner_block:
             * entry 1:
               - attrs: n/a
               - rendered: "\n  "
             entry:
             * entry 1:
               - attrs: n/a
               - rendered: "content for slot entry 1"
             * entry 2:
               - attrs:
                 attr: "i4"
               - rendered: "\n    content for slot entry 4\n  "
             * entry 3:
               - attrs:
                 attr: "i6"
               - rendered: "\n    content for slot entry 6\n  "
             * entry 4:
               - attrs:
                 attr: "i3"
               - rendered: "\n    (entry) content for slot entry 3\n  "
             * entry 5:
               - attrs:
                 attr: "i5"
               - rendered: "\n    (entry) content for slot entry 5\n  "
             * entry 6:
               - attrs: n/a
               - rendered: "content for slot entry 7"
             """
    end
  end

  describe "special attr" do
    test "ceex-no-curly-interpolation disables curly interpolation, and is not rendered" do
      assert render_string!("""
             <div ceex-no-curly-interpolation />
             """) == "<div></div>"

      assert render_string!("""
             <div ceex-no-curly-interpolation>content</div>
             """) == "<div>content</div>"

      assert render_string!("""
             <div ceex-no-curly-interpolation>{open}<%= :eval %>{close}</div>
             """) == "<div>{open}eval{close}</div>"

      assert render_string!("""
             <div ceex-no-curly-interpolation>{open}{<%= :eval %>}{close}</div>
             """) == "<div>{open}{eval}{close}</div>"

      assert render_string!("""
             {:pre}<div ceex-no-curly-interpolation>{open}<%= :eval %>{close}</div>{:post}
             """) == "pre<div>{open}eval{close}</div>post"

      assert render_string!("""
             <div ceex-no-curly-interpolation>{:pre}{open}<%= :eval %>{close}{:post}</div>
             """) == "<div>{:pre}{open}eval{close}{:post}</div>"
    end

    test "ceex-no-format attr is not rendered" do
      assert render_string!("<div ceex-no-format />") == "<div></div>"
      assert render_string!("<div ceex-no-format>content</div>") == "<div>content</div>"
    end
  end

  describe "whitespace suppression at boundaries" do
    test "is disabled for text" do
      assert render_string!("""

               c1

               c2
             """) == "\n  c1\n\n  c2\n"
    end

    test "is enabled for EEx tags" do
      assert render_string!("""

               <%= "c1" %>

               c2
             """) == "c1\n\n  c2\n"

      assert render_string!("""

               c1

               <%= "c2" %>
             """) == "\n  c1\n\n  c2"

      assert render_string!("""

               <%= "c1" %>

               <%= "c2" %>
             """) == "c1\n\n  c2"
    end

    test "is enabled for curly-interpolation" do
      assert render_string!("""

               {"c1"}

               c2
             """) == "c1\n\n  c2\n"

      assert render_string!("""

               c1

               {"c2"}
             """) == "\n  c1\n\n  c2"

      assert render_string!("""

               {"c1"}

               {"c2"}
             """) == "c1\n\n  c2"
    end

    test "is enabled for HTML tags" do
      assert render_string!("""

               <div>c1</div>

               c2
             """) == "<div>c1</div>\n\n  c2\n"

      assert render_string!("""

               c1

               <div>c2</div>
             """) == "\n  c1\n\n  <div>c2</div>"

      assert render_string!("""

               <div>c1</div>

               <div>c2</div>
             """) == "<div>c1</div>\n\n  <div>c2</div>"
    end

      defp c_render_default_slot(assigns) do
      compile_string!("""
      {render_slot(@inner_block)}
      """)
    end

    test "is enabled for components" do
      assert render_string!("""

               <.c_render_default_slot>c1</.c_render_default_slot>

               c2
             """) == "c1\n\n  c2\n"

      assert render_string!("""

               c1

               <.c_render_default_slot>c2</.c_render_default_slot>
             """) == "\n  c1\n\n  c2"

      assert render_string!("""

               <.c_render_default_slot>c1</.c_render_default_slot>

               <.c_render_default_slot>c2</.c_render_default_slot>
             """) == "c1\n\n  c2"
    end

    defp c_render_named_slot(assigns) do
      compile_string!("""
      {render_slot(@entry)}
      """)
    end

    test "is disabled for slots" do
      assert render_string!("""

               <.c_render_named_slot>
                 <:entry>c1.1</:entry>
                 <:entry>c1.2</:entry>
               </.c_render_named_slot>

               c2
             """) == "c1.1c1.2\n\n  c2\n"

      assert render_string!("""

               c1

               <.c_render_named_slot>
                 <:entry>c2.1</:entry>
                 <:entry>c2.2</:entry>
               </.c_render_named_slot>
             """) == "\n  c1\n\n  c2.1c2.2"

      assert render_string!("""

               <.c_render_named_slot>
                 <:entry>c1.1</:entry>
                 <:entry>c1.2</:entry>
               </.c_render_named_slot>

               <.c_render_named_slot>
                 <:entry>c2.1</:entry>
                 <:entry>c2.2</:entry>
               </.c_render_named_slot>
             """) == "c1.1c1.2\n\n  c2.1c2.2"

      assert render_string!("""

               <.c_render_named_slot>
                 <:entry>
                   c1.1
                 </:entry>
                 <:entry>
                   c1.2
                 </:entry>
               </.c_render_named_slot>

               c2
             """) == "\n      c1.1\n    \n      c1.2\n    \n\n  c2\n"

      assert render_string!("""

               c1

               <.c_render_named_slot>
                 <:entry>
                   c2.1
                 </:entry>
                 <:entry>
                   c2.2
                 </:entry>
               </.c_render_named_slot>
             """) == "\n  c1\n\n  \n      c2.1\n    \n      c2.2\n    "

      assert render_string!("""

               <.c_render_named_slot>
                 <:entry>
                   c1.1
                 </:entry>
                 <:entry>
                   c1.2
                 </:entry>
               </.c_render_named_slot>

               <.c_render_named_slot>
                 <:entry>
                   c2.1
                 </:entry>
                 <:entry>
                   c2.2
                 </:entry>
               </.c_render_named_slot>
             """) ==
               "\n      c1.1\n    \n      c1.2\n    \n\n  \n      c2.1\n    \n      c2.2\n    "

      assert render_string!("""

               <.c_render_named_slot>
                 <:entry>
                   <div>c1.1</div>
                 </:entry>
                 <:entry>
                   <div>c1.2</div>
                 </:entry>
               </.c_render_named_slot>

               c2
             """) == "\n      <div>c1.1</div>\n    \n      <div>c1.2</div>\n    \n\n  c2\n"

      assert render_string!("""

               c1

               <.c_render_named_slot>
                 <:entry>
                   <div>c2.1</div>
                 </:entry>
                 <:entry>
                   <div>c2.2</div>
                 </:entry>
               </.c_render_named_slot>
             """) == "\n  c1\n\n  \n      <div>c2.1</div>\n    \n      <div>c2.2</div>\n    "

      assert render_string!("""

               <.c_render_named_slot>
                 <:entry>
                   <div>c1.1</div>
                 </:entry>
                 <:entry>
                   <div>c1.2</div>
                 </:entry>
               </.c_render_named_slot>

               <.c_render_named_slot>
                 <:entry>
                   <div>c2.1</div>
                 </:entry>
                 <:entry>
                   <div>c2.2</div>
                 </:entry>
               </.c_render_named_slot>
             """) ==
               "\n      <div>c1.1</div>\n    \n      <div>c1.2</div>\n    \n\n  \n      <div>c2.1</div>\n    \n      <div>c2.2</div>\n    "
    end
  end
end
