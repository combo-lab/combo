defmodule Combo.Endpoint.Adapter do
  @moduledoc false

  @type endpoint :: module()
  @type config :: Keyword.t()
  @type scheme :: :http | :https

  @doc """
  Returns the child specs of servers for the provided endpoint with the given
  config.
  """
  @callback child_specs(endpoint(), config()) :: [Supervisor.child_spec(), ...]

  @doc """
  Returns the ip address and port number of server process for the provided
  scheme within the given endpoint.
  """
  @callback server_info(endpoint(), scheme()) ::
              {:ok, {ip :: :inet.ip_address(), port :: :inet.port_number()}}
              | {:error, reason :: term()}
end
