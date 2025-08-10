# Changelog for v1.8

## Deprecations

This release introduces deprecation warnings for several features that have been soft-deprecated in the past.

- `use Combo.Controller` must now specify the `:formats` option, which may be set to an empty list if the formats are not known upfront
- The `:namespace` and `:put_default_views` options on `use Combo.Controller` are deprecated and emit a warning on use
- Specifying layouts without modules, such as `put_layout(conn, :print)` or `put_layout(conn, html: :print)` is deprecated
