defmodule Combo.SafeHTMLTest do
  use ExUnit.Case, async: true

  import Combo.SafeHTML
  doctest Combo.SafeHTML

  describe "escape/1" do
    test "escapes entities" do
      assert escape("foo") == "foo"
      assert escape("<foo>") == [[[] | "&lt;"], "foo" | "&gt;"]
      assert escape("\" & \'") == [[[[] | "&quot;"], " " | "&amp;"], " " | "&#39;"]
    end
  end

  describe "escape_attrs/1" do
    test "key as atom" do
      assert escape_attrs([{:title, "the title"}]) |> IO.iodata_to_binary() ==
               ~s( title="the title")
    end

    test "key as string" do
      assert escape_attrs([{"title", "the title"}]) |> IO.iodata_to_binary() ==
               ~s( title="the title")
    end

    test "keep the case style of keys unchanged" do
      assert escape_attrs([{:my_attr, "value"}]) |> IO.iodata_to_binary() == ~s( my_attr="value")
      assert escape_attrs([{"my_attr", "value"}]) |> IO.iodata_to_binary() == ~s( my_attr="value")

      assert escape_attrs([{:"my-attr", "value"}]) |> IO.iodata_to_binary() ==
               ~s( my-attr="value")

      assert escape_attrs([{"my-attr", "value"}]) |> IO.iodata_to_binary() ==
               ~s( my-attr="value")
    end

    test "value as string" do
      assert escape_attrs([{:class, "btn"}]) |> IO.iodata_to_binary() == ~s( class="btn")

      assert escape_attrs([{:class, "<active>"}]) |> IO.iodata_to_binary() ==
               ~s( class="&lt;active&gt;")
    end

    test "suppress value when value is true" do
      assert escape_attrs([{"required", true}]) |> IO.iodata_to_binary() == ~s( required)
      assert escape_attrs([{"selected", true}]) |> IO.iodata_to_binary() == ~s( selected)
    end

    test "suppress attribute when value is falsy" do
      assert escape_attrs([{"title", nil}]) |> IO.iodata_to_binary() == ~s()
      assert escape_attrs([{"title", false}]) |> IO.iodata_to_binary() == ~s()
    end

    test "multiple attributes" do
      assert escape_attrs([{:title, "the title"}, {:id, "the id"}]) |> IO.iodata_to_binary() ==
               ~s( title="the title" id="the id")
    end
  end
end
