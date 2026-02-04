defmodule Combo.Router.Pipeline do
  @moduledoc false

  alias Combo.Router.ModuleAttr
  alias Combo.Router.Util

  def init(module) do
    ModuleAttr.put(module, :pipelines, MapSet.new())
    ModuleAttr.put(module, :pipeline_plugs, nil)
  end

  @doc """
  Defines a pipeline.

  Pipelines are defined at the router root and can be used from any scope.

  ## Examples

      pipeline :api do
        plug :token_authentication
        plug :dispatch
      end

  A scope may then use this pipeline as:

      scope "/" do
        pipe_through :api
      end

  Every time `pipe_through/1` is called, the new pipelines are appended to the
  ones previously given.
  """
  defmacro pipeline(name, do: block) do
    with true <- is_atom(name),
         imports = __CALLER__.macros ++ __CALLER__.functions,
         {mod, _} <- Enum.find(imports, fn {_, imports} -> {name, 2} in imports end) do
      raise ArgumentError,
            "cannot define pipeline named #{inspect(name)} " <>
              "because there is an import from #{inspect(mod)} with the same name"
    end

    block =
      quote do
        name = unquote(name)
        ModuleAttr.put(__MODULE__, :pipeline_plugs, [])
        unquote(block)
      end

    compiler =
      quote unquote: false do
        ModuleAttr.put(__MODULE__, :pipelines, &MapSet.put(&1, name))

        {conn, body} =
          Plug.Builder.compile(__ENV__, ModuleAttr.get(__MODULE__, :pipeline_plugs),
            init_mode: Combo.plug_init_mode()
          )

        def unquote(name)(unquote(conn), _) do
          try do
            unquote(body)
          rescue
            e in Plug.Conn.WrapperError ->
              Plug.Conn.WrapperError.reraise(e)
          catch
            :error, reason ->
              Plug.Conn.WrapperError.reraise(unquote(conn), :error, reason, __STACKTRACE__)
          end
        end

        ModuleAttr.put(__MODULE__, :pipeline_plugs, nil)
      end

    quote do
      try do
        unquote(block)
        unquote(compiler)
      after
        :ok
      end
    end
  end

  @doc """
  Defines a plug inside a pipeline.

  See `pipeline/2` for more information.
  """
  defmacro plug(plug, opts \\ []) do
    {plug, opts} = Util.expand_plug_and_opts(plug, opts, __CALLER__)

    quote do
      if plugs = ModuleAttr.get(__MODULE__, :pipeline_plugs) do
        ModuleAttr.put(__MODULE__, :pipeline_plugs, [{unquote(plug), unquote(opts), true} | plugs])
      else
        raise "cannot define plug at the router level, plug must be defined inside a pipeline"
      end
    end
  end
end
