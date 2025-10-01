defmodule Combo.LiveReloader.Socket do
  @moduledoc """
  The Socket handler for `combo:live_reloader` channel.
  """

  use Combo.Socket, log: false
  alias Combo.LiveReloader.Channel

  channel "combo:live_reloader", Channel

  @impl true
  def connect(_params, socket), do: {:ok, socket}

  @impl true
  def id(_socket), do: nil
end
