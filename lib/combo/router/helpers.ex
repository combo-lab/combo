defmodule Combo.Router.Helpers do
  @moduledoc """
  Generates a module for named routes helpers and generic url helpers.

  Named routes helpers exist to avoid hardcoding routes, if you wrote
  `<a href="/login">` and then changed your router, the link would point to a
  page that no longer exist. By using router helpers, you can make sure it
  always points to a valid URL in your router.

  Generic url helpers exist for convenience.

  ## Examples

      defmodule MyApp.Web.Router do
        use Combo.Router
        # ...
      end

  It will generated a module named `MyApp.Web.Router.Helpers`, and following
  functions are available.

  Name routes helpers:

    * `*_url/_`
    * `*_path/_`

  Generic url helpers:

    * `url/_`
    * `path/_`
    * `static_url/_`
    * `static_path/_`
    * `static_integrity/_`

  ## Forwarded routes

  Forwarded routes are also resolved automatically. For example, imagine you
  have a forward path to an admin router in your main router:

      defmodule MyApp.Web.Router do
        # ...
        forward "/admin", MyApp.Web.AdminRouter
      end

      defmodule MyApp.Web.AdminRouter do
        # ...
        get "/users", MyApp.Web.Admin.UserController
      end

  """

  alias Combo.Router.Route
  alias Plug.Conn

  @doc """
  Generates the helper module for the given environment and routes.
  """
  def define(env, routes) do
    # Ignore any route without helper or forwards.
    routes =
      Enum.reject(routes, fn {route, _exprs} ->
        is_nil(route.helper) or route.kind == :forward
      end)

    groups = Enum.group_by(routes, fn {route, _exprs} -> route.helper end)

    helpers =
      for {_helper, helper_routes} <- groups,
          {_, [{route, exprs} | _]} <-
            helper_routes
            |> Enum.group_by(fn {route, exprs} -> [length(exprs.binding) | route.plug_opts] end)
            |> Enum.sort(),
          do: def_helper(route, exprs)

    # It is in general bad practice to generate large chunks of code inside
    # quoted expressions. However, we can get away with this here for two
    # reasons:
    #
    # * Helper modules are quite uncommon, typically one per project.
    # * We inline most of the code for performance, so it is specific
    #   per helper module anyway.
    #
    code =
      quote do
        @moduledoc false
        unquote(defs())
        unquote_splicing(helpers)

        @doc """
        See `Combo.URLBuilder.url/3` for more information.
        """
        def url(conn_or_socket_or_endpoint, path \\ "", params \\ %{}) do
          Combo.URLBuilder.url(conn_or_socket_or_endpoint, path, params)
        end

        @doc """
        See `Combo.URLBuilder.path/4` for more information.
        """
        def path(conn_or_socket_or_endpoint, path, params \\ %{}) do
          Combo.URLBuilder.path(conn_or_socket_or_endpoint, unquote(env.module), path, params)
        end

        @doc """
        See `Combo.URLBuilder.static_url/2` for more information.
        """
        def static_url(conn_or_socket_or_endpoint, path) do
          Combo.URLBuilder.static_url(conn_or_socket_or_endpoint, path)
        end

        @doc """
        See `Combo.URLBuilder.static_path/2` for more information.
        """
        def static_path(conn_or_socket_or_endpoint, path) do
          Combo.URLBuilder.static_path(conn_or_socket_or_endpoint, path)
        end

        @doc """
        See `Combo.URLBuilder.static_integrity/2` for more information.
        """
        def static_integrity(conn_or_socket_or_endpoint, path) do
          Combo.URLBuilder.static_integrity(conn_or_socket_or_endpoint, path)
        end

        defp append_params(path, [], _ignored_param_keys) do
          path
        end

        defp append_params(path, params, _ignored_param_keys)
             when is_map(params) and map_size(params) == 0 do
          path
        end

        defp append_params(path, params, ignored_param_keys)
             when is_list(params) or is_map(params) do
          filtered_params =
            for {k, v} <- params,
                k = to_string(k),
                k not in ignored_param_keys,
                do: {k, v}

          case Conn.Query.encode(filtered_params, &Combo.URLParam.to_param/1) do
            "" -> path
            query -> path <> "?" <> query
          end
        end
      end

    name = Module.concat(env.module, Helpers)
    Module.create(name, code, line: env.line, file: env.file)
    name
  end

  def defs do
    quote generated: true, unquote: false do
      def_helper = fn helper, plug_opts, vars, bins, path ->
        def unquote(:"#{helper}_path")(
              conn_or_endpoint,
              unquote(Macro.escape(plug_opts)),
              unquote_splicing(vars)
            ) do
          unquote(:"#{helper}_path")(
            conn_or_endpoint,
            unquote(Macro.escape(plug_opts)),
            unquote_splicing(vars),
            []
          )
        end

        def unquote(:"#{helper}_path")(
              conn_or_endpoint,
              unquote(Macro.escape(plug_opts)),
              unquote_splicing(vars),
              params
            )
            when is_list(params) or is_map(params) do
          path(
            conn_or_endpoint,
            append_params(
              unquote(path),
              params,
              unquote(bins)
            )
          )
        end

        def unquote(:"#{helper}_url")(
              conn_or_endpoint,
              unquote(Macro.escape(plug_opts)),
              unquote_splicing(vars)
            ) do
          unquote(:"#{helper}_url")(
            conn_or_endpoint,
            unquote(Macro.escape(plug_opts)),
            unquote_splicing(vars),
            []
          )
        end

        def unquote(:"#{helper}_url")(
              conn_or_endpoint,
              unquote(Macro.escape(plug_opts)),
              unquote_splicing(vars),
              params
            )
            when is_list(params) or is_map(params) do
          url(conn_or_endpoint, "") <>
            unquote(:"#{helper}_path")(
              conn_or_endpoint,
              unquote(Macro.escape(plug_opts)),
              unquote_splicing(vars),
              params
            )
        end
      end
    end
  end

  @doc """
  Receives a route and returns the quoted definition for its helper function.

  In case a helper name was not given, or route is forwarded, returns nil.
  """
  def def_helper(%Route{} = route, exprs) do
    helper = route.helper
    plug_opts = route.plug_opts

    {bins, vars} = :lists.unzip(exprs.binding)
    path = expand_segments(exprs.path)

    quote do
      def_helper.(
        unquote(helper),
        unquote(Macro.escape(plug_opts)),
        unquote(Macro.escape(vars)),
        unquote(Macro.escape(bins)),
        unquote(Macro.escape(path))
      )
    end
  end

  def expand_segments([]), do: "/"

  def expand_segments(segments) when is_list(segments) do
    segments =
      segments
      |> Enum.map(&expand_segment(&1))
      |> List.flatten()
      |> Enum.intersperse("/")

    segments = ["/" | segments]

    build_concat_chain(segments)
  end

  def expand_segments(segment) do
    expand_segments([segment])
  end

  def expand_segment({:|, _, [h, t]}) do
    [
      expand_segment(h),
      quote do
        Enum.map_join(unquote(t), "/", &unquote(__MODULE__).encode_segment/1)
      end
    ]
  end

  def expand_segment(segment) when is_binary(segment) do
    segment
  end

  def expand_segment({_, _, _} = segment) do
    quote do
      unquote(__MODULE__).encode_segment(unquote(segment))
    end
  end

  defp build_concat_chain([_ | _] = list) do
    # Reverse the list to build a concat chain like:
    #
    #     "a" <> "b" <> "c" <> "d"
    #
    # Or, it will be:
    #
    #     (("a" <> "b") <> "c") <> "d"
    #
    [h | t] = Enum.reverse(list)
    build_concat_chain(t, h)
  end

  defp build_concat_chain([], acc), do: acc

  defp build_concat_chain([h | t], acc) do
    new_acc = quote(do: unquote(h) <> unquote(acc))
    build_concat_chain(t, new_acc)
  end

  @doc false
  def encode_segment(data) do
    data
    |> Combo.URLParam.to_param()
    |> URI.encode(&URI.char_unreserved?/1)
  end
end
