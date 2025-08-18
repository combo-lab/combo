# Get Mix output sent to the current process to avoid polluting tests.
Mix.shell(Mix.Shell.Process)

defmodule MixHelper do
  def in_tmp(which, function) do
    base = Path.join([tmp_path(), random_string(10)])
    path = Path.join([base, to_string(which)])

    try do
      File.rm_rf!(path)
      File.mkdir_p!(path)
      File.cd!(path, function)
    after
      File.rm_rf!(base)
    end
  end

  defp random_string(len) do
    len |> :crypto.strong_rand_bytes() |> Base.url_encode64() |> binary_part(0, len)
  end

  defp tmp_path do
    Path.expand("../../../tmp/mix", __DIR__)
  end
end
