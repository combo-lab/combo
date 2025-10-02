defmodule SampleCombo.Router do
  @moduledoc false

  use Combo.Router
  import Combo.Conn

  pipeline :browser do
    plug :accepts, ["html"]
  end

  scope "/", SampleCombo do
    pipe_through :browser

    get "/", Controller, :index

    # Prevent an error because ErrorView is missing
    get "/favicon.ico", Controller, :index
  end
end
