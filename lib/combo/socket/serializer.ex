defmodule Combo.Socket.Serializer do
  @moduledoc """
  A behaviour that serializes incoming and outgoing socket messages.

  By default, Combo provides a serializer that encodes to JSON and
  decodes JSON messages.

  Custom serializers may be configured in the socket.
  """

  @doc """
  Encodes a `Combo.Socket.Broadcast` struct to fastlane format.
  """
  @callback fastlane!(Combo.Socket.Broadcast.t()) ::
              {:socket_push, :text, iodata()}
              | {:socket_push, :binary, iodata()}

  @doc """
  Encodes `Combo.Socket.Message` and `Combo.Socket.Reply` structs to push format.
  """
  @callback encode!(Combo.Socket.Message.t() | Combo.Socket.Reply.t()) ::
              {:socket_push, :text, iodata()}
              | {:socket_push, :binary, iodata()}

  @doc """
  Decodes iodata into `Combo.Socket.Message` struct.
  """
  @callback decode!(iodata, options :: Keyword.t()) :: Combo.Socket.Message.t()
end
