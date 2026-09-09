defmodule Combo.Endpoint.Compilers.Debugger do
  @moduledoc false

  @behaviour Combo.Endpoint.Compiler

  alias Combo.Router.NoRouteError

  @impl true
  def install do
    quote location: :keep do
      if var!(debug_errors?) do
        use Plug.Debugger,
          otp_app: @otp_app,
          banner: {unquote(__MODULE__), :__banner__, []},
          style: [
            primary: "#D00000",
            logo: nil,
            dark: [
              primary: "#FF5F59",
              logo: nil
            ]
          ]
      end
    end
  end

  @doc false
  def __banner__(_conn, _status, _kind, %NoRouteError{router: router}, _stack) do
    """
    <h3>Available routes</h3>
    <pre>#{Combo.Router.ConsoleFormatter.format(router)}</pre>
    """
  end

  def __banner__(_conn, _status, _kind, _reason, _stack), do: nil
end
