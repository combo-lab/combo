defmodule Combo.Template.CEExEngine.Compiler.Engine do
  @moduledoc false

  alias Combo.Template.CEExEngine.Tokenizer
  alias Combo.Template.CEExEngine.SyntaxError
  alias Combo.Template.CEExEngine.TagHandler
  alias Combo.Template.CEExEngine.Compiler.IOBuilder
  alias Combo.Template.CEExEngine.Compiler.Attr
  alias Combo.Template.CEExEngine.Compiler.Assigns
  alias Combo.Template.CEExEngine.Compiler.DebugAnnotation

  @doc false
  def __reserved_assigns__, do: [:__slot__, :inner_block]

  @behaviour EEx.Engine

  @impl true
  def init(opts) do
    {iob, opts} = Keyword.pop(opts, :iob, IOBuilder)

    %{
      source: Keyword.fetch!(opts, :source),
      file: Keyword.get(opts, :file, "nofile"),
      indentation: Keyword.get(opts, :indentation, 0),
      caller: Keyword.fetch!(opts, :caller),
      # token scanning
      tokens: [],
      cont: {:text, :enabled},
      # token parsing
      iob: iob,
      iob_stack: [iob.init()]
    }
  end

  @impl true
  def handle_text(state, meta, text) do
    %{
      source: source,
      file: file,
      indentation: indentation,
      tokens: tokens,
      cont: cont
    } = state

    tokenizer_state = Tokenizer.init(source, file, indentation)
    {tokens, cont} = Tokenizer.tokenize(text, meta, tokens, cont, tokenizer_state)
    %{state | tokens: tokens, cont: cont}
  end

  @impl true
  def handle_expr(state, marker, expr) do
    %{tokens: tokens} = state
    %{state | tokens: [{:expr, marker, expr} | tokens]}
  end

  @impl true
  def handle_begin(state) do
    %{state | tokens: []}
  end

  @impl true
  def handle_end(state) do
    %{tokens: tokens} = state
    tokens = Enum.reverse(tokens)
    handle_tokens(state, "do-block", tokens)
  end

  @impl true
  def handle_body(state) do
    %{
      source: source,
      file: file,
      caller: caller,
      tokens: tokens,
      cont: cont
    } = state

    tokens = Tokenizer.finalize(tokens, file, cont, source)

    quoted = handle_tokens(state, "template", tokens)
    quoted = Assigns.traverse(quoted)

    quoted =
      if caller && DebugAnnotation.enable?() do
        %{module: mod, function: {fun, _}, file: file, line: line} = caller
        component_name = "#{inspect(mod)}.#{fun}"
        annotation = DebugAnnotation.build_annotation(component_name, file, line)
        annotate_block(quoted, annotation)
      else
        quoted
      end

    quote do
      require unquote(__MODULE__)

      _ = var!(assigns)
      unquote(quoted)
    end
  end

  ## Token parsing

  defp handle_tokens(state, context, tokens) do
    %{
      source: source,
      file: file,
      indentation: indentation,
      caller: caller,
      iob: iob,
      iob_stack: iob_stack
    } = state

    # Before parsing, a fresh new state of tokens is created.
    tokens_state = %{
      # These fields are static, so they are "always" fresh new.
      source: source,
      file: file,
      indentation: indentation,
      caller: caller,
      iob: iob,
      # Its value is copied from state, and no code will change state.iob_stack.
      # It's static, too. So, it's "always" fresh new.
      iob_stack: iob_stack,
      # These fields are set with new values. So they are "always" fresh new.
      tags: [],
      slots: []
    }

    tokens
    |> Enum.map(&preprocess_token(&1, tokens_state))
    |> then(&reduce_tokens(tokens_state, &1))
    |> validate_unclosed_tags!(context)
    |> iob_dump()
  end

  defp preprocess_token({t_type, _t_name, _t_attrs, _t_meta} = token, state)
       when t_type in [:html_tag, :remote_component, :local_component, :slot] do
    rules = [
      &remove_control_attr/3,
      &validate_attr!/3,
      &normalize_attr/3,
      &metafy_special_attr/3
    ]

    Enum.reduce(rules, token, fn rule, acc -> apply_rule(acc, rule, state) end)
  end

  defp preprocess_token(token, _state), do: token

  defp apply_rule({t_type, t_name, t_attrs, t_meta} = _token, rule, state) do
    {t_type, t_name, new_t_attrs, new_t_meta} =
      Enum.reduce(t_attrs, {t_type, t_name, [], t_meta}, fn attr, acc ->
        rule.(attr, acc, state)
      end)

    new_t_attrs = Enum.reverse(new_t_attrs)
    {t_type, t_name, new_t_attrs, new_t_meta}
  end

  defp remove_control_attr({"ceex-no-format", _, _}, token, _state),
    do: token

  defp remove_control_attr({"ceex-no-curly-interpolation", _, _}, token, _state),
    do: token

  defp remove_control_attr(attr, {t_type, t_name, t_attrs, t_meta}, _state),
    do: {t_type, t_name, [attr | t_attrs], t_meta}

  defp validate_attr!(
         {":" <> _ = _, _, _} = attr,
         {t_type, t_name, t_attrs, t_meta} = token,
         state
       ) do
    validate_supported_attr!(token, attr, state)
    validate_duplicated_attr!(token, attr, state)
    validate_attr_value!(token, attr, state)

    {t_type, t_name, [attr | t_attrs], t_meta}
  end

  defp validate_attr!(
         attr,
         {t_type, t_name, t_attrs, t_meta},
         _state
       ) do
    {t_type, t_name, [attr | t_attrs], t_meta}
  end

  defp validate_supported_attr!(
         {:html_tag = t_type, t_name, _, _},
         {":" <> _ = a_name, _, a_meta},
         state
       ) do
    if a_name in [":if", ":for"] do
      :ok
    else
      message =
        "unsupported attribute #{a_name} in #{humanize_t_type(t_type)}: #{t_name}"

      raise_syntax_error!(message, a_meta, state)
    end
  end

  defp validate_supported_attr!(
         {t_type, t_name, _, _},
         {":" <> _ = a_name, _, a_meta},
         state
       )
       when t_type in [:remote_component, :local_component, :slot] do
    if a_name in [":if", ":for", ":let"] do
      :ok
    else
      message =
        "unsupported attribute #{a_name} in #{humanize_t_type(t_type)}: #{t_name}"

      raise_syntax_error!(message, a_meta, state)
    end
  end

  defp validate_supported_attr!(_token, _attr, _state), do: :ok

  defp validate_duplicated_attr!({_, _, t_attrs, _}, {a_name, _, a_meta}, state)
       when a_name in [":if", ":for", ":let"] do
    case List.keyfind(t_attrs, a_name, 0) do
      nil ->
        :ok

      {_, _, dup_a_meta} ->
        message = """
        cannot define multiple #{a_name} attributes. \
        Another #{a_name} has already been defined at line #{dup_a_meta.line}\
        """

        raise_syntax_error!(message, a_meta, state)
    end
  end

  defp validate_duplicated_attr!(_token, _attr, _state), do: :ok

  defp validate_attr_value!({t_type, t_name, _, _}, {":if" = a_name, a_value, a_meta}, state) do
    case a_value do
      {:expr, _, _} ->
        :ok

      _ ->
        message =
          "#{a_name} must be an expression between {...} in #{humanize_t_type(t_type)}: #{t_name}"

        raise_syntax_error!(message, a_meta, state)
    end
  end

  defp validate_attr_value!({t_type, t_name, _, _}, {":for" = a_name, a_value, a_meta}, state) do
    case a_value do
      {:expr, source, v_meta} ->
        quoted = to_quoted!(source, v_meta, state)

        case quoted do
          {:<-, _, [_, _]} ->
            :ok

          _ ->
            message =
              "#{a_name} must be a generator expression (pattern <- enumerable) between {...} in #{humanize_t_type(t_type)}: #{t_name}"

            raise_syntax_error!(message, a_meta, state)
        end

      _ ->
        message =
          "#{a_name} must be an expression between {...} in #{humanize_t_type(t_type)}: #{t_name}"

        raise_syntax_error!(message, a_meta, state)
    end
  end

  defp validate_attr_value!(
         {t_type, t_name, _, t_meta},
         {":let" = a_name, a_value, a_meta},
         state
       ) do
    case a_value do
      {:expr, _, _} ->
        :ok

      _ ->
        message =
          "#{a_name} must be a pattern between {...} in #{humanize_t_type(t_type)}: #{t_name}"

        raise_syntax_error!(message, a_meta, state)
    end

    case t_meta do
      %{closing: :self} ->
        message =
          "cannot use #{a_name} on a #{humanize_t_type(t_type)} without inner content"

        raise_syntax_error!(message, a_meta, state)

      %{} ->
        :ok
    end
  end

  defp validate_attr_value!(_token, _attr, _state), do: :ok

  defp normalize_attr(
         {:root = a_name, {:expr, source, v_meta}, a_meta},
         {t_type, t_name, t_attrs, t_meta},
         state
       ) do
    quoted = to_quoted!(source, v_meta, state)
    # convert keyword list or map into map
    quoted = quote line: v_meta.line, do: Map.new(unquote(quoted))
    attr = {a_name, {:quoted, quoted, v_meta}, a_meta}
    {t_type, t_name, [attr | t_attrs], t_meta}
  end

  defp normalize_attr(
         {a_name, {:expr, source, v_meta}, a_meta},
         {t_type, t_name, t_attrs, t_meta},
         state
       ) do
    quoted = to_quoted!(source, v_meta, state)
    attr = {a_name, {:quoted, quoted, v_meta}, a_meta}
    {t_type, t_name, [attr | t_attrs], t_meta}
  end

  defp normalize_attr(
         {_a_name, {:string, _string, _v_meta}, _a_meta} = attr,
         {t_type, t_name, t_attrs, t_meta},
         _state
       ) do
    {t_type, t_name, [attr | t_attrs], t_meta}
  end

  defp normalize_attr(
         {_a_name, nil, _a_meta} = attr,
         {t_type, t_name, t_attrs, t_meta},
         _state
       ) do
    {t_type, t_name, [attr | t_attrs], t_meta}
  end

  defp metafy_special_attr(
         {":" <> _ = a_name, a_value, _a_meta} = _attr,
         {t_type, t_name, t_attrs, t_meta},
         _state
       )
       when a_name in [":if", ":for", ":let"] do
    key =
      case a_name do
        ":if" -> :if
        ":for" -> :for
        ":let" -> :let
      end

    new_t_meta = Map.put(t_meta, key, a_value)
    {t_type, t_name, t_attrs, new_t_meta}
  end

  defp metafy_special_attr(attr, {t_type, t_name, t_attrs, t_meta}, _state) do
    {t_type, t_name, [attr | t_attrs], t_meta}
  end

  defp reduce_tokens(state, []), do: state

  # text

  defp reduce_tokens(state, [{:text, text, _meta} | tokens]) do
    if text == "" do
      state
    else
      state
      |> iob_acc_text(text)
    end
    |> reduce_tokens(tokens)
  end

  # expr

  defp reduce_tokens(state, [{:expr, marker, quoted} | tokens]) do
    state
    |> iob_acc_expr(marker, quoted)
    |> reduce_tokens(tokens)
  end

  defp reduce_tokens(state, [{:body_expr, source, t_meta} | tokens]) do
    quoted = to_quoted!(source, t_meta, state)

    state
    |> iob_acc_expr(quoted)
    |> reduce_tokens(tokens)
  end

  # HTML tag (self-closing)

  defp reduce_tokens(
         state,
         [{:html_tag, name, attrs, %{closing: closing} = meta} = tag | tokens]
       ) do
    suffix = if closing == :void, do: ">", else: "></#{name}>"

    if should_wrap?(tag) do
      state =
        state
        |> iob_push_ctx()
        |> iob_acc_text("<#{name}")
        |> acc_attrs(attrs, meta)
        |> iob_acc_text(suffix)

      quoted =
        state
        |> iob_dump()
        |> wrap(tag)

      state
      |> iob_pop_ctx()
      |> iob_acc_expr(quoted)
    else
      state
      |> iob_acc_text("<#{name}")
      |> acc_attrs(attrs, meta)
      |> iob_acc_text(suffix)
    end
    |> reduce_tokens(tokens)
  end

  # HTML tag

  defp reduce_tokens(
         state,
         [{:html_tag, name, attrs, meta} = tag | tokens]
       ) do
    if should_wrap?(tag) do
      state
      |> push_tag(tag)
      |> iob_push_ctx()
      |> iob_acc_text("<#{name}")
      |> acc_attrs(attrs, meta)
      |> iob_acc_text(">")
    else
      state
      |> push_tag(tag)
      |> iob_acc_text("<#{name}")
      |> acc_attrs(attrs, meta)
      |> iob_acc_text(">")
    end
    |> reduce_tokens(tokens)
  end

  defp reduce_tokens(
         state,
         [{:close, :html_tag, name, _meta} = tag | tokens]
       ) do
    {open_tag, state} = pop_tag!(state, tag)

    if should_wrap?(open_tag) do
      state =
        state
        |> iob_acc_text("</#{name}>")

      quoted =
        state
        |> iob_dump()
        |> wrap(open_tag)

      state
      |> iob_pop_ctx()
      |> iob_acc_expr(quoted)
    else
      state
      |> iob_acc_text("</#{name}>")
    end
    |> reduce_tokens(tokens)
  end

  # remote component (self-closing)

  defp reduce_tokens(
         state,
         [{:remote_component, _name, _attrs, %{closing: :self} = meta} = tag | tokens]
       ) do
    mod_asf = decompose_remote_component_tag!(tag, state)
    mod = build_remote_component_module(mod_asf, meta, state)
    capture = build_remote_component_capture(mod_asf, meta)

    {assigns, attr_info} = build_self_closed_component_assigns(tag)
    {_mod_ast, _mod_size, fun} = mod_asf
    store_component_call(mod, fun, attr_info, [], meta.line, state)

    quoted =
      quote line: meta.line do
        unquote(__MODULE__).component(unquote(capture), unquote(assigns))
      end

    if should_wrap?(tag) do
      state =
        state
        |> iob_push_ctx()
        |> maybe_annotate_caller(meta)
        |> iob_acc_expr(quoted)

      quoted =
        state
        |> iob_dump()
        |> wrap(tag)

      state
      |> iob_pop_ctx()
      |> iob_acc_expr(quoted)
    else
      state
      |> maybe_annotate_caller(meta)
      |> iob_acc_expr(quoted)
    end
    |> reduce_tokens(tokens)
  end

  # remote component

  defp reduce_tokens(
         state,
         [{:remote_component = type, name, attrs, meta} = tag | tokens]
       ) do
    mod_asf = decompose_remote_component_tag!(tag, state)
    new_meta = meta |> Map.put(:mod_asf, mod_asf)
    new_tag = {type, name, attrs, new_meta}

    state
    |> push_tag(new_tag)
    |> init_slots()
    |> iob_push_ctx()
    |> reduce_tokens(tokens)
  end

  defp reduce_tokens(
         state,
         [{:close, :remote_component, _name, _meta} = tag | tokens]
       ) do
    {{:remote_component, _name, _attrs, meta} = open_tag, state} = pop_tag!(state, tag)
    %{mod_asf: {_mod_ast, _mod_size, fun} = mod_asf} = meta

    mod = build_remote_component_module(mod_asf, meta, state)
    capture = build_remote_component_capture(mod_asf, meta)

    {assigns, attr_info, slot_info, state} = build_component_assigns(open_tag, state)
    state = iob_pop_ctx(state)

    store_component_call(mod, fun, attr_info, slot_info, meta.line, state)

    quoted =
      quote line: meta.line do
        unquote(__MODULE__).component(unquote(capture), unquote(assigns))
      end
      |> tag_slots(slot_info)

    if should_wrap?(open_tag) do
      state =
        state
        |> iob_push_ctx()
        |> maybe_annotate_caller(meta)
        |> iob_acc_expr(quoted)

      quoted =
        state
        |> iob_dump()
        |> wrap(open_tag)

      state
      |> iob_pop_ctx()
      |> iob_acc_expr(quoted)
    else
      state
      |> maybe_annotate_caller(meta)
      |> iob_acc_expr(quoted)
    end
    |> reduce_tokens(tokens)
  end

  # local component (self-closing)

  defp reduce_tokens(
         state,
         [{:local_component, name, _attrs, %{closing: :self} = meta} = tag | tokens]
       ) do
    fun = String.to_atom(name)
    mod = build_local_component_module(state.caller, fun)
    capture = build_local_component_capture(fun, meta)

    {assigns, attr_info} = build_self_closed_component_assigns(tag)
    store_component_call(mod, fun, attr_info, [], meta.line, state)

    quoted =
      quote line: meta.line do
        unquote(__MODULE__).component(unquote(capture), unquote(assigns))
      end

    if should_wrap?(tag) do
      state =
        state
        |> iob_push_ctx()
        |> maybe_annotate_caller(meta)
        |> iob_acc_expr(quoted)

      quoted =
        state
        |> iob_dump()
        |> wrap(tag)

      state
      |> iob_pop_ctx()
      |> iob_acc_expr(quoted)
    else
      state
      |> maybe_annotate_caller(meta)
      |> iob_acc_expr(quoted)
    end
    |> reduce_tokens(tokens)
  end

  # local component

  defp reduce_tokens(
         state,
         [{:local_component, _name, _attrs, _meta} = tag | tokens]
       ) do
    state
    |> push_tag(tag)
    |> init_slots()
    |> iob_push_ctx()
    |> reduce_tokens(tokens)
  end

  defp reduce_tokens(
         state,
         [{:close, :local_component, name, _meta} = tag | tokens]
       ) do
    {{:local_component, _name, _attrs, meta} = open_tag, state} = pop_tag!(state, tag)

    fun = String.to_atom(name)
    mod = build_local_component_module(state.caller, fun)
    capture = build_local_component_capture(fun, meta)

    {assigns, attr_info, slot_info, state} = build_component_assigns(open_tag, state)
    state = iob_pop_ctx(state)

    store_component_call(mod, fun, attr_info, slot_info, meta.line, state)

    quoted =
      quote line: meta.line do
        unquote(__MODULE__).component(unquote(capture), unquote(assigns))
      end
      |> tag_slots(slot_info)

    if should_wrap?(open_tag) do
      state =
        state
        |> iob_push_ctx()
        |> maybe_annotate_caller(meta)
        |> iob_acc_expr(quoted)

      quoted =
        state
        |> iob_dump()
        |> wrap(open_tag)

      state
      |> iob_pop_ctx()
      |> iob_acc_expr(quoted)
    else
      state
      |> maybe_annotate_caller(meta)
      |> iob_acc_expr(quoted)
    end
    |> reduce_tokens(tokens)
  end

  # slot (self-closing)

  defp reduce_tokens(
         state,
         [{:slot, name, attrs, %{closing: :self} = meta} = tag | tokens]
       ) do
    validate_slot!(tag, state)

    slot_name = String.to_atom(name)
    %{line: line} = meta

    {roots, attrs, attr_info} = split_component_attrs(attrs)
    attrs = [{:__slot__, slot_name}, {:inner_block, nil} | attrs]
    assigns = wrap_slot(build_component_attrs(roots, attrs, line), tag)

    state
    |> add_slot(slot_name, assigns, attr_info, meta)
    |> reduce_tokens(prune_text_after_slot(tokens))
  end

  # slot

  defp reduce_tokens(
         state,
         [{:slot, _name, _attrs, _meta} = tag | tokens]
       ) do
    validate_slot!(tag, state)

    state
    |> push_tag(tag)
    |> iob_push_ctx()
    |> reduce_tokens(tokens)
  end

  defp reduce_tokens(
         state,
         [{:close, :slot, _name, _meta} = tag | tokens]
       ) do
    {{:slot, name, attrs, meta} = open_tag, state} = pop_tag!(state, tag)
    %{line: line} = meta

    slot_name = String.to_atom(name)

    {roots, attrs, attr_info} = split_component_attrs(attrs)
    clauses = build_component_clauses(slot_name, meta, state)

    inner_block =
      quote line: line do
        unquote(__MODULE__).build_inner_block(unquote(slot_name), do: unquote(clauses))
      end

    attrs = [{:__slot__, slot_name}, {:inner_block, inner_block} | attrs]
    assigns = wrap_slot(build_component_attrs(roots, attrs, line), open_tag)
    inner = add_inner_block(attr_info, inner_block, meta)

    state
    |> iob_pop_ctx()
    |> add_slot(slot_name, assigns, inner, meta)
    |> reduce_tokens(prune_text_after_slot(tokens))
  end

  defp validate_unclosed_tags!(%{tags: []} = state, _context) do
    state
  end

  defp validate_unclosed_tags!(%{tags: [tag | _]} = state, context) do
    {_t_type, _t_name, _t_attrs, t_meta} = tag
    message = "end of #{context} reached without closing tag for <#{t_meta.tag_name}>"
    raise_syntax_error!(message, t_meta, state)
  end

  ## Helpers

  # iob helpers

  defp iob_push_ctx(%{iob_stack: [current | _] = all} = state) do
    new = state.iob.reset(current)
    %{state | iob_stack: [new | all]}
  end

  defp iob_pop_ctx(%{iob_stack: [_ | rest]} = state) do
    %{state | iob_stack: rest}
  end

  defp iob_acc_text(%{iob_stack: [current | rest]} = state, text) do
    updated = state.iob.acc_text(current, text)
    %{state | iob_stack: [updated | rest]}
  end

  defp iob_acc_expr(%{iob_stack: [current | rest]} = state, marker \\ "=", expr) do
    updated = state.iob.acc_expr(current, marker, expr)
    %{state | iob_stack: [updated | rest]}
  end

  defp iob_dump(%{iob_stack: [current | _]} = state) do
    state.iob.dump(current)
  end

  # wrap helpers

  defp should_wrap?({_t_type, _t_name, _t_attrs, t_meta}) do
    Map.has_key?(t_meta, :if) or Map.has_key?(t_meta, :for)
  end

  defp wrap(quoted, {_t_type, _t_name, _t_attrs, t_meta}) do
    case t_meta do
      %{for: {:quoted, for_quoted, %{line: line}}, if: {:quoted, if_quoted, %{line: _line}}} ->
        quote line: line do
          for unquote(for_quoted), unquote(if_quoted), do: unquote(quoted)
        end

      %{for: {:quoted, for_quoted, %{line: line}}} ->
        quote line: line do
          for unquote(for_quoted), do: unquote(quoted)
        end

      %{if: {:quoted, if_quoted, %{line: line}}} ->
        quote line: line do
          if unquote(if_quoted), do: unquote(quoted)
        end

      %{} ->
        quoted
    end
  end

  # tag-tracking helpers

  defp push_tag(state, tag) do
    %{tags: tags} = state
    %{state | tags: [tag | tags]}
  end

  defp pop_tag!(
         %{tags: [{t_type, t_name, _t_attrs, _t_meta} = tag | tags]} = state,
         {:close, t_type, t_name, _t_close_meta}
       ) do
    {tag, %{state | tags: tags}}
  end

  defp pop_tag!(
         %{tags: [{t_type, t_name, _attrs, t_meta} | _]} = state,
         {:close, t_type, close_t_name, close_t_meta}
       ) do
    hint = closing_void_hint(close_t_name)

    message = """
    unmatched closing tag. Expected </#{t_name}> for <#{t_name}> \
    at line #{t_meta.line}, got: </#{close_t_name}>#{hint}\
    """

    raise_syntax_error!(message, close_t_meta, state)
  end

  defp pop_tag!(state, {:close, _t_type, _t_name, t_meta}) do
    %{tag_name: tag_name} = t_meta
    hint = closing_void_hint(tag_name)
    message = "missing opening tag for </#{tag_name}>#{hint}"
    raise_syntax_error!(message, t_meta, state)
  end

  defp closing_void_hint(tag_name) do
    if TagHandler.void_tag?(tag_name) do
      " (note <#{tag_name}> is a void tag and cannot have any content)"
    else
      ""
    end
  end

  # tag helpers

  defp acc_attrs(state, t_attrs, t_meta) do
    Enum.reduce(t_attrs, state, fn
      {:root, {:quoted, quoted, _}, _a_meta}, state ->
        state |> acc_quoted_attr({:global, quoted}, t_meta)

      {name, {:quoted, quoted, _}, _a_meta}, state ->
        state |> acc_quoted_attr({:local, name, quoted}, t_meta)

      {name, {:string, value, %{delimiter: ?"}}, _a_meta}, state ->
        state |> iob_acc_text(~s| #{name}="#{value}"|)

      {name, {:string, value, %{delimiter: ?'}}, _a_meta}, state ->
        state |> iob_acc_text(~s| #{name}='#{value}'|)

      {name, nil, _a_meta}, state ->
        state |> iob_acc_text(" #{name}")
    end)
  end

  defp acc_quoted_attr(state, pattern, meta) do
    case Attr.handle_attr(pattern, meta) do
      {:attr, name, quoted} ->
        state
        |> iob_acc_text(~s| #{name}="|)
        |> then(fn state ->
          # It is safe to List.wrap/1 because if we receive nil,
          # it would become the interpolation of nil, which is an
          # empty string anyway.
          Enum.reduce(List.wrap(quoted), state, fn
            binary, acc when is_binary(binary) ->
              acc |> iob_acc_text(binary)

            quoted, acc ->
              acc |> iob_acc_expr(quoted)
          end)
        end)
        |> iob_acc_text(~s|"|)

      {:quoted, quoted} ->
        state |> iob_acc_expr(quoted)
    end
  end

  # component helpers

  defp decompose_remote_component_tag!({:remote_component, t_name, _t_attrs, t_meta}, state) do
    case t_name |> String.split(".") |> Enum.reverse() do
      [<<first, _::binary>> = fun_name | rest] when first in ?a..?z ->
        %{line: line, column: column} = t_meta
        aliases = rest |> Enum.reverse() |> Enum.map(&String.to_atom/1)
        mod_ast = {:__aliases__, [line: line, column: column], aliases}
        mod_size = Enum.sum(Enum.map(rest, &byte_size/1)) + length(rest) + 1
        fun = String.to_atom(fun_name)
        {mod_ast, mod_size, fun}

      _ ->
        message = "invalid tag <#{t_name}>"
        raise_syntax_error!(message, t_meta, state)
    end
  end

  defp build_remote_component_module({mod_ast, _mod_size, _fun} = _mod_asf, t_meta, state) do
    %{caller: caller} = state
    %{line: line} = t_meta
    Macro.expand(mod_ast, %{caller | line: line})
  end

  defp build_remote_component_capture({mod_ast, mod_size, fun} = _mod_asf, t_meta)
       when is_atom(fun) do
    %{line: line, column: column} = t_meta
    meta = [line: line, column: column + mod_size]
    name = {{:., meta, [mod_ast, fun]}, meta, []}
    quote(do: &(unquote(name) / 1))
  end

  defp build_local_component_module(caller, fun) do
    case Macro.Env.lookup_import(caller, {fun, 1}) do
      [{_, module} | _] -> module
      _ -> caller.module
    end
  end

  defp build_local_component_capture(fun, t_meta)
       when is_atom(fun) do
    %{line: line, column: column} = t_meta
    meta = [line: line, column: column]
    name = {fun, meta, __MODULE__}
    quote(do: &(unquote(name) / 1))
  end

  # slot helpers

  defp validate_slot!({:slot, _, _, _}, %{tags: [{parent_type, _, _, _} | _]})
       when parent_type in [:remote_component, :local_component] do
    :ok
  end

  defp validate_slot!({:slot, name, _, meta}, state) do
    message =
      "invalid slot entry <:#{name}>. A slot entry must be a direct child of a component"

    raise_syntax_error!(message, meta, state)
  end

  defp init_slots(state) do
    %{slots: all} = state
    %{state | slots: [[] | all]}
  end

  defp add_slot(state, slot_name, slot_assigns, slot_info, meta) do
    special_attrs =
      meta
      |> Map.take([:if, :for, :let])
      |> Enum.map(fn {k, {:quoted, quoted, v_meta}} ->
        {inspect(k), {quoted, v_meta}}
      end)
      |> Map.new()

    %{slots: [slots | rest]} = state
    slot = {slot_name, slot_assigns, special_attrs, {meta, slot_info}}
    %{state | slots: [[slot | slots] | rest]}
  end

  defp pop_slots(%{slots: [slots | rest]} = state) do
    # Perform group_by by hand as we need to group two distinct maps.
    {acc_assigns, acc_info, specials} =
      Enum.reduce(slots, {%{}, %{}, %{}}, fn {key, assigns, special, info},
                                             {acc_assigns, acc_info, specials} ->
        special? = Map.has_key?(special, ":if") or Map.has_key?(special, ":for")
        specials = Map.update(specials, key, special?, &(&1 or special?))

        case acc_assigns do
          %{^key => existing_assigns} ->
            acc_assigns = %{acc_assigns | key => [assigns | existing_assigns]}
            %{^key => existing_info} = acc_info
            acc_info = %{acc_info | key => [info | existing_info]}
            {acc_assigns, acc_info, specials}

          %{} ->
            {Map.put(acc_assigns, key, [assigns]), Map.put(acc_info, key, [info]), specials}
        end
      end)

    acc_assigns =
      Enum.into(acc_assigns, %{}, fn {key, assigns_ast} ->
        cond do
          # No special entry, return it as a list
          not Map.fetch!(specials, key) ->
            {key, assigns_ast}

          # We have a special entry and multiple entries, we have to flatten
          match?([_, _ | _], assigns_ast) ->
            {key, quote(do: List.flatten(unquote(assigns_ast)))}

          # A single special entry is guaranteed to return a list from the expression
          true ->
            {key, hd(assigns_ast)}
        end
      end)

    {Map.to_list(acc_assigns), Map.to_list(acc_info), %{state | slots: rest}}
  end

  defp prune_text_after_slot([{:text, text, meta} | tokens]) do
    [{:text, String.trim_leading(text), meta} | tokens]
  end

  defp prune_text_after_slot(tokens) do
    tokens
  end

  defp add_inner_block({roots?, attrs, locs}, ast, tag_meta) do
    {roots?, [{:inner_block, ast} | attrs], [line_column(tag_meta) | locs]}
  end

  defp tag_slots({call, meta, args}, slot_info) do
    {call, [slots: Keyword.keys(slot_info)] ++ meta, args}
  end

  defp wrap_slot(quoted, {_t_type, _t_name, _t_attrs, t_meta}) do
    case t_meta do
      %{for: {:quoted, for_quoted, %{line: line}}, if: {:quoted, if_quoted, %{line: _line}}} ->
        quote line: line do
          for unquote(for_quoted), unquote(if_quoted), do: unquote(quoted)
        end

      %{for: {:quoted, for_quoted, %{line: line}}} ->
        quote line: line do
          for unquote(for_quoted), do: unquote(quoted)
        end

      %{if: {:quoted, if_quoted, %{line: line}}} ->
        quote line: line do
          if unquote(if_quoted), do: [unquote(quoted)], else: []
        end

      %{} ->
        quoted
    end
  end

  defp build_self_closed_component_assigns({_type, _name, attrs, meta} = _tag) do
    %{line: line} = meta
    {roots, attrs, attr_info} = split_component_attrs(attrs)
    {build_component_attrs(roots, attrs, line), attr_info}
  end

  defp build_component_assigns({_type, _name, attrs, meta}, state) do
    %{line: line} = meta

    {roots, attrs, attr_info} = split_component_attrs(attrs)
    slot_name = :inner_block

    # This slot is the default slot, the meta points to the component.
    clauses = build_component_clauses(slot_name, meta, state)

    inner_block =
      quote line: line do
        unquote(__MODULE__).build_inner_block(:inner_block, do: unquote(clauses))
      end

    inner_block_assigns =
      quote line: line do
        %{
          __slot__: :inner_block,
          inner_block: unquote(inner_block)
        }
      end

    {slot_assigns, slot_info, state} = pop_slots(state)

    slot_info = [
      {:inner_block, [{meta, add_inner_block({false, [], []}, inner_block, meta)}]}
      | slot_info
    ]

    attrs = attrs ++ [{:inner_block, [inner_block_assigns]} | slot_assigns]
    {build_component_attrs(roots, attrs, line), attr_info, slot_info, state}
  end

  defp split_component_attrs(attrs) do
    {roots, attrs, locs} =
      attrs
      |> Enum.reverse()
      |> Enum.reduce(
        {[], [], []},
        &split_component_attr(&1, &2)
      )

    {roots, attrs, {roots != [], attrs, locs}}
  end

  defp split_component_attr(
         {:root, {:quoted, quoted, _}, _attr_meta},
         {r, a, locs}
       ) do
    {[quoted | r], a, locs}
  end

  defp split_component_attr(
         {name, {:quoted, quoted, _}, attr_meta},
         {r, a, locs}
       ) do
    {r, [{String.to_atom(name), quoted} | a], [line_column(attr_meta) | locs]}
  end

  defp split_component_attr(
         {name, {:string, value, _meta}, attr_meta},
         {r, a, locs}
       ) do
    {r, [{String.to_atom(name), value} | a], [line_column(attr_meta) | locs]}
  end

  defp split_component_attr(
         {name, nil, attr_meta},
         {r, a, locs}
       ) do
    {r, [{String.to_atom(name), true} | a], [line_column(attr_meta) | locs]}
  end

  defp line_column(%{line: line, column: column}), do: {line, column}

  defp build_component_attrs(roots, attrs, line) do
    entries =
      case {roots, attrs} do
        {[], []} -> [{:%{}, [], []}]
        {_, []} -> roots
        {_, _} -> roots ++ [{:%{}, [], attrs}]
      end

    Enum.reduce(entries, fn expr, acc ->
      quote line: line, do: Map.merge(unquote(acc), unquote(expr))
    end)
  end

  defp build_component_clauses(slot_name, meta, state) do
    quoted = iob_dump(state)

    %{caller: caller} = state

    quoted =
      if caller && DebugAnnotation.enable?() do
        %{file: file} = caller
        %{line: line} = meta
        annotation = DebugAnnotation.build_annotation(":#{slot_name}", file, line)
        annotate_block(quoted, annotation)
      else
        quoted
      end

    case meta[:let] do
      # If we have a var, we can skip the catch-all clause
      {:quoted, {var, _, ctx} = pattern, %{line: line}} when is_atom(var) and is_atom(ctx) ->
        quote line: line do
          unquote(pattern) -> unquote(quoted)
        end

      {:quoted, pattern, %{line: line}} ->
        quote line: line do
          unquote(pattern) -> unquote(quoted)
        end ++
          quote line: line, generated: true do
            other ->
              unquote(__MODULE__).__unmatched_let__!(
                unquote(Macro.to_string(pattern)),
                other
              )
          end

      _ ->
        quote do
          _ -> unquote(quoted)
        end
    end
  end

  defp store_component_call(mod, fun, attr_info, slot_info, line, %{caller: caller} = state) do
    component = {mod, fun}
    module = caller.module

    if module && Module.open?(module) do
      {root?, attrs, locs} = attr_info
      pruned_attrs = attrs_for_call(attrs, locs)

      pruned_slots =
        for {slot_name, slot_values} <- slot_info, into: %{} do
          values =
            for {tag_meta, {root?, attrs, locs}} <- slot_values do
              %{line: tag_meta.line, root: root?, attrs: attrs_for_call(attrs, locs)}
            end

          {slot_name, values}
        end

      call = %{
        component: component,
        attrs: pruned_attrs,
        slots: pruned_slots,
        file: state.file,
        line: line,
        root: root?
      }

      # This may still fail under a very specific scenario where
      # we are defining a template dynamically inside a function
      # (most likely a test) that starts running while the module
      # is still open.
      try do
        Module.put_attribute(module, :__components_calls__, call)
      rescue
        _ -> :ok
      end
    end
  end

  defp attrs_for_call(attrs, locs) do
    for {{attr, value}, {line, column}} <- Enum.zip(attrs, locs),
        do: {attr, {line, column, attr_type(value)}},
        into: %{}
  end

  defp attr_type({:<<>>, _, _} = value), do: {:string, value}
  defp attr_type(value) when is_list(value), do: {:list, value}
  defp attr_type(value = {:%{}, _, _}), do: {:map, value}
  defp attr_type(value) when is_binary(value), do: {:string, value}
  defp attr_type(value) when is_integer(value), do: {:integer, value}
  defp attr_type(value) when is_float(value), do: {:float, value}
  defp attr_type(value) when is_boolean(value), do: {:boolean, value}
  defp attr_type(value) when is_atom(value), do: {:atom, value}
  defp attr_type({:fn, _, [{:->, _, [args, _]}]}), do: {:fun, length(args)}
  defp attr_type({:&, _, [{:/, _, [_, arity]}]}), do: {:fun, arity}

  # this could be a &myfun(&1, &2)
  defp attr_type({:&, _, args}) do
    {_ast, arity} =
      Macro.prewalk(args, 0, fn
        {:&, _, [n]} = ast, acc when is_integer(n) ->
          {ast, max(n, acc)}

        ast, acc ->
          {ast, acc}
      end)

    (arity > 0 && {:fun, arity}) || :any
  end

  defp attr_type(_value), do: :any

  ## Helpers

  defp raise_syntax_error!(message, meta, state) do
    raise SyntaxError,
      file: state.file,
      line: meta.line,
      column: meta.column,
      description: message <> SyntaxError.code_snippet(state.source, meta, state.indentation)
  end

  defp maybe_annotate_caller(state, meta) do
    %{file: file} = state
    %{line: line} = meta

    if DebugAnnotation.enable?() do
      annotation = DebugAnnotation.build_caller_annotation(file, line)
      state |> iob_acc_text(annotation)
    else
      state
    end
  end

  defp annotate_block({:__block__, meta, block}, {anno_begin, anno_end}) do
    {dynamic, [{:safe, binary}]} = Enum.split(block, -1)

    binary =
      case binary do
        [] ->
          ["#{anno_begin}#{anno_end}"]

        [_ | _] ->
          [to_string(anno_begin) | binary] ++ [to_string(anno_end)]
      end

    {:__block__, meta, dynamic ++ [{:safe, binary}]}
  end

  defp to_quoted!(source, %{line: line, column: column} = _meta, %{file: file} = _state)
       when is_binary(source) do
    Code.string_to_quoted!(source, line: line, column: column, file: file)
  end

  defp humanize_t_type(:html_tag), do: "tag"
  defp humanize_t_type(:remote_component), do: "remote component"
  defp humanize_t_type(:local_component), do: "local component"
  defp humanize_t_type(:slot), do: "slot"

  @doc false
  def __unmatched_let__!(pattern, value) do
    message = """
    cannot match arguments sent from render_slot/2 against the pattern in :let.

    Expected a value matching `#{pattern}`, got: #{inspect(value)}\
    """

    stacktrace =
      self()
      |> Process.info(:current_stacktrace)
      |> elem(1)
      |> Enum.drop(2)

    reraise(message, stacktrace)
  end

  @doc """
  Define a inner block, generally used by slots.

  This macro is mostly used by custom HTML engines that provide
  a `slot` implementation and rarely called directly. The
  `name` must be the assign name the slot/block will be stored
  under.

  If you're using CEEx templates, you should use its higher
  level `<:slot>` notation instead.
  """
  defmacro build_inner_block(_name, do: do_block) do
    case do_block do
      [{:->, meta, _} | _] ->
        inner_fun = {:fn, meta, do_block}

        quote do
          fn arg ->
            _ = var!(assigns)
            unquote(inner_fun).(arg)
          end
        end

      _ ->
        quote do
          fn arg ->
            _ = var!(assigns)
            unquote(do_block)
          end
        end
    end
  end

  @doc """
  Renders a component defined by the given function.

  This function is rarely invoked directly by users. Instead, it is used by
  this engine when rendering components. For example:

  ```ceex
  <MyApp.Weather.city name="Kraków" />
  ```

  Is the same as:

  ```ceex
  <%= component(
        &MyApp.Weather.city/1,
        [name: "Kraków"],
        {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
      ) %>
  ```

  """
  def component(fun, assigns)
      when is_function(fun, 1) and (is_map(assigns) or is_list(assigns)) do
    assigns =
      case assigns do
        %{} -> assigns
        _ -> Map.new(assigns)
      end

    case fun.(assigns) do
      {:safe, data} when is_list(data) or is_binary(data) ->
        {:safe, data}

      other ->
        raise RuntimeError, """
        expected #{inspect(fun)} to return a tuple {:safe, iodata()}

        Ensure the component defines its template with CEEx.

        Got:

            #{inspect(other)}
        """
    end
  end
end
