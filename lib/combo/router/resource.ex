defmodule Combo.Router.Resource do
  @moduledoc false

  @default_param_key "id"
  @actions [:index, :new, :create, :show, :edit, :update, :delete]

  @doc """
  The `Combo.Router.Resource` struct. It stores:

    * `:singleton` - if the resource is a singleton resource.
    * `:path` - the path as string (not normalized).
    * `:param` - the param to be used in routes (not normalized).
    * `:controller` - the controller as an atom.
    * `:actions` - the list of actions as atoms.
    * `:route` - the context for resource routes.
    * `:member` - the context for member routes.
    * `:collection` - the context for collection routes.

  """
  defstruct [:singleton, :path, :param, :controller, :actions, :route, :collection, :member]
  @type t :: %__MODULE__{}

  @doc """
  Builds a resource struct.
  """
  def build(path, controller, opts) when is_atom(controller) and is_list(opts) do
    singleton = Keyword.get(opts, :singleton, false)
    path = Combo.Router.Scope.validate_path!(path)
    param = Keyword.get(opts, :param, @default_param_key)
    actions = build_actions(opts, singleton)

    name = Keyword.get(opts, :name, Combo.Naming.resource_name(controller, "Controller"))
    alias = Keyword.get(opts, :alias)
    as = Keyword.get(opts, :as, name)
    private = Keyword.get(opts, :private, %{})
    assigns = Keyword.get(opts, :assigns, %{})
    route = [as: as, private: private, assigns: assigns]
    collection = [path: path, as: as, private: private, assigns: assigns]
    member_path = if singleton, do: path, else: Path.join(path, ":#{name}_#{param}")
    member = [path: member_path, as: as, alias: alias, private: private, assigns: assigns]

    %__MODULE__{
      singleton: singleton,
      path: path,
      param: param,
      controller: controller,
      actions: actions,
      route: route,
      collection: collection,
      member: member
    }
  end

  defp build_actions(opts, singleton) do
    only = Keyword.get(opts, :only)
    except = Keyword.get(opts, :except)

    cond do
      only ->
        supported_actions = validate_actions(:only, singleton, only)
        supported_actions -- (supported_actions -- only)

      except ->
        supported_actions = validate_actions(:except, singleton, except)
        supported_actions -- except

      true ->
        default_actions(singleton)
    end
  end

  defp validate_actions(type, singleton, actions) do
    supported_actions = default_actions(singleton)

    if actions -- supported_actions != [] do
      raise ArgumentError, """
      invalid #{inspect(type)} action(s) passed to resources.

      supported#{if singleton, do: " singleton", else: ""} actions: #{inspect(supported_actions)}

      got: #{inspect(actions)}
      """
    end

    supported_actions
  end

  defp default_actions(true = _singleton), do: @actions -- [:index]
  defp default_actions(false = _singleton), do: @actions
end
