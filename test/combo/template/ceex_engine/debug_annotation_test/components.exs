defmodule Combo.Template.CEExEngine.DebugAnnotationTest.Components do
  use Combo.Template.CEExEngine

  def remote(assigns) do
    ~CE"REMOTE COMPONENT"
  end

  def remote_with_tags(assigns) do
    ~CE"<div>REMOTE COMPONENT</div>"
  end

  def local(assigns) do
    ~CE"LOCAL COMPONENT"
  end

  def local_with_tags(assigns) do
    ~CE"<div>LOCAL COMPONENT</div>"
  end

  def default_slot(assigns) do
    ~CE"""
    <.list>
      No items.
    </.list>
    """
  end

  def default_slot_with_tags(assigns) do
    ~CE"""
    <.list>
      <p>No items</p>
    </.list>
    """
  end

  def named_slot(assigns) do
    ~CE"""
    <.list>
      <:item>Coding</:item>
      <:item>Sleeping</:item>
    </.list>
    """
  end

  def named_slot_with_tags(assigns) do
    ~CE"""
    <.list>
      <:item><span>Coding</span></:item>
      <:item><span>Sleeping</span></:item>
    </.list>
    """
  end

  def nesting(assigns) do
    ~CE"""
    <div>
      <.local_with_tags value="local" />
    </div>
    """
  end

  defp list(assigns) do
    ~CE"""
    <%= for item <- Enum.intersperse(assigns[:item] || [], :separator) do %><%=
      if item == :separator do
        ", "
      else
        render_slot(item)
      end
    %><% end %>
    <%= if assigns[:inner_block] != [] do %>{render_slot(@inner_block)}<% end %>
    """noformat
  end
end
