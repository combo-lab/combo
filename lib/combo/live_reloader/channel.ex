defmodule Combo.LiveReloader.Channel do
  @moduledoc false

  use Combo.Channel
  require Logger
  alias Combo.LiveReloader.Server

  def join("combo:live_reloader", _msg, socket) do
    endpoint = socket.endpoint

    case Server.ensure_started() do
      :ok ->
        :pass

      _ ->
        Logger.warning("""
        Could not start #{inspect(__MODULE__)} because it can't listen to the \
        file system.

        Don't worry! This is an optional feature used during development to refresh
        web browser when files change, and it does not affect production.
        """)
    end

    case Server.subscribe() do
      :ok ->
        config = endpoint.config(:live_reloader)

        socket =
          socket
          |> assign(:patterns, config[:patterns] || [])

        {:ok, %{}, socket}

      :error ->
        {:error, %{message: "#{inspect(Server)} is not running"}}
    end
  end

  def handle_info({:file_event, _pid, file_event}, socket) do
    %{patterns: patterns} = socket.assigns

    file_events = collect_file_events(file_event, patterns, [])

    grouped_file_events =
      Enum.group_by(
        file_events,
        fn {path, _events} -> build_file_type(path) end,
        fn {path, _events} -> path end
      )

    for {type, paths} <- grouped_file_events do
      for path <- paths do
        Logger.debug("Combo.LiveReloader detected changes of #{Path.relative_to_cwd(path)}")
      end

      push(socket, "reload", %{type: type})
    end

    {:noreply, socket}
  end

  @watched_events [:created, :modified, :removed, :renamed]
  defp collect_file_events(file_event, path_patterns, acc) do
    acc =
      if match_file_event?(file_event, path_patterns, @watched_events),
        do: [file_event | acc],
        else: acc

    receive do
      {:file_event, _pid, file_event} ->
        collect_file_events(file_event, path_patterns, acc)
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp match_file_event?(file_event, path_patterns, watched_events) do
    {path, events} = file_event
    path = to_string(path)

    path_matched? =
      Enum.any?(path_patterns, fn path_pattern ->
        String.match?(path, path_pattern) and not String.match?(path, ~r{(^|/)_build/})
      end)

    events_matched? = Enum.any?(events, fn event -> event in watched_events end)

    path_matched? && events_matched?
  end

  defp build_file_type(path) do
    path
    |> Path.extname()
    |> remove_leading_dot()
  end

  defp remove_leading_dot("." <> rest), do: rest
  defp remove_leading_dot(rest), do: rest
end
