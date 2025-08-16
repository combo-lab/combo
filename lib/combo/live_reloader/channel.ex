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
          |> assign(:debounce, config[:debounce] || 0)

        {:ok, %{}, socket}

      :error ->
        {:error, %{message: "#{inspect(FileSystemListener)} is not running"}}
    end
  end

  def handle_info({:file_event, _pid, {path, _event}}, socket) do
    %{
      patterns: patterns,
      debounce: debounce
    } = socket.assigns

    if match_patterns?(path, patterns) do
      ext = Path.extname(path)

      for {path, ext} <- [{path, ext} | debounce(debounce, [ext], patterns)] do
        asset_type = remove_leading_dot(ext)
        Logger.debug("Live reload: #{Path.relative_to_cwd(path)}")
        push(socket, "assets_change", %{asset_type: asset_type})
      end
    end

    {:noreply, socket}
  end

  defp match_patterns?(path, patterns) do
    path = to_string(path)

    Enum.any?(patterns, fn pattern ->
      String.match?(path, pattern) and not String.match?(path, ~r{(^|/)_build/})
    end)
  end

  defp debounce(0, _exts, _patterns), do: []

  defp debounce(time, exts, patterns) when is_integer(time) and time > 0 do
    Process.send_after(self(), :debounced, time)
    debounce(exts, patterns)
  end

  defp debounce(exts, patterns) do
    receive do
      :debounced ->
        []

      {:file_event, _pid, {path, _event}} ->
        ext = Path.extname(path)

        if match_patterns?(path, patterns) and ext not in exts do
          [{path, ext} | debounce([ext | exts], patterns)]
        else
          debounce(exts, patterns)
        end
    end
  end

  defp remove_leading_dot("." <> rest), do: rest
  defp remove_leading_dot(rest), do: rest
end
