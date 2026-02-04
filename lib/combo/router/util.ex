defmodule Combo.Router.Util do
  @moduledoc false

  def expand_plug_and_opts(plug, opts, caller) do
    runtime? = Combo.plug_init_mode() == :runtime

    plug =
      if runtime? do
        expand_alias(plug, caller)
      else
        plug
      end

    opts =
      if runtime? and Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, caller))
      else
        opts
      end

    {plug, opts}
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:init, 1}})

  defp expand_alias(other, _env), do: other

  ## Validations

  # Validates a route path, which should be a string and have a leading "/".
  def validate_route_path!("/" <> _ = path), do: path

  def validate_route_path!(path) when is_binary(path) do
    IO.warn("router paths should begin with a forward slash, got: #{inspect(path)}")
    "/" <> path
  end

  def validate_route_path!(path) do
    raise ArgumentError, "router paths must be strings, got: #{inspect(path)}"
  end
end
