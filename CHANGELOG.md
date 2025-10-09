# Changelog

## Unreleased

### `Combo`

- rename `json_module/0` to `json_library/0`, because other packages are using the same pattern, like `:postgrex`, `:swoosh`, etc.
- change default json_library to `Jason`

### `Combo.Proxy`

- sort backends by specificity

## v0.4.1

### `Combo.Proxy`

- fix the default value of `:adapter` option

## v0.4.0

- add `Combo.Proxy`
- rename `Combo.Param` to `Combo.URLParam`
