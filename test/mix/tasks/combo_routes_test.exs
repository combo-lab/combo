Code.require_file("./mix_helper.exs", __DIR__)

defmodule PageController do
  def init(opts), do: opts
  def call(conn, _opts), do: conn
end

defmodule ComboTestWeb.Router do
  use Support.Router
  get "/", PageController, :index, as: :page
end

defmodule Mix.Tasks.Combo.RoutesTest do
  use ExUnit.Case, async: true

  import Mix.Tasks.Combo.Routes

  test "format routes for router" do
    run(["ComboTestWeb.Router", "--no-compile"])
    assert_received {:mix_shell, :info, [routes]}
    assert routes =~ "GET  /  PageController :index"
  end

  test "prints error when router cannot be found" do
    assert_raise Mix.Error,
                 "the provided router, Foo.UnknownBar.CantFindBaz, does not exist",
                 fn ->
                   run(["Foo.UnknownBar.CantFindBaz", "--no-compile"])
                 end
  end
end
