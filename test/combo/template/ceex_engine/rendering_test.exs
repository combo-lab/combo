defmodule Combo.Template.CEExEngine.RenderingTest do
  use ExUnit.Case, async: true

  import ComboTest.Template.CEExEngine.Helper
  alias ComboTest.Template.CEExEngine.Components
  import ComboTest.Template.CEExEngine.Components

  describe "EEx - do-block" do
    test "where static content is treated as safe" do
      assert render_string("""
             <%= Components.do_block do %>
               <p>content</p>
             <% end %>
             """) == "\n  <p>content</p>\n"

      assert render_string("""
             <p><%= Components.do_block do %>content<% end %></p>
             """) == "<p>content</p>"
    end

    test "where dynamic content is treated as unsafe" do
      assert render_string("""
             <%= Components.do_block do %>
               <%= "<p>content</p>" %>
             <% end %>
             """) == "\n  &lt;p&gt;content&lt;/p&gt;\n"
    end
  end

  describe "EEx - more" do
    test "supports non-output expressions" do
      assert render_string(
               """
               <% content = @content %>
               <%= content %>
               """,
               %{content: "<p>content</p>"}
             ) == "\n&lt;p&gt;content&lt;/p&gt;"
    end

    test "supports mixed non-output expressions" do
      assert render_string(
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

  describe "text with" do
    test "with static content" do
      assert render_string("Hello world!") == "Hello world!"
    end

    test "with dynamic content enclosed by EEx notation" do
      assert render_string("""
             Hello <%= "world!" %>
             """) == "Hello world!"
    end

    test "with dynamic content enclosed by curly braces" do
      assert render_string("""
             Hello {"world!"}
             """) == "Hello world!"
    end
  end

  describe "HTML elements" do
    test "with static content" do
      assert render_string("<p>content</p>") == "<p>content</p>"
      assert render_string("<unknown>content</unknown>") == "<unknown>content</unknown>"
    end

    test "with static content and attrs" do
      assert render_string("""
             <p name="value">content</p>
             """) == ~S|<p name="value">content</p>|

      assert render_string("""
             <unknown name="value">content</unknown>
             """) == ~S|<unknown name="value">content</unknown>|
    end

    test "with static content (void)" do
      assert render_string("<br>") == "<br>"
      assert render_string("<br />") == "<br>"
    end

    test "with static content and attrs (void)" do
      assert render_string("<br>") == "<br>"
      assert render_string("<br />") == "<br>"

      assert render_string("""
             <br name="value">
             """) == ~S|<br name="value">|

      assert render_string("""
             <br name="value" />
             """) == ~S|<br name="value">|
    end

    test "as self closed" do
      assert render_string("<p />") == "<p></p>"
      assert render_string("<unknown />") == "<unknown></unknown>"
    end

    test "as self closed with attrs" do
      assert render_string("""
             <p name="value" />
             """) == ~S|<p name="value"></p>|

      assert render_string("""
             <unknown name="value" />
             """) == ~S|<unknown name="value"></unknown>|
    end

    test "dynamic content enclosed by EEx notation" do
      assert render_string("""
             <div><%= "<p>content</p>" %></div>
             """) == "<div>&lt;p&gt;content&lt;/p&gt;</div>"

      assert render_string("""
             <div><%= {:safe, "<p>content</p>"} %></div>
             """) == "<div><p>content</p></div>"
    end

    test "dynamic content enclosed by curly braces" do
      assert render_string("""
             <div>{"<p>content</p>"}</div>
             """) == "<div>&lt;p&gt;content&lt;/p&gt;</div>"

      assert render_string("""
             <div>{{:safe, "<p>content</p>"}}</div>
             """) == "<div><p>content</p></div>"
    end
  end

  describe "special HTML elements" do
    test "curly interpolation is disabled for <style>" do
      assert render_string("""
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
      assert render_string("""
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
      assert render_string("""
             begin<!-- <%= 123 %> -->end
             """) == """
             begin<!-- 123 -->end
             """

      assert render_string("""
             begin<!-- <div><%= 123 %></div> -->end
             """) == """
             begin<!-- <div>123</div> -->end
             """
    end
  end

  describe "attrs" do
    test "boolean - static" do
      assert render_string("Hello <p hidden>world!</p>") == "Hello <p hidden>world!</p>"
    end

    test "boolean - dynamic" do
      assert render_string("Hello <p hidden={true}>world!</p>") == "Hello <p hidden>world!</p>"
      assert render_string("Hello <p hidden={false}>world!</p>") == "Hello <p>world!</p>"
      assert render_string("Hello <p hidden={nil}>world!</p>") == "Hello <p>world!</p>"
    end

    test "string - static" do
      assert render_string("""
             Hello <p name="value">world!</p>
             """) == ~S|Hello <p name="value">world!</p>|
    end

    test "string - static - leave the quotation marks unchanged" do
      assert render_string("""
             Hello <p name="value">world!</p>
             """) == ~S|Hello <p name="value">world!</p>|

      assert render_string("""
             Hello <p name='value'>world!</p>
             """) == ~S|Hello <p name='value'>world!</p>|
    end

    test "string - static - leave special chars unchanged" do
      assert render_string("""
             <p name="1 < 2">content</p>
             """) == ~S|<p name="1 < 2">content</p>|

      assert render_string("""
             <p name="1 < 2"/>
             """) == ~S|<p name="1 < 2"></p>|
    end

    test "string - dynamic" do
      assert render_string("""
             <p name={"string"}>content</p>
             """) == ~S|<p name="string">content</p>|

      assert render_string("""
             <p name={1024}>content</p>
             """) == ~S|<p name="1024">content</p>|
    end

    test "string - dynamic - escape unsafe values" do
      assert render_string("""
             <p name={"<value>"}>content</p>
             """) == ~S|<p name="&lt;value&gt;">content</p>|

      assert render_string("""
             <p name={"1 < 2"}>content</p>
             """) == ~S|<p name="1 &lt; 2">content</p>|
    end

    test "string - dynamic - keep safe values unchanged" do
      assert render_string("""
             <p name={{:safe, "<value>"}}>content</p>
             """) == ~S|<p name="<value>">content</p>|

      assert render_string("""
             <p name={{:safe, "1 < 2"}}>content</p>
             """) == ~S|<p name="1 < 2">content</p>|
    end

    test "root attrs" do
      assert render_string(
               """
               <p {assigns.attrs}>content</p>
               """,
               %{attrs: %{}}
             ) ==
               ~S|<p>content</p>|

      assert render_string(
               """
               <p {assigns.attrs}>content</p>
               """,
               %{attrs: [string: "string", number: 1024]}
             ) ==
               ~S|<p string="string" number="1024">content</p>|
    end

    test "root attrs - leave underscores of attr names unchanged" do
      assert render_string(
               """
               <p {assigns.attrs}>content</p>
               """,
               %{attrs: [long_string: "string", big_number: 1024]}
             ) ==
               ~S|<p long_string="string" big_number="1024">content</p>|
    end

    test "root attrs - escape keys and values" do
      assert render_string("<div {@rest} />", %{
               rest: [{"key1", "value1"}]
             }) == ~S|<div key1="value1"></div>|

      assert render_string("<div {@rest} />", %{
               rest: [{"<key2>", "value2"}]
             }) == ~S|<div &lt;key2&gt;="value2"></div>|

      assert render_string("<div {@rest} />", %{
               rest: [{"key3", "<value3>"}]
             }) == ~S|<div key3="&lt;value3&gt;"></div>|

      assert render_string("<div {@rest} />", %{
               rest: [{{:safe, "<key4>"}, {:safe, "<value4>"}}]
             }) == ~S|<div <key4>="<value4>"></div>|
    end

    test "root attrs - keep the order of attrs" do
      assert render_string(
               """
               <div {assigns.attrs1} sd1={1} s1="1" {assigns.attrs2} s2="2" sd2={2} />
               """,
               %{attrs1: [d1: "1"], attrs2: [d2: "2"]}
             ) ==
               ~S|<div d1="1" sd1="1" s1="1" d2="2" s2="2" sd2="2"></div>|
    end

    test "using expression with curly braces" do
      assert render_string("""
             <p name={elem({"string"}, 0)}>content</p>
             """) == ~S|<p name="string">content</p>|
    end
  end

  describe "assigns" do
    test "basic usage" do
      assert render_string("<%= assigns[:msg] %>", %{msg: "<hello>"}) == "&lt;hello&gt;"
      assert render_string("<%= assigns.msg %>", %{msg: "<hello>"}) == "&lt;hello&gt;"

      assert render_string("<%= Access.get(assigns, :msg) %>", %{msg: "<hello>"}) ==
               "&lt;hello&gt;"

      assert render_string("<%= assigns[:missing] %>", %{msg: "<hello>"}) == ""
    end

    test "sugar syntax - @" do
      assert render_string("<%= @msg %>", %{msg: "<hello>"}) == "&lt;hello&gt;"
    end

    test "raises KeyError for missing assigns" do
      assert_raise KeyError,
                   "assign @msg not available in template.\n\nAvailable assigns: []\n",
                   fn ->
                     render_string("<%= @msg %>", %{})
                   end
    end
  end

  describe "component" do
    test "with remote call" do
      assert render_string("""
             <ComboTest.Template.CEExEngine.Components.inspect_c attr="1" />
             """) == "<div>1:NA</div>"

      assert render_string("""
             <ComboTest.Template.CEExEngine.Components.inspect_c attr="1">
               content
             </ComboTest.Template.CEExEngine.Components.inspect_c>
             """) == "<div>1:\n  content\n</div>"
    end

    test "with remote call via an alias" do
      assert render_string("""
             <Components.inspect_c attr="1" />
             """) == "<div>1:NA</div>"

      assert render_string("""
             <Components.inspect_c attr="1">
               content
             </Components.inspect_c>
             """) == "<div>1:\n  content\n</div>"
    end

    test "with local call" do
      assert render_string("""
             <.inspect_c attr="1" />
             """) == "<div>1:NA</div>"

      assert render_string("""
             <.inspect_c attr="1">
               content
             </.inspect_c>
             """) == "<div>1:\n  content\n</div>"
    end
  end

  describe "default slot" do
    test "-" do
      assert render_string("""
             <.component_with_default_slot value="1">content</.component_with_default_slot>
             """) == """
             [COMPONENT_WITH_DEFAULT_SLOT]

             Value:
             "1"

             Inner block:
             content\
             """
    end

    test "with args" do
      assert render_string("""
             <.component_with_default_slot_args
               value="aBcD"
               :let={%{upcase: upcase, downcase: downcase}}
             >
               Upcase: <%= upcase %>
               Downcase: <%= downcase %>
             </.component_with_default_slot_args>
             """) == """
             [COMPONENT_WITH_DEFAULT_SLOT_ARGS]

             Value:
             "aBcD"

             Inner block:

               Upcase: "ABCD"
               Downcase: "abcd"
             """
    end
  end

  describe "named slots (self-closed)" do
    test "with inner block" do
      # unsupported
    end

    test "with args" do
      # unsupported
    end

    test "with attrs" do
      expected = """

        1

        2
      """

      assert render_string("""
             <Components.component_with_self_closed_named_slot>
               <:sample id="1" />
               <:sample id="2" />
             </Components.component_with_self_closed_named_slot>
             """) == expected

      assert render_string("""
             <.component_with_self_closed_named_slot>
               <:sample id="1" />
               <:sample id="2" />
             </.component_with_self_closed_named_slot>
             """) == expected
    end
  end

  describe "named slots" do
    test "with inner block" do
      expected = """
      COMPONENT WITH SLOTS:
      BEFORE SLOT

          The sample slot
        \

      AFTER SLOT
      """

      assert render_string("""
             COMPONENT WITH SLOTS:
             <Components.component_with_named_slot>
               <:sample>
                 The sample slot
               </:sample>
             </Components.component_with_named_slot>
             """) == expected

      assert render_string("""
             COMPONENT WITH SLOTS:
             <.component_with_named_slot>
               <:sample>
                 The sample slot
               </:sample>
             </.component_with_named_slot>
             """) == expected
    end

    test "with args" do
      expected = """
      COMPONENT WITH SLOTS:
      BEFORE SLOT

          The sample slot
          Arg: 1
        \

      AFTER SLOT
      """

      assert render_string("""
             COMPONENT WITH SLOTS:
             <Components.component_with_named_slot_args>
               <:sample :let={arg}>
                 The sample slot
                 Arg: <%= arg %>
               </:sample>
             </Components.component_with_named_slot_args>
             """) == expected

      assert render_string("""
             COMPONENT WITH SLOTS:
             <.component_with_named_slot_args>
               <:sample :let={arg}>
                 The sample slot
                 Arg: <%= arg %>
               </:sample>
             </.component_with_named_slot_args>
             """) == expected
    end

    test "with attrs" do
      expected = "\nA\n and \nB\n"

      assert render_string(
               """
               <Components.component_with_named_slot_attrs>
                 <:sample a={@a} b="B"> and </:sample>
               </Components.component_with_named_slot_attrs>
               """,
               %{a: "A"}
             ) == expected

      assert render_string(
               """
               <.component_with_named_slot_attrs>
                 <:sample a={@a} b="B"> and </:sample>
               </.component_with_named_slot_attrs>
               """,
               %{a: "A"}
             ) == expected
    end

    test "with multiple slot entries which are handled by implicit list rendering provided by render_slot/2" do
      expected = """
      COMPONENT WITH SLOTS:
      BEFORE SLOT

          one
        \

          two
        \

      AFTER SLOT
      """

      assert render_string("""
             COMPONENT WITH SLOTS:
             <Components.component_with_named_slot_implicit_list_rendering>
               <:sample>
                 one
               </:sample>
               <:sample>
                 two
               </:sample>
             </Components.component_with_named_slot_implicit_list_rendering>
             """) == expected

      assert render_string("""
             COMPONENT WITH SLOTS:
             <.component_with_named_slot_implicit_list_rendering>
               <:sample>
                 one
               </:sample>
               <:sample>
                 two
               </:sample>
             </.component_with_named_slot_implicit_list_rendering>
             """) == expected
    end

    test "with multiple slot entries which are handled by an explicit for comprehension" do
      expected = """
      COMPONENT WITH SLOTS:
      BEFORE SLOT

        one

        two

      AFTER SLOT
      """

      assert render_string("""
             COMPONENT WITH SLOTS:
             <Components.component_with_named_slot_explicit_list_rendering>
               <:sample>one</:sample>
               <:sample>two</:sample>
             </Components.component_with_named_slot_explicit_list_rendering>
             """) == expected

      assert render_string("""
             COMPONENT WITH SLOTS:
             <.component_with_named_slot_explicit_list_rendering>
               <:sample>one</:sample>
               <:sample>two</:sample>
             </.component_with_named_slot_explicit_list_rendering>
             """) == expected
    end

    test "with nesting components" do
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

      assert render_string("""
             <Components.component_with_named_slot>
               <:sample>
                The outer slot
                 <Components.component_with_named_slot>
                   <:sample>
                   The inner slot
                   </:sample>
                 </Components.component_with_named_slot>
               </:sample>
             </Components.component_with_named_slot>
             """) == expected

      assert render_string("""
             <.component_with_named_slot>
               <:sample>
                The outer slot
                 <.component_with_named_slot>
                   <:sample>
                   The inner slot
                   </:sample>
                 </.component_with_named_slot>
               </:sample>
             </.component_with_named_slot>
             """) == expected
    end

    test "raises on slots without inner block" do
      message = ~r"attempted to render slot :sample but the slot has no inner content"

      assert_raise(RuntimeError, message, fn ->
        render_string("""
        <Components.component_with_named_slot>
          <:sample />
        </Components.component_with_named_slot>
        """)
      end)

      assert_raise(RuntimeError, message, fn ->
        render_string("""
        <Components.component_with_named_slot>
          <:sample />
          <:sample />
        </Components.component_with_named_slot>
        """)
      end)

      assert_raise(RuntimeError, message, fn ->
        render_string("""
        <.component_with_named_slot>
          <:sample/>
        </.component_with_named_slot>
        """)
      end)

      assert_raise(RuntimeError, message, fn ->
        render_string("""
        <.component_with_named_slot>
          <:sample/>
          <:sample/>
        </.component_with_named_slot>
        """)
      end)
    end

    test "raises on passing unmatched args to slot" do
      message = """
      cannot match arguments sent from render_slot/2 against the pattern in :let.

      Expected a value matching `%{wrong: _}`, got: %{downcase: {:safe, "\\"abcd\\""}, upcase: {:safe, "\\"ABCD\\""}}\
      """

      assert_raise(RuntimeError, message, fn ->
        render_string("""
        <.component_with_default_slot_args
          value="aBcD"
          :let={%{wrong: _}}
        >
          ...
        </.component_with_default_slot_args>
        """)
      end)
    end
  end

  test "multiple named slots" do
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

    assert render_string("""
           BEFORE COMPONENT
           <Components.component_with_named_slots>
             <:header>
               The header content
             </:header>
             <:footer>
               The footer content
             </:footer>
           </Components.component_with_named_slots>
           AFTER COMPONENT
           """) == expected

    assert render_string("""
           BEFORE COMPONENT
           <.component_with_named_slots>
             <:header>
               The header content
             </:header>
             <:footer>
               The footer content
             </:footer>
           </.component_with_named_slots>
           AFTER COMPONENT
           """) == expected
  end

  test "default and multiple named slots" do
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

    assert render_string(
             """
             BEFORE COMPONENT
             <Components.component_with_default_and_named_slots>
               top
               <:header>
                 The header content
               </:header>
               foo <%= @middle %> bar
               <:footer>
                 The footer content
               </:footer>
               bot
             </Components.component_with_default_and_named_slots>
             AFTER COMPONENT
             """,
             %{middle: "middle"}
           ) == expected

    assert render_string(
             """
             BEFORE COMPONENT
             <.component_with_default_and_named_slots>
               top
               <:header>
                 The header content
               </:header>
               foo <%= @middle %> bar
               <:footer>
                 The footer content
               </:footer>
               bot
             </.component_with_default_and_named_slots>
             AFTER COMPONENT
             """,
             %{middle: "middle"}
           ) == expected
  end

  describe "special attr - :if" do
    test "for HTML tags" do
      assert render_string(
               """
               <div :if={@flag} id="test" />
               """,
               %{flag: true}
             ) == """
             <div id="test"></div>\
             """

      assert render_string(
               """
               <div :if={!@flag} id="test" />
               """,
               %{flag: true}
             ) == ""

      assert render_string(
               """
               <div :if={@flag} id="test">yes</div>
               """,
               %{flag: true}
             ) == """
             <div id=\"test\">yes</div>\
             """

      assert render_string(
               """
               <div :if={!@flag} id="test">yes</div>
               """,
               %{flag: true}
             ) == ""
    end

    test "for components" do
      assert render_string(
               """
               <.component value="123" :if={@flag} />
               """,
               %{flag: true}
             ) == """
             [COMPONENT]

             Value:
             "123"\
             """

      assert render_string(
               """
               <.component value="123" :if={!@flag}>test</.component>
               """,
               %{flag: true}
             ) == ""

      assert render_string(
               """
               <Components.component value="123" :if={@flag} />
               """,
               %{flag: true}
             ) == """
             [COMPONENT]

             Value:
             "123"\
             """

      assert render_string(
               """
               <Components.component value="123" :if={!@flag}>content</Components.component>
               """,
               %{flag: true}
             ) == ""
    end

    test "for slots" do
      assert render_string(
               """
               <.inspector_slot_entries>
                 <:entry :if={@flag}>v1</:entry>
                 <:entry :if={!@flag}>v2</:entry>
                 <:entry :if={@flag}>v3</:entry>
               </.inspector_slot_entries>
               """,
               %{flag: true}
             ) == "<div>begin|NA:v1|NA:v3|end</div>"

      assert render_string(
               """
               <.inspector_slot_entries>
                 <:entry :if={@flag} attr="v1" />
                 <:entry :if={!@flag} attr="v2" />
                 <:entry :if={@flag} attr="v3" />
               </.inspector_slot_entries>
               """,
               %{flag: true}
             ) == "<div>begin|v1:NA|v3:NA|end</div>"
    end
  end

  describe "special attr - :for" do
    test "for HTML tags" do
      assert render_string(
               """
               <div :for={i <- @items} id={"i" <> to_string(i)} />
               """,
               %{items: 1..3}
             ) == """
             <div id="i1"></div><div id="i2"></div><div id="i3"></div>\
             """

      assert render_string(
               """
               <div :for={i <- @items} id={"i" <> to_string(i)}>c{i}</div>
               """,
               %{items: 1..3}
             ) == """
             <div id="i1">c1</div><div id="i2">c2</div><div id="i3">c3</div>\
             """
    end

    test "for components" do
      assert render_string(
               """
               <Components.inspector_component :for={i <- @items} attr={i} />
               """,
               %{items: 1..3}
             ) == "<div>1:NA</div><div>2:NA</div><div>3:NA</div>"

      assert render_string(
               """
               <.inspector_component :for={i <- @items} attr={i} />
               """,
               %{items: 1..3}
             ) == "<div>1:NA</div><div>2:NA</div><div>3:NA</div>"

      assert render_string(
               """
               <Components.inspector_component :for={i <- @items} attr={i}>c{i}</Components.inspector_component>
               """,
               %{items: 1..3}
             ) == "<div>1:c1</div><div>2:c2</div><div>3:c3</div>"

      assert render_string(
               """
               <.inspector_component :for={i <- @items} attr={i}>c{i}</.inspector_component>
               """,
               %{items: 1..3}
             ) == "<div>1:c1</div><div>2:c2</div><div>3:c3</div>"
    end

    test "for slots" do
      assert render_string(
               """
               <.inspector_slot_entries>
                 <:entry :for={i <- @items}>c<%= i %></:entry>
               </.inspector_slot_entries>
               """,
               %{items: 1..3}
             ) == "<div>begin|NA:c1|NA:c2|NA:c3|end</div>"
    end
  end

  describe "special attrs - :for and :if together" do
    test "for HTML tags" do
      assert render_string(
               """
               <div :for={i <- @items} :if={rem(i, 2) == 0} id={"i" <> to_string(i)} />
               """,
               %{items: 1..4}
             ) == """
             <div id="i2"></div><div id="i4"></div>\
             """

      assert render_string(
               """
               <div :for={i <- @items} :if={false} id={"i" <> to_string(i)} />
               """,
               %{items: 1..4}
             ) == ""

      assert render_string(
               """
               <div :for={i <- @items} :if={rem(i, 2) == 0} id={"i" <> to_string(i)}>c{i}</div>
               """,
               %{items: 1..4}
             ) == """
             <div id="i2">c2</div><div id="i4">c4</div>\
             """

      assert render_string(
               """
               <div :for={i <- @items} :if={false} id={"i" <> to_string(i)}>c{i}</div>
               """,
               %{items: 1..4}
             ) == ""
    end

    test "for components" do
      assert render_string(
               """
               <Components.inspector_component :for={i <- @items} :if={rem(i, 2) == 0} attr={"i" <> to_string(i)} />
               """,
               %{items: 1..4}
             ) == """
             <div>i2:NA</div><div>i4:NA</div>\
             """

      assert render_string(
               """
               <Components.inspector_component :for={i <- @items} :if={false} attr={"i" <> to_string(i)} />
               """,
               %{items: 1..4}
             ) == ""

      assert render_string(
               """
               <.inspector_component :for={i <- @items} :if={rem(i, 2) == 0} attr={"i" <> to_string(i)} />
               """,
               %{items: 1..4}
             ) == """
             <div>i2:NA</div><div>i4:NA</div>\
             """

      assert render_string(
               """
               <.inspector_component :for={i <- @items} :if={false} attr={"i" <> to_string(i)} />
               """,
               %{items: 1..4}
             ) == ""

      assert render_string(
               """
               <Components.inspector_component :for={i <- @items} :if={rem(i, 2) == 0} attr={"i" <> to_string(i)}>c{i}</Components.inspector_component>
               """,
               %{items: 1..4}
             ) == """
             <div>i2:c2</div><div>i4:c4</div>\
             """

      assert render_string(
               """
               <Components.inspector_component :for={i <- @items} :if={false} attr={"i" <> to_string(i)}>c{i}</Components.inspector_component>
               """,
               %{items: 1..4}
             ) == ""

      assert render_string(
               """
               <.inspector_component :for={i <- @items} :if={rem(i, 2) == 0} attr={"i" <> to_string(i)}>c{i}</.inspector_component>
               """,
               %{items: 1..4}
             ) == """
             <div>i2:c2</div><div>i4:c4</div>\
             """

      assert render_string(
               """
               <.inspector_component :for={i <- @items} :if={false} attr={"i" <> to_string(i)}>c{i}</.inspector_component>
               """,
               %{items: 1..4}
             ) == ""
    end

    test "for slots" do
      assert render_string(
               """
               <.inspector_slot_entries>
                 <:entry :for={i <- @items} :if={rem(i, 2) == 0} attr={"i" <> to_string(i)} />
               </.inspector_slot_entries>
               """,
               %{items: 1..4}
             ) == "<div>begin|i2:NA|i4:NA|end</div>"

      assert render_string(
               """
               <.inspector_slot_entries>
                 <:entry :for={i <- @items} :if={false} attr={"i" <> to_string(i)} />
               </.inspector_slot_entries>
               """,
               %{items: 1..4}
             ) == "<div>begin|end</div>"

      assert render_string(
               """
               <.inspector_slot_entries>
                 <:entry :for={i <- @items} :if={rem(i, 2) == 0} attr={"i" <> to_string(i)}>c{i}</:entry>
               </.inspector_slot_entries>
               """,
               %{items: 1..4}
             ) == "<div>begin|i2:c2|i4:c4|end</div>"

      assert render_string(
               """
               <.inspector_slot_entries>
                 <:entry :for={i <- @items} :if={false} attr={"i" <> to_string(i)}>c{i}</:entry>
               </.inspector_slot_entries>
               """,
               %{items: 1..4}
             ) == "<div>begin|end</div>"
    end
  end

  describe "special attrs - :for, :if and :let together" do
    test "in one slot" do
      assert render_string(
               """
               <.inspector_slot_entries>
                 <:entry :for={i <- @items} :if={rem(i, 2) == 0} :let={star} attr={"i" <> to_string(i)}>c{i}({star})</:entry>
               </.inspector_slot_entries>
               """,
               %{items: 1..4}
             ) == "<div>begin|i2:c2(*)|i4:c4(*)|end</div>"
    end

    test "in multiple slots, and in a mixed way" do
      assert render_string(
               """
               <.inspector_slot_entries>
                 <:entry>c1</:entry>
                 <:entry :if={false}>c2</:entry>
                 <:entry :for={i <- @items} :if={rem(i, 2) == 0} attr={"i" <> to_string(i)}>c{i}</:entry>
                 <:entry :for={i <- @items} :if={rem(i, 2) != 0} :let={star} attr={"i" <> to_string(i)}>c{i}({star})</:entry>
                 <:entry>c7</:entry>
               </.inspector_slot_entries>
               """,
               %{items: 3..6}
             ) == "<div>begin|NA:c1|i4:c4|i6:c6|i3:c3(*)|i5:c5(*)|NA:c7|end</div>"
    end
  end

  describe "special attrs - ceex-*" do
    test "ceex-no-curly-interpolation for disabling curly interpolation" do
      assert render_string("""
             <div ceex-no-curly-interpolation>content</div>
             """) == "<div>content</div>"

      assert render_string("""
                   <div ceex-no-curly-interpolation />
             """) == "<div></div>"

      assert render_string("""
             <div ceex-no-curly-interpolation>{open}<%= :eval %>{close}</div>
             """) == "<div>{open}eval{close}</div>"

      assert render_string("""
             <div ceex-no-curly-interpolation>{open}{<%= :eval %>}{close}</div>
             """) == "<div>{open}{eval}{close}</div>"

      assert render_string("""
             {:pre}<div ceex-no-curly-interpolation>{open}<%= :eval %>{close}</div>{:post}
             """) == "pre<div>{open}eval{close}</div>post"

      assert render_string("""
             <div ceex-no-curly-interpolation>{:pre}{open}<%= :eval %>{close}{:post}</div>
             """) == "<div>{:pre}{open}eval{close}{:post}</div>"
    end

    test "ceex-no-format for skipping the formatting" do
      assert render_string("<div ceex-no-format>content</div>") == "<div>content</div>"
      assert render_string("<div ceex-no-format />") == "<div></div>"
    end
  end

  describe "whitespace suppression at boundaries" do
    test "for text (disabled)" do
      assert render_string("""

               c1

               c2
             """) == "\n  c1\n\n  c2\n"
    end

    test "for EEx tags (enabled)" do
      assert render_string("""

               <%= "c1" %>

               c2
             """) == "c1\n\n  c2\n"

      assert render_string("""

               c1

               <%= "c2" %>
             """) == "\n  c1\n\n  c2"

      assert render_string("""

               <%= "c1" %>

               <%= "c2" %>
             """) == "c1\n\n  c2"
    end

    test "for curly-interpolation (enabled)" do
      assert render_string("""

               {"c1"}

               c2
             """) == "c1\n\n  c2\n"

      assert render_string("""

               c1

               {"c2"}
             """) == "\n  c1\n\n  c2"

      assert render_string("""

               {"c1"}

               {"c2"}
             """) == "c1\n\n  c2"
    end

    test "for HTML tags (enabled)" do
      assert render_string("""

               <div>c1</div>

               c2
             """) == "<div>c1</div>\n\n  c2\n"

      assert render_string("""

               c1

               <div>c2</div>
             """) == "\n  c1\n\n  <div>c2</div>"

      assert render_string("""

               <div>c1</div>

               <div>c2</div>
             """) == "<div>c1</div>\n\n  <div>c2</div>"
    end

    test "for componets (enabled)" do
      assert render_string("""

               <.c_default_slot>c1</.c_default_slot>

               c2
             """) == "c1\n\n  c2\n"

      assert render_string("""

               c1

               <.c_default_slot>c2</.c_default_slot>
             """) == "\n  c1\n\n  c2"

      assert render_string("""

               <.c_default_slot>c1</.c_default_slot>

               <.c_default_slot>c2</.c_default_slot>
             """) == "c1\n\n  c2"
    end

    test "for slots (disabled)" do
      assert render_string("""

               <.c_named_slot>
                 <:entry>c1.1</:entry>
                 <:entry>c1.2</:entry>
               </.c_named_slot>

               c2
             """) == "c1.1c1.2\n\n  c2\n"

      assert render_string("""

               c1

               <.c_named_slot>
                 <:entry>c2.1</:entry>
                 <:entry>c2.2</:entry>
               </.c_named_slot>
             """) == "\n  c1\n\n  c2.1c2.2"

      assert render_string("""

               <.c_named_slot>
                 <:entry>c1.1</:entry>
                 <:entry>c1.2</:entry>
               </.c_named_slot>

               <.c_named_slot>
                 <:entry>c2.1</:entry>
                 <:entry>c2.2</:entry>
               </.c_named_slot>
             """) == "c1.1c1.2\n\n  c2.1c2.2"

      assert render_string("""

               <.c_named_slot>
                 <:entry>
                   c1.1
                 </:entry>
                 <:entry>
                   c1.2
                 </:entry>
               </.c_named_slot>

               c2
             """) == "\n      c1.1\n    \n      c1.2\n    \n\n  c2\n"

      assert render_string("""

               c1

               <.c_named_slot>
                 <:entry>
                   c2.1
                 </:entry>
                 <:entry>
                   c2.2
                 </:entry>
               </.c_named_slot>
             """) == "\n  c1\n\n  \n      c2.1\n    \n      c2.2\n    "

      assert render_string("""

               <.c_named_slot>
                 <:entry>
                   c1.1
                 </:entry>
                 <:entry>
                   c1.2
                 </:entry>
               </.c_named_slot>

               <.c_named_slot>
                 <:entry>
                   c2.1
                 </:entry>
                 <:entry>
                   c2.2
                 </:entry>
               </.c_named_slot>
             """) ==
               "\n      c1.1\n    \n      c1.2\n    \n\n  \n      c2.1\n    \n      c2.2\n    "

      assert render_string("""

               <.c_named_slot>
                 <:entry>
                   <div>c1.1</div>
                 </:entry>
                 <:entry>
                   <div>c1.2</div>
                 </:entry>
               </.c_named_slot>

               c2
             """) == "\n      <div>c1.1</div>\n    \n      <div>c1.2</div>\n    \n\n  c2\n"

      assert render_string("""

               c1

               <.c_named_slot>
                 <:entry>
                   <div>c2.1</div>
                 </:entry>
                 <:entry>
                   <div>c2.2</div>
                 </:entry>
               </.c_named_slot>
             """) == "\n  c1\n\n  \n      <div>c2.1</div>\n    \n      <div>c2.2</div>\n    "

      assert render_string("""

               <.c_named_slot>
                 <:entry>
                   <div>c1.1</div>
                 </:entry>
                 <:entry>
                   <div>c1.2</div>
                 </:entry>
               </.c_named_slot>

               <.c_named_slot>
                 <:entry>
                   <div>c2.1</div>
                 </:entry>
                 <:entry>
                   <div>c2.2</div>
                 </:entry>
               </.c_named_slot>
             """) ==
               "\n      <div>c1.1</div>\n    \n      <div>c1.2</div>\n    \n\n  \n      <div>c2.1</div>\n    \n      <div>c2.2</div>\n    "
    end
  end
end
