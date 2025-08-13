defmodule Combo.TemplateTest do
  use ExUnit.Case, async: true

  doctest Combo.Template
  require Combo.Template, as: Template
  import Combo.SafeHTML, only: [safe_to_string: 1]

  @templates Path.expand("../fixtures/templates", __DIR__)

  test "engines/0" do
    assert is_map(Template.engines())
  end

  test "format_encoders/0" do
    assert is_map(Template.format_encoders())
  end

  test "format_encoder/1 returns the format encoder for a given format" do
    assert Template.format_encoder("html") == Combo.Template.HTMLEncoder
    assert Template.format_encoder("js") == Combo.Template.HTMLEncoder
    assert Template.format_encoder("unknown") == nil
  end

  test "find_all/3 finds all templates in the given root" do
    templates = Template.find_all(@templates)
    assert Path.join(@templates, "show.html.ceex") in templates

    templates = Template.find_all(Path.expand("unknown"))
    assert templates == []
  end

  test "hash/3 returns the hash for the given root" do
    assert is_binary(Template.hash(@templates))
  end

  describe "embed_templates/2" do
    defmodule EmbedTemplates do
      import Combo.Template, only: [embed_templates: 1, embed_templates: 2]

      embed_templates("../fixtures/templates/*.html")
      embed_templates("../fixtures/templates/*.json", suffix: "_json")
    end

    test "embeds templates" do
      assert EmbedTemplates.show(%{message: "hello"}) ==
               {:safe, ["<div", ">", "Show! ", "hello", "</div>", "\n"]}

      assert EmbedTemplates.trim(%{}) ==
               {:safe, ["12", "\n  ", "34", "\n", "56"]}
    end

    test "embeds templates with suffix" do
      assert EmbedTemplates.show_json(%{}) == %{foo: "bar"}
    end
  end

  describe "compile_all/4" do
    defmodule AllTemplates do
      Template.compile_all(
        &(&1 |> Path.basename() |> String.replace(".", "_")),
        Path.expand("../fixtures/templates", __DIR__)
      )
    end

    test "compiles all templates at once" do
      assert AllTemplates.show_html_ceex(%{message: "hello!"})
             |> safe_to_string() ==
               "<div>Show! hello!</div>\n"

      assert AllTemplates.show_html_ceex(%{message: "<hello>"})
             |> safe_to_string() ==
               "<div>Show! &lt;hello&gt;</div>\n"

      assert AllTemplates.show_html_ceex(%{message: {:safe, "<hello>"}})
             |> safe_to_string() ==
               "<div>Show! <hello></div>\n"

      assert AllTemplates.show_json_exs(%{}) == %{foo: "bar"}
      assert AllTemplates.show_text_eex(%{message: "hello"}) == "from hello"
      refute AllTemplates.__mix_recompile__?()
    end

    test "trims only HTML templates" do
      assert AllTemplates.trim_html_ceex(%{}) |> safe_to_string() == "12\n  34\n56"
      assert AllTemplates.trim_text_eex(%{}) == "12\n  34\n56\n"
    end

    defmodule OptionsTemplates do
      [{"show1html1ceex", _} | _] =
        Template.compile_all(
          &(&1 |> Path.basename() |> String.replace(".", "1")),
          Path.expand("../fixtures/templates", __DIR__),
          "*.html"
        )

      [{"show2json2exs", _}] =
        Template.compile_all(
          &(&1 |> Path.basename() |> String.replace(".", "2")),
          Path.expand("../fixtures/templates", __DIR__),
          "*.json"
        )

      [{"show3html3foo", _}] =
        Template.compile_all(
          &(&1 |> Path.basename() |> String.replace(".", "3")),
          Path.expand("../fixtures/templates", __DIR__),
          "*",
          %{foo: Combo.Template.EExEngine}
        )
    end

    test "compiles templates across several calls" do
      assert OptionsTemplates.show1html1ceex(%{message: "hello!"})
             |> safe_to_string() ==
               "<div>Show! hello!</div>\n"

      assert OptionsTemplates.show2json2exs(%{}) == %{foo: "bar"}

      assert OptionsTemplates.show3html3foo(%{message: "hello"}) == "from hello"

      refute OptionsTemplates.__mix_recompile__?()
    end

    test "render/4" do
      assigns = %{message: "hello!"}

      assert Template.render(AllTemplates, "show_html_ceex", "html", assigns)
             |> safe_to_string() ==
               "<div>Show! hello!</div>\n"
    end

    test "render_to_iodata/4" do
      assigns = %{message: "hello!"}

      assert Template.render_to_iodata(AllTemplates, "show_html_ceex", "html", assigns) ==
               ["<div", ">", "Show! ", "hello!", "</div>", "\n"]
    end

    test "render_to_string/4" do
      assert Template.render_to_string(AllTemplates, "show_html_ceex", "html", %{
               message: "hello!"
             }) ==
               "<div>Show! hello!</div>\n"
    end
  end
end
