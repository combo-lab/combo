defmodule Combo.Socket.MessageTest do
  use ExUnit.Case, async: true
  doctest Combo.Socket.Message

  alias Combo.Socket.Message

  describe "inspect/2 custom implementation" do
    test "filters sensitive values in form submit events" do
      message = %Message{
        topic: "t:1",
        event: "event",
        payload: %{
          "event" => "submit",
          "type" => "form",
          "value" => "username=john&password=secret123&email=john@example.com"
        },
        ref: "1",
        join_ref: "1"
      }

      assert inspect(message) =~ "\"value\" => \"[FILTERED]\""
    end

    test "filters sensitive values at the end of form submit events" do
      message = %Message{
        topic: "t:1",
        event: "event",
        payload: %{
          "event" => "submit",
          "type" => "form",
          "value" => "username=john&password=secret123"
        },
        ref: "1",
        join_ref: "1"
      }

      assert inspect(message) =~ "\"value\" => \"[FILTERED]\""
    end

    test "handles malformed query strings gracefully" do
      message = %Message{
        topic: "t:1",
        event: "event",
        payload: %{
          "event" => "submit",
          "type" => "form",
          "value" => "invalid=query=string&password=secret"
        },
        ref: "1",
        join_ref: "1"
      }

      assert inspect(message) =~ "\"value\" => \"[FILTERED]\""
    end
  end
end
