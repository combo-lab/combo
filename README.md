# Combo

A web framework, that combines the good parts of modern web development.

[![Build Status](https://github.com/combo-lab/combo/workflows/CI/badge.svg)](https://github.com/combo-lab/combo/actions/workflows/ci.yml) [![Hex.pm](https://img.shields.io/hexpm/v/combo.svg)](https://hex.pm/packages/combo)

## About

Combo started as a fork of Phoenix. Its goals includes:

- being a typical MVC framework.
- integrating with the modern frontend tooling.
- ...

To archive the goals, it:

- merges closely related dependencies, such as `phoenix_template`, `phoenix_html`, `phoenix_live_reload` etc.
- merges the HEEx engine-related code from `phoenix_live_view` and completely removes the dependency on `phoenix_live_view`.
- provides packages for integrating with the modern frontend tooling.
- ...

Although Combo is forked from Phoenix and will continue to track upstream changes in the future, full compatibility between the two is not guaranteed.

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

[MIT](./LICENSE)
