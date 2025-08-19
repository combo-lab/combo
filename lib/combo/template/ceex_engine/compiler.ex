defmodule Combo.Template.CEExEngine.Compiler do
  @moduledoc """
  The compiler for `Combo.Template.CEExEngine`.
  """

  alias Combo.Env
  alias Combo.Template.CEExEngine.Compiler.Engine

  @doc false
  defmacro compile_file(path, opts \\ []) do
    source = File.read!(path)

    default_opts = [
      engine: Engine,
      caller: __CALLER__,
      file: path,
      line: 1,
      trim: trim?(),
      source: source
    ]

    opts = Keyword.merge(default_opts, opts)
    EEx.compile_string(source, opts)
  end

  @doc false
  def compile_string(source, opts \\ []) do
    default_opts = [
      engine: Engine,
      caller: :not_available,
      file: "nofile",
      line: 1,
      indentation: 0,
      trim: trim?(),
      source: source
    ]

    opts = Keyword.merge(default_opts, opts)
    EEx.compile_string(source, opts)
  end

  @doc false
  defdelegate __reserved_assigns__, to: Engine

  defp trim?, do: Env.get_env(:template, :ceex_whitespace_trimming, true)
end
