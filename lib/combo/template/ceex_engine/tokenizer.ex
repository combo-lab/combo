defmodule Combo.Template.CEExEngine.Tokenizer do
  @moduledoc false

  alias Combo.Template.CEExEngine.SyntaxError
  alias Combo.Template.CEExEngine.TagHandler

  @space_chars ~c"\s\t\f"
  @quote_chars ~c"\"'"
  @stop_chars ~c">/=\r\n" ++ @quote_chars ++ @space_chars

  @doc """
  Initializes the tokenizer's state.

  ### Arguments

  * `source` - The source code to be tokenized.
  * `file` - Can be either a file or a string "nofile".
  * `indentation` - An integer that indicates the current indentation.

  """
  def init(source, file, indentation) do
    %{
      source: source,
      file: file,
      indentation: indentation,
      column_base: indentation + 1,
      braces: :enabled,
      context: []
    }
  end

  @doc """
  Tokenizes the source.

  ### Arguments

  * `source` - The source code to be tokenized.
  * `location` - The location of text's first char. It's a keyword list with
    `:line` and `:column`, and both of them must be positive integers.
  * `tokens` - The list of tokens.
  * `cont` - The continuation which indicates current processing context.
     It can be `{:text, braces}`, `:style`, `:script`, or `{:comment, line, column}`.
  * `state` - The state which is initiated by `Tokenizer.init/4`

  ### Examples

      iex> alias #{__MODULE__}

      iex> state = Tokenizer.init("<section><div/></section>", file, indentation)

      iex> Tokenizer.tokenize(state)
      {[
         {:close, :html_tag, "section", %{column: 16, line: 1}},
         {:html_tag, "div", [], %{column: 10, line: 1, closing: :self}},
         {:html_tag, "section", [], %{column: 1, line: 1}}
       ], {:text, :enabled}}

  """
  def tokenize(source, location, tokens, cont, state) do
    line = Keyword.get(location, :line, 1)
    column = Keyword.get(location, :column, state.column_base)
    buffer = []

    case cont do
      {:text, braces} ->
        handle_text(source, line, column, buffer, tokens, %{state | braces: braces})

      :style ->
        handle_style(source, line, column, buffer, tokens, state)

      :script ->
        handle_script(source, line, column, buffer, tokens, state)

      {:comment, _line, _column} ->
        handle_comment(source, line, column, buffer, tokens, state)
    end
  end

  def finalize(_tokens, {:comment, line, column}, file, source) do
    message = "unexpected end of string inside tag"
    meta = %{line: line, column: column}
    raise_syntax_error!(message, meta, %{source: source, file: file, indentation: 0})
  end

  def finalize(tokens, _cont, _file, _source) do
    tokens
    |> trim_leading_whitespace_tokens()
    |> Enum.reverse()
    |> trim_leading_whitespace_tokens()
  end

  ## handle_text

  defp handle_text("\r\n" <> rest, line, _column, buffer, tokens, state) do
    handle_text(rest, line + 1, state.column_base, ["\r\n" | buffer], tokens, state)
  end

  defp handle_text("\n" <> rest, line, _column, buffer, tokens, state) do
    handle_text(rest, line + 1, state.column_base, ["\n" | buffer], tokens, state)
  end

  defp handle_text("<!doctype" <> rest, line, column, buffer, tokens, state) do
    handle_doctype(rest, line, column + 9, ["<!doctype" | buffer], tokens, state)
  end

  defp handle_text("<!DOCTYPE" <> rest, line, column, buffer, tokens, state) do
    handle_doctype(rest, line, column + 9, ["<!DOCTYPE" | buffer], tokens, state)
  end

  defp handle_text("<!--" <> rest, line, column, buffer, tokens, state) do
    state = update_in(state.context, &[:comment_start | &1])
    handle_comment(rest, line, column + 4, ["<!--" | buffer], tokens, state)
  end

  defp handle_text("</" <> rest, line, column, buffer, tokens, state) do
    tokens = tokenize_buffer(buffer, tokens, line, column, state.context)
    handle_tag_close(rest, line, column + 2, tokens, %{state | context: []})
  end

  defp handle_text("<" <> rest, line, column, buffer, tokens, state) do
    tokens = tokenize_buffer(buffer, tokens, line, column, state.context)
    handle_tag_open(rest, line, column + 1, tokens, %{state | context: []})
  end

  defp handle_text("{" <> rest, line, column, buffer, tokens, %{braces: :enabled} = state) do
    tokens = tokenize_buffer(buffer, tokens, line, column, state.context)
    state = put_in(state.context, [])

    case handle_interpolation(rest, line, column + 1, [], 0, state) do
      {:ok, value, new_line, new_column, rest} ->
        tokens = [{:body_expr, value, %{line: line, column: column}} | tokens]
        handle_text(rest, new_line, new_column, [], tokens, state)

      {:error, message} ->
        meta = %{line: line, column: column}
        raise_syntax_error!(message, meta, state)
    end
  end

  defp handle_text(<<c::utf8, rest::binary>>, line, column, buffer, tokens, state) do
    handle_text(rest, line, column + 1, [char_or_bin(c) | buffer], tokens, state)
  end

  defp handle_text(<<>>, line, column, buffer, tokens, state) do
    ok(tokenize_buffer(buffer, tokens, line, column, state.context), {:text, state.braces})
  end

  ## handle_doctype

  defp handle_doctype(<<?>, rest::binary>>, line, column, buffer, tokens, state) do
    handle_text(rest, line, column + 1, [?> | buffer], tokens, state)
  end

  defp handle_doctype("\r\n" <> rest, line, _column, buffer, tokens, state) do
    handle_doctype(rest, line + 1, state.column_base, ["\r\n" | buffer], tokens, state)
  end

  defp handle_doctype("\n" <> rest, line, _column, buffer, tokens, state) do
    handle_doctype(rest, line + 1, state.column_base, ["\n" | buffer], tokens, state)
  end

  defp handle_doctype(<<c::utf8, rest::binary>>, line, column, buffer, tokens, state) do
    handle_doctype(rest, line, column + 1, [char_or_bin(c) | buffer], tokens, state)
  end

  defp handle_doctype(<<>>, line, column, _buffer, _tokens, state) do
    raise_syntax_error!(
      "expected closing `>` for doctype",
      %{line: line, column: column},
      state
    )
  end

  ## handle_comment

  # this wrapper is for preserving the location where the comment starts
  defp handle_comment(rest, line, column, buffer, tokens, state) do
    case handle_comment(rest, line, column, buffer, state) do
      {:text, rest, line, column, buffer} ->
        state = update_in(state.context, &[:comment_end | &1])
        handle_text(rest, line, column, buffer, tokens, state)

      {:eoc, line_end, column_end, buffer} ->
        tokens = tokenize_buffer(buffer, tokens, line_end, column_end, state.context)
        # use 'column - 4' to point to the opening <!--
        ok(tokens, {:comment, line, column - 4})
    end
  end

  defp handle_comment("\r\n" <> rest, line, _column, buffer, state) do
    handle_comment(rest, line + 1, state.column_base, ["\r\n" | buffer], state)
  end

  defp handle_comment("\n" <> rest, line, _column, buffer, state) do
    handle_comment(rest, line + 1, state.column_base, ["\n" | buffer], state)
  end

  defp handle_comment("-->" <> rest, line, column, buffer, _state) do
    {:text, rest, line, column + 3, ["-->" | buffer]}
  end

  defp handle_comment(<<c::utf8, rest::binary>>, line, column, buffer, state) do
    handle_comment(rest, line, column + 1, [char_or_bin(c) | buffer], state)
  end

  defp handle_comment(<<>>, line, column, buffer, _state) do
    {:eoc, line, column, buffer}
  end

  ## handle_style

  defp handle_style("</style>" <> rest, line, column, buffer, tokens, state) do
    tokens = [
      {:close, :html_tag, "style", %{line: line, column: column, inner_location: {line, column}}}
      | tokenize_buffer(buffer, tokens, line, column, [])
    ]

    handle_text(rest, line, column + 9, [], tokens, state)
  end

  defp handle_style("\r\n" <> rest, line, _column, buffer, tokens, state) do
    handle_style(rest, line + 1, state.column_base, ["\r\n" | buffer], tokens, state)
  end

  defp handle_style("\n" <> rest, line, _column, buffer, tokens, state) do
    handle_style(rest, line + 1, state.column_base, ["\n" | buffer], tokens, state)
  end

  defp handle_style(<<c::utf8, rest::binary>>, line, column, buffer, tokens, state) do
    handle_style(rest, line, column + 1, [char_or_bin(c) | buffer], tokens, state)
  end

  defp handle_style(<<>>, line, column, buffer, tokens, _state) do
    ok(tokenize_buffer(buffer, tokens, line, column, []), :style)
  end

  ## handle_script

  defp handle_script("</script>" <> rest, line, column, buffer, tokens, state) do
    tokens = [
      {:close, :html_tag, "script", %{line: line, column: column, inner_location: {line, column}}}
      | tokenize_buffer(buffer, tokens, line, column, [])
    ]

    handle_text(rest, line, column + 9, [], tokens, state)
  end

  defp handle_script("\r\n" <> rest, line, _column, buffer, tokens, state) do
    handle_script(rest, line + 1, state.column_base, ["\r\n" | buffer], tokens, state)
  end

  defp handle_script("\n" <> rest, line, _column, buffer, tokens, state) do
    handle_script(rest, line + 1, state.column_base, ["\n" | buffer], tokens, state)
  end

  defp handle_script(<<c::utf8, rest::binary>>, line, column, buffer, tokens, state) do
    handle_script(rest, line, column + 1, [char_or_bin(c) | buffer], tokens, state)
  end

  defp handle_script(<<>>, line, column, buffer, tokens, _state) do
    ok(tokenize_buffer(buffer, tokens, line, column, []), :script)
  end

  ## handle_tag_open

  defp handle_tag_open(text, line, column, tokens, state) do
    case handle_tag_name(text, column, []) do
      {:ok, name, new_column, rest} ->
        meta = %{line: line, column: column - 1, inner_location: nil, tag_name: name}

        case classify_tag(name) do
          {:error, message} ->
            raise_syntax_error!(message, %{line: line, column: column}, state)

          {type, name} ->
            tokens = [{type, name, [], meta} | tokens]
            handle_maybe_tag_open_end(rest, line, new_column, tokens, state)
        end

      :error ->
        message =
          "expected tag name after <. If you meant to use < as part of a text, use &lt; instead"

        meta = %{line: line, column: column}
        raise_syntax_error!(message, meta, state)
    end
  end

  ## handle_tag_close

  defp handle_tag_close(text, line, column, tokens, state) do
    case handle_tag_name(text, column, []) do
      {:ok, name, new_column, ">" <> rest} ->
        meta = %{
          line: line,
          column: column - 2,
          inner_location: {line, column - 2},
          tag_name: name
        }

        case classify_tag(name) do
          {:error, message} ->
            raise_syntax_error!(message, meta, state)

          {type, name} ->
            tokens = [{:close, type, name, meta} | tokens]
            handle_text(rest, line, new_column + 1, [], tokens, pop_braces(state))
        end

      {:ok, _, new_column, _} ->
        message = "expected closing `>`"
        meta = %{line: line, column: new_column}
        raise_syntax_error!(message, meta, state)

      :error ->
        message = "expected tag name after </"
        meta = %{line: line, column: column}
        raise_syntax_error!(message, meta, state)
    end
  end

  ## handle_tag_name

  defp handle_tag_name(<<c::utf8, _rest::binary>> = text, column, buffer)
       when c in @stop_chars do
    done_tag_name(text, column, buffer)
  end

  defp handle_tag_name(<<c::utf8, rest::binary>>, column, buffer) do
    handle_tag_name(rest, column + 1, [char_or_bin(c) | buffer])
  end

  defp handle_tag_name(<<>>, column, buffer) do
    done_tag_name(<<>>, column, buffer)
  end

  defp done_tag_name(_text, _column, []) do
    :error
  end

  defp done_tag_name(text, column, buffer) do
    {:ok, buffer_to_string(buffer), column, text}
  end

  ## handle_maybe_tag_open_end

  defp handle_maybe_tag_open_end("\r\n" <> rest, line, _column, tokens, state) do
    handle_maybe_tag_open_end(rest, line + 1, state.column_base, tokens, state)
  end

  defp handle_maybe_tag_open_end("\n" <> rest, line, _column, tokens, state) do
    handle_maybe_tag_open_end(rest, line + 1, state.column_base, tokens, state)
  end

  defp handle_maybe_tag_open_end(<<c::utf8, rest::binary>>, line, column, tokens, state)
       when c in @space_chars do
    handle_maybe_tag_open_end(rest, line, column + 1, tokens, state)
  end

  defp handle_maybe_tag_open_end("/>" <> rest, line, column, tokens, state) do
    tokens = normalize_tag(tokens, line, column + 2, true)
    handle_text(rest, line, column + 2, [], tokens, state)
  end

  defp handle_maybe_tag_open_end(">" <> rest, line, column, tokens, state) do
    case normalize_tag(tokens, line, column + 1, false) do
      [{:html_tag, "script", _, _} | _] = tokens ->
        handle_script(rest, line, column + 1, [], tokens, state)

      [{:html_tag, "style", _, _} | _] = tokens ->
        handle_style(rest, line, column + 1, [], tokens, state)

      tokens ->
        handle_text(rest, line, column + 1, [], tokens, push_braces(state))
    end
  end

  defp handle_maybe_tag_open_end("{" <> rest, line, column, tokens, state) do
    handle_root_attribute(rest, line, column + 1, tokens, state)
  end

  defp handle_maybe_tag_open_end(<<>>, line, column, _tokens, state) do
    message = ~S"""
    expected closing `>` or `/>`

    Make sure the tag is properly closed. This may happen if there
    is an EEx interpolation inside a tag, which is not supported.
    For instance, instead of

        <div id="<%= @id %>">Content</div>

    do

        <div id={@id}>Content</div>

    If @id is nil or false, then no attribute is sent at all.

    Inside {...} you can place any Elixir expression. If you want
    to interpolate in the middle of an attribute value, instead of

        <a class="foo bar <%= @class %>">Text</a>

    you can pass an Elixir string with interpolation:

        <a class={"foo bar #{@class}"}>Text</a>
    """

    raise_syntax_error!(message, %{line: line, column: column}, state)
  end

  defp handle_maybe_tag_open_end(text, line, column, tokens, state) do
    handle_attribute(text, line, column, tokens, state)
  end

  ## handle_attribute

  defp handle_attribute(text, line, column, tokens, state) do
    case handle_attr_name(text, column, []) do
      {:ok, name, new_column, rest} ->
        attr_meta = %{line: line, column: column}
        {text, line, column, value} = handle_maybe_attr_value(rest, line, new_column, state)
        tokens = put_attr(tokens, name, attr_meta, value)

        state =
          if name == "ceex-no-curly-interpolation" and state.braces == :enabled and
               not script_or_style?(tokens) do
            %{state | braces: 0}
          else
            state
          end

        handle_maybe_tag_open_end(text, line, column, tokens, state)

      {:error, message, column} ->
        meta = %{line: line, column: column}
        raise_syntax_error!(message, meta, state)
    end
  end

  defp script_or_style?([{:html_tag, name, _, _} | _]) when name in ~w(script style), do: true
  defp script_or_style?(_), do: false

  ## handle_root_attribute

  defp handle_root_attribute(text, line, column, tokens, state) do
    case handle_interpolation(text, line, column, [], 0, state) do
      {:ok, value, new_line, new_column, rest} ->
        meta = %{line: line, column: column}
        tokens = put_attr(tokens, :root, meta, {:expr, value, meta})
        handle_maybe_tag_open_end(rest, new_line, new_column, tokens, state)

      {:error, message} ->
        # We do column - 1 to point to the opening {
        meta = %{line: line, column: column - 1}
        raise_syntax_error!(message, meta, state)
    end
  end

  ## handle_attr_name

  defp handle_attr_name(<<c::utf8, _rest::binary>>, column, _buffer)
       when c in @quote_chars do
    {:error, "invalid character in attribute name: #{<<c>>}", column}
  end

  defp handle_attr_name(<<c::utf8, _rest::binary>>, column, [])
       when c in @stop_chars do
    {:error, "expected attribute name", column}
  end

  defp handle_attr_name(<<c::utf8, _rest::binary>> = text, column, buffer)
       when c in @stop_chars do
    {:ok, buffer_to_string(buffer), column, text}
  end

  defp handle_attr_name(<<c::utf8, rest::binary>>, column, buffer) do
    handle_attr_name(rest, column + 1, [char_or_bin(c) | buffer])
  end

  defp handle_attr_name(<<>>, column, _buffer) do
    {:error, "unexpected end of string inside tag", column}
  end

  ## handle_maybe_attr_value

  defp handle_maybe_attr_value("\r\n" <> rest, line, _column, state) do
    handle_maybe_attr_value(rest, line + 1, state.column_base, state)
  end

  defp handle_maybe_attr_value("\n" <> rest, line, _column, state) do
    handle_maybe_attr_value(rest, line + 1, state.column_base, state)
  end

  defp handle_maybe_attr_value(<<c::utf8, rest::binary>>, line, column, state)
       when c in @space_chars do
    handle_maybe_attr_value(rest, line, column + 1, state)
  end

  defp handle_maybe_attr_value("=" <> rest, line, column, state) do
    handle_attr_value_begin(rest, line, column + 1, state)
  end

  defp handle_maybe_attr_value(text, line, column, _state) do
    {text, line, column, nil}
  end

  ## handle_attr_value_begin

  defp handle_attr_value_begin("\r\n" <> rest, line, _column, state) do
    handle_attr_value_begin(rest, line + 1, state.column_base, state)
  end

  defp handle_attr_value_begin("\n" <> rest, line, _column, state) do
    handle_attr_value_begin(rest, line + 1, state.column_base, state)
  end

  defp handle_attr_value_begin(<<c::utf8, rest::binary>>, line, column, state)
       when c in @space_chars do
    handle_attr_value_begin(rest, line, column + 1, state)
  end

  defp handle_attr_value_begin("\"" <> rest, line, column, state) do
    handle_attr_value_quote(rest, ?", line, column + 1, [], state)
  end

  defp handle_attr_value_begin("'" <> rest, line, column, state) do
    handle_attr_value_quote(rest, ?', line, column + 1, [], state)
  end

  defp handle_attr_value_begin("{" <> rest, line, column, state) do
    handle_attr_value_as_expr(rest, line, column + 1, state)
  end

  defp handle_attr_value_begin(_text, line, column, state) do
    message =
      "invalid attribute value after `=`. Expected either a value between quotes " <>
        "(such as \"value\" or \'value\') or an Elixir expression between curly braces (such as `{expr}`)"

    meta = %{line: line, column: column}
    raise_syntax_error!(message, meta, state)
  end

  ## handle_attr_value_quote

  defp handle_attr_value_quote("\r\n" <> rest, delim, line, _column, buffer, state) do
    column = state.column_base
    handle_attr_value_quote(rest, delim, line + 1, column, ["\r\n" | buffer], state)
  end

  defp handle_attr_value_quote("\n" <> rest, delim, line, _column, buffer, state) do
    column = state.column_base
    handle_attr_value_quote(rest, delim, line + 1, column, ["\n" | buffer], state)
  end

  defp handle_attr_value_quote(<<delim, rest::binary>>, delim, line, column, buffer, _state) do
    value = buffer_to_string(buffer)
    {rest, line, column + 1, {:string, value, %{delimiter: delim}}}
  end

  defp handle_attr_value_quote(<<c::utf8, rest::binary>>, delim, line, column, buffer, state) do
    handle_attr_value_quote(rest, delim, line, column + 1, [char_or_bin(c) | buffer], state)
  end

  defp handle_attr_value_quote(<<>>, delim, line, column, _buffer, state) do
    message = """
    expected closing `#{<<delim>>}` for attribute value

    Make sure the attribute is properly closed. This may also happen if
    there is an EEx interpolation inside a tag, which is not supported.
    Instead of

        <div <%= @some_attributes %>>
        </div>

    do

        <div {@some_attributes}>
        </div>

    Where @some_attributes must be a keyword list or a map.
    """

    meta = %{line: line, column: column}
    raise_syntax_error!(message, meta, state)
  end

  ## handle_attr_value_as_expr

  defp handle_attr_value_as_expr(text, line, column, state) do
    case handle_interpolation(text, line, column, [], 0, state) do
      {:ok, value, new_line, new_column, rest} ->
        {rest, new_line, new_column, {:expr, value, %{line: line, column: column}}}

      {:error, message} ->
        # We do column - 1 to point to the opening {
        meta = %{line: line, column: column - 1}
        raise_syntax_error!(message, meta, state)
    end
  end

  ## handle_interpolation

  defp handle_interpolation("\r\n" <> rest, line, _column, buffer, braces, state) do
    handle_interpolation(rest, line + 1, state.column_base, ["\r\n" | buffer], braces, state)
  end

  defp handle_interpolation("\n" <> rest, line, _column, buffer, braces, state) do
    handle_interpolation(rest, line + 1, state.column_base, ["\n" | buffer], braces, state)
  end

  defp handle_interpolation("}" <> rest, line, column, buffer, 0, _state) do
    value = buffer_to_string(buffer)
    {:ok, value, line, column + 1, rest}
  end

  defp handle_interpolation(~S(\}) <> rest, line, column, buffer, braces, state) do
    handle_interpolation(rest, line, column + 2, [~S(\}) | buffer], braces, state)
  end

  defp handle_interpolation(~S(\{) <> rest, line, column, buffer, braces, state) do
    handle_interpolation(rest, line, column + 2, [~S(\{) | buffer], braces, state)
  end

  defp handle_interpolation("}" <> rest, line, column, buffer, braces, state) do
    handle_interpolation(rest, line, column + 1, ["}" | buffer], braces - 1, state)
  end

  defp handle_interpolation("{" <> rest, line, column, buffer, braces, state) do
    handle_interpolation(rest, line, column + 1, ["{" | buffer], braces + 1, state)
  end

  defp handle_interpolation(<<c::utf8, rest::binary>>, line, column, buffer, braces, state) do
    handle_interpolation(rest, line, column + 1, [char_or_bin(c) | buffer], braces, state)
  end

  defp handle_interpolation(<<>>, _line, _column, _buffer, _braces, _state) do
    {:error,
     """
     expected closing `}` for expression

     In case you don't want `{` to begin a new interpolation, \
     you may write it using `&lbrace;` or using `<%= "{" %>`\
     """}
  end

  ## helpers

  @compile {:inline, ok: 2, char_or_bin: 1}

  defp ok(tokens, cont), do: {tokens, cont}

  defp char_or_bin(c) when c <= 127, do: c
  defp char_or_bin(c), do: <<c::utf8>>

  defp buffer_to_string(buffer) do
    IO.iodata_to_binary(Enum.reverse(buffer))
  end

  defp tokenize_buffer(buffer, tokens, line, column, context)

  defp tokenize_buffer([], tokens, _line, _column, _context),
    do: tokens

  defp tokenize_buffer(buffer, tokens, line, column, context) do
    meta = %{line_end: line, column_end: column}

    meta =
      if context == [] do
        meta
      else
        Map.put(meta, :context, trim_context(context))
      end

    [{:text, buffer_to_string(buffer), meta} | tokens]
  end

  defp trim_context([:comment_end, :comment_start | [_ | _] = rest]), do: trim_context(rest)
  defp trim_context(rest), do: Enum.reverse(rest)

  defp push_braces(%{braces: :enabled} = state), do: state
  defp push_braces(%{braces: braces} = state), do: %{state | braces: braces + 1}

  defp pop_braces(%{braces: :enabled} = state), do: state
  defp pop_braces(%{braces: 1} = state), do: %{state | braces: :enabled}
  defp pop_braces(%{braces: braces} = state), do: %{state | braces: braces - 1}

  defp put_attr([{type, name, attrs, meta} | rest], attr, attr_meta, value) do
    attrs = [{attr, value, attr_meta} | attrs]
    [{type, name, attrs, meta} | rest]
  end

  defp classify_tag(<<first, _::binary>> = name) when first in ?A..?Z,
    do: {:remote_component, name}

  defp classify_tag("."), do: {:error, "a component name is required after ."}
  defp classify_tag("." <> name), do: {:local_component, name}

  defp classify_tag(":inner_block"), do: {:error, "the slot name :inner_block is reserved"}
  defp classify_tag(":" <> name), do: {:slot, name}

  defp classify_tag(name), do: {:html_tag, name}

  defp normalize_tag([{type, name, attrs, meta} | rest], line, column, self_close?) do
    attrs = Enum.reverse(attrs)
    meta = %{meta | inner_location: {line, column}}

    meta =
      cond do
        type == :html_tag and TagHandler.void_tag?(name) -> Map.put(meta, :closing, :void)
        self_close? -> Map.put(meta, :closing, :self)
        true -> meta
      end

    [{type, name, attrs, meta} | rest]
  end

  defp trim_leading_whitespace_tokens(tokens) do
    with [{:text, text, _} | rest] <- tokens,
         "" <- String.trim(text) do
      trim_leading_whitespace_tokens(rest)
    else
      _ -> tokens
    end
  end

  defp raise_syntax_error!(message, meta, state) do
    raise SyntaxError,
      file: state.file,
      line: meta.line,
      column: meta.column,
      description: message <> SyntaxError.code_snippet(state.source, meta, state.indentation)
  end
end
