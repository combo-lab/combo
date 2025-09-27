defmodule Combo.Static.Compressor.GzipTest do
  use ExUnit.Case, async: true
  alias Combo.Static.Compressor.Gzip

  test "compress_file/2 compresses file" do
    file_path = "test/fixtures/static/priv/static/css/app.css"
    content = File.read!(file_path)

    {:ok, compressed} = Gzip.compress_file(file_path, content)

    assert is_binary(compressed)
  end
end
