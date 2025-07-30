defmodule Phoenix.Template.CEExEngine.AssignsTest do
  use ExUnit.Case, async: true

  import Phoenix.Template.CEExEngine.Assigns

  @assigns %{k1: "v1"}

  describe "assign/3" do
    test "works" do
      assert assign(@assigns, :k1, "v1-new") == %{k1: "v1-new"}
      assert assign(@assigns, :k2, "v2") == %{k1: "v1", k2: "v2"}
    end

    test "raises error when the key is not an atom" do
      assert_raise ArgumentError, ~S|assigns' keys must be atoms, got: "k2"|, fn ->
        assign(@assigns, "k2", "v2")
      end
    end
  end

  describe "assign/2" do
    test "works" do
      assert assign(@assigns, k1: "v1-new", k2: "v2") == %{k1: "v1-new", k2: "v2"}
      assert assign(@assigns, %{k1: "v1-new", k2: "v2"}) == %{k1: "v1-new", k2: "v2"}
    end

    test "raises error when the key is not an atom" do
      assert_raise ArgumentError, ~S|assigns' keys must be atoms, got: "k2"|, fn ->
        assign(@assigns, %{"k2" => "v2"})
      end
    end
  end

  describe "assign_new/3" do
    test "works" do
      result =
        @assigns
        |> assign_new(:k1, fn -> "v1-new" end)
        |> assign_new(:k2, fn -> "v2" end)
        |> assign_new(:k3, fn assigns -> assigns.k2 end)

      assert result == %{k1: "v1", k2: "v2", k3: "v2"}
    end

    test "raises error when the key is not an atom" do
      assert_raise ArgumentError, ~S|assigns' keys must be atoms, got: "k2"|, fn ->
        assign_new(@assigns, "k2", fn -> "v2" end)
      end
    end
  end

  test "assigns_to_attrs/2" do
    assert assigns_to_attrs(%{}) == []
    assert assigns_to_attrs(%{}, [:non_exists]) == []
    assert assigns_to_attrs(%{one: 1, two: 2}) == [one: 1, two: 2]
    assert assigns_to_attrs(%{one: 1, two: 2}, [:one]) == [two: 2]
    assert assigns_to_attrs(%{one: 1, two: 2}, [:one]) == [two: 2]
    assert assigns_to_attrs(%{inner_block: fn -> :ok end, a: 1}) == [a: 1]
    assert assigns_to_attrs(%{__slot__: :foo, inner_block: fn -> :ok end, a: 1}) == [a: 1]
  end
end
