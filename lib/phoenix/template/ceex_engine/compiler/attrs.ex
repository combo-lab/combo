defmodule Phoenix.Template.CEExEngine.Compiler.Attrs do
  @moduledoc false

  alias Combo.SafeHTML

  def handle_attr({:global, quoted}, meta) do
    {:quoted, quoted_escape_attrs(quoted, meta)}
  end

  def handle_attr({:local, name, quoted}, meta) do
    # Optimization:
    # If name is known at compile-time, we analyze its value, find the
    # static parts of them, then escape them at compile-time, instead
    # of runtime.
    with name when is_binary(name) <- name,
         {:ok, precompiled} <- precompile_static(name, quoted, meta) do
      # {:attr, name, quoted}
      precompiled
    else
      _ ->
        {:quoted, quoted_escape_attrs([{name, quoted}], meta)}
    end
  end

  defp quoted_escape_attrs(attrs, meta) do
    quote line: meta[:line] do
      {:safe, Combo.SafeHTML.escape_attrs(unquote(attrs))}
    end
  end

  # for values of list type, like ["static1", "static2", dynamic1, "static3"]
  defp precompile_static(name, [head | tail] = quoted, meta)
       when is_list(quoted) and is_binary(head) do
    {bins, tail} = Enum.split_while(tail, &is_binary/1)
    static = [head | bins]
    dynamic = tail

    escaped_static = escape_attr_value(static)

    new_quoted =
      if tail == [] do
        [IO.iodata_to_binary(escaped_static)]
      else
        quoted_dynamic =
          quote line: meta[:line] do
            {:safe, unquote(__MODULE__).escape_attr_value(unquote(dynamic))}
          end

        [IO.iodata_to_binary([escaped_static, ?\s]), quoted_dynamic]
      end

    {:ok, {:attr, name, new_quoted}}
  end

  # for values using string concatenation operator, like "btn" <> "-red"
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
      part, acc when is_binary(part) ->
        [escape_binary(part) | acc]

      {:"::", _, [binary, {:binary, _, _}]} = _part, acc ->
        [quoted_escape_binary(binary, meta) | acc]

      _, _ ->
        throw(:unknown_part)
    end)
  catch
    :unknown_part ->
      [quoted_escape_binary(quoted, meta) | acc]
  end

  defp inline_binaries(quoted, acc, _meta) when is_binary(quoted),
    do: [escape_binary(quoted) | acc]

  defp inline_binaries(quoted, acc, meta),
    do: [quoted_escape_binary(quoted, meta) | acc]

  @doc false
  def escape_binary(value) when is_binary(value) do
    value |> SafeHTML.to_iodata() |> IO.iodata_to_binary()
  end

  def escape_binary(value) do
    raise ArgumentError, "expected a binary in <>, got: #{inspect(value)}"
  end

  defp quoted_escape_binary(binary, meta) do
    quote line: meta[:line] do
      {:safe, unquote(__MODULE__).escape_binary(unquote(binary))}
    end
  end

  @doc false
  def escape_attr_value({:safe, data}), do: data
  def escape_attr_value(nil), do: []

  def escape_attr_value(value) when is_list(value),
    do: value |> encode_list() |> SafeHTML.to_iodata()

  def escape_attr_value(value), do: SafeHTML.to_iodata(value)

  defp encode_list(value) do
    value
    |> Enum.flat_map(fn
      nil -> []
      false -> []
      inner when is_list(inner) -> [encode_list(inner)]
      other -> [other]
    end)
    |> Enum.join(" ")
  end
end
