defmodule Combo.Template.CEExEngine.CompilerTest do
  use ExUnit.Case, async: true

  # # Tests

  # def remote_component(assigns) do
  #   compile_string("REMOTE COMPONENT: Value: {@value}")
  # end

  # def remote_component_with_inner_block(assigns) do
  #   compile_string("REMOTE COMPONENT: Value: {@value}, Content: {render_slot(@inner_block)}")
  # end

  # def remote_component_with_inner_block_args(assigns) do
  #   compile_string("""
  #   REMOTE COMPONENT WITH ARGS: Value: {@value}
  #   {render_slot(@inner_block, %{
  #     upcase: String.upcase(@value),
  #     downcase: String.downcase(@value)
  #   })}
  #   """)
  # end

  # defp local_component(assigns) do
  #   compile_string("LOCAL COMPONENT: Value: {@value}")
  # end

  # defp local_component_with_inner_block(assigns) do
  #   compile_string("LOCAL COMPONENT: Value: {@value}, Content: {render_slot(@inner_block)}")
  # end

  # defp local_component_with_inner_block_args(assigns) do
  #   compile_string("""
  #   LOCAL COMPONENT WITH ARGS: Value: {@value}
  #   {render_slot(@inner_block, %{
  #     upcase: String.upcase(@value),
  #     downcase: String.downcase(@value)
  #   })}
  #   """)
  # end

  # describe "named slots" do
  #   def component_with_slots_and_args(assigns) do
  #     compile_string("""
  #     BEFORE SLOT
  #     <%= render_slot(@sample, 1) %>
  #     AFTER SLOT
  #     """)
  #   end

  #   def component_with_slot_attrs(assigns) do
  #     compile_string("""
  #     <%= for entry <- @sample do %>
  #     <%= entry.a %>
  #     <%= render_slot(entry) %>
  #     <%= entry.b %>
  #     <% end %>
  #     """)
  #   end

  #   def component_with_self_close_slots(assigns) do
  #     compile_string("""
  #     <%= for entry <- @sample do %>
  #       <%= entry.id %>
  #     <% end %>
  #     """)
  #   end

  #   def render_slot_name(assigns) do
  #     compile_string("<%= for entry <- @sample do %>[<%= entry.__slot__ %>]<% end %>")
  #   end

  #   def render_inner_block_slot_name(assigns) do
  #     compile_string("<%= for entry <- @inner_block do %>[<%= entry.__slot__ %>]<% end %>")
  #   end

  #   test "store the slot name in __slot__" do
  #     assigns = %{}

  #     assert render_compiled("""
  #            <.render_slot_name>
  #              <:sample>
  #                The sample slot
  #              </:sample>
  #            </.render_slot_name>
  #            """) == "[sample]"

  #     assert render_compiled("""
  #            <.render_slot_name>
  #              <:sample/>
  #              <:sample/>
  #            </.render_slot_name>
  #            """) == "[sample][sample]"
  #   end

  #   test "store the inner_block slot name in __slot__" do
  #     assigns = %{}

  #     assert render_compiled("""
  #            <.render_inner_block_slot_name>
  #                The content
  #            </.render_inner_block_slot_name>
  #            """) == "[inner_block]"
  #   end
  # end
end
