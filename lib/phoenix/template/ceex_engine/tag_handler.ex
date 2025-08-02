defmodule Phoenix.Template.CEExEngine.TagHandler do
  @moduledoc false

  @doc """
  Classifies tag from a given tag.

  It returns a tuple containing the type of tag and the name of tag, such as
  `{:html_tag, "div"}`. It can also return `{:error, reason}`, so that the
  compiler will display this error.
  """
  @spec classify_tag(name :: binary()) ::
          {type :: atom(), name :: binary()} | {:error, reason :: binary()}
  def classify_tag(<<first, _::binary>> = name) when first in ?A..?Z,
    do: {:remote_component, name}

  def classify_tag("."), do: {:error, "a component name is required after ."}
  def classify_tag("." <> name), do: {:local_component, name}

  def classify_tag(":inner_block"), do: {:error, "the slot name :inner_block is reserved"}
  def classify_tag(":" <> name), do: {:slot, name}

  def classify_tag(name), do: {:html_tag, name}

  @doc """
  Checks if a given tag is a void tag.
  """
  @spec void_tag?(name :: binary()) :: boolean()
  for name <- ~w(area base br col hr img input link meta param command keygen source) do
    def void_tag?(unquote(name)), do: true
  end

  def void_tag?(_), do: false
end
