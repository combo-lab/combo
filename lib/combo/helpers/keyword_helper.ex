defmodule Combo.Helpers.KeywordHelper do
  @moduledoc false

  @type keys :: [atom(), ...]
  @type value :: term()

  @spec has_key?(keyword(), keys()) :: boolean()
  def has_key?(kw, [_ | _] = keys) when is_list(kw) and is_list(keys) do
    deep_has_key?(kw, keys)
  end

  defp deep_has_key?(kw, [key]) do
    Keyword.has_key?(kw, key)
  end

  defp deep_has_key?(kw, [key | rest_keys]) do
    if Keyword.has_key?(kw, key) do
      nested_kw = kw[key]

      if Keyword.keyword?(nested_kw) do
        deep_has_key?(nested_kw, rest_keys)
      else
        false
      end
    else
      false
    end
  end

  @spec get(keyword(), keys(), default :: value()) :: value()
  def get(kw, keys, default \\ nil) when is_list(keys) do
    if value = get_in(kw, keys) do
      value
    else
      # in case the value is falsy
      if has_key?(kw, keys) do
        value
      else
        default
      end
    end
  end

  @spec put(keyword(), keys(), value()) :: keyword()
  def put(kw, keys, value) when is_list(keys) do
    built_kw = build_kw(Enum.reverse(keys), value)

    Keyword.merge(kw, built_kw, fn _k, v1, v2 ->
      Keyword.merge(v1, v2, &deep_merge/3)
    end)
  end

  defp build_kw([], value), do: value
  defp build_kw([key | rest_key], value), do: build_kw(rest_key, [{key, value}])

  @spec merge(keyword(), keyword()) :: keyword()
  def merge(kw1, kw2) when is_list(kw1) and is_list(kw2) do
    Keyword.merge(kw1, kw2, fn _k, v1, v2 ->
      Keyword.merge(v1, v2, &deep_merge/3)
    end)
  end

  defp deep_merge(_k, v1, v2) do
    if Keyword.keyword?(v1) and Keyword.keyword?(v2) do
      Keyword.merge(v1, v2, &deep_merge/3)
    else
      v2
    end
  end
end
