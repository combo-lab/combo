defmodule Combo.Endpoint.BanditAdapter do
  @moduledoc """
  The Bandit adapter for `Combo.Endpoint`.

  To use this adapter, bandit should be installed as a dependency:

      {:bandit, "~> 1.0"}

  Once Bandit is installed, add the `:adapter` option to the endpoint
  configuration in `config/config.exs`, as in the following example:

      # config/config.exs
      config :your_app, YourAppWeb.Endpoint,
        adapter: Combo.Endpoint.BanditAdapter, # <---- ADD THIS LINE
        url: [host: "localhost"],
        render_errors: ...

  That's it! **After restarting Combo you should see the startup message indicate that it is being
  served by Bandit**, and everything should 'just work'. Note that if you have set any exotic
  configuration options within your endpoint, you may need to update that configuration to work
  with Bandit; see below for details.

  ## Endpoint configuration

  This adapter supports the standard Combo structure for endpoint configuration. Top-level keys for
  `:http` and `:https` are supported, and configuration values within each of those are interpreted
  as raw Bandit configuration as specified by `t:Bandit.options/0`. Bandit's configuration supports
  all values used in a standard out-of-the-box Combo application, so if you haven't made any
  substantial changes to your endpoint configuration things should 'just work' for you.

  In the event that you *have* made advanced changes to your endpoint configuration, you may need
  to update this config to work with Bandit. Consult Bandit's documentation at
  `t:Bandit.options/0` for details.

  It can be difficult to know exactly *where* to put the options that you may need to set from the
  ones available at `t:Bandit.options/0`. The general idea is that anything inside the `http:` or
  `https:` keyword lists in your configuration are passed directly to `Bandit.start_link/1`, so an
  example may look like so:

  ```elixir
  # config/{dev,prod,etc}.exs

  config :your_app, YourAppWeb.Endpoint,
    http: [
      ip: {127, 0, 0, 1},
      port: 4000,
      thousand_island_options: [num_acceptors: 123],
      http_options: [log_protocol_errors: false],
      http_1_options: [max_requests: 1],
      websocket_options: [compress: false]
    ],
  ```

  Note that, unlike the `adapter: Combo.Endpoint.BanditAdapter` configuration change outlined previously,
  configuration of specific `http:` and `https:` values is done on a per-environment basis in
  Combo, so these changes will typically be in your `config/dev.exs`, `config/prod.exs` and
  similar files.
  """

  @doc """
  Returns the Bandit server process for the provided scheme within the given Combo Endpoint
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
  Returns the bound address and port of the Bandit server process for the provided
  scheme within the given Combo Endpoint
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
