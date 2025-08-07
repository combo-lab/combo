# Note this file is intentionally a .exs file because it is loaded
# in the test helper with debug_heex_annotations turned on.
defmodule Combo.HTML.DebugAnnotations do
  use Combo.HTML

  def remote(assigns) do
    ~CE"REMOTE COMPONENT: Value: {@value}"
  end

  def remote_with_root(assigns) do
    ~CE"<div>REMOTE COMPONENT: Value: {@value}</div>"
  end

  def local(assigns) do
    ~CE"LOCAL COMPONENT: Value: {@value}"
  end

  def local_with_root(assigns) do
    ~CE"<div>LOCAL COMPONENT: Value: {@value}</div>"
  end

  def nested(assigns) do
    ~CE"""
    <div>
      <.local_with_root value="local" />
    </div>
    """
  end
end
