# Release Instructions

1. update `CHANGELOG.md`
2. update the version in `mix.exs`
3. update the version in `package.json`
4. run `mix test`
5. run `cd npm-packages/combo && npm run test `
6. run `mix build`
7. commit code, and wait CI to pass.
8. run `mix publish`

Post operations:

1. update the deps of `combo_new`'s templates
