defmodule Combo.TokenTest do
  use ExUnit.Case, async: true
  alias Combo.Token

  defstruct [:endpoint]

  defmodule Endpoint do
    def config(:secret_key_base), do: "xxxxxx"
  end

  defp conn() do
    %Plug.Conn{} |> Plug.Conn.put_private(:combo_endpoint, Endpoint)
  end

  defp socket() do
    %Combo.Socket{endpoint: Endpoint}
  end

  describe "sign and verify" do
    test "token with context as string" do
      id = 1
      key = String.duplicate("xxxxxx", 5)
      token = Token.sign(key, "salt", id)
      assert Token.verify(key, "salt", token) == {:ok, id}
    end

    test "token with context as conn" do
      id = 1
      token = Token.sign(conn(), "salt", id)
      assert Token.verify(conn(), "salt", token) == {:ok, id}
    end

    test "token with context as socket" do
      id = 1
      token = Token.sign(socket(), "salt", id)
      assert Token.verify(socket(), "salt", token) == {:ok, id}
    end

    test "token with context as endpoint" do
      id = 1
      token = Token.sign(Endpoint, "salt", id)
      assert Token.verify(Endpoint, "salt", token) == {:ok, id}
    end

    test "token with context which has endpoint field" do
      id = 1
      token = Token.sign(%__MODULE__{endpoint: Endpoint}, "salt", id)
      assert Token.verify(%__MODULE__{endpoint: Endpoint}, "salt", token) == {:ok, id}
    end

    test "fails on missing token" do
      assert Token.verify(Endpoint, "salt", nil) == {:error, :missing}
    end

    test "fails on invalid token" do
      token = Token.sign(Endpoint, "salt", 1)

      assert Token.verify(Endpoint, "salt", "garbage") ==
               {:error, :invalid}

      assert Token.verify(Endpoint, "not_salt", token) ==
               {:error, :invalid}
    end

    test "fails on expired token" do
      token = Token.sign(conn(), "salt", 1)
      assert Token.verify(conn(), "salt", token, max_age: 0.1) == {:ok, 1}
      :timer.sleep(150)
      assert Token.verify(conn(), "salt", token, max_age: 0.1) == {:error, :expired}
    end

    test "supports max age" do
      token = Token.sign(conn(), "salt", 1)
      assert Token.verify(conn(), "salt", token, max_age: 1000) == {:ok, 1}
      assert Token.verify(conn(), "salt", token, max_age: -1000) == {:error, :expired}
      assert Token.verify(conn(), "salt", token, max_age: 100) == {:ok, 1}
      assert Token.verify(conn(), "salt", token, max_age: -100) == {:error, :expired}
      assert Token.verify(conn(), "salt", token, max_age: 0) == {:error, :expired}
    end

    test "supports :infinity for max age" do
      token = Token.sign(conn(), "salt", 1)
      assert Token.verify(conn(), "salt", token, max_age: :infinity) == {:ok, 1}
    end

    test "supports signed_at" do
      seconds_in_day = 24 * 60 * 60
      day_ago_seconds = System.system_time(:second) - seconds_in_day
      token = Token.sign(conn(), "salt", 1, signed_at: day_ago_seconds)
      assert Token.verify(conn(), "salt", token, max_age: seconds_in_day + 1) == {:ok, 1}

      assert Token.verify(conn(), "salt", token, max_age: seconds_in_day - 1) ==
               {:error, :expired}
    end

    test "passes key_iterations options to key generator" do
      signed1 = Token.sign(conn(), "salt", 1, signed_at: 0, key_iterations: 1)
      signed2 = Token.sign(conn(), "salt", 1, signed_at: 0, key_iterations: 2)
      assert signed1 != signed2
    end

    test "passes key_digest options to key generator" do
      signed1 = Token.sign(conn(), "salt", 1, signed_at: 0, key_digest: :sha256)
      signed2 = Token.sign(conn(), "salt", 1, signed_at: 0, key_digest: :sha512)
      assert signed1 != signed2
    end

    test "key defaults" do
      signed1 = Token.sign(conn(), "salt", 1, signed_at: 0)

      signed2 =
        Token.sign(conn(), "salt", 1,
          signed_at: 0,
          key_length: 32,
          key_digest: :sha256,
          key_iterations: 1000
        )

      assert signed1 == signed2
    end
  end

  describe "encrypt and decrypt" do
    test "token with context as string" do
      id = 1
      key = String.duplicate("xxxxxx", 5)
      token = Token.encrypt(key, "salt", id)
      assert Token.decrypt(key, "salt", token) == {:ok, id}
    end

    test "token with context as conn" do
      id = 1
      token = Token.encrypt(conn(), "salt", id)
      assert Token.decrypt(conn(), "salt", token) == {:ok, id}
    end

    test "token with context as socket" do
      id = 1
      token = Token.encrypt(socket(), "salt", id)
      assert Token.decrypt(socket(), "salt", token) == {:ok, id}
    end

    test "token with context as endpoint" do
      id = 1
      token = Token.encrypt(Endpoint, "salt", id)
      assert Token.decrypt(Endpoint, "salt", token) == {:ok, id}
    end

    test "token with context which has endpoint field" do
      id = 1
      token = Token.encrypt(%__MODULE__{endpoint: Endpoint}, "salt", id)
      assert Token.decrypt(%__MODULE__{endpoint: Endpoint}, "salt", token) == {:ok, id}
    end

    test "fails on missing token" do
      assert Token.decrypt(Endpoint, "salt", nil) == {:error, :missing}
    end

    test "fails on invalid token" do
      token = Token.encrypt(Endpoint, "salt", 1)

      assert Token.decrypt(Endpoint, "salt", "garbage") ==
               {:error, :invalid}

      assert Token.decrypt(Endpoint, "not_salt", token) ==
               {:error, :invalid}
    end

    test "fails on expired token" do
      token = Token.encrypt(conn(), "salt", 1)
      assert Token.decrypt(conn(), "salt", token, max_age: 0.1) == {:ok, 1}
      :timer.sleep(150)
      assert Token.decrypt(conn(), "salt", token, max_age: 0.1) == {:error, :expired}
    end

    test "supports max age" do
      token = Token.encrypt(conn(), "salt", 1)
      assert Token.decrypt(conn(), "salt", token, max_age: 1000) == {:ok, 1}
      assert Token.decrypt(conn(), "salt", token, max_age: -1000) == {:error, :expired}
      assert Token.decrypt(conn(), "salt", token, max_age: 100) == {:ok, 1}
      assert Token.decrypt(conn(), "salt", token, max_age: -100) == {:error, :expired}
      assert Token.decrypt(conn(), "salt", token, max_age: 0) == {:error, :expired}
    end

    test "supports :infinity for max age" do
      token = Token.encrypt(conn(), "salt", 1)
      assert Token.decrypt(conn(), "salt", token, max_age: :infinity) == {:ok, 1}
    end

    test "supports signed_at" do
      seconds_in_day = 24 * 60 * 60
      day_ago_seconds = System.system_time(:second) - seconds_in_day
      token = Token.encrypt(conn(), "salt", 1, signed_at: day_ago_seconds)
      assert Token.decrypt(conn(), "salt", token, max_age: seconds_in_day + 1) == {:ok, 1}

      assert Token.decrypt(conn(), "salt", token, max_age: seconds_in_day - 1) ==
               {:error, :expired}
    end

    test "passes key_iterations options to key generator" do
      signed1 = Token.encrypt(conn(), "salt", 1, signed_at: 0, key_iterations: 1)
      signed2 = Token.encrypt(conn(), "salt", 1, signed_at: 0, key_iterations: 2)
      assert signed1 != signed2
    end

    test "passes key_digest options to key generator" do
      signed1 = Token.encrypt(conn(), "salt", 1, signed_at: 0, key_digest: :sha256)
      signed2 = Token.encrypt(conn(), "salt", 1, signed_at: 0, key_digest: :sha512)
      assert signed1 != signed2
    end
  end
end
