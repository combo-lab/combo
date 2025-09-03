defmodule ComboTest.Template.CEExEngine.Helper do
  @moduledoc false

  use Combo.Template.CEExEngine
  alias Combo.SafeHTML
  alias Combo.Template.CEExEngine.Compiler

  @doc """
  Prints the generated code.
  """
  def puts_compiled(source) do
    opts = [caller: __ENV__, file: __ENV__.file]

    Compiler.compile_string(source, opts)
    |> Macro.to_string()
    |> IO.puts()
  end

  @doc """
  At runtime, compiles the source into template.
  """
  def compile_string(source, opts \\ []) do
    default_opts = [caller: __ENV__, file: "nofile"]
    opts = Keyword.merge(default_opts, opts)
    Compiler.compile_string(source, opts)
  end

  @doc """
  At compile-time, compiles the source into template.
  """
  defmacro compile_string!(source, opts \\ []) do
    default_opts = [caller: __CALLER__, file: __CALLER__.file]
    opts = Keyword.merge(default_opts, opts)
    Compiler.compile_string(source, opts)
  end

  @doc """
  At compile-time, compiles the source into template, and generates the
  code for rendering the template as a string.
  """
  defmacro render_string!(source, assigns \\ {:%{}, [], []}) do
    opts = [caller: __CALLER__, file: __CALLER__.file]
    compiled = Compiler.compile_string(source, opts)

    quote do
      var!(assigns) = unquote(assigns)

      unquote(compiled)
      |> SafeHTML.to_iodata()
      |> IO.iodata_to_binary()
    end
  end


  @doc """
  A component for inspecting the internal of itself.
  """
  def inspector(assigns) do
    slots =
      Enum.filter(assigns, fn {_k, v} ->
        is_list(v) or
          (is_list(v) && Enum.any?(v, fn i -> Map.has_key?(i, :__slot__) end))
      end)

    slot_keys = Enum.map(slots, fn {k, _v} -> k end)

    slots =
      slots
      |> Enum.reject(fn {_k, v} -> v == [] end)
      |> Enum.sort_by(fn {k, _v} ->
        if k == :inner_block, do: 0, else: k
      end)

    slots =
      Enum.map(slots, fn {name, entries} ->
        entries =
          Enum.map(entries, fn entry ->
            attrs =
              entry
              |> Enum.reject(fn {k, _} -> k in [:__slot__, :inner_block] end)
              |> Enum.sort_by(&elem(&1, 0))

            {attrs, entry}
          end)
          |> Enum.with_index(fn {attrs, entry}, index -> {index + 1, attrs, entry} end)

        {name, entries}
      end)

    attrs = Enum.filter(assigns, fn {k, _v} -> k not in slot_keys end)
    attrs = Enum.sort_by(attrs, &elem(&1, 0))

    ~CE"""
    ---
    [ATTRS]
    <%= if attrs == [] do %>n/a
    <% else %><%= for {k, v} <- attrs do %>{k}: {inspect_attr_value(v)}
    <% end %><% end %>[SLOTS]
    <%= if slots == [] do %>n/a
    <% else %><%= for {name, entries} <- slots do %>{name}:
    <%= for {i, attrs, entry} <- entries do %>* entry {i}:
      - attrs:<%= if attrs == [] do %> n/a
    <% else %><%= for {k, v} <- attrs do %>
        {k}: {inspect_attr_value(v)}<% end %>
    <% end %>  - rendered: {inspect_rendered_slot_entry(entry)}
    <% end %><% end %><% end %>
    """noformat
  end

  defp inspect_attr_value(value) do
    {:safe, inspect(value)}
  end

  defp inspect_rendered_slot_entry(entry) do
    mode = entry[:render_inner_block] || :auto

    case mode do
      :auto ->
        if entry.inner_block do
          # to demonstrate the arg passed to render_slot/2, pass the entry itself as the arg
          arg = entry
          {:safe, render_slot(entry, arg) |> SafeHTML.to_iodata() |> to_string() |> inspect()}
        else
          {:safe, "n/a"}
        end

      :force ->
        # to demonstrate the arg passed to render_slot/2, pass the entry itself as the arg
        arg = entry
        {:safe, render_slot(entry, arg) |> SafeHTML.to_iodata() |> to_string() |> inspect()}
    end
  end
end
