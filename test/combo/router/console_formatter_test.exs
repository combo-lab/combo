for module <- [
      Combo.Router.ConsoleFormatterTest.PageController,
      Combo.Router.ConsoleFormatterTest.ImageController
    ] do
  defmodule module do
    def init(opts), do: opts
    def call(conn, _opts), do: conn
  end
end

defmodule Combo.Router.ConsoleFormatterTest do
  use ExUnit.Case, async: true
  alias Combo.Router.ConsoleFormatter
  alias Combo.Router.ConsoleFormatterTest.PageController
  alias Combo.Router.ConsoleFormatterTest.ImageController

  defmodule Endpoint do
    use Combo.Endpoint, otp_app: :combo
  end

  defmodule EndpointWithSocket do
    use Combo.Endpoint, otp_app: :combo
    socket "/socket", TestSocket, websocket: true
  end

  defmodule MatchRouter do
    use Combo.Router
    get "/", PageController, :index, as: :page
    post "/images", ImageController, :upload, as: :upload_image
    delete "/images", ImageController, :delete, as: :remove_image
  end

  defmodule ForwardRouter do
    use Combo.Router
    forward "/admin", PageController, [], as: :admin
    forward "/f1", ImageController
  end

  defmodule MixedRouter do
    use Combo.Router
    get "/", PageController, :index, as: :page
    post "/images", ImageController, :upload, as: :upload_image
    delete "/images", ImageController, :delete, as: :remove_image
    forward "/admin", PageController, [], as: :admin
    forward "/f1", ImageController
  end

  test "format :match routes" do
    assert draw(MatchRouter, Endpoint) == """
                   page_path  GET     /        Combo.Router.ConsoleFormatterTest.PageController :index
           upload_image_path  POST    /images  Combo.Router.ConsoleFormatterTest.ImageController :upload
           remove_image_path  DELETE  /images  Combo.Router.ConsoleFormatterTest.ImageController :delete
           """
  end

  test "format :forward routes" do
    assert draw(ForwardRouter, Endpoint) == """
             *  /admin  Combo.Router.ConsoleFormatterTest.PageController []
             *  /f1     Combo.Router.ConsoleFormatterTest.ImageController []
           """
  end

  test "format mixed routes" do
    assert draw(MixedRouter, Endpoint) == """
                   page_path  GET     /        Combo.Router.ConsoleFormatterTest.PageController :index
           upload_image_path  POST    /images  Combo.Router.ConsoleFormatterTest.ImageController :upload
           remove_image_path  DELETE  /images  Combo.Router.ConsoleFormatterTest.ImageController :delete
                              *       /admin   Combo.Router.ConsoleFormatterTest.PageController []
                              *       /f1      Combo.Router.ConsoleFormatterTest.ImageController []
           """
  end

  describe "format routes" do
    test "without sockets" do
      assert draw(MatchRouter, Endpoint) == """
                     page_path  GET     /        Combo.Router.ConsoleFormatterTest.PageController :index
             upload_image_path  POST    /images  Combo.Router.ConsoleFormatterTest.ImageController :upload
             remove_image_path  DELETE  /images  Combo.Router.ConsoleFormatterTest.ImageController :delete
             """
    end

    test "with sockets" do
      assert draw(MatchRouter, EndpointWithSocket) == """
                     page_path  GET     /                  Combo.Router.ConsoleFormatterTest.PageController :index
             upload_image_path  POST    /images            Combo.Router.ConsoleFormatterTest.ImageController :upload
             remove_image_path  DELETE  /images            Combo.Router.ConsoleFormatterTest.ImageController :delete
                                WS      /socket/websocket  TestSocket
                                GET     /socket/longpoll   TestSocket
                                POST    /socket/longpoll   TestSocket
             """
    end
  end

  defp draw(router, endpoint), do: ConsoleFormatter.format(router, endpoint)
end
