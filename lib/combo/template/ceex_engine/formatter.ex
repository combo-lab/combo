defmodule Combo.Template.CEExEngine.Formatter do
  @moduledoc false

  require Logger

  alias Combo.Template.CEExEngine.Formatter.HTMLAlgebra
  alias Combo.Template.CEExEngine.Tokenizer
  alias Combo.Template.CEExEngine.SyntaxError

  defguard is_tag_open(tag_type)
           when tag_type in [:html_tag, :remote_component, :local_component, :slot]

  # Default line length to be used in case nothing is specified in the `.formatter.exs` options.
  @default_line_length 98

  @behaviour Mix.Tasks.Format

  @impl true
  def features(_opts) do
    [sigils: [:CE], extensions: [".ceex"]]
  end

  @impl true
  def format(source, opts) do
    if opts[:sigil] === :CE and opts[:modifiers] === ~c"noformat" do
      source
    else
      line_length = opts[:ceex_line_length] || opts[:line_length] || @default_line_length
      newlines = :binary.matches(source, ["\r\n", "\n"])

      opts =
        Keyword.update(opts, :attribute_formatters, %{}, fn formatters ->
          Enum.reduce(formatters, %{}, fn {attr, formatter}, formatters ->
            if Code.ensure_loaded?(formatter) do
              Map.put(formatters, to_string(attr), formatter)
            else
              Logger.error("module #{inspect(formatter)} is not loaded and could not be found")
              formatters
            end
          end)
        end)

      formatted =
        source
        |> tokenize()
        |> to_tree([], [], %{source: {source, newlines}})
        |> case do
          {:ok, nodes} ->
            nodes
            |> HTMLAlgebra.build(opts)
            |> Inspect.Algebra.format(line_length)

          {:error, line, column, message} ->
            file = Keyword.get(opts, :file, "nofile")
            raise SyntaxError, line: line, column: column, file: file, description: message
        end

      # If the opening delimiter is a single character, such as ~CE"...", or the formatted code is empty,
      # do not add trailing newline.
      newline =
        if match?(<<_>>, opts[:opening_delimiter]) or formatted == [] or formatted == "",
          do: [],
          else: ?\n

      IO.iodata_to_binary([formatted, newline])
    end
  end

  # The following content:
  #
  # "<section>\n  <p><%= user.name ></p>\n  <%= if true do %> <p>this</p><% else %><p>that</p><% end %>\n</section>\n"
  #
  # Will be tokenized as:
  #
  # [
  #   {:html_tag, "section", [], %{column: 1, line: 1}},
  #   {:text, "\n  ", %{column_end: 3, line_end: 2}},
  #   {:html_tag, "p", [], %{column: 3, line: 2}},
  #   {:eex_tag_render, "<%= user.name ></p>\n  <%= if true do %>", %{block?: true, column: 6, line: 1}},
  #   {:text, " ", %{column_end: 2, line_end: 1}},
  #   {:html_tag, "p", [], %{column: 2, line: 1}},
  #   {:text, "this", %{column_end: 12, line_end: 1}},
  #   {:close, :html_tag, "p", %{column: 12, line: 1}},
  #   {:eex_tag, "<% else %>", %{block?: false, column: 35, line: 2}},
  #   {:html_tag, "p", [], %{column: 1, line: 1}},
  #   {:text, "that", %{column_end: 14, line_end: 1}},
  #   {:close, :html_tag, "p", %{column: 14, line: 1}},
  #   {:eex_tag, "<% end %>", %{block?: false, column: 62, line: 2}},
  #   {:text, "\n", %{column_end: 1, line_end: 2}},
  #   {:close, :html_tag, "section", %{column: 1, line: 2}}
  # ]
  #
  @eex_expr [:start_expr, :expr, :end_expr, :middle_expr]

  defp tokenize(source) do
    {:ok, eex_nodes} = EEx.tokenize(source)
    {tokens, cont} = Enum.reduce(eex_nodes, {[], {:text, :enabled}}, &do_tokenize(&1, &2, source))
    Tokenizer.finalize(tokens, cont, "nofile", source)
  end

  defp do_tokenize({:text, text, meta}, {tokens, cont}, source) do
    text = List.to_string(text)
    meta = [line: meta.line, column: meta.column]
    state = Tokenizer.init(source, "nofile", 0)
    Tokenizer.tokenize(text, meta, tokens, cont, state)
  end

  defp do_tokenize({:comment, text, meta}, {tokens, cont}, _contents) do
    {[{:eex_comment, List.to_string(text), meta} | tokens], cont}
  end

  defp do_tokenize({type, opt, expr, %{column: column, line: line}}, {tokens, cont}, _contents)
       when type in @eex_expr do
    meta = %{opt: opt, line: line, column: column}
    {[{:eex, type, expr |> List.to_string() |> String.trim(), meta} | tokens], cont}
  end

  defp do_tokenize(_node, acc, _contents) do
    acc
  end

  # Build an HTML Tree according to the tokens from the EEx and HTML tokenizers.
  #
  # This is a recursive algorithm that will build an HTML tree from a flat list of
  # tokens. For instance, given this input:
  #
  # [
  #   {:html_tag, "div", [], %{column: 1, line: 1}},
  #   {:html_tag, "h1", [], %{column: 6, line: 1}},
  #   {:text, "Hello", %{column_end: 15, line_end: 1}},
  #   {::close, :html_tag, "h1", %{column: 15, line: 1}},
  #   {::close, :html_tag, "div", %{column: 20, line: 1}},
  #   {:html_tag, "div", [], %{column: 1, line: 2}},
  #   {:html_tag, "h1", [], %{column: 6, line: 2}},
  #   {:text, "World", %{column_end: 15, line_end: 2}},
  #   {::close, :html_tag, "h1", %{column: 15, line: 2}},
  #   {::close, :html_tag, "div", %{column: 20, line: 2}}
  # ]
  #
  # The output will be:
  #
  # [
  #   {:tag_block, "div", [], [{:tag_block, "h1", [], [text: "Hello"]}]},
  #   {:tag_block, "div", [], [{:tag_block, "h1", [], [text: "World"]}]}
  # ]
  #
  # Note that a `tag_block` has been created so that its fourth argument is a list of
  # its nested content.
  #
  # ### How does this algorithm work?
  #
  # As this is a recursive algorithm, it starts with an empty buffer and an empty
  # stack. The buffer will be accumulated until it finds a `{:html_tag, ..., ...}`.
  #
  # As soon as the `tag_open` arrives, a new buffer will be started and we move
  # the previous buffer to the stack along with the `tag_open`:
  #
  #   ```
  #   defp build([{:html_tag, name, attrs, _meta} | tokens], buffer, stack) do
  #     build(tokens, [], [{name, attrs, buffer} | stack])
  #   end
  #   ```
  #
  # Then, we start to populate the buffer again until a `{:close, :html_tag, ...} arrives:
  #
  #   ```
  #   defp build([{:close, :html_tag, name, _meta} | tokens], buffer, [{name, attrs, upper_buffer} | stack]) do
  #     build(tokens, [{:tag_block, name, attrs, Enum.reverse(buffer)} | upper_buffer], stack)
  #   end
  #   ```
  #
  # In the snippet above, we build the `tag_block` with the accumulated buffer,
  # putting the buffer accumulated before the tag open (upper_buffer) on top.
  #
  # We apply the same logic for `eex` expressions but, instead of `tag_open` and
  # `tag_close`, eex expressions use `start_expr`, `middle_expr` and `end_expr`.
  # The only real difference is that also need to handle `middle_buffer`.
  #
  # So given this eex input:
  #
  # ```elixir
  # [
  #   {:eex, :start_expr, "if true do", %{column: 0, line: 0, opt: '='}},
  #   {:text, "\n  ", %{column_end: 3, line_end: 2}},
  #   {:eex, :expr, "\"Hello\"", %{column: 3, line: 1, opt: '='}},
  #   {:text, "\n", %{column_end: 1, line_end: 2}},
  #   {:eex, :middle_expr, "else", %{column: 1, line: 2, opt: []}},
  #   {:text, "\n  ", %{column_end: 3, line_end: 2}},
  #   {:eex, :expr, "\"World\"", %{column: 3, line: 3, opt: '='}},
  #   {:text, "\n", %{column_end: 1, line_end: 2}},
  #   {:eex, :end_expr, "end", %{column: 1, line: 4, opt: []}}
  # ]
  # ```
  #
  # The output will be:
  #
  # ```elixir
  # [
  #   {:eex_block, "if true do",
  #    [
  #      {[{:eex, "\"Hello\"", %{column: 3, line: 1, opt: '='}}], "else"},
  #      {[{:eex, "\"World\"", %{column: 3, line: 3, opt: '='}}], "end"}
  #    ]}
  # ]
  # ```
  defp to_tree([], buffer, [], _opts) do
    {:ok, Enum.reverse(buffer)}
  end

  defp to_tree([], _buffer, [{name, _, %{line: line, column: column}, _} | _], _opts) do
    message = "end of template reached without closing tag for <#{name}>"
    {:error, line, column, message}
  end

  defp to_tree([{:text, text, %{context: [:comment_start]}} | tokens], buffer, stack, opts) do
    to_tree(tokens, [], [{:comment, text, buffer} | stack], opts)
  end

  defp to_tree(
         [{:text, text, %{context: [:comment_end | _rest]}} | tokens],
         buffer,
         [{:comment, start_text, upper_buffer} | stack],
         opts
       ) do
    meta = %{
      newlines_before_text: count_newlines_before_text(text),
      newlines_after_text: count_newlines_after_text(text)
    }

    buffer = Enum.reverse([{:text, String.trim_trailing(text), meta} | buffer])
    text = {:text, String.trim_leading(start_text), %{}}
    to_tree(tokens, [{:html_comment, [text | buffer]} | upper_buffer], stack, opts)
  end

  defp to_tree(
         [{:text, text, %{context: [:comment_start, :comment_end]}} | tokens],
         buffer,
         stack,
         opts
       ) do
    meta = %{
      newlines_before_text: count_newlines_before_text(text),
      newlines_after_text: count_newlines_after_text(text)
    }

    to_tree(tokens, [{:html_comment, [{:text, String.trim(text), meta}]} | buffer], stack, opts)
  end

  defp to_tree([{:text, text, _meta} | tokens], buffer, stack, opts) do
    buffer = may_set_preserve_on_block(buffer, text)

    meta = %{
      newlines_before_text: count_newlines_before_text(text),
      newlines_after_text: count_newlines_after_text(text)
    }

    to_tree(tokens, [{:text, text, meta} | buffer], stack, opts)
  end

  defp to_tree([{:body_expr, value, meta} | tokens], buffer, stack, opts) do
    buffer = set_preserve_on_block(buffer)
    to_tree(tokens, [{:body_expr, value, meta} | buffer], stack, opts)
  end

  defp to_tree([{type, _name, attrs, %{closing: _} = meta} | tokens], buffer, stack, opts)
       when is_tag_open(type) do
    to_tree(tokens, [{:tag_self_close, meta.tag_name, attrs} | buffer], stack, opts)
  end

  defp to_tree([{type, _name, attrs, meta} | tokens], buffer, stack, opts)
       when is_tag_open(type) do
    to_tree(tokens, [], [{meta.tag_name, attrs, meta, buffer} | stack], opts)
  end

  defp to_tree(
         [{:close, _type, _name, close_meta} | tokens],
         reversed_buffer,
         [{tag_name, attrs, open_meta, upper_buffer} | stack],
         opts
       ) do
    {mode, block} =
      if tag_name in ["pre", "textarea"] or contains_special_attrs?(attrs) do
        content =
          content_from_source(opts.source, open_meta.inner_location, close_meta.inner_location)

        {:preserve, [{:text, content, %{newlines_before_text: 0, newlines_after_text: 0}}]}
      else
        {:normal, Enum.reverse(reversed_buffer)}
      end

    tag_block = {:tag_block, tag_name, attrs, block, %{mode: mode}}
    to_tree(tokens, [tag_block | upper_buffer], stack, opts)
  end

  # handle eex

  defp to_tree([{:eex_comment, text, _meta} | tokens], buffer, stack, opts) do
    to_tree(tokens, [{:eex_comment, text} | buffer], stack, opts)
  end

  defp to_tree([{:eex, :start_expr, expr, meta} | tokens], buffer, stack, opts) do
    to_tree(tokens, [], [{:eex_block, expr, meta, buffer} | stack], opts)
  end

  defp to_tree(
         [{:eex, :middle_expr, middle_expr, _meta} | tokens],
         buffer,
         [{:eex_block, expr, meta, upper_buffer, middle_buffer} | stack],
         opts
       ) do
    middle_buffer = [{Enum.reverse(buffer), middle_expr} | middle_buffer]
    to_tree(tokens, [], [{:eex_block, expr, meta, upper_buffer, middle_buffer} | stack], opts)
  end

  defp to_tree(
         [{:eex, :middle_expr, middle_expr, _meta} | tokens],
         buffer,
         [{:eex_block, expr, meta, upper_buffer} | stack],
         opts
       ) do
    middle_buffer = [{Enum.reverse(buffer), middle_expr}]
    to_tree(tokens, [], [{:eex_block, expr, meta, upper_buffer, middle_buffer} | stack], opts)
  end

  defp to_tree(
         [{:eex, :end_expr, end_expr, _meta} | tokens],
         buffer,
         [{:eex_block, expr, meta, upper_buffer, middle_buffer} | stack],
         opts
       ) do
    block = Enum.reverse([{Enum.reverse(buffer), end_expr} | middle_buffer])
    to_tree(tokens, [{:eex_block, expr, block, meta} | upper_buffer], stack, opts)
  end

  defp to_tree(
         [{:eex, :end_expr, end_expr, _meta} | tokens],
         buffer,
         [{:eex_block, expr, meta, upper_buffer} | stack],
         opts
       ) do
    block = [{Enum.reverse(buffer), end_expr}]
    to_tree(tokens, [{:eex_block, expr, block, meta} | upper_buffer], stack, opts)
  end

  defp to_tree([{:eex, _type, expr, meta} | tokens], buffer, stack, opts) do
    buffer = set_preserve_on_block(buffer)
    to_tree(tokens, [{:eex, expr, meta} | buffer], stack, opts)
  end

  # -- HELPERS

  defp count_newlines_before_text(binary),
    do: count_newlines_until_text(binary, 0, 0, 1)

  defp count_newlines_after_text(binary),
    do: count_newlines_until_text(binary, 0, byte_size(binary) - 1, -1)

  defp count_newlines_until_text(binary, counter, pos, inc) do
    try do
      :binary.at(binary, pos)
    rescue
      _ -> counter
    else
      char when char in [?\s, ?\t] -> count_newlines_until_text(binary, counter, pos + inc, inc)
      ?\n -> count_newlines_until_text(binary, counter + 1, pos + inc, inc)
      _ -> counter
    end
  end

  # In case the closing tag is immediatelly followed by non whitespace text,
  # we want to set mode as preserve.
  defp may_set_preserve_on_block([{:tag_block, name, attrs, block, meta} | list], text) do
    mode =
      if String.trim_leading(text) != "" and :binary.first(text) not in ~c"\s\t\n\r" do
        :preserve
      else
        meta.mode
      end

    [{:tag_block, name, attrs, block, %{meta | mode: mode}} | list]
  end

  defp may_set_preserve_on_block(buffer, _text), do: buffer

  # Set preserve on block when it is immediately followed by interpolation.
  defp set_preserve_on_block([{:tag_block, name, attrs, block, meta} | list]) do
    [{:tag_block, name, attrs, block, %{meta | mode: :preserve}} | list]
  end

  defp set_preserve_on_block(buffer), do: buffer

  defp contains_special_attrs?(attrs) do
    Enum.any?(attrs, fn
      {"contenteditable", {:string, "false", _meta}, _} -> false
      {"contenteditable", _v, _} -> true
      {"ceex-no-format", _v, _} -> true
      _ -> false
    end)
  end

  defp content_from_source(
         {source, newlines},
         {line_start, column_start},
         {line_end, column_end}
       ) do
    lines = Enum.slice([{0, 0} | newlines], (line_start - 1)..(line_end - 1))
    [first_line | _] = lines
    [last_line | _] = Enum.reverse(lines)

    offset_start = line_byte_offset(source, first_line, column_start)
    offset_end = line_byte_offset(source, last_line, column_end)

    binary_part(source, offset_start, offset_end - offset_start)
  end

  defp line_byte_offset(source, {line_before, line_size}, column) do
    line_offset = line_before + line_size

    line_extra =
      source
      |> binary_part(line_offset, byte_size(source) - line_offset)
      |> String.slice(0, column - 1)
      |> byte_size()

    line_offset + line_extra
  end
end
