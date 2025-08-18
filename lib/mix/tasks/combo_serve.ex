defmodule Mix.Tasks.Combo.Serve do
  @shortdoc "Serves all endpoints"

  @moduledoc """
  #{@shortdoc}.

  Note: To start the endpoint without using this mix task, you must set
  `server: true` in your endpoint configuration.

  ## Options

  This task accepts the same command-line options as `mix run`.

  For example, to run `combo.serve` without recompiling:

  ```console
  $ mix combo.serve --no-compile
  ```

  If the IEx is running, the `--no-halt` flag is automatically added.

  Note that the `--no-deps-check` flag cannot be used this way, because Mix
  needs to check dependencies to find `combo.serve`. To run `combo.serve`
  without checking dependencies, you can run:

  ```console
  $ mix do deps.loadpaths --no-deps-check, combo.serve
  ```
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Application.put_env(:combo, :serve_endpoints, true, persistent: true)
    Mix.Tasks.Run.run(run_args() ++ args)
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) and IEx.started?()
  end

  defp run_args do
    if iex_running?(), do: [], else: ["--no-halt"]
  end
end
