defmodule Combo.LiveReloader.FileSystemListener do
  @moduledoc false

  require Logger
  alias Combo.Env

  def child_spec(args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [args]},
      restart: :transient
    }
  end

  def start_link(endpoint) do
    name = build_name(endpoint)

    dirs = Env.get_env(:live_reloader, :dirs, [""])
    backend = Env.get_env(:live_reloader, :backend)
    backend_opts = Env.get_env(:live_reloader, :backend_opts, [])

    opts =
      [
        name: name,
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

  def subscribe(endpoint) do
    name = build_name(endpoint)

    if Process.whereis(name) do
      :ok = FileSystem.subscribe(name)
      :ok
    else
      :error
    end
  end

  defp build_name(endpoint) do
    Module.concat(endpoint, __MODULE__)
  end
end
