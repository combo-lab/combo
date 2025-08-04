defmodule Phoenix.Template.CEExEngine.Component do
  @moduledoc false

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
end
