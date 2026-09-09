defmodule Combo.Endpoint.Compiler do
  @moduledoc false

  # Internal protocol for adding capabilities to an endpoint during compilation.
  # Callback results are quoted code to be inserted into the endpoint module.
  # Missing callbacks are treated as empty stages by the endpoint.

  @doc """
  Returns code that prepares the compiler's compile-time state.

  This stage runs before installation and user declarations. It can register
  module attributes used to collect compiler declarations.
  """
  @callback setup() :: Macro.t()

  @doc """
  Returns code that installs the compiler's capabilities in the endpoint.

  This stage runs after setup and initialization of the endpoint's Plug.Builder,
  but before the user module body. It can insert `use`, `import`, and `plug`
  declarations.
  """
  @callback install() :: Macro.t()

  @doc """
  Returns code generated from the endpoint's completed declarations.

  This callback receives the endpoint module while it is still being compiled,
  after the user module body has been expanded. It can read collected module
  attributes and generate functions that depend on them.
  """
  @callback before_compile(endpoint :: module()) :: Macro.t()

  @optional_callbacks setup: 0, install: 0, before_compile: 1

  @doc false
  def setup(compilers),
    do: compile_stage(compilers, :setup, [])

  @doc false
  def install(compilers),
    do: compile_stage(compilers, :install, [])

  @doc false
  def before_compile(compilers, endpoint),
    do: compile_stage(compilers, :before_compile, [endpoint])

  defp compile_stage(compilers, callback, args) do
    blocks =
      for compiler <- compilers,
          _ = Code.ensure_compiled!(compiler),
          function_exported?(compiler, callback, length(args)) do
        apply(compiler, callback, args)
      end

    quote do
      (unquote_splicing(blocks))
    end
  end
end
