defmodule Combo.LiveReloader.ChannelTest do
  use ExUnit.Case

  @moduletag :capture_log

  import Combo.ChannelTest

  alias Combo.LiveReloader
  alias Combo.LiveReloader.Channel

  defmodule Endpoint do
    use Combo.Endpoint, otp_app: :combo
  end

  Application.put_env(:combo, Endpoint,
    pubsub_server: __MODULE__.PubSub,
    live_reloader: [
      patterns: [
        ~r"lib/demo/web/(?:router|controllers|layouts|components)(?:/.*)?\.(ex|ceex)$",
        ~r"priv/static/.*(js|css|png|jpeg|jpg|gif)$"
      ]
    ]
  )

  @endpoint Endpoint

  defp file_event(path, event) do
    {:file_event, self(), {path, event}}
  end

  setup_all do
    children =
      [
        {Phoenix.PubSub, name: __MODULE__.PubSub},
        Endpoint
      ] ++ Combo.LiveReloader.child_specs(Endpoint)

    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)
    :ok
  end

  setup do
    {:ok, _, socket} =
      LiveReloader.Socket
      |> socket()
      |> subscribe_and_join(Channel, "combo:live_reload", %{})

    {:ok, socket: socket}
  end

  test "sends a notification when a file is created", %{socket: socket} do
    send(socket.channel_pid, file_event("priv/static/example.js", :created))
    assert_push "reload", %{type: "js"}
  end

  test "sends a notification when a file is removed", %{socket: socket} do
    send(socket.channel_pid, file_event("priv/static/example.js", :removed))
    assert_push "reload", %{type: "js"}
  end

  test "logs on live reload", %{socket: socket} do
    content =
      ExUnit.CaptureLog.capture_log(fn ->
        send(socket.channel_pid, file_event("priv/static/example.js", :removed))
        assert_push "reload", %{type: "js"}
      end)

    assert content =~ "[debug] Live reload: priv/static/example.js"
  end

  test "does not send a notification when a file comes from _build", %{socket: socket} do
    send(
      socket.channel_pid,
      file_event(
        "_build/test/lib/combo/priv/static/live_reloader.min.js",
        :created
      )
    )

    refute_receive _anything, 100
  end

  test "allows project names containing _build", %{socket: socket} do
    send(
      socket.channel_pid,
      file_event(
        "/home/nobody/www/widget_builder/lib/demo/web/layouts/app.html.ceex",
        :created
      )
    )

    assert_push "reload", %{type: "ceex"}
  end

  test "sends notification for js", %{socket: socket} do
    send(socket.channel_pid, file_event("priv/static/example.js", :created))
    assert_push "reload", %{type: "js"}
  end

  test "sends notification for css", %{socket: socket} do
    send(socket.channel_pid, file_event("priv/static/example.css", :created))
    assert_push "reload", %{type: "css"}
  end

  test "sends notification for images", %{socket: socket} do
    send(socket.channel_pid, file_event("priv/static/example.png", :created))
    assert_push "reload", %{type: "png"}
  end

  test "sends notification for templates", %{socket: socket} do
    send(socket.channel_pid, file_event("lib/demo/web/layouts/root.html.ceex", :created))
    assert_push "reload", %{type: "ceex"}
  end

  test "sends notification for Elixir module", %{socket: socket} do
    send(socket.channel_pid, file_event(~c"lib/demo/web/router.ex", :created))
    assert_push "reload", %{type: "ex"}
  end
end
