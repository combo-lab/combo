defmodule Combo.URLParamTest do
  use ExUnit.Case, async: true

  import Combo.URLParam

  test "to_param for integers" do
    assert to_param(1) == "1"
  end

  test "to_param for floats" do
    assert to_param(3.14) == "3.14"
  end

  test "to_param for binaries" do
    assert to_param("foo") == "foo"
  end

  test "to_param for atoms" do
    assert to_param(:foo) == "foo"
    assert to_param(true) == "true"
    assert to_param(false) == "false"
    assert_raise ArgumentError, fn -> to_param(nil) end
  end

  test "to_param for maps" do
    assert_raise ArgumentError, fn -> to_param(%{id: 1}) end
  end

  test "to_param for structs" do
    defmodule Foo do
      defstruct [:id]
    end
    assert to_param(struct(Foo, id: 1)) == "1"
    assert to_param(struct(Foo, id: "foo")) == "foo"
  after
    :code.purge(__MODULE__.Foo)
    :code.delete(__MODULE__.Foo)
  end

  test "to_param for derivable structs without id" do
    msg = ~r"cannot derive Combo.URLParam for struct Combo.URLParamTest.Bar"
    assert_raise ArgumentError, msg, fn ->
      defmodule Bar do
        @derive Combo.URLParam
        defstruct [:uuid]
      end
    end

    defmodule Bar do
      @derive {Combo.URLParam, key: :uuid}
      defstruct [:uuid]
    end

    assert to_param(struct(Bar, uuid: 1)) == "1"
    assert to_param(struct(Bar, uuid: "foo")) == "foo"

    msg = ~r"cannot convert Combo.URLParamTest.Bar to param, key :uuid contains a nil value"
    assert_raise ArgumentError, msg, fn ->
      to_param(struct(Bar, uuid: nil))
    end
  after
    :code.purge(Module.concat(Combo.URLParam, __MODULE__.Bar))
    :code.delete(Module.concat(Combo.URLParam, __MODULE__.Bar))
    :code.purge(__MODULE__.Bar)
    :code.delete(__MODULE__.Bar)
  end
end
