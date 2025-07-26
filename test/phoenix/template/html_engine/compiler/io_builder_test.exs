defmodule Phoenix.Template.HTMLEngine.Compiler.IOBuilderTest do
  use ExUnit.Case, async: true

  alias Phoenix.Template.HTMLEngine.Compiler.IOBuilder

  defmodule Engine do
    @moduledoc false

    @behaviour EEx.Engine

    @impl true
    def init(_opts) do
      IOBuilder.init()
    end

    @impl true
    def handle_text(state, _meta, text) do
      IOBuilder.acc_text(state, text)
    end

    @impl true
    def handle_expr(state, marker, expr) do
      IOBuilder.acc_expr(state, marker, expr)
    end

    @impl true
    def handle_begin(state) do
      IOBuilder.reset(state)
    end

    @impl true
    def handle_end(state) do
      IOBuilder.dump(state)
    end

    @impl true
    def handle_body(state) do
      IOBuilder.dump(state)
    end
  end

  defp render(string, binding \\ []) do
    string
    |> EEx.eval_string(binding,
      engine: Engine,
      file: __ENV__.file
    )
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  describe "rendering" do
    test "doesn't escape safe expressions" do
      template = """
      <start> <%= {:safe, "<end>"} %>
      """

      assert render(template) == "<start> <end>\n"
    end

    test "escapes unsafe expressions" do
      template = """
      <start> <%= "<end>" %>
      """

      assert render(template) == "<start> &lt;end&gt;\n"
    end

    test "supports non-output expressions" do
      template = """
      <% v = "<hello>" %>
      <%= v %>
      """

      assert render(template) == "\n&lt;hello&gt;\n"
    end

    test "user-defined variables named v* doesn't effect the generated variables named v*" do
      template = """
      <% v0 = 0 %>
      <%= for i <- 1..3 do %><%= i %><%= v0 %><% end %>
      """

      # The compiled template will be:
      #
      #     v0 = 0
      #
      #     v2 =
      #       Phoenix.Template.HTMLEngine.IOBuilder.to_iodata(
      #         for i <- 1..3 do
      #           v0 = Phoenix.Template.HTMLEngine.Compiler.IOBuilder.to_safe(i)
      #           v1 = Phoenix.Template.HTMLEngine.Compiler.IOBuilder.to_safe(v0)
      #           {:safe, [v0, v1]}
      #         end
      #       )
      #
      #     {:safe, ["\n", v2, "\n"]}
      #
      # If the code above is executed in the usual way, it will returns
      #
      #     {:safe, ["\n", "112233", "\n"]}
      #
      # But, that's not what we expected.
      # We want the inner v0 doesn't effect outer v0.
      #
      # Anyway, Elixir handles it as we expected.
      assert render(template) == "\n102030\n"
    end
  end
end
