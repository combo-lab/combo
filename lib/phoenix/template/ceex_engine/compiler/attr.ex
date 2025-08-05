defmodule Combo.Template.CEExEngine.Compiler.Attr do
  @moduledoc false

  alias Combo.SafeHTML

  @type name :: String.t()
  @type quoted :: Macro.t()
  @type meta :: keyword()

  @spec handle_attr({:global, quoted()} | {:local, name(), quoted()}, meta()) ::
          {:attr, name(), quoted()} | {:quoted, quoted()}
  def handle_attr({:global, quoted}, meta) do
    {:quoted, quoted_escape_attrs(quoted, meta)}
  end

  def handle_attr({:local, name, quoted}, meta) do
    # Optimization:
    # If name is known at compile-time, we analyze its value, find the
    # static elements of them, then escape them at compile-time, instead
    # of runtime.
    with name when is_binary(name) <- name,
         {:ok, precompiled} <- precompile_static(name, quoted, meta),
         do: precompiled,
         else: (_ -> {:quoted, quoted_escape_attrs([{name, quoted}], meta)})
  end

  # for values using string concatenation, like "btn" <> "-red"
  defp precompile_static(name, {:<>, _, [_, _]} = quoted, meta) do
    {:ok, {:attr, name, inline_binaries(quoted, meta)}}
  end

  # for values of binary type, like <<"Hello", 32, "World">>
  defp precompile_static(name, {:<<>>, _, _} = quoted, meta) do
    {:ok, {:attr, name, inline_binaries(quoted, meta)}}
  end

  # for other values
  defp precompile_static(_name, _quoted, _meta), do: {:error, :unsupported}

  defp inline_binaries(quoted, meta) do
    reversed = inline_binaries(quoted, [], meta)
    Enum.reverse(reversed)
  end

  defp inline_binaries({:<>, _, [left, right]}, acc, meta) do
    acc = inline_binaries(left, acc, meta)
    inline_binaries(right, acc, meta)
  end

  defp inline_binaries({:<<>>, _, parts} = quoted, acc, meta) do
    Enum.reduce(parts, acc, fn
      binary, acc when is_binary(binary) ->
        [escape_binary_value(binary) | acc]

      {:"::", _, [binary, {:binary, _, _}]}, acc ->
        [quoted_escape_binary_value(binary, meta) | acc]

      _, _ ->
        throw(:unsupported_part)
    end)
  catch
    :unsupported_part ->
      [quoted_escape_binary_value(quoted, meta) | acc]
  end

  defp inline_binaries(quoted, acc, _meta) when is_binary(quoted),
    do: [escape_binary_value(quoted) | acc]

  defp inline_binaries(quoted, acc, meta),
    do: [quoted_escape_binary_value(quoted, meta) | acc]

  @doc false
  @spec escape_attrs(keyword() | map()) :: iodata()
  def escape_attrs(keyword_or_map), do: SafeHTML.escape_attrs(keyword_or_map)

  defp quoted_escape_attrs(attrs, meta) do
    quote line: meta[:line] do
      {:safe, unquote(__MODULE__).escape_attrs(unquote(attrs))}
    end
  end

  @doc false
  @spec escape_binary_value(binary()) :: binary()
  def escape_binary_value(value) when is_binary(value) do
    value |> SafeHTML.to_iodata() |> IO.iodata_to_binary()
  end

  def escape_binary_value(value) do
    raise ArgumentError, "expected a binary in <>, got: #{inspect(value)}"
  end

  defp quoted_escape_binary_value(value, meta) do
    quote line: meta[:line] do
      {:safe, unquote(__MODULE__).escape_binary_value(unquote(value))}
    end
  end
end
