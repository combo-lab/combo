defmodule Combo.RouterTest do
  use ExUnit.Case, async: true
  use Support.RouterHelper

  defmodule UserController do
    use Support.Controller

    def show(conn, _params), do: text(conn, "api v1 users show")
  end

  setup do
    Logger.disable(self())
    :ok
  end

  # scope

  describe "scope/_ -" do
    test "single scope" do
      defmodule RouterForSingleScope do
        use Support.Router

        scope "/admin" do
          get "/users/:id", UserController, :show
        end
      end

      alias RouterForSingleScope, as: Router

      conn = call(Router, :get, "/admin/users/1")
      assert conn.status == 200
      assert conn.resp_body == "api v1 users show"
      assert conn.params["id"] == "1"
    end

    test "nested scopes" do
      defmodule RouterForNestedScopes do
        use Support.Router

        scope "/api" do
          scope "/v1" do
            get "/users/:id", UserController, :show
          end
        end
      end

      alias RouterForNestedScopes, as: Router

      conn = call(Router, :get, "/api/v1/users/1")
      assert conn.status == 200
      assert conn.resp_body == "api v1 users show"
      assert conn.params["id"] == "1"
    end

    test ":alias option" do
      defmodule L1.L2.CatController do
        use Support.Controller
        def index(conn, _params), do: text(conn, "all cats")
      end

      defmodule RouterForAliasOption do
        use Support.Router

        scope "/case1/l1", L1 do
          get "/l2/cats", L2.CatController, :index
        end

        scope "/case2/l1", alias: L1 do
          get "/l2/cats", L2.CatController, :index
        end

        scope "/case3/l1", alias: false do
          scope "/l2", L1.L2 do
            get "/cats", CatController, :index
          end
        end

        scope "/case4/l1", L1 do
          scope "/l2", alias: false do
            get "/cats", L1.L2.CatController, :index
          end
        end

        scope "/case5/l1", L1 do
          scope "/l2", L2 do
            get "/cats", L1.L2.CatController, :index, alias: false
          end
        end
      end

      for i <- 1..5 do
        conn = call(RouterForAliasOption, :get, "/case#{i}/l1/l2/cats")
        assert conn.status == 200
        assert conn.resp_body == "all cats"
      end
    end

    test ":private option" do
      defmodule RouterForPrivateOption do
        use Support.Router

        scope "/private", private: %{token: "foo"} do
          get "/token", UserController, :show
          get "/token/override", UserController, :show, private: %{token: "bar"}

          scope "/nested" do
            get "/token/override", UserController, :show, private: %{token: "baz"}
          end
        end
      end

      alias RouterForPrivateOption, as: Router

      conn = call(Router, :get, "/private/token")
      assert conn.status == 200
      assert conn.private[:token] == "foo"

      conn = call(Router, :get, "/private/token/override")
      assert conn.status == 200
      assert conn.private[:token] == "bar"

      conn = call(Router, :get, "/private/nested/token/override")
      assert conn.status == 200
      assert conn.private[:token] == "baz"
    end

    test ":assigns option" do
      defmodule RouterForAssignsOption do
        use Support.Router

        scope "/assigns", assigns: %{token: "foo"} do
          get "/token", UserController, :show
          get "/token/override", UserController, :show, assigns: %{token: "bar"}

          scope "/nested" do
            get "/token/override", UserController, :show, assigns: %{token: "baz"}
          end
        end
      end

      alias RouterForAssignsOption, as: Router

      conn = call(Router, :get, "/assigns/token")
      assert conn.status == 200
      assert conn.assigns[:token] == "foo"

      conn = call(Router, :get, "/assigns/token/override")
      assert conn.status == 200
      assert conn.assigns[:token] == "bar"

      conn = call(Router, :get, "/assigns/nested/token/override")
      assert conn.status == 200
      assert conn.assigns[:token] == "baz"
    end

    test "raises on bad path" do
      assert_raise ArgumentError, ~r{route path must be a string, got: :bad}, fn ->
        defmodule BadRouter do
          use Support.Router

          scope path: :bad do
          end
        end
      end
    end
  end

  test "scoped_module/1" do
    defmodule L1.InspectController do
      use Support.Controller
      def show(conn, _params), do: text(conn, inspect(conn.assigns.module))
    end

    defmodule RouterForScopedModule do
      use Support.Router

      scope "/case1/l1", L1 do
        get "/inspect", InspectController, :show,
          assigns: %{module: scoped_module(DummyController)}
      end

      scope "/case2/l1", alias: false do
        get "/inspect", L1.InspectController, :show,
          assigns: %{module: scoped_module(DummyController)}
      end
    end

    alias RouterForScopedModule, as: Router

    conn = call(Router, :get, "/case1/l1/inspect")
    assert conn.status == 200
    assert conn.resp_body == "Combo.RouterTest.L1.DummyController"

    conn = call(Router, :get, "/case2/l1/inspect")
    assert conn.status == 200
    assert conn.resp_body == "DummyController"
  end

  # route

  describe "" do
    test "raises on bad path" do
      assert_raise ArgumentError, ~r{route path must be a string, got: :/}, fn ->
        defmodule BadRouter do
          use Support.Router
          get :/, DummyController, :show
        end
      end
    end

    test "raises on reserved route name" do
      # derived from the name of controller
      assert_raise ArgumentError, ~r/`static` is a reserved route name/, fn ->
        defmodule BadRouter do
          use Support.Router
          get "/", StaticController, :index
        end
      end

      # derived from the :as option
      assert_raise ArgumentError, ~r/`static` is a reserved route name/, fn ->
        defmodule BadRouter do
          use Support.Router
          get "/", DummyController, :show, as: :static
        end
      end
    end
  end
end
