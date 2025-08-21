defmodule Support.Controller do
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use Combo.Controller, opts: opts

      import Plug.Conn
      import Combo.Conn
    end
  end
end
