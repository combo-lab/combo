# Changelog

## Unreleased

- remove the support of debug annotation for HEEx templates.
- remove verified routes, and un-deprecate router helpers.
- remove trailing_slash support of router helpers.

## v0.7.0

No substantial changes, just restructured the project.

## v0.6.0

### `Combo.Conn`

- add `put_previous_url/2`, `get_previous_url/1` for URL tracking
- add `redirect_back/2`

## v0.5.0

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
