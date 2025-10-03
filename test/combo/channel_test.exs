defmodule Combo.Channel.ChannelTest do
  use ExUnit.Case, async: true

  @pubsub __MODULE__.PubSub
  import Combo.Channel

  setup_all do
    start_supervised!({Combo.PubSub, name: @pubsub, pool_size: 1})
    :ok
  end

  test "broadcasts from self" do
    Combo.PubSub.subscribe(@pubsub, "sometopic")

    socket = %Combo.Socket{
      pubsub_server: @pubsub,
      topic: "sometopic",
      channel_pid: self(),
      joined: true
    }

    broadcast_from(socket, "event1", %{key: :val})

    refute_received %Combo.Socket.Broadcast{
      event: "event1",
      payload: %{key: :val},
      topic: "sometopic"
    }

    broadcast_from!(socket, "event2", %{key: :val})

    refute_received %Combo.Socket.Broadcast{
      event: "event2",
      payload: %{key: :val},
      topic: "sometopic"
    }

    broadcast(socket, "event3", %{key: :val})

    assert_receive %Combo.Socket.Broadcast{
      event: "event3",
      payload: %{key: :val},
      topic: "sometopic"
    }

    broadcast!(socket, "event4", %{key: :val})

    assert_receive %Combo.Socket.Broadcast{
      event: "event4",
      payload: %{key: :val},
      topic: "sometopic"
    }
  end

  test "broadcasts from other" do
    Combo.PubSub.subscribe(@pubsub, "sometopic")

    socket = %Combo.Socket{
      pubsub_server: @pubsub,
      topic: "sometopic",
      channel_pid: spawn_link(fn -> :ok end),
      joined: true
    }

    broadcast_from(socket, "event1", %{key: :val})

    assert_receive %Combo.Socket.Broadcast{
      event: "event1",
      payload: %{key: :val},
      topic: "sometopic"
    }

    broadcast_from!(socket, "event2", %{key: :val})

    assert_receive %Combo.Socket.Broadcast{
      event: "event2",
      payload: %{key: :val},
      topic: "sometopic"
    }

    broadcast(socket, "event3", %{key: :val})

    assert_receive %Combo.Socket.Broadcast{
      event: "event3",
      payload: %{key: :val},
      topic: "sometopic"
    }

    broadcast!(socket, "event4", %{key: :val})

    assert_receive %Combo.Socket.Broadcast{
      event: "event4",
      payload: %{key: :val},
      topic: "sometopic"
    }
  end

  test "pushing to transport" do
    socket = %Combo.Socket{
      serializer: Combo.ChannelTest.NoopSerializer,
      topic: "sometopic",
      transport_pid: self(),
      joined: true
    }

    push(socket, "event1", %{key: :val})

    assert_receive %Combo.Socket.Message{
      event: "event1",
      payload: %{key: :val},
      topic: "sometopic"
    }
  end

  test "replying to transport" do
    socket = %Combo.Socket{
      serializer: Combo.ChannelTest.NoopSerializer,
      ref: "123",
      topic: "sometopic",
      transport_pid: self(),
      joined: true
    }

    ref = socket_ref(socket)
    reply(ref, {:ok, %{key: :val}})

    assert_receive %Combo.Socket.Reply{
      payload: %{key: :val},
      ref: "123",
      status: :ok,
      topic: "sometopic"
    }
  end

  test "replying just status to transport" do
    socket = %Combo.Socket{
      serializer: Combo.ChannelTest.NoopSerializer,
      ref: "123",
      topic: "sometopic",
      transport_pid: self(),
      joined: true
    }

    ref = socket_ref(socket)
    reply(ref, :ok)

    assert_receive %Combo.Socket.Reply{
      payload: %{},
      ref: "123",
      status: :ok,
      topic: "sometopic"
    }
  end

  test "socket_ref raises ArgumentError when socket is not joined or has no ref" do
    assert_raise ArgumentError, ~r"join", fn ->
      socket_ref(%Combo.Socket{joined: false})
    end

    assert_raise ArgumentError, ~r"ref", fn ->
      socket_ref(%Combo.Socket{joined: true})
    end
  end
end
