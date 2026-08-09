defmodule Combo.Transport.Handler do
  @moduledoc """
  Outlines the Socket <-> Transport communication.

  Each transport, such as websockets and longpolling, must interact
  with a socket. This module defines the functions a transport will
  invoke on a given socket implementation.

  `Combo.Socket` is just one possible implementation of a socket
  that multiplexes events over multiple channels. If you implement
  this behaviour, then existing transports can use your new socket
  implementation, without passing through channels.

  ## Example

  Here is a simple echo socket implementation:

      defmodule EchoSocket do
        @behaviour Combo.Transport.Handler

        def child_spec(opts) do
          # We won't spawn any process, so let's ignore the child spec
          :ignore
        end

        def connect(state) do
          # Callback to retrieve relevant data from the connection.
          # The map contains options, params, transport and endpoint keys.
          {:ok, state}
        end

        def init(state) do
          # Now we are effectively inside the process that maintains the socket.
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

  It can be mounted in your endpoint like any other socket:

      socket "/socket", EchoSocket, websocket: true, longpoll: true

  You can now interact with the socket under `/socket/websocket`
  and `/socket/longpoll`.

  ## Custom transports

  Sockets are operated by a transport. When a transport is defined,
  it usually receives a socket module and the module will be invoked
  when certain events happen at the transport level. The functions
  a transport can invoke are the callbacks defined in this module.

  Whenever the transport receives a new connection, it should invoke
  the `c:connect/1` callback with a map of metadata. Different sockets
  may require different metadata.

  If the connection is accepted, the transport can move the connection
  to another process, if so desires, or keep using the same process. The
  process responsible for managing the socket should then call `c:init/1`.

  For each message received from the client, the transport must call
  `c:handle_in/2` on the socket. For each informational message the
  transport receives, it should call `c:handle_info/2` on the socket.

  Transports can optionally implement `c:handle_control/2` for handling
  control frames such as `:ping` and `:pong`.

  On termination, `c:terminate/2` must be called. A special atom with
  reason `:closed` can be used to specify that the client terminated
  the connection.

  ### Booting

  When you list a socket under `Combo.Endpoint.socket/3`, Combo
  will automatically start the socket module under its supervision tree,
  however Combo does not manage any transport.

  Whenever your endpoint starts, Combo invokes the `child_spec/1` on
  each listed socket and start that specification under the endpoint
  supervisor. Since the socket supervision tree is started by the endpoint,
  any custom transport must be started after the endpoint.
  """

  @type state :: term()

  @doc """
  Returns a child specification for socket management.

  This is invoked only once per socket regardless of
  the number of transports and should be responsible
  for setting up any process structure used exclusively
  by the socket regardless of transports.

  Each socket connection is started by the transport
  and the process that controls the socket likely
  belongs to the transport. However, some sockets spawn
  new processes, such as `Combo.Socket` which spawns
  channels, and this gives the ability to start a
  supervision tree associated to the socket.

  It receives the socket options from the endpoint,
  for example:

      socket "/my_app", MyApp.Socket, shutdown: 5000

  means `child_spec([shutdown: 5000])` will be invoked.

  `:ignore` means no child spec is necessary for this socket.
  """
  @callback child_spec(keyword) :: :supervisor.child_spec() | :ignore

  @doc """
  Returns a child specification for terminating the socket.

  This is a process that is started late in the supervision
  tree with the specific goal of draining connections on
  application shutdown.

  Similar to `child_spec/1`, it receives the socket options
  from the endpoint.
  """
  @callback drainer_spec(keyword) :: :supervisor.child_spec() | :ignore

  @doc """
  Connects to the socket.

  The transport passes a map of metadata and the socket
  returns `{:ok, state}`, `{:error, reason}` or `:error`.
  The state must be stored by the transport and returned
  in all future operations. When `{:error, reason}` is
  returned, some transports - such as WebSockets - allow
  customizing the response based on `reason` via a custom
  `:error_handler`.

  This function is used for authorization purposes and it
  may be invoked outside of the process that effectively
  runs the socket.

  In the default `Combo.Socket` implementation, the
  metadata expects the following keys:

    * `:endpoint` - the application endpoint
    * `:transport` - the transport name
    * `:params` - the connection parameters
    * `:options` - a keyword list of transport options, often
      given by developers when configuring the transport.
      It must include a `:serializer` field with the list of
      serializers and their requirements

  """
  @callback connect(transport_info :: map) :: {:ok, state} | {:error, term()} | :error

  @doc """
  Initializes the socket state.

  This must be executed from the process that will effectively
  operate the socket.
  """
  @callback init(state) :: {:ok, state}

  @doc """
  Handles incoming socket messages.

  The message is represented as `{payload, options}`. It must
  return one of:

    * `{:ok, state}` - continues the socket with no reply
    * `{:reply, status, reply, state}` - continues the socket with reply
    * `{:stop, reason, state}` - stops the socket

  The `reply` is a tuple contain an `opcode` atom and a message that can
  be any term. The built-in websocket transport supports both `:text` and
  `:binary` opcode and the message must be always iodata. Long polling only
  supports text opcode.
  """
  @callback handle_in({message :: term, opts :: keyword}, state) ::
              {:ok, state}
              | {:reply, :ok | :error, {opcode :: atom, message :: term}, state}
              | {:stop, reason :: term, state}

  @doc """
  Handles incoming control frames.

  The message is represented as `{payload, options}`. It must
  return one of:

    * `{:ok, state}` - continues the socket with no reply
    * `{:reply, status, reply, state}` - continues the socket with reply
    * `{:stop, reason, state}` - stops the socket

  Control frames are only supported when using websockets.

  The `options` contains an `opcode` key, this will be either `:ping` or
  `:pong`.

  If a control frame doesn't have a payload, then the payload value
  will be `nil`.
  """
  @callback handle_control({message :: term, opts :: keyword}, state) ::
              {:ok, state}
              | {:reply, :ok | :error, {opcode :: atom, message :: term}, state}
              | {:stop, reason :: term, state}

  @doc """
  Handles info messages.

  The message is a term. It must return one of:

    * `{:ok, state}` - continues the socket with no reply
    * `{:push, reply, state}` - continues the socket with reply
    * `{:stop, reason, state}` - stops the socket

  The `reply` is a tuple contain an `opcode` atom and a message that can
  be any term. The built-in websocket transport supports both `:text` and
  `:binary` opcode and the message must be always iodata. Long polling only
  supports text opcode.
  """
  @callback handle_info(message :: term, state) ::
              {:ok, state}
              | {:push, {opcode :: atom, message :: term}, state}
              | {:stop, reason :: term, state}

  @doc """
  Invoked on termination.

  If `reason` is `:closed`, it means the client closed the socket. This is
  considered a `:normal` exit signal, so linked process will not automatically
  exit. See `Process.exit/2` for more details on exit signals.
  """
  @callback terminate(reason :: term, state) :: :ok

  @optional_callbacks handle_control: 2, drainer_spec: 1
end
