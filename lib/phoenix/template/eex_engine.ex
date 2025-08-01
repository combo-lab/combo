defmodule Phoenix.Template.EExEngine do
  @moduledoc """
  The template engine that handles EEx templates.

  Warning: Do not use this function with user-generated content, as it does not
  escape HTML, hence it doesn't provides XSS protection.
  """

  @behaviour Phoenix.Template.Engine

  def compile(path, _name) do
    opts = [
      engine: EEx.SmartEngine,
      line: 1
    ]

    EEx.compile_file(path, opts)
  end
end
