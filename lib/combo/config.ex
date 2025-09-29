defmodule Combo.Config do
  @moduledoc false

  require Logger

  @spec from_env(atom(), module()) :: keyword()
  def from_env(otp_app, module) do
    case Application.fetch_env(otp_app, module) do
      {:ok, config} ->
        config

      :error ->
        Logger.warning(
          "no configuration found for otp_app #{inspect(otp_app)} and module #{inspect(module)}"
        )

        []
    end
  end

  @spec merge(keyword(), keyword()) :: keyword()
  def merge(a, b), do: Keyword.merge(a, b, &__merge__/3)

  defp __merge__(_k, v1, v2) do
    if Keyword.keyword?(v1) and Keyword.keyword?(v2) do
      Keyword.merge(v1, v2, &__merge__/3)
    else
      v2
    end
  end
end
