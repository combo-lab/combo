defmodule Phoenix.Template.CEExEngine.TagHandler.HTML do
  @moduledoc false

  @behaviour Phoenix.Template.CEExEngine.TagHandler

  @impl true
  def classify_type(":inner_block"), do: {:error, "the slot name :inner_block is reserved"}
  def classify_type(":" <> name), do: {:slot, name}

  def classify_type(<<first, _::binary>> = name) when first in ?A..?Z,
    do: {:remote_component, name}

  def classify_type("."), do: {:error, "a component name is required after ."}
  def classify_type("." <> name), do: {:local_component, name}

  def classify_type(name), do: {:tag, name}

  @impl true
  for tag <- ~w(area base br col hr img input link meta param command keygen source) do
    def void?(unquote(tag)), do: true
  end

  def void?(_), do: false

  @impl true
  def annotate_body(%Macro.Env{} = caller) do
    if Application.get_env(:phoenix_live_view, :debug_heex_annotations, false) do
      %Macro.Env{module: mod, function: {fun, _}, file: file, line: line} = caller
      name = "#{inspect(mod)}.#{fun}"
      annotate_source(name, file, line)
    end
  end

  @impl true
  def annotate_slot(name, %{line: line}, _close_meta, %{file: file}) do
    if Application.get_env(:phoenix_live_view, :debug_heex_annotations, false) do
      annotate_source(":#{name}", file, line)
    end
  end

  defp annotate_source(name, file, line) do
    line = if line == 0, do: 1, else: line
    file = Path.relative_to_cwd(file)
    {"<!-- <#{name}> #{file}:#{line} (#{current_otp_app()}) -->", "<!-- </#{name}> -->"}
  end

  @impl true
  def annotate_caller(file, line) do
    if Application.get_env(:phoenix_live_view, :debug_heex_annotations, false) do
      line = if line == 0, do: 1, else: line
      file = Path.relative_to_cwd(file)
      "<!-- @caller #{file}:#{line} (#{current_otp_app()}) -->"
    end
  end

  defp current_otp_app do
    Application.get_env(:logger, :compile_time_application)
  end
end
