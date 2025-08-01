defmodule Phoenix.Template.ExsEngine do
  @moduledoc """
  The template engine that handles Elixir script template.
  """

  @behaviour Phoenix.Template.Engine

  def compile(path, _name) do
    path
    |> File.read!()
    |> Code.string_to_quoted!(file: path)
  end
end
