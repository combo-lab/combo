defmodule Phoenix.EnvTest do
  use ExUnit.Case

  alias Phoenix.Env

  @app :phoenix

  test "get_all_env/1" do
    ns = :ga1

    assert [] == Env.get_all_env(ns)
    Application.put_env(@app, ns, k1: "v1", k2: "v2")
    assert [k1: "v1", k2: "v2"] == Env.get_all_env(ns)

    on_exit(fn -> Application.delete_env(@app, ns) end)
  end

  describe "get_env/_" do
    test "gets default value" do
      ns = :g1

      assert nil == Env.get_env(ns, :k1)
      assert "default" == Env.get_env(ns, :k1, "default")

      on_exit(fn -> Application.delete_env(@app, ns) end)
    end

    test "gets value" do
      ns = :g2

      Application.put_env(@app, ns, k1: "v1", k2: "v2")
      assert "v1" == Env.get_env(ns, :k1)
      assert "v2" == Env.get_env(ns, :k2)

      on_exit(fn -> Application.delete_env(@app, ns) end)
    end
  end

  describe "put_env/3" do
    test "puts kv pair" do
      ns = :p1

      Env.put_env(ns, :k1, "v1")
      assert [k1: "v1"] == Application.get_env(@app, ns)

      on_exit(fn -> Application.delete_env(@app, ns) end)
    end

    test "puts multiple kv pairs" do
      ns = :p2

      Env.put_env(ns, :k1, "v1")
      Env.put_env(ns, :k2, "v2")
      assert [k1: "v1", k2: "v2"] == Application.get_env(@app, ns)

      on_exit(fn -> Application.delete_env(@app, ns) end)
    end
  end
end
