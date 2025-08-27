defmodule Combo.Template.CEExEngine.Tokenizer do
  @moduledoc false

  alias Combo.Template.CEExEngine.SyntaxError

  @space_chars ~c"\s\t\f"
  @quote_chars ~c"\"'"
  @stop_chars ~c">/=\r\n" ++ @space_chars ++ @quote_chars

  @type source :: binary()
  @type file :: String.t()
  @type indentation :: non_neg_integer()
  @type state :: map()

  @type location :: keyword()

  @type line :: pos_integer()
  @type column :: pos_integer()

  @type tokens :: list()
  @type cont :: {:text, :enabled} | :style | :script | {:comment, line(), column()}

  @doc """
  Initializes the tokenizer's state.

  ### Arguments

    * `source` - the source to be tokenized.
    * `file` - the path of file. Defaulto to `"nofile"`.
    * `indentation` - the indentation of source. Default to `0`.

  """
  @spec init(source(), file(), indentation()) :: state()
  def init(source, file \\ "nofile", indentation \\ 0) do
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

    * `source` - The source to be tokenized.
    * `location` - The location of source's first chararcter.
    * `tokens` - The list of tokens.
    * `cont` - The continuation which indicates current processing context.
    * `state` - The state which is initiated by `Tokenizer.init/3`

  ### Examples

      iex> source = "<section><div/></section>"

      iex> state = Tokenizer.init(source, "nofile", 0)

      iex> Tokenizer.tokenize(source, [], [], {:text, :enabled}, state)
      {[
         {:close, :htag, "section",
          %{
            tag_name: "section",
            void?: false,
            line: 1,
            column: 16,
            inner_location: {1, 16}
          }},
         {:htag, "div", [],
          %{
            tag_name: "div",
            void?: false,
            line: 1,
            column: 10,
            inner_location: {1, 16},
            self_closing?: true
          }},
         {:htag, "section", [],
          %{
            tag_name: "section",
            void?: false,
            line: 1,
            column: 1,
            inner_location: {1, 10},
            self_closing?: false
          }}
       ], {:text, :enabled}}

  """
  @spec tokenize(source(), location(), tokens(), cont(), state()) :: {tokens(), cont()}
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

  @doc """
  Gets the final tokens.
  """
  @spec finalize(tokens(), cont(), file(), source()) :: tokens()
  def finalize(_tokens, {:comment, line, column}, file, source) do
    message = "unexpected end of string inside tag"
    raise_syntax_error!(message, {line, column}, %{source: source, file: file, indentation: 0})
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
      {:ok, expr, new_line, new_column, rest} ->
        tokens = [{:body_expr, expr, %{line: line, column: column}} | tokens]
        handle_text(rest, new_line, new_column, [], tokens, state)

      {:error, message} ->
        raise_syntax_error!(message, {line, column}, state)
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
    message = "expected closing `>` for doctype"
    raise_syntax_error!(message, {line, column}, state)
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
      {:close, :htag, "style", %{line: line, column: column, inner_location: {line, column}}}
      | tokenize_buffer(buffer, tokens, line, column, [])
    ]

    handle_text(rest, line, column + 8, [], tokens, state)
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
      {:close, :htag, "script", %{line: line, column: column, inner_location: {line, column}}}
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
        meta = %{
          tag_name: name,
          void?: :pending,
          line: line,
          column: column - 1,
          inner_location: :pending,
          self_closing?: :pending
        }

        case classify_tag_name(name) do
          {:ok, {type, name}} ->
            void? = type == :htag and void_tag?(name)
            meta = %{meta | void?: void?}
            tokens = [{type, name, [], meta} | tokens]
            handle_maybe_tag_open_end(rest, line, new_column, tokens, state)

          {:error, message} ->
            raise_syntax_error!(message, {line, column}, state)
        end

      :error ->
        message = "expected tag name after <"
        raise_syntax_error!(message, {line, column}, state)
    end
  end

  ## handle_tag_close

  defp handle_tag_close(text, line, column, tokens, state) do
    case handle_tag_name(text, column, []) do
      {:ok, name, new_column, rest} ->
        meta = %{
          tag_name: name,
          void?: :pending,
          line: line,
          column: column - 2,
          inner_location: {line, column - 2}
        }

        case classify_tag_name(name) do
          {:ok, {type, name}} ->
            void? = type == :htag and void_tag?(name)
            meta = %{meta | void?: void?}
            tokens = [{:close, type, name, meta} | tokens]
            handle_maybe_tag_close_end(rest, line, new_column, tokens, state)

          {:error, message} ->
            raise_syntax_error!(message, {line, column - 2}, state)
        end

      :error ->
        message = "expected tag name after </"
        raise_syntax_error!(message, {line, column}, state)
    end
  end

  defp handle_maybe_tag_close_end(">" <> rest, line, column, tokens, state) do
    handle_text(rest, line, column + 1, [], tokens, pop_braces(state))
  end

  defp handle_maybe_tag_close_end(_, line, column, _tokens, state) do
    message = "expected closing `>` for tag"
    raise_syntax_error!(message, {line, column}, state)
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

  defp done_tag_name(_rest, _column, []) do
    :error
  end

  defp done_tag_name(rest, column, buffer) do
    name = buffer_to_string(buffer)
    {:ok, name, column, rest}
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
      [{:htag, "script", _, _} | _] = tokens ->
        handle_script(rest, line, column + 1, [], tokens, state)

      [{:htag, "style", _, _} | _] = tokens ->
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
    expected closing `>` or `/>` for tag

    Make sure the tag is properly closed. This may happen if there
    is an EEx interpolation inside a tag, which is not supported.
    For instance, instead of

        <div id="<%= @id %>">content</div>

    do

        <div id={@id}>content</div>

    If @id is nil or false, then no attribute is sent at all.

    Inside {...} you can place any Elixir expression. If you want
    to interpolate in the middle of an attribute value, instead of

        <div class="foo bar <%= @class %>">content</div>

    you can pass an Elixir string with interpolation:

        <div class={"foo bar #{@class}"}>content</div>
    """

    raise_syntax_error!(message, {line, column}, state)
  end

  defp handle_maybe_tag_open_end(text, line, column, tokens, state) do
    handle_attribute(text, line, column, tokens, state)
  end

  ## handle_root_attribute

  defp handle_root_attribute(text, line, column, tokens, state) do
    case handle_interpolation(text, line, column, [], 0, state) do
      {:ok, expr, new_line, new_column, rest} ->
        meta = %{line: line, column: column}
        tokens = put_attr(tokens, :root, {:expr, expr, meta}, meta)
        handle_maybe_tag_open_end(rest, new_line, new_column, tokens, state)

      {:error, message} ->
        # use column - 1 to point to the opening {
        raise_syntax_error!(message, {line, column - 1}, state)
    end
  end

  ## handle_attribute

  defp handle_attribute(text, line, column, tokens, state) do
    case handle_attr_name(text, column, []) do
      {:ok, name, new_column, rest} ->
        attr_meta = %{line: line, column: column}
        {rest, line, column, value} = handle_maybe_attr_value(rest, line, new_column, state)
        tokens = put_attr(tokens, name, value, attr_meta)

        state =
          if name == "ceex-no-curly-interpolation" and state.braces == :enabled and
               not style_or_script?(tokens) do
            %{state | braces: 0}
          else
            state
          end

        handle_maybe_tag_open_end(rest, line, column, tokens, state)

      {:error, message, column} ->
        raise_syntax_error!(message, {line, column}, state)
    end
  end

  defp style_or_script?([{:htag, name, _, _} | _]) when name in ~w(style script), do: true
  defp style_or_script?(_), do: false

  ## handle_attr_name

  defp handle_attr_name(<<c::utf8, _rest::binary>>, column, _buffer)
       when c in @quote_chars do
    {:error, "expected valid character in attribute name, got: #{<<c>>}", column}
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

  defp handle_maybe_attr_value(rest, line, column, _state) do
    {rest, line, column, nil}
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
    handle_attr_value_brace(rest, line, column + 1, state)
  end

  defp handle_attr_value_begin(_text, line, column, state) do
    message = """
    expected valid attribute value after `=`

    The attribute value can be a value between quotes (such as "value" or 'value') \
    or an Elixir expression between curly braces (such as `{expr}`).\
    """

    raise_syntax_error!(message, {line, column}, state)
  end

  ## handle_attr_value_quote

  defp handle_attr_value_quote("\r\n" <> rest, delimiter, line, _column, buffer, state) do
    column = state.column_base
    handle_attr_value_quote(rest, delimiter, line + 1, column, ["\r\n" | buffer], state)
  end

  defp handle_attr_value_quote("\n" <> rest, delimiter, line, _column, buffer, state) do
    column = state.column_base
    handle_attr_value_quote(rest, delimiter, line + 1, column, ["\n" | buffer], state)
  end

  defp handle_attr_value_quote(
         <<delimiter, rest::binary>>,
         delimiter,
         line,
         column,
         buffer,
         _state
       ) do
    value = buffer_to_string(buffer)
    {rest, line, column + 1, {:string, value, %{delimiter: delimiter}}}
  end

  defp handle_attr_value_quote(<<c::utf8, rest::binary>>, delimiter, line, column, buffer, state) do
    handle_attr_value_quote(rest, delimiter, line, column + 1, [char_or_bin(c) | buffer], state)
  end

  defp handle_attr_value_quote(<<>>, delimiter, line, column, _buffer, state) do
    message = """
    expected closing `#{<<delimiter>>}` for attribute value

    Make sure the attribute is properly closed. This may also happen if
    there is an EEx interpolation inside a tag, which is not supported.
    Instead of

        <div <%= @attrs %>>
        </div>

    do

        <div {@attrs}>
        </div>

    Where @attrs must be a keyword list or a map.
    """

    raise_syntax_error!(message, {line, column}, state)
  end

  ## handle_attr_value_brace

  defp handle_attr_value_brace(text, line, column, state) do
    case handle_interpolation(text, line, column, [], 0, state) do
      {:ok, expr, new_line, new_column, rest} ->
        {rest, new_line, new_column, {:expr, expr, %{line: line, column: column}}}

      {:error, message} ->
        # use column - 1 to point to the opening {
        raise_syntax_error!(message, {line, column - 1}, state)
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
    expr = buffer_to_string(buffer)
    {:ok, expr, line, column + 1, rest}
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
     you may write it using `&lbrace;` or using `<%= "{" %>`.\
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

  defp put_attr([{type, name, attrs, meta} | rest], attr_name, attr_value, attr_meta) do
    new_attrs = [{attr_name, attr_value, attr_meta} | attrs]
    [{type, name, new_attrs, meta} | rest]
  end

  defp classify_tag_name(<<first, _::binary>> = name) when first in ?A..?Z do
    if valid_remote_component_name?(name),
      do: {:ok, {:remote_component, name}},
      else: {:error, "expected valid remote component name"}
  end

  defp classify_tag_name("."), do: {:error, "expected local component name after ."}

  defp classify_tag_name("." <> name) do
    if valid_local_component_name?(name),
      do: {:ok, {:local_component, name}},
      else: {:error, "expected valid local component name after ."}
  end

  defp classify_tag_name(":"), do: {:error, "expected slot name after :"}

  defp classify_tag_name(":inner_block"), do: {:error, "the slot name `:inner_block` is reserved"}

  defp classify_tag_name(":" <> name) do
    if valid_slot_name?(name),
      do: {:ok, {:slot, name}},
      else: {:error, "expected valid slot name after :"}
  end

  defp classify_tag_name(name), do: {:ok, {:htag, name}}

  @remote_component_name_pattern ~r/^[A-Z][a-zA-Z0-9_]*(\.[A-Z][a-zA-Z0-9_]*)*\.[a-z_][a-zA-Z0-9_]*[!?]?$/
  defp valid_remote_component_name?(name) do
    Regex.match?(@remote_component_name_pattern, name)
  end

  @local_component_name_pattern ~r/^[a-z_][a-zA-Z0-9_]*[!?]?$/
  defp valid_local_component_name?(name) do
    Regex.match?(@local_component_name_pattern, name)
  end

  @slot_name_pattern ~r/^[a-z_][a-zA-Z0-9_]*[!?]?$/
  defp valid_slot_name?(name) do
    Regex.match?(@slot_name_pattern, name)
  end

  for name <- ~w(area base br col hr img input link meta param command keygen source) do
    defp void_tag?(unquote(name)), do: true
  end

  defp void_tag?(_), do: false

  defp normalize_tag([{type, name, attrs, meta} | rest], line, column, self_closing?) do
    attrs = Enum.reverse(attrs)
    meta = %{meta | inner_location: {line, column}, self_closing?: self_closing?}
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

  defp raise_syntax_error!(message, {line, column}, state) do
    raise SyntaxError,
      file: state.file,
      line: line,
      column: column,
      description:
        message <> SyntaxError.code_snippet(state.source, {line, column}, state.indentation)
  end
end
