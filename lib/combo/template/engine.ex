defmodule Combo.Template.Engine do
  @moduledoc """
  The behaviour for implementing template engines.

  Check out `Combo.Template` for more details.
  """

  @doc """
  Returns the quoted expression of template.
  """
  @callback compile(template_path :: binary(), template_name :: binary()) :: Macro.t()
end
