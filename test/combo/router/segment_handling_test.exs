defmodule DummyController do
  def init(opts), do: opts
  def call(conn, _opts), do: conn
end

defmodule Combo.Router.SegmentHandlingTest do
  use ExUnit.Case, async: true
  use Support.RouterHelper

  defmodule Router do
    use Combo.Router

    # pipeline "some" do
    # end

    scope "/" do
      # pipe_through [:api]

      get "/:param1", DummyController, :a
    end

    #   # P(3, 1)
    #   # A
    #   get "/:param1", DummyController, :a
    #   get "/prefix/:param1", DummyController, :a1
    #   # B
    #   get "/prefix-:param1", DummyController, :b
    #   get "/prefix/prefix-:param1", DummyController, :b1
    #   # C
    #   get "/*param1", DummyController, :c
    #   get "/prefix/*param1", DummyController, :c1

    #   # P(3, 2)
    #   # AB
    #   get "/:param1/prefix-:param2", DummyController, :ab
    #   # AC
    #   get "/:param1/*param2", DummyController, :ac
    #   # BA
    #   get "/prefix-:param1/:param2", DummyController, :ba
    #   # BC
    #   get "/prefix-:param1/*param2", DummyController, :bc
    #   # CA
    #   # not supported
    #   # CB
    #   # not supported

    #   # P(3, 3)
    #   # ABC
    #   get "/:param1/prefix-:param2/*param3", DummyController, :abc
    #   # ACB
    #   # not supported
    #   # BAC
    #   get "/prefix-:param1/:param2/*param3", DummyController, :bac
    #   # BCA
    #   # not supported
    #   # CAB
    #   # not supported
    #   # CBA
    #   # not supported
    # end
  end
end
