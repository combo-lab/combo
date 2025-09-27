defmodule Combo.Static.Compressor.Gzip do
  @moduledoc """
  An implementation of gzip compressor.
  """

  @behaviour Combo.Static.Compressor

  def compress_file(file_path, content) do
    if Path.extname(file_path) in Combo.Static.compressible_extensions() do
      {:ok, :zlib.gzip(content)}
    else
      :error
    end
  end

  def file_extensions do
    [".gz"]
  end
end
