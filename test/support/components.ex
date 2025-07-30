defmodule Phoenix.LiveViewTest.Support.FunctionComponent do
  use Phoenix.Template.CEExEngine.Component

  def render(assigns) do
    ~CE"""
    COMPONENT:{@value}
    """
  end

  def render_with_inner_content(assigns) do
    ~CE"""
    COMPONENT:{@value}, Content: {render_slot(@inner_block)}
    """
  end
end

defmodule Phoenix.LiveViewTest.Support.FunctionComponentWithAttrs do
  use Phoenix.Template.CEExEngine.Component

  defmodule Struct do
    defstruct []
  end

  def identity(var), do: var
  def map_identity(%{} = map), do: map

  attr :attr, :any
  def fun_attr_any(assigns), do: ~CE[]

  attr :attr, :string
  def fun_attr_string(assigns), do: ~CE[]

  attr :attr, :atom
  def fun_attr_atom(assigns), do: ~CE[]

  attr :attr, :boolean
  def fun_attr_boolean(assigns), do: ~CE[]

  attr :attr, :integer
  def fun_attr_integer(assigns), do: ~CE[]

  attr :attr, :float
  def fun_attr_float(assigns), do: ~CE[]

  attr :attr, :map
  def fun_attr_map(assigns), do: ~CE[]

  attr :attr, :list
  def fun_attr_list(assigns), do: ~CE[]

  attr :attr, :global
  def fun_attr_global(assigns), do: ~CE[]

  attr :rest, :global, doc: "These are passed to the inner input field"
  def fun_attr_global_doc(assigns), do: ~CE[]

  attr :rest, :global, doc: "These are passed to the inner input field", include: ~w(value)
  def fun_attr_global_doc_include(assigns), do: ~CE[]

  attr :rest, :global, include: ~w(value)
  def fun_attr_global_include(assigns), do: ~CE[]

  attr :name, :string, doc: "The form input name"
  attr :rest, :global, doc: "These are passed to the inner input field"
  def fun_attr_global_and_regular(assigns), do: ~CE[]

  attr :attr, Struct
  def fun_attr_struct(assigns), do: ~CE[]

  attr :attr, :any, required: true
  def fun_attr_required(assigns), do: ~CE[]

  attr :attr, :any, default: %{}
  def fun_attr_default(assigns), do: ~CE[]

  attr :attr1, :any
  attr :attr2, :any
  def fun_multiple_attr(assigns), do: ~CE[]

  attr :attr, :any, doc: "attr docs"
  def fun_with_attr_doc(assigns), do: ~CE[]

  attr :attr, :any, default: "foo", doc: "attr docs."
  def fun_with_attr_doc_period(assigns), do: ~CE[]

  attr :attr, :any,
    default: "foo",
    doc: """
    attr docs with bullets:

      * foo
      * bar

    and that's it.
    """

  def fun_with_attr_doc_multiline(assigns), do: ~CE[]

  attr :attr1, :any
  attr :attr2, :any, doc: false
  def fun_with_hidden_attr(assigns), do: ~CE[]

  attr :attr, :any
  @doc "fun docs"
  def fun_with_doc(assigns), do: ~CE[]

  attr :attr, :any

  @doc """
  fun docs
  [INSERT LVATTRDOCS]
  fun docs
  """
  def fun_doc_injection(assigns), do: ~CE[]

  attr :attr, :any
  @doc false
  def fun_doc_false(assigns), do: ~CE[]

  attr :attr, :any
  defp private_fun(assigns), do: ~CE[]
  def exposes_private_fun_to_avoid_warnings(assigns), do: private_fun(assigns)

  slot :inner_block
  def fun_slot(assigns), do: ~CE[]

  slot :inner_block, doc: "slot docs"
  def fun_slot_doc(assigns), do: ~CE[]

  slot :inner_block, required: true
  def fun_slot_required(assigns), do: ~CE[]

  slot :named, required: true, doc: "a named slot" do
    attr :attr1, :any, required: true, doc: "a slot attr doc"
    attr :attr2, :any, doc: "a slot attr doc"
  end

  def fun_slot_with_attrs(assigns), do: ~CE[]

  slot :named, required: true do
    attr :attr1, :any, required: true, doc: "a slot attr doc"
    attr :attr2, :any, doc: "a slot attr doc"
  end

  def fun_slot_no_doc_with_attrs(assigns), do: ~CE[]

  slot :named,
    required: true,
    doc: """
    Important slot:

    * for a
    * for b
    """ do
    attr :attr1, :any, required: true, doc: "a slot attr doc"
    attr :attr2, :any, doc: "a slot attr doc"
  end

  def fun_slot_doc_multiline_with_attrs(assigns), do: ~CE[]

  slot :named, required: true do
    attr :attr1, :any,
      required: true,
      doc: """
      attr docs with bullets:

        * foo
        * bar

      and that's it.
      """

    attr :attr2, :any, doc: "a slot attr doc"
  end

  def fun_slot_doc_with_attrs_multiline(assigns), do: ~CE[]

  attr :attr1, :atom, values: [:foo, :bar, :baz]
  attr :attr2, :atom, examples: [:foo, :bar, :baz]
  attr :attr3, :list, values: [[60, 40]]
  attr :attr4, :list, examples: [[60, 40]]
  attr :attr5, :atom, default: :foo, values: [:foo, :bar, :baz]
  attr :attr6, :atom, doc: "Attr 6 doc", values: [:foo, :bar, :baz]
  attr :attr7, :atom, doc: "Attr 7 doc", default: :foo, values: [:foo, :bar, :baz]
  def fun_attr_values_examples(assigns), do: ~CE[]
end
