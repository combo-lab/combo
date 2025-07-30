defmodule Phoenix.Template.HTMLEncoder do
  @moduledoc """
  The format encoder for HTML.
  """

  @behaviour Phoenix.Template.FormatEncoder

  def encode_to_iodata!(data), do: Phoenix.HTML.Safe.to_iodata(data)
end
