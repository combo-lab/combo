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
end
