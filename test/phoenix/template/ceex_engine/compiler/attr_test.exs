# Typically, we don't test such low-level implementations, but for this
# type of code, testing at here is the most convenient.
#
# And, we only test whether right quoted expressions are generated.
# The results of evaluating the quoted expressions will be tested by
# upper-level tests.
defmodule Phoenix.Template.CEExEngine.Compiler.AttrTest do
  use ExUnit.Case, async: true

  alias Phoenix.Template.CEExEngine.Compiler.Attr

  defp handle_attr(pattern) do
    Attr.handle_attr(pattern, line: 1)
  end

  describe "local - optimizes string concatenation using <>" do
    test ~S'like "static1" <> "static2"' do
      assert {:attr, "class", ["static1", "static2"]} =
               handle_attr({:local, "class", quote(do: "static1" <> "static2")})

      assert {:attr, "class", ["static1", "static2", "static3"]} =
               handle_attr({:local, "class", quote(do: "static1" <> "static2" <> "static3")})
    end

    test ~S'like "static1" <> dynamic1' do
      assert {:attr, "class",
              [
                "static1",
                {:safe,
                 {{:., [line: 1], [_module, :escape_binary_value]}, [line: 1],
                  [{:dynamic1, [], __MODULE__}]}}
              ]} = handle_attr({:local, "class", quote(do: "static1" <> dynamic1)})

      assert {:attr, "class",
              [
                "static1",
                {:safe,
                 {{:., [line: 1], [_module, :escape_binary_value]}, [line: 1],
                  [{:dynamic1, [], __MODULE__}]}},
                "static2"
              ]} = handle_attr({:local, "class", quote(do: "static1" <> dynamic1 <> "static2")})
    end
  end

  describe "local - optimizes string concatenation using binary syntax" do
    test ~S'like <<"static1", "static2">>' do
      assert {:attr, "class", ["static1", "static2"]} =
               handle_attr({:local, "class", quote(do: <<"static1", "static2">>)})

      assert {:attr, "class", ["static1", "static2", "static3"]} =
               handle_attr({:local, "class", quote(do: <<"static1", "static2", "static3">>)})
    end

    test ~S'like <<"static1", dynamic::binary>>' do
      assert {:attr, "class",
              [
                "static1",
                {:safe,
                 {{:., [line: 1], [_module, :escape_binary_value]}, [line: 1],
                  [{:dynamic1, [], __MODULE__}]}}
              ]} =
               handle_attr({:local, "class", quote(do: <<"static1", dynamic1::binary>>)})

      assert {:attr, "class",
              [
                "static1",
                {:safe,
                 {{:., [line: 1], [_module, :escape_binary_value]}, [line: 1],
                  [{:dynamic1, [], __MODULE__}]}},
                "static2"
              ]} =
               handle_attr(
                 {:local, "class", quote(do: <<"static1", dynamic1::binary, "static2">>)}
               )
    end
  end

  describe "local - does't optimize other cases" do
    test "lists without binary as the first element" do
      assert {:quoted,
              {:safe,
               {{:., [line: 1], [_module, :escape_attrs]}, [line: 1],
                [
                  [
                    {"class",
                     [
                       {:dynamic, [], __MODULE__},
                       "static1",
                       "static2",
                       "static3"
                     ]}
                  ]
                ]}}} =
               handle_attr(
                 {:local, "class", quote(do: [dynamic, "static1", "static2", "static3"])}
               )

      assert {:quoted,
              {:safe,
               {{:., [line: 1], [_module, :escape_attrs]}, [line: 1],
                [
                  [
                    {"class", []}
                  ]
                ]}}} =
               handle_attr({:local, "class", quote(do: [])})
    end

    test "other values, like integers, atoms, etc" do
      assert {:quoted,
              {:safe, {{:., [line: 1], [_module, :escape_attrs]}, [line: 1], [[{"class", 1024}]]}}} =
               handle_attr({:local, "class", quote(do: 1024)})

      assert {:quoted,
              {:safe,
               {{:., [line: 1], [_module, :escape_attrs]}, [line: 1], [[{"class", :hello}]]}}} =
               handle_attr({:local, "class", quote(do: :hello)})
    end
  end

  test "global - doesn't optimize at all" do
    assert {:quoted,
            {:safe, {{:., [line: 1], [_module, :escape_attrs]}, [line: 1], [{:%{}, [], []}]}}} =
             handle_attr({:global, quote(do: %{})})
  end
end
