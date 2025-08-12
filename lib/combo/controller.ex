defmodule Combo.Controller do
  @moduledoc """
  Defines a controller.

  A controller is a module that contains actions. And, actions are regular
  functions that receive a`Plug.Conn` struct and params. For example:

      defmodule Demo.Web.UserController do
        use Combo.Controller, formats: [:html]

        def show(conn, %{"id" => id}) do
          # user = ...
          render(conn, :show, user: user)
        end
      end

  If we mount the controller and action to a route, like:

      get "/users/:id", Demo.Web.UserController, :show

  Then, when a request matching the route arrives, the action will run.

  Let's explore more related concepts.

  ## Formats

  One of the main features provided by controllers is the ability to perform
  content negotiation and render templates based on information sent by the
  client.

  ## Rendering

  There are two ways to render content in a controller.

  One approach is to invoke format-specific functions, such as `html/2` and
  `json/2`.

  Another approach is to render templates.

  The latter approach is the commonly used one. And, it's done by specifying
  the option `:formats` when defining the controller:

      use Combo.Controller, formats: [:html, :json]

   Now, when invoking `render/3`, a controller named `Demo.Web.UserController`
   will invoke `Demo.Web.UserHTML` and `Demo.Web.UserJSON` respectively
   when rendering each format:

      def show(conn, %{"id" => id}) do
        user = Repo.get(User, id)

        # Will invoke UserHTML.show(%{user: user}) for HTML requests
        # Will invoke UserJSON.show(%{user: user}) for JSON requests
        render(conn, :show, user: user)
      end

  You can also specify formats to render by calling `put_view/2` directly with
  a connection. For example, instead of inferring the the view names from the
  controller, as done in:

      use Combo.Controller, formats: [:html, :json]

  You can write the above explicitly in your actions as:

      put_view(conn, html: Demo.Web.UserHTML, json: Demo.Web.UserJSON)

  Or as a plug:

      plug :put_view, html: Demo.Web.UserHTML, json: Demo.Web.UserJSON

  ## Layouts

  Many applications have shared content, most often the `<head>` tag and its
  contents. In Combo, this is done via the `put_root_layout/2`:

      put_root_layout(conn, html: {Demo.Web.Layouts, :root})

  Or, as a plug:

      plug :put_root_layout, html: {Demo.Web.Layouts, :root}

  You can also specify controller-specific layouts using `put_layout/2`,
  although this functionality is discouraged in favor of using components.

  ## Connection

  A controller by default provides many convenience functions for
  manipulating the connection, rendering templates, and more.

  Those functions are imported from two modules:

    * `Plug.Conn` - a collection of low-level functions to work with
      the connection

    * `Combo.Controller` - functions provided by Phoenix
      to support rendering, and other Phoenix specific behaviour

  If you want to have functions that manipulate the connection
  without fully implementing the controller, you can import both
  modules directly instead of `use Combo.Controller`.


  ## Plug pipeline

  As with routers, controllers also have their own plug pipeline.
  However, different from routers, controllers have a single pipeline:

      defmodule MyAppWeb.UserController do
        use MyAppWeb, :controller

        plug :authenticate, usernames: ["jose", "eric", "sonny"]

        def show(conn, params) do
          # authenticated users only
        end

        defp authenticate(conn, options) do
          if get_session(conn, :username) in options[:usernames] do
            conn
          else
            conn |> redirect(to: "/") |> halt()
          end
        end
      end

  The `:authenticate` plug will be invoked before the action. If the
  plug calls `Plug.Conn.halt/1` (which is by default imported into
  controllers), it will halt the pipeline and won't invoke the action.

  ### Guards

  `plug/2` in controllers supports guards, allowing a developer to configure
  a plug to only run in some particular action.

      plug :do_something when action in [:show, :edit]

  Due to operator precedence in Elixir, if the second argument is a keyword list,
  we need to wrap the keyword in `[...]` when using `when`:

      plug :authenticate, [usernames: ["jose", "eric", "sonny"]] when action in [:show, :edit]
      plug :authenticate, [usernames: ["admin"]] when not action in [:index]

  The first plug will run only when action is show or edit. The second plug will
  always run, except for the index action.

  Those guards work like regular Elixir guards and the only variables accessible
  in the guard are `conn`, the `action` as an atom and the `controller` as an
  alias.

  ## Controllers are plugs

  Like routers, controllers are plugs, but they are wired to dispatch
  to a particular function which is called an action.

  For example, the route:

      get "/users/:id", UserController, :show

  will invoke `UserController` as a plug:

      UserController.call(conn, :show)

  which will trigger the plug pipeline and which will eventually
  invoke the inner action plug that dispatches to the `show/2`
  function in `UserController`.

  As controllers are plugs, they implement both [`init/1`](`c:Plug.init/1`) and
  [`call/2`](`c:Plug.call/2`), and it also provides a function named `action/2`
  which is responsible for dispatching the appropriate action
  after the plug stack (and is also overridable).

  ### Overriding `action/2` for custom arguments

  Phoenix injects an `action/2` plug in your controller which calls the
  function matched from the router. By default, it passes the conn and params.
  In some cases, overriding the `action/2` plug in your controller is a
  useful way to inject arguments into your actions that you would otherwise
  need to repeatedly fetch off the connection. For example, imagine if you
  stored a `conn.assigns.current_user` in the connection and wanted quick
  access to the user for every action in your controller:

      def action(conn, _) do
        args = [conn, conn.params, conn.assigns.current_user]
        apply(__MODULE__, controller_action_name!(conn), args)
      end

      def index(conn, _params, user) do
        videos = Repo.all(user_videos(user))
        # ...
      end

      def delete(conn, %{"id" => id}, user) do
        video = Repo.get!(user_videos(user), id)
        # ...
      end

  """

  @type format :: atom()
  @type suffix :: String.t()
  @type formats :: [format()] | [{format(), suffix()}]

  @type opt :: {:formats, formats()}
  @type opts :: [opt()]

  @doc """
  Defines a controller.

  It accepts the following options:

    * `:formats` - the formats a controller can render.

  If you don't expect to render any format upfront, you can ignore `:formats`
  option:

      use Combo.Controller

  Or, set it to an empty list:

      use Combo.Controller, formats: []

  If you want to render some formats, and follow the Combo convention for
  inferring view names, you can set `:formats` option to a list of formats:

      use Combo.Controller, formats: [:html, :json]
      # If the controller name is `Demo.Web.UserController`, the inferred
      # view names are `Demo.Web.UserHTML` and `Demo.Web.UserJSON`.

  If you want to customize the view names, you can set `:formats` option to
  a list of `{format, suffix}` tuples:

      use Combo.Controller, formats: [html: "View", json: "View"]
      # If the controller name is `Demo.Web.UserController`, the inferred view
      # names are `Demo.Web.UserView` and `Demo.Web.UserView`.

  """
  @spec __using__(opts()) :: Macro.t()
  defmacro __using__(opts) do
    opts =
      if Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, __CALLER__))
      else
        opts
      end

    quote bind_quoted: [opts: opts] do
      import Plug.Conn
      import Combo.Conn
      import Combo.Controller

      use Combo.Controller.Pipeline

      with view_formats <- Combo.Controller.__view_formats__(__MODULE__, opts) do
        plug :put_new_view, view_formats
      end
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:action, 2}})

  defp expand_alias(other, _env), do: other

  @doc false
  def __view_formats__(controller_module, opts) do
    base = Combo.Naming.unsuffix(controller_module, "Controller")

    case Keyword.get(opts, :formats, []) do
      formats when is_list(formats) ->
        Enum.map(formats, fn
          format when is_atom(format) ->
            {format, :"#{base}#{String.upcase(to_string(format))}"}

          {format, suffix} ->
            {format, :"#{base}#{suffix}"}
        end)

      other ->
        raise ArgumentError, """
        expected :formats option to be a list following this spec:

            [format()] | [{format(), suffix()}]

        Got:

            #{inspect(other)}
        """
    end
  end

  @doc """
  Registers the plug to call as a fallback to the controller action.

  A fallback plug is useful to translate common domain data structures into a
  valid `%Plug.Conn{}` response. If the controller action fails to return a
  `%Plug.Conn{}`, the fallback plug will be called and receive the controller's
  `%Plug.Conn{}` as it was before the action was invoked along with the value
  returned from the controller action.

  ## Examples

      defmodule Demo.Web.UserController do
        use Combo.Controller, formats: [:html]

        action_fallback Demo.Web.FallbackController

        def show(conn, %{"id" => id}, current_user) do
          with {:ok, post} <- Blog.fetch_post(id),
               :ok <- Authorizer.authorize(current_user, :view, post) do

            render(conn, "show.json", post: post)
          end
        end
      end

  In the above example, `with` is used to match only a successful post fetch,
  followed by valid authorization for the current user. If either of those
  fail to match, `with` will not invoke the render block and instead return
  the unmatched value. In this case, imagine `Blog.fetch_post/2` returned
  `{:error, :not_found}` or `Authorizer.authorize/3` returned
  `{:error, :unauthorized}`. For cases where these data structures serve as
  return values across multiple boundaries in our domain, a single fallback
  controller can be used to translate the value into a valid response. For
  example, you could write the following fallback controller to handle the
  above values:

      defmodule Demo.Web.FallbackController do
        use Combo.Controller, formats: [:html]

        def call(conn, {:error, :not_found}) do
          conn
          |> put_status(:not_found)
          |> put_view(html: Demo.Web.ErrorHTML)
          |> render(:"404")
        end

        def call(conn, {:error, :unauthorized}) do
          conn
          |> put_status(:forbidden)
          |> put_view(html: Demo.Web.ErrorHTML)
          |> render(:"403")
        end
      end

  """
  defmacro action_fallback(plug) do
    Combo.Controller.Pipeline.__action_fallback__(plug, __CALLER__)
  end
end
