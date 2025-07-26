defmodule Phoenix.Template.HTMLEngine.Component do
  @moduledoc ~S'''
  Defines reusable components.

  A component is any function that receives an assigns map as an argument
  and returns a CH template.

      defmodule MyComponent do
        use Phoenix.Component

        def greet(assigns) do
          ~CH"""
          <p>Hello, {@name}!</p>
          """
        end
      end

  When invoked within a `.ch` template file: or `~CH` sigil

  ```ch
  <MyComponent.greet name="Jane" />
  ```

  The following HTML is rendered:

  ```html
  <p>Hello, Jane!</p>
  ```

  If the component is defined locally, or its module is imported, then the
  caller can invoke it directly without specifying the module:

  ```ch
  <.greet name="Jane" />
  ```

  For dynamic values, you can interpolate Elixir expressions into a component:

  ```ch
  <.greet name={@user.name} />
  ```

  Components can also accept blocks (more on this later):

  ```ch
  <.card>
    <p>This is the body of my card!</p>
  </.card>
  ```

  ## Attributes

  `Phoenix.Component` provides the `attr/3` macro to declare what attributes
  the proceeding component expects to receive when invoked:

  ```elixir
  attr :name, :string, required: true

  def greet(assigns) do
    ~CH"""
    <p>Hello, {@name}!</p>
    """
  end
  ```

  By calling `attr/3`, it is now clear that `greet/1` requires a string attribute
  called `name` present in its `assigns` map to properly render. Failing to do
  so will result in a compilation warning:

  ```ch
  <MyComponent.greet />
  <!-- warning: missing required attribute "name" for component MyAppWeb.MyComponent.greet/1 ...-->
  ```

  Attributes can provide default values that are automatically merged into the
  `assigns` map:

  ```elixir
  attr :name, :string, default: "Bob"
  ```

  Now you can invoke the component without providing a value for `name`:

  ```ch
  <.greet />
  ```

  Rendering the following HTML:

  ```html
  <p>Hello, Bob!</p>
  ```

  Accessing an attribute which is required and does not have a default value will fail.
  You must explicitly declare `default: nil` or assign a value programmatically with the
  `assign_new/3` function.

  Multiple attributes can be declared for the same component:

  ```elixir
  attr :name, :string, required: true
  attr :age, :integer, required: true

  def celebrate(assigns) do
    ~CH"""
    <p>
      Happy birthday {@name}!
      You are {@age} years old.
    </p>
    """
  end
  ```

  Allowing the caller to pass multiple values:

  ```ch
  <.celebrate name={"Genevieve"} age={34} />
  ```

  Rendering the following HTML:

  ```html
  <p>
    Happy birthday Genevieve!
    You are 34 years old.
  </p>
  ```

  Multiple components can be defined in the same module, with different
  attributes. In the following example, `<MyComponent.greet/>` requires a
  `name`, but *does not* require a `title`, and `<MyComponent.heading>`
  requires a `title`, but *does not* require a `name`.

  ```elixir
  defmodule MyComponent do
    use Phoenix.Component

    attr :title, :string, required: true

    def heading(assigns) do
      ~CH"""
      <h1>{@title}</h1>
      """
    end

    attr :name, :string, required: true

    def greet(assigns) do
      ~CH"""
      <p>Hello {@name}</p>
      """
    end
  end
  ```

  With the `attr/3` macro you have the core ingredients to create reusable
  components. But what if you need your components to support
  dynamic attributes, such as common HTML attributes to mix into a component's
  container?

  ## Global attributes

  Global attributes are a set of attributes that a component can accept when
  it declares an attribute of type `:global`. By default, the set of attributes
  accepted are those attributes common to all standard HTML tags.
  See [Global attributes](https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes)
  for a complete list of attributes.

  Once a global attribute is declared, any number of attributes in the set can be passed by
  the caller without having to modify the component itself.

  Below is an example of a component that accepts a dynamic number of global attributes:

  ```elixir
  attr :message, :string, required: true
  attr :rest, :global

  def notification(assigns) do
    ~CH"""
    <span {@rest}>{@message}</span>
    """
  end
  ```

  The caller can pass multiple global attributes:

  ```ch
  <.notification message="You've got mail!" id="1024" class="bg-green-200" />
  ```

  Rendering the following HTML:

  ```html
  <span id="1024" class="bg-green-200">You've got mail!</span>
  ```

  Note that the component did not have to explicitly declare an `id` or `class`
  attribute in order to render.

  Global attributes can define defaults which are merged with attributes
  provided by the caller. For example, you may declare a default `class`
  if the caller does not provide one:

  ```elixir
  attr :rest, :global, default: %{class: "bg-blue-200"}
  ```

  Now you can call the component without a `class` attribute:

  ```ch
  <.notification message="You've got mail!" />
  ```

  Rendering the following HTML:

  ```html
  <span class="bg-blue-200">You've got mail!</span>
  ```

  Note that the global attribute cannot be provided directly and doing so will emit
  a warning. In other words, this is invalid:

  ```ch
  <.notification message="You've got mail!" rest={%{class: "bg-blue-200"}} />
  ```

  ### Included globals

  You may also specify which attributes are included in addition to the known globals
  with the `:include` option. For example to support the `form` attribute on a button
  component:

  ```elixir
  # <.button form="my-form"/>
  attr :rest, :global, include: ~w(form)
  slot :inner_block

  def button(assigns) do
    ~CH"""
    <button {@rest}>{render_slot(@inner_block)}</button>
    """
  end
  ```

  The `:include` option is useful to apply global additions on a case-by-case basis,
  but sometimes you want to extend existing components with new global attributes,
  such as Alpine.js' `x-` prefixes, which we'll outline next.

  ### Custom global attribute prefixes

  You can extend the set of global attributes by providing a list of attribute prefixes to
  `use Phoenix.Component`. Like the default attributes common to all HTML elements,
  any number of attributes that start with a global prefix will be accepted by function
  components invoked by the current module. By default, the following prefixes are supported:
  `phx-`, `aria-`, and `data-`. For example, to support the `x-` prefix used by
  [Alpine.js](https://alpinejs.dev/), you can pass the `:global_prefixes` option to
  `use Phoenix.Component`:

  ```elixir
  use Phoenix.Component, global_prefixes: ~w(x-)
  ```

  In your Phoenix application, this is typically done in your
  `lib/my_app_web.ex` file, inside the `def html` definition:

  ```elixir
  def html do
    quote do
      use Phoenix.Component, global_prefixes: ~w(x-)
      # ...
    end
  end
  ```

  Now all components invoked by this module will accept any number of attributes
  prefixed with `x-`, in addition to the default global prefixes.

  You can learn more about attributes by reading the documentation for `attr/3`.

  ## Slots

  In addition to attributes, components can accept blocks of HEEx content, referred to
  as slots. Slots enable further customization of the rendered HTML, as the caller can pass the
  component HEEx content they want the component to render. `Phoenix.Component` provides
  the `slot/3` macro used to declare slots for components:

  ```elixir
  slot :inner_block, required: true

  def button(assigns) do
    ~CH"""
    <button>
      {render_slot(@inner_block)}
    </button>
    """
  end
  ```

  The expression `render_slot(@inner_block)` renders the HEEx content. You can
  invoke this component like so:

  ```ch
  <.button>
    This renders <strong>inside</strong> the button!
  </.button>
  ```

  Which renders the following HTML:

  ```html
  <button>
    This renders <strong>inside</strong> the button!
  </button>
  ```

  Like the `attr/3` macro, using the `slot/3` macro will provide compile-time
  validations. For example, invoking `button/1` without a slot of HEEx content
  will result in a compilation warning being emitted:

  ```heex
  <.button />
  <!-- warning: missing required slot "inner_block" for component MyComponent.button/1 ... -->
  ```

  ### The default slot

  The example above uses the default slot, accessible as an assign named `@inner_block`, to render
  HEEx content via the `render_slot/1` function.

  If the values rendered in the slot need to be dynamic, you can pass a second value back to the
  HEEx content by calling `render_slot/2`:

      slot :inner_block, required: true

      attr :entries, :list, default: []

      def unordered_list(assigns) do
        ~CH"""
        <ul>
          <li :for={entry <- @entries}>{render_slot(@inner_block, entry)}</li>
        </ul>
        """
      end

  When invoking the component, you can use the special attribute `:let` to take the value
  that the component passes back and bind it to a variable:

  ```heex
  <.unordered_list :let={fruit} entries={~w(apples bananas cherries)}>
    I like <b>{fruit}</b>!
  </.unordered_list>
  ```

  Rendering the following HTML:

  ```html
  <ul>
    <li>I like <b>apples</b>!</li>
    <li>I like <b>bananas</b>!</li>
    <li>I like <b>cherries</b>!</li>
  </ul>
  ```

  Now the separation of concerns is maintained: the caller can specify multiple values in a list
  attribute without having to specify the HEEx content that surrounds and separates them.

  ### Named slots

  In addition to the default slot, components can accept multiple, named slots of HEEx
  content. For example, imagine you want to create a modal that has a header, body, and footer:

      slot :header
      slot :inner_block, required: true
      slot :footer, required: true

      def modal(assigns) do
        ~CH"""
        <div class="modal">
          <div class="modal-header">
            {render_slot(@header) || "Modal"}
          </div>
          <div class="modal-body">
            {render_slot(@inner_block)}
          </div>
          <div class="modal-footer">
            {render_slot(@footer)}
          </div>
        </div>
        """
      end

  You can invoke this component using the named slot HEEx syntax:

  ```heex
  <.modal>
    This is the body, everything not in a named slot is rendered in the default slot.
    <:footer>
      This is the bottom of the modal.
    </:footer>
  </.modal>
  ```

  Rendering the following HTML:

  ```html
  <div class="modal">
    <div class="modal-header">
      Modal.
    </div>
    <div class="modal-body">
      This is the body, everything not in a named slot is rendered in the default slot.
    </div>
    <div class="modal-footer">
      This is the bottom of the modal.
    </div>
  </div>
  ```

  As shown in the example above, `render_slot/1` returns `nil` when an optional slot
  is declared and none is given. This can be used to attach default behaviour.

  ### Slot attributes

  Unlike the default slot, it is possible to pass a named slot multiple pieces of HEEx content.
  Named slots can also accept attributes, defined by passing a block to the `slot/3` macro.
  If multiple pieces of content are passed, `render_slot/2` will merge and render all the values.

  Below is a table component illustrating multiple named slots with attributes:

      slot :column, doc: "Columns with column labels" do
        attr :label, :string, required: true, doc: "Column label"
      end

      attr :rows, :list, default: []

      def table(assigns) do
        ~CH"""
        <table>
          <tr>
            <th :for={col <- @column}>{col.label}</th>
          </tr>
          <tr :for={row <- @rows}>
            <td :for={col <- @column}>{render_slot(col, row)}</td>
          </tr>
        </table>
        """
      end

  You can invoke this component like so:

  ```heex
  <.table rows={[%{name: "Jane", age: "34"}, %{name: "Bob", age: "51"}]}>
    <:column :let={user} label="Name">
      {user.name}
    </:column>
    <:column :let={user} label="Age">
      {user.age}
    </:column>
  </.table>
  ```

  Rendering the following HTML:

  ```html
  <table>
    <tr>
      <th>Name</th>
      <th>Age</th>
    </tr>
    <tr>
      <td>Jane</td>
      <td>34</td>
    </tr>
    <tr>
      <td>Bob</td>
      <td>51</td>
    </tr>
  </table>
  ```

  You can learn more about slots and the `slot/3` macro [in its documentation](`slot/3`).

  ## Embedding external template files

  The `embed_templates/1` macro can be used to embed `.html.heex` files
  as components. The directory path is based on the current
  module (`__DIR__`), and a wildcard pattern may be used to select all
  files within a directory tree. For example, imagine a directory listing:

  ```plain
  ├── components.ex
  ├── cards
  │   ├── pricing_card.html.heex
  │   └── features_card.html.heex
  ```

  Then you can embed the page templates in your `components.ex` module
  and call them like any other component:

      defmodule MyAppWeb.Components do
        use Phoenix.Component

        embed_templates "cards/*"

        def landing_hero(assigns) do
          ~CH"""
          <.pricing_card />
          <.features_card />
          """
        end
      end

  See `embed_templates/1` for more information, including declarative
  assigns support for embedded templates.

  ## Debug Annotations

  HEEx templates support debug annotations, which are special HTML comments
  that wrap around rendered components to help you identify where markup
  in your HTML document is rendered within your component tree.

  For example, imagine the following HEEx template:

  ```heex
  <.header>
    <.button>Click</.button>
  </.header>
  ```

  The HTML document would receive the following comments when debug annotations
  are enabled:

  ```html
  <!-- @caller lib/app_web/home_live.ex:20 -->
  <!-- <AppWeb.CoreComponents.header> lib/app_web/core_components.ex:123 -->
  <header class="p-5">
    <!-- @caller lib/app_web/home_live.ex:48 -->
    <!-- <AppWeb.CoreComponents.button> lib/app_web/core_components.ex:456 -->
    <button class="px-2 bg-indigo-500 text-white">Click</button>
    <!-- </AppWeb.CoreComponents.button> -->
  </header>
  <!-- </AppWeb.CoreComponents.header> -->
  ```

  Debug annotations work across any `~CH` or `.html.heex` template.
  They can be enabled globally with the following configuration in your
  `config/dev.exs` file:

      config :phoenix_live_view, debug_heex_annotations: true

  Changing this configuration will require `mix clean` and a full recompile.

  ## Dynamic Component Rendering

  Sometimes you might need to decide at runtime which component to render.
  Because components are just regular functions, we can leverage
  Elixir's `apply/3` function to dynamically call a module and/or function passed
  in as an assign.

  For example, using the following component definition:

  ```elixir
  attr :module, :atom, required: true
  attr :function, :atom, required: true
  # any shared attributes
  attr :shared, :string, required: true

  # any shared slots
  slot :named_slot, required: true
  slot :inner_block, required: true

  def dynamic_component(assigns) do
    {mod, assigns} = Map.pop(assigns, :module)
    {func, assigns} = Map.pop(assigns, :function)

    apply(mod, func, [assigns])
  end
  ```

  Then you can use the `dynamic_component` function like so:

  ```heex
  <.dynamic_component
    module={MyAppWeb.MyModule}
    function={:my_function}
    shared="Yay Elixir!"
  >
    <p>Howdy from the inner block!</p>
    <:named_slot>
      <p>Howdy from the named slot!</p>
    </:named_slot>
  </.dynamic_component>
  ```

  This will call the `MyAppWeb.MyModule.my_function/1` function passing in the remaining assigns.

  ```elixir
  defmodule MyAppWeb.MyModule do
    attr :shared, :string, required: true

    slot :named_slot, required: true
    slot :inner_block, required: true

    def my_function(assigns) do
      ~CH"""
      <p>Dynamic component with shared assigns: {@shared}</p>
      {render_slot(@inner_block)}
      {render_slot(@named_slot)}
      """
    end
  end
  ```

  Resulting in the following HTML:

  ```html
  <p>Dynamic component with shared assigns: Yay Elixir!</p>
  <p>Howdy from the inner block!</p>
  <p>Howdy from the named slot!</p>
  ```

  Note that to get the most out of `Phoenix.Component`'s compile-time validations, it is beneficial to
  define such a `dynamic_component` for a specific set of components sharing the same API, instead of
  defining it for the general case.
  In this example, we defined our `dynamic_component` to expect an assign called `shared`, as well as
  two slots that all components we want to use with it must implement.
  The called `my_function` component's attribute and slot definitions cannot be validated through the apply call.
  '''

  ## Functions

  import Phoenix.Template.HTMLEngine.Sigil

  @reserved_assigns __MODULE__.Declarative.__reserved__()

  @doc """
  Adds a key-value pair to assigns.

  ## Examples

      iex> assign(socket, :name, "Combo")

  """
  def assign(assigns, key, value) when is_map(assigns) do
    validate_assign_key!(key)

    case assigns do
      %{^key => ^value} -> assigns
      _ -> Map.put(assigns, key, value)
    end
  end

  @doc """
  Adds key-value pairs to assigns.

  ## Examples

      iex> assign(socket, name: "Combo", lang: "Elixir")
      iex> assign(socket, %{name: "Combo", lang: "Elixir"})

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
      iex> assign_new(assigns, :name, fn assigns -> assigns[:old_name] end)

  ## Use cases - lazy assigns

  Imagine you have a component that accepts a color:

  ```ch
  <.my_component bg_color="red" />
  ```

  The color is also optional, so you can skip it:

  ```ch
  <.my_component />
  ```

  In such case, the implementation can use `assign_new` to lazily assign
  a color if none is given.

  ```elixir
  def my_component(assigns) do
    assigns = assign_new(assigns, :bg_color, fn -> Enum.random(~w(bg-red-200 bg-green-200 bg-blue-200)) end)

    ~CH"""
    <div class={@bg_color}>
      Example
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
  Filters the assigns as a list of keywords for use in dynamic tag attributes.

  One should prefer to use declarative assigns and `:global` attributes
  over this function.

  ## Examples

  Imagine the following `my_link` component which allows a caller
  to pass a `new_window` assign, along with any other attributes they
  would like to add to the element, such as class, data attributes, etc:

  ```heex
  <.my_link to="/" id={@id} new_window={true} class="my-class">Home</.my_link>
  ```

  We could support the dynamic attributes with the following component:

      def my_link(assigns) do
        target = if assigns[:new_window], do: "_blank", else: false
        extra = assigns_to_attributes(assigns, [:new_window, :to])

        assigns =
          assigns
          |> assign(:target, target)
          |> assign(:extra, extra)

        ~CH"""
        <a href={@to} target={@target} {@extra}>
          {render_slot(@inner_block)}
        </a>
        """
      end

  The above would result in the following rendered HTML:

  ```heex
  <a href="/" target="_blank" id="1" class="my-class">Home</a>
  ```

  The second argument (optional) to `assigns_to_attributes` is a list of keys to
  exclude. It typically includes reserved keys by the component itself, which either
  do not belong in the markup, or are already handled explicitly by the component.
  '''
  def assigns_to_attributes(assigns, exclude \\ []) do
    excluded_keys = @reserved_assigns ++ exclude
    for {key, val} <- assigns, key not in excluded_keys, into: [], do: {key, val}
  end

  @doc ~S'''
  Renders a slot entry with the given optional `argument`.

  ```heex
  {render_slot(@inner_block, @form)}
  ```

  If the slot has no entries, nil is returned.

  If multiple slot entries are defined for the same slot,`render_slot/2` will automatically render
  all entries, merging their contents. In case you want to use the entries' attributes, you need
  to iterate over the list to access each slot individually.

  For example, imagine a table component:

  ```heex
  <.table rows={@users}>
    <:col :let={user} label="Name">
      {user.name}
    </:col>

    <:col :let={user} label="Address">
      {user.address}
    </:col>
  </.table>
  ```

  At the top level, we pass the rows as an assign and we define a `:col` slot for each column we
  want in the table. Each column also has a `label`, which we are going to use in the table header.

  Inside the component, you can render the table with headers, rows, and columns:

      def table(assigns) do
        ~CH"""
        <table>
          <tr>
            <th :for={col <- @col}>{col.label}</th>
          </tr>
          <tr :for={row <- @rows}>
            <td :for={col <- @col}>{render_slot(col, row)}</td>
          </tr>
        </table>
        """
      end

  '''
  defmacro render_slot(slot, argument \\ nil) do
    quote do
      unquote(__MODULE__).__render_slot__(
        unquote(slot),
        unquote(argument)
      )
    end
  end

  @doc false
  def __render_slot__([], _), do: nil

  def __render_slot__([entry], arg) do
    call_inner_block!(entry, arg)
  end

  def __render_slot__(entries, arg) when is_list(entries) do
    assigns = %{entries: entries, arg: arg}

    ~CH"""
    <%= for entry <- @entries do %>{call_inner_block!(entry, @arg)}<% end %>
    """noformat
  end

  def __render_slot__(entry, arg) when is_map(entry) do
    entry.inner_block.(arg)
  end

  defp call_inner_block!(entry, arg) do
    if !entry.inner_block do
      message = "attempted to render slot <:#{entry.__slot__}> but the slot has no inner content"
      raise RuntimeError, message
    end

    entry.inner_block.(arg)
  end

  @doc """
  Converts a given data structure to a `Phoenix.HTML.Form`.

  This is commonly used to convert a map or an Ecto changeset
  into a form to be given to the `form/1` component.

  ## Creating a form from params

  If you want to create a form based on `handle_event` parameters,
  you could do:

      def handle_event("submitted", params, socket) do
        {:noreply, assign(socket, form: to_form(params))}
      end

  When you pass a map to `to_form/1`, it assumes said map contains
  the form parameters, which are expected to have string keys.

  You can also specify a name to nest the parameters:

      def handle_event("submitted", %{"user" => user_params}, socket) do
        {:noreply, assign(socket, form: to_form(user_params, as: :user))}
      end

  ## Creating a form from changesets

  When using changesets, the underlying data, form parameters, and
  errors are retrieved from it. The `:as` option is automatically
  computed too. For example, if you have a user schema:

      defmodule MyApp.Users.User do
        use Ecto.Schema

        schema "..." do
          ...
        end
      end

  And then you create a changeset that you pass to `to_form`:

      %MyApp.Users.User{}
      |> Ecto.Changeset.change()
      |> to_form()

  In this case, once the form is submitted, the parameters will
  be available under `%{"user" => user_params}`.

  ## Options

    * `:as` - the `name` prefix to be used in form inputs
    * `:id` - the `id` prefix to be used in form inputs
    * `:errors` - keyword list of errors (used by maps exclusively)
    * `:action` - The action that was taken against the form. This value can be
      used to distinguish between different operations such as the user typing
      into a form for validation, or submitting a form for a database insert.
      For example: `to_form(changeset, action: :validate)`,
      or `to_form(changeset, action: :save)`. The provided action is passed
      to the underlying `Phoenix.HTML.FormData` implementation options.

  The underlying data may accept additional options when
  converted to forms. For example, a map accepts `:errors`
  to list errors, but such option is not accepted by
  changesets. `:errors` is a keyword of tuples in the shape
  of `{error_message, options_list}`. Here is an example:

      to_form(%{"search" => nil}, errors: [search: {"Can't be blank", []}])

  If an existing `Phoenix.HTML.Form` struct is given, the
  options above will override its existing values if given.
  Then the remaining options are merged with the existing
  form options.

  Errors in a form are only displayed if the changeset's `action`
  field is set (and it is not set to `:ignore`) and can be filtered
  by whether the fields have been used on the client or not. Refer to
  [a note on :errors for more information](#form/1-a-note-on-errors).
  """
  def to_form(data_or_params, options \\ [])

  def to_form(%Phoenix.HTML.Form{} = data, []) do
    data
  end

  def to_form(%Phoenix.HTML.Form{} = data, options) do
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

      Or, if you prefer, use to_form to create a form in your LiveView:

          assign(socket, form: to_form(%{}, as: #{inspect(data)}))

      and then use it in your templates (no :let required):

          <.form for={@form}>
      """)
    end

    Phoenix.HTML.FormData.to_form(data, options)
  end

  @doc """
  Embeds external template files into the module as components.

  ## Options

    * `:root` - The root directory to embed files. Defaults to the current
      module's directory (`__DIR__`)
    * `:suffix` - A string value to append to embedded function names. By
      default, function names will be the name of the template file excluding
      the format and engine.

  A wildcard pattern may be used to select all files within a directory tree.
  For example, imagine a directory listing:

  ```plain
  ├── components.ex
  ├── pages
  │   ├── about_page.html.heex
  │   └── welcome_page.html.heex
  ```

  Then to embed the page templates in your `components.ex` module:

      defmodule MyAppWeb.Components do
        use Phoenix.Component

        embed_templates "pages/*"
      end

  Now, your module will have an `about_page/1` and `welcome_page/1` function
  component defined. Embedded templates also support declarative assigns
  via bodyless function definitions, for example:

      defmodule MyAppWeb.Components do
        use Phoenix.Component

        embed_templates "pages/*"

        attr :name, :string, required: true
        def welcome_page(assigns)

        slot :header
        def about_page(assigns)
      end

  Multiple invocations of `embed_templates` is also supported, which can be
  useful if you have more than one template format. For example:

      defmodule MyAppWeb.Emails do
        use Phoenix.Component

        embed_templates "emails/*.html", suffix: "_html"
        embed_templates "emails/*.text", suffix: "_text"
      end

  Note: this function is the same as `Phoenix.Template.embed_templates/2`.
  It is also provided here for convenience and documentation purposes.
  Therefore, if you want to embed templates for other formats, which are
  not related to `Phoenix.Component`, prefer to
  `import Phoenix.Template, only: [embed_templates: 1]` than this module.
  """
  @doc type: :macro
  defmacro embed_templates(pattern, opts \\ []) do
    quote bind_quoted: [pattern: pattern, opts: opts] do
      Phoenix.Template.compile_all(
        &Phoenix.Component.__embed__(&1, opts[:suffix]),
        Path.expand(opts[:root] || __DIR__, __DIR__),
        pattern
      )
    end
  end

  @doc false
  def __embed__(path, suffix),
    do:
      path
      |> Path.basename()
      |> Path.rootname()
      |> Path.rootname()
      |> Kernel.<>(suffix || "")

  ## Declarative assigns API

  @doc false
  defmacro __using__(opts \\ []) do
    quote bind_quoted: [opts: opts] do
      import Kernel, except: [def: 2, defp: 2]
      import Phoenix.Template.HTMLEngine.Sigil
      import unquote(__MODULE__)
      import unquote(__MODULE__).Declarative
      require Phoenix.Template

      for {prefix_match, value} <- unquote(__MODULE__).Declarative.__setup__(__MODULE__, opts) do
        @doc false
        def __global__?(unquote(prefix_match)), do: unquote(value)
      end
    end
  end

  @doc ~S'''
  Declares a component slot.

  ## Arguments

  * `name` - an atom defining the name of the slot. Note that slots cannot define the same name
  as any other slots or attributes declared for the same component.

  * `opts` - a keyword list of options. Defaults to `[]`.

  * `block` - a code block containing calls to `attr/3`. Defaults to `nil`.

  ### Options

  * `:required` - marks a slot as required. If a caller does not pass a value for a required slot,
  a compilation warning is emitted. Otherwise, an omitted slot will default to `[]`.

  * `:validate_attrs` - when set to `false`, no warning is emitted when a caller passes attributes
  to a slot defined without a do block. If not set, defaults to `true`.

  * `:doc` - documentation for the slot. Any slot attributes declared
  will have their documentation listed alongside the slot.

  ### Slot Attributes

  A named slot may declare attributes by passing a block with calls to `attr/3`.

  Unlike attributes, slot attributes cannot accept the `:default` option. Passing one
  will result in a compile warning being issued.

  ### The Default Slot

  The default slot can be declared by passing `:inner_block` as the `name` of the slot.

  Note that the `:inner_block` slot declaration cannot accept a block. Passing one will
  result in a compilation error.

  ## Compile-Time Validations

  LiveView performs some validation of slots via the `:phoenix_live_view` compiler.
  When slots are defined, LiveView will warn at compilation time on the caller if:

  * A required slot of a component is missing.

  * An unknown slot is given.

  * An unknown slot attribute is given.

  On the side of the component itself, defining attributes provides the following
  quality of life improvements:

  * Slot documentation is generated for the component.

  * Calls made to the component are tracked for reflection and validation purposes.

  ## Documentation Generation

  Public components that define slots will have their docs injected into the function's
  documentation, depending on the value of the `@doc` module attribute:

  * if `@doc` is a string, the slot docs are injected into that string. The optional placeholder
  `[INSERT LVATTRDOCS]` can be used to specify where in the string the docs are injected.
  Otherwise, the docs are appended to the end of the `@doc` string.

  * if `@doc` is unspecified, the slot docs are used as the default `@doc` string.

  * if `@doc` is `false`, the slot docs are omitted entirely.

  The injected slot docs are formatted as a markdown list:

    * `name` (required) - slot docs. Accepts attributes:
      * `name` (`:type`) (required) - attr docs. Defaults to `:default`.

  By default, all slots will have their docs injected into the function `@doc` string.
  To hide a specific slot, you can set the value of `:doc` to `false`.

  ## Example

      slot :header
      slot :inner_block, required: true
      slot :footer

      def modal(assigns) do
        ~CH"""
        <div class="modal">
          <div class="modal-header">
            {render_slot(@header) || "Modal"}
          </div>
          <div class="modal-body">
            {render_slot(@inner_block)}
          </div>
          <div class="modal-footer">
            {render_slot(@footer) || submit_button()}
          </div>
        </div>
        """
      end

  As shown in the example above, `render_slot/1` returns `nil` when an optional slot is declared
  and none is given. This can be used to attach default behaviour.
  '''
  @doc type: :macro
  defmacro slot(name, opts, block)

  defmacro slot(name, opts, do: block) when is_atom(name) and is_list(opts) do
    quote do
      Phoenix.Component.Declarative.__slot__!(
        __MODULE__,
        unquote(name),
        unquote(opts),
        __ENV__.line,
        __ENV__.file,
        fn -> unquote(block) end
      )
    end
  end

  @doc """
  Declares a slot. See `slot/3` for more information.
  """
  @doc type: :macro
  defmacro slot(name, opts \\ []) when is_atom(name) and is_list(opts) do
    {block, opts} = Keyword.pop(opts, :do, nil)

    quote do
      Phoenix.Component.Declarative.__slot__!(
        __MODULE__,
        unquote(name),
        unquote(opts),
        __ENV__.line,
        __ENV__.file,
        fn -> unquote(block) end
      )
    end
  end

  @doc ~S'''
  Declares attributes for a HEEx components.

  ## Arguments

  * `name` - an atom defining the name of the attribute. Note that attributes cannot define the
  same name as any other attributes or slots declared for the same component.

  * `type` - an atom defining the type of the attribute.

  * `opts` - a keyword list of options. Defaults to `[]`.

  ### Types

  An attribute is declared by its name, type, and options. The following types are supported:

  | Name            | Description                                                          |
  |-----------------|----------------------------------------------------------------------|
  | `:any`          | any term (including `nil`)                                           |
  | `:string`       | any binary string                                                    |
  | `:atom`         | any atom (including `true`, `false`, and `nil`)                      |
  | `:boolean`      | any boolean                                                          |
  | `:integer`      | any integer                                                          |
  | `:float`        | any float                                                            |
  | `:list`         | any list of any arbitrary types                                      |
  | `:map`          | any map of any arbitrary types                                       |
  | `:fun`          | any function                                                         |
  | `{:fun, arity}` | any function of arity                                                |
  | `:global`       | any common HTML attributes, plus those defined by `:global_prefixes` |
  | A struct module | any module that defines a struct with `defstruct/1`                  |

  Note only `:any` and `:atom` expect the value to be set to `nil`.

  ### Options

  * `:required` - marks an attribute as required. If a caller does not pass the given attribute,
  a compile warning is issued.

  * `:default` - the default value for the attribute if not provided. If this option is
    not set and the attribute is not given, accessing the attribute will fail unless a
    value is explicitly set with `assign_new/3`.

  * `:examples` - a non-exhaustive list of values accepted by the attribute, used for documentation
    purposes.

  * `:values` - an exhaustive list of values accepted by the attributes. If a caller passes a literal
    not contained in this list, a compile warning is issued.

  * `:doc` - documentation for the attribute.

  ## Compile-Time Validations

  LiveView performs some validation of attributes via the `:phoenix_live_view` compiler.
  When attributes are defined, LiveView will warn at compilation time on the caller if:

  * A required attribute of a component is missing.

  * An unknown attribute is given.

  * You specify a literal attribute (such as `value="string"` or `value`, but not `value={expr}`)
  and the type does not match. The following types currently support literal validation:
  `:string`, `:atom`, `:boolean`, `:integer`, `:float`, `:map` and `:list`.

  * You specify a literal attribute and it is not a member of the `:values` list.

  LiveView does not perform any validation at runtime. This means the type information is mostly
  used for documentation and reflection purposes.

  On the side of the LiveView component itself, defining attributes provides the following quality
  of life improvements:

  * The default value of all attributes will be added to the `assigns` map upfront.

  * Attribute documentation is generated for the component.

  * Required struct types are annotated and emit compilation warnings. For example, if you specify
  `attr :user, User, required: true` and then you write `@user.non_valid_field` in your template,
  a warning will be emitted.

  * Calls made to the component are tracked for reflection and validation purposes.

  ## Documentation Generation

  Public components that define attributes will have their attribute
  types and docs injected into the function's documentation, depending on the
  value of the `@doc` module attribute:

  * if `@doc` is a string, the attribute docs are injected into that string. The optional
  placeholder `[INSERT LVATTRDOCS]` can be used to specify where in the string the docs are
  injected. Otherwise, the docs are appended to the end of the `@doc` string.

  * if `@doc` is unspecified, the attribute docs are used as the default `@doc` string.

  * if `@doc` is `false`, the attribute docs are omitted entirely.

  The injected attribute docs are formatted as a markdown list:

    * `name` (`:type`) (required) - attr docs. Defaults to `:default`.

  By default, all attributes will have their types and docs injected into the function `@doc`
  string. To hide a specific attribute, you can set the value of `:doc` to `false`.

  ## Example

      attr :name, :string, required: true
      attr :age, :integer, required: true

      def celebrate(assigns) do
        ~CH"""
        <p>
          Happy birthday {@name}!
          You are {@age} years old.
        </p>
        """
      end
  '''
  @doc type: :macro
  defmacro attr(name, type, opts \\ []) do
    type = Macro.expand_literals(type, %{__CALLER__ | function: {:attr, 3}})
    opts = Macro.expand_literals(opts, %{__CALLER__ | function: {:attr, 3}})

    quote bind_quoted: [name: name, type: type, opts: opts] do
      Phoenix.Component.Declarative.__attr__!(
        __MODULE__,
        name,
        type,
        opts,
        __ENV__.line,
        __ENV__.file
      )
    end
  end

  ## Components

  import Kernel, except: [def: 2, defp: 2]
  import __MODULE__.Declarative
  alias __MODULE__.Declarative

  # We need to bootstrap by hand to avoid conflicts.
  [] = Declarative.__setup__(__MODULE__, [])

  attr = fn name, type, opts ->
    Declarative.__attr__!(__MODULE__, name, type, opts, __ENV__.line, __ENV__.file)
  end

  slot = fn name, opts ->
    Declarative.__slot__!(__MODULE__, name, opts, __ENV__.line, __ENV__.file, fn -> nil end)
  end

  @doc ~S'''
  Renders a form.

  This function receives a `Phoenix.HTML.Form` struct, generally created with
  `to_form/2`, and generates the relevant form tags. It can be used either
  inside LiveView or outside.

  > To see how forms work in practice, you can run
  > `mix phx.gen.live Blog Post posts title body:text` inside your Phoenix
  > application, which will setup the necessary database tables and LiveViews
  > to manage your data.

  ## Examples: inside LiveView

  Inside LiveViews, this component is typically called with
  as `for={@form}`, where `@form` is the result of the `to_form/1` function.
  `to_form/1` expects either a map or an [`Ecto.Changeset`](https://hexdocs.pm/ecto/Ecto.Changeset.html)
  as the source of data and normalizes it into `Phoenix.HTML.Form` structure.

  For example, you may use the parameters received in a
  `c:Phoenix.LiveView.handle_event/3` callback to create an Ecto changeset
  and then use `to_form/1` to convert it to a form. Then, in your templates,
  you pass the `@form` as argument to `:for`:

  ```heex
  <.form
    for={@form}
    phx-change="change_name"
  >
    <.input field={@form[:email]} />
  </.form>
  ```

  The `.input` component is generally defined as part of your own application
  and adds all styling necessary:

  ```heex
  def input(assigns) do
    ~CH"""
    <input type="text" name={@field.name} id={@field.id} value={@field.value} class="..." />
    """
  end
  ```

  A form accepts multiple options. For example, if you are doing file uploads
  and you want to capture submissions, you might write instead:

  ```heex
  <.form
    for={@form}
    multipart
    phx-change="change_user"
    phx-submit="save_user"
  >
    ...
    <input type="submit" value="Save" />
  </.form>
  ```

  Notice how both examples use `phx-change`. The LiveView must implement the
  `phx-change` event and store the input values as they arrive on change.
  This is important because, if an unrelated change happens on the page,
  LiveView should re-render the inputs with their updated values. Without `phx-change`,
  the inputs would otherwise be cleared. Alternatively, you can use `phx-update="ignore"`
  on the form to discard any updates.

  ### Using the `for` attribute

  The `for` attribute can also be a map or an Ecto.Changeset. In such cases,
  a form will be created on the fly, and you can capture it using `:let`:

  ```heex
  <.form
    :let={form}
    for={@changeset}
    phx-change="change_user"
  >
  ```

  However, such approach is discouraged in LiveView for two reasons:

    * LiveView can better optimize your code if you access the form fields
      using `@form[:field]` rather than through the let-variable `form`

    * Ecto changesets are meant to be single use. By never storing the changeset
      in the assign, you will be less tempted to use it across operations

  ### A note on `:errors`

  Even if `changeset.errors` is non-empty, errors will not be displayed in a
  form if [the changeset
  `:action`](https://hexdocs.pm/ecto/Ecto.Changeset.html#module-changeset-actions)
  is `nil` or `:ignore`.

  This is useful for things like validation hints on form fields, e.g. an empty
  changeset for a new form. That changeset isn't valid, but we don't want to
  show errors until an actual user action has been performed.

  For example, if the user submits and a `Repo.insert/1` is called and fails on
  changeset validation, the action will be set to `:insert` to show that an
  insert was attempted, and the presence of that action will cause errors to be
  displayed. The same is true for Repo.update/delete.

  Error visibility is handled by providing the action to `to_form/2`, which will
  set the underlying changeset action. You can also set the action manually by
  directly updating on the `Ecto.Changeset` struct field, or by using
  `Ecto.Changeset.apply_action/2`. Since the action can be arbitrary, you can
  set it to `:validate` or anything else to avoid giving the impression that a
  database operation has actually been attempted.

  ### Displaying errors on used and unused input fields

  Used inputs are only those inputs that have been focused, interacted with, or
  submitted by the client. In most cases, a user shouldn't receive error feedback
  for forms they haven't yet interacted with, until they submit the form. Filtering
  the errors based on used input fields can be done with `used_input?/1`.

  ## Example: outside LiveView (regular HTTP requests)

  The `form` component can still be used to submit forms outside of LiveView.
  In such cases, the standard HTML `action` attribute MUST be given.
  Without said attribute, the `form` method and csrf token are discarded.

  ```heex
  <.form :let={f} for={@changeset} action={~p"/comments/#{@comment}"}>
    <.input field={f[:body]} />
  </.form>
  ```

  In the example above, we passed a changeset to `for` and captured
  the value using `:let={f}`. This approach is ok outside of LiveViews,
  as there are no change tracking optimizations to consider.

  ### CSRF protection

  CSRF protection is a mechanism to ensure that the user who rendered
  the form is the one actually submitting it. This module generates a
  CSRF token by default. Your application should check this token on
  the server to avoid attackers from making requests on your server on
  behalf of other users. Phoenix by default checks this token.

  When posting a form with a host in its address, such as "//host.com/path"
  instead of only "/path", Phoenix will include the host signature in the
  token and validate the token only if the accessed host is the same as
  the host in the token. This is to avoid tokens from leaking to third
  party applications. If this behaviour is problematic, you can generate
  a non-host specific token with `Plug.CSRFProtection.get_csrf_token/0` and
  pass it to the form generator via the `:csrf_token` option.

  [INSERT LVATTRDOCS]
  '''
  @doc type: :component
  attr.(:for, :any, required: true, doc: "An existing form or the form source data.")

  attr.(:action, :string,
    doc: """
    The action to submit the form on.
    This attribute must be given if you intend to submit the form to a URL without LiveView.
    """
  )

  attr.(:as, :atom,
    doc: """
    The prefix to be used in names and IDs generated by the form.
    For example, setting `as: :user_params` means the parameters
    will be nested "user_params" in your `handle_event` or
    `conn.params["user_params"]` for regular HTTP requests.
    If you set this option, you must capture the form with `:let`.
    """
  )

  attr.(:csrf_token, :any,
    doc: """
    A token to authenticate the validity of requests.
    One is automatically generated when an action is given and the method is not `get`.
    When set to `false`, no token is generated.
    """
  )

  attr.(:errors, :list,
    doc: """
    Use this to manually pass a keyword list of errors to the form.
    This option is useful when a regular map is given as the form
    source and it will make the errors available under `f.errors`.
    If you set this option, you must capture the form with `:let`.
    """
  )

  attr.(:method, :string,
    doc: """
    The HTTP method.
    It is only used if an `:action` is given. If the method is not `get` nor `post`,
    an input tag with name `_method` is generated alongside the form tag.
    If an `:action` is given with no method, the method will default to the return value
    of `Phoenix.HTML.FormData.to_form/2` (usually `post`).
    """
  )

  attr.(:multipart, :boolean,
    default: false,
    doc: """
    Sets `enctype` to `multipart/form-data`.
    Required when uploading files.
    """
  )

  attr.(:rest, :global,
    include: ~w(autocomplete name rel enctype novalidate target),
    doc: "Additional HTML attributes to add to the form tag."
  )

  slot.(:inner_block, required: true, doc: "The content rendered inside of the form tag.")

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

    ~CH"""
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
  Renders nested form inputs for associations or embeds.

  [INSERT LVATTRDOCS]

  ## Examples

  ```heex
  <.form
    for={@form}
    phx-change="change_name"
  >
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

  ```heex
  <.inputs_for :let={ef} field={@form[:emails]}>
    <input type="hidden" name="mailing_list[emails_sort][]" value={ef.index} />
    <.input type="text" field={ef[:email]} placeholder="email" />
    <.input type="text" field={ef[:name]} placeholder="name" />
    <button
      type="button"
      name="mailing_list[emails_drop][]"
      value={ef.index}
      phx-click={JS.dispatch("change")}
    >
      <.icon name="hero-x-mark" class="w-6 h-6 relative top-2" />
    </button>
  </.inputs_for>

  <input type="hidden" name="mailing_list[emails_drop][]" />

  <button type="button" name="mailing_list[emails_sort][]" value="new" phx-click={JS.dispatch("change")}>
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

  Like before, this tells Ecto to delete the child at this index when the button is
  clicked. We use `phx-click={JS.dispatch("change")}` on the button to tell LiveView
  to treat this button click as a change event, rather than a submit event on the form,
  which invokes our form's `phx-change` binding.

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
  > The correct way to approach this problem is by computing any property either in
  > your LiveViews, by traversing the relevant changesets and data structures, or by
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
  attr.(:field, Phoenix.HTML.FormField,
    required: true,
    doc: "A %Phoenix.HTML.Form{}/field name tuple, for example: {@form[:email]}."
  )

  attr.(:id, :string,
    doc: """
    The id base to be used in the form inputs. Defaults to the parent form id. The computed
    id will be the concatenation of the base id with the field name, along with a book keeping
    index for each input in the list.
    """
  )

  attr.(:as, :atom,
    doc: """
    The name to be used in the form, defaults to the concatenation of the given
    field to the parent form name.
    """
  )

  attr.(:default, :any, doc: "The value to use if none is available.")

  attr.(:prepend, :list,
    doc: """
    The values to prepend when rendering. This only applies if the field value
    is a list and no parameters were sent through the form.
    """
  )

  attr.(:append, :list,
    doc: """
    The values to append when rendering. This only applies if the field value
    is a list and no parameters were sent through the form.
    """
  )

  attr.(:skip_hidden, :boolean,
    default: false,
    doc: """
    Skip the automatic rendering of hidden fields to allow for more tight control
    over the generated markup.
    """
  )

  attr.(:skip_persistent_id, :boolean,
    default: false,
    doc: """
    Skip the automatic rendering of hidden _persistent_id fields used for reordering
    inputs.
    """
  )

  attr.(:options, :list,
    default: [],
    doc: """
    Any additional options for the `Phoenix.HTML.FormData` protocol
    implementation.
    """
  )

  slot.(:inner_block, required: true, doc: "The content rendered for each nested form.")

  @persistent_id "_persistent_id"
  def inputs_for(assigns) do
    %Phoenix.HTML.FormField{field: field_name, form: parent_form} = assigns.field
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

    ~CH"""
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
        %Phoenix.HTML.Form{params: params} = form, {seen_ids, index} ->
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
    Phoenix.HTML.Form.input_name(form, field) <> "[]"
  end

  defp name_for_value_or_values(form, field, _value) do
    Phoenix.HTML.Form.input_name(form, field)
  end

  @doc """
  Generates a link to a given route.

  It is typically used with one of the three attributes:

    * `patch` - on click, it patches the current LiveView with the given path
    * `navigate` - on click, it navigates to a new LiveView at the given path
    * `href` - on click, it performs traditional browser navigation (as any `<a>` tag)

  [INSERT LVATTRDOCS]

  ## Examples

  ```heex
  <.link href="/">Regular anchor link</.link>
  ```

  ```heex
  <.link navigate={~p"/"} class="underline">home</.link>
  ```

  ```heex
  <.link navigate={~p"/?sort=asc"} replace={false}>
    Sort By Price
  </.link>
  ```

  ```heex
  <.link patch={~p"/details"}>view details</.link>
  ```

  ```heex
  <.link href={URI.parse("https://elixir-lang.org")}>hello</.link>
  ```

  ```heex
  <.link href="/the_world" method="delete" data-confirm="Really?">delete</.link>
  ```

  ## JavaScript dependency

  In order to support links where `:method` is not `"get"` or use the above data attributes,
  `Phoenix.HTML` relies on JavaScript. You can load `priv/static/phoenix_html.js` into your
  build tool.

  ### Data attributes

  Data attributes are added as a keyword list passed to the `data` key. The following data
  attributes are supported:

  * `data-confirm` - shows a confirmation prompt before generating and submitting the form when
  `:method` is not `"get"`.

  ### Overriding the default confirm behaviour

  `phoenix_html.js` does trigger a custom event `phoenix.link.click` on the clicked DOM element
  when a click happened. This allows you to intercept the event on its way bubbling up
  to `window` and do your own custom logic to enhance or replace how the `data-confirm`
  attribute is handled. You could for example replace the browsers `confirm()` behavior with
  a custom javascript implementation:

  ```javascript
  // Compared to a javascript window.confirm, the custom dialog does not block
  // javascript execution. Therefore to make this work as expected we store
  // the successful confirmation as an attribute and re-trigger the click event.
  // On the second click, the `data-confirm-resolved` attribute is set and we proceed.
  const RESOLVED_ATTRIBUTE = "data-confirm-resolved";
  // listen on document.body, so it's executed before the default of
  // phoenix_html, which is listening on the window object
  document.body.addEventListener('phoenix.link.click', function (e) {
    // Prevent default implementation
    e.stopPropagation();
    // Introduce alternative implementation
    var message = e.target.getAttribute("data-confirm");
    if(!message){ return; }

    // Confirm is resolved execute the click event
    if (e.target?.hasAttribute(RESOLVED_ATTRIBUTE)) {
      e.target.removeAttribute(RESOLVED_ATTRIBUTE);
      return;
    }

    // Confirm is needed, preventDefault and show your modal
    e.preventDefault();
    e.target?.setAttribute(RESOLVED_ATTRIBUTE, "");

    vex.dialog.confirm({
      message: message,
      callback: function (value) {
        if (value == true) {
          // Customer confirmed, re-trigger the click event.
          e.target?.click();
        } else {
          // Customer canceled
          e.target?.removeAttribute(RESOLVED_ATTRIBUTE);
        }
      }
    })
  }, false);
  ```

  Or you could attach your own custom behavior.

  ```javascript
  window.addEventListener('phoenix.link.click', function (e) {
    // Introduce custom behaviour
    var message = e.target.getAttribute("data-prompt");
    var answer = e.target.getAttribute("data-prompt-answer");
    if(message && answer && (answer != window.prompt(message))) {
      e.preventDefault();
    }
  }, false);
  ```

  The latter could also be bound to any `click` event, but this way you can be sure your custom
  code is only executed when the code of `phoenix_html.js` is run.

  ## CSRF Protection

  By default, CSRF tokens are generated through `Plug.CSRFProtection`.
  """
  @doc type: :component
  attr.(:navigate, :string,
    doc: """
    Navigates to a LiveView.
    When redirecting across LiveViews, the browser page is kept, but a new LiveView process
    is mounted and its contents is loaded on the page. It is only possible to navigate
    between LiveViews declared under the same router
    [`live_session`](`Phoenix.LiveView.Router.live_session/3`).
    When used outside of a LiveView or across live sessions, it behaves like a regular
    browser redirect.
    """
  )

  attr.(:patch, :string,
    doc: """
    Patches the current LiveView.
    The `handle_params` callback of the current LiveView will be invoked and the minimum content
    will be sent over the wire, as any other LiveView diff.
    """
  )

  attr.(:href, :any,
    doc: """
    Uses traditional browser navigation to the new location.
    This means the whole page is reloaded on the browser.
    """
  )

  attr.(:replace, :boolean,
    default: false,
    doc: """
    When using `:patch` or `:navigate`,
    should the browser's history be replaced with `pushState`?
    """
  )

  attr.(:method, :string,
    default: "get",
    doc: """
    The HTTP method to use with the link. This is intended for usage outside of LiveView
    and therefore only works with the `href={...}` attribute. It has no effect on `patch`
    and `navigate` instructions.

    In case the method is not `get`, the link is generated inside the form which sets the proper
    information. In order to submit the form, JavaScript must be enabled in the browser.
    """
  )

  attr.(:csrf_token, :any,
    default: true,
    doc: """
    A boolean or custom token to use for links with an HTTP method other than `get`.
    """
  )

  attr.(:rest, :global,
    include: ~w(download hreflang referrerpolicy rel target type),
    doc: """
    Additional HTML attributes added to the `a` tag.
    """
  )

  slot.(:inner_block,
    required: true,
    doc: """
    The content rendered inside of the `a` tag.
    """
  )

  def link(%{navigate: to} = assigns) when is_binary(to) do
    ~CH"""
    <a
      href={@navigate}
      data-phx-link="redirect"
      data-phx-link-state={if @replace, do: "replace", else: "push"}
      phx-no-format
      {@rest}
    >{render_slot(@inner_block)}</a>
    """
  end

  def link(%{patch: to} = assigns) when is_binary(to) do
    ~CH"""
    <a
      href={@patch}
      data-phx-link="patch"
      data-phx-link-state={if @replace, do: "replace", else: "push"}
      phx-no-format
      {@rest}
    >{render_slot(@inner_block)}</a>
    """
  end

  def link(%{href: href} = assigns) when href != "#" and not is_nil(href) do
    href = valid_destination!(href, "<.link>")
    assigns = assign(assigns, :href, href)

    ~CH"""
    <a
      href={@href}
      data-method={if @method != "get", do: @method}
      data-csrf={if @method != "get", do: csrf_token(@csrf_token, @href)}
      data-to={if @method != "get", do: @href}
      phx-no-format
      {@rest}
    >{render_slot(@inner_block)}</a>
    """
  end

  def link(%{} = assigns) do
    ~CH"""
    <a href="#" {@rest}>{render_slot(@inner_block)}</a>
    """
  end

  defp csrf_token(true, href), do: Plug.CSRFProtection.get_csrf_token_for(href)
  defp csrf_token(false, _href), do: nil
  defp csrf_token(csrf, _href) when is_binary(csrf), do: csrf

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

  @doc """
  Generates a dynamically named HTML tag.

  Raises an `ArgumentError` if the tag name is found to be unsafe HTML.

  [INSERT LVATTRDOCS]

  ## Examples

  ```heex
  <.dynamic_tag tag_name="input" name="my-input" type="text"/>
  ```

  ```html
  <input name="my-input" type="text"/>
  ```

  ```heex
  <.dynamic_tag tag_name="p">content</.dynamic_tag>
  ```

  ```html
  <p>content</p>
  ```
  """
  @doc type: :component
  attr.(:tag_name, :string, required: true, doc: "The name of the tag, such as `div`.")

  attr.(:name, :string,
    required: false,
    doc:
      "Deprecated: use tag_name instead. If tag_name is used, passed to the tag. Otherwise the name of the tag, such as `div`."
  )

  attr.(:rest, :global,
    doc: """
    Additional HTML attributes to add to the tag, ensuring proper escaping.
    """
  )

  slot.(:inner_block, [])

  def dynamic_tag(%{rest: rest} = assigns) do
    {tag_name, rest} =
      case assigns do
        %{tag_name: tag_name, name: name} ->
          {tag_name, Map.put(rest, :name, name)}

        %{tag_name: tag_name} ->
          {tag_name, rest}

        %{name: name} ->
          IO.warn("""
          Passing the tag name to `Phoenix.Component.dynamic_tag/1` using the `name` attribute is deprecated.

          Instead of:

              <.dynamic_tag name="p" ...>

          use `tag_name` instead:

              <.dynamic_tag tag_name="p" ...>
          """)

          {name, Map.delete(rest, :name)}
      end

    tag =
      case Phoenix.HTML.html_escape(tag_name) do
        {:safe, ^tag_name} ->
          tag_name

        {:safe, _escaped} ->
          raise ArgumentError,
                "expected dynamic_tag name to be safe HTML, got: #{inspect(tag_name)}"
      end

    assigns =
      assigns
      |> assign(:tag, tag)
      |> assign(
        :escaped_attrs,
        Phoenix.Template.HTMLEngine.TagHandler.HTML.attributes_escape(rest)
      )

    if assigns.inner_block != [] do
      ~CH"""
      {{:safe, [?<, @tag]}}{@escaped_attrs}{{:safe, [?>]}}{render_slot(@inner_block)}{{:safe,
       [?<, ?/, @tag, ?>]}}
      """
    else
      ~CH"""
      {{:safe, [?<, @tag]}}{@escaped_attrs}{{:safe, [?/, ?>]}}
      """
    end
  end

  @doc """
  Intersperses separator slot between an enumerable.

  Useful when you need to add a separator between items such as when
  rendering breadcrumbs for navigation. Provides each item to the
  inner block.

  ## Examples

  ```heex
  <.intersperse :let={item} enum={["home", "profile", "settings"]}>
    <:separator>
      <span class="sep">|</span>
    </:separator>
    {item}
  </.intersperse>
  ```

  Renders the following markup:

  ```html
  home <span class="sep">|</span> profile <span class="sep">|</span> settings
  ```
  """
  @doc type: :component
  attr.(:enum, :any, required: true, doc: "the enumerable to intersperse with separators")
  slot.(:inner_block, required: true, doc: "the inner_block to render for each item")
  slot.(:separator, required: true, doc: "the slot for the separator")

  def intersperse(assigns) do
    ~CH"""
    <%= for item <- Enum.intersperse(@enum, :separator) do %>
      {if item == :separator do
        render_slot(@separator)
      else
        render_slot(@inner_block, item)
      end}
    <% end %>
    """noformat
  end
end
