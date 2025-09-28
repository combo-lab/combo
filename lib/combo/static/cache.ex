defmodule Combo.Static.Cache do
  @moduledoc false
  # It's built on top of `Combo.Cache`.

  require Logger

  @unsafe_local_url_chars ["\\"]

  def warmup(endpoint, config) do
    if get_in(config, [:static, :manifest]) do
      try do
        if manifest = get_manifest(config) do
          warmup_static(endpoint, config, manifest)
        end

        :ok
      rescue
        e -> Logger.error("Could not warm up static: #{Exception.message(e)}")
      end
    else
      cleanup(endpoint)
    end
  end

  @spec lookup(module(), String.t()) :: {String.t(), String.t()} | {String.t(), nil}
  def lookup(_endpoint, "//" <> _ = path) do
    raise_invalid_path(path)
  end

  def lookup(endpoint, "/" <> _ = path) do
    if String.contains?(path, @unsafe_local_url_chars) do
      raise ArgumentError, "unsafe characters detected for path #{inspect(path)}"
    else
      key = {:static, path}

      if value = Combo.Cache.get(endpoint, key) do
        value
      else
        {path, nil}
      end
    end
  end

  def lookup(_endpoint, path) when is_binary(path) do
    raise_invalid_path(path)
  end

  defp raise_invalid_path(path) do
    raise ArgumentError, "expected a path starting with a single /, got #{inspect(path)}"
  end

  defp get_manifest(config) do
    if from = get_in(config, [:static, :manifest]) do
      {app, path} =
        case from do
          {_, _} -> from
          path when is_binary(path) -> {Keyword.fetch!(config, :otp_app), path}
          _ -> raise ArgumentError, "[:static, :manifest] must be a binary or a tuple"
        end

      manifest_path = Application.app_dir(app, path)

      if File.exists?(manifest_path) do
        manifest_path |> File.read!() |> Combo.json_module().decode!()
      else
        raise ArgumentError, """
        could not find static manifest at #{inspect(manifest_path)}. \
        Run "mix combo.static.digest" after building your static files or \
        disable it by removing the [:static, :manifest] configuration.
        """
      end
    else
      nil
    end
  end

  defp warmup_static(endpoint, config, %{"latest" => latest, "digests" => digests}) do
    with_vsn? = get_in(config, [:static, :vsn])

    kvs =
      Enum.map(latest, fn {name, hashed_name} ->
        key = {:static, "/" <> name}
        value = build_value(digests, hashed_name, with_vsn?)
        {key, value}
      end)

    old_keys = Combo.Cache.get_keys(endpoint, {:static, :"$1"})
    new_keys = Enum.map(kvs, &elem(&1, 0))
    staled_keys = old_keys -- new_keys

    Combo.Cache.put(endpoint, kvs)
    for staled_key <- staled_keys, do: Combo.Cache.delete(endpoint, staled_key)

    :ok
  end

  defp warmup_static(_endpoint, _static_config, _manifest) do
    raise ArgumentError, "expected static manifest file to include 'latest' and 'digests' keys"
  end

  defp cleanup(endpoint) do
    keys = Combo.Cache.get_keys(endpoint, {:static, :"$1"})
    for key <- keys, do: Combo.Cache.delete(endpoint, key)
    :ok
  end

  defp build_value(digests, hashed_name, true) do
    {"/#{hashed_name}?vsn=d", build_integrity(digests[hashed_name]["sha512"])}
  end

  defp build_value(digests, hashed_name, false) do
    {"/#{hashed_name}", build_integrity(digests[hashed_name]["sha512"])}
  end

  defp build_integrity(nil), do: nil
  defp build_integrity(sum), do: "sha512-#{sum}"
end
