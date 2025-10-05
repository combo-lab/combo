defmodule Combo.Proxy.ConfigTest do
  use ExUnit.Case, async: true
  alias Combo.Proxy.Config

  defmodule PlugPlaceholder do
    @behaviour Plug

    @impl true
    def init(opts), do: opts

    @impl true
    def call(conn, _opts), do: conn
  end

  describe "backends are sorted by specificity" do
    test "method has highest specificity, followed by host, then path" do
      assert %{
               backends: [
                 %Combo.Proxy.Backend{
                   method: "GET"
                 },
                 %Combo.Proxy.Backend{
                   host: "www.example.com"
                 },
                 %Combo.Proxy.Backend{
                   path: "/"
                 }
               ]
             } =
               Config.new!(
                 backends: [
                   %{
                     plug: PlugPlaceholder,
                     path: "/"
                   },
                   %{
                     plug: PlugPlaceholder,
                     host: "www.example.com"
                   },
                   %{
                     plug: PlugPlaceholder,
                     method: "GET"
                   }
                 ]
               )
    end

    test "backends with host are sorted" do
      assert %{
               backends: [
                 %Combo.Proxy.Backend{
                   host: "www.example.com"
                 },
                 %Combo.Proxy.Backend{
                   host: ~r/^.*\.example\.com$/
                 }
               ]
             } =
               Config.new!(
                 backends: [
                   %{
                     plug: PlugPlaceholder,
                     host: ~r/^.*\.example\.com$/
                   },
                   %{
                     plug: PlugPlaceholder,
                     host: "www.example.com"
                   }
                 ]
               )
    end

    test "backends with path are sorted" do
      assert %{
               backends: [
                 %Combo.Proxy.Backend{
                   path: "/api/v1"
                 },
                 %Combo.Proxy.Backend{
                   path: "/health"
                 },
                 %Combo.Proxy.Backend{
                   path: "/admin"
                 },
                 %Combo.Proxy.Backend{
                   path: "/"
                 }
               ]
             } =
               Config.new!(
                 backends: [
                   %{
                     plug: PlugPlaceholder,
                     path: "/health"
                   },
                   %{
                     plug: PlugPlaceholder,
                     path: "/"
                   },
                   %{
                     plug: PlugPlaceholder,
                     path: "/admin"
                   },
                   %{
                     plug: PlugPlaceholder,
                     path: "/api/v1"
                   }
                 ]
               )
    end
  end
end
