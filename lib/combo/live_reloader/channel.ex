defmodule Combo.LiveReloader.Channel do
  @moduledoc false

  use Combo.Channel
  require Logger
  alias Combo.LiveReloader.FileSystemListener

  def join("combo:live_reload", _msg, socket) do
    endpoint = socket.endpoint

    case FileSystemListener.subscribe(endpoint) do
      :ok ->
        config = endpoint.config(:live_reloader)

        socket =
          socket
          |> assign(:patterns, config[:patterns] || [])

        {:ok, %{}, socket}

      :error ->
        {:error, %{message: "#{inspect(FileSystemListener)} is not running"}}
    end
  end

  def handle_info({:file_event, _pid, {path, _event}}, socket) do
    %{patterns: patterns} = socket.assigns

    file_events = collect_file_events(path, patterns, [])

    grouped_file_events =
      Enum.group_by(
        file_events,
        fn {type, _path} -> type end,
        fn {_type, path} -> path end
      )

    for {type, paths} <- grouped_file_events do
      for path <- paths do
        Logger.debug("Live reload: #{Path.relative_to_cwd(path)}")
      end

      push(socket, "assets_change", %{asset_type: type})
    end

    {:noreply, socket}
  end

  defp collect_file_events(path, patterns, acc) do
    acc =
      if match_patterns?(path, patterns) do
        type = build_file_type(path)
        [{type, path} | acc]
      else
        acc
      end

    receive do
      {:file_event, _pid, {path, _event}} ->
        collect_file_events(path, patterns, acc)
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp match_patterns?(path, patterns) do
    path = to_string(path)

    Enum.any?(patterns, fn pattern ->
      String.match?(path, pattern) and not String.match?(path, ~r{(^|/)_build/})
    end)
  end

  defp build_file_type(path) do
    path
    |> Path.extname()
    |> remove_leading_dot()
  end

  defp remove_leading_dot("." <> rest), do: rest
  defp remove_leading_dot(rest), do: rest
end
