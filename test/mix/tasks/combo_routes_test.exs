Code.require_file("./mix_helper.exs", __DIR__)

defmodule PageController do
  def init(opts), do: opts
  def call(conn, _opts), do: conn

  defmodule Live do
    def init(opts), do: opts
  end
end

defmodule ComboTestWeb.Router do
  use Support.Router
  get "/", PageController, :index, as: :page
end

defmodule ComboTestLiveWeb.Router do
  use Support.Router
  get "/", PageController, :index, metadata: %{mfa: {PageController.Live, :init, 1}}
end

defmodule ComboTestWeb.ForwardedRouter do
  use Support.Router
  forward "/", ComboTestWeb.PlugRouterWithVerifiedRoutes
end

defmodule ComboTestWeb.PlugRouterWithVerifiedRoutes do
  use Plug.Router

  @behaviour Combo.VerifiedRoutes

  get "/foo" do
    send_resp(conn, 200, "ok")
  end

  @impl Combo.VerifiedRoutes
  def formatted_routes(_plug_opts) do
    [
      %{verb: "GET", path: "/foo", label: "Hello"}
    ]
  end

  @impl Combo.VerifiedRoutes
  def verified_route?(_plug_opts, path) do
    path == ["foo"]
  end
end

defmodule Mix.Tasks.Combo.RoutesTest do
  use ExUnit.Case, async: true

  import Mix.Tasks.Combo.Routes

  test "format routes for router" do
    run(["ComboTestWeb.Router", "--no-compile"])
    assert_received {:mix_shell, :info, [routes]}
    assert routes =~ "GET  /  PageController :index"
  end

  test "format routes for forwarded router that implements verified routes" do
    run(["ComboTestWeb.ForwardedRouter", "--no-compile"])
    assert_received {:mix_shell, :info, [routes]}
    assert routes =~ "GET  /foo  Hello"
  end

  test "prints error when router cannot be found" do
    assert_raise Mix.Error,
                 "the provided router, Foo.UnknownBar.CantFindBaz, does not exist",
                 fn ->
                   run(["Foo.UnknownBar.CantFindBaz", "--no-compile"])
                 end
  end

  test "overrides module name for route with :mfa metadata" do
    run(["ComboTestLiveWeb.Router", "--no-compile"])
    assert_received {:mix_shell, :info, [routes]}
    assert routes =~ "GET  /  PageController.Live :index"
  end
end
