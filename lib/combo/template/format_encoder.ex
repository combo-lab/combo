defmodule Combo.Template.FormatEncoder do
  @moduledoc """
  The behaviour for implementing format encoders.

  Check out `Combo.Template` for more details.
  """

  @doc """
  Returns the iodata.
  """
  @callback encode_to_iodata!(term()) :: iodata()
end
