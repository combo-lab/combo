defmodule Mix.Tasks.Combo.Routes do
  @shortdoc "Prints all routes for a given router"

  @moduledoc """
  #{@shortdoc}.

  ```console
  $ mix combo.routes ROUTER
  ```

  ## Examples

  Print all routes for the given router:

      $ mix combo.routes Demo.Web.Router

  If you find it annoying to specify the router every time, add an alias to
  `mix.exs`:

      defp aliases do
        [
          "combo.routes": "combo.routes Demo.Web.Router",
          # ...
        ]
      end

  """

  use Mix.Task
  alias Combo.Router

  @impl Mix.Task
  def run(args) do
    if "--no-compile" not in args do
      Mix.Task.run("compile")
    end

    Mix.Task.reenable("combo.routes")

    {_, args, _} = OptionParser.parse(args, switches: [])

    router_name =
      case args do
        [name] -> name
        _ -> nil
      end

    router_name
    |> router_module()
    |> Router.ConsoleFormatter.format()
    |> Mix.shell().info()
  end

  defp router_module(nil) do
    Mix.raise("""
    `mix combo.routes` requires an explicit router to be given, for example:

        $ mix combo.routes Demo.Web.Router
    """)
  end

  defp router_module(name) do
    module = Module.concat([name])

    if Code.ensure_loaded?(module) do
      module
    else
      Mix.raise("the provided router, #{inspect(module)}, does not exist")
    end
  end
end
