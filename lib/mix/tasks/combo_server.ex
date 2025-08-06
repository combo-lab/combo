defmodule Mix.Tasks.Combo.Server do
  use Mix.Task

  @shortdoc "Starts applications and their servers"

  @moduledoc """
  Starts the application by configuring all endpoints servers to run.

  Note: to start the endpoint without using this mix task you must set
  `server: true` in your `Combo.Endpoint` configuration.

  ## Command line options

    * `--open` - open browser window for each started endpoint

  Furthermore, this task accepts the same command-line options as
  `mix run`.

  For example, to run `combo.server` without recompiling:

      $ mix combo.server --no-compile

  The `--no-halt` flag is automatically added.

  Note that the `--no-deps-check` flag cannot be used this way,
  because Mix needs to check dependencies to find `combo.server`.

  To run `combo.server` without checking dependencies, you can run:

      $ mix do deps.loadpaths --no-deps-check, combo.server

  """

  @impl true
  def run(args) do
    Application.put_env(:combo, :serve_endpoints, true, persistent: true)
    Mix.Tasks.Run.run(run_args() ++ open_args(args))
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) and IEx.started?()
  end

  defp open_args(args) do
    if "--open" in args do
      Application.put_env(:combo, :browser_open, true)
      args -- ["--open"]
    else
      args
    end
  end

  defp run_args do
    if iex_running?(), do: [], else: ["--no-halt"]
  end
end
