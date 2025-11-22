defmodule Combo.RouterBridge do
  @moduledoc """
  Provides client-side bridge for Combo's router.

  ## Usage

  Use `Combo.RouterBridge` in your router:

      defmodule MyApp.Web.Router do
        use Combo.Router
        use Combo.RouterBridge, otp_app: :my_app

        # ...
      end

  And, configure it in your `config.exs` like this:

      config :my_app, MyApp.Web.Router,
        bridge: [
          lang: :typescript,
          output_path: Path.expand("../assets/src/js/routes", __DIR__)
        ]
          

  # ======= more

  To regenerate routes when your router file changes during development, add
  `Combo.RouterBridge` to your application's supervisor tree.

  Once configured, `Combo.RouterBridge` will generate two files in the configured
  `output_path`:

    * `routes.js`: The JavaScript route helper implementation.
    * `routes.d.ts`: TypeScript type definitions for full type safety.

  """

  alias Combo.Router
  alias Combo.Router.Route

  defmacro __using__(opts) do
    quote do
      unquote(config(opts))

      @after_compile unquote(__MODULE__)
    end
  end

  defp config(opts) do
    quote do
      @otp_app unquote(opts)[:otp_app] ||
                 raise("#{unquote(__MODULE__)} expects :otp_app to be given")

      @combo_router_bridge Application.compile_env(@otp_app, [__MODULE__, :bridge], false)
    end
  end

  def __after_compile__(env, _bytecode) do
    router = env.module

    router
    |> fetch_routes!()
    |> generate_route_helpers()

    # |> IO.puts()
  end

  defp fetch_routes!(router) do
    routes = Router.routes(router)
    routes_with_exprs = Enum.map(routes, &{&1, Route.build_exprs(&1)})

    # Ignore any route without helper or with forwards.
    Enum.reject(routes_with_exprs, fn {route, _exprs} ->
      is_nil(route.helper) or route.kind == :forward
    end)
  end

  defp generate_route_helpers(routes_with_exprs) do
    groups =
      routes_with_exprs
      |> Enum.group_by(fn {route, _exprs} -> route.helper end)
      |> Enum.map(fn {helper, routes_with_exprs} ->
        routes_with_exprs =
          routes_with_exprs
          |> Enum.group_by(fn {route, exprs} -> {length(exprs.binding), route.plug_opts} end)
          |> Enum.sort()
          |> Enum.map(fn {{_, _}, [route_and_exprs | _]} -> route_and_exprs end)
          |> Enum.sort_by(fn {route, _exprs} -> route.line end)

        {helper, routes_with_exprs}
      end)

    groups
    |> Enum.map(&build_route_helper(&1))
    |> Enum.join("\n")

    # content = routes |> Jason.encode!()
    # path = Path.join(__DIR__, "./generated.js")
    # IO.puts(path)
    # File.write!(path, content)
  end

  defp build_route_helper({helper, routes_with_exprs}) do
    [
      build_comment(helper),
      build_overloads(routes_with_exprs),
      build_implementations(helper, routes_with_exprs)
    ]
    |> Enum.join("\n")
  end

  defp build_comment(helper) do
    """
    /* #{helper}_path */
    """
  end

  defp build_overloads(routes_with_exprs) do
    routes_with_exprs
    |> Enum.map(&build_overload(&1))
    |> Enum.join("")
  end

  defp build_overload({route, exprs}) do
    helper = route.helper
    action = route.plug_opts
    binding = exprs.binding

    args =
      [
        ~s|action: "#{inspect(action)}"|,
        Enum.map(binding, fn {name, _expr} -> ~s|#{name}: PathParam| end),
        ~s|params?: Params|
      ]
      |> List.flatten()
      |> Enum.join(", ")

    """
    export function #{helper}_path(#{args}): string
    """
  end

  defp build_implementations(helper, routes_with_exprs) do
    {switch_clauses, functions} =
      routes_with_exprs
      |> Enum.map(&build_implementation(&1))
      |> Enum.unzip()

    # IO.inspect(switch_clauses |> Enum.join("\n"))
    switch_clauses = switch_clauses |> Enum.join("\n") |> indent(4)

    # IO.inspect(switch_clauses)
    functions = Enum.join(functions, "\n")

    """
    export function #{helper}_path(action: string, ...args: any[]): string {
      switch (action) {
    #{switch_clauses}
        default:
          throw `unknown action ${action}`
      }
    }

    #{functions}
    """
  end

  defp indent(content, indentation) do
    content
    |> String.split("\n")
    |> Enum.map(fn line ->
      String.duplicate(" ", indentation) <> line
    end)
    |> Enum.join("\n")
    |> String.trim_trailing(" ")
  end

  defp build_implementation({route, exprs}) do
    helper = route.helper
    action = route.plug_opts
    binding = exprs.binding
    # IO.inspect(exprs)

    fun_name = "#{helper}_path_#{action}"

    args_type =
      [
        Enum.map(binding, fn _ -> "PathParam" end),
        "Params?"
      ]
      |> List.flatten()
      |> Enum.join(", ")

    args =
      [
        Enum.map(binding, fn {name, _expr} -> ~s|#{name}: PathParam| end),
        ~s|params?: Params|
      ]
      |> List.flatten()
      |> Enum.join(", ")

    path_template = build_path_template(exprs.path)

    switch_clause = """
    case "#{inspect(action)}":
      return #{fun_name}(...(args as [#{args_type}]))
    """

    function = """
    function #{fun_name}(#{args}) {
      return appendParams(#{path_template}, params)
    }
    """

    {switch_clause, function}
  end

  defp build_path_template(segments) when is_list(segments) do
    dynamic? =
      Enum.any?(segments, fn
        {_, _, _} -> true
        _ -> false
      end)

    inner =
      segments
      |> Enum.map(fn
        segment when is_binary(segment) -> segment
        {var, _, _} -> "${#{var}}"
      end)
      |> Enum.join("/")

    if dynamic?,
      do: ~s|`/#{inner}`|,
      else: ~s|"/#{inner}"|
  end

  defp build_path_template({var, _, _} = _segment) do
    "`/#{var}`"
  end
end
