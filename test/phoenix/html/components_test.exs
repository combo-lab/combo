defmodule Phoenix.HTML.ComponentsTest do
  use ExUnit.Case, async: true

  use Phoenix.HTML

  import Combo.HTMLTest, only: [to_x: 1, sigil_X: 2, sigil_x: 2]

  describe "link/1" do
    test "with no href" do
      assigns = %{}

      assert to_x(~CE|<.link>text</.link>|) ==
               ~X|<a href="#">text</a>|
    end

    test "with href" do
      assigns = %{}

      assert to_x(~CE|<.link href="/">text</.link>|) ==
               ~X|<a href="/">text</a>|
    end

    test "with href - #" do
      assigns = %{}

      assert to_x(~CE|<.link href="#">text</.link>|) ==
               ~X|<a href="#">text</a>|
    end

    test "with href - nil" do
      assigns = %{}

      assert to_x(~CE|<.link href={nil} >text</.link>|) ==
               ~X|<a href="#">text</a>|
    end

    test "with href - unsupported scheme" do
      assigns = %{}

      assert to_x(~CE|<.link href={{:javascript, "alert('bad')"}}>js</.link>|) ==
               ~X|<a href="javascript:alert(&#39;bad&#39;)">js</a>|
    end

    test "with href - invalid scheme" do
      assigns = %{}

      assert_raise ArgumentError, ~r/unsupported scheme given to <.link>/, fn ->
        to_x(~CE|<.link href="javascript:alert('bad')">bad</.link>|) ==
          ~X|<a href="/users" data-method="post" data-csrf="123">delete</a>|
      end
    end

    test "global attributes" do
      assigns = %{}

      assert to_x(~CE|<.link href="/" class="foo" data-action="click">text</.link>|) ==
               ~X|<a href="/" class="foo" data-action="click">text</a>|
    end

    test "csrf with get method" do
      assigns = %{}

      assert to_x(~CE|<.link href="/" method="get">text</.link>|) ==
               ~X|<a href="/">text</a>|

      assert to_x(~CE|<.link href="/" method="get" csrf_token="123">text</.link>|) ==
               ~X|<a href="/">text</a>|
    end

    test "csrf with non-get method" do
      assigns = %{}
      csrf = Plug.CSRFProtection.get_csrf_token_for("/users")

      assert to_x(~CE|<.link href="/users" method="delete">delete</.link>|) ==
               ~x|<a href="/users" data-method="delete" data-csrf="#{csrf}" data-to="/users">delete</a>|

      assert to_x(~CE|<.link href="/users" method="delete" csrf_token={true}>delete</.link>|) ==
               ~x|<a href="/users" data-method="delete" data-csrf="#{csrf}" data-to="/users">delete</a>|

      assert to_x(~CE|<.link href="/users" method="delete" csrf_token={false}>delete</.link>|) ==
               ~X|<a href="/users" data-method="delete" data-to="/users">delete</a>|
    end

    test "csrf with custom token" do
      assigns = %{}

      assert to_x(~CE|<.link href="/users" method="post" csrf_token="123">delete</.link>|) ==
               ~X|<a href="/users" data-method="post" data-csrf="123" data-to="/users">delete</a>|
    end
  end

  describe "form/1" do
    test "renders form with prebuilt form" do
      assigns = %{form: to_form(%{})}

      template = ~CE"""
      <.form for={@form}>
        <input id={@form[:foo].id} name={@form[:foo].name} type="text" />
      </.form>
      """

      assert to_x(template) == ~X[<form><input id="foo" name="foo" type="text"></input></form>]
    end

    test "renders form with prebuilt form and :as" do
      assigns = %{form: to_form(%{}, as: :data)}

      template = ~CE"""
      <.form :let={f} for={@form}>
        <input id={f[:foo].id} name={f[:foo].name} type="text" />
      </.form>
      """

      assert to_x(template) ==
               ~X{<form><input id="data_foo" name="data[foo]" type="text"></input></form>}
    end

    test "renders form with prebuilt form and options" do
      assigns = %{form: to_form(%{})}

      template = ~CE"""
      <.form :let={f} for={@form} as={:base} data-foo="bar" class="pretty">
        <input id={f[:foo].id} name={f[:foo].name} type="text" />
      </.form>
      """

      assert to_x(template) ==
               ~X"""
               <form data-foo="bar" class="pretty">
                 <input id="base_foo" name=base[foo] type="text"/>
               </form>
               """
    end

    test "renders form with prebuilt form and errors" do
      assigns = %{form: to_form(%{})}

      template = ~CE"""
      <.form :let={form} for={@form} errors={[name: "can't be blank"]}>
        {inspect(form.errors)}
      </.form>
      """

      assert to_x(template) == [{"form", [], ["\n  \n  \n  \n  [name: \"can't be blank\"]\n\n"]}]
    end

    test "renders form with form data" do
      assigns = %{}

      template = ~CE"""
      <.form :let={f} for={to_form(%{})}>
        <input id={f[:foo].id} name={f[:foo].name} type="text" />
      </.form>
      """

      assert to_x(template) ==
               ~X{<form><input id="foo" name="foo" type="text"></input></form>}
    end

    test "does not raise when action is given and method is missing" do
      assigns = %{}

      template = ~CE"""
      <.form for={to_form(%{})} action="/"></.form>
      """

      csrf_token = Plug.CSRFProtection.get_csrf_token_for("/")

      assert to_x(template) ==
               ~x{<form action="/" method="post"><input name="_csrf_token" type="hidden" hidden="" value="#{csrf_token}"></input></form>}
    end

    test "renders a csrf_token if if an action is set" do
      assigns = %{}

      template = ~CE"""
      <.form :let={f} for={to_form(%{})} action="/">
        <input id={f[:foo].id} name={f[:foo].name} type="text" />
      </.form>
      """

      csrf_token = Plug.CSRFProtection.get_csrf_token_for("/")

      assert to_x(template) ==
               ~x"""
               <form action="/" method="post">
                 <input name="_csrf_token" type="hidden" hidden="" value="#{csrf_token}"></input>
                 <input id="foo" name="foo" type="text"></input>
               </form>
               """
    end

    test "does not generate csrf_token if method is not post or if no action" do
      assigns = %{}

      template = ~CE"""
      <.form :let={f} for={to_form(%{})} method="get" action="/">
        <input id={f[:foo].id} name={f[:foo].name} type="text" />
      </.form>
      """

      assert to_x(template) ==
               ~X"""
               <form action="/" method="get">
                 <input id="foo" name="foo" type="text"></input>
               </form>
               """

      template = ~CE"""
      <.form :let={f} for={to_form(%{})}>
        <input id={f[:foo].id} name={f[:foo].name} type="text" />
      </.form>
      """

      assert to_x(template) ==
               ~X"""
               <form>
                 <input id="foo" name="foo" type="text"></input>
               </form>
               """
    end

    test "renders form with available options and custom attributes" do
      assigns = %{}

      template = ~CE"""
      <.form
        :let={user_form}
        for={to_form(%{})}
        id="form"
        action="/"
        method="put"
        multipart
        csrf_token="123"
        as={:user}
        errors={[name: "can't be blank"]}
        data-foo="bar"
        class="pretty"
      >
        <input id={user_form[:foo].id} name={user_form[:foo].name} type="text" />
        {inspect(user_form.errors)}
      </.form>
      """

      assert to_x(template) ==
               ~X"""
               <form
                 id="form"
                 action="/"
                 method="post"
                 enctype="multipart/form-data"
                 data-foo="bar"
                 class="pretty"
               >
                 <input name="_method" type="hidden" hidden="" value="put">
                 <input name="_csrf_token" type="hidden" hidden="" value="123">
                 <input id="form_foo" name="user[foo]" type="text">
                 [name: "can't be blank"]

               </form>
               """
    end

    test "method is case insensitive when using get or post with action" do
      assigns = %{}

      template = ~CE"""
      <.form for={to_form(%{})} method="GET" action="/"></.form>
      """

      assert to_x(template) ==
               ~x{<form method="get" action="/"></form>}

      template = ~CE"""
      <.form for={to_form(%{})} method="PoST" action="/"></.form>
      """

      csrf = Plug.CSRFProtection.get_csrf_token_for("/")

      assert to_x(template) ==
               ~x{<form method="post" action="/"><input name="_csrf_token" type="hidden" hidden="" value="#{csrf}"></form>}

      # for anything != get or post we use post and set the hidden _method field
      template = ~CE"""
      <.form for={to_form(%{})} method="PuT" action="/"></.form>
      """

      assert to_x(template) ==
               ~x"""
               <form action="/" method="post">
                 <input name="_method" type="hidden" hidden="" value="PuT">
                 <input name="_csrf_token" type="hidden" hidden="" value="#{csrf}">
               </form>
               """
    end
  end

  describe "dynamic_tag/1" do
    test "ensures tag_name are HTML safe" do
      assigns = %{}

      assert_raise ArgumentError, ~r/expected tag_name to be safe HTML/, fn ->
        to_x(~CE|<.dynamic_tag tag_name="p><script>alert('nice try');</script>" />|)
      end
    end

    test "ensures attribute names are escaped" do
      assigns = %{}

      assert to_x(
               ~CE|<.dynamic_tag tag_name="p" {%{"<script>alert('nice try');</script>" => ""}}></.dynamic_tag>|
             ) == ~X|<p &lt;script&gt;alert(&#39;nice try&#39;);&lt;/script&gt;=""></p>|
    end

    test "ensures attribute values are escaped" do
      assigns = %{}

      assert to_x(
               ~CE|<.dynamic_tag tag_name="p" class="<script>alert('nice try');</script>"></.dynamic_tag>|
             ) == ~X|<p class="&lt;script&gt;alert(&#39;nice try&#39;);&lt;/script&gt;"></p>|
    end

    test "with empty inner block" do
      assigns = %{}

      assert to_x(~CE|<.dynamic_tag tag_name="tr"></.dynamic_tag>|) == ~X|<tr></tr>|

      assert to_x(~CE|<.dynamic_tag tag_name="tr" class="foo"></.dynamic_tag>|) ==
               ~X|<tr class="foo"></tr>|
    end

    test "with inner block" do
      assigns = %{}

      assert to_x(~CE|<.dynamic_tag tag_name="tr">content</.dynamic_tag>|) == ~X|<tr>content</tr>|

      assert to_x(~CE|<.dynamic_tag tag_name="tr" class="foo">content</.dynamic_tag>|) ==
               ~X|<tr class="foo">content</tr>|
    end

    test "self closing without inner block" do
      assigns = %{}

      assert to_x(~CE|<.dynamic_tag tag_name="br" />|) == ~X|<br/>|
      assert to_x(~CE|<.dynamic_tag tag_name="input" type="text" />|) == ~X|<input type="text"/>|
    end
  end

  describe "inputs_for/1" do
    test "renders nested inputs with no options" do
      assigns = %{}

      template = ~CE"""
      <.form :let={f} for={to_form(%{})} as={:myform}>
        <.inputs_for :let={finner} field={f[:inner]}>
          <% 0 = finner.index %>
          <input id={finner[:foo].id} name={finner[:foo].name} type="text" />
        </.inputs_for>
      </.form>
      """

      assert to_x(template) ==
               ~X"""
               <form>
                 <input type="hidden" name="myform[inner][_persistent_id]" value="0"> </input>
                 <input id="myform_inner_0_foo" name="myform[inner][foo]" type="text"></input>
               </form>
               """
    end

    test "with naming options" do
      assigns = %{}

      template = ~CE"""
      <.form :let={f} for={to_form(%{})} as={:myform}>
        <.inputs_for :let={finner} field={f[:inner]} id="test" as={:name}>
          <input id={finner[:foo].id} name={finner[:foo].name} type="text" />
        </.inputs_for>
      </.form>
      """

      assert to_x(template) ==
               ~X"""
               <form>
                 <input type="hidden" name="name[_persistent_id]" value="0"> </input>
                 <input id="test_inner_0_foo" name="name[foo]" type="text"></input>
               </form>
               """

      template = ~CE"""
      <.form :let={f} for={to_form(%{})} as={:myform}>
        <.inputs_for :let={finner} field={f[:inner]} as={:name}>
          <input id={finner[:foo].id} name={finner[:foo].name} type="text" />
        </.inputs_for>
      </.form>
      """

      assert to_x(template) ==
               ~X"""
               <form>
                 <input type="hidden" name="name[_persistent_id]" value="0"> </input>
                 <input id="myform_inner_0_foo" name="name[foo]" type="text"></input>
               </form>
               """
    end

    test "with default map option" do
      assigns = %{}

      template = ~CE"""
      <.form :let={f} for={to_form(%{})} as={:myform}>
        <.inputs_for :let={finner} field={f[:inner]} default={%{foo: "123"}}>
          <input id={finner[:foo].id} name={finner[:foo].name} type="text" value={finner[:foo].value} />
        </.inputs_for>
      </.form>
      """

      assert to_x(template) ==
               ~X"""
               <form>
                 <input type="hidden" name="myform[inner][_persistent_id]" value="0"> </input>
                 <input id="myform_inner_0_foo" name="myform[inner][foo]" type="text" value="123"></input>
               </form>
               """
    end

    test "with default list and list related options" do
      assigns = %{}

      template = ~CE"""
      <.form :let={f} for={to_form(%{})} as={:myform}>
        <.inputs_for
          :let={finner}
          field={f[:inner]}
          default={[%{foo: "456"}]}
          prepend={[%{foo: "123"}]}
          append={[%{foo: "789"}]}
        >
          <input id={finner[:foo].id} name={finner[:foo].name} type="text" value={finner[:foo].value} />
        </.inputs_for>
      </.form>
      """

      assert to_x(template) ==
               ~X"""
               <form>
                 <input type="hidden" name="myform[inner][0][_persistent_id]" value="0"></input>
                 <input id="myform_inner_0_foo" name="myform[inner][0][foo]" type="text" value="123"></input>
                 <input type="hidden" name="myform[inner][1][_persistent_id]" value="1"></input>
                 <input id="myform_inner_1_foo" name="myform[inner][1][foo]" type="text" value="456"></input>
                 <input type="hidden" name="myform[inner][2][_persistent_id]" value="2"></input>
                 <input id="myform_inner_2_foo" name="myform[inner][2][foo]" type="text" value="789"></input>
               </form>
               """
    end

    test "can disable persistent ids" do
      assigns = %{}

      template = ~CE"""
      <.form :let={f} for={to_form(%{})} as={:myform}>
        <.inputs_for
          :let={finner}
          field={f[:inner]}
          default={[%{foo: "456"}, %{foo: "789"}]}
          prepend={[%{foo: "123"}]}
          append={[%{foo: "101112"}]}
          skip_persistent_id
        >
          <input id={finner[:foo].id} name={finner[:foo].name} type="text" value={finner[:foo].value} />
        </.inputs_for>
      </.form>
      """

      assert to_x(template) ==
               ~X"""
               <form>
                 <input id="myform_inner_0_foo" name="myform[inner][0][foo]" type="text" value="123">
                 <input id="myform_inner_1_foo" name="myform[inner][1][foo]" type="text" value="456">
                 <input id="myform_inner_2_foo" name="myform[inner][2][foo]" type="text" value="789">
                 <input id="myform_inner_3_foo" name="myform[inner][3][foo]" type="text" value="101112">
               </form>
               """
    end

    test "with FormData implementation options" do
      assigns = %{}

      template = ~CE"""
      <.form :let={f} for={to_form(%{})} as={:myform}>
        <.inputs_for :let={finner} field={f[:inner]} options={[foo: "bar"]}>
          <p>{finner.options[:foo]}</p>
        </.inputs_for>
      </.form>
      """

      assert to_x(template) ==
               ~X"""
               <form>
                 <input type="hidden" name="myform[inner][_persistent_id]" value="0">
                 <p>bar</p>
               </form>
               """
    end
  end

  describe "intersperse" do
    test "renders" do
      assigns = %{}

      template = ~CE"""
      <.intersperse :let={item} enum={[1, 2, 3]}>
        <:separator><span class="sep">|</span></:separator>
        Item{item}
      </.intersperse>
      """

      assert to_x(template) == ~X"""

               Item1
             <span class="sep">|</span>
               Item2
             <span class="sep">|</span>
               Item3
             """

      template = ~CE"""
      <.intersperse :let={item} enum={[1]}>
        <:separator><span class="sep">|</span></:separator>
        Item{item}
      </.intersperse>
      """

      assert to_x(template) == ~X"""

               Item1
             """
    end
  end
end
