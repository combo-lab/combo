defmodule Mix.Tasks.Combo.Test do
  use ExUnit.Case

  test "provide a list of available phx mix tasks" do
    Mix.Tasks.Combo.run []
    assert_received {:mix_shell, :info, ["mix combo.serve" <> _]}
    assert_received {:mix_shell, :info, ["mix combo.routes" <> _]}
    assert_received {:mix_shell, :info, ["mix combo.static.digest" <> _]}
    assert_received {:mix_shell, :info, ["mix combo.static.clean" <> _]}
    assert_received {:mix_shell, :info, ["mix combo.gen.secret" <> _]}
  end

  test "expects no arguments" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Combo.run ["invalid"]
    end
  end
end
