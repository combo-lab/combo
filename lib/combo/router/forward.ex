defmodule Combo.Router.Forward do
  @moduledoc false

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(
        %{path_info: path_info, script_name: script_name} = conn,
        {base_path_info, {plug, plug_opts}}
      ) do
    new_path_info = path_info -- base_path_info
    new_script_name = script_name ++ base_path_info
    conn = %{conn | path_info: new_path_info, script_name: new_script_name}
    plug_opts = plug.init(plug_opts)
    conn = plug.call(conn, plug_opts)

    %{conn | path_info: path_info, script_name: script_name}
  end
end
