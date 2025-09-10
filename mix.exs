defmodule Combo.MixProject do
  use Mix.Project

  @version "0.2.1"
  @elixir_requirement "~> 1.18"
  @scm_url "https://github.com/combo-team/combo"

  def project do
    [
      app: :combo,
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
      name: "Combo",
      docs: docs(),
      aliases: aliases(),
      source_url: @scm_url,
      description: "Combines the good parts of modern web development.",
      test_ignore_filters: [
        &String.starts_with?(&1, "test/fixtures/"),
        &String.starts_with?(&1, "test/support/")
      ],
      dialyzer: [
        plt_add_apps: [:mix, :iex, :ex_unit]
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [
        docs: :docs,
        publish: :publish
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp extra_applications(:test), do: [:inets]
  defp extra_applications(_), do: []

  def application do
    [
      mod: {Combo, []},
      extra_applications: extra_applications(Mix.env()) ++ [:logger, :eex, :crypto, :public_key]
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.14"},
      {:plug_crypto, "~> 1.2 or ~> 2.0"},
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:phoenix_pubsub, "~> 2.1"},
      {:websock_adapter, "~> 0.5.3"},
      {:file_system, "~> 1.0"},
      {:lazy_html, "~> 0.1.0"},

      # Optional deps
      {:plug_cowboy, "~> 2.7", optional: true},
      {:bandit, "~> 1.0", optional: true},
      {:jason, "~> 1.0", optional: true},

      # Docs dependencies (some for cross references)
      {:ex_doc, "~> 0.38", only: [:docs, :publish]},
      {:ecto, "~> 3.0", only: [:docs, :publish]},
      {:ecto_sql, "~> 3.10", only: [:docs, :publish]},
      {:gettext, "~> 0.26", only: [:docs, :publish]},
      {:telemetry_poller, "~> 1.0", only: [:docs, :publish]},
      {:telemetry_metrics, "~> 1.0", only: [:docs, :publish]},
      {:makeup_elixir, "~> 1.0.1", only: [:docs, :publish]},
      {:makeup_ceex, "~> 0.1.0", only: [:docs, :publish]},
      {:makeup_syntect, "~> 0.1.0", only: [:docs, :publish]},

      # code quality
      {:ex_check, "~> 0.16.0", only: [:dev], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev], runtime: false},

      # Test dependencies
      {:mint, "~> 1.4", only: :test},
      {:mint_web_socket, "~> 1.0.0", only: :test},
      {:decimal, "~> 2.0", optional: true}
    ]
  end

  defp package do
    [
      maintainers: ["Chris McCord", "José Valim", "Gary Rennie", "Jason Stiebs"],
      licenses: ["MIT"],
      links: %{"GitHub" => @scm_url},
      files: ~w(
          lib mix.exs
          priv package.json
          .formatter.exs
          README.md
          CHANGELOG.md
          LICENSE.txt
        )
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "overview",
      extra_section: "GUIDES",
      assets: %{"guides/assets" => "assets"},
      formatters: ["html"],
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
      # "guides/introduction/overview.md",
      # "guides/introduction/installation.md",
      # "guides/introduction/up_and_running.md",
      # "guides/introduction/packages_glossary.md",
      # "guides/directory_structure.md",
      # "guides/request_lifecycle.md",
      # "guides/plug.md",
      # "guides/routing.md",
      # "guides/controllers.md",
      # "guides/components.md",
      # "guides/ecto.md",
      # "guides/json_and_apis.md",
      # "guides/live_view.md",
      # "guides/asset_management.md",
      # "guides/telemetry.md",
      # "guides/security.md",
      # "guides/authn_authz/authn_authz.md",
      # "guides/authn_authz/mix_phx_gen_auth.md",
      # "guides/authn_authz/scopes.md",
      # "guides/authn_authz/api_authentication.md",
      # "guides/data_modelling/contexts.md",
      # "guides/data_modelling/your_first_context.md",
      # "guides/data_modelling/in_context_relationships.md",
      # "guides/data_modelling/cross_context_boundaries.md",
      # "guides/data_modelling/more_examples.md",
      # "guides/data_modelling/faq.md",
      # "guides/real_time/channels.md",
      # "guides/real_time/presence.md",
      # "guides/testing/testing.md",
      # "guides/testing/testing_contexts.md",
      # "guides/testing/testing_controllers.md",
      # "guides/testing/testing_channels.md",
      # "guides/deployment/deployment.md",
      # "guides/deployment/releases.md",
      # "guides/deployment/fly.md",
      # "guides/deployment/gigalixir.md",
      # "guides/deployment/heroku.md",
      # "guides/howto/custom_error_pages.md",
      # "guides/howto/file_uploads.md",
      # "guides/howto/swapping_databases.md",
      # "guides/howto/using_ssl.md",
      # "guides/howto/writing_a_channels_client.md",
      # "guides/cheatsheets/router.cheatmd",
      "CHANGELOG.md",
      "JS Documentation": [url: "js/index.html"]
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
    # Combo
    # Combo.Channel
    # Combo.Controller
    # Combo.Endpoint
    # Combo.Naming
    # Combo.Logger
    # Combo.Param
    # Combo.Presence
    # Combo.Router
    # Combo.Socket
    # Combo.Token
    # Combo.VerifiedRoutes

    [
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
        Combo.Template.HTMLEncoder
      ],
      HTML: [
        Combo.HTML,
        Combo.HTML.Formatter,
        Combo.HTML.Form,
        Combo.HTML.FormData,
        Combo.HTML.FormField
      ],
      "Safe HTML": [
        Combo.SafeHTML,
        Combo.SafeHTML.Safe
      ],
      Testing: [
        Combo.ChannelTest,
        Combo.ConnTest
      ],
      "Adapters and Plugs": [
        Combo.CodeReloader,
        Combo.Endpoint.Cowboy2Adapter,
        Combo.Endpoint.SyncCodeReloadPlug
      ],
      Digester: [
        Combo.Digester.Compressor,
        Combo.Digester.Gzip
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
      setup: ["deps.get", "assets.deps.get"],
      docs: ["docs", "assets.docs"],

      # bridges for npm scripts
      "assets.deps.get": "cmd npm install --prefix assets",
      "assets.watch": "cmd npm run watch --prefix assets",
      "assets.build": "cmd npm run build --prefix assets",
      "assets.docs": "cmd npm run docs --prefix assets",

      # publish
      publish: ["hex.publish", "tag"],
      tag: &tag_release/1
    ]
  end

  defp tag_release(_) do
    Mix.shell().info("Tagging release as v#{@version}")
    System.cmd("git", ["tag", "v#{@version}"])
    System.cmd("git", ["push", "--tags"])
  end
end
