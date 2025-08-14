defmodule Combo.LiveReloader.Application do
  @moduledoc false

  use Application
  require Logger
  alias Combo.Env

  # 1. rewrite it as dynamic supervisor?
  # 2. create one every endpoint?

  @impl Application
  def start(_type, _args) do
    children = [%{id: __MODULE__, start: {__MODULE__, :start_link, []}}]
    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def start_link do
    dirs = Env.get_env(:live_reloader, :dirs, [""])
    backend = Env.get_env(:live_reloader, :backend)
    backend_opts = Env.get_env(:live_reloader, :backend_opts, [])

    opts =
      [
        # TODO:
        name: :combo_live_reloader_file_monitor,
        dirs: Enum.map(dirs, &Path.absname/1)
      ] ++ backend_opts

    opts =
      if backend,
        do: [backend: backend] ++ opts,
        else: opts

    case FileSystem.start_link(opts) do
      {:ok, pid} ->
        {:ok, pid}

      other ->
        Logger.warning("""
        Could not start Combo.LiveReloader.Application because it can't listen to the \
        file system.

        Don't worry! This is an optional feature used during development to refresh
        web browser when files change, and it does not affect production.
        """)

        other
    end
  end
end
