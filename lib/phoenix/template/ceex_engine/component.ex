defmodule Phoenix.Template.CEExEngine.Component do
  @moduledoc ~S'''
  Defines reusable components.

  A component is any function that receives an assigns map as an argument
  and returns a CH template.

      defmodule MyComponent do
        use Phoenix.Component

        def greet(assigns) do
          ~CE"""
          <p>Hello, {@name}!</p>
          """
        end
      end

  When invoked within a `.ch` template file: or `~CE` sigil

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
    ~CE"""
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
    ~CE"""
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
      ~CE"""
      <h1>{@title}</h1>
      """
    end

    attr :name, :string, required: true

    def greet(assigns) do
      ~CE"""
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
    ~CE"""
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
    ~CE"""
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
    ~CE"""
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
        ~CE"""
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
        ~CE"""
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
        ~CE"""
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
          ~CE"""
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

  Debug annotations work across any `~CE` or `.html.heex` template.
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
      ~CE"""
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

  import Phoenix.Template.CEExEngine.Sigil
  alias Phoenix.Template.CEExEngine.Compiler

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

    ~CE"""
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

        ~CE"""
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
    excluded_keys = Compiler.__reserved_assigns__() ++ exclude
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
        ~CE"""
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

    ~CE"""
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
  Embedded templates also support declarative assigns
  via bodyless function definitions, for example:

      defmodule MyAppWeb.Components do
        use Phoenix.Component

        embed_templates "pages/*"

        attr :name, :string, required: true
        def welcome_page(assigns)

        slot :header
        def about_page(assigns)
      end

  """

  @doc false
  defmacro __using__(opts \\ []) do
    quote bind_quoted: [opts: opts] do
      use Phoenix.Template.CEExEngine.DeclarativeAssigns, opts

      import Phoenix.Template, only: [embed_templates: 1]
      import Phoenix.Template.CEExEngine.Sigil
      import Phoenix.Template.CEExEngine.Component
    end
  end
end
