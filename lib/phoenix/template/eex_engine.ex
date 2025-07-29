defmodule Phoenix.Template.EExEngine do
  @moduledoc """
  The template engine that handles the `.eex` extension.
  """

  @behaviour Phoenix.Template.Engine

  alias Phoenix.Env

  def compile(path, _name) do
    EEx.compile_file(path, [line: 1] ++ options_for(path))
  end

  defp options_for(path) do
    format =
      case path |> Path.rootname() |> Path.extname() do
        "." <> format ->
          format

        _ ->
          raise ArgumentError,
                "template paths in Phoenix require the format extension, got: #{path}"
      end

    case Phoenix.Template.format_encoder(format) do
      Phoenix.HTML.Engine ->
        unless Code.ensure_loaded?(Phoenix.HTML.Engine) do
          raise "could not load Phoenix.HTML.Engine to use with .html.eex templates. " <>
                  "You can configure your own format encoder for HTML but we recommend " <>
                  "adding phoenix_html as a dependency as it provides XSS protection."
        end

        trim = Env.get_env(:template, :trim_on_html_eex_engine, true)

        [engine: Phoenix.HTML.Engine, trim: trim]

      _ ->
        [engine: EEx.SmartEngine]
    end
  end
end
