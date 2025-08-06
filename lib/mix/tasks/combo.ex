defmodule Mix.Tasks.Combo do
  use Mix.Task

  @shortdoc "Prints Combo help information"

  @moduledoc """
  Prints Combo tasks and their information.

      $ mix combo

  To print the Combo version, pass `-v` or `--version`, for example:

      $ mix combo --version

  """

  @version Mix.Project.config()[:version]

  @impl true
  @doc false
  def run([version]) when version in ~w(-v --version) do
    Mix.shell().info("Combo v#{@version}")
  end

  def run(args) do
    case args do
      [] -> general()
      _ -> Mix.raise "Invalid arguments, expected: mix combo"
    end
  end

  defp general() do
    Application.ensure_all_started(:phoenix)
    Mix.shell().info "Combo v#{Application.spec(:phoenix, :vsn)}"
    Mix.shell().info "Peace of mind from prototype to production"
    Mix.shell().info "\n"
    Mix.shell().info "## Options\n"
    Mix.shell().info "-v, --version        # Prints Combo version\n"
    Mix.shell().info "## Sub commands\n"
    Mix.Tasks.Help.run(["--search", "combo."])
  end
end
