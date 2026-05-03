defmodule Combo.Template.EExEngine do
  @moduledoc """
  The template engine that handles EEx templates.
  """

  @behaviour Combo.Template.Engine

  def compile(path, _name) do
    opts = [
      engine: EEx.SmartEngine,
      line: 1
    ]

    EEx.compile_file(path, opts)
  end
end
