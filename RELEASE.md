# Release Instructions

1. Check related deps for required version bumps and compatibility.
2. Bump version in related files below:
   - `CHANGELOG`
   - `mix.exs`
   - `package.json`
3. Run tests:
   - `mix test`
   - `cd assets && npm run test`
4. Commit, push code
5. Publish `combo` Hex package and docs after pruning any extraneous uncommitted files
6. Generate a new app by using `combo_new`, running `mix deps.get`, and compiling
7. Start -dev version in related files below
