# Combo

Combines the good parts of modern web development.

[![Build Status](https://github.com/combo-team/combo/workflows/CI/badge.svg)](https://github.com/combo-team/combo/actions/workflows/ci.yml) [![Hex.pm](https://img.shields.io/hexpm/v/combo.svg)](https://hex.pm/packages/combo)

## Getting started

Read the [documentation](https://hexdocs.pm/combo).

## Contributing

We appreciate any contribution to Combo. Check our [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) and [CONTRIBUTING.md](CONTRIBUTING.md) guides for more information. We usually keep a list of features and bugs in the [issue tracker][4].

### Generating a Combo project from unreleased versions

You can create a new project using the latest Phoenix source installer (the `phx.new` Mix task) with the following steps:

1. Remove any previously installed `phx_new` archives so that Mix will pick up the local source code. This can be done with `mix archive.uninstall phx_new` or by simply deleting the file, which is usually in `~/.mix/archives/`.
2. Copy this repo via `git clone https://github.com/phoenixframework/phoenix` or by downloading it
3. Run the `phx.new` Mix task from within the `installer` directory, for example:

```bash
cd phoenix/installer
mix phx.new dev_app --dev
```

The `--dev` flag will configure your new project's `:phoenix` dep as a relative path dependency, pointing to your local Phoenix checkout:

```elixir
defp deps do
  [{:phoenix, path: "../..", override: true},
```

To create projects outside of the `installer/` directory, add the latest archive to your machine by following the instructions in [installer/README.md](https://github.com/phoenixframework/phoenix/blob/main/installer/README.md)

### Building from source

To build the documentation:

```bash
npm install --prefix assets
MIX_ENV=docs mix docs
```

To build Combo:

```bash
mix deps.get
mix compile
```

To build Combo.js:

```bash
cd assets
npm install
```

## License

[MIT](LICENSE.txt)
