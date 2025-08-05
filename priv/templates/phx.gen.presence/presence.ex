defmodule <%= module %> do
  @moduledoc """
  Provides presence tracking to channels and processes.

  See the [`Combo.Presence`](https://hexdocs.pm/phoenix/Combo.Presence.html)
  docs for more details.
  """
  use Combo.Presence,
    otp_app: <%= inspect otp_app %>,
    pubsub_server: <%= inspect pubsub_server %>
end
