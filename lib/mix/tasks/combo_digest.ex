defmodule Mix.Tasks.Combo.Digest do
  @shortdoc "Digests and compresses files"

  @moduledoc """
  #{@shortdoc}.

  ```console
  $ mix combo.digest
  $ mix combo.digest priv/static -o /www/public
  ```

  The first argument is the path where the static files are located. The
  `-o` option specifies the path that will be used to save the digested and
  compressed files.

  If no path is given, it will use `priv/static` as the input and output path.

  It will generate following files:

    * the original file
    * the file compressed with gzip
    * a file containing the original file name and its digest
    * a compressed file containing the file name and its digest
    * a cache manifest file

  An example of generated files:

    * app.js
    * app.js.gz
    * app-eb0a5b9302e8d32828d8a73f137cc8f0.js
    * app-eb0a5b9302e8d32828d8a73f137cc8f0.js.gz
    * cache_manifest.json

  You can use `mix combo.digest.clean` to prune stale versions of the assets.
  If you want to remove all generated files:

  ```console
  $ mix combo.digest.clean --all
  ```

  ## vsn

  It is possible to digest the stylesheet asset references without the query
  string "?vsn=d" with the option `--no-vsn`.

  ## Options

    * `-o, --output` - specifies the path of output directory.
      Defaults to `priv/static`.

    * `--no-vsn` - do not add version query string to file references.

    * `--no-compile` - do not run mix compile.

  """

  use Mix.Task

  @default_input_path "priv/static"
  @default_opts [vsn: true]

  @switches [output: :string, vsn: :boolean]

  @impl Mix.Task
  def run(all_args) do
    # Ensure all compressors are compiled.
    if "--no-compile" not in all_args do
      Mix.Task.run("compile", all_args)
    end

    Mix.Task.reenable("combo.digest")

    {:ok, _} = Application.ensure_all_started(:combo)

    {opts, args, _} = OptionParser.parse(all_args, switches: @switches, aliases: [o: :output])
    input_path = List.first(args) || @default_input_path
    output_path = opts[:output] || input_path
    with_vsn? = Keyword.merge(@default_opts, opts)[:vsn]

    case Combo.Digester.compile(input_path, output_path, with_vsn?) do
      :ok ->
        # We need to call build structure so everything we have
        # generated into priv is copied to _build in case we have
        # build_embedded set to true. In case it's not true,
        # build structure is mostly a no-op, so we are fine.
        Mix.Project.build_structure()
        Mix.shell().info([:green, "Check your digested files at #{inspect(output_path)}"])

      {:error, :invalid_path} ->
        # Do not exit with status code on purpose because
        # in an umbrella not all apps are digestable.
        Mix.shell().error("The input path #{inspect(input_path)} does not exist")
    end
  end
end
