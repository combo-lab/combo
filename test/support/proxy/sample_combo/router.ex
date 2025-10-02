defmodule TestSupport.Proxy.SampleCombo.Router do
  @moduledoc false

  use Combo.Router
  import Combo.Conn

  pipeline :browser do
    plug :accepts, ["html"]
  end

  scope "/", TestSupport.Proxy.SampleCombo do
    pipe_through :browser

    get "/", Controller, :index

    # Prevent an error because conrresponding view is missing
    get "/favicon.ico", Controller, :index
  end
end
