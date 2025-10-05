defmodule Combo.Proxy.Backend do
  @moduledoc false

  defstruct plug: :unset,
            method: :unset,
            host: :unset,
            path: :unset,
            path_info: :unset,
            rewrite_path_info: true

  @type t :: %__MODULE__{}

  @doc false
  def new!(config) do
    config
    |> as_map!()
    |> transform_plug()
    |> transform_path()
    |> as_struct!()
  end

  defp as_map!(config) when is_map(config), do: config
  defp as_map!(config) when is_list(config), do: Enum.into(config, %{})

  defp as_map!(config) do
    raise ArgumentError,
          "backend config should be a map or a keyword list, but #{inspect(config)} is provided"
  end

  defp transform_plug(%{plug: plug} = config) do
    plug =
      case plug do
        {mod, opts} -> {mod, mod.init(opts)}
        mod -> {mod, mod.init([])}
      end

    %{config | plug: plug}
  end

  defp transform_plug(config), do: config

  defp transform_path(%{path: path} = config) do
    path_info = String.split(path, "/", trim: true)
    Map.put(config, :path_info, path_info)
  end

  defp transform_path(config), do: config

  defp as_struct!(config) do
    default_struct = __MODULE__.__struct__()
    valid_keys = Map.keys(default_struct)
    config = Map.take(config, valid_keys)
    Map.merge(default_struct, config)
  end

  @doc """
  Calculate specificity score for a backend.
  """
  def specificity(%__MODULE__{} = backend) do
    method_score = method_score(backend.method)
    host_score = host_score(backend.host)
    path_score = path_score(backend.path)
    {method_score, host_score, path_score}
  end

  defp method_score(:unset), do: 0
  defp method_score(_), do: 1

  defp host_score(:unset), do: 0
  defp host_score(regex) when is_struct(regex, Regex), do: 1
  defp host_score(binary) when is_binary(binary), do: 2

  defp path_score(:unset), do: 0
  defp path_score("/"), do: 1

  defp path_score(path) when is_binary(path) do
    segments = String.split(path, "/", trim: true)
    length(segments) * 10
  end
end
