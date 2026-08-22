defmodule Combo.Transport.Handler do
  @moduledoc """
  The transport handler behaviour.

  ## Terminology

  **Transport handler resources** are extra resources used by a transport
  handler, such as processes, or other infrastructure.

  **Transport handler state** is the per-session state returned by the
  transport handler and passed between its callbacks.

  **Transport messages** are units of data transferred through a transport
  session. They do not necessarily correspond to an underlying network frames
  or HTTP requests.

  **Transport session draining** is the process of gradually terminating
  established transport sessions during application shutdown or restart.

  ## Example

  Here is a simple echo handler:

      defmodule EchoHandler do
        @behaviour Combo.Transport.Handler

        def child_spec(opts) do
          :ignore
        end

        def connect(state) do
          {:ok, state}
        end

        def init(state) do
          {:ok, state}
        end

        def handle_in({text, _opts}, state) do
          {:reply, :ok, {:text, text}, state}
        end

        def handle_info(_, state) do
          {:ok, state}
        end

        def terminate(_reason, _state) do
          :ok
        end
      end

  """

  @type state :: term()

  @type message :: term()
  @type opcode :: atom()

  @type reason :: term()

  @doc """
  Returns a child specification for managing handler resources.

  Return `:ignore` if the transport handler requires no managed resources.
  """
  @callback child_spec(opts :: Keyword.t()) ::
              :supervisor.child_spec()
              | :ignore

  @doc """
  Returns a child specification for draining transport sessions.

  Return `:ignore` if the transport handler requires no session drainer.
  """
  @callback drainer_spec(opts :: Keyword.t()) ::
              :supervisor.child_spec()
              | :ignore

  @doc """
  Accepts or rejects to establish a transport session.

  This callback typically performs authorization and creates the initial
  transport handler state. It may run outside the process that will operate
  the established transport session.

  Return `{:ok, state}` to accept it, `{:error, reason}` to reject it with a
  reason, or `:error` to reject it without a reason.
  """
  @callback connect(metadata :: map()) ::
              {:ok, state()}
              | {:error, reason()}
              | :error

  @doc """
  Initializes the transport handler state for a established transport session.

  This callback runs in the process that handles the transport session.
  """
  @callback init(state()) :: {:ok, state()}

  @doc """
  Handles a transport message received during a transport session.

  The transport message is represented as `{payload, options}`.
  It must return one of:

    * `{:ok, state}` - continues the transport session without a reply.
    * `{:reply, status, reply, state}` - sends a reply and continues the transport session.
    * `{:stop, reason, state}` - terminates the transport session.

  The reply is an `{opcode, message}` tuple. The built-in WebSocket
  transport supports `:text` and `:binary` opcodes, and the message must
  be iodata. Long Poll supports only the `:text` opcode.
  """
  @callback handle_in({message(), opts :: Keyword.t()}, state()) ::
              {:ok, state()}
              | {:reply, :ok | :error, {opcode(), message()}, state()}
              | {:stop, reason(), state()}

  @doc """
  Handles a control frame received during a transport session.

  The control frame is represented as `{payload, options}`.
  It must return one of:

    * `{:ok, state}` - continues the transport session without a reply.
    * `{:reply, status, reply, state}` - sends a reply and continues the transport session.
    * `{:stop, reason, state}` - terminates the transport session.

  Control frames are supported only by WebSocket transports. The `:opcode`
  option is either `:ping` or `:pong`. The payload is `nil` when the frame
  has no payload.
  """
  @callback handle_control({message(), opts :: Keyword.t()}, state()) ::
              {:ok, state()}
              | {:reply, :ok | :error, {opcode(), message()}, state()}
              | {:stop, reason(), state()}

  @doc """
  Handles an Erlang message received during a transport session.

  It must return one of:

    * `{:ok, state}` - continues the transport session without a push.
    * `{:push, push, state}` - sends a push and continues the transport session.
    * `{:stop, reason, state}` - terminates the transport session.

  The push is an `{opcode, message}` tuple. The built-in WebSocket transport
  supports `:text` and `:binary` opcodes, and the message must be iodata. Long
  Poll supports only the `:text` opcode.
  """
  @callback handle_info(message(), state()) ::
              {:ok, state()}
              | {:push, {opcode(), message()}, state()}
              | {:stop, reason(), state()}

  @doc """
  Cleans up the transport handler state when a transport session terminates.

  If `reason` is `:closed`, the client closed the transport session. This is
  considered a `:normal` exit signal, so linked processes do not automatically
  exit. See `Process.exit/2` for more details on exit signals.
  """
  @callback terminate(reason(), state()) :: :ok

  @optional_callbacks drainer_spec: 1, handle_control: 2
end
