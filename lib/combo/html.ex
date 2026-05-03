defmodule Combo.HTML do
  @moduledoc ~S"""
  Building blocks for working with HTML.

  ## Features

    * Components
    * Form handling

  ## Note

  This module is built on top of:

    * `Combo.Template`
    * `HAT`

  And, by design, they are hidden from daily use.
  """

  @doc false
  defmacro __using__(opts \\ []) do
    default =
      quote bind_quoted: [opts: opts] do
        import Combo.HTML
        import Combo.Template, only: [embed_templates: 1]
        use HAT, opts
      end

    conditional =
      if __CALLER__.module != Combo.HTML.Components do
        quote do
          import Combo.HTML.Components
        end
      end

    [default, conditional]
  end

  @doc """
  Marks the given content as raw.

  This means any HTML code inside the given string won't be escaped.

  By default, interpolated data in templates is considered unsafe:

  ```hat
  <%= "<hello>" %>
  ```

  which renders:

  ```html
  &lt;hello&gt;
  ```

  However, in some cases, you may want to tag it as safe and show its
  "raw" contents:

  ```hat
  <%= raw "<hello>" %>
  ```

  which renders:

  ```html
  <hello>
  ```

  ## Examples

      iex> raw({:safe, "<hello>"})
      {:safe, "<hello>"}

      iex> raw("<hello>")
      {:safe, "<hello>"}

      iex> raw(nil)
      {:safe, ""}

  """
  @spec raw(HAT.SafeHTML.safe() | iodata() | nil) :: HAT.SafeHTML.safe()
  def raw({:safe, _} = safe), do: safe
  def raw(nil), do: {:safe, ""}
  def raw(value) when is_binary(value) or is_list(value), do: {:safe, value}

  @doc """
  Merge values in a list as a string, which can be used as the value of
  attributes.

  This function bulits the final string by by joining all truthy elements in
  the list with `" "`.

  ## Examples

      iex> ml(["btn", nil, false, "btn-primary"])
      "btn btn-primary"

      iex> ml(["btn", nil, false, [nil, "btn-primary"]])
      "btn btn-primary"

  """
  def ml(list) when is_list(list), do: ml_encode(list)

  defp ml_encode(value) do
    value
    |> Enum.flat_map(fn
      nil -> []
      false -> []
      inner when is_list(inner) -> [ml_encode(inner)]
      other -> [other]
    end)
    |> Enum.join(" ")
  end
end
