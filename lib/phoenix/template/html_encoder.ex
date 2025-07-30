defmodule Phoenix.Template.HTMLEncoder do
  @moduledoc """
  The format encoder for HTML.
  """

  alias Combo.SafeHTML

  @behaviour Phoenix.Template.FormatEncoder

  def encode_to_iodata!(data), do: SafeHTML.to_iodata(data)
end
