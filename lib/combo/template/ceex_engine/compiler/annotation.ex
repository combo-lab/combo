defmodule Combo.Template.CEExEngine.Compiler.Annotation do
  @moduledoc false

  alias Combo.Env

  @doc """
  Gets annotation around the whole body of a template.
  """
  @spec get_body_annotation(caller :: Macro.Env.t()) :: {String.t(), String.t()} | nil
  def get_body_annotation(%Macro.Env{} = caller) do
    if Env.get_env(:template, :ceex_debug_annotations, false) do
      %Macro.Env{module: mod, function: {fun, _}, file: file, line: line} = caller
      name = "#{inspect(mod)}.#{fun}"
      annotate_source(name, file, line)
    end
  end

  @doc """
  Gets annotation around each slot of a template.

  In case the slot is an implicit inner block, the tag meta points to
  the component.
  """
  @spec get_slot_annotation(
          name :: atom(),
          tag_meta :: %{line: non_neg_integer(), column: non_neg_integer()},
          close_tag_meta :: %{line: non_neg_integer(), column: non_neg_integer()},
          caller :: Macro.Env.t()
        ) :: {String.t(), String.t()} | nil
  def get_slot_annotation(name, %{line: line}, _close_meta, %{file: file}) do
    if Env.get_env(:template, :ceex_debug_annotations, false) do
      annotate_source(":#{name}", file, line)
    end
  end

  @doc """
  Gets annotation which is added at the beginning of a component.
  """
  # TODO: change file and line to caller, just like get_body_annotation
  @callback get_caller_annotation(file :: String.t(), line :: integer()) :: String.t() | nil
  def get_caller_annotation(file, line) do
    if Env.get_env(:template, :ceex_debug_annotations, false) do
      line = if line == 0, do: 1, else: line
      file = Path.relative_to_cwd(file)
      "<!-- @caller #{file}:#{line} (#{current_otp_app()}) -->"
    end
  end

  defp annotate_source(name, file, line) do
    line = if line == 0, do: 1, else: line
    file = Path.relative_to_cwd(file)
    {"<!-- <#{name}> #{file}:#{line} (#{current_otp_app()}) -->", "<!-- </#{name}> -->"}
  end

  defp current_otp_app do
    Application.get_env(:logger, :compile_time_application)
  end
end
