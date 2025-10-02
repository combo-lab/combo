defmodule TestSupport.Proxy.SampleCombo.Endpoint do
  @moduledoc false

  use Combo.Endpoint, otp_app: :test_support_proxy_sample_combo

  plug TestSupport.Proxy.SampleCombo.Router
end
