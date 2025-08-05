defmodule Combo.HTMLTest do
  @moduledoc """
  Provides helpers for testing HTML.

  All these helpers converts different data structure into a tree structure,
  which represents the essential structure of HTML.

  The tree structure is abbreviated as "x". That's the reason why these helpers
  are named like this.
  """

  alias Combo.SafeHTML
  alias Combo.HTMLTest.DOM

  @doc """
  Renders template into a tree structure.
  """
  def to_x(template) do
    template
    |> rendered_to_string()
    |> normalize_to_tree(sort_attributes: true)
  end

  @doc ~S"""
  Parses and normalizes HTML into a tree structure at compile-time.

  ## Examples

      iex> ~X|<a href="#{href}">text</a>|
      [{"a", [{"href", "\#{href}"}], ["text"]}]

  """
  defmacro sigil_X({:<<>>, _, [binary]}, []) when is_binary(binary) do
    Macro.escape(normalize_to_tree(binary, sort_attributes: true))
  end

  @doc ~S"""
  Parses and normalizes HTML into a tree structure at runtime.

  Different from ~X, the content between ~x is evaluated before parsing and
  normalizing.

  ## Examples

      iex> href = "https://example.com"
      iex> ~x|<a href="#{href}">text</a>|
      [{"a", [{"href", "https://example.com"}], ["text"]}]

  """
  defmacro sigil_x(term, []) do
    quote do
      unquote(__MODULE__).normalize_to_tree(unquote(term), sort_attributes: true)
    end
  end

  defp rendered_to_string(rendered) do
    rendered
    |> SafeHTML.to_safe()
    |> SafeHTML.safe_to_string()
  end

  defp render_string(mod, func, assigns) do
    apply(mod, func, [assigns]) |> rendered_to_string()
  end

  # defp render_html(mod, func, assigns) do
  #   apply(mod, func, [assigns]) |> t2h()
  # end

  @doc false
  def normalize_to_tree(html, opts \\ []) do
    sort_attributes? = Keyword.get(opts, :sort_attributes, false)
    trim_whitespace? = Keyword.get(opts, :trim_whitespace, true)
    full_document? = Keyword.get(opts, :full_document, false)

    html =
      case html do
        binary when is_binary(binary) ->
          (full_document? && DOM.parse_document(binary)) || DOM.parse_fragment(binary)

        h ->
          h
      end

    tree =
      case html do
        {%{} = struct, tree} when is_struct(struct, LazyHTML) -> tree
        html when is_struct(html, LazyHTML) -> DOM.to_tree(html)
        _ -> html
      end

    normalize_tree(tree, sort_attributes?, trim_whitespace?)
  end

  defp normalize_tree({node_type, attributes, content}, sort_attributes?, trim_whitespace?) do
    {node_type, (sort_attributes? && Enum.sort(attributes)) || attributes,
     normalize_tree(content, sort_attributes?, trim_whitespace?)}
  end

  defp normalize_tree(values, sort_attributes?, true) when is_list(values) do
    for value <- values,
        not is_binary(value) or (is_binary(value) and String.trim(value) != ""),
        do: normalize_tree(value, sort_attributes?, true)
  end

  defp normalize_tree(values, sort_attributes?, false) when is_list(values) do
    Enum.map(values, &normalize_tree(&1, sort_attributes?, false))
  end

  defp normalize_tree(binary, _sort_attributes?, true) when is_binary(binary) do
    if String.trim(binary) != "" do
      binary
    else
      nil
    end
  end

  defp normalize_tree(value, _sort_attributes?, _trim_whitespace?), do: value
end
