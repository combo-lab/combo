defmodule Combo.Template.CEExEngine.Slot do
  @moduledoc """
  Provides slot related helpers.
  """

  import Combo.Template.CEExEngine.Sigil

  @doc ~S'''
  Renders a slot with the given optional `arg`.

  ```ceex
  {render_slot(@inner_block, @form)}
  ```

  If the slot has no entries, `nil` is returned.

  If the slot has multiple entries, `render_slot/2` will render all entries,
  concatenating their rendered contents.

  In case you want to use the entries' attributes, you need to iterate over
  the list to access each slot individually. For example, imagine a table
  component:

  ```ceex
  <.table rows={@users}>
    <:col :let={user} label="Name">
      {user.name}
    </:col>

    <:col :let={user} label="Address">
      {user.address}
    </:col>
  </.table>
  ```

  We pass the rows as an assign and we define a `:col` slot entry for each column
  we want in the table. Each column also has a `label`, which we are going to use
  in the table header.

  Inside the component, you can render the table with headers, rows, and columns:

      def table(assigns) do
        ~CE"""
        <table>
          <tr>
            <th :for={col <- @col}>{col.label}</th>
          </tr>
          <tr :for={row <- @rows}>
            <td :for={col <- @col}>{render_slot(col, row)}</td>
          </tr>
        </table>
        """
      end

  '''
  def render_slot(entry_or_entries, arg \\ nil)

  def render_slot(entry, arg) when is_map(entry) do
    call_inner_block!(entry, arg)
  end

  def render_slot([] = _entries, _), do: nil

  def render_slot([entry] = _entries, arg) do
    call_inner_block!(entry, arg)
  end

  def render_slot(entries, arg) when is_list(entries) do
    assigns = %{entries: entries, arg: arg}

    ~CE"""
    <%= for entry <- @entries do %>{call_inner_block!(entry, @arg)}<% end %>
    """noformat
  end

  defp call_inner_block!(entry, arg) do
    if !entry.inner_block do
      message =
        "attempted to render slot #{inspect(entry.__slot__)} but the slot has no inner block"

      raise RuntimeError, message
    end

    entry.inner_block.(arg)
  end
end
