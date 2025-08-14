defmodule Combo.LiveReloader.Socket do
  @moduledoc """
  The Socket handler for `combo:live_reload` channel.
  """

  use Combo.Socket, log: false

  channel "combo:live_reload", Combo.LiveReloader.Channel

  def connect(_params, socket), do: {:ok, socket}

  def id(_socket), do: nil
end
