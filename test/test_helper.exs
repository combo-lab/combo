Application.put_env(:phoenix_live_view, :debug_heex_annotations, true)
Code.require_file("support/debug_annotations.exs", __DIR__)
Application.put_env(:phoenix_live_view, :debug_heex_annotations, false)

Code.require_file("support/router_helper.exs", __DIR__)

# Starts web server applications
Application.ensure_all_started(:plug_cowboy)

# Used whenever a router fails. We default to simply
# rendering a short string.
defmodule Phoenix.ErrorView do
  def render("404.json", %{kind: kind, reason: _reason, stack: _stack, conn: conn}) do
    %{error: "Got 404 from #{kind} with #{conn.method}"}
  end

  def render(template, %{conn: conn}) do
    unless conn.private.combo_endpoint do
      raise "no endpoint in error view"
    end

    "#{template} from Phoenix.ErrorView"
  end
end

# For mix tests
Mix.shell(Mix.Shell.Process)

assert_timeout = String.to_integer(System.get_env("ELIXIR_ASSERT_TIMEOUT") || "200")

ExUnit.start(assert_receive_timeout: assert_timeout)
