defmodule Combo.Socket.Message do
  @moduledoc """
  Defines a message dispatched over transport to channels and vice-versa.

  The message format requires the following keys:

    * `:topic` - The string topic or topic:subtopic pair namespace, for
      example "messages", "messages:123"
    * `:event`- The string event name, for example "phx_join"
    * `:payload` - The message payload
    * `:ref` - The unique string ref
    * `:join_ref` - The unique string ref when joining

  """

  @type t :: %Combo.Socket.Message{}
  defstruct topic: nil, event: nil, payload: nil, ref: nil, join_ref: nil

  @doc """
  Converts a map with string keys into a message struct.

  Raises `Combo.Socket.InvalidMessageError` if not valid.
  """
  def from_map!(map) when is_map(map) do
    try do
      %Combo.Socket.Message{
        topic: Map.fetch!(map, "topic"),
        event: Map.fetch!(map, "event"),
        payload: Map.fetch!(map, "payload"),
        ref: Map.fetch!(map, "ref"),
        join_ref: Map.get(map, "join_ref")
      }
    rescue
      err in [KeyError] ->
        raise Combo.Socket.InvalidMessageError, "missing key #{inspect(err.key)}"
    end
  end
end

defmodule Combo.Socket.Reply do
  @moduledoc """
  Defines a reply sent from channels to transports.

  The message format requires the following keys:

    * `:topic` - The string topic or topic:subtopic pair namespace, for example "messages", "messages:123"
    * `:status` - The reply status as an atom
    * `:payload` - The reply payload
    * `:ref` - The unique string ref
    * `:join_ref` - The unique string ref when joining

  """

  @type t :: %Combo.Socket.Reply{}
  defstruct topic: nil, status: nil, payload: nil, ref: nil, join_ref: nil
end

defmodule Combo.Socket.Broadcast do
  @moduledoc """
  Defines a message sent from pubsub to channels and vice-versa.

  The message format requires the following keys:

    * `:topic` - The string topic or topic:subtopic pair namespace, for example "messages", "messages:123"
    * `:event`- The string event name, for example "phx_join"
    * `:payload` - The message payload

  """

  @type t :: %Combo.Socket.Broadcast{}
  defstruct topic: nil, event: nil, payload: nil
end
