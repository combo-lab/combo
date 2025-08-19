defmodule Combo.CodeReloaderTest do
  use ExUnit.Case, async: true
  use Support.RouterHelper

  defmodule Endpoint do
    def config(:code_reloader) do
      [
        reloadable_apps: nil,
        reloadable_compilers: [:unknown_compiler, :elixir]
      ]
    end
  end

  def reload(_, _) do
    {:error, "oops \e[31merror"}
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

    assert_receive {:trace, ^pid, :receive, {_, _, {:reload!, Endpoint, _}}}
  end

  test "renders compilation error on failure" do
    opts = Combo.CodeReloader.init(reloader: &__MODULE__.reload/2)

    conn =
      conn(:get, "/")
      |> Plug.Conn.put_private(:combo_endpoint, Endpoint)
      |> Combo.CodeReloader.call(opts)

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
