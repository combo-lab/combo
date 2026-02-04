defmodule Combo.Router.Scope do
  @moduledoc false

  alias Combo.Router.ModuleAttr

  defstruct path: [],
            alias: [],
            as: [],
            pipes: [],
            hosts: [],
            private: %{},
            assigns: %{},
            log: :debug

  @doc false
  def init(module) do
    ModuleAttr.put(module, :scopes, [%__MODULE__{}])
  end

  @doc """
  Defines a scope.

  It's for grouping routes.

  ## Examples

      scope path: "/api/v1", alias: API.V1 do
        get "/pages/:id", PageController, :show
      end

  The generated route above will match on the path `"/api/v1/pages/:id"` and
  will dispatch to `:show` action in `API.V1.PageController`. A named helper
  `api_v1_page_path` will also be generated.

  ## Options

    * `:path` - the path scope as a string.
    * `:alias` - the controller scope as an alias. When set to `false`, it
      resets all nested `:alias` options.
    * `:as` - the named helper scope as a string or an atom. When set to
      `false`, it resets all nested `:as` options.
    * `:host` - the host scope or prefix host scope as a string or a list
      of strings, such as `"foo.bar.com"`, `"foo."`.
    * `:private` - the private data as a map to merge into the connection when
      a route matches.
    * `:assigns` - the data as a map to merge into the connection when a route
      matches.
    * `:log` - the level to log the route dispatching under, may be set to
      `false`.
      Defaults to `:debug`. Route dispatching contains information about how
      the route is handled (which controller action is called, what parameters
      are available and which pipelines are used) and is separate from the plug
      level logging. To alter the plug log level, please see
      https://hexdocs.pm/combo/Combo.Logger.html#module-dynamic-log-level.

  ## Shortcuts

  A scope can also be defined with shortcuts.

      # specify path and alias
      scope "/api/v1", API.V1 do
        get "/pages/:id", PageController, :show
      end

      # specify path, alias and options
      scope "/api/v1", API.V1, host: "api." do
        get "/pages/:id", PageController, :show
      end

      # specify path only
      scope "/api/v1" do
        get "/pages/:id", API.V1.PageController, :show
      end

      # specify path and options
      scope "/api/v1", host: "api." do
        get "/pages/:id", API.V1.PageController, :show
      end

      # specify alias only
      scope API.V1 do
        get "/pages/:id", PageController, :show
      end

      # specify alias and options
      scope API.V1, host: "api." do
        get "/pages/:id", PageController, :show
      end

  """
  defmacro scope(arg, [do: context] = _do_block) do
    do_scope([arg], context)
  end

  @doc """
  See the shortcuts section of `#{inspect(__MODULE__)}.scope/2`.
  """
  defmacro scope(arg1, arg2, [do: context] = _do_block) do
    do_scope([arg1, arg2], context)
  end

  @doc """
  See the shortcuts section of `#{inspect(__MODULE__)}.scope/2`.
  """
  defmacro scope(arg1, arg2, arg3, [do: context] = _do_block) do
    do_scope([arg1, arg2, arg3], context)
  end

  defp do_scope(args, context) do
    scope =
      quote do
        unquote(__MODULE__).build_scope(
          __MODULE__,
          unquote(__MODULE__).normalize_scope_opts(unquote(args))
        )
      end

    quote do
      unquote(__MODULE__).push_scope(__MODULE__, unquote(scope))

      try do
        unquote(context)
      after
        unquote(__MODULE__).pop_scope(__MODULE__)
      end
    end
  end

  @doc false
  def normalize_scope_opts([path]) when is_binary(path) do
    [path: path]
  end

  def normalize_scope_opts([alias]) when is_atom(alias) do
    [alias: alias]
  end

  def normalize_scope_opts([opts]) when is_list(opts) do
    opts
  end

  def normalize_scope_opts([path, alias]) when is_binary(path) and is_atom(alias) do
    [path: path, alias: alias]
  end

  def normalize_scope_opts([path, opts]) when is_binary(path) and is_list(opts) do
    Keyword.put(opts, :path, path)
  end

  def normalize_scope_opts([alias, opts]) when is_atom(alias) and is_list(opts) do
    Keyword.put(opts, :alias, alias)
  end

  def normalize_scope_opts([path, alias, opts])
      when is_binary(path) and is_atom(alias) and is_list(opts) do
    opts
    |> Keyword.put(:path, path)
    |> Keyword.put(:alias, alias)
  end

  @doc false
  def build_scope(module, opts) do
    top = get_top_scope(module)

    path =
      if path = Keyword.get(opts, :path) do
        path |> validate_path!() |> String.split("/", trim: true)
      else
        []
      end

    path = top.path ++ path
    alias = append_if_not_false(top, opts, :alias, &Atom.to_string(&1))
    as = append_if_not_false(top, opts, :as, & &1)

    hosts =
      case Keyword.fetch(opts, :host) do
        {:ok, val} -> validate_hosts!(val)
        :error -> top.hosts
      end

    pipes = top.pipes
    private = Map.merge(top.private, Keyword.get(opts, :private, %{}))
    assigns = Map.merge(top.assigns, Keyword.get(opts, :assigns, %{}))
    log = Keyword.get(opts, :log, top.log)

    %__MODULE__{
      path: path,
      alias: alias,
      as: as,
      hosts: hosts,
      pipes: pipes,
      private: private,
      assigns: assigns,
      log: log
    }
  end

  def push_scope(module, scope) do
    ModuleAttr.update(module, :scopes, fn scopes -> [scope | scopes] end)
  end

  def pop_scope(module) do
    ModuleAttr.update(module, :scopes, fn [_top | scopes] -> scopes end)
  end

  @doc """
  Defines a list of plugs (and pipelines) to send the connection through.

  Plugs are specified using the atom name of any imported 2-arity function
  which takes a `Plug.Conn` struct and options and returns a `Plug.Conn` struct.
  For example, `:require_authenticated_user`.

  Pipelines are defined in the router, see `pipeline/2` for more information.

  ## Examples

      pipe_through [:require_authenticated_user, :my_browser_pipeline]

  ## Multiple invocations

  `pipe_through/1` can be invoked multiple times within the same scope. Each
  invocation appends new plugs and pipelines to run, which are applied to all
  routes **after** the `pipe_through/1` invocation. For example:

      scope "/" do
        pipe_through [:browser]
        get "/", HomeController, :index

        pipe_through [:require_authenticated_user]
        get "/settings", UserController, :edit
      end

  In the example above, `/` pipes through `browser` only, while `/settings` pipes
  through both `browser` and `require_authenticated_user`. Therefore, to avoid
  confusion, we recommend a single `pipe_through` at the top of each scope:

      scope "/" do
        pipe_through [:browser]
        get "/", HomeController, :index
      end

      scope "/" do
        pipe_through [:browser, :require_authenticated_user]
        get "/settings", UserController, :edit
      end

  """
  defmacro pipe_through(pipes) do
    pipes =
      if Combo.plug_init_mode() == :runtime and Macro.quoted_literal?(pipes) do
        Macro.prewalk(pipes, &expand_alias(&1, __CALLER__))
      else
        pipes
      end

    quote do
      if pipeline = ModuleAttr.get(__MODULE__, :pipeline_plugs) do
        raise "cannot pipe_through inside a pipeline"
      else
        unquote(__MODULE__).do_pipe_through(__MODULE__, unquote(pipes))
      end
    end
  end

  @doc false
  def do_pipe_through(module, new_pipes) do
    %{pipes: pipes} = get_top_scope(module)
    new_pipes = List.wrap(new_pipes)

    if pipe = Enum.find(new_pipes, &(&1 in pipes)) do
      raise ArgumentError,
            "duplicate pipe_through for #{inspect(pipe)}. " <>
              "A plug may only be used once inside a scoped pipe_through"
    end

    ModuleAttr.update(module, :scopes, fn [top | rest] ->
      [%{top | pipes: pipes ++ new_pipes} | rest]
    end)
  end

  @doc """
  Builds a route based on the top of the stack.
  """
  def route(line, module, kind, verb, path, plug, plug_opts, opts) do
    if not is_atom(plug) do
      raise ArgumentError,
            "routes expect a module plug as second argument, got: #{inspect(plug)}"
    end

    top = get_top_scope(module)
    path = validate_path!(path)

    alias? = Keyword.get(opts, :alias, true)
    as = Keyword.get_lazy(opts, :as, fn -> Combo.Naming.resource_name(plug, "Controller") end)
    private = Keyword.get(opts, :private, %{})
    assigns = Keyword.get(opts, :assigns, %{})
    log = Keyword.get(opts, :log, top.log)

    if to_string(as) == "static" do
      raise ArgumentError,
            "`static` is a reserved route prefix generated from #{inspect(plug)} or `:as` option"
    end

    {path, plug, as, private, assigns} = join(top, path, plug, alias?, as, private, assigns)

    metadata =
      opts
      |> Keyword.get(:metadata, %{})
      |> Map.put(:log, log)

    metadata =
      if kind == :forward do
        Map.put(metadata, :forward, validate_forward_path!(path))
      else
        metadata
      end

    Combo.Router.Route.build(
      line,
      kind,
      verb,
      path,
      top.hosts,
      plug,
      plug_opts,
      as,
      top.pipes,
      private,
      assigns,
      metadata
    )
  end

  defp validate_forward_path!(path) do
    case Plug.Router.Utils.build_path_match(path) do
      {[], path_segments} ->
        path_segments

      _ ->
        raise ArgumentError,
              "dynamic segment \"#{path}\" not allowed when forwarding. Use a static path instead"
    end
  end

  @doc """
  Validates a path is a string and contains a leading prefix.
  """
  def validate_path!("/" <> _ = path), do: path

  def validate_path!(path) when is_binary(path) do
    IO.warn("router paths should begin with a forward slash, got: #{inspect(path)}")
    "/" <> path
  end

  def validate_path!(path) do
    raise ArgumentError, "router paths must be strings, got: #{inspect(path)}"
  end

  defp validate_hosts!(nil), do: []
  defp validate_hosts!(host) when is_binary(host), do: [host]

  defp validate_hosts!(hosts) when is_list(hosts) do
    for host <- hosts do
      if not is_binary(host), do: raise_invalid_host!(host)
      host
    end
  end

  defp validate_hosts!(invalid), do: raise_invalid_host!(invalid)

  defp raise_invalid_host!(host) do
    raise ArgumentError,
          "expected router scope :host to be compile-time string or list of strings, got: #{inspect(host)}"
  end

  defp append_if_not_false(top, opts, key, fun) do
    case opts[key] do
      false -> []
      nil -> Map.fetch!(top, key)
      other -> Map.fetch!(top, key) ++ [fun.(other)]
    end
  end

  @doc """
  Expands the alias in the current router scope.
  """
  def expand_alias(module, alias) do
    join_alias(get_top_scope(module), alias)
  end

  @doc """
  Returns the full path in the current router scope.
  """
  def full_path(module, path) do
    split_path = String.split(path, "/", trim: true)
    prefix = get_top_scope(module).path

    cond do
      prefix == [] -> path
      split_path == [] -> "/" <> Enum.join(prefix, "/")
      true -> "/" <> Path.join(get_top_scope(module).path ++ split_path)
    end
  end

  defp join(top, path, plug, alias?, as, private, assigns) do
    path = join_path(top, path)
    plug = if alias?, do: join_alias(top, plug), else: plug
    as = join_as(top, as)
    private = Map.merge(top.private, private)
    assigns = Map.merge(top.assigns, assigns)
    {path, plug, as, private, assigns}
  end

  defp join_path(top, path) do
    "/" <> Enum.join(top.path ++ String.split(path, "/", trim: true), "/")
  end

  defp join_alias(top, plug) when is_atom(plug) do
    case Atom.to_string(plug) do
      <<head, _::binary>> when head in ?a..?z -> plug
      plug -> Module.concat(top.alias ++ [plug])
    end
  end

  defp join_as(_top, nil), do: nil
  defp join_as(top, as) when is_atom(as) or is_binary(as), do: Enum.join(top.as ++ [as], "_")

  defp get_top_scope(module) do
    module
    |> ModuleAttr.get(:scopes)
    |> hd()
  end
end
