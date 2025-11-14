modules = [
  PostController,
  UserController,
  CommentController,
  FileController,
  ProductController,
  Admin.MessageController,
  SubPlug
]

for module <- modules do
  defmodule module do
    def init(opts), do: opts
    def call(conn, _opts), do: conn
  end
end

defmodule Combo.Router.HelpersTest do
  use ExUnit.Case, async: true
  use Support.RouterHelper

  defmodule Router do
    use Combo.Router

    get "/posts/top", PostController, :top, as: :top
    get "/posts/bottom/:order/:count", PostController, :bottom, as: :bottom
    get "/posts/:id", PostController, :show
    get "/posts/file/*file", PostController, :file
    get "/posts/skip", PostController, :skip, as: nil

    resources "/users", UserController do
      resources "/comments", CommentController do
        resources "/files", FileController
      end
    end

    scope "/", host: "users." do
      post "/host_users/:id/info", UserController, :create
    end

    resources "/files", FileController

    resources "/account", UserController, as: :account, singleton: true do
      resources "/page", PostController, as: :page, only: [:show], singleton: true
    end

    scope "/admin", alias: Admin do
      resources "/messages", MessageController
    end

    scope "/admin/new", alias: Admin, as: "admin" do
      resources "/messages", MessageController

      scope "/unscoped", as: false do
        resources "/messages", MessageController, as: :my_admin_message
      end
    end

    get "/", PostController, :root, as: :page
    get "/products/:id", ProductController, :show
    get "/products", ProductController, :show
    get "/products/:id/:sort", ProductController, :show
    get "/products/:id/:sort/:page", ProductController, :show

    get "/mfa_path", SubPlug, func: {M, :f, [10]}
  end

  defmodule Endpoint do
    def url, do: "https://example.com"
    def static_url, do: "https://static.example.com"
    def path(path), do: path
    def static_path(path), do: path
    def static_integrity(_path), do: nil
  end

  defmodule EndpointWithScriptName do
    def url, do: "https://example.com"
    def static_url, do: "https://static.example.com"
    def path(path), do: "/api" <> path
    def static_path(path), do: "/api" <> path
  end

  defmodule EndpointWithStaticPath do
    def url, do: "https://example.com"
    def static_url, do: "https://example.com"
    def path(path), do: path
    def static_path(path), do: "/static" <> path
    def static_integrity(_path), do: nil
  end

  defmodule Post do
    @derive Combo.URLParam
    defstruct [:id]
  end

  defp conn_with_endpoint(endpoint \\ Endpoint) do
    conn(:get, "/") |> put_private(:combo_endpoint, endpoint)
  end

  defp socket_with_endpoint(endpoint \\ Endpoint) do
    %Combo.Socket{endpoint: endpoint}
  end

  def conn_with_script_name(script_name \\ ~w(api)) do
    conn = conn(:get, "/") |> put_private(:combo_endpoint, EndpointWithScriptName)
    put_in(conn.script_name, script_name)
  end

  alias Router.Helpers

  test "defines a __helpers__ function" do
    assert Router.__helpers__() == Router.Helpers
  end

  test "root helper" do
    conn = conn(:get, "/") |> put_private(:combo_endpoint, Endpoint)
    assert Helpers.page_path(conn, :root) == "/"
    assert Helpers.page_path(Endpoint, :root) == "/"
  end

  test "url helper with query strings" do
    assert Helpers.post_path(Endpoint, :show, 5, id: 3) == "/posts/5"
    assert Helpers.post_path(Endpoint, :show, 5, foo: "bar") == "/posts/5?foo=bar"
    assert Helpers.post_path(Endpoint, :show, 5, foo: :bar) == "/posts/5?foo=bar"
    assert Helpers.post_path(Endpoint, :show, 5, foo: true) == "/posts/5?foo=true"
    assert Helpers.post_path(Endpoint, :show, 5, foo: false) == "/posts/5?foo=false"
    assert Helpers.post_path(Endpoint, :show, 5, foo: nil) == "/posts/5?foo="

    assert Helpers.post_path(Endpoint, :show, 5, foo: ~w(bar baz)) ==
             "/posts/5?foo[]=bar&foo[]=baz"

    assert Helpers.post_path(Endpoint, :show, 5, foo: %{id: 5}) ==
             "/posts/5?foo[id]=5"

    assert Helpers.post_path(Endpoint, :show, 5, foo: %{__struct__: Foo, id: 5}) ==
             "/posts/5?foo=5"
  end

  test "url helper with URLParam protocol" do
    post = %Post{id: 5}
    assert Helpers.post_path(Endpoint, :show, post) == "/posts/5"

    assert_raise ArgumentError, fn ->
      Helpers.post_path(Endpoint, :show, nil)
    end
  end

  test "url helper shows an error if an id is accidentally passed" do
    error_suggestion = ~r/bottom_path\(conn, :bottom, order, count, page: 5, per_page: 10\)/

    assert_raise ArgumentError, error_suggestion, fn ->
      Helpers.bottom_path(Endpoint, :bottom, :asc, 8, {:not, :enumerable})
    end

    error_suggestion = ~r/top_path\(conn, :top, page: 5, per_page: 10\)/

    assert_raise ArgumentError, error_suggestion, fn ->
      Helpers.top_path(Endpoint, :top, "invalid")
    end
  end

  test "top-level named route" do
    assert Helpers.post_path(Endpoint, :show, 5) == "/posts/5"
    assert Helpers.post_path(Endpoint, :show, 5, []) == "/posts/5"
    assert Helpers.post_path(Endpoint, :show, 5, id: 5) == "/posts/5"
    assert Helpers.post_path(Endpoint, :show, 5, %{"id" => 5}) == "/posts/5"
    assert Helpers.post_path(Endpoint, :show, "foo") == "/posts/foo"
    assert Helpers.post_path(Endpoint, :show, "foo bar") == "/posts/foo%20bar"

    assert Helpers.post_path(Endpoint, :file, ["foo", "bar/baz"]) == "/posts/file/foo/bar%2Fbaz"
    assert Helpers.post_path(Endpoint, :file, ["foo", "bar"], []) == "/posts/file/foo/bar"

    assert Helpers.post_path(Endpoint, :file, ["foo", "bar baz"], []) ==
             "/posts/file/foo/bar%20baz"

    assert Helpers.top_path(Endpoint, :top) == "/posts/top"
    assert Helpers.top_path(Endpoint, :top, id: 5) == "/posts/top?id=5"
    assert Helpers.top_path(Endpoint, :top, %{"id" => 5}) == "/posts/top?id=5"
    assert Helpers.top_path(Endpoint, :top, %{"id" => "foo"}) == "/posts/top?id=foo"
    assert Helpers.top_path(Endpoint, :top, %{"id" => "foo bar"}) == "/posts/top?id=foo+bar"

    error_message = fn helper, arity ->
      """
      no action :skip for #{inspect(Helpers)}.#{helper}/#{arity}. The following actions/clauses are supported:

          #{helper}(conn_or_endpoint, :file, file, params \\\\ [])
          #{helper}(conn_or_endpoint, :show, id, params \\\\ [])

      """
      |> String.trim()
    end

    assert_raise ArgumentError, error_message.("post_path", 3), fn ->
      Helpers.post_path(Endpoint, :skip, 5)
    end

    assert_raise ArgumentError, error_message.("post_url", 3), fn ->
      Helpers.post_url(Endpoint, :skip, 5)
    end

    assert_raise ArgumentError, error_message.("post_path", 4), fn ->
      Helpers.post_path(Endpoint, :skip, 5, foo: "bar", other: "param")
    end

    assert_raise ArgumentError, error_message.("post_url", 4), fn ->
      Helpers.post_url(Endpoint, :skip, 5, foo: "bar", other: "param")
    end
  end

  test "top-level named routes with complex ids" do
    assert Helpers.post_path(Endpoint, :show, "==d--+") ==
             "/posts/%3D%3Dd--%2B"

    assert Helpers.post_path(Endpoint, :show, "==d--+", []) ==
             "/posts/%3D%3Dd--%2B"

    assert Helpers.top_path(Endpoint, :top, id: "==d--+") ==
             "/posts/top?id=%3D%3Dd--%2B"

    assert Helpers.post_path(Endpoint, :file, ["==d--+", ":O.jpg"]) ==
             "/posts/file/%3D%3Dd--%2B/%3AO.jpg"

    assert Helpers.post_path(Endpoint, :file, ["==d--+", ":O.jpg"], []) ==
             "/posts/file/%3D%3Dd--%2B/%3AO.jpg"

    assert Helpers.post_path(Endpoint, :file, ["==d--+", ":O.jpg"], xx: "/=+/") ==
             "/posts/file/%3D%3Dd--%2B/%3AO.jpg?xx=%2F%3D%2B%2F"
  end

  test "resources generates named routes for :index, :edit, :show, :new" do
    assert Helpers.user_path(Endpoint, :index, []) == "/users"
    assert Helpers.user_path(Endpoint, :index) == "/users"
    assert Helpers.user_path(Endpoint, :edit, 123, []) == "/users/123/edit"
    assert Helpers.user_path(Endpoint, :edit, 123) == "/users/123/edit"
    assert Helpers.user_path(Endpoint, :show, 123, []) == "/users/123"
    assert Helpers.user_path(Endpoint, :show, 123) == "/users/123"
    assert Helpers.user_path(Endpoint, :new, []) == "/users/new"
    assert Helpers.user_path(Endpoint, :new) == "/users/new"
  end

  test "resources generated named routes with complex ids" do
    assert Helpers.user_path(Endpoint, :edit, "1a+/31d", []) == "/users/1a%2B%2F31d/edit"
    assert Helpers.user_path(Endpoint, :edit, "1a+/31d") == "/users/1a%2B%2F31d/edit"
    assert Helpers.user_path(Endpoint, :show, "1a+/31d", []) == "/users/1a%2B%2F31d"
    assert Helpers.user_path(Endpoint, :show, "1a+/31d") == "/users/1a%2B%2F31d"

    assert Helpers.message_path(Endpoint, :update, "8=/=d", []) == "/admin/messages/8%3D%2F%3Dd"
    assert Helpers.message_path(Endpoint, :update, "8=/=d") == "/admin/messages/8%3D%2F%3Dd"
    assert Helpers.message_path(Endpoint, :delete, "8=/=d", []) == "/admin/messages/8%3D%2F%3Dd"
    assert Helpers.message_path(Endpoint, :delete, "8=/=d") == "/admin/messages/8%3D%2F%3Dd"

    assert Helpers.user_path(Endpoint, :show, "1a+/31d", dog: "8d=") ==
             "/users/1a%2B%2F31d?dog=8d%3D"

    assert Helpers.user_path(Endpoint, :index, cat: "=8+/&") == "/users?cat=%3D8%2B%2F%26"
  end

  test "resources generates named routes for :create, :update, :delete" do
    assert Helpers.message_path(Endpoint, :create, []) == "/admin/messages"
    assert Helpers.message_path(Endpoint, :create) == "/admin/messages"

    assert Helpers.message_path(Endpoint, :update, 1, []) == "/admin/messages/1"
    assert Helpers.message_path(Endpoint, :update, 1) == "/admin/messages/1"

    assert Helpers.message_path(Endpoint, :delete, 1, []) == "/admin/messages/1"
    assert Helpers.message_path(Endpoint, :delete, 1) == "/admin/messages/1"
  end

  test "1-Level nested resources generates nested named routes for :index, :edit, :show, :new" do
    assert Helpers.user_comment_path(Endpoint, :index, 99, []) == "/users/99/comments"
    assert Helpers.user_comment_path(Endpoint, :index, 99) == "/users/99/comments"
    assert Helpers.user_comment_path(Endpoint, :edit, 88, 2, []) == "/users/88/comments/2/edit"
    assert Helpers.user_comment_path(Endpoint, :edit, 88, 2) == "/users/88/comments/2/edit"
    assert Helpers.user_comment_path(Endpoint, :show, 123, 2, []) == "/users/123/comments/2"
    assert Helpers.user_comment_path(Endpoint, :show, 123, 2) == "/users/123/comments/2"
    assert Helpers.user_comment_path(Endpoint, :new, 88, []) == "/users/88/comments/new"
    assert Helpers.user_comment_path(Endpoint, :new, 88) == "/users/88/comments/new"

    assert_raise ArgumentError, ~r/no action :skip/, fn ->
      Helpers.user_comment_file_path(Endpoint, :skip, 123, 456)
    end

    assert_raise ArgumentError, ~r/no action :skip/, fn ->
      Helpers.user_comment_file_path(Endpoint, :skip, 123, 456, foo: "bar")
    end

    assert_raise ArgumentError,
                 ~r/no function clause for Combo.Router.HelpersTest.Router.Helpers.user_comment_path\/3 and action :show/,
                 fn ->
                   Helpers.user_comment_path(Endpoint, :show, 123)
                 end
  end

  test "multi-level nested resources generated named routes with complex ids" do
    assert Helpers.user_comment_path(Endpoint, :index, "f4/d+~=", []) ==
             "/users/f4%2Fd%2B~%3D/comments"

    assert Helpers.user_comment_path(Endpoint, :index, "f4/d+~=") ==
             "/users/f4%2Fd%2B~%3D/comments"

    assert Helpers.user_comment_path(Endpoint, :edit, "f4/d+~=", "x-+=/", []) ==
             "/users/f4%2Fd%2B~%3D/comments/x-%2B%3D%2F/edit"

    assert Helpers.user_comment_path(Endpoint, :edit, "f4/d+~=", "x-+=/") ==
             "/users/f4%2Fd%2B~%3D/comments/x-%2B%3D%2F/edit"

    assert Helpers.user_comment_path(Endpoint, :show, "f4/d+~=", "x-+=/", []) ==
             "/users/f4%2Fd%2B~%3D/comments/x-%2B%3D%2F"

    assert Helpers.user_comment_path(Endpoint, :show, "f4/d+~=", "x-+=/") ==
             "/users/f4%2Fd%2B~%3D/comments/x-%2B%3D%2F"

    assert Helpers.user_comment_path(Endpoint, :new, "/==/", []) ==
             "/users/%2F%3D%3D%2F/comments/new"

    assert Helpers.user_comment_path(Endpoint, :new, "/==/") ==
             "/users/%2F%3D%3D%2F/comments/new"

    assert Helpers.user_comment_file_path(Endpoint, :show, "f4/d+~=", "/==/", "x-+=/", []) ==
             "/users/f4%2Fd%2B~%3D/comments/%2F%3D%3D%2F/files/x-%2B%3D%2F"

    assert Helpers.user_comment_file_path(Endpoint, :show, "f4/d+~=", "/==/", "x-+=/") ==
             "/users/f4%2Fd%2B~%3D/comments/%2F%3D%3D%2F/files/x-%2B%3D%2F"
  end

  test "2-Level nested resources generates nested named routes for :index, :edit, :show, :new" do
    assert Helpers.user_comment_file_path(Endpoint, :index, 99, 1, []) ==
             "/users/99/comments/1/files"

    assert Helpers.user_comment_file_path(Endpoint, :index, 99, 1) ==
             "/users/99/comments/1/files"

    assert Helpers.user_comment_file_path(Endpoint, :edit, 88, 1, 2, []) ==
             "/users/88/comments/1/files/2/edit"

    assert Helpers.user_comment_file_path(Endpoint, :edit, 88, 1, 2) ==
             "/users/88/comments/1/files/2/edit"

    assert Helpers.user_comment_file_path(Endpoint, :show, 123, 1, 2, []) ==
             "/users/123/comments/1/files/2"

    assert Helpers.user_comment_file_path(Endpoint, :show, 123, 1, 2) ==
             "/users/123/comments/1/files/2"

    assert Helpers.user_comment_file_path(Endpoint, :new, 88, 1, []) ==
             "/users/88/comments/1/files/new"

    assert Helpers.user_comment_file_path(Endpoint, :new, 88, 1) ==
             "/users/88/comments/1/files/new"
  end

  test "resources without block generates named routes for :index, :edit, :show, :new" do
    assert Helpers.file_path(Endpoint, :index, []) == "/files"
    assert Helpers.file_path(Endpoint, :index) == "/files"
    assert Helpers.file_path(Endpoint, :edit, 123, []) == "/files/123/edit"
    assert Helpers.file_path(Endpoint, :edit, 123) == "/files/123/edit"
    assert Helpers.file_path(Endpoint, :show, 123, []) == "/files/123"
    assert Helpers.file_path(Endpoint, :show, 123) == "/files/123"
    assert Helpers.file_path(Endpoint, :new, []) == "/files/new"
    assert Helpers.file_path(Endpoint, :new) == "/files/new"
  end

  test "resource generates named routes for :show, :edit, :new, :update, :delete" do
    assert Helpers.account_path(Endpoint, :show, []) == "/account"
    assert Helpers.account_path(Endpoint, :show) == "/account"
    assert Helpers.account_path(Endpoint, :edit, []) == "/account/edit"
    assert Helpers.account_path(Endpoint, :edit) == "/account/edit"
    assert Helpers.account_path(Endpoint, :new, []) == "/account/new"
    assert Helpers.account_path(Endpoint, :new) == "/account/new"
    assert Helpers.account_path(Endpoint, :update, []) == "/account"
    assert Helpers.account_path(Endpoint, :update) == "/account"
    assert Helpers.account_path(Endpoint, :delete, []) == "/account"
    assert Helpers.account_path(Endpoint, :delete) == "/account"
  end

  test "2-Level nested resource generates nested named routes for :show" do
    assert Helpers.account_page_path(Endpoint, :show, []) == "/account/page"
    assert Helpers.account_page_path(Endpoint, :show) == "/account/page"
  end

  test "scoped route helpers generated named routes with :path, and :alias options" do
    assert Helpers.message_path(Endpoint, :index, []) == "/admin/messages"
    assert Helpers.message_path(Endpoint, :index) == "/admin/messages"
    assert Helpers.message_path(Endpoint, :show, 1, []) == "/admin/messages/1"
    assert Helpers.message_path(Endpoint, :show, 1) == "/admin/messages/1"
  end

  test "scoped route helpers generated named routes with :path, :alias, and :helper options" do
    assert Helpers.admin_message_path(Endpoint, :index, []) == "/admin/new/messages"
    assert Helpers.admin_message_path(Endpoint, :index) == "/admin/new/messages"
    assert Helpers.admin_message_path(Endpoint, :show, 1, []) == "/admin/new/messages/1"
    assert Helpers.admin_message_path(Endpoint, :show, 1) == "/admin/new/messages/1"
  end

  test "scoped route helpers generated unscoped :as options" do
    assert Helpers.my_admin_message_path(Endpoint, :index, []) == "/admin/new/unscoped/messages"
    assert Helpers.my_admin_message_path(Endpoint, :index) == "/admin/new/unscoped/messages"

    assert Helpers.my_admin_message_path(Endpoint, :show, 1, []) ==
             "/admin/new/unscoped/messages/1"

    assert Helpers.my_admin_message_path(Endpoint, :show, 1) == "/admin/new/unscoped/messages/1"
  end

  test "can pass an {m, f, a} tuple as a plug argument" do
    assert Helpers.sub_plug_path(Endpoint, func: {M, :f, [10]}) == "/mfa_path"
  end

  ## Others

  test "helpers module generates a url helper" do
    endpoint = Endpoint
    conn = conn_with_endpoint()
    socket = socket_with_endpoint()

    assert Helpers.url(endpoint) == "https://example.com"
    assert Helpers.url(endpoint, "/posts") == "https://example.com/posts"
    assert Helpers.url(endpoint, "/posts", page: 1) == "https://example.com/posts?page=1"
    assert Helpers.url(conn) == "https://example.com"
    assert Helpers.url(conn, "/posts") == "https://example.com/posts"
    assert Helpers.url(conn, "/posts", page: 1) == "https://example.com/posts?page=1"
    assert Helpers.url(socket) == "https://example.com"
    assert Helpers.url(socket, "/posts") == "https://example.com/posts"
    assert Helpers.url(socket, "/posts", page: 1) == "https://example.com/posts?page=1"
  end

  test "helpers module generates a path helper" do
    endpoint = Endpoint
    conn = conn_with_endpoint()
    socket = socket_with_endpoint()

    assert Helpers.path(endpoint, "/") == "/"
    assert Helpers.path(conn, "/") == "/"
    assert Helpers.path(socket, "/") == "/"
    assert Helpers.path(endpoint, "/posts") == "/posts"
    assert Helpers.path(conn, "/posts") == "/posts"
    assert Helpers.path(socket, "/posts") == "/posts"
    assert Helpers.path(endpoint, "/posts", page: 1) == "/posts?page=1"
    assert Helpers.path(conn, "/posts", page: 1) == "/posts?page=1"
    assert Helpers.path(socket, "/posts", page: 1) == "/posts?page=1"
  end

  test "helpers module generates a static_url helper" do
    endpoint = Endpoint
    conn = conn_with_endpoint()
    socket = socket_with_endpoint()

    url = "https://static.example.com/images/foo.png"
    assert Helpers.static_url(endpoint, "/images/foo.png") == url
    assert Helpers.static_url(conn, "/images/foo.png") == url
    assert Helpers.static_url(socket, "/images/foo.png") == url
  end

  test "helpers module generates a static_path helper" do
    endpoint = Endpoint
    conn = conn_with_endpoint()
    socket = socket_with_endpoint()

    assert Helpers.static_path(endpoint, "/images/foo.png") == "/images/foo.png"
    assert Helpers.static_path(conn, "/images/foo.png") == "/images/foo.png"
    assert Helpers.static_path(socket, "/images/foo.png") == "/images/foo.png"
  end

  test "helpers module generates a static_integrity helper" do
    endpoint = Endpoint
    conn = conn_with_endpoint()
    socket = socket_with_endpoint()

    assert is_nil(Helpers.static_integrity(endpoint, "/images/foo.png"))
    assert is_nil(Helpers.static_integrity(conn, "/images/foo.png"))
    assert is_nil(Helpers.static_integrity(socket, "/images/foo.png"))
  end

  test "helpers module generates named routes url helpers" do
    endpoint = Endpoint
    conn = conn_with_endpoint()
    socket = socket_with_endpoint()

    url = "https://example.com/admin/new/messages/1"
    assert Helpers.admin_message_url(endpoint, :show, 1) == url
    assert Helpers.admin_message_url(endpoint, :show, 1, []) == url
    assert Helpers.admin_message_url(conn, :show, 1) == url
    assert Helpers.admin_message_url(conn, :show, 1, []) == url
    assert Helpers.admin_message_url(socket, :show, 1) == url
    assert Helpers.admin_message_url(socket, :show, 1, []) == url
  end

  test "helpers properly encode named and query string params" do
    assert Router.Helpers.post_path(Endpoint, :show, "my path", foo: "my param") ==
             "/posts/my%20path?foo=my+param"
  end

  test "duplicate helpers with unique arities" do
    assert Helpers.product_path(Endpoint, :show) == "/products"
    assert Helpers.product_path(Endpoint, :show, foo: "bar") == "/products?foo=bar"
    assert Helpers.product_path(Endpoint, :show, 123) == "/products/123"
    assert Helpers.product_path(Endpoint, :show, 123, foo: "bar") == "/products/123?foo=bar"
    assert Helpers.product_path(Endpoint, :show, 123, "asc") == "/products/123/asc"

    assert Helpers.product_path(Endpoint, :show, 123, "asc", foo: "bar") ==
             "/products/123/asc?foo=bar"

    assert Helpers.product_path(Endpoint, :show, 123, "asc", 1) == "/products/123/asc/1"

    assert Helpers.product_path(Endpoint, :show, 123, "asc", 1, foo: "bar") ==
             "/products/123/asc/1?foo=bar"
  end

  ## Script name

  test "urls use script name" do
    assert Helpers.page_url(EndpointWithScriptName, :root) ==
             "https://example.com/api/"

    assert Helpers.page_url(conn_with_script_name(~w(foo)), :root) ==
             "https://example.com/foo/"

    assert Helpers.post_url(EndpointWithScriptName, :show, 5) ==
             "https://example.com/api/posts/5"

    assert Helpers.post_url(conn_with_script_name(), :show, 5) ==
             "https://example.com/api/posts/5"

    assert Helpers.post_url(conn_with_script_name(~w(foo)), :show, 5) ==
             "https://example.com/foo/posts/5"
  end

  test "paths use script name" do
    endpoint = EndpointWithScriptName
    conn = conn_with_script_name()

    assert Helpers.page_path(endpoint, :root) == "/api/"
    assert Helpers.post_path(endpoint, :show, 5) == "/api/posts/5"
    assert Helpers.page_path(conn, :root) == "/api/"
    assert Helpers.post_path(conn, :show, 5) == "/api/posts/5"
  end

  test "static use endpoint script name only" do
    assert Helpers.static_path(conn_with_script_name(~w(foo)), "/images/foo.png") ==
             "/api/images/foo.png"

    assert Helpers.static_url(conn_with_script_name(~w(foo)), "/images/foo.png") ==
             "https://static.example.com/api/images/foo.png"
  end

  ## Dynamics

  test "combo_router_url with string takes precedence over endpoint" do
    url = "https://comboframework.org"
    conn = Combo.Conn.put_router_url(conn_with_endpoint(), url)
    assert Helpers.url(conn) == url
    assert Helpers.admin_message_url(conn, :show, 1) == url <> "/admin/new/messages/1"
  end

  test "combo_router_url with URI takes precedence over endpoint" do
    uri = %URI{scheme: "https", host: "comboframework.org", port: 123, path: "/path"}
    conn = Combo.Conn.put_router_url(conn_with_endpoint(), uri)

    assert Helpers.url(conn) == "https://comboframework.org:123/path"

    assert Helpers.admin_message_url(conn, :show, 1) ==
             "https://comboframework.org:123/path/admin/new/messages/1"
  end

  test "combo_static_url with string takes precedence over endpoint" do
    url = "https://comboframework.org"
    conn = Combo.Conn.put_static_url(conn_with_endpoint(), url)
    assert Helpers.static_url(conn, "/images/foo.png") == url <> "/images/foo.png"

    conn = Combo.Conn.put_static_url(conn_with_script_name(), url)
    assert Helpers.static_url(conn, "/images/foo.png") == url <> "/images/foo.png"
  end

  test "combo_static_url set to string with path results in static url with that path" do
    url = "https://comboframework.org/path"
    conn = Combo.Conn.put_static_url(conn_with_endpoint(), url)
    assert Helpers.static_url(conn, "/images/foo.png") == url <> "/images/foo.png"

    conn = Combo.Conn.put_static_url(conn_with_script_name(), url)
    assert Helpers.static_url(conn, "/images/foo.png") == url <> "/images/foo.png"
  end

  test "combo_static_url with URI takes precedence over endpoint" do
    uri = %URI{scheme: "https", host: "comboframework.org", port: 123}

    conn = Combo.Conn.put_static_url(conn_with_endpoint(), uri)

    assert Helpers.static_url(conn, "/images/foo.png") ==
             "https://comboframework.org:123/images/foo.png"

    conn = Combo.Conn.put_static_url(conn_with_script_name(), uri)

    assert Helpers.static_url(conn, "/images/foo.png") ==
             "https://comboframework.org:123/images/foo.png"
  end

  test "combo_static_url set to URI with path results in static url with that path" do
    uri = %URI{scheme: "https", host: "comboframework.org", port: 123, path: "/path"}

    conn = Combo.Conn.put_static_url(conn_with_endpoint(), uri)

    assert Helpers.static_url(conn, "/images/foo.png") ==
             "https://comboframework.org:123/path/images/foo.png"

    conn = Combo.Conn.put_static_url(conn_with_script_name(), uri)

    assert Helpers.static_url(conn, "/images/foo.png") ==
             "https://comboframework.org:123/path/images/foo.png"
  end

  describe "helpers: false" do
    defmodule NoHelpersRouter do
      use Combo.Router, helpers: false

      get "/", PostController, :home
    end

    test "__helpers__ return nil" do
      assert NoHelpersRouter.__helpers__() == nil
    end

    test "test not generate Helpers module" do
      refute Code.ensure_loaded?(NoHelpersRouter.Helpers)
    end
  end
end
