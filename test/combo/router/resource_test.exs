defmodule Combo.Router.ResourceTest do
  use ExUnit.Case, async: true
  use Support.RouterHelper

  defmodule API.GenericController do
    use Support.Controller
    def new(conn, _params), do: text(conn, "new")
    def create(conn, _params), do: text(conn, "create")
    def show(conn, _params), do: text(conn, "show")
    def edit(conn, _params), do: text(conn, "edit")
    def update(conn, _params), do: text(conn, "update")
    def delete(conn, _params), do: text(conn, "delete")
  end

  defmodule Router do
    use Support.Router

    resources "/account", API.GenericController, alias: API, singleton: true do
      resources "/comments", GenericController
      resources "/session", GenericController, except: [:delete], singleton: true
    end

    resources "/session", API.GenericController, only: [:show], singleton: true
  end

  setup do
    Logger.disable(self())
    :ok
  end

  test "top-level route matches new action" do
    conn = call(Router, :get, "/account/new")
    assert conn.status == 200
    assert conn.resp_body == "new"
  end

  test "top-level route matches show action" do
    conn = call(Router, :get, "/account")
    assert conn.status == 200
    assert conn.resp_body == "show"
  end

  test "top-level route matches create action" do
    conn = call(Router, :post, "/account")
    assert conn.status == 200
    assert conn.resp_body == "create"
  end

  test "top-level route matches edit action" do
    conn = call(Router, :get, "/account/edit")
    assert conn.status == 200
    assert conn.resp_body == "edit"
  end

  test "top-level route matches update action with both PUT and PATCH" do
    for method <- [:put, :patch] do
      conn = call(Router, method, "/account")
      assert conn.status == 200
      assert conn.resp_body == "update"

      conn = call(Router, method, "/account")
      assert conn.status == 200
      assert conn.resp_body == "update"
    end
  end

  test "top-level route matches delete action" do
    conn = call(Router, :delete, "/account")
    assert conn.status == 200
    assert conn.resp_body == "delete"
  end

  test "1-level nested route matches" do
    conn = call(Router, :get, "/account/comments/2")
    assert conn.status == 200
    assert conn.resp_body == "show"
    assert conn.params["id"] == "2"
  end

  test "nested prefix context reverts back to previous scope after expansion" do
    conn = call(Router, :get, "/account/session")
    assert conn.status == 200
    assert conn.resp_body == "show"

    conn = call(Router, :get, "/session")
    assert conn.status == 200
    assert conn.resp_body == "show"
  end

  test "limit resource by passing :only option" do
    assert_raise Combo.Router.NoRouteError, fn ->
      call(Router, :patch, "/session/new")
    end

    conn = call(Router, :get, "/session")
    assert conn.status == 200
  end

  test "limit resource by passing :except option" do
    assert_raise Combo.Router.NoRouteError, fn ->
      call(Router, :delete, "/account/session")
    end

    conn = call(Router, :get, "/account/session/new")
    assert conn.status == 200
  end
end
