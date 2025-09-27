defmodule Combo.Static do
  @doc """
  Lists the compressors.
  """
  @spec compressors :: [module()]
  def compressors do
    Combo.Env.get_env(
      :static,
      :compressors,
      [Combo.Static.Compressor.Gzip]
    )
  end

  @doc """
  Lists the extensions of compressible files.
  """
  @spec compressible_extensions :: [String.t()]
  def compressible_extensions do
    Combo.Env.get_env(
      :static,
      :compressible_extensions,
      ~w(.js .map .css .txt .text .html .json .svg .eot .ttf)
    )
  end
end
