defmodule Combo.Controller.ControllerTest do
  use ExUnit.Case, async: true

  describe "__using__" do
    defp view_formats(module, opts), do: Combo.Controller.__view_formats__(module, opts)

    test "returns view modules based on format" do
      assert view_formats(Demo.Web.UserController, []) ==
               []

      assert view_formats(Demo.Web.UserController, formats: [:html, :json]) ==
               [html: Demo.Web.UserHTML, json: Demo.Web.UserJSON]

      assert view_formats(Demo.Web.UserController, formats: [:html, json: "View"]) ==
               [html: Demo.Web.UserHTML, json: Demo.Web.UserView]
    end

    test "raises on bad formats" do
      message = """
      expected :formats option to be a list following this spec:

          [format()] | [{format(), suffix()}]

      Got:

          :bad
      """

      assert_raise ArgumentError, message, fn ->
        view_formats(MyApp.UserController, formats: :bad)
      end
    end
  end
end
