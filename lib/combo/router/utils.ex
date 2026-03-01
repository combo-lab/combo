defmodule Combo.Router.Utils do
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

  def expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:init, 1}})

  def expand_alias(other, _env), do: other

  def validate_path!("/" <> _ = path), do: path

  def validate_path!(path) when is_binary(path) do
    raise ArgumentError, "route path must begin with a slash, got: #{inspect(path)}"
  end

  def validate_path!(path) do
    raise ArgumentError, "route path must be a string, got: #{inspect(path)}"
  end

  # from https://github.com/elixir-plug/plug/blob/59cf2b552d2130398e27cd192157faf12d1356f5/lib/plug/conn/adapter.ex#L54
  def split_path(path) do
    segments = :binary.split(path, "/", [:global])
    for segment <- segments, segment != "", do: segment
  end
end
