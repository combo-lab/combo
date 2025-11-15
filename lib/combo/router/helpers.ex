defmodule Combo.Router.Helpers do
  @moduledoc """
  Generates a module for named routes helpers and generic url helpers.

  Named routes helpers exist to avoid hardcoding routes, if you wrote
  `<a href="/login">` and then changed your router, the link would point to a
  page that no longer exist. By using router helpers, we make sure it always
  points to a valid URL in our router.

  Generic url helpers exist for convenience.

  ## Examples

      defmodule MyApp.Web.Router do
        use Combo.Router
        # ...
      end

  It will generated a module named `MyApp.Web.Router.Helpers`, and following
  functions are available:

    * `url/_`
    * `path/_`
    * `static_url/_`
    * `static_path/_`
    * `static_integrity/_`
    * `*_url/_`
    * `*_path/_`

  ## Override endpoint's URL

      - `Combo.Conn.put_router_url/2` is used to override the endpoint's URL
      - `Combo.Conn.put_static_url/2` is used to override the endpoint's static URL

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

    impls =
      for {_helper, helper_routes} <- groups,
          {_, [{route, exprs} | _]} <-
            helper_routes
            |> Enum.group_by(fn {route, exprs} -> [length(exprs.binding) | route.plug_opts] end)
            |> Enum.sort(),
          do: defhelper(route, exprs)

    catch_all = Enum.map(groups, &defhelper_catch_all/1)

    defhelper =
      quote generated: true, unquote: false do
        defhelper = fn helper, vars, opts, bins, segs ->
          def unquote(:"#{helper}_path")(
                conn_or_endpoint,
                unquote(Macro.escape(opts)),
                unquote_splicing(vars)
              ) do
            unquote(:"#{helper}_path")(
              conn_or_endpoint,
              unquote(Macro.escape(opts)),
              unquote_splicing(vars),
              []
            )
          end

          def unquote(:"#{helper}_path")(
                conn_or_endpoint,
                unquote(Macro.escape(opts)),
                unquote_splicing(vars),
                params
              )
              when is_list(params) or is_map(params) do
            path(
              conn_or_endpoint,
              build_path(
                unquote(segs),
                params,
                unquote(bins)
              )
            )
          end

          def unquote(:"#{helper}_url")(
                conn_or_endpoint,
                unquote(Macro.escape(opts)),
                unquote_splicing(vars)
              ) do
            unquote(:"#{helper}_url")(
              conn_or_endpoint,
              unquote(Macro.escape(opts)),
              unquote_splicing(vars),
              []
            )
          end

          def unquote(:"#{helper}_url")(
                conn_or_endpoint,
                unquote(Macro.escape(opts)),
                unquote_splicing(vars),
                params
              )
              when is_list(params) or is_map(params) do
            url(conn_or_endpoint, "") <>
              unquote(:"#{helper}_path")(
                conn_or_endpoint,
                unquote(Macro.escape(opts)),
                unquote_splicing(vars),
                params
              )
          end
        end
      end

    defcatch_all =
      quote generated: true, unquote: false do
        defcatch_all = fn helper, binding_lengths, params_lengths, routes ->
          for length <- binding_lengths do
            binding = List.duplicate({:_, [], nil}, length)
            arity = length + 2

            def unquote(:"#{helper}_path")(conn_or_endpoint, action, unquote_splicing(binding)) do
              path(conn_or_endpoint, "/")
              raise_route_error(unquote(helper), :path, unquote(arity), action, [])
            end

            def unquote(:"#{helper}_url")(conn_or_endpoint, action, unquote_splicing(binding)) do
              url(conn_or_endpoint, "/")
              raise_route_error(unquote(helper), :url, unquote(arity), action, [])
            end
          end

          for length <- params_lengths do
            binding = List.duplicate({:_, [], nil}, length)
            arity = length + 2

            def unquote(:"#{helper}_path")(
                  conn_or_endpoint,
                  action,
                  unquote_splicing(binding),
                  params
                ) do
              path(conn_or_endpoint, "/")
              raise_route_error(unquote(helper), :path, unquote(arity + 1), action, params)
            end

            def unquote(:"#{helper}_url")(
                  conn_or_endpoint,
                  action,
                  unquote_splicing(binding),
                  params
                ) do
              url(conn_or_endpoint, "/")
              raise_route_error(unquote(helper), :url, unquote(arity + 1), action, params)
            end
          end

          defp raise_route_error(unquote(helper), suffix, arity, action, params) do
            Combo.Router.Helpers.raise_route_error(
              __MODULE__,
              "#{unquote(helper)}_#{suffix}",
              arity,
              action,
              unquote(Macro.escape(routes)),
              params
            )
          end
        end
      end

    # It is in general bad practice to generate large chunks of code
    # inside quoted expressions. However, we can get away with this
    # here for two reasons:
    #
    # * Helper modules are quite uncommon, typically one per project.
    #
    # * We inline most of the code for performance, so it is specific
    #   per helper module anyway.
    #
    code =
      quote do
        @moduledoc false
        unquote(defhelper)
        unquote(defcatch_all)
        unquote_splicing(impls)
        unquote_splicing(catch_all)

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

        # Functions used by generated helpers
        # Those are inlined here for performance

        defp to_param(int) when is_integer(int), do: Integer.to_string(int)
        defp to_param(bin) when is_binary(bin), do: bin
        defp to_param(false), do: "false"
        defp to_param(true), do: "true"
        defp to_param(data), do: Combo.URLParam.to_param(data)

        defp build_path(segments, [], _reserved_param_keys) do
          segments
        end

        defp build_path(pathname, params, reserved_param_keys)
             when is_list(params) or is_map(params) do
          filtered_params =
            for {k, v} <- params,
                k = to_string(k),
                k not in reserved_param_keys,
                do: {k, v}

          case Conn.Query.encode(filtered_params, &to_param/1) do
            "" -> pathname
            query -> pathname <> "?" <> query
          end
        end

        defp maybe_append_slash("/", _), do: "/"
        defp maybe_append_slash(path, true), do: path <> "/"
        defp maybe_append_slash(path, _), do: path
      end

    name = Module.concat(env.module, Helpers)
    Module.create(name, code, line: env.line, file: env.file)
    name
  end

  @doc """
  Receives a route and returns the quoted definition for its helper function.

  In case a helper name was not given, or route is forwarded, returns nil.
  """
  def defhelper(%Route{} = route, exprs) do
    helper = route.helper
    opts = route.plug_opts

    {bins, vars} = :lists.unzip(exprs.binding)
    segs = expand_segments(exprs.path)

    quote do
      defhelper.(
        unquote(helper),
        unquote(Macro.escape(vars)),
        unquote(Macro.escape(opts)),
        unquote(Macro.escape(bins)),
        unquote(Macro.escape(segs))
      )
    end
  end

  def defhelper_catch_all({helper, routes_and_exprs}) do
    routes =
      routes_and_exprs
      |> Enum.map(fn {routes, exprs} ->
        {routes.plug_opts, Enum.map(exprs.binding, &elem(&1, 0))}
      end)
      |> Enum.sort()

    params_lengths =
      routes
      |> Enum.map(fn {_, bindings} -> length(bindings) end)
      |> Enum.uniq()

    # Each helper defines catch all like this:
    #
    #     def helper_path(context, action, ...binding)
    #     def helper_path(context, action, ...binding, params)
    #
    # Given the helpers are ordered by binding length, the additional
    # helper with param for a helper_path/n will always override the
    # binding for helper_path/n+1, so we skip those here to avoid warnings.
    binding_lengths = Enum.reject(params_lengths, &((&1 - 1) in params_lengths))

    quote do
      defcatch_all.(
        unquote(helper),
        unquote(binding_lengths),
        unquote(params_lengths),
        unquote(Macro.escape(routes))
      )
    end
  end

  @doc """
  Callback for generate router catch all.
  """
  def raise_route_error(mod, fun, arity, action, routes, params) do
    cond do
      is_atom(action) and not Keyword.has_key?(routes, action) ->
        "no action #{inspect(action)} for #{inspect(mod)}.#{fun}/#{arity}"
        |> invalid_route_error(fun, routes)

      is_list(params) or is_map(params) ->
        "no function clause for #{inspect(mod)}.#{fun}/#{arity} and action #{inspect(action)}"
        |> invalid_route_error(fun, routes)

      true ->
        invalid_param_error(mod, fun, arity, action, routes)
    end
  end

  defp invalid_route_error(prelude, fun, routes) do
    suggestions =
      for {action, bindings} <- routes do
        bindings = Enum.join([inspect(action) | bindings], ", ")
        "\n    #{fun}(conn_or_endpoint, #{bindings}, params \\\\ [])"
      end

    raise ArgumentError,
          "#{prelude}. The following actions/clauses are supported:\n#{suggestions}"
  end

  defp invalid_param_error(mod, fun, arity, action, routes) do
    call_vars = Keyword.fetch!(routes, action)

    raise ArgumentError, """
    #{inspect(mod)}.#{fun}/#{arity} called with invalid params.
    The last argument to this function should be a keyword list or a map.
    For example:

        #{fun}(#{Enum.join(["conn", ":#{action}" | call_vars], ", ")}, page: 5, per_page: 10)

    It is possible you have called this function without defining the proper
    number of path segments in your router.
    """
  end

  # TODO: replace it
  @doc """
  Callback for properly encoding parameters in routes.
  """
  def encode_param(str), do: URI.encode(str, &URI.char_unreserved?/1)

  # HERE
  defp encode_segment(data) do
    data
    |> Combo.URLParam.to_param()
    |> URI.encode(&URI.char_unreserved?/1)
  end

  defp expand_segments([]), do: "/"

  defp expand_segments(segments) when is_list(segments) do
    expand_segments(segments, "")
  end

  defp expand_segments(segments) do
    quote do
      "/" <> Enum.map_join(unquote(segments), "/", &unquote(__MODULE__).encode_param/1)
    end
  end

  defp expand_segments([{:|, _, [h, t]}], acc) do
    quote do
      unquote(expand_segments([h], acc)) <>
        "/" <> Enum.map_join(unquote(t), "/", &unquote(__MODULE__).encode_param/1)
    end
  end

  defp expand_segments([h | t], acc) when is_binary(h) do
    expand_segments(t, quote(do: unquote(acc) <> unquote("/" <> h)))
  end

  defp expand_segments([h | t], acc) do
    expand_segments(
      t,
      quote(do: unquote(acc) <> "/" <> unquote(__MODULE__).encode_param(to_param(unquote(h))))
    )
  end

  defp expand_segments([], acc) do
    acc
  end
end

# @doc false
# def __encode_segment__(data) do
#   case data do
#     [] -> ""
#     [str | _] when is_binary(str) -> Enum.map_join(data, "/", &encode_segment/1)
#     _ -> encode_segment(data)
#   end
# end
