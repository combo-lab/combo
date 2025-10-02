defmodule TestSupport.Proxy.SampleCombo.Controller do
  @moduledoc false

  use Combo.Controller
  import Plug.Conn
  import Combo.Conn

  def index(conn, _) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "Combo: Hello, World!")
  end
end
