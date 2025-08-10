defmodule ComboTest.Template.CEExEngine.Components do
  use Combo.Template.CEExEngine

  def do_block(do: {:safe, _} = safe), do: safe

  def c_default_slot(assigns) do
    ~CE"""
    {render_slot(@inner_block)}
    """noformat
  end

  def c_named_slot(assigns) do
    ~CE"""
    {render_slot(@entry)}
    """
  end

  def component(assigns) do
    ~CE"""
    [COMPONENT]

    Value:
    {{:safe, inspect(@value)}}
    """noformat
  end

  def component_with_default_slot(assigns) do
    ~CE"""
    [COMPONENT_WITH_DEFAULT_SLOT]

    Value:
    {{:safe, inspect(@value)}}

    Inner block:
    {render_slot(@inner_block)}
    """noformat
  end

  def component_with_default_slot_args(assigns) do
    ~CE"""
    [COMPONENT_WITH_DEFAULT_SLOT_ARGS]

    Value:
    {{:safe, inspect(@value)}}

    Inner block:
    {render_slot(@inner_block, %{
      upcase: {:safe, inspect(String.upcase(@value))},
      downcase: {:safe, inspect(String.downcase(@value))}
    })}
    """noformat
  end

  # ===

  def component_with_self_closed_named_slot(assigns) do
    ~CE"""
    <%= for entry <- @sample do %>
      <%= entry.id %>
    <% end %>
    """noformat
  end

  def component_with_named_slot(assigns) do
    ~CE"""
    BEFORE SLOT
    <%= render_slot(@sample) %>
    AFTER SLOT
    """noformat
  end

  def component_with_named_slot_implicit_list_rendering(assigns) do
    ~CE"""
    BEFORE SLOT
    <%= render_slot(@sample) %>
    AFTER SLOT
    """noformat
  end

  def component_with_named_slot_explicit_list_rendering(assigns) do
    ~CE"""
    BEFORE SLOT
    <%= for entry <- @sample do %>
      <%= render_slot(entry, %{}) %>
    <% end %>
    AFTER SLOT
    """noformat
  end

  def component_with_named_slot_attrs(assigns) do
    ~CE"""
    <%= for entry <- @sample do %>
    <%= entry.a %>
    <%= render_slot(entry) %>
    <%= entry.b %>
    <% end %>
    """noformat
  end

  def component_with_named_slot_args(assigns) do
    ~CE"""
    BEFORE SLOT
    <%= render_slot(@sample, 1) %>
    AFTER SLOT
    """noformat
  end

  def component_with_named_slots(assigns) do
    ~CE"""
    BEFORE HEADER
    <%= render_slot(@header) %>
    TEXT
    <%= render_slot(@footer) %>
    AFTER FOOTER
    """noformat
  end

  def component_with_default_and_named_slots(assigns) do
    ~CE"""
    BEFORE HEADER
    <%= render_slot(@header) %>
    TEXT:<%= render_slot(@inner_block) %>:TEXT
    <%= render_slot(@footer) %>
    AFTER FOOTER
    """noformat
  end

  def inspector_component(assigns) do
    ~CE"""
    <div><%= assigns[:attr] || "NA" %>:<%= assigns[:inner_block] && render_slot(@inner_block) || "NA" %></div>
    """noformat
  end

  def inspector_component1(assigns) do
    ~CE"""
    <%= assigns[:attr] || "NA" %>:<%= assigns[:inner_block] && render_slot(@inner_block) || "NA" %>
    """noformat
  end

  def inspector_default_slot(assigns) do
    ~CE"""
    {render_slot(@inner_block)}
    """
  end

  def inspector_slot_entries(assigns) do
    ~CE"""
    <div>begin|<%= for entry <- @entry do %><%= entry[:attr] || "NA" %>:<%= entry[:inner_block] && render_slot(entry, "*") || "NA" %>|<% end %>end</div>
    """noformat
  end
end
