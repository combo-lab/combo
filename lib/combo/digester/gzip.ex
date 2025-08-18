defmodule Combo.Digester.Gzip do
  @moduledoc ~S"""
  Gzip compressor for Combo.Digester
  """
  @behaviour Combo.Digester.Compressor

  def compress_file(file_path, content) do
    if Path.extname(file_path) in Combo.Digester.compressible_extensions() do
      {:ok, :zlib.gzip(content)}
    else
      :error
    end
  end

  def file_extensions do
    [".gz"]
  end
end
