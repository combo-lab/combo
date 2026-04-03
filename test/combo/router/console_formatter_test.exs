for controller <- [
      Combo.Router.ConsoleFormatterTest.PageController,
      Combo.Router.ConsoleFormatterTest.ImageController
    ] do
  defmodule controller do
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
    socket "/socket", __MODULE__.TestSocket, websocket: true
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
                   page  GET     /        Combo.Router.ConsoleFormatterTest.PageController :index
           upload_image  POST    /images  Combo.Router.ConsoleFormatterTest.ImageController :upload
           remove_image  DELETE  /images  Combo.Router.ConsoleFormatterTest.ImageController :delete
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
                   page  GET     /        Combo.Router.ConsoleFormatterTest.PageController :index
           upload_image  POST    /images  Combo.Router.ConsoleFormatterTest.ImageController :upload
           remove_image  DELETE  /images  Combo.Router.ConsoleFormatterTest.ImageController :delete
                         *       /admin   Combo.Router.ConsoleFormatterTest.PageController []
                         *       /f1      Combo.Router.ConsoleFormatterTest.ImageController []
           """
  end

  describe "format routes" do
    test "without sockets" do
      assert draw(MatchRouter, Endpoint) == """
                     page  GET     /        Combo.Router.ConsoleFormatterTest.PageController :index
             upload_image  POST    /images  Combo.Router.ConsoleFormatterTest.ImageController :upload
             remove_image  DELETE  /images  Combo.Router.ConsoleFormatterTest.ImageController :delete
             """
    end

    test "with sockets" do
      assert draw(MatchRouter, EndpointWithSocket) == """
                     page  GET     /                  Combo.Router.ConsoleFormatterTest.PageController :index
             upload_image  POST    /images            Combo.Router.ConsoleFormatterTest.ImageController :upload
             remove_image  DELETE  /images            Combo.Router.ConsoleFormatterTest.ImageController :delete
                           WS      /socket/websocket  Combo.Router.ConsoleFormatterTest.EndpointWithSocket.TestSocket
                           GET     /socket/longpoll   Combo.Router.ConsoleFormatterTest.EndpointWithSocket.TestSocket
                           POST    /socket/longpoll   Combo.Router.ConsoleFormatterTest.EndpointWithSocket.TestSocket
             """
    end
  end

  defp draw(router, endpoint), do: ConsoleFormatter.format(router, endpoint)
end
