defmodule Combo.Endpoint.TelemetryTest do
  use ExUnit.Case, async: true

  defmodule Endpoint do
    use Combo.Endpoint, otp_app: :combo
  end

  def validate_init_event(event, measurements, metadata, _config) do
    assert event == [:combo, :endpoint, :init]
    assert Process.whereis(Endpoint) == metadata.pid
    assert metadata.otp_app == :combo
    assert metadata.module == Endpoint
    assert Keyword.fetch!(metadata.config, :custom) == true
    assert Map.has_key?(measurements, :system_time)
  end

  test "start_link/2 should emit an init event" do
    :telemetry.attach(
      [:test, :endpoint, :init, :handler],
      [:combo, :endpoint, :init],
      &__MODULE__.validate_init_event/4,
      nil
    )

    Application.put_env(:combo, Endpoint, custom: true)
    start_supervised!(Endpoint)
  after
    :telemetry.detach([:test, :endpoint, :init, :handler])
    Application.delete_env(:combo, Endpoint)
  end
end
