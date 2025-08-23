defmodule Combo.Token do
  @moduledoc """
  Conveniences to sign/encrypt data inside tokens for use in API authentication
  , Channel authentication, and more.

  The data stored in the token is signed to prevent tampering, and is
  optionally encrypted. This means that, so long as the key (see below) remains
  secret, you can be assured that the data stored in the token has not been
  tampered with by a third party.

  However, unless the token is encrypted, it is not safe to use this token to
  store private information, such as a user's sensitive identification data,
  as it can be trivially decoded. If the token is encrypted, its contents will
  be kept secret from the client, but it is still a best practice to encode as
  little secret information as possible, to minimize the impact of key leakage.

  ## Examples

  When generating a unique token for use in an API or Channel it is advised to
  use a unique identifier for the user, typically the id from a database.
  For example:

      iex> context = Demo.Web.Endpoint
      iex> namespace = "user auth"
      iex> user_id = 1
      iex> token = Combo.Token.sign(context, namespace, user_id)
      iex> Combo.Token.verify(context, namespace, token)
      {:ok, 1}

  In that example we have a user's id, we generate a token and verify it using
  the secret key base configured in the given `endpoint`. We guarantee the
  token will only be valid for one day by setting a max age (recommended).

  The first argument to `sign/4`, `verify/4`, `encrypt/4`, and `decrypt/4` is
  called context, and it can be one of:

    * a string - the secret key base itself. A key base with at least 20
      randomly generated characters should be used to provide adequate entropy.
    * the module name of an endpoint - the secret key base is extracted from
      the endpoint.
    * `%Plug.Conn{}` - the secret key base is extracted from the endpoint stored
      in the connection.
    * `%Combo.Socket{}` - the secret key base is extracted from the endpoint
      stored in the socket.

  The second argument is a [cryptographic salt](https://en.wikipedia.org/wiki/Salt_(cryptography))
  which must be the same in both calls to `sign/4` and `verify/4`, or both
  calls to `encrypt/4` and `decrypt/4`. For instance, it may be called
  "user auth" and treated as namespace when generating a token that will be
  used to authenticate users on channels or on your APIs.

  The third argument can be any term that you wish to codify into the token.
  Upon valid verification, this same term will be extracted from the token.

  ## Usage

  Once a token is signed, we can send it to the client in multiple ways.

  One is via the meta tag:

  ```ceex
  <meta name="channel_token" content={Combo.Token.sign(@conn, "user auth", @current_user.id)}>
  ```

  Or an endpoint that returns it:

      def create(conn, params) do
        user = User.create(params)
        render(conn, "user.json", %{
          token: Combo.Token.sign(conn, "user auth", user.id),
          user: user
        })
      end

  Once the token is sent, the client may now send it back to the server as an
  authentication mechanism. For example, we can use it to authenticate a user
  on a channel:

      defmodule Demo.Web.UserSocket do
        use Combo.Socket

        def connect(%{"token" => token}, socket, _connect_info) do
          case Combo.Token.verify(socket, "user auth", token) do
            {:ok, user_id} ->
              socket = assign(socket, :user, Repo.get!(User, user_id))
              {:ok, socket}
            {:error, _} ->
              :error
          end
        end

        def connect(_params, _socket, _connect_info), do: :error
      end

  In this example, the client JavaScript code will send the token in the
  `connect` command which is then validated by the server.

  `Combo.Token` can also be used for validating APIs, handling password resets,
  e-mail confirmation and more.
  """

  require Logger
  import Combo.Conn, only: [endpoint_module!: 1]

  @type context ::
          binary()
          | module()
          | Plug.Conn.t()
          | Phoenix.Socket.t()

  @type salt :: binary()

  @type data :: term()

  @type token :: binary()

  @type shared_opt ::
          {:key_iterations, pos_integer()}
          | {:key_length, pos_integer()}
          | {:key_digest, :sha256 | :sha384 | :sha512}

  @type max_age_opt :: {:max_age, pos_integer() | :infinity}
  @type signed_at_opt :: {:signed_at, pos_integer()}

  @doc """
  Encodes and signs data into a token you can send to clients.

  ## Options

    * `:key_iterations` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 1000
    * `:key_length` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 32
    * `:key_digest` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to `:sha256`
    * `:signed_at` - the timestamp of the token in seconds. Defaults to
      `System.os_time(:second)`
    * `:max_age` - the default maximum age of the token in seconds. Defaults to
      `86400` and it may be overridden on `verify/4`.

  """
  @spec sign(context(), salt(), data(), [shared_opt() | max_age_opt() | signed_at_opt()]) ::
          token()
  def sign(context, salt, data, opts \\ []) when is_binary(salt) do
    context
    |> get_key_base()
    |> Plug.Crypto.sign(salt, data, opts)
  end

  @doc """
  Encodes, encrypts, and signs data into a token you can send to
  clients. Its usage is identical to that of `sign/4`, but the data
  is extracted using `decrypt/4`, rather than `verify/4`.

  ## Options

    * `:key_iterations` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 1000
    * `:key_length` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 32
    * `:key_digest` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to `:sha256`
    * `:signed_at` - set the timestamp of the token in seconds. Defaults to
      `System.os_time(:second)`
    * `:max_age` - the default maximum age of the token in seconds. Defaults to
      `86400` and it may be overridden on `decrypt/4`.

  """
  @spec encrypt(context(), salt(), data(), [shared_opt() | max_age_opt() | signed_at_opt()]) ::
          token()
  def encrypt(context, salt, data, opts \\ []) when is_binary(salt) do
    context
    |> get_key_base()
    |> Plug.Crypto.encrypt(salt, data, opts)
  end

  @doc """
  Decodes the original data from the token and verifies its integrity.

  ## Examples

  In this scenario we will create a token, sign it, then provide it to a client
  . The client will then use this token to authenticate requests for resources
  from the server. See `Combo.Token` summary for more info about creating tokens.

      iex> secret     = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
      iex> namespace  = "user auth"
      iex> user_id    = 99
      iex> token      = Combo.Token.sign(secret, namespace, user_id)

  The mechanism for passing the token to the client is typically through a
  cookie, a JSON response body, or HTTP header. For now, assume the client has
  received a token it can use to validate requests for protected resources.

  When the server receives a request, it can use `verify/4` to determine if it
  should provide the requested resources to the client:

      iex> Combo.Token.verify(secret, namespace, token)
      {:ok, 99}

  In this example, we know the client sent a valid token because `verify/4`
  returned a tuple of type `{:ok, user_id}`. The server can now proceed with
  the request.

  However, if the client had sent an expired token, an invalid token, or `nil`,
  `verify/4` would have returned an error instead:

      iex> Combo.Token.verify(secret, namespace, expired)
      {:error, :expired}

      iex> Combo.Token.verify(secret, namespace, invalid)
      {:error, :invalid}

      iex> Combo.Token.verify(secret, namespace, nil)
      {:error, :missing}

  ## Options

    * `:key_iterations` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 1000
    * `:key_length` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 32
    * `:key_digest` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to `:sha256`
    * `:max_age` - verifies the token only if it has been generated
      "max age" ago in seconds. Defaults to the max age signed in the
      token by `sign/4`.

  """
  @spec verify(context(), salt(), token(), [shared_opt() | max_age_opt()]) ::
          {:ok, data()} | {:error, :expired | :invalid | :missing}
  def verify(context, salt, token, opts \\ []) when is_binary(salt) do
    context
    |> get_key_base()
    |> Plug.Crypto.verify(salt, token, opts)
  end

  @doc """
  Decrypts the original data from the token and verifies its integrity.

  Its usage is identical to `verify/4` but for encrypted tokens.

  ## Options

    * `:key_iterations` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 1000
    * `:key_length` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 32
    * `:key_digest` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to `:sha256`
    * `:max_age` - verifies the token only if it has been generated
      "max age" ago in seconds. Defaults to the max age signed in the
      token by `encrypt/4`.

  """
  @spec decrypt(context(), salt(), token(), [shared_opt() | max_age_opt()]) ::
          {:ok, data()} | {:error, :expired | :invalid | :missing}
  def decrypt(context, salt, token, opts \\ []) when is_binary(salt) do
    context
    |> get_key_base()
    |> Plug.Crypto.decrypt(salt, token, opts)
  end

  defp get_key_base(string) when is_binary(string) and byte_size(string) >= 20,
    do: string

  defp get_key_base(endpoint) when is_atom(endpoint),
    do: get_endpoint_key_base(endpoint)

  defp get_key_base(%Plug.Conn{} = conn),
    do: get_endpoint_key_base(endpoint_module!(conn))

  defp get_key_base(%Combo.Socket{} = socket),
    do: get_endpoint_key_base(socket.endpoint)

  defp get_endpoint_key_base(endpoint) do
    endpoint.config(:secret_key_base) ||
      raise """
      no :secret_key_base configuration found in #{inspect(endpoint)}.
      Ensure that it is added into your endpoint configuration. For example:

          config :demo, Demo.Web.Endpoint,
            secret_key_base: ...
      """
  end
end
