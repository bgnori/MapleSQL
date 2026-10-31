# MapleSQL

MapleSQL is an experiment in bringing HoneySQL's data-driven SQL construction
to Lean 4. The initial implementation supports parameterized `SELECT`,
`INSERT`, `UPDATE`, and `DELETE` statements.

See [the design notes](docs/design.md) for the HoneySQL comparison, the
trade-offs of a statically typed API, and the Mathlib and CI decisions.

## Local development with Dev Containers

Install Docker (Docker Desktop on macOS/Windows, or Docker Engine on Linux),
VS Code, and the VS Code **Dev Containers** extension on your own computer.
Start Docker, then clone and open the current development branch:

```sh
git clone --branch copilot/create-documentation-for-maplesql https://github.com/bgnori/MapleSQL.git
cd MapleSQL
code .
```

Run **Dev Containers: Reopen in Container** from the VS Code command palette.
This uses your local Docker daemon; Codespaces or another cloud environment is
not required. The initial image and Lean downloads require internet access.

The container installs Elan and the Lean VS Code extension. On creation,
`.devcontainer/setup.sh` uses the version in `lean-toolchain`, runs `lake update`
to generate `lake-manifest.json`, then builds the library and compile-time tests.
Toolchain installation and dependency resolution have a 10-minute limit; the
build has a 5-minute limit. A download or build failure stops initialization and
appears in the Dev Containers creation log. After resolving the cause, rerun
`bash .devcontainer/setup.sh` in the container terminal.

The repository is bind-mounted from your computer: edits and the generated
manifest remain on your host when the container is removed. `.lake/` contains
ignored build artifacts. Commit `lake-manifest.json` after generating it so CI
can also resolve the project.

## Build and test

In the container terminal, run:

```sh
lake build MapleSQL MapleSQLTests
```

The test module uses Lean's `#guard` command, so the build checks the expected
SQL and parameter values without an additional test dependency.

Without a container, install Elan and the Lean version specified in
`lean-toolchain`, run `lake update` once, then use the same build command.
