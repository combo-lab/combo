defmodule Combo.Routing.Pipeline do
  @moduledoc false

  alias Combo.Utils.ModuleAttribute

  @doc false
  def setup(module) do
    ModuleAttribute.put(module, :combo_routing_pipelines, MapSet.new())
    ModuleAttribute.put(module, :combo_routing_pipeline_plugs, nil)
  end

  @doc false
  def add_pipeline(name, block) do
    pre =
      quote do
        name = unquote(name)
        ModuleAttribute.put(__MODULE__, :combo_routing_pipelines, &MapSet.put(&1, name))
        ModuleAttribute.put(__MODULE__, :combo_routing_pipeline_plugs, [])
      end

    compiled =
      quote unquote: false do
        {conn, body} =
          with plugs = ModuleAttribute.get(__MODULE__, :combo_routing_pipeline_plugs) do
            Plug.Builder.compile(__ENV__, plugs, init_mode: Combo.plug_init_mode())
          end

        def unquote(name)(unquote(conn), _opts) do
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
      end

    post =
      quote do
        ModuleAttribute.put(__MODULE__, :combo_routing_pipeline_plugs, nil)
      end

    quote do
      try do
        unquote(pre)
        unquote(block)
        unquote(compiled)
        unquote(post)
      after
        :ok
      end
    end
  end

  @doc false
  def add_plug(plug, opts) do
    quote do
      if plugs = ModuleAttribute.get(__MODULE__, :combo_routing_pipeline_plugs) do
        ModuleAttribute.put(__MODULE__, :combo_routing_pipeline_plugs, [
          {unquote(plug), unquote(opts), true} | plugs
        ])
      else
        raise "expected plug to be defined inside a pipeline"
      end
    end
  end
end
