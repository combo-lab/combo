defmodule Combo.Router.Forward do
  @moduledoc false

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{path_info: path, script_name: script} = conn, {forward_segments, plug, opts}) do
    new_path = path -- forward_segments
    {base, ^new_path} = Enum.split(path, length(path) - length(new_path))
    conn = %{conn | path_info: new_path, script_name: script ++ base}
    conn = plug.call(conn, plug.init(opts))
    %{conn | path_info: path, script_name: script}
  end
end
