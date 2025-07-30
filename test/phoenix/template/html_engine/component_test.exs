defmodule Phoenix.Template.CEExEngine.ComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.Template.CEExEngine.Component

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

  test "assigns_to_attributes/2" do
    assert assigns_to_attributes(%{}) == []
    assert assigns_to_attributes(%{}, [:non_exists]) == []
    assert assigns_to_attributes(%{one: 1, two: 2}) == [one: 1, two: 2]
    assert assigns_to_attributes(%{one: 1, two: 2}, [:one]) == [two: 2]
    assert assigns_to_attributes(%{one: 1, two: 2}, [:one]) == [two: 2]
    assert assigns_to_attributes(%{inner_block: fn -> :ok end, a: 1}) == [a: 1]
    assert assigns_to_attributes(%{__slot__: :foo, inner_block: fn -> :ok end, a: 1}) == [a: 1]
  end

  describe "to_form/2" do
    test "with a map" do
      form = to_form(%{})
      assert form.name == nil
      assert form.id == nil

      form = to_form(%{}, as: :foo)
      assert form.name == "foo"
      assert form.id == "foo"

      form = to_form(%{}, as: :foo, id: "bar")
      assert form.name == "foo"
      assert form.id == "bar"

      form = to_form(%{}, custom: "attr")
      assert form.options == [custom: "attr"]

      form = to_form(%{}, errors: [name: "can't be blank"])
      assert form.errors == [name: "can't be blank"]
    end

    test "with a form" do
      base = to_form(%{}, as: "name", id: "id")
      assert to_form(base, []) == base

      form = to_form(base, as: :foo)
      assert form.name == "foo"
      assert form.id == "foo"

      form = to_form(base, id: "bar")
      assert form.name == "name"
      assert form.id == "bar"

      form = to_form(base, as: :foo, id: "bar")
      assert form.name == "foo"
      assert form.id == "bar"

      form = to_form(base, as: nil, id: nil)
      assert form.name == nil
      assert form.id == nil

      form = to_form(base, custom: "attr")
      assert form.options[:custom] == "attr"

      form = to_form(base, errors: [name: "can't be blank"])
      assert form.errors == [name: "can't be blank"]

      form = to_form(base, action: :validate)
      assert form.action == :validate

      form = to_form(%{base | action: :validate})
      assert form.action == :validate
    end
  end
end
