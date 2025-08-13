defmodule Support.Router do
  defmacro __using__(_) do
    quote do
      use Combo.Router

      import Combo.Conn
      import Plug.Conn
    end
  end
end
