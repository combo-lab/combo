defmodule Phoenix.Template.CEExEngine.Assigns do
  @moduledoc """
  Provides `assigns` related helpers.
  """

  alias Phoenix.Template.CEExEngine.Compiler

  @doc """
  Adds a key-value pair to `assigns`.

  ## Examples

      iex> assign(assigns, :name, "Combo")

  """
  def assign(assigns, key, value) when is_map(assigns) do
    validate_assign_key!(key)

    case assigns do
      %{^key => ^value} -> assigns
      _ -> Map.put(assigns, key, value)
    end
  end

  @doc """
  Adds key-value pairs to `assigns`.

  ## Examples

      iex> assign(assigns, name: "Combo", lang: "Elixir")
      iex> assign(assigns, %{name: "Combo", lang: "Elixir"})

  """
  def assign(assigns, keyword_or_map)
      when is_map(assigns) and
             (is_list(keyword_or_map) or is_map(keyword_or_map)) do
    Enum.reduce(keyword_or_map, assigns, fn {key, value}, acc ->
      assign(acc, key, value)
    end)
  end

  @doc ~S'''
  Adds the given `key` with `value` from `fun` into `assigns` if one
  does not yet exist.

  This function is useful for lazily assigning values.

  ## Examples

      iex> assign_new(assigns, :name, fn -> "Combo" end)
      iex> assign_new(assigns, :new_name, fn assigns -> "new" <> assigns[:name] end)

  ## Use cases - lazy assigns

  Imagine a card component:

  ```ceex
  <.card bg_color="red" />
  ```

  The `bg_color` is optional, so you can skip it:

  ```ceex
  <.card />
  ```

  In such case, the implementation can use `assign_new/1` to lazily assign
  a color if none is given.

  ```elixir
  def card(assigns) do
    assigns = assign_new(assigns, :bg_color, fn -> "green" end)

    ~CE"""
    <div class={@bg_color}>
      Example Card
    </div>
    """
  end
  ```
  '''
  def assign_new(assigns, key, fun) when is_map(assigns) and is_function(fun, 0) do
    validate_assign_key!(key)

    case assigns do
      %{^key => _} -> assigns
      _ -> Map.put(assigns, key, fun.())
    end
  end

  def assign_new(assigns, key, fun) when is_map(assigns) and is_function(fun, 1) do
    validate_assign_key!(key)

    case assigns do
      %{^key => _} -> assigns
      _ -> Map.put(assigns, key, fun.(assigns))
    end
  end

  defp validate_assign_key!(key) when is_atom(key), do: :ok

  defp validate_assign_key!(key) do
    raise ArgumentError, "assigns' keys must be atoms, got: #{inspect(key)}"
  end

  @doc ~S'''
  Filters `assigns` as a list of keywords for use as tag attributes.

  The second argument is optional, and it is a list of keys to exclude.
  It typically includes reserved keys by the component itself, which
  either do not belong in the markup, or are already handled explicitly
  by the component.

  > It is recommended to use `attr` macro of `:global` type provided by
  > `Phoenix.Template.CEExEngine.DeclarativeAssigns` rather than this function.

  ## Examples

  Imagine the following `link` component which allows a caller to pass
  a `new_window` assign, along with any other attributes they would like
  to add to the element, such as class, data attributes, etc:

  ```ceex
  <.link to="/" new_window={true} id="sku-1" class="underline">Home</.link>
  ```

  We could support the dynamic attributes with the following component:

  ```elixir
  def link(assigns) do
    target = if assigns[:new_window], do: "_blank", else: false
    rest = assigns_to_attrs(assigns, [:new_window, :to])

    assigns =
      assigns
      |> assign(:target, target)
      |> assign(:rest, rest)

    ~CE"""
    <a href={@to} target={@target} {@rest}>
      {render_slot(@inner_block)}
    </a>
    """
  end
  ```

  The above would result in the following rendered HTML:

  ```ceex
  <a href="/" target="_blank" id="sku-1" class="underline">Home</a>
  ```
  '''
  def assigns_to_attrs(assigns, exclude \\ []) do
    excluded_keys = Compiler.__reserved_assigns__() ++ exclude
    for {key, val} <- assigns, key not in excluded_keys, into: [], do: {key, val}
  end
end
