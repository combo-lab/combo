defmodule Mix.Tasks.Combo do
  @shortdoc "Prints Combo tasks and their information"

  @moduledoc """
  #{@shortdoc}.

  ```console
  $ mix combo
  ```

  ## Options

    * `-v, --version` - prints the version only.

  """

  use Mix.Task

  @version Mix.Project.config()[:version]
  @description Mix.Project.config()[:description]

  @impl Mix.Task
  def run([version]) when version in ~w(-v --version) do
    Mix.shell().info("Combo v#{@version}")
  end

  def run(args) do
    case args do
      [] -> info()
      _ -> Mix.raise("Invalid arguments, expected: mix combo")
    end
  end

  defp info() do
    Application.ensure_all_started(:combo)
    Mix.shell().info("Combo v#{Application.spec(:combo, :vsn)}")
    Mix.shell().info(@description)
    Mix.shell().info("")
    Mix.shell().info("## Options\n")
    Mix.shell().info("-v, --version        # Prints Combo version\n")
    Mix.shell().info("## Sub commands\n")
    Mix.Tasks.Help.run(["--search", "combo."])
  end
end
