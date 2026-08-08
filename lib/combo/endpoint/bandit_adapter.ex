if Code.ensure_loaded?(Bandit) do
  defmodule Combo.Endpoint.BanditAdapter do
    @moduledoc """
    The Bandit adapter for `Combo.Endpoint`.

    To use this adapter, bandit should be installed as a dependency:

        {:bandit, "~> 1.0"}

    Once bandit is installed, set the `:adapter` option to your endpoint
    configuration. For example:

        config :demo, Demo.Web.Endpoint,
          adapter: Combo.Endpoint.BanditAdapter

    ## Endpoint configuration

    This adapter uses the following endpoint configuration:

    * `:http` - the configuration for the HTTP server. It accepts all options
      as defined by `t:Bandit.options/0`. Defaults to `false`.

    * `:https` - the configuration for the HTTPS server. It accepts all options
      as defined by `t:Bandit.options/0`. Defaults to `false`.

    For example:

        config :demo, Demo.Web.Endpoint,
          http: [
            ip: {127, 0, 0, 1},
            port: 4000,
            thousand_island_options: [num_acceptors: 12],
            http_options: [log_protocol_errors: false],
            http_1_options: [max_requests: 1],
            websocket_options: [compress: false]
          ]

    ## Connection draining

    Bandit has built-in support of connection draining.

    ## Thanks

    The original code comes from `Bandit.PhoenixAdapter` of
    [bandit](https://github.com/mtrudel/bandit) which is created by Mat Trudel.
    """

    @behaviour Combo.Endpoint.Adapter

    @impl true
    def child_specs(endpoint, config) do
      otp_app = Keyword.fetch!(config, :otp_app)

      plug = resolve_plug(config[:code_reloader], endpoint)

      for scheme <- [:http, :https], opts = config[scheme] do
        ([plug: plug, display_plug: endpoint, scheme: scheme, otp_app: otp_app] ++ opts)
        |> Bandit.child_spec()
        |> Supervisor.child_spec(id: {endpoint, scheme})
      end
    end

    @impl true
    def server_info(endpoint, scheme) do
      case bandit_pid(endpoint, scheme) do
        {:ok, pid} -> ThousandIsland.listener_info(pid)
        {:error, reason} -> {:error, reason}
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

    # Returns the Bandit server process for the provided scheme within the given
    # endpoint.
    @spec bandit_pid(module(), atom()) ::
            {:ok, Supervisor.child() | :restarting | :undefined} | {:error, :no_server_found}
    defp bandit_pid(endpoint, scheme) do
      endpoint
      |> Supervisor.which_children()
      |> Enum.find(fn {id, _, _, _} -> id == {endpoint, scheme} end)
      |> case do
        {_, pid, _, _} -> {:ok, pid}
        nil -> {:error, :no_server_found}
      end
    end
  end
end
