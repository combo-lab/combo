defmodule Combo.Endpoint.BanditAdapter do
  @moduledoc """
  The Bandit adapter for `Combo.Endpoint`.

  To use this adapter, bandit should be installed as a dependency:

      {:bandit, "~> 1.0"}

  Once bandit is installed, set the `:adapter` option to your endpoint
  configuration. For example:

      config :demo, Demo.Web.Endpoint,
        adapter: Combo.Endpoint.BanditAdapter

  Good to know that it's the default adapter, so you don't have to set
  `:adapter` option.

  ## Endpoint configuration

  This adapter supports the structure for endpoint configuration.

  Top-level keys for `:http` and `:https` are supported, and values within
  within each of those are interpreted as raw Bandit configuration as specified
  by `t:Bandit.options/0`.

  It can be difficult to know exactly where to put the options that you may
  need to set from the ones available at `t:Bandit.options/0`. The general
  idea is that anything inside the `http:` or `https:` keyword lists in
  your configuration are passed directly to `Bandit.start_link/1`, so an
  example may look like so:

      config :demo, Demo.Web.Endpoint,
        http: [
          ip: {127, 0, 0, 1},
          port: 4000,
          thousand_island_options: [num_acceptors: 123],
          http_options: [log_protocol_errors: false],
          http_1_options: [max_requests: 1],
          websocket_options: [compress: false]
        ]

  ## Thanks

  The original code comes from `Bandit.PhoenixAdapter` of
  [bandit](https://github.com/mtrudel/bandit) which is created by Mat Trudel.

  """

  @doc """
  Returns the Bandit server process for the provided scheme within the given
  endpoint.
  """
  @spec bandit_pid(module()) ::
          {:ok, Supervisor.child() | :restarting | :undefined} | {:error, :no_server_found}
  def bandit_pid(endpoint, scheme \\ :http) do
    endpoint
    |> Supervisor.which_children()
    |> Enum.find(fn {id, _, _, _} -> id == {endpoint, scheme} end)
    |> case do
      {_, pid, _, _} -> {:ok, pid}
      nil -> {:error, :no_server_found}
    end
  end

  @doc """
  Returns the bound address and port of the Bandit server process for the
  provided scheme within the given endpoint.
  """
  def server_info(endpoint, scheme) do
    case bandit_pid(endpoint, scheme) do
      {:ok, pid} -> ThousandIsland.listener_info(pid)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  def child_specs(endpoint, config) do
    otp_app = Keyword.fetch!(config, :otp_app)

    plug = resolve_plug(config[:code_reloader], endpoint)

    for scheme <- [:http, :https], opts = config[scheme] do
      ([plug: plug, display_plug: endpoint, scheme: scheme, otp_app: otp_app] ++ opts)
      |> Bandit.child_spec()
      |> Supervisor.child_spec(id: {endpoint, scheme})
    end
  end

  defp resolve_plug(code_reload?, endpoint) do
    if code_reload? &&
         Code.ensure_loaded?(Combo.Endpoint.SyncCodeReloadPlug) &&
         function_exported?(Combo.Endpoint.SyncCodeReloadPlug, :call, 2) do
      {Combo.Endpoint.SyncCodeReloadPlug, {endpoint, []}}
    else
      endpoint
    end
  end
end
