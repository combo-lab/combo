defmodule Combo.HTML.Components do
  @moduledoc false

  use Combo.HTML
  alias Combo.SafeHTML

  @doc """
  Renders an anchor element.

  [INSERT ASSIGNS_DOCS]

  ## Examples

  ```ceex
  <.a href={~p"/"}>home</.a>
  ```

  ```ceex
  <.a href={URI.parse("https://elixir-lang.org")}>Elixir</.a>
  ```

  ```ceex
  <.a href="/the_world" method="delete" data-confirm="Really?">delete</.a>
  ```

  ### Data attributes

  The following data attributes are supported:

    * `data-confirm` - shows a confirmation prompt before navigating to the
      destination.

  ## JavaScript dependency

  In order to support anchors where `:method` is not `"get"` or use the
  `data-confirm` attribute, JavaScript dependency must be loaded:

  ```javascript
  import html from `combo/html`

  html.init()
  ```

  To customize the default behaviour of the JavaScript dependency, check
  out the doc of `combo/html`.

  ## CSRF Protection

  By default, CSRF tokens are generated through `Plug.CSRFProtection`.
  """
  @doc type: :component
  attr :method, :string,
    default: "get",
    doc: """
    The HTTP method to use for navigating.

    In case the method is not `get`, JavaScript dependency must be loaded.
    """

  attr :href, :any,
    doc: """
    The destination to navigate to.
    """

  attr :csrf_token, :any,
    default: true,
    doc: """
    A boolean or custom token to use for anchors with an HTTP method other than `get`.
    """

  attr :rest, :global,
    include: ~w(download hreflang referrerpolicy rel target type),
    doc: """
    Additional attributes added to the `a` tag.
    """

  slot :inner_block,
    required: true,
    doc: """
    The content rendered inside of the `a` tag.
    """

  def a(%{href: href} = assigns) when href != "#" and not is_nil(href) do
    href = valid_destination!(href, "<.a>")
    assigns = assign(assigns, :href, href)

    ~CE"""
    <a
      href={@href}
      data-method={if @method != "get", do: @method}
      data-csrf={if @method != "get", do: csrf_token(@csrf_token, @href)}
      data-to={if @method != "get", do: @href}
      ceex-no-format
      {@rest}
    >{render_slot(@inner_block)}</a>
    """
  end

  def a(%{} = assigns) do
    ~CE"""
    <a href="#" {@rest}>{render_slot(@inner_block)}</a>
    """
  end

  defp valid_destination!(%URI{} = uri, context) do
    valid_destination!(URI.to_string(uri), context)
  end

  defp valid_destination!({:safe, to}, context) do
    {:safe, valid_string_destination!(IO.iodata_to_binary(to), context)}
  end

  defp valid_destination!({other, to}, _context) when is_atom(other) do
    [Atom.to_string(other), ?:, to]
  end

  defp valid_destination!(to, context) do
    valid_string_destination!(IO.iodata_to_binary(to), context)
  end

  @valid_uri_schemes [
    "http:",
    "https:",
    "ftp:",
    "ftps:",
    "mailto:",
    "news:",
    "irc:",
    "gopher:",
    "nntp:",
    "feed:",
    "telnet:",
    "mms:",
    "rtsp:",
    "svn:",
    "tel:",
    "fax:",
    "xmpp:"
  ]

  for scheme <- @valid_uri_schemes do
    defp valid_string_destination!(unquote(scheme) <> _ = string, _context), do: string
  end

  defp valid_string_destination!(to, context) do
    if not match?("/" <> _, to) and String.contains?(to, ":") do
      raise ArgumentError, """
      unsupported scheme given to #{context}. In case you want to link to an
      unknown or unsafe scheme, such as javascript, use a tuple: {:javascript, rest}
      """
    else
      to
    end
  end

  defp csrf_token(true, href), do: Plug.CSRFProtection.get_csrf_token_for(href)
  defp csrf_token(false, _href), do: nil
  defp csrf_token(csrf, _href) when is_binary(csrf), do: csrf

  @doc """
  Transforms various data structures to a `%Combo.HTML.Form{}` struct for use
  with the `form/1` component.

  The various data structures must implement `Combo.HTML.FormData` protocol.

  > Combo implements `Combo.HTML.FormData` protocol for maps.
  >
  > And, `combo_ecto` implements `Combo.HTML.FormData` protocol for
  > `%Ecto.Changeset{}` structs.

  ## Options

    * `:as` - the `name` prefix to be used in form inputs
    * `:id` - the `id` prefix to be used in form inputs
    * `:errors` - the keyword list of errors (used by maps exclusively)
    * `:action` - the action that was taken against the form. This value can be
      used to distinguish between different operations such as the user typing
      into a form for validation, or submitting a form for a database insert.
      For example: `to_form(changeset, action: :validate)`,
      or `to_form(changeset, action: :save)`. The provided action is passed
      to the underlying `Combo.HTML.FormData` implementation options.

  ### Overriding options

  If an existing `%Combo.HTML.Form{}` is passed, the given options will override
  its existing values if given. Then the remaining options are merged with the
  existing form options.

      to_form(form, as: "new-name")

  ### About `:errors` option

  The `:errors` option is used by maps exclusively.

  `:errors` is a keyword of tuples in the shape of `{error_message, options_list}`.
  Here is an example:

      to_form(%{"search" => nil}, errors: [search: {"Can't be blank", []}])

  ### About showing errors

  Errors in a form are only displayed if the changeset's `action` field is set
  (and it is not set to `:ignore`) and can be filtered by whether the fields
  have been used on the client or not.
  Refer to [a note on :errors for more information](#form/1-a-note-on-errors).

  ## Examples

  ### Building a form from the params of controller's action

  To build it, you could do:

      def edit(conn, params) do
        form = to_form(params)
        # ...
      end

  Above code passes a map to `to_form/2`, and it assumes given map contains
  the form parameters, which are expected to have string keys.

  You can also use the nested params:

      def edit(conn, %{"user" => user_params}) do
        form = to_form(user_params)
        # ...
      end

  ### Building a form from Ecto changesets

  When using changesets, the underlying data, form parameters, and errors
  are retrieved from it. The `:as` option is automatically computed too.
  For example, if you have a user schema:

      defmodule Demo.Users.User do
        use Ecto.Schema

        schema "..." do
          ...
        end
      end

  And then you create a changeset that you pass to `to_form/2`:

      %Demo.Users.User{}
      |> Ecto.Changeset.change()
      |> to_form()

  In this case, once the form is submitted, the parameters will be available
  under `%{"user" => user_params}`.

  ### Using the built form

  The form can be passed to the `<.form>` component:

  ```ceex
  <.form for={@form} :let={f} id="todo-form">
    <.input field={f[:name]} type="text" />
  </.form>
  ```
  """
  def to_form(data_or_params, options \\ [])

  def to_form(%Combo.HTML.Form{} = data, []) do
    data
  end

  def to_form(%Combo.HTML.Form{} = data, options) do
    data =
      case Keyword.fetch(options, :as) do
        {:ok, as} ->
          name = if as == nil, do: as, else: to_string(as)
          %{data | name: name, id: Keyword.get(options, :id) || name}

        :error ->
          case Keyword.fetch(options, :id) do
            {:ok, id} -> %{data | id: id}
            :error -> data
          end
      end

    {options, data} =
      Enum.reduce(options, {data.options, data}, fn
        {:as, _as}, {options, data} -> {options, data}
        {:action, action}, {options, data} -> {options, %{data | action: action}}
        {:errors, errors}, {options, data} -> {options, %{data | errors: errors}}
        {key, value}, {options, data} -> {[{key, value} | Keyword.delete(options, key)], data}
      end)

    %{data | options: options}
  end

  def to_form(data, options) do
    if is_atom(data) do
      IO.warn("""
      Passing an atom to "for" in the form component is deprecated.
      Instead of:

          <.form :let={f} for={#{inspect(data)}} ...>

      You might do:

          <.form :let={f} for={%{}} as={#{inspect(data)}} ...>

      Or, if you prefer, use to_form to create a form in your template:

          assign(:form, to_form(%{}, as: #{inspect(data)}))

      and then use it in your templates (no :let required):

          <.form for={@form}>
      """)
    end

    Combo.HTML.FormData.to_form(data, options)
  end

  @doc ~S'''
  Renders a form element.

  [INSERT ASSIGNS_DOCS]

  ## Examples

  This component is typically called with `for={@form}`, where `@form` is built
  using the `to_form/2` function. For example:

  ```ceex
  <.form for={@form} action={~p"/path"}>
    <.input field={@form[:email]} />
  </.form>
  ```

  ### Using the `:let` attribute

  The form passed to `for` attribute can be captured using `:let` attribute:

  ```ceex
  <.form for={@form} :let={f} action={~p"/path"}>
    <.input field={f[:email]} />
  </.form>
  ```

  ## A note on `:errors`

  Even if `changeset.errors` is non-empty, errors will not be displayed in a
  form if [the changeset
  `:action`](https://hexdocs.pm/ecto/Ecto.Changeset.html#module-changeset-actions)
  is `nil` or `:ignore`.

  This is useful for things like validation hints on form fields, e.g. an empty
  changeset for a new form. That changeset isn't valid, but we don't want to
  show errors until an actual user action has been performed.

  For example, if the user submits and a `Repo.insert` is called and fails on
  changeset validation, the action will be set to `:insert` to show that an
  insert was attempted, and the presence of that action will cause errors to be
  displayed. The same is true for `Repo.update` and `Repo.delete`.

  Error visibility is handled by providing the action to `to_form/2`, which will
  set the underlying changeset action. You can also set the action manually by
  directly updating on the `Ecto.Changeset` struct field, or by using
  `Ecto.Changeset.apply_action/2`. Since the action can be arbitrary, you can
  set it to `:validate` or anything else to avoid giving the impression that a
  database operation has actually been attempted.

  ## CSRF protection

  CSRF protection is a mechanism to ensure that the user who rendered
  the form is the one actually submitting it. This module generates a
  CSRF token by default. Your application should check this token on
  the server to avoid attackers from making requests on your server on
  behalf of other users. Combo by default checks this token.

  When posting a form with a host in its address, such as "//host.com/path"
  instead of only "/path", Combo will include the host signature in the
  token and validate the token only if the accessed host is the same as
  the host in the token. This is to avoid tokens from leaking to third
  party applications. If this behaviour is problematic, you can generate
  a non-host specific token with `Plug.CSRFProtection.get_csrf_token/0` and
  pass it to the form generator via the `:csrf_token` option.
  '''
  @doc type: :component
  attr :for, :any,
    required: true,
    doc: "A `%Combo.HTML.Form{}` or the form source data."

  attr :action, :string,
    doc: """
    The action to submit the form on.
    """

  attr :as, :atom,
    doc: """
    The prefix to be used in names and IDs generated by the form.
    For example, setting `as: :user_params` means the parameters
    will be nested "user_params" in `conn.params["user_params"]` for
    regular HTTP requests.
    If you set this option, you must capture the form with `:let`.
    """

  attr :csrf_token, :any,
    doc: """
    A token to authenticate the validity of requests.
    One is automatically generated when an action is given and the method is
    not `get`. When set to `false`, no token is generated.
    """

  attr :errors, :list,
    doc: """
    Use this to manually pass a keyword list of errors to the form.
    This option is useful when a regular map is given as the form
    source and it will make the errors available under `f.errors`.
    If you set this option, you must capture the form with `:let`.
    """

  attr :method, :string,
    doc: """
    The HTTP method.
    It is only used if an `:action` is given. If the method is not `get`
    nor `post`, an input tag with name `_method` is generated alongside the
    form tag. If an `:action` is given with no method, the method will default
    to the return value of `Combo.HTML.FormData.to_form/2` (usually `post`).
    """

  attr :multipart, :boolean,
    default: false,
    doc: """
    Sets `enctype` to `multipart/form-data`.
    Required when uploading files.
    """

  attr :rest, :global,
    include: ~w(autocomplete name rel enctype novalidate target),
    doc: "Additional HTML attributes to add to the form tag."

  slot :inner_block, required: true, doc: "The content rendered inside of the form tag."

  def form(assigns) do
    action = assigns[:action]

    # We require for={...} to be given but we automatically handle nils for convenience
    form_for =
      case assigns[:for] do
        nil -> %{}
        other -> other
      end

    form_options =
      assigns
      |> Map.take([:as, :csrf_token, :errors, :method, :multipart])
      |> Map.merge(assigns.rest)
      |> Map.to_list()

    # Since FormData may add options, read the actual options from form
    %{options: opts} = form = to_form(form_for, form_options)

    # By default, we will ignore action, method, and csrf token
    # unless the action is given.
    {attrs, hidden_method, csrf_token} =
      if action do
        {method, opts} = Keyword.pop(opts, :method)
        {method, hidden_method} = form_method(method)

        {csrf_token, opts} =
          Keyword.pop_lazy(opts, :csrf_token, fn ->
            if method == "post" do
              Plug.CSRFProtection.get_csrf_token_for(action)
            end
          end)

        {[action: action, method: method] ++ opts, hidden_method, csrf_token}
      else
        {opts, nil, nil}
      end

    attrs =
      case Keyword.pop(attrs, :multipart, false) do
        {false, attrs} -> attrs
        {true, attrs} -> Keyword.put(attrs, :enctype, "multipart/form-data")
      end

    assigns =
      assign(assigns,
        form: form,
        csrf_token: csrf_token,
        hidden_method: hidden_method,
        attrs: attrs
      )

    ~CE"""
    <form {@attrs}>
      <input
        :if={@hidden_method && @hidden_method not in ~w(get post)}
        name="_method"
        type="hidden"
        hidden
        value={@hidden_method}
      />
      <input :if={@csrf_token} name="_csrf_token" type="hidden" hidden value={@csrf_token} />
      {render_slot(@inner_block, @form)}
    </form>
    """
  end

  defp form_method(nil), do: {"post", nil}

  defp form_method(method) when is_binary(method) do
    case String.downcase(method) do
      method when method in ~w(get post) -> {method, nil}
      _ -> {"post", method}
    end
  end

  @doc """
  Renders an input element.

  A `%Combo.HTML.FormField{}` can be passed as `:field` attr, which is used
  to retrieve the `:id`, `:name`, and `:value` attrs automatically. Otherwise,
  all these attrs may be passed explicitly.

  Unsupported types, such as `"radio"` and `"submit"`, are best written
  directly as plain HTML.

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information.

  [INSERT ASSIGNS_DOCS]

  ## Examples

  ```ceex
  <.input field={@form[:email]} type="email" />
  ```

  ```ceex
  <.input id="email" name="email" value="admin@example.com" />
  ```
  """
  @doc type: :component
  attr :id, :any
  attr :name, :any
  attr :value, :any
  attr :field, Combo.HTML.FormField, doc: "a form field struct retrieved from the form"

  attr :type, :string,
    default: "text",
    values: ~w(button checkbox color date datetime-local email file hidden image month number
               password radio range reset search tel text time url week)

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Combo.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(:field, nil)
    |> assign_new(:id, fn -> field.id end)
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> build_input()
  end

  def input(assigns) do
    assigns
    |> assign_new(:id, fn -> nil end)
    |> assign_new(:name, fn -> nil end)
    |> assign_new(:value, fn -> nil end)
    |> build_input()
  end

  defp build_input(%{type: "checkbox"} = assigns) do
    assigns =
      assigns
      |> assign_new(:checked, fn ->
        Combo.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~CE"""
    <input name={@name} type="hidden" value="false" disabled={@rest[:disabled]} />
    <input
      id={@id}
      name={@name}
      type={@type}
      value="true"
      checked={@checked}
      {@rest}
    />
    """
  end

  defp build_input(assigns) do
    ~CE"""
    <input
      id={@id}
      name={@name}
      type={@type}
      value={Combo.HTML.Form.normalize_value(@type, @value)}
      {@rest}
    />
    """
  end

  @doc """
  Renders a textarea element.

  A `%Combo.HTML.FormField{}` can be passed as `:field` attr, which is used
  to retrieve the `:id`, `:name`, and `:value` attrs automatically. Otherwise,
  all these attrs may be passed explicitly.

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/textarea
  for more information.

  ## Examples

  ```ceex
  <.textarea field={@form[:content]} />
  ```

  ```ceex
  <.textarea id="content" name="content" value="Lorem ipsum..." />
  ```
  """
  @doc type: :component
  attr :id, :any
  attr :name, :any
  attr :value, :any
  attr :field, Combo.HTML.FormField, doc: "a form field struct retrieved from the form"

  attr :rest, :global,
    include: ~w(autocapitalize autocomplete autocorrect autofocus cols dirname disabled form
                maxlength minlength placeholder readonly required rows spellcheck wrap)

  def textarea(%{field: %Combo.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(:field, nil)
    |> assign_new(:id, fn -> field.id end)
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> build_textarea()
  end

  def textarea(assigns) do
    assigns
    |> assign_new(:id, fn -> nil end)
    |> assign_new(:name, fn -> nil end)
    |> assign_new(:value, fn -> nil end)
    |> build_textarea()
  end

  defp build_textarea(assigns) do
    ~CE"""
    <textarea
      id={@id}
      name={@name}
      {@rest}
    >{Combo.HTML.Form.normalize_value("textarea", @value)}</textarea>
    """
  end

  @doc """
  Renders a select element.

  A `%Combo.HTML.FormField{}` can be passed as `:field` attr, which is used
  to retrieve the `:id`, `:name`, and `:value` attrs automatically. Otherwise,
  all these attrs may be passed explicitly.

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/select
  for more information.

  ## Examples

  ```ceex
  <.select
    field={@form[:pet]}
    prompt="Choose a pet"
    options={[Cat: "cat", Dog: "dog", Fish: "fish"]}
  />
  ```

  ```ceex
  <.select
    field={@form[:pet]}
    prompt="Choose a pet"
    options={[Cat: "cat", Dog: "dog", Fish: "fish"]}
    multiple
  />
  ```

  """
  @doc type: :component
  attr :id, :any
  attr :name, :any
  attr :value, :any
  attr :field, Combo.HTML.FormField, doc: "a form field struct retrieved from the form"

  attr :prompt, :string, default: nil, doc: "the prompt"

  attr :options, :list,
    doc: "the options, which will be passed to Combo.HTML.Form.options_for_select/2"

  attr :multiple, :boolean,
    default: false,
    doc: "the flag indicates that multiple options can be selected"

  attr :rest, :global, include: ~w(autocomplete autofocus disabled form required size)

  def select(%{field: %Combo.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(:field, nil)
    |> assign_new(:id, fn -> field.id end)
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> build_select()
  end

  def select(assigns) do
    assigns
    |> assign_new(:id, fn -> nil end)
    |> assign_new(:name, fn -> nil end)
    |> assign_new(:value, fn -> nil end)
    |> build_select()
  end

  defp build_select(assigns) do
    ~CE"""
    <select
      id={@id}
      name={@name}
      multiple={@multiple}
      {@rest}
    >
      <option :if={@prompt} value="">{@prompt}</option>
      {Combo.HTML.Form.options_for_select(@options, @value)}
    </select>
    """
  end

  # TODO: fix the docs
  @doc """
  Renders nested form inputs for associations or embeds.

  [INSERT ASSIGNS_DOCS]

  ## Examples

  ```ceex
  <.form for={@form} action={~p"/path"}>
    <.inputs_for :let={f_nested} field={@form[:nested]}>
      <.input type="text" field={f_nested[:name]} />
    </.inputs_for>
  </.form>
  ```

  ## Dynamically adding and removing inputs

  Dynamically adding and removing inputs is supported by rendering named buttons for
  inserts and removals. Like inputs, buttons with name/value pairs are serialized with
  form data on change and submit events. Libraries such as Ecto, or custom param
  filtering can then inspect the parameters and handle the added or removed fields.
  This can be combined with `Ecto.Changeset.cast_assoc/3`'s `:sort_param` and `:drop_param`
  options. For example, imagine a parent with an `:emails` `has_many` or `embeds_many`
  association. To cast the user input from a nested form, one simply needs to configure
  the options:

      schema "mailing_lists" do
        field :title, :string

        embeds_many :emails, EmailNotification, on_replace: :delete do
          field :email, :string
          field :name, :string
        end
      end

      def changeset(list, attrs) do
        list
        |> cast(attrs, [:title])
        |> cast_embed(:emails,
          with: &email_changeset/2,
          sort_param: :emails_sort,
          drop_param: :emails_drop
        )
      end

  Here we see the `:sort_param` and `:drop_param` options in action.

  > Note: `on_replace: :delete` on the `has_many` and `embeds_many` is required
  > when using these options.

  When Ecto sees the specified sort or drop parameter from the form, it will sort
  the children based on the order they appear in the form, add new children it hasn't
  seen, or drop children if the parameter instructs it to do so.

  The markup for such a schema and association would look like this:

  ```ceex
  <.inputs_for :let={ef} field={@form[:emails]}>
    <input type="hidden" name="mailing_list[emails_sort][]" value={ef.index} />
    <.input type="text" field={ef[:email]} placeholder="email" />
    <.input type="text" field={ef[:name]} placeholder="name" />
    <button
      type="button"
      name="mailing_list[emails_drop][]"
      value={ef.index}
    >
      <.icon name="hero-x-mark" class="w-6 h-6 relative top-2" />
    </button>
  </.inputs_for>

  <input type="hidden" name="mailing_list[emails_drop][]" />

  <button type="button" name="mailing_list[emails_sort][]" value="new">
    add more
  </button>
  ```

  We used `inputs_for` to render inputs for the `:emails` association, which
  contains an email address and name input for each child. Within the nested inputs,
  we render a hidden `mailing_list[emails_sort][]` input, which is set to the index of the
  given child. This tells Ecto's cast operation how to sort existing children, or
  where to insert new children. Next, we render the email and name inputs as usual.
  Then we render a button containing the "delete" text with the name `mailing_list[emails_drop][]`,
  containing the index of the child as its value.

  Outside the `inputs_for`, we render an empty `mailing_list[emails_drop][]` input,
  to ensure that all children are deleted when saving a form where the user
  dropped all entries. This hidden input is required whenever dropping associations.

  Finally, we also render another button with the sort param name `mailing_list[emails_sort][]`
  and `value="new"` name with accompanied "add more" text. Please note that this button must
  have `type="button"` to prevent it from submitting the form.
  Ecto will treat unknown sort params as new children and build a new child.
  This button is optional and only necessary if you want to dynamically add entries.
  You can optionally add a similar button before the `<.inputs_for>`, in the case you want
  to prepend entries.

  > ### A note on accessing a field's `value` {: .warning}
  >
  > You may be tempted to access `form[:field].value` or attempt to manipulate
  > the form metadata in your templates. However, bear in mind that the `form[:field]`
  > value reflects the most recent changes. For example, an `:integer` field may
  > either contain integer values, but it may also hold a string, if the form has
  > been submitted.
  >
  > This is particularly noticeable when using `inputs_for`. Accessing the `.value`
  > of a nested field may either return a struct, a changeset, or raw parameters
  > sent by the client (when using `drop_param`). This makes the `form[:field].value`
  > impractical for deriving or computing other properties.
  >
  > The correct way to approach this problem is by computing any property either
  > by traversing the relevant changesets and data structures, or by
  > moving the logic to the `Ecto.Changeset` itself.
  >
  > As an example, imagine you are building a time tracking application where:
  >
  > - users enter the total work time for a day
  > - individual activities are tracked as embeds
  > - the sum of all activities should match the total time
  > - the form should display the remaining time
  >
  > Instead of trying to calculate the remaining time in your template by
  > doing something like `calculate_remaining(@form)` and accessing
  > `form[:activities].value`, calculate the remaining time based
  > on the changeset in your `handle_event` instead:
  >
  > ```elixir
  > def handle_event("validate", %{"tracked_day" => params}, socket) do
  >   changeset = TrackedDay.changeset(socket.assigns.tracked_day, params)
  >   remaining = calculate_remaining(changeset)
  >   {:noreply, assign(socket, form: to_form(changeset, action: :validate), remaining: remaining)}
  > end
  >
  > # Helper function to calculate remaining time
  > defp calculate_remaining(changeset) do
  >   total = Ecto.Changeset.get_field(changeset, :total)
  >   activities = Ecto.Changeset.get_embed(changeset, :activities)
  >
  >   Enum.reduce(activities, total, fn activity, acc ->
  >     duration =
  >       case activity do
  >         %{valid?: true} = changeset -> Ecto.Changeset.get_field(changeset, :duration)
  >         # if the activity is invalid, we don't include its duration in the calculation
  >         _ -> 0
  >       end
  >
  >     acc - length
  >   end)
  > end
  > ```
  >
  > This logic might also be implemented directly in your schema module and, if you
  > often need the `:remaining` value, you could also add it as a `:virtual` field to
  > your schema and run the calculation when validating the changeset:
  >
  > ```elixir
  > def changeset(tracked_day, attrs) do
  >   tracked_day
  >   |> cast(attrs, [:total_duration])
  >   |> cast_embed(:activities)
  >   |> validate_required([:total_duration])
  >   |> validate_number(:total_duration, greater_than: 0)
  >   |> validate_and_put_remaining_time()
  > end
  >
  > defp validate_and_put_remaining_time(changeset) do
  >   remaining = calculate_remaining(changeset)
  >   put_change(changeset, :remaining, remaining)
  > end
  > ```
  >
  > By using this approach, you can safely render the remaining time in your template
  > using `@form[:remaining].value`, avoiding the pitfalls of directly accessing complex field values.
  """
  @doc type: :component
  attr :field, Combo.HTML.FormField,
    required: true,
    doc: "A %Combo.HTML.Form{}/field name tuple, for example: {@form[:email]}."

  attr :id, :string,
    doc: """
    The id base to be used in the form inputs. Defaults to the parent form id. The computed
    id will be the concatenation of the base id with the field name, along with a book keeping
    index for each input in the list.
    """

  attr :as, :atom,
    doc: """
    The name to be used in the form, defaults to the concatenation of the given
    field to the parent form name.
    """

  attr :default, :any, doc: "The value to use if none is available."

  attr :prepend, :list,
    doc: """
    The values to prepend when rendering. This only applies if the field value
    is a list and no parameters were sent through the form.
    """

  attr :append, :list,
    doc: """
    The values to append when rendering. This only applies if the field value
    is a list and no parameters were sent through the form.
    """

  attr :skip_hidden, :boolean,
    default: false,
    doc: """
    Skip the automatic rendering of hidden fields to allow for more tight control
    over the generated markup.
    """

  attr :skip_persistent_id, :boolean,
    default: false,
    doc: """
    Skip the automatic rendering of hidden _persistent_id fields used for reordering
    inputs.
    """

  attr :options, :list,
    default: [],
    doc: """
    Any additional options for the `Combo.HTML.FormData` protocol
    implementation.
    """

  slot :inner_block, required: true, doc: "The content rendered for each nested form."

  @persistent_id "_persistent_id"
  def inputs_for(assigns) do
    %Combo.HTML.FormField{field: field_name, form: parent_form} = assigns.field
    options = assigns |> Map.take([:id, :as, :default, :append, :prepend]) |> Keyword.new()

    options =
      parent_form.options
      |> Keyword.take([:multipart])
      |> Keyword.merge(options)
      |> Keyword.merge(assigns.options)

    forms = parent_form.impl.to_form(parent_form.source, parent_form, field_name, options)

    forms =
      case assigns do
        %{skip_persistent_id: true} ->
          forms

        _ ->
          apply_persistent_id(
            parent_form,
            forms,
            field_name,
            options
          )
      end

    assigns = assign(assigns, :forms, forms)

    ~CE"""
    <%= for finner <- @forms do %>
      <%= if !@skip_hidden do %>
        <%= for {name, value_or_values} <- finner.hidden,
                name = name_for_value_or_values(finner, name, value_or_values),
                value <- List.wrap(value_or_values) do %>
          <input type="hidden" name={name} value={value} />
        <% end %>
      <% end %>
      {render_slot(@inner_block, finner)}
    <% end %>
    """
  end

  defp apply_persistent_id(parent_form, forms, field_name, options) do
    seen_ids = for f <- forms, vid = f.params[@persistent_id], into: %{}, do: {vid, true}

    {forms, _} =
      Enum.map_reduce(forms, {seen_ids, 0}, fn
        %Combo.HTML.Form{params: params} = form, {seen_ids, index} ->
          id =
            case params do
              %{@persistent_id => id} -> id
              %{} -> next_id(map_size(seen_ids), seen_ids)
            end

          form_id =
            if inputs_for_id = options[:id] do
              "#{inputs_for_id}_#{field_name}_#{id}"
            else
              "#{parent_form.id}_#{field_name}_#{id}"
            end

          new_params = Map.put(params, @persistent_id, id)
          new_hidden = [{@persistent_id, id} | form.hidden]

          new_form = %{
            form
            | id: form_id,
              params: new_params,
              hidden: new_hidden,
              index: index
          }

          {new_form, {Map.put(seen_ids, id, true), index + 1}}
      end)

    forms
  end

  defp next_id(idx, %{} = seen_ids) do
    id_str = to_string(idx)

    if Map.has_key?(seen_ids, id_str) do
      next_id(idx + 1, seen_ids)
    else
      id_str
    end
  end

  defp name_for_value_or_values(form, field, values) when is_list(values) do
    Combo.HTML.Form.input_name(form, field) <> "[]"
  end

  defp name_for_value_or_values(form, field, _value) do
    Combo.HTML.Form.input_name(form, field)
  end

  @doc """
  Renders a dynamic tag.

  Raises an `ArgumentError` if the tag name is found to be unsafe HTML.

  [INSERT ASSIGNS_DOCS]

  ## Examples

  ```ceex
  <.dynamic_tag tag_name="input" name="my-input" type="text" />
  # outputs:
  <input name="my-input" type="text" />
  ```

  ```ceex
  <.dynamic_tag tag_name="p">content</.dynamic_tag>
  # outputs:
  <p>content</p>
  ```
  """
  @doc type: :component
  attr :tag_name, :string, required: true, doc: "The name of the tag, such as `div`."

  attr :rest, :global,
    doc: """
    Additional HTML attributes to add to the tag, ensuring proper escaping.
    """

  slot :inner_block, []

  def dynamic_tag(assigns) do
    %{tag_name: tag_name, rest: rest} = assigns

    tag =
      if SafeHTML.escape(tag_name) == tag_name do
        tag_name
      else
        raise ArgumentError,
              "expected tag_name to be safe HTML, got: #{inspect(tag_name)}"
      end

    assigns =
      assigns
      |> assign(:tag, tag)
      |> assign(:escaped_attrs, SafeHTML.escape_attrs(rest))

    if assigns.inner_block != [] do
      ~CE"""
      {{:safe, [?<, @tag]}}{{:safe, @escaped_attrs}}{{:safe, [?>]}}{render_slot(@inner_block)}{{:safe,
       [?<, ?/, @tag, ?>]}}
      """
    else
      ~CE"""
      {{:safe, [?<, @tag]}}{{:safe, @escaped_attrs}}{{:safe, [?/, ?>]}}
      """
    end
  end

  @doc """
  Renders a flash message.

  ## Examples

  ```ceex
  <.flash kind={:info} flash={@flash} :let={{_kind, msg}} />
    <p>{msg}</p>
  </.flash>
  ```
  """
  attr :id, :string, doc: "the optional id"
  attr :flash, :map, required: true, doc: "the flash assign"
  attr :kind, :atom, required: true, doc: "the kind of flash message"
  attr :rest, :global, doc: "additional HTML attributes"
  slot :inner_block, required: true

  def flash(assigns) do
    assigns =
      assigns
      |> assign_new(:id, fn -> "flash-#{assigns.kind}" end)
      |> assign(:msg, Combo.Flash.get(assigns.flash, assigns.kind))

    ~CE"""
    <div :if={@msg} id={@id} {@rest}>
      {render_slot(@inner_block, {@kind, @msg})}
    </div>
    """
  end

  @doc """
  Intersperses separator slot between an enumerable.

  It is useful when you need to add a separator between items such as when
  rendering breadcrumbs for navigation. Provides each item to the inner block.

  ## Examples

  ```ceex
  <.intersperse :let={item} enum={["home", "profile", "settings"]}>
    <:separator>
      <span class="sep">|</span>
    </:separator>
    {item}
  </.intersperse>
  ```

  Which renders the following HTML:

  ```html
  home <span class="sep">|</span> profile <span class="sep">|</span> settings
  ```
  """
  @doc type: :component
  attr :enum, :any, required: true, doc: "the enumerable to intersperse with separators"
  slot :inner_block, required: true, doc: "the inner_block to render for each item"
  slot :separator, required: true, doc: "the slot for the separator"

  def intersperse(assigns) do
    ~CE"""
    <%= for item <- Enum.intersperse(@enum, :separator) do %><%=
      if item == :separator do
        render_slot(@separator)
      else
        render_slot(@inner_block, item)
      end
    %><% end %>
    """noformat
  end
end
