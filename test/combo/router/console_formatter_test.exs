for module <- [RouteFormatter.PageController, RouteFormatter.ImageController] do
  defmodule module do
    def init(opts), do: opts
    def call(conn, _opts), do: conn
  end
end

defmodule Combo.Router.ConsoleFormatterTest do
  use ExUnit.Case, async: true
  alias Combo.Router.ConsoleFormatter

  defmodule RouterTestSingleRoutes do
    use Combo.Router

    get "/", RouteFormatter.PageController, :index, as: :page
    post "/images", RouteFormatter.ImageController, :upload, as: :upload_image
    delete "/images", RouteFormatter.ImageController, :delete, as: :remove_image
  end

  def __sockets__, do: []

  defmodule FormatterEndpoint do
    use Combo.Endpoint, otp_app: :phoenix

    socket "/socket", TestSocket, websocket: true
  end

  test "format multiple routes" do
    assert draw(RouterTestSingleRoutes) == """
           GET     /        RouteFormatter.PageController :index
           POST    /images  RouteFormatter.ImageController :upload
           DELETE  /images  RouteFormatter.ImageController :delete
           """
  end

  defmodule RouterTestResources do
    use Combo.Router
    resources "/images", RouteFormatter.ImageController
  end

  test "format resource routes" do
    assert draw(RouterTestResources) == """
           GET     /images           RouteFormatter.ImageController :index
           GET     /images/:id/edit  RouteFormatter.ImageController :edit
           GET     /images/new       RouteFormatter.ImageController :new
           GET     /images/:id       RouteFormatter.ImageController :show
           POST    /images           RouteFormatter.ImageController :create
           PATCH   /images/:id       RouteFormatter.ImageController :update
           PUT     /images/:id       RouteFormatter.ImageController :update
           DELETE  /images/:id       RouteFormatter.ImageController :delete
           """
  end

  defmodule RouterTestResource do
    use Combo.Router
    resources "/image", RouteFormatter.ImageController, singleton: true
    forward "/admin", RouteFormatter.PageController, [], as: :admin
    forward "/f1", RouteFormatter.ImageController
  end

  test "format single resource routes" do
    assert draw(RouterTestResource) == """
           GET     /image/edit  RouteFormatter.ImageController :edit
           GET     /image/new   RouteFormatter.ImageController :new
           GET     /image       RouteFormatter.ImageController :show
           POST    /image       RouteFormatter.ImageController :create
           PATCH   /image       RouteFormatter.ImageController :update
           PUT     /image       RouteFormatter.ImageController :update
           DELETE  /image       RouteFormatter.ImageController :delete
           *       /admin       RouteFormatter.PageController []
           *       /f1          RouteFormatter.ImageController []
           """
  end

  describe "endpoint sockets" do
    test "format with sockets" do
      assert draw(RouterTestSingleRoutes, FormatterEndpoint) == """
             GET     /                  RouteFormatter.PageController :index
             POST    /images            RouteFormatter.ImageController :upload
             DELETE  /images            RouteFormatter.ImageController :delete
             WS      /socket/websocket  TestSocket
             GET     /socket/longpoll   TestSocket
             POST    /socket/longpoll   TestSocket
             """
    end

    test "format without sockets" do
      assert draw(RouterTestSingleRoutes, __MODULE__) == """
             GET     /        RouteFormatter.PageController :index
             POST    /images  RouteFormatter.ImageController :upload
             DELETE  /images  RouteFormatter.ImageController :delete
             """
    end
  end

  defp draw(router, endpoint \\ nil) do
    ConsoleFormatter.format(router, endpoint)
  end
end
