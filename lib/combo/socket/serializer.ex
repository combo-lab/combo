defmodule Combo.Socket.Serializer do
  @moduledoc """
  A behaviour that serializes incoming and outgoing socket messages.

  By default, Combo provides a serializer that encodes to JSON and
  decodes JSON messages.

  Custom serializers may be configured in the socket.
  """

  @type opcode :: :text | :binary

  @doc """
  Encodes a `%Combo.Socket.Broadcast{}` to fastlane format.
  """
  @callback fastlane!(Combo.Socket.Broadcast.t()) ::
              {:socket_push, opcode(), iodata()}

  @doc """
  Encodes `%Combo.Socket.Message{}` and `%Combo.Socket.Reply{}` to push format.
  """
  @callback encode!(Combo.Socket.Message.t() | Combo.Socket.Reply.t()) ::
              {:socket_push, opcode(), iodata()}

  @doc """
  Decodes iodata into `%Combo.Socket.Message{}`.
  """
  @callback decode!(iodata, options :: keyword()) ::
              Combo.Socket.Message.t()
end
