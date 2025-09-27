defmodule Combo.Static.Compressor do
  @moduledoc ~S"""
  The behaviour for implementing static file compressors.

  ## Example

  If you wanted to compress static files using an external brotli compression
  library, you could define a new module implementing the behaviour and add
  it to the list of configured compressors.

      defmodule MyApp.Web.BrotliCompressor do
        @behaviour Combo.Static.Compressor

        def compress_file(file_path, content) do
          valid_extension = Path.extname(file_path) in Combo.Static.compressible_extensions()
          {:ok, compressed_content} = :brotli.encode(content)

          if valid_extension && byte_size(compressed_content) < byte_size(content) do
            {:ok, compressed_content}
          else
            :error
          end
        end

        def file_extensions do
          [".br"]
        end
      end

      # config/config.exs
      config :combo, :static,
        compressors: [Combo.Static.Compressor.Gzip, MyApp.Web.BrotliCompressor],
        # ...

  """
  @callback compress_file(Path.t(), binary()) :: {:ok, binary()} | :error
  @callback file_extensions() :: nonempty_list(String.t())
end
