defmodule Combo.NotAcceptableError do
  @moduledoc """
  Raised when one of the `accept*` headers is not accepted by the server.

  This exception is commonly raised by `Combo.Conn.accepts/2` which negotiates
  the media types the server is able to serve with the contents the client is
  able to render.

  If you are seeing this error, you should check if you are listing the desired
  formats in your `:accepts` plug or if you are setting the proper accept
  header in the client. The exception contains the acceptable mime types in the
  `accepts` field.
  """

  defexception message: nil, accepts: [], plug_status: 406
end

defmodule Combo.ActionClauseError do
  exception_keys =
    FunctionClauseError.__struct__()
    |> Map.keys()
    |> Kernel.--([:__exception__, :__struct__])

  defexception exception_keys

  @impl true
  def message(exception) do
    exception
    |> Map.put(:__struct__, FunctionClauseError)
    |> FunctionClauseError.message()
  end

  @impl true
  def blame(exception, stacktrace) do
    {exception, stacktrace} =
      exception
      |> Map.put(:__struct__, FunctionClauseError)
      |> FunctionClauseError.blame(stacktrace)

    exception = Map.put(exception, :__struct__, __MODULE__)

    {exception, stacktrace}
  end
end

defimpl Plug.Exception, for: Combo.ActionClauseError do
  def status(_), do: 400
  def actions(_), do: []
end
