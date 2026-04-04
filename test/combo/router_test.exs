defmodule Combo.RouterTest do
  use ExUnit.Case, async: true
  use Support.RouterHelper

  defmodule UserController do
    use Support.Controller

    def show(conn, _params), do: text(conn, "api v1 users show")
  end

  setup do
    Logger.put_process_level(self(), :none)
    router = build_router()
    %{router: router}
  end

  defp build_router do
    Module.concat(__MODULE__, "Router#{System.unique_integer([:positive])}")
  end

  # scope

  describe "scope/_ -" do
    test "single scope", %{router: router} do
      defmodule router do
        use Support.Router

        scope "/admin" do
          get "/users/:id", UserController, :show
        end
      end

      conn = call(router, :get, "/admin/users/1")
      assert conn.status == 200
      assert conn.resp_body == "api v1 users show"
      assert conn.params["id"] == "1"
    end

    test "nested scopes", %{router: router} do
      defmodule router do
        use Support.Router

        scope "/api" do
          scope "/v1" do
            get "/users/:id", UserController, :show
          end
        end
      end

      conn = call(router, :get, "/api/v1/users/1")
      assert conn.status == 200
      assert conn.resp_body == "api v1 users show"
      assert conn.params["id"] == "1"
    end

    test ":module option", %{router: router} do
      defmodule L1.L2.CatController do
        use Support.Controller
        def index(conn, _params), do: text(conn, "all cats")
      end

      defmodule router do
        use Support.Router

        scope "/case1/l1", L1 do
          get "/l2/cats", L2.CatController, :index
        end

        scope "/case2/l1", module: L1 do
          get "/l2/cats", L2.CatController, :index
        end

        scope "/case3/l1", module: false do
          scope "/l2", L1.L2 do
            get "/cats", CatController, :index
          end
        end

        scope "/case4/l1", L1 do
          scope "/l2", module: false do
            get "/cats", L1.L2.CatController, :index
          end
        end

        scope "/case5/l1", L1 do
          scope "/l2", L2 do
            get "/cats", L1.L2.CatController, :index, scoped_module: false
          end
        end
      end

      for i <- 1..5 do
        conn = call(router, :get, "/case#{i}/l1/l2/cats")
        assert conn.status == 200
        assert conn.resp_body == "all cats"
      end
    end

    test ":private option", %{router: router} do
      defmodule router do
        use Support.Router

        scope "/private", private: %{token: "foo"} do
          get "/token", UserController, :show
          get "/token/override", UserController, :show, private: %{token: "bar"}

          scope "/nested" do
            get "/token/override", UserController, :show, private: %{token: "baz"}
          end
        end
      end

      conn = call(router, :get, "/private/token")
      assert conn.status == 200
      assert conn.private[:token] == "foo"

      conn = call(router, :get, "/private/token/override")
      assert conn.status == 200
      assert conn.private[:token] == "bar"

      conn = call(router, :get, "/private/nested/token/override")
      assert conn.status == 200
      assert conn.private[:token] == "baz"
    end

    test ":assigns option", %{router: router} do
      defmodule router do
        use Support.Router

        scope "/assigns", assigns: %{token: "foo"} do
          get "/token", UserController, :show
          get "/token/override", UserController, :show, assigns: %{token: "bar"}

          scope "/nested" do
            get "/token/override", UserController, :show, assigns: %{token: "baz"}
          end
        end
      end

      conn = call(router, :get, "/assigns/token")
      assert conn.status == 200
      assert conn.assigns[:token] == "foo"

      conn = call(router, :get, "/assigns/token/override")
      assert conn.status == 200
      assert conn.assigns[:token] == "bar"

      conn = call(router, :get, "/assigns/nested/token/override")
      assert conn.status == 200
      assert conn.assigns[:token] == "baz"
    end

    test "raises on bad path", %{router: router} do
      assert_raise ArgumentError, ~r{route path must be a string, got: :bad}, fn ->
        defmodule router do
          use Support.Router

          scope path: :bad do
          end
        end
      end
    end
  end

  test "scoped_module/1", %{router: router} do
    defmodule L1.InspectController do
      use Support.Controller
      def show(conn, _params), do: text(conn, inspect(conn.assigns.module))
    end

    defmodule router do
      use Support.Router

      scope "/case1/l1", L1 do
        get "/inspect", InspectController, :show,
          assigns: %{module: scoped_module(DummyController)}
      end

      scope "/case2/l1", module: false do
        get "/inspect", L1.InspectController, :show,
          assigns: %{module: scoped_module(DummyController)}
      end
    end

    conn = call(router, :get, "/case1/l1/inspect")
    assert conn.status == 200
    assert conn.resp_body == "Combo.RouterTest.L1.DummyController"

    conn = call(router, :get, "/case2/l1/inspect")
    assert conn.status == 200
    assert conn.resp_body == "DummyController"
  end

  # route

  describe "verb/_" do
    test "raises on bad path", %{router: router} do
      assert_raise ArgumentError, ~r{route path must be a string, got: :/}, fn ->
        defmodule router do
          use Support.Router
          get :/, DummyController, :show
        end
      end
    end

    test "raises on reserved route name - derived from the name of controller", %{router: router} do
      assert_raise ArgumentError,
                   "route name \"static\" is reserved, you must change it by renaming StaticController or specifying :as option",
                   fn ->
                     defmodule router do
                       use Support.Router
                       get "/", StaticController, :index
                     end
                   end
    end

    test "raises on reserved route name - derived from the :as option", %{router: router} do
      assert_raise ArgumentError,
                   "route name \"static\" is reserved, you must change it by renaming DummyController or specifying :as option",
                   fn ->
                     defmodule router do
                       use Support.Router
                       get "/", DummyController, :show, as: :static
                     end
                   end
    end
  end

  describe "forward/4" do
    test "forwards requests whose path is the base path", %{router: router} do
      defmodule router do
        use Support.Router

        defmodule Assign do
          def init(opts), do: opts
          def call(conn, _opts), do: conn |> assign(:conn, conn) |> text("ok")
        end

        forward "/base", Assign
      end

      conn = call(router, :get, "/base")
      assert conn.path_info == ["base"]
      assert conn.script_name == []
      assert conn.assigns.conn.path_info == []
      assert conn.assigns.conn.script_name == ["base"]
      assert conn.status == 200
      assert conn.resp_body == "ok"
    end

    test "forwards requests whose path starts with base path", %{router: router} do
      defmodule router do
        use Support.Router

        defmodule Assign do
          def init(opts), do: opts
          def call(conn, _opts), do: conn |> assign(:conn, conn) |> text("ok")
        end

        forward "/base", Assign
      end

      conn = call(router, :get, "/base/example")
      assert conn.path_info == ["base", "example"]
      assert conn.script_name == []
      assert conn.assigns.conn.path_info == ["example"]
      assert conn.assigns.conn.script_name == ["base"]
      assert conn.status == 200
      assert conn.resp_body == "ok"
    end

    test "handles plugs with opts", %{router: router} do
      defmodule router do
        use Support.Router

        defmodule Assign do
          def init(opts), do: opts
          def call(conn, opts), do: conn |> assign(:opts, opts) |> text("ok")
        end

        forward "/base", Assign, %{foo: "bar"}
      end

      conn = call(router, :get, "/base/example")
      assert conn.assigns.opts == %{foo: "bar"}
      assert conn.status == 200
      assert conn.resp_body == "ok"
    end

    test "raises on dynamic path prefix", %{router: router} do
      assert_raise ArgumentError,
                   ~r{route path must be static when forwarding, got: "/api/:version"},
                   fn ->
                     defmodule router do
                       use Support.Router
                       forward "/api/:version", FakePlug
                     end
                   end
    end
  end
end
