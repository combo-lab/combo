defmodule Combo.RouterBridge.TypeScript do
  @moduledoc false

  def build(routes_with_exprs) do
    [
      build_types(),
      build_utils(),
      build_route_helpers(routes_with_exprs)
    ]
  end

  defp build_route_helpers(routes_with_exprs) do
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
      |> Enum.sort_by(fn {_helper, [{route, _exprs} | _]} ->
        route.line
      end)

    content =
      [
        build_imports(),
        Enum.map(groups, &build_route_helper(&1))
      ]
      |> List.flatten()
      |> Enum.join("\n")

    {"index.ts", content}
  end

  defp build_types do
    content = """
    export type PathParam = string | number | boolean

    export type ParamKey = string

    export type ParamValue = string | number | boolean | null | undefined

    export type Params = {
      [key: ParamKey]: ParamValue | ParamValue[]
    }
    """

    {"types.d.ts", content}
  end

  defp build_utils do
    content = """
    import { ParamKey, Params } from "./types"

    export function appendParams(
      url_or_path: string,
      reserved_param_keys: ParamKey[],
      params?: Params,
    ): string {
      return url_or_path
    }
    """

    {"utils.ts", content}
  end

  defp build_imports do
    """
    import { PathParam, Params } from "./types"
    import { appendParams } from "./utils"
    """
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

    path_template = build_path_template(exprs.path_info_match)

    reserved_param_keys =
      binding
      |> Enum.map_join(", ", fn {name, _} -> ~s|"#{name}"| end)
      |> then(&"[#{&1}]")

    switch_clause = """
    case "#{inspect(action)}":
      return #{fun_name}(...(args as [#{args_type}]))
    """

    function = """
    function #{fun_name}(#{args}) {
      return appendParams(#{path_template}, #{reserved_param_keys}, params)
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
        segment when is_binary(segment) ->
          segment

        {var, _, _} ->
          ~s|${#{var}}|
      end)
      |> Enum.join("/")

    if dynamic?,
      do: ~s|`/#{inner}`|,
      else: ~s|"/#{inner}"|
  end

  defp build_path_template({var, _, _} = _segment) do
  end

  defp expand_segment({:|, _, [h, t]}) do
    [
      expand_segment(h),
      expand_segment(t)
    ]
  end

  {:|, [], ["file", {:file, [], Combo.Router.Route}]}

  defp expand_segment({:<>, _, [h, t]}) do
    ~s|#{h}${#{encode_segment(t)}|
  end

  defp expand_segment(segment) when is_binary(segment) do
    segment
  end

  defp expand_segment({var, _, _} = _segment) do
    ~s|${#{encode_segment(var)}}|
  end

  defp encode_segment(data) do
    data

    # data
    # |> Combo.URLParam.to_param()
    # |> URI.encode(&URI.char_unreserved?/1)
  end
end
