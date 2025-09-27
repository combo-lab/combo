defmodule Mix.Tasks.Combo.Static.Clean do
  @shortdoc "Cleans old versions of static files"

  @moduledoc """
  #{@shortdoc}.

  By default, it will keep the latest version and 2 previous versions of static
  files as well as any digested static files created in the last hour.

  ```console
  $ mix combo.static.clean
  $ mix combo.static.clean -o /www/public
  $ mix combo.static.clean --age 600 --keep 3
  $ mix combo.static.clean --all
  ```

  ## Options

    * `-o, --output` - specifies the path of output directory.
      Defaults to `priv/static`.

    * `--age` - specifies a maximum age (in seconds) for static files. Files
      older than this age that are not in the last `--keep` versions will be
      removed.
      Defaults to `3600`.

    * `--keep` - specifies how many previous versions of static files to keep.
      Defaults to 2 previous versions.

    * `--all` - specifies that all digested static files (including the manifest)
      will be removed. Note this overrides the `--age` and `--keep`.

    * `--no-compile` - do not run mix compile.

  """

  use Mix.Task

  @default_output_path "priv/static"
  @default_age 3600
  @default_keep 2

  @switches [output: :string, age: :integer, keep: :integer, all: :boolean]

  @impl Mix.Task
  def run(all_args) do
    # Ensure all compressors are compiled.
    if "--no-compile" not in all_args do
      Mix.Task.run("compile", all_args)
    end

    Mix.Task.reenable("combo.static.clean")

    {:ok, _} = Application.ensure_all_started(:combo)

    {opts, _, _} = OptionParser.parse(all_args, switches: @switches, aliases: [o: :output])
    output_path = opts[:output] || @default_output_path
    age = opts[:age] || @default_age
    keep = opts[:keep] || @default_keep
    all? = opts[:all] || false

    result =
      if all?,
        do: Combo.Static.Digester.clean_all(output_path),
        else: Combo.Static.Digester.clean(output_path, age, keep)

    case result do
      :ok ->
        # We need to call build structure so everything we have cleaned from
        # priv is removed from _build in case we have build_embedded set to
        # true. In case it's not true, build structure is mostly a no-op, so we
        # are fine.
        Mix.Project.build_structure()
        Mix.shell().info([:green, "Clean complete for #{inspect(output_path)}"])

      {:error, :invalid_path} ->
        Mix.shell().error("The output path #{inspect(output_path)} does not exist")
    end
  end
end
