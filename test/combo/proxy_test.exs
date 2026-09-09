defmodule Combo.ProxyTest do
  use ExUnit.Case
  doctest Combo.Proxy

  @tag :capture_log
  test "selects the server adapter without forwarding the option to the server" do
    assert {:ok, {_, [child]}} =
             Combo.Proxy.init(
               server: true,
               server_adapter: Combo.Proxy.ServerAdapters.Bandit,
               port: 0
             )

    assert {Bandit, :start_link, [opts]} = child.start
    assert opts[:port] == 0
    refute Keyword.has_key?(opts, :server_adapter)
  end

  test "rejects an unknown server adapter" do
    assert_raise RuntimeError, "unknown server adapter UnknownServerAdapter", fn ->
      Combo.Proxy.init(server_adapter: UnknownServerAdapter)
    end
  end
end
