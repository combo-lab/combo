defmodule Support.Router do
  defmacro __using__(_) do
    quote do
      use Combo.Router

      import Plug.Conn
      import Combo.Conn
    end
  end
end
