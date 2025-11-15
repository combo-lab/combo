defmodule Combo.Router.ResourcesTest do
  use ExUnit.Case, async: true
  use Support.RouterHelper

  defmodule API.UserController do
    use Support.Controller
    def index(conn, _params), do: text(conn, "index users")
    def new(conn, _params), do: text(conn, "new user")
    def create(conn, _params), do: text(conn, "create user")
    def show(conn, _params), do: text(conn, "show user")
    def edit(conn, _params), do: text(conn, "edit user")
    def update(conn, _params), do: text(conn, "update user")
    def delete(conn, _params), do: text(conn, "delete user")
  end

  defmodule API.FileController do
    use Support.Controller
    def index(conn, _params), do: text(conn, "index files")
    def new(conn, _params), do: text(conn, "new file")
    def show(conn, _params), do: text(conn, "show file")
  end

  defmodule API.CommentController do
    use Support.Controller
    def index(conn, _params), do: text(conn, "index comments")
    def new(conn, _params), do: text(conn, "new comment")
    def create(conn, _params), do: text(conn, "create comment")
    def show(conn, _params), do: text(conn, "show comment")
    def edit(conn, _params), do: text(conn, "edit comment")
    def update(conn, _params), do: text(conn, "update comment")
    def delete(conn, _params), do: text(conn, "delete comment")
    def special(conn, _params), do: text(conn, "special comment")
  end

  defmodule Router do
    use Support.Router

    resources "/users", API.UserController, alias: API do
      resources "/comments", CommentController do
        get "/special", CommentController, :special
      end

      resources "/files", FileController, except: [:delete]
    end

    resources "/members", API.UserController, only: [:show, :new, :delete]

    resources "/files", API.FileController, only: [:index]

    resources "/admin", API.UserController,
      param: "slug",
      name: "admin",
      only: [:show],
      alias: API do
      resources "/comments", CommentController, param: "key", name: "post", except: [:delete]
      resources "/files", FileController, only: [:show, :index, :new]
    end
  end

  setup do
    Logger.disable(self())
    :ok
  end

  test "top-level route matches index action" do
    conn = call(Router, :get, "/users")
    assert conn.status == 200
    assert conn.resp_body == "index users"
  end

  test "top-level route matches new action" do
    conn = call(Router, :get, "/users/new")
    assert conn.status == 200
    assert conn.resp_body == "new user"
  end

  test "top-level route matches create action" do
    conn = call(Router, :post, "/users")
    assert conn.status == 200
    assert conn.resp_body == "create user"
  end

  test "top-level route matches show action" do
    conn = call(Router, :get, "/users/1")
    assert conn.params["id"] == "1"
    assert conn.status == 200
    assert conn.resp_body == "show user"
  end

  test "top-level route matches edit action" do
    conn = call(Router, :get, "/users/1/edit")
    assert conn.params["id"] == "1"
    assert conn.status == 200
    assert conn.resp_body == "edit user"
  end

  test "top-level route matches update action" do
    for method <- [:put, :patch] do
      conn = call(Router, method, "/users/1")
      assert conn.params["id"] == "1"
      assert conn.status == 200
      assert conn.resp_body == "update user"
    end
  end

  test "top-level route matches delete action" do
    conn = call(Router, :delete, "/users/1")
    assert conn.params["id"] == "1"
    assert conn.status == 200
    assert conn.resp_body == "delete user"
  end

  test "1-level nested route matches index action" do
    conn = call(Router, :get, "/users/1/comments")
    assert conn.params["user_id"] == "1"
    assert conn.status == 200
    assert conn.resp_body == "index comments"
  end

  test "1-level nested route matches new action" do
    conn = call(Router, :get, "/users/1/comments/new")
    assert conn.params["user_id"] == "1"
    assert conn.status == 200
    assert conn.resp_body == "new comment"
  end

  test "1-level nested route matches create action" do
    conn = call(Router, :post, "/users/1/comments")
    assert conn.params["user_id"] == "1"
    assert conn.status == 200
    assert conn.resp_body == "create comment"
  end

  test "1-level nested route matches show action" do
    conn = call(Router, :get, "/users/1/comments/2")
    assert conn.params["user_id"] == "1"
    assert conn.params["id"] == "2"
    assert conn.status == 200
    assert conn.resp_body == "show comment"
  end

  test "1-level nested route matches edit action" do
    conn = call(Router, :get, "/users/1/comments/2/edit")
    assert conn.params["user_id"] == "1"
    assert conn.params["id"] == "2"
    assert conn.status == 200
    assert conn.resp_body == "edit comment"
  end

  test "1-level nested route matches update action" do
    for method <- [:put, :patch] do
      conn = call(Router, method, "/users/1/comments/2")
      assert conn.params["user_id"] == "1"
      assert conn.params["id"] == "2"
      assert conn.status == 200
      assert conn.resp_body == "update comment"
    end
  end

  test "1-level nested route matches delete action" do
    conn = call(Router, :delete, "/users/1/comments/2")
    assert conn.params["user_id"] == "1"
    assert conn.params["id"] == "2"
    assert conn.status == 200
    assert conn.resp_body == "delete comment"
  end

  test "2-level nested matches" do
    conn = call(Router, :get, "/users/1/comments/2/special")
    assert conn.params["user_id"] == "1"
    assert conn.params["comment_id"] == "2"
    assert conn.status == 200
    assert conn.resp_body == "special comment"
  end

  test "nested prefix context reverts back to previous scope after expansion" do
    conn = call(Router, :get, "/users/8/files/10")
    assert conn.status == 200
    assert conn.resp_body == "show file"
    assert conn.params["user_id"] == "8"
    assert conn.params["id"] == "10"

    conn = call(Router, :get, "/files")
    assert conn.status == 200
    assert conn.resp_body == "index files"
  end

  test "nested options limit resource by passing :only option" do
    assert_raise Combo.Router.NoRouteError, fn ->
      call(Router, :patch, "/admin/1/files/2")
    end

    assert_raise Combo.Router.NoRouteError, fn ->
      call(Router, :post, "/admin/1/files")
    end

    assert_raise Combo.Router.NoRouteError, fn ->
      call(Router, :delete, "/admin/1/files/1")
    end

    conn = call(Router, :get, "/admin/1/files/")
    assert conn.status == 200
    conn = call(Router, :get, "/admin/1/files/1")
    assert conn.status == 200
    conn = call(Router, :get, "/admin/1/files/new")
    assert conn.status == 200
  end

  test "nested options limit resource by passing :except option" do
    assert_raise Combo.Router.NoRouteError, fn ->
      call(Router, :delete, "/users/1/files/2")
    end

    conn = call(Router, :get, "/users/1/files/new")
    assert conn.status == 200
  end

  test "resource limiting options should work for nested resources" do
    conn = call(Router, :get, "/admin/1")
    assert conn.status == 200
    assert conn.resp_body == "show user"

    assert_raise Combo.Router.NoRouteError, fn ->
      call(Router, :get, "/admin/")
    end

    assert_raise Combo.Router.NoRouteError, fn ->
      call(Router, :patch, "/admin/1")
    end

    assert_raise Combo.Router.NoRouteError, fn ->
      call(Router, :post, "/admin")
    end

    assert_raise Combo.Router.NoRouteError, fn ->
      call(Router, :delete, "/admin/1")
    end

    conn = call(Router, :get, "/admin/1/comments")
    assert conn.status == 200
    assert conn.resp_body == "index comments"

    conn = call(Router, :get, "/admin/1/comments/1")
    assert conn.status == 200
    assert conn.resp_body == "show comment"

    conn = call(Router, :patch, "/admin/1/comments/1")
    assert conn.status == 200
    assert conn.resp_body == "update comment"

    conn = call(Router, :post, "/admin/1/comments")
    assert conn.status == 200
    assert conn.resp_body == "create comment"

    assert_raise Combo.Router.NoRouteError, fn ->
      call(Router, :delete, "/scoped_files/1")
    end
  end

  test "param option allows default singularized _id param to be overridden" do
    conn = call(Router, :get, "/admin/foo")
    assert conn.status == 200
    assert conn.params["slug"] == "foo"
    assert conn.resp_body == "show user"

    conn = call(Router, :get, "/admin/bar/comments/the_key")
    assert conn.status == 200
    assert conn.params["admin_slug"] == "bar"
    assert conn.params["key"] == "the_key"
    assert conn.resp_body == "show comment"
  end

  test "resources with :only sets proper match order for :show and :new" do
    conn = call(Router, :get, "/members/new")
    assert conn.status == 200
    assert conn.resp_body == "new user"

    conn = call(Router, :get, "/members/2")
    assert conn.status == 200
    assert conn.resp_body == "show user"
    assert conn.params["id"] == "2"
  end

  test "singleton resources declaring an :index route throws an ArgumentError" do
    assert_raise ArgumentError,
                 ~r/supported singleton actions: \[:new, :create, :show, :edit, :update, :delete\]/,
                 fn ->
                   defmodule SingletonRouter.Router do
                     use Support.Router
                     resources "/", API.UserController, singleton: true, only: [:index]
                   end
                 end
  end

  test "validates :only actions" do
    assert_raise ArgumentError,
                 ~r/supported actions: \[:index, :new, :create, :show, :edit, :update, :delete\]/,
                 fn ->
                   defmodule SingletonRouter.Router do
                     use Support.Router
                     resources "/", API.UserController, only: [:bad_index]
                   end
                 end
  end

  test "validates :except actions" do
    assert_raise ArgumentError,
                 ~r/supported actions: \[:index, :new, :create, :show, :edit, :update, :delete\]/,
                 fn ->
                   defmodule SingletonRouter.Router do
                     use Support.Router
                     resources "/", API.UserController, except: [:bad_index]
                   end
                 end
  end
end
