# Fortran Neural Network — Agent Instructions

Neural network library implemented in modern Fortran. This file is the single
source of truth for project conventions. All agents (orchestrator and
subagents) must follow it.

## Toolchain

- Compiler: `gfortran`, standard **Fortran 2008** (`-std=f2008`).
- Build system: GNU `make`, single `Makefile` at the repo root.
  - `make release` — optimized build (`-O2`), artifacts in `build/release/`
  - `make debug`   — checked build (`-g -fcheck=all -Wall -Wextra`), artifacts in `build/debug/`
  - `make test`    — build and run the test suite against the debug build
  - `make clean`   — remove build artifacts
- Version: semantic versioning, stored in the `VERSION` file at the repo root.

## Repository layout

```
src/        Fortran sources (library modules), one module per file
tests/      Test programs, one per file, named test_*.f90 (f90 for tests)
docs/       Design docs and CHANGELOG.md (per-version entries)
build/      Generated artifacts (never committed)
```

## Code style (enforced by the reviewer)

- Free-form source files with `.f90` extension; file name equals the module
  name it contains (case-insensitive).
- `implicit none` in **every** scoping unit.
- Everything in a module is `private` by default; exports are listed
  explicitly in a `public :: ...` statement right after the accessibility
  attribute.
- Derived types: `PascalCase`. Modules, procedures, variables, constants:
  `snake_case`. Named constants instead of magic numbers.
- 4-space indentation, no tabs, maximum line length 100 characters.
- All dummy arguments carry an explicit `intent(...)`.
- Pure functions where possible; no I/O inside library code except through
  explicitly documented procedures.
- Comments start with `! ` and explain *why*, not *what*. Public API gets a
  brief doc comment above the declaration.
- Every source file declares the module it belongs to and is compilable
  independently given its `use` dependencies.

## Testing

- Each test is a standalone program `test_<topic>.f90` that exits with a
  non-zero status on failure (`error stop 1`) and prints a one-line
  `PASS <name>` / `FAIL <name> ...` result.
- The Makefile discovers `tests/test_*.f90` automatically; adding a test must
  not require Makefile edits. If it does, report it so the builder fixes the
  Makefile.

## Multi-agent workflow

Agent definitions live in `.github/agents/`. The `orchestrator` is the only
agent that talks to the human; every other subagent communicates **only**
with the orchestrator and reports results back to it.

Standard feature flow:

1. Human gives the specification to `orchestrator`.
2. `git-manager` updates the repo and creates a feature branch.
3. `implementer` writes the Fortran code on that branch.
4. `builder` builds the project (release + debug); failures loop back to `implementer`.
5. `tester` writes new tests if needed.
6. `builder` builds the tests.
7. `tester` runs the full suite; failures loop back to `implementer` (rebuild + retest).
8. `reviewer` checks style and formal correctness; findings are routed by the
   orchestrator to the responsible agent and **every resulting change is
   rebuilt and retested**.
9. `git-manager` bumps the version in `VERSION`.
10. `documenter` documents the changes in `docs/`, referencing the new version.
11. `git-manager` commits everything on the feature branch.
12. Merging into `main` happens only when the human explicitly instructs the
    orchestrator.
