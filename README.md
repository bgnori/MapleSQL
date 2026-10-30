# MapleSQL

MapleSQL is an experiment in bringing HoneySQL's data-driven SQL construction
to Lean 4. The initial implementation supports parameterized `SELECT`,
`INSERT`, `UPDATE`, and `DELETE` statements.

See [the design notes](docs/design.md) for the HoneySQL comparison, the
trade-offs of a statically typed API, and the Mathlib and CI decisions.

## Build and test

Install the Lean version specified in `lean-toolchain`, then run:

```sh
lake build
```

The test module uses Lean's `#guard` command, so the build checks the expected
SQL and parameter values without an additional test dependency.
