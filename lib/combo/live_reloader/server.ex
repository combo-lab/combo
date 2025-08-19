defmodule Combo.LiveReloader.Server do
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

  def start_link(name) do
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

    FileSystem.start_link(opts)
  end

  def ensure_started do
    name = get_name()

    case DynamicSupervisor.start_child(Combo.LiveReloader.Supervisor, {__MODULE__, name}) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      other -> other
    end
  end

  def subscribe do
    name = get_name()

    if Process.whereis(name) do
      :ok = FileSystem.subscribe(name)
      :ok
    else
      :error
    end
  end

  defp get_name, do: __MODULE__
end
