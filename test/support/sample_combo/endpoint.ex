defmodule SampleCombo.Endpoint do
  @moduledoc false

  use Combo.Endpoint, otp_app: :sample_combo

  plug SampleCombo.Router
end
