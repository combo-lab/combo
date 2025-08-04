defmodule Combo.HTMLTest.DOM do
  @moduledoc false

  def ensure_loaded! do
    if not Code.ensure_loaded?(LazyHTML) do
      raise """
      Combo.HTMLTest requires lazy_html as a test dependency.
      Please add to your mix.exs:

      {:lazy_html, ">= 0.1.0", only: :test}
      """
    end
  end

  @spec parse_document(binary) :: {LazyHTML.t(), LazyHTML.Tree.t()}
  def parse_document(html) do
    lazydoc = LazyHTML.from_document(html)
    tree = LazyHTML.to_tree(lazydoc)
    {lazydoc, tree}
  end

  @spec parse_fragment(binary) :: {LazyHTML.t(), LazyHTML.Tree.t()}
  def parse_fragment(html) do
    lazydoc = LazyHTML.from_fragment(html)
    tree = LazyHTML.to_tree(lazydoc)
    {lazydoc, tree}
  end

  @spec to_tree(LazyHTML.t(), keyword()) :: LazyHTML.Tree.t()
  def to_tree(lazy, opts \\ []) when is_struct(lazy, LazyHTML) do
    LazyHTML.to_tree(lazy, opts)
  end

  @spec to_lazy(LazyHTML.Tree.t()) :: LazyHTML.t()
  def to_lazy(tree) do
    LazyHTML.from_tree(tree)
  end

  @spec to_tree(LazyHTML.t()) :: String.t()
  def to_html(lazy) when is_struct(lazy, LazyHTML) do
    LazyHTML.to_html(lazy, skip_whitespace_nodes: true)
  end
end
