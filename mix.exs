defmodule Combo.MixProject do
  use Mix.Project

  @version "0.7.0"
  @description "A web framework, that combines the good parts of modern web development."
  @elixir_requirement "~> 1.18"
  @source_url "https://github.com/combo-lab/combo"
  @changelog_url "https://github.com/combo-lab/combo/blob/v#{@version}/CHANGELOG.md"

  def project do
    [
      app: :combo,
      version: @version,
      elixir: @elixir_requirement,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
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
      description: @description,
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      package: package(),
      aliases: aliases(),
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

  def application do
    [
      mod: {Combo, []},
      extra_applications: extra_applications(Mix.env()) ++ [:logger, :eex, :crypto]
    ]
  end

  defp extra_applications(:test), do: [:inets]
  defp extra_applications(_), do: []

  defp deps do
    [
      {:plug, "~> 1.14"},
      {:plug_crypto, "~> 1.2 or ~> 2.0"},
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:combo_pubsub, "~> 0.1"},
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
      licenses: ["MIT"],
      links: %{
        Source: @source_url,
        Changelog: @changelog_url
      },
      files: ~w(
        lib/ priv/ mix.exs .formatter.exs README.md CHANGELOG.md LICENSE

        node-packages/combo/package.json
        node-packages/combo/dist/
      )
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"],
      groups_for_modules: groups_for_modules(),
      extras: extras(),
      groups_for_docs: [
        Reflection: &(&1[:type] == :reflection)
      ],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp extras do
    [
      "README.md",
      "LICENSE",
      "CHANGELOG.md",
      "CONTRIBUTING.md",
      "CODE_OF_CONDUCT.md",
      "JS Documentation": [url: "js/index.html"]
    ]
  end

  defp groups_for_modules do
    # Ungrouped Modules:
    #
    # Combo
    # Combo.Naming
    # Combo.Token
    #

    [
      Connection: [
        Combo.Conn,
        Combo.Flash
      ],
      Endpoint: [
        Combo.Endpoint,
        Combo.Endpoint.BanditAdapter,
        Combo.Endpoint.Cowboy2Adapter,
        Combo.Endpoint.SyncCodeReloadPlug
      ],
      Router: [
        Combo.Router,
        Combo.VerifiedRoutes,
        Combo.URLParam
      ],
      Controller: [
        Combo.Controller
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
      Static: [
        Combo.Static,
        Combo.Static.Compressor,
        Combo.Static.Compressor.Gzip
      ],
      Socket: [
        Combo.Socket,
        Combo.Socket.Broadcast,
        Combo.Socket.Message,
        Combo.Socket.Reply,
        Combo.Socket.Serializer,
        Combo.Socket.Transport
      ],
      Channel: [
        Combo.Channel,
        Combo.Presence
      ],
      Logging: [
        Combo.Logger,
        Combo.FilteredParams
      ],
      "Extra Utils": [
        Combo.Naming,
        Combo.Token,
        Combo.Proxy
      ],
      Development: [
        Combo.LiveReloader,
        Combo.LiveReloader.Socket,
        Combo.CodeReloader
      ],
      Debugging: [
        Combo.Debug
      ],
      Testing: [
        Combo.ConnTest,
        Combo.ChannelTest,
        Combo.HTMLTest
      ]
    ]
  end

  defp aliases do
    [
      setup: [
        "deps.get",
        "node-packages.deps.get",
        "assets.deps.get"
      ],
      build: ["node-packages.sync-lock-file", "node-packages.build", "assets.build", "compile"],
      docs: ["docs", "node-packages.docs"],
      publish: ["hex.publish", "tag"],
      tag: &tag_release/1,
      "node-packages.deps.get": "cmd --cd node-packages/combo pnpm install",
      "node-packages.sync-lock-file": "cmd --cd node-packages/combo pnpm install",
      "node-packages.build": "cmd --cd node-packages/combo pnpm run build",
      "node-packages.docs": "cmd --cd node-packages/combo pnpm run docs",
      "assets.deps.get": "cmd --cd assets pnpm install",
      "assets.build": "cmd --cd assets pnpm run build"
    ]
  end

  defp tag_release(_) do
    Mix.shell().info("Tagging release as v#{@version}")
    System.cmd("git", ["tag", "v#{@version}", "--message", "Release v#{@version}"])
    System.cmd("git", ["push", "--tags"])
  end
end
