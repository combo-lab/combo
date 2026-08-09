defmodule Combo.Transports.WebSocketTest do
  use ExUnit.Case, async: true
  use Support.RouterHelper

  alias Combo.Transports.WebSocket

  setup do
    Logger.put_process_level(self(), :none)
  end

  defp check_subprotocols(expected, passed) do
    conn = conn(:get, "/") |> put_req_header("sec-websocket-protocol", Enum.join(passed, ", "))
    WebSocket.check_subprotocols(conn, expected)
  end

  test "does not check subprotocols if no expected subprotocols are configured" do
    refute check_subprotocols(nil, ["sip"]).halted
  end

  test "does not check subprotocols if conn is halted" do
    halted_conn = conn(:get, "/") |> halt()
    assert WebSocket.check_subprotocols(halted_conn, ["sip"]) == halted_conn
  end

  test "returns first matched subprotocol" do
    conn = check_subprotocols(["sip", "mqtt"], ["sip", "mqtt"])

    refute conn.halted
    assert get_resp_header(conn, "sec-websocket-protocol") == ["sip"]
  end

  test "halts if expected and requested subprotocols don't match" do
    conn = check_subprotocols(["sip"], ["mqtt"])

    assert conn.halted
    assert conn.status == 403
  end

  test "halts if expected subprotocols have the wrong format" do
    conn = check_subprotocols("sip", ["mqtt"])

    assert conn.halted
    assert conn.status == 403
  end
end
