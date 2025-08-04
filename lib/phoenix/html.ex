defmodule Phoenix.HTML do
  @moduledoc ~S'''
  All the things about HTML templates.

  This module is built on top of:

    * `Phoenix.Template`
    * `Phoenix.Template.CEExEngine`

  ## Syntax

  ### EEx

  As the name "CEEx" suggests, CEEx is built on top of `EEx`, and therefore it
  supports all EEx features.

  #### Tags

    * `<%= expression %>` - expression tag, which inserts the value of
      expression.
    * `<% expression %>` - execution tag, which executes expression, but
      doesn't insert the value.
    * `<%!-- comments --%>` - comment tag, which is removed from the final
      output.
    * `<%% content %>` - quotation tag, which inserts literal `<% content %>`.

  #### Interpolating blocks

  `if`:

  ```ceex
  <%= if ... do %>
    ...
  <% end %>
  ```

  `case`:
  ```ceex
  <%= case ... do %>
    <% ... -> %>
      ...
    <% ... -> %>
      ...
  <% end %>
  ```

  `for`:
  ```ceex
  <%= for ... do %>
    ...
  <% end %>
  ```

  ### CEEx extensions

  #### Curly-interpolation

  Besides EEx's intepolation syntax - `<%= expression %>`, CEEx introduces a
  syntax for HTML-aware interpolation - `{expression}`. It can be used within
  HTML tag attributes and HTML tag contents.

  ##### Interpolating the value of tag attributes

  To interpolate the value of an tag attribute, use `{}` to assign an
  expression to the tag attribute:

  ```ceex
  <div class={expression}>
    ...
  </div>
  ```

  Additionally, there are values which have special meanings when they are used
  as the values of tag attributes:

    * if a value is `true`, the attribute is treated as boolean attribute, and
      it will be rendered with no value at all.
      For example, `<input required={true}>` is rendered as `<input required>`.

    * if a value is `false` or `nil`, the attribute is treated as boolean
      attribute, and it won't be rendered at all.
      For example, `<input required={false}>` is rendered as `<input>`.

    * if a value a list, the attribute's value is built by joining all truthy
      elements in the list with `" "`.
      For example: `<input class={["btn", nil, false, "btn-primary"]}>` is
      rendered as `<input class="btn btn-primary">`.

  ##### Interpolating multiple attributes

  To interpolate multiple attributes, use `{}` without assigning expression
  to any specific attribute:

  ```ceex
  <div {expression}>
    ...
  </div>
  ```

  And the `expression` must be either a keyword list or a map containing the
  key-value pairs representing the attributes.

  ##### Interpolating tag contents

  To interpolate a tag content:

  ```ceex
  <p>Hello, {expression}</p>
  ```

  ##### Limitations

  Curly-interpolation is easy to use, but it has limitations:

    * it can't be used inside `<script>` and `<style>` tags, as that would make
      writing JS and CSS quite tedious.

    * it doesn't support interpolating blocks, such as `if`, `for` or `case`
      blocks. (But, for conditionals and for-comprehensions, there are built-in
      support in CEEx, which we will explained later.)

  For these cases, you have to use EEx tags as the workaround. For example:

  ```ceex
  <script>
    window.URL = "<%= expression %>"
  </script>
  ```

  ```ceex
  <%= if condition do %>
    <p>Hello, {expression}</p>
  <% end %>
  ```

  #### Disabling curly-interpolation

  Curly-interpolation is allowed to be disabled in a given tag and its children by
  adding the `phx-no-curly-interpolation` attribute. For example:

  ```ceex
  <p phx-no-curly-interpolation>
    Hello, {expression}
  </p>
  ```

  > #### Curly braces in text within tag content {: .tip}
  >
  > If you have text in your tag content, which includes curly braces you can
  > use `&lbrace;` or `<%= "{" %>` to prevent them from being considered the
  > start of interpolation.

  #### Special attributes

  Besides normal HTML attributes, CEEx supports some special attributes.

  ##### :if and :for

  They are syntax sugar for `<%= if ... do %>` and `<%= for ... do %>`. They can
  be used in HTML tags, components and slots.

  ```ceex
  <p :if={@admin?}>secret</p>

  <%!-- same as --%>
  <%= if @admin? do %>
    <p>secret</p>
  <% end %>
  ```

  ```ceex
  <table>
    <tr :for={user <- @users}>
      <td>{user.name}</td>
    </tr>
  <table>

  <%!-- same as --%>
  <table>
    <%= for user <- @users do %>
      <tr>
        <td>{user.name}</td>
      </tr>
    <% end %>
  <table>
  ```

  We can also combine `:for` and `:if`:

  ```ceex
  <table>
    <tr :for={user <- @users} :if={user.vip? == true}>
      <td>{user.name}</td>
    </tr>
  <table>

  <%!-- same as --%>
  <table>
    <%= for user <- @users, user.vip? == true do %>
      <tr>
        <td>{user.name}</td>
      </tr>
    <% end %>
  <table>
  ```

  These syntax sugars is easy to use, but it still has limitations:

    * Unlike Elixir's regular `for`, `:for` does not support multiple
      generators in one expression.

  ##### :let

  It's used to yield a value back to the caller of component. They can
  be used by components and slots.

  This is used by components and slots which want to yield a value back to the
  caller. For an example:

  ```ceex
  <.form :let={f} for={@form} >
    <.input field={f[:username]} type="text" />
    ...
  </.form>
  ```

  We'll talk about it when introducing slots.

  ### `assigns` and `@` symbol

  `assigns` refers to the external data which is available in templates. If we
  want to pass external data into templates, we put data into `assigns`.

  And, when accessing external data, we can use `assigns` directly, or its
  syntax sugar `@`.

  ## Creating templates

  There are two ways to create templates, inline templates or template files.

  Inline templates are good choice for small templates. And, template files are
  good choice when having a lot of markup.

  ### Inline templates

  Inline templates are defined with `~CE` sigil. For example:

  ```elixir
  ~CE"""
  <p>Hello, {@name}!</p>
  """
  ```

  ### Template files

  Template files are those with the `.html.ceex` extension.

  For example, imagine a file `welcome.html.ceex` with following content:

  ```ceex
  <p>Hello, {@name}!</p>
  ```

  ## Creating components

  In fact, standalone templates are useless on their own, as there is no way
  to call them. To make them callable, templates must be wrapped as components.

  But, what is a component?

  A component is a function that accepts an `assigns` map as an argument and
  returns a template.

  Next, we will wrap templates as components.

  ### Components using inline templates

  ```elixir
  defmodule DemoWeb.Component do
    use Combo.HTML

    def welcome(assigns) do
      ~CE"""
      <p>Hello, {@name}!</p>
      """
    end
  end
  ```

  ### Components using template files

  Imagine a directory listing:

  ```text
  ├── pages.ex
  ├── pages
  │   ├── welcome.html.ceex
  │   └── contact.html.ceex
  ```

  We can embed the template files as components into a module:

  ```elixir
  defmodule DemoWeb.Pages do
    use Combo.HTML

    embed_templates "pages/*"
  end
  ```

  Effectively, it is equivalent to:

  ```elixir
  defmodule DemoWeb.Pages do
    def welcome(assigns) do
      # the content of compiled welcome.html.ceex
    end

    def contact(assigns) do
      # the content of compiled contact.html.ceex
    end
  end
  ```

  ## Calling components

  Before introducing how to call a component, let's explain two terms:

    * remote components, which are components defined in external modules.
    * local components, which are components defined in current module, or
      components imported into current module.

  To call components, CEEx provides an HTML-like notation.

  For a remote component, the caller should call it with the qualified name
  of the component:

  ```ceex
  <DemoWeb.Component.welcome name="Charlie Brown" />
  ```

  For a local component, the caller can call it with the component name
  prefixing a leading dot:

  ```ceex
  <.greet name="Charlie Brown" />
  ```

  ## Declarative API of assigns

  ### Declaring attributes

  `Combo.HTML` provides `attr/3` used to declare an attribute for a component.

  For example:

  ```ceex
  attr :name, :string, required: true
  attr :age, :integer, required: true

  def welcome(assigns) do
    ~CE"""
    <p>Hello, {@name}!</p>
    """
  end
  ```

  See `Phoenix.Template.CEExEngine.DeclarativeAssigns.attr/3` for more
  information.

  #### Global attributes

  There is a special case that requires detailed explanation - global attributes.

  A global attribute is a special attribute which collects all attributes that
  are not explicitly declared by `attr/3`.

  The collected attributes can be:

    * attributes listed in HTML standard. See
      [Global attributes](https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes)
      for a complete list of attributes.
    * attributes specified by `:include` option (to be explained later).
    * attributes prefixed with custom global prefixes (to be explained later).

  Let's look at an example first. Below is a component that accepts a global
  attribute:

      attr :message, :string, required: true
      attr :rest, :global

      def notification(assigns) do
        ~H"""
        <span {@rest}>{@message}</span>
        """
      end

  The caller can pass multiple attributes to it, such as `class`, `data-*`, etc:

  ```ceex
  <.notification message="You've got mail!" class="bg-green-200" data-action="close" />
  ```

  Rendering the following HTML:

  ```html
  <span class="bg-green-200" data-action="close">You've got mail!</span>
  ```

  Note that the component did not explicitly declare a `class` or `data-state`
  attribute.

  ##### `:default` option

  The `:default` option specifies the default value, which will be merged with
  attributes provided by the caller. For example, we can declare a default
  `class`:

      attr :rest, :global, default: %{class: "bg-blue-200"}

  Now, we can call the component without a `class` attribute:

  ```ceex
  <.notification message="You've got mail!" data-action="close" />
  ```

  Rendering the following HTML:

  ```html
  <span class="bg-blue-200" data-action="close">You've got mail!</span>
  ```

  ##### `:include` option

  The `:include` option specifies extra attributes to be included. For example:

     attr :rest, :global, include: ~w(form)

  The `:include` option is useful to apply global additions on a case-by-case
  basis, but sometimes we want to extend existing components with new global
  attributes, such as Alpine.js' `x-` prefixes, which we'll outline next.

  ##### Global prefixes

  All attributes prefixed with global prefixes, will be collected by a global
  attribute. By default, the following global prefixes are supported:

    * `data-`
    * `aria-`

  To add extra global prefixes, let's say adding the `x-` prefix used by
  [Alpine.js](https://alpinejs.dev/), we can pass the `:global_prefixes` option
  to `use Combo.HTML`:

      use Combo.HTML, global_prefixes: ~w(x-)

  ### Declaring slots

  In addition to attributes, components can accept blocks of CEEx content,
  referred to as slots.

  `Combo.HTML` provides `slot/3` used to declare a slot for a component.

      slot :inner_block, required: true

      def button(assigns) do
        ~H"""
        <button>
          {render_slot(@inner_block)}
        </button>
        """
      end

  The expression `render_slot(@inner_block)` renders the CEEx content. You can
  call this component like:

  ```ceex
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

  The example above uses the default slot, accessible as an assign named
  `@inner_block`, to render CEEx content by calling `render_slot/1`.

  #### Passing value to slots

  If the values rendered in the slot need to be dynamic, you can pass a value
  back to the CEEx content by calling `render_slot/2`:

      attr :entries, :list, default: []
      slot :inner_block, required: true

      def list(assigns) do
        ~H"""
        <ul>
          <li :for={entry <- @entries}>{render_slot(@inner_block, entry)}</li>
        </ul>
        """
      end

  When calling the component, we can use the special attribute `:let` to take
  the value that the component passes back and bind it to a variable:

  ```heex
  <.list :let={fruit} entries={~w(apples bananas cherries)}>
    I like <b>{fruit}</b>!
  </.list>
  ```

  Which renders the following HTML:

  ```html
  <ul>
    <li>I like <b>apples</b>!</li>
    <li>I like <b>bananas</b>!</li>
    <li>I like <b>cherries</b>!</li>
  </ul>
  ```

  #### Named slots

  In addition to the default slot, components can accept multiple, named slots.
  For example, imagine a modal component that has a header, body, and footer:

      slot :header
      slot :inner_block, required: true
      slot :footer, required: true

      def modal(assigns) do
        ~H"""
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

  You can call this component using the named slot syntax:

  ```ceex
  <.modal>
    This is the body, everything not in a named slot is rendered in the default slot.
    <:footer>
      This is the bottom of the modal.
    </:footer>
  </.modal>
  ```

  Which renders the following HTML:

  ```html
  <div class="modal">
    <div class="modal-header">
      Modal
    </div>
    <div class="modal-body">
      This is the body, everything not in a named slot is rendered in the default slot.
    </div>
    <div class="modal-footer">
      This is the bottom of the modal.
    </div>
  </div>
  ```

  As shown in the example, `render_slot/1` returns `nil` when an optional slot
  is declared and none is given. This can be used to attach default behaviour.

  #### Slot attributes

  Named slots can also accept attributes, defined by passing a block to the
  `slot/3` macro. If multiple pieces of content are passed, `render_slot/2`
  will merge and render all the values.

  For example, image a table component:

      slot :column do
        attr :label, :string, required: true
      end

      attr :rows, :list, default: []

      def table(assigns) do
        ~H"""
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

  You can call this component like:

  ```ceex
  <.table rows={[%{name: "Jane", age: "34"}, %{name: "Bob", age: "51"}]}>
    <:column :let={user} label="Name">
      {user.name}
    </:column>
    <:column :let={user} label="Age">
      {user.age}
    </:column>
  </.table>
  ```

  which renders the following HTML:

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

  See `Phoenix.Template.CEExEngine.DeclarativeAssigns.slot/3` for more
  information.

  ## Dynamic Component Rendering

  Sometimes you might need to decide at runtime which component to render.
  Because components are just regular functions, we can leverage Elixir's
  `apply/3` function to dynamically call a module and/or function passed in

  For example, image a component like this:

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

        # call the function with remaining assigns
        apply(mod, func, [assigns])
      end

  And, a component like this:

      defmodule DemoWeb.Components do
        attr :shared, :string, required: true

        slot :named_slot, required: true
        slot :inner_block, required: true

        def example(assigns) do
          ~H"""
          <p>Dynamic component with shared assigns: {@shared}</p>
          {render_slot(@inner_block)}
          {render_slot(@named_slot)}
          """
        end
      end

  Then, we can use the `dynamic_component` function like:

  ```ceex
  <.dynamic_component
    module={DemoWeb.Components}
    function={:example}
    shared="Yay Elixir!"
  >
    <p>Howdy from the inner block!</p>
    <:named_slot>
      <p>Howdy from the named slot!</p>
    </:named_slot>
  </.dynamic_component>
  ```

  Which renders the following HTML:

  ```html
  <p>Dynamic component with shared assigns: Yay Elixir!</p>
  <p>Howdy from the inner block!</p>
  <p>Howdy from the named slot!</p>
  ```

  ## Debug annotations

  CEEx support adding debug annotations to the rendered templates.

  Debug annotations are special HTML comments that help to identify which
  component is used for rendering content of rendered templates.

  For example, imagine the following template:

  ```ceex
  <.header>
    <.button>Save</.button>
  </.header>
  ```

  By enabling debug annotations, the rendered templates would receive the
  comments like this:

  ```html
  <!-- @caller lib/demo_web/home_live.ex:20 -->
  <!-- <DemoWeb.Components.header> lib/demo_web/components.ex:123 -->
  <header class="p-5">
    <!-- @caller lib/demo_web/home_live.ex:48 -->
    <!-- <DemoWeb.Components.button> lib/demo_web/components.ex:456 -->
    <button class="px-2 bg-indigo-500 text-white">Save</button>
    <!-- </DemoWeb.Components.button> -->
  </header>
  <!-- </DemoWeb.Components.header> -->
  ```

  To enable debug annotations, put following configuration into
  `config/dev.exs` file:

  ```elixir
  config :combo, :template, debug_annotations: true
  ```

  Note that changing this configuration will require `mix clean` and a full recompile.

  ## Code formatting

  You can automatically format CEEx template files (using .ceex extension) and
  inline templates (using `~CE` sigil) using `Combo.HTML.Formatter`. Please
  check that module for more information.
  '''

  @doc """
  Building blocks for working with HTML.


  It provides following main functionalities:

    * Form handling
    * A tiny JavaScript library to enhance applications

  ## HTML safety

  It is to provide convenience functions for escaping and marking HTML code
  as safe.

  By default, interpolated data in templates is considered unsafe:

  ```ch
  <%= "<hello>" %>
  ```

  will be rendered as:

  ```html
  &lt;hello&gt;
  ```

  However, in some cases, you may want to tag it as safe and show its "raw"
  contents:

  ```ch
  <%= raw "<hello>" %>
  ```

  will be rendered as

  ```html
  <hello>
  ```

  ## Form handling

  See `Phoenix.HTML.Form`.

  ## JavaScript library

  This project ships with a tiny bit of JavaScript that listens
  to all click events to:

    * Support `data-confirm="message"` attributes, which shows
      a confirmation modal with the given message

    * Support `data-method="patch|post|put|delete"` attributes,
      which sends the current click as a PATCH/POST/PUT/DELETE
      HTTP request. You will need to add `data-to` with the URL
      and `data-csrf` with the CSRF token value

    * Dispatch a "phoenix.link.click" event. You can listen to this
      event to customize the behaviour above. Returning false from
      this event will disable `data-method`. Stopping propagation
      will disable `data-confirm`

  To use the functionality above, you must load `priv/static/phoenix_html.js`
  into your build tool.

  ### Overriding the default confirmation behaviour

  You can override the default implementation by hooking
  into `phoenix.link.click`. Here is an example:

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

  """

  @doc false
  defmacro __using__(opts \\ []) do
    quote bind_quoted: [opts: opts] do
      import Phoenix.Template, only: [embed_templates: 1]
      use Phoenix.Template.CEExEngine, opts
    end
  end

  @doc """
  Marks the given content as raw.

  This means any HTML code inside the given
  string won't be escaped.

      iex> raw({:safe, "<hello>"})
      {:safe, "<hello>"}

      iex> raw("<hello>")
      {:safe, "<hello>"}

      iex> raw(nil)
      {:safe, ""}

  """
  @spec raw(Combo.SafeHTML.safe() | iodata() | nil) :: Combo.SafeHTML.safe()
  def raw({:safe, _} = safe), do: safe
  def raw(nil), do: {:safe, ""}
  def raw(value) when is_binary(value) or is_list(value), do: {:safe, value}
end
