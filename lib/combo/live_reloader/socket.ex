defmodule Combo.LiveReloader.Socket do
  @moduledoc """
  The Socket handler for `combo:live_reload` channel.
  """

  use Combo.Socket, log: false
  alias Combo.LiveReloader.Channel

  channel "combo:live_reload", Channel

  def connect(_params, socket), do: {:ok, socket}
  def id(_socket), do: nil
end
