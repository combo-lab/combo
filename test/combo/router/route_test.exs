defmodule Combo.Router.RouteTest do
  use ExUnit.Case, async: true

  import Combo.Router.Route

  def init(opts), do: opts

  defmodule AdminRouter do
    def init(opts), do: opts
    def call(conn, _), do: Plug.Conn.assign(conn, :fwd_conn, conn)
  end

  test "builds a route based on verb, path, plug, plug options and helper" do
    route =
      build(
        1,
        :match,
        :get,
        "/foo/:bar",
        Hello,
        :world,
        "hello_world",
        [:foo, :bar],
        %{foo: "bar"},
        %{bar: "baz"},
        %{log: :debug}
      )

    assert route.kind == :match
    assert route.verb == :get
    assert route.path == "/foo/:bar"
    assert route.line == 1
    assert route.plug == Hello
    assert route.plug_opts == :world
    assert route.helper == "hello_world"
    assert route.pipe_through == [:foo, :bar]
    assert route.private == %{foo: "bar"}
    assert route.assigns == %{bar: "baz"}
    assert route.metadata == %{log: :debug}
  end

  test "builds expressions based on the route" do
    exprs =
      build(
        1,
        :match,
        :get,
        "/foo/:bar",
        Hello,
        :world,
        "hello_world",
        [],
        %{},
        %{},
        %{}
      )
      |> build_exprs()

    assert exprs.method_match == "GET"
    assert exprs.path_match == ["foo", {:bar, [], Combo.Router.Route}]
    assert exprs.binding == [{"bar", {:bar, [], Combo.Router.Route}}]
  end

  test "builds a catch-all verb for match routes" do
    route =
      build(
        1,
        :match,
        :*,
        "/foo/:bar",
        __MODULE__,
        :world,
        "hello_world",
        [:foo, :bar],
        %{foo: "bar"},
        %{bar: "baz"},
        %{}
      )

    assert route.verb == :*
    assert route.kind == :match
    assert build_exprs(route).method_match == {:_method, [], nil}
  end

  test "builds a catch-all verb for forwarded routes" do
    route =
      build(
        1,
        :forward,
        :*,
        "/foo",
        __MODULE__,
        :world,
        "hello_world",
        [:foo],
        %{foo: "bar"},
        %{bar: "baz"},
        %{forward: ~w(foo)}
      )

    assert route.verb == :*
    assert route.kind == :forward
    assert build_exprs(route).method_match == {:_method, [], nil}
  end
end
