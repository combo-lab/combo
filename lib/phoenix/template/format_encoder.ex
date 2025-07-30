defmodule Phoenix.Template.FormatEncoder do
  @moduledoc """
  The behaviour for implementing format encoders.

  Check out `Phoenix.Template` for more details.
  """

  @doc """
  Returns the iodata.
  """
  @callback encode_to_iodata!(term()) :: iodata()
end
