defmodule Combo do
  @moduledoc """
  Combines the good parts of modern web development.
  """

  use Application

  @doc false
  def start(_type, _args) do
    warn_on_missing_json_module()

    # Warm up caches
    _ = Combo.Template.engines()
    _ = Combo.Template.format_encoders()

    # Configure proper system flags
    if stacktrace_depth = Application.get_env(:combo, :stacktrace_depth, nil) do
      :erlang.system_flag(:backtrace_depth, stacktrace_depth)
    end

    if Application.get_env(:combo, :logger, true) do
      Combo.Logger.install()
    end

    children = [
      # Code reloading must be serial across all Combo apps
      Combo.CodeReloader.Server,
      {DynamicSupervisor, name: Combo.Transports.LongPoll.Supervisor, strategy: :one_for_one}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Combo.Supervisor)
  end

  defp warn_on_missing_json_module do
    module = json_module()

    if module && not Code.ensure_loaded?(module) do
      IO.warn("""
      found #{inspect(module)} in your application configuration
      for Combo JSON encoding, but module #{inspect(module)} is not available.
      Ensure #{inspect(module)} is listed as a dependency in mix.exs.
      """)
    end
  end

  @doc """
  Returns the value of `:json_module` option, which specifies the module
  for JSON encoding.

  To customize the JSON module, including the following in your
  `config/config.exs`:

      config :combo, :json_module, JSON

  """
  def json_module do
    Application.get_env(:combo, :json_module, Jason)
  end

  @doc """
  Returns the value of `:plug_init_mode` option that controls when plugs are
  initialized.

  It's recommended to set it to `:runtime` in development for compilation time
  improvements. It must be `:compile` in production (the default).

  This option is passed as the `:init_mode` to `Plug.Builder.compile/3`.
  """
  def plug_init_mode do
    Application.get_env(:combo, :plug_init_mode, :compile)
  end
end
