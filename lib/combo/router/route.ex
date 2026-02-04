defmodule Combo.Router.Route do
  @moduledoc false

  alias Combo.Router.ModuleAttr

  @doc false
  def setup(module) do
    ModuleAttr.register(module, :routes, accumulate: true)
  end

  @doc """
  The `Combo.Router.Route` struct. It stores:

    * `:line` - the line the route was defined.
    * `:kind` - the kind of route as an atom, either `:match` or `:forward`.
    * `:verb` - the HTTP verb as an atom, such as `:get`, `:post` or `:*`.
    * `:path` - the normalized path as a string.
    * `:hosts` - the list of request hosts or host prefixes.
    * `:plug` - the plug module.
    * `:plug_opts` - the plug options.
    * `:helper` - the name of the helper as a string, or `nil`.
    * `:pipe_through` - the pipeline names as a list of atoms.
    * `:private` - the private route info as a map.
    * `:assigns` - the route info as a map.
    * `:metadata` - the metadata as a map, used on telemetry events and route info.

  """
  defstruct [
    :line,
    :kind,
    :verb,
    :path,
    :hosts,
    :plug,
    :plug_opts,
    :helper,
    :pipe_through,
    :private,
    :assigns,
    :metadata
  ]

  @type t :: %__MODULE__{}

  @doc "Used as a plug on forwarding."
  def init(opts), do: opts

  @doc "Used as a plug on forwarding."
  def call(%{path_info: path, script_name: script} = conn, {fwd_segments, plug, opts}) do
    new_path = path -- fwd_segments
    {base, ^new_path} = Enum.split(path, length(path) - length(new_path))
    conn = %{conn | path_info: new_path, script_name: script ++ base}
    conn = plug.call(conn, plug.init(opts))
    %{conn | path_info: path, script_name: script}
  end

  @doc """
  Build a `Combo.Router.Route` struct.
  """
  @spec build(
          line :: non_neg_integer(),
          kind :: :match | :forward,
          verb :: atom(),
          path :: String.t(),
          hosts :: [String.t()],
          plug :: atom(),
          plug_opts :: atom(),
          helper :: binary() | nil,
          pipe_through :: [atom()],
          private :: map(),
          assigns :: map(),
          metadata :: map()
        ) :: t()
  def build(
        line,
        kind,
        verb,
        path,
        hosts,
        plug,
        plug_opts,
        helper,
        pipe_through,
        private,
        assigns,
        metadata
      )
      when kind in [:match, :forward] and
             is_atom(verb) and
             is_binary(path) and
             is_list(hosts) and
             is_atom(plug) and
             (is_binary(helper) or is_nil(helper)) and
             is_list(pipe_through) and
             is_map(private) and
             is_map(assigns) and
             is_map(metadata) do
    %__MODULE__{
      line: line,
      kind: kind,
      verb: verb,
      path: path,
      hosts: hosts,
      plug: plug,
      plug_opts: plug_opts,
      helper: helper,
      pipe_through: pipe_through,
      private: private,
      assigns: assigns,
      metadata: metadata
    }
  end

  @doc """
  Builds the compiled expressions of route.
  """
  def build_exprs(route) do
    {path, binding} = build_path_and_binding(route)

    %{
      verb: build_verb(route.verb),
      path: path,
      binding: binding,
      dispatch: build_dispatch(route),
      hosts: build_hosts(route.hosts),
      path_params: build_path_params(binding),
      prepare: build_prepare(route)
    }
  end

  defp build_path_and_binding(%__MODULE__{path: path} = route) do
    {_params, segments} =
      case route.kind do
        :match -> Plug.Router.Utils.build_path_match(path)
        :forward -> Plug.Router.Utils.build_path_match(path <> "/*_forward_path_info")
      end

    rewrite_segments(segments)
  end

  defp rewrite_segments(segments) do
    {segments, binding} =
      Macro.prewalk(segments, [], fn
        {name, _meta, nil}, binding when is_atom(name) and name != :_forward_path_info ->
          var = Macro.var(name, __MODULE__)
          {var, [{Atom.to_string(name), var} | binding]}

        other, binding ->
          {other, binding}
      end)

    {segments, Enum.reverse(binding)}
  end

  defp build_dispatch(%__MODULE__{
         kind: :match,
         plug: plug,
         plug_opts: plug_opts
       }) do
    quote do
      {unquote(plug), unquote(Macro.escape(plug_opts))}
    end
  end

  defp build_dispatch(%__MODULE__{
         kind: :forward,
         plug: plug,
         plug_opts: plug_opts,
         metadata: metadata
       }) do
    quote do
      {
        Combo.Router.Route,
        {unquote(metadata.forward), unquote(plug), unquote(Macro.escape(plug_opts))}
      }
    end
  end

  def build_hosts([]), do: [Plug.Router.Utils.build_host_match(nil)]

  def build_hosts([_ | _] = hosts) do
    for host <- hosts, do: Plug.Router.Utils.build_host_match(host)
  end

  defp build_verb(:*), do: Macro.var(:_verb, nil)
  defp build_verb(verb), do: verb |> to_string() |> String.upcase()

  defp build_path_params(binding), do: {:%{}, [], binding}

  defp build_prepare(route) do
    {match_params, merge_params} = build_params()
    {match_private, merge_private} = build_prepare_expr(:private, route.private)
    {match_assigns, merge_assigns} = build_prepare_expr(:assigns, route.assigns)

    match_all = match_params ++ match_private ++ match_assigns
    merge_all = merge_params ++ merge_private ++ merge_assigns

    quote do
      %{unquote_splicing(match_all)} = var!(conn, :conn)
      %{var!(conn, :conn) | unquote_splicing(merge_all)}
    end
  end

  defp build_params() do
    params = Macro.var(:params, :conn)
    path_params = Macro.var(:path_params, :conn)

    merge_params =
      quote(do: Combo.Router.Route.merge_params(unquote(params), unquote(path_params)))

    {
      [{:params, params}],
      [{:params, merge_params}, {:path_params, path_params}]
    }
  end

  defp build_prepare_expr(_key, data) when data == %{}, do: {[], []}

  defp build_prepare_expr(key, data) do
    var = Macro.var(key, :conn)
    merge = quote(do: Map.merge(unquote(var), unquote(Macro.escape(data))))
    {[{key, var}], [{key, merge}]}
  end

  @doc """
  Merges params from router.
  """
  def merge_params(%Plug.Conn.Unfetched{}, path_params), do: path_params
  def merge_params(params, path_params), do: Map.merge(params, path_params)
end
