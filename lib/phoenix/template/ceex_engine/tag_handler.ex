defmodule Phoenix.Template.CEExEngine.TagHandler do
  @moduledoc false

  # The behaviour for implementing tag handler.

  @doc """
  Classifies the type and the name of tag from the given binary.

  It must return a tuple containing the type of the tag and the name of tag.
  For instance, in a tag handler for HTML this would return `{:tag, "div"}`
  in case the given binary is identified as HTML tag.

  You can also return `{:error, reason}` so that the compiler will display this
  error.
  """
  @callback classify_type(name :: binary()) ::
              {type :: atom(), name :: binary()} | {:error, reason :: binary()}

  @doc """
  Checks if the given binary is either void or not.

  That's mainly useful for HTML tags and used internally by the compiler. You
  can just implement as `def void?(_), do: false` if you want to ignore this.
  """
  @callback void?(name :: binary()) :: boolean()

  @doc """
  Handles attributes.

  It returns a quoted expression or attributes. If attributes are returned,
  the second element is a list where each element in the list represents
  one attribute.If the list element is a two-element tuple, it is assumed
  the key is the name to be statically written in the template. The second
  element is the value which is also statically written to the template whenever
  possible (such as binaries or binaries inside a list).
  """
  @callback handle_attributes(ast :: Macro.t(), meta :: keyword) ::
              {:attributes, [{binary(), Macro.t()} | Macro.t()]} | {:quoted, Macro.t()}

  @doc """
  Gets annotation around the whole body of a template.
  """
  # TODO: change the name to get_body_annotation
  @callback annotate_body(caller :: Macro.Env.t()) :: {String.t(), String.t()} | nil

  @doc """
  Gets annotation around each slot of a template.

  In case the slot is an implicit inner block, the tag meta points to
  the component.
  """
  @callback annotate_slot(
              name :: atom(),
              tag_meta :: %{line: non_neg_integer(), column: non_neg_integer()},
              close_tag_meta :: %{line: non_neg_integer(), column: non_neg_integer()},
              caller :: Macro.Env.t()
            ) :: {String.t(), String.t()} | nil

  @doc """
  Gets annotation which is added at the beginning of a component.
  """
  # TODO: change the name to get_caller_annotation
  # TODO: change file and line to caller, just like annotate_body
  @callback annotate_caller(file :: String.t(), line :: integer()) :: String.t() | nil
end
