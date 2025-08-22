defmodule Combo.Template.CEExEngine.Compiler.DebugAnnotation do
  @moduledoc false

  alias Combo.Env

  def enable? do
    Env.get_env(:template, :ceex_debug_annotations, false)
  end

  @doc """
  Builds annotation around a tag.
  """
  @spec build_annotation(name :: String.t(), file :: String.t(), line: non_neg_integer()) ::
          {String.t(), String.t()}
  def build_annotation(name, file, line) do
    line = if line == 0, do: 1, else: line
    file = Path.relative_to_cwd(file)
    {"<!-- <#{name}> #{file}:#{line} (#{current_otp_app()}) -->", "<!-- </#{name}> -->"}
  end

  @doc """
  Builds annotation that indicates the caller of a tag.
  """
  @callback build_caller_annotation(file :: String.t(), line :: integer()) :: String.t()
  def build_caller_annotation(file, line) do
    line = if line == 0, do: 1, else: line
    file = Path.relative_to_cwd(file)
    "<!-- @caller #{file}:#{line} (#{current_otp_app()}) -->"
  end

  defp current_otp_app do
    Application.get_env(:logger, :compile_time_application)
  end
end
