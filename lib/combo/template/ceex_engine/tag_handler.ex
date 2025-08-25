defmodule Combo.Template.CEExEngine.TagHandler do
  @moduledoc false

  @doc """
  Checks if a given tag is a void tag.
  """
  @spec void_tag?(name :: binary()) :: boolean()
  for name <- ~w(area base br col hr img input link meta param command keygen source) do
    def void_tag?(unquote(name)), do: true
  end

  def void_tag?(_), do: false
end
