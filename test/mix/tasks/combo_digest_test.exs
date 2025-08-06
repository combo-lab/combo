Code.require_file "./mix_helper.exs", __DIR__

defmodule Mix.Tasks.Combo.DigestTest do
  use ExUnit.Case
  import MixHelper

  test "logs when the path is invalid" do
    Mix.Tasks.Combo.Digest.run(["invalid_path", "--no-compile"])
    assert_received {:mix_shell, :error, ["The input path \"invalid_path\" does not exist"]}
  end

  @output_path "mix_combo_digest"
  test "digests and compress files" do
    in_tmp @output_path, fn ->
      File.mkdir_p!("priv/static")
      Mix.Tasks.Combo.Digest.run(["priv/static", "-o", @output_path, "--no-compile"])
      assert_received {:mix_shell, :info, ["Check your digested files at \"mix_combo_digest\""]}
    end
  end

  @output_path "mix_combo_digest_no_input"
  test "digests and compress files without the input path" do
    in_tmp @output_path, fn ->
      File.mkdir_p!("priv/static")
      Mix.Tasks.Combo.Digest.run(["-o", @output_path, "--no-compile"])
      assert_received {:mix_shell, :info, ["Check your digested files at \"mix_combo_digest_no_input\""]}
    end
  end

  @input_path "input_path"
  test "uses the input path as output path when no output path is given" do
    in_tmp @input_path, fn ->
      File.mkdir_p!(@input_path)
      Mix.Tasks.Combo.Digest.run([@input_path, "--no-compile"])
      assert_received {:mix_shell, :info, ["Check your digested files at \"input_path\""]}
    end
  end
end
