defmodule Combo.LoggerTest do
  use ExUnit.Case, async: true
  use Support.RouterHelper

  describe "telemetry" do
    def log_level(conn) do
      case conn.path_info do
        [] -> :debug
        ["warn" | _] -> :warning
        ["error" | _] -> :error
        ["false" | _] -> false
        _ -> :info
      end
    end

    test "invokes log level callback from Plug.Telemetry" do
      opts =
        Plug.Telemetry.init(
          event_prefix: [:combo, :endpoint],
          log: {__MODULE__, :log_level, []}
        )

      assert ExUnit.CaptureLog.capture_log(fn ->
               Plug.Telemetry.call(conn(:get, "/"), opts)
             end) =~ "[debug] GET /"

      assert ExUnit.CaptureLog.capture_log(fn ->
               Plug.Telemetry.call(conn(:get, "/warn"), opts)
             end) =~ ~r"\[warn(ing)?\]  ?GET /warn"

      assert ExUnit.CaptureLog.capture_log(fn ->
               Plug.Telemetry.call(conn(:get, "/error/404"), opts)
             end) =~ "[error] GET /error/404"

      assert ExUnit.CaptureLog.capture_log(fn ->
               Plug.Telemetry.call(conn(:get, "/any"), opts)
             end) =~ "[info] GET /any"
    end

    test "invokes log level from Plug.Telemetry" do
      assert ExUnit.CaptureLog.capture_log(fn ->
               opts = Plug.Telemetry.init(event_prefix: [:combo, :endpoint], log: :error)
               Plug.Telemetry.call(conn(:get, "/"), opts)
             end) =~ "[error] GET /"
    end
  end
end
