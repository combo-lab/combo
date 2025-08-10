# Combo

Combines the good parts of modern web development.

[![Build Status](https://github.com/combo-team/combo/workflows/CI/badge.svg)](https://github.com/combo-team/combo/actions/workflows/ci.yml) [![Hex.pm](https://img.shields.io/hexpm/v/combo.svg)](https://hex.pm/packages/combo)

## Getting started

Read the [documentation](https://hexdocs.pm/combo).

## Contributing

We appreciate any contribution to Combo. Check our [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) and [CONTRIBUTING.md](CONTRIBUTING.md) guides for more information. We usually keep a list of features and bugs in the [issue tracker][4].

### Building from source

To build Combo only:

```console
$ mix deps.get
$ mix compile
```

To build Combo.js only:

```console
$ mix assets.deps.get
$ mix assets.build
```

To build Combo and Combo.js together:

```bash
$ mix setup
$ mix compile
$ mix assets.build
```

To build the documentation:

```console
$ mix setup
$ mix docs
```

## License

[MIT](LICENSE.txt)
