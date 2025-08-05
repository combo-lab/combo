defmodule Phoenix.MixProject do
  use Mix.Project

  @version "1.8.0-rc.3"
  @scm_url "https://github.com/phoenixframework/phoenix"

  # If the elixir requirement is updated, we need to make the installer
  # use at least the minimum requirement used here. Although often the
  # installer is ahead of Phoenix itself.
  @elixir_requirement "~> 1.15"

  def project do
    [
      app: :phoenix,
      version: @version,
      elixir: @elixir_requirement,
      deps: deps(),
      package: package(),
      consolidate_protocols: Mix.env() != :test,
      xref: [
        exclude: [
          {IEx, :started?, 0},
          Ecto.Type,
          :ranch,
          :cowboy_req,
          Plug.Cowboy.Conn,
          Plug.Cowboy,
          :httpc,
          :public_key
        ]
      ],
      elixirc_paths: elixirc_paths(Mix.env()),
      name: "Phoenix",
      docs: docs(),
      aliases: aliases(),
      source_url: @scm_url,
      homepage_url: "https://www.phoenixframework.org",
      description: "Peace of mind from prototype to production",
      test_ignore_filters: [
        &String.starts_with?(&1, "test/fixtures/"),
        &String.starts_with?(&1, "test/support/")
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [docs: :docs]
    ]
  end

  defp elixirc_paths(:docs), do: ["lib", "installer/lib"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp extra_applications(:test), do: [:inets]
  defp extra_applications(_), do: []

  def application do
    [
      mod: {Phoenix, []},
      extra_applications: extra_applications(Mix.env()) ++ [:logger, :eex, :crypto, :public_key],
      env: [
        logger: true,
        stacktrace_depth: nil,
        filter_parameters: ["password"],
        serve_endpoints: false,
        gzippable_exts: ~w(.js .map .css .txt .text .html .json .svg .eot .ttf),
        static_compressors: [Phoenix.Digester.Gzip]
      ]
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.14"},
      {:plug_crypto, "~> 1.2 or ~> 2.0"},
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:phoenix_pubsub, "~> 2.1"},
      {:websock_adapter, "~> 0.5.3"},

      # Optional deps
      {:plug_cowboy, "~> 2.7", optional: true},
      {:bandit, "~> 1.0", optional: true},
      {:jason, "~> 1.0", optional: true},
      {:lazy_html, "~> 0.1.0", optional: true},

      # Docs dependencies (some for cross references)
      {:ex_doc, "~> 0.38", only: :docs},
      {:ecto, "~> 3.0", only: :docs},
      {:ecto_sql, "~> 3.10", only: :docs},
      {:gettext, "~> 0.26", only: :docs},
      {:telemetry_poller, "~> 1.0", only: :docs},
      {:telemetry_metrics, "~> 1.0", only: :docs},
      {:makeup_elixir, "~> 1.0.1", only: :docs},
      {:makeup_ceex, "~> 0.1.0", only: :docs},
      {:makeup_syntect, "~> 0.1.0", only: :docs},

      # Test dependencies
      {:mint, "~> 1.4", only: :test},
      {:mint_web_socket, "~> 1.0.0", only: :test},

      # Dev dependencies
      {:esbuild, "~> 0.8", only: :dev}
    ]
  end

  defp package do
    [
      maintainers: ["Chris McCord", "José Valim", "Gary Rennie", "Jason Stiebs"],
      licenses: ["MIT"],
      links: %{"GitHub" => @scm_url},
      files: ~w(
          assets/js lib priv CHANGELOG.md LICENSE.md mix.exs package.json README.md .formatter.exs
        )
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "overview",
      extra_section: "GUIDES",
      assets: %{"guides/assets" => "assets"},
      formatters: ["html", "epub"],
      groups_for_modules: groups_for_modules(),
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      groups_for_docs: [
        Reflection: &(&1[:type] == :reflection)
      ],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp extras do
    [
      "guides/introduction/overview.md",
      "guides/introduction/installation.md",
      "guides/introduction/up_and_running.md",
      "guides/introduction/packages_glossary.md",
      "guides/directory_structure.md",
      "guides/request_lifecycle.md",
      "guides/plug.md",
      "guides/routing.md",
      "guides/controllers.md",
      "guides/components.md",
      "guides/ecto.md",
      "guides/json_and_apis.md",
      "guides/live_view.md",
      "guides/asset_management.md",
      "guides/telemetry.md",
      "guides/security.md",
      "guides/authn_authz/authn_authz.md",
      "guides/authn_authz/mix_phx_gen_auth.md",
      "guides/authn_authz/scopes.md",
      "guides/authn_authz/api_authentication.md",
      "guides/data_modelling/contexts.md",
      "guides/data_modelling/your_first_context.md",
      "guides/data_modelling/in_context_relationships.md",
      "guides/data_modelling/cross_context_boundaries.md",
      "guides/data_modelling/more_examples.md",
      "guides/data_modelling/faq.md",
      "guides/real_time/channels.md",
      "guides/real_time/presence.md",
      "guides/testing/testing.md",
      "guides/testing/testing_contexts.md",
      "guides/testing/testing_controllers.md",
      "guides/testing/testing_channels.md",
      "guides/deployment/deployment.md",
      "guides/deployment/releases.md",
      "guides/deployment/fly.md",
      "guides/deployment/gigalixir.md",
      "guides/deployment/heroku.md",
      "guides/howto/custom_error_pages.md",
      "guides/howto/file_uploads.md",
      "guides/howto/swapping_databases.md",
      "guides/howto/using_ssl.md",
      "guides/howto/writing_a_channels_client.md",
      "guides/cheatsheets/router.cheatmd",
      "CHANGELOG.md",
      "JS Documentation": [url: "/js/"]
    ]
  end

  defp groups_for_extras do
    [
      Introduction: ~r/guides\/introduction\/.?/,
      "Core Concepts": ~r/guides\/[^\/]+\.md/,
      "Data Modelling": ~r/guides\/data_modelling\/.?/,
      "Authn and Authz": ~r/guides\/authn_authz\/.?/,
      "Real-time": ~r/guides\/real_time\/.?/,
      Testing: ~r/guides\/testing\/.?/,
      Deployment: ~r/guides\/deployment\/.?/,
      Cheatsheets: ~r/guides\/cheatsheets\/.?/,
      "How-to's": ~r/guides\/howto\/.?/
    ]
  end

  defp groups_for_modules do
    # Ungrouped Modules:
    #
    # Phoenix
    # Combo.Channel
    # Phoenix.Controller
    # Phoenix.Endpoint
    # Phoenix.Naming
    # Phoenix.Logger
    # Combo.Param
    # Combo.Presence
    # Combo.Router
    # Combo.Socket
    # Combo.Token
    # Combo.VerifiedRoutes

    [
      "Safe HTML": [
        Combo.SafeHTML,
        Combo.SafeHTML.Safe
      ],
      Template: [
        Combo.Template,
        Combo.Template.Engine,
        Combo.Template.FormatEncoder,
        Combo.Template.ExsEngine,
        Combo.Template.EExEngine,
        Combo.Template.CEExEngine,
        Combo.Template.CEExEngine.Compiler,
        Combo.Template.CEExEngine.Sigil,
        Combo.Template.CEExEngine.Assigns,
        Combo.Template.CEExEngine.DeclarativeAssigns,
        Combo.Template.CEExEngine.Slot,
        Combo.Template.CEExEngine.Formatter,
        Combo.Template.HTMLEncoder
      ],
      HTML: [
        Combo.HTML,
        Combo.HTML.Form,
        Combo.HTML.FormData,
        Combo.HTML.FormField
      ],
      Testing: [
        Combo.ChannelTest,
        Combo.ConnTest
      ],
      "Adapters and Plugs": [
        Phoenix.CodeReloader,
        Phoenix.Endpoint.Cowboy2Adapter,
        Phoenix.Endpoint.SyncCodeReloadPlug
      ],
      Digester: [
        Phoenix.Digester.Compressor,
        Phoenix.Digester.Gzip
      ],
      Socket: [
        Combo.Socket.Broadcast,
        Combo.Socket.Message,
        Combo.Socket.Reply,
        Combo.Socket.Serializer,
        Combo.Socket.Transport
      ]
    ]
  end

  defp aliases do
    [
      docs: ["docs", &generate_js_docs/1],
      "assets.build": ["esbuild module", "esbuild cdn", "esbuild cdn_min", "esbuild main"],
      "assets.watch": "esbuild module --watch"
    ]
  end

  defp generate_js_docs(_) do
    Mix.Task.run("app.start")
    System.cmd("npm", ["run", "docs"])
  end
end
