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
          output_dir: Path.expand("../assets/src/js/routes", __DIR__)
        ]

  ## Languages

  > At present, only TypeScript bridge code generation is supported.
  > Want to use JavaScript? Feel free to contribute.

  Available value of `:lang` option:

    * `:typescript`

  """

  alias Combo.Router
  alias Combo.Router.Route
  alias __MODULE__.TypeScript

  defmacro __using__(opts) do
    quote do
      # step 1: get the config
      unquote(config(opts))

      # step 2: define the bridge module, and the bridge module will generate requried files
      @after_compile {unquote(__MODULE__), :__define_bridge_module__}
    end
  end

  defp config(opts) do
    quote do
      @otp_app unquote(opts)[:otp_app] ||
                 raise("#{unquote(__MODULE__)} expects :otp_app to be given")

      @combo_router_bridge Application.compile_env(@otp_app, [__MODULE__, :bridge], false)
    end
  end

  def __define_bridge_module__(env, _bytecode) do
    router = env.module
    config = Module.get_attribute(router, :combo_router_bridge)

    code =
      quote do
        @combo_router unquote(env.module)
        @combo_router_bridge_config unquote(config)

        @after_compile __MODULE__

        def router, do: @combo_router

        def config, do: @combo_router_bridge_config

        def generate do
          routes_with_exprs = unquote(__MODULE__).build_routes_with_exprs!(router())
          unquote(__MODULE__).generate(routes_with_exprs, config())
        end

        def __after_compile__(_env, _bytecode), do: generate()
      end

    name = Module.concat(router, Bridge)
    Module.create(name, code, line: env.line, file: env.file)
    name
  end

  @doc false
  def build_routes_with_exprs!(router) do
    routes = Router.routes(router)

    routes
    # Ignore any route without helper or with forwards.
    |> Enum.reject(fn route ->
      is_nil(route.helper) or route.kind == :forward
    end)
    |> Enum.map(fn route ->
      exprs = Route.build_exprs(route)
      {route, exprs}
    end)
  end

  @supported_langs %{
    typescript: TypeScript
  }

  @doc false
  def generate(_routes_with_exprs, false) do
    :skip
  end

  def generate(routes_with_exprs, config) do
    lang = Keyword.fetch!(config, :lang)
    output_dir = Keyword.fetch!(config, :output_dir)

    module = Map.fetch!(@supported_langs, lang)

    for {path, content} <- module.build(routes_with_exprs) do
      abs_path = Path.join(output_dir, path)
      write_content!(abs_path, content)
    end

    :ok
  end

  defp write_content!(abs_path, content) do
    abs_dir = Path.dirname(abs_path)
    File.mkdir_p!(abs_dir)
    File.write!(abs_path, content)
  end
end
