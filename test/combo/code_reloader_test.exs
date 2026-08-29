defmodule Combo.CodeReloaderTest do
  use ExUnit.Case, async: true
  use Support.RouterHelper

  defmodule Endpoint do
    def config(:code_reloader) do
      [
        reloadable_apps: nil,
        reloadable_compilers: [:unknown_compiler, :elixir],
        reloadable_args: ["--unknown", "--all-warnings"]
      ]
    end
  end

  # Booting Elixir puts Mix in the code path but does not start it,
  # which is how deployments that keep Mix around look to Combo.
  @boot_without_mix """
  true = Code.ensure_loaded?(Mix.Project)
  nil = Process.whereis(Mix.ProjectStack)
  {:ok, _} = Application.ensure_all_started(:combo)
  IO.write("combo booted")
  """

  test "boots when Mix is in the code path but not started" do
    args =
      Enum.flat_map(:code.get_path(), &["-pa", List.to_string(&1)]) ++
        ["-e", @boot_without_mix]

    assert {output, 0} = System.cmd("elixir", args, stderr_to_stdout: true)
    assert output =~ "combo booted"
  end

  @tag :capture_log
  test "syncs with code server" do
    assert Combo.CodeReloader.sync() == :ok

    # Suspend so we can monitor the process until we get a reply.
    # There is an inherent race condition here in that the process
    # may die before we request but the code should work in both
    # cases, so we are fine.
    :sys.suspend(Combo.CodeReloader.Server)
    ref = Process.monitor(Combo.CodeReloader.Server)

    Task.start_link(fn ->
      Combo.CodeReloader.Server
      |> Process.whereis()
      |> Process.exit(:kill)
    end)

    assert Combo.CodeReloader.sync() == :ok
    assert_receive {:DOWN, ^ref, _, _, _}
    wait_until_is_up(Combo.CodeReloader.Server)
  end

  test "reloads on every request" do
    pid = Process.whereis(Combo.CodeReloader.Server)
    :erlang.trace(pid, true, [:receive])

    opts = Combo.CodeReloader.init([])

    conn =
      conn(:get, "/")
      |> Plug.Conn.put_private(:combo_endpoint, Endpoint)
      |> Combo.CodeReloader.call(opts)

    assert conn.state == :unset

    assert_receive {:trace, ^pid, :receive, {_, _, {:reload!, Endpoint}}}
  end

  test "renders compilation error on failure" do
    reload_result = {:error, "oops \e[31merror"}

    conn =
      conn(:get, "/")
      |> Combo.CodeReloader.__handle_reload__(reload_result)

    assert conn.state == :sent
    assert conn.status == 500
    assert conn.resp_body =~ "oops error"
    assert conn.resp_body =~ "CompileError"
    assert conn.resp_body =~ "Compilation error"
  end

  defp wait_until_is_up(process) do
    if Process.whereis(process) do
      :ok
    else
      Process.sleep(10)
      wait_until_is_up(process)
    end
  end
end
