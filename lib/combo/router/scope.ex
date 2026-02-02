defmodule Combo.Router.Scope do
  @moduledoc false

  alias Combo.Router.Scope

  @stack :combo_router_scope_stack
  @pipes :combo_router_pipeline_scopes

  defstruct path: [],
            alias: [],
            as: [],
            pipes: [],
            hosts: [],
            private: %{},
            assigns: %{},
            log: :debug

  @doc """
  Initializes the scope.
  """
  def init(module) do
    Module.put_attribute(module, @stack, [%Scope{}])
    Module.put_attribute(module, @pipes, MapSet.new())
  end

  @doc """
  Builds a route based on the top of the stack.
  """
  def route(line, module, kind, verb, path, plug, plug_opts, opts) do
    if not is_atom(plug) do
      raise ArgumentError,
            "routes expect a module plug as second argument, got: #{inspect(plug)}"
    end

    top = get_stack_top(module)
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

  @doc """
  Defines the given pipeline.
  """
  def pipeline(module, pipe) when is_atom(pipe) do
    update_pipes(module, &MapSet.put(&1, pipe))
  end

  @doc """
  Appends the given pipes to the current scope pipe through.
  """
  def pipe_through(module, new_pipes) do
    %{pipes: pipes} = get_stack_top(module)
    new_pipes = List.wrap(new_pipes)

    if pipe = Enum.find(new_pipes, &(&1 in pipes)) do
      raise ArgumentError,
            "duplicate pipe_through for #{inspect(pipe)}. " <>
              "A plug may only be used once inside a scoped pipe_through"
    end

    update_stack(module, fn [top | rest] ->
      [%{top | pipes: pipes ++ new_pipes} | rest]
    end)
  end

  @doc """
  Pushes a scope into the module stack.
  """
  def push(module, opts) when is_list(opts) do
    top = get_stack_top(module)

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

    new_top = %Scope{
      path: path,
      alias: alias,
      as: as,
      hosts: hosts,
      pipes: pipes,
      private: private,
      assigns: assigns,
      log: log
    }

    update_stack(module, fn stack -> [new_top | stack] end)
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
  Pops a scope from the module stack.
  """
  def pop(module) do
    update_stack(module, fn [_top | rest] -> rest end)
  end

  @doc """
  Expands the alias in the current router scope.
  """
  def expand_alias(module, alias) do
    join_alias(get_stack_top(module), alias)
  end

  @doc """
  Returns the full path in the current router scope.
  """
  def full_path(module, path) do
    split_path = String.split(path, "/", trim: true)
    prefix = get_stack_top(module).path

    cond do
      prefix == [] -> path
      split_path == [] -> "/" <> Enum.join(prefix, "/")
      true -> "/" <> Path.join(get_stack_top(module).path ++ split_path)
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

  defp get_stack_top(module) do
    module
    |> get_attribute(@stack)
    |> hd()
  end

  defp update_stack(module, fun) do
    update_attribute(module, @stack, fun)
  end

  defp update_pipes(module, fun) do
    update_attribute(module, @pipes, fun)
  end

  defp get_attribute(module, attr) do
    Module.get_attribute(module, attr) ||
      raise "#{inspect(__MODULE__)} was not initialized"
  end

  defp update_attribute(module, attr, fun) do
    Module.put_attribute(module, attr, fun.(get_attribute(module, attr)))
  end
end
