defmodule Combo.Socket.V1.JSONSerializer do
  @moduledoc false
  @behaviour Combo.Socket.Serializer

  alias Combo.Socket.{Broadcast, Message, Reply}

  @impl true
  def fastlane!(%Broadcast{} = msg) do
    map = %Message{topic: msg.topic, event: msg.event, payload: msg.payload}
    {:socket_push, :text, encode_v1_fields_only(map)}
  end

  @impl true
  def encode!(%Reply{} = reply) do
    map = %Message{
      topic: reply.topic,
      event: "phx_reply",
      ref: reply.ref,
      payload: %{status: reply.status, response: reply.payload}
    }

    {:socket_push, :text, encode_v1_fields_only(map)}
  end

  def encode!(%Message{} = map) do
    {:socket_push, :text, encode_v1_fields_only(map)}
  end

  @impl true
  def decode!(message, _opts) do
    payload = Combo.json_library().decode!(message)

    case payload do
      %{} ->
        Combo.Socket.Message.from_map!(payload)

      other ->
        raise "V1 JSON Serializer expected a map, got #{inspect(other)}"
    end
  end

  defp encode_v1_fields_only(%Message{} = msg) do
    msg
    |> Map.take([:topic, :event, :payload, :ref])
    |> Combo.json_library().encode_to_iodata!()
  end
end
