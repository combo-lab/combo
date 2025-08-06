defmodule Mix.Tasks.Combo.Routes do
  use Mix.Task
  alias Combo.Router.ConsoleFormatter

  @shortdoc "Prints all routes"

  @moduledoc """
  Prints all routes for a given router.
  Can also locate the controller function behind a specified url.

      $ mix combo.routes ROUTER [--info URL]

  An alias can be added to `mix.exs` to specify a router:

      defp aliases do
        [
          "combo.routes": "combo.routes DemoWeb.Router",
          # ...
        ]
      end

  ## Options

    * `--info` - locate the controller function definition called by the given url
    * `--method` - what HTTP method to use with the given url, only works when
      used with `--info` and defaults to `get`

  ## Examples

  Print all routes for the given router:

      $ mix combo.routes DemoWeb.Router

  Print information about the controller function called by a specified url:

      $ mix combo.routes --info http://0.0.0.0:4000/home
        Module: DemoWeb.PageController
        Function: :index
        /home/user/demo/demo_web/controllers/page_controller.ex:4

  Print information about the controller function called by a specified url and
  HTTP method:

      $ mix combo.routes --info http://0.0.0.0:4000/users --method post
        Module: DemoWeb.UserController
        Function: :create
        /home/user/demo/demo_web/controllers/user_controller.ex:24

  """

  @impl Mix.Task
  def run(args) do
    if "--no-compile" not in args do
      Mix.Task.run("compile")
    end

    Mix.Task.reenable("combo.routes")

    {opts, args, _} =
      OptionParser.parse(args, switches: [endpoint: :string, router: :string, info: :string])

    {router_mod, endpoint_mod} =
      case args do
        [passed_router] -> {router(passed_router), opts[:endpoint]}
        [] -> {router(opts[:router]), endpoint(opts[:endpoint])}
      end

    case Keyword.fetch(opts, :info) do
      {:ok, url} ->
        get_url_info(url, {router_mod, opts})

      :error ->
        router_mod
        |> ConsoleFormatter.format(endpoint_mod)
        |> Mix.shell().info()
    end
  end

  defp get_url_info(url, {router_mod, opts}) do
    %{path: path} = URI.parse(url)

    method = opts |> Keyword.get(:method, "get") |> String.upcase()
    meta = Combo.Router.route_info(router_mod, method, path, "")
    %{plug: plug, plug_opts: plug_opts} = meta

    {module, func_name} =
      case meta[:mfa] do
        {mod, fun, _} -> {mod, fun}
        _ -> {plug, plug_opts}
      end

    Mix.shell().info("Module: #{inspect(module)}")
    if func_name, do: Mix.shell().info("Function: #{inspect(func_name)}")

    file_path = get_file_path(module)

    if line = get_line_number(module, func_name) do
      Mix.shell().info("#{file_path}:#{line}")
    else
      Mix.shell().info("#{file_path}")
    end
  end

  defp endpoint(module) do
    loaded(Module.concat([module]))
  end

  defp router(nil) do
    Mix.raise("""
    mix combo.routes requires an explicit router to be given, for example:

        $ mix combo.routes DemoWeb.Router

    If you think that's tedious, consider to add an alias to mix.exs:

        defp aliases do
          [
            "combo.routes": "combo.routes DemoWeb.Router",
            # ...
          ]
        end

    """)
  end

  defp router(router_name) do
    arg_router = Module.concat([router_name])
    loaded(arg_router) || Mix.raise("the provided router, #{inspect(arg_router)}, does not exist")
  end

  defp loaded(module) do
    if Code.ensure_loaded?(module), do: module
  end

  defp get_file_path(module_name) do
    [compile_infos] = Keyword.get_values(module_name.module_info(), :compile)
    [source] = Keyword.get_values(compile_infos, :source)
    Path.relative_to_cwd(source)
  end

  defp get_line_number(_, nil), do: nil

  defp get_line_number(module, function_name) do
    {_, _, _, _, _, _, functions_list} = Code.fetch_docs(module)

    function_infos =
      functions_list
      |> Enum.find(fn {{type, name, _}, _, _, _, _} ->
        type == :function and name == function_name
      end)

    case function_infos do
      {_, anno, _, _, _} -> :erl_anno.line(anno)
      nil -> nil
    end
  end
end
