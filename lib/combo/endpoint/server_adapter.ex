defmodule Combo.Endpoint.ServerAdapter do
  @moduledoc """
  The behaviour for serving a `Combo.Endpoint` with an HTTP server.

  A server adapter connects the endpoint to a server implementation.

  And, it is also responsible for arranging connection draining when
  the endpoint shuts down.
  """

  @type config :: keyword()
  @type scheme :: :http | :https

  @doc """
  Returns the server child specs to add to the endpoint's supervision tree when
  its server is enabled.

  It receives the endpoint module and config, including the `:http` and `:https`
  options.
  """
  @callback child_specs(Combo.Endpoint.t(), config()) :: [Supervisor.child_spec(), ...]

  @doc """
  Returns the listening ip address and port number of server process for the
  provided scheme.
  """
  @callback server_info(Combo.Endpoint.t(), scheme()) ::
              {:ok, {ip :: :inet.ip_address(), port :: :inet.port_number()}}
              | {:error, reason :: term()}
end
