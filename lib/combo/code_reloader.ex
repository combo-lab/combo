defmodule Combo.CodeReloader do
  @moduledoc """
  A plug and module to handle automatic code reloading.

  To avoid race conditions, all code reloads are funneled through a
  sequential call operation.
  """

  ## Server delegation

  @doc """
  Reloads code for the current Mix project by invoking the
  `:reloadable_compilers` on the list of `:reloadable_apps`.

  This is configured in your application environment like:

      config :demo, Demo.Web.Endpoint,
        reloadable_apps: [:ui, :backend],
        reloadable_compilers: [:gettext, :elixir]

  The `:reloadable_apps` defaults to `nil`. In such case, default behaviour is
  to reload the current project if it consists of a single app, or all
  applications within an umbrella project. You can set `:reloadable_apps` to a
  subset of default applications to reload only some of them, an empty list to
  effectively disable the code reloader, or include external applications from
  library dependencies.

  The `:reloadable_compilers` must be a subset of the `:compilers` specified in
  `project/0` in your `mix.exs`.

  This function is a no-op and returns `:ok` if Mix is not available.

  The reloader should also be configured as a Mix listener in your `mix.exs`
  since Elixir v1.18:

      def project do
        [
          ...,
          listeners: [Combo.CodeReloader]
        ]
      end

  This way the reloader can notice whenever your project is compiled
  concurrently.

  ## Options

    * `:reloadable_args` - additional CLI args to pass to the compiler tasks.
      Defaults to `["--no-all-warnings"]` so only warnings related to the
      files being compiled are printed

  """
  @spec reload(module, keyword) :: :ok | {:error, binary()}
  def reload(endpoint, opts \\ []) do
    if Code.ensure_loaded?(Mix.Project), do: reload!(endpoint, opts), else: :ok
  end

  @doc """
  Same as `reload/1` but it will raise if Mix is not available.
  """
  @spec reload!(module, keyword) :: :ok | {:error, binary()}
  defdelegate reload!(endpoint, opts), to: Combo.CodeReloader.Server

  @doc """
  Synchronizes with the code server if it is alive.

  It returns `:ok`. If it is not running, it also returns `:ok`.
  """
  @spec sync :: :ok
  defdelegate sync, to: Combo.CodeReloader.Server

  @doc false
  @spec child_spec(keyword) :: Supervisor.child_spec()
  defdelegate child_spec(opts), to: Combo.CodeReloader.MixListener

  ## Plug

  @behaviour Plug
  import Combo.Conn, only: [endpoint_module!: 1]
  import Plug.Conn
  alias Combo.SafeHTML

  @style %{
    light: %{
      primary: "#D00000",
      accent: "#A0B0C0",
      text_color: "#304050",
      background: "#FFFFFF",
      heading_background: "#F9F9FA"
    },
    dark: %{
      primary: "#FF5F59",
      accent: "#C0C0C0",
      text_color: "#E5E5E5",
      background: "#1A1A1A",
      heading_background: "#2A2A2A"
    },
    monospace_font: "menlo, consolas, monospace"
  }

  @doc """
  API used by Plug to start the code reloader.
  """
  def init(opts) do
    Keyword.put_new(opts, :reloader, &Combo.CodeReloader.reload/2)
  end

  @doc """
  API used by Plug to invoke the code reloader on every request.
  """
  def call(conn, opts) do
    endpoint = endpoint_module!(conn)

    case opts[:reloader].(endpoint, opts) do
      :ok ->
        conn

      {:error, output} ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(500, template(output))
        |> halt()
    end
  end

  defp template(output) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>CompileError</title>
        <meta name="viewport" content="width=device-width">
        <style>/*! normalize.css v4.2.0 | MIT License | github.com/necolas/normalize.css */html{font-family:sans-serif;line-height:1.15;-ms-text-size-adjust:100%;-webkit-text-size-adjust:100%}body{margin:0}article,aside,details,figcaption,figure,footer,header,main,menu,nav,section,summary{display:block}audio,canvas,progress,video{display:inline-block}audio:not([controls]){display:none;height:0}progress{vertical-align:baseline}template,[hidden]{display:none}a{background-color:transparent;-webkit-text-decoration-skip:objects}a:active,a:hover{outline-width:0}abbr[title]{border-bottom:none;text-decoration:underline;text-decoration:underline dotted}b,strong{font-weight:inherit}b,strong{font-weight:bolder}dfn{font-style:italic}h1{font-size:2em;margin:0.67em 0}mark{background-color:#ff0;color:#000}small{font-size:80%}sub,sup{font-size:75%;line-height:0;position:relative;vertical-align:baseline}sub{bottom:-0.25em}sup{top:-0.5em}img{border-style:none}svg:not(:root){overflow:hidden}code,kbd,pre,samp{font-family:monospace, monospace;font-size:1em}figure{margin:1em 40px}hr{box-sizing:content-box;height:0;overflow:visible}button,input,optgroup,select,textarea{font:inherit;margin:0}optgroup{font-weight:bold}button,input{overflow:visible}button,select{text-transform:none}button,html [type="button"],[type="reset"],[type="submit"]{-webkit-appearance:button}button::-moz-focus-inner,[type="button"]::-moz-focus-inner,[type="reset"]::-moz-focus-inner,[type="submit"]::-moz-focus-inner{border-style:none;padding:0}button:-moz-focusring,[type="button"]:-moz-focusring,[type="reset"]:-moz-focusring,[type="submit"]:-moz-focusring{outline:1px dotted ButtonText}fieldset{border:1px solid #c0c0c0;margin:0 2px;padding:0.35em 0.625em 0.75em}legend{box-sizing:border-box;color:inherit;display:table;max-width:100%;padding:0;white-space:normal}textarea{overflow:auto}[type="checkbox"],[type="radio"]{box-sizing:border-box;padding:0}[type="number"]::-webkit-inner-spin-button,[type="number"]::-webkit-outer-spin-button{height:auto}[type="search"]{-webkit-appearance:textfield;outline-offset:-2px}[type="search"]::-webkit-search-cancel-button,[type="search"]::-webkit-search-decoration{-webkit-appearance:none}::-webkit-input-placeholder{color:inherit;opacity:0.54}::-webkit-file-upload-button{-webkit-appearance:button;font:inherit}</style>
        <style>
        html, body, td, input {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Roboto", "Oxygen", "Ubuntu", "Cantarell", "Fira Sans", "Droid Sans", "Helvetica Neue", sans-serif;
        }

        * {
            box-sizing: border-box;
        }

        html {
            font-size: 15px;
            line-height: 1.6;
            background: #{@style.light.background};
            color: #{@style.light.text_color};
        }

        @media (prefers-color-scheme: dark) {
            html {
                background: #{@style.dark.background};
                color: #{@style.dark.text_color};
            }
        }

        @media (max-width: 768px) {
            html {
                 font-size: 14px;
            }
        }

        @media (max-width: 480px) {
            html {
                 font-size: 13px;
            }
        }

        button:focus,
        summary:focus {
            outline: 0;
        }

        summary {
            cursor: pointer;
        }

        pre {
            font-family: #{@style.monospace_font};
            max-width: 100%;
        }

        .heading-block {
            background: #{@style.light.heading_background};
        }

        @media (prefers-color-scheme: dark) {
            .heading-block {
                background: #{@style.dark.heading_background};
            }
        }

        .heading-block,
        .output-block {
            padding: 48px;
        }

        @media (max-width: 768px) {
            .heading-block,
            .output-block {
                padding: 32px;
            }
        }

        @media (max-width: 480px) {
            .heading-block,
            .output-block {
                padding: 16px;
            }
        }

        /*
         * Exception info
         */

        .exception-info > .error,
        .exception-info > .subtext {
            margin: 0;
            padding: 0;
        }

        .exception-info > .error {
            font-size: 1em;
            font-weight: 700;
            color: #{@style.light.primary};
        }

        @media (prefers-color-scheme: dark) {
            .exception-info > .error {
                color: #{@style.dark.primary};
            }
        }

        .exception-info > .subtext {
            font-size: 1em;
            font-weight: 400;
            color: #{@style.light.accent};
        }

        @media (prefers-color-scheme: dark) {
            .exception-info > .subtext {
                color: #{@style.dark.accent};
            }
        }

        @media (max-width: 768px) {
            .exception-info > .title {
                font-size: #{:math.pow(1.15, 4)}em;
            }
        }

        @media (max-width: 480px) {
            .exception-info > .title {
                font-size: #{:math.pow(1.1, 4)}em;
            }
        }

        .code-block {
            margin: 0;
            font-size: .85em;
            line-height: 1.6;
            white-space: pre-wrap;
        }
        </style>
    </head>
    <body>
        <div class="heading-block">
            <header class="exception-info">
                <h5 class="error">Compilation error</h5>
                <h5 class="subtext">Console output is shown below.</h5>
            </header>
        </div>
        <div class="output-block">
            <pre class="code code-block">#{format_output(output)}</pre>
        </div>
    </body>
    </html>
    """
  end

  defp format_output(output) do
    output
    |> String.trim()
    |> remove_ansi_escapes()
    |> SafeHTML.escape()
  end

  defp remove_ansi_escapes(text) do
    Regex.replace(~r/\e\[[0-9;]*[a-zA-Z]/, text, "")
  end
end
