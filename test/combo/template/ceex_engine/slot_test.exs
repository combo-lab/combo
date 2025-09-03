defmodule Combo.Template.CEExEngine.SlotTest do
  use ExUnit.Case, async: true

  import Combo.Template.CEExEngine.Sigil
  import Combo.Template.CEExEngine.Slot
  import ComboTest.Template.CEExEngine.Helper

  def implicit_entries_render(assigns) do
    ~CE"""
    BEGIN
    <%= render_slot(@entry) %>
    END
    """noformat
  end

  def explicit_entries_render(assigns) do
    ~CE"""
    BEGIN
    <%= for entry <- @entry do %><%= render_slot(entry) %><% end %>
    END
    """noformat
  end

  describe "render_slot/2" do
    test "handles multiple slot entries with implicit list rendering" do
      assert render_string!("""
             <.implicit_entries_render>
               <:entry>
                 one
               </:entry>
               <:entry>
                 two
               </:entry>
             </.implicit_entries_render>
             """) == "BEGIN\n\n    one\n  \n    two\n  \nEND\n"
    end

    test "handles multiple slot entries with explicit list rendering" do
      assert render_string!("""
             <.explicit_entries_render>
               <:entry>
                 one
               </:entry>
               <:entry>
                 two
               </:entry>
             </.explicit_entries_render>
             """) == "BEGIN\n\n    one\n  \n    two\n  \nEND\n"
    end

    test "has the same rendered content no matter which rendering method is used" do
      implicit_rendered_content =
        render_string!("""
        <.implicit_entries_render>
          <:entry>
            one
          </:entry>
          <:entry>
            two
          </:entry>
        </.implicit_entries_render>
        """)

      explicit_rendered_content =
        render_string!("""
        <.explicit_entries_render>
          <:entry>
            one
          </:entry>
          <:entry>
            two
          </:entry>
        </.explicit_entries_render>
        """)

      assert implicit_rendered_content == explicit_rendered_content
    end
  end
end
