defmodule Phoenix.Template.CEExEngine.ComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.Template.CEExEngine.Component


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
