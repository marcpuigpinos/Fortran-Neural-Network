> **AI Generated**

# Architecture

This document describes the module layout of the Fortran Neural Network
library and the public API as currently implemented. It reflects only code
present in the tree; see [`CHANGELOG.md`](CHANGELOG.md) for per-version
changes and [`AGENTS.md`](../AGENTS.md) for the authoritative style rules.

## Overview

As of version **0.0.1** the library consists of a single entry-point module.
The overall repository layout (per `AGENTS.md`) is:

```
src/        Fortran library sources (one module per file)
tests/      Standalone test programs, tests/test*.f90
docs/       Design docs (this file) and CHANGELOG.md
build/      Generated artifacts (never committed)
Makefile    release / debug / test / docs / clean targets
VERSION     semantic version (MAJOR.MINOR.PATCH)
```

The build is driven entirely by the root `Makefile` using `gfortran`
(`-std=f2008`) with two profiles: `release` (`-O2`) and `debug`
(`-g -fcheck=all -Wall -Wextra`). Sources under `src/` and tests under
`tests/test*.f90` are discovered automatically.

## Modules

### `mFortranNeuralNetwork` — library entry point

Defined in `src/fortranNeuralNetwork.f90`. This is the top-level module that
consumers `USE` to reach the library. The entire module is `private` except
for the exports listed below.

#### Public API

| Procedure | Kind | Result | Description |
|---|---|---|---|
| `get_version()` | `pure function` | `character(len=:), allocatable` | Returns the current library version string. |

`get_version` is a pure function; aside from allocating the result it has no
side effects and performs no I/O. At release `0.0.1` it returns `"0.0.1"`.

#### Internal state

| Symbol | Kind | Value | Description |
|---|---|---|---|
| `library_version` | `private` named constant, `character(len=*)` | `"0.0.1"` | Single source of truth for the version string inside the library; kept in sync with the `VERSION` file. |

The private constant exists so callers depend on a runtime query rather than
a hard-coded literal.

#### Example

```fortran
use mFortranNeuralNetwork, only: get_version

implicit none

print '(A, 1X, A)', 'library version:', get_version()
```

#### Naming

`AGENTS.md` no longer requires the file name to match the module name and uses
the `m` + `PascalCase` module convention, so `fortranNeuralNetwork.f90`
defining `mFortranNeuralNetwork` is the standard naming (no exception
required).

## Tests

Tests are standalone programs under `tests/` named
`test<MainNameInPascalCase>.f90` (e.g. `testVersion.f90`), where the `program`
statement uses the same name as the file. Each prints `PASS <name>` on success
or aborts with `error stop 1` and a `FAIL <name> <reason>` message on failure,
and is discovered and run by `make test`.

| Test | Covers |
|---|---|
| `tests/testVersion.f90` | `get_version()` returns `"0.0.1"` with the expected length. |

## Build-system notes

Two host-specific adaptations are recorded in `CHANGELOG.md` (`0.0.0`) and
should be preserved unless the underlying tooling changes:

- `MODULE`/`USE` dependency discovery is implemented with `awk` (not `grep`)
  for portability across `grep` builds.
- Compiler-generated depfiles (`-MMD`/`-MD`) are intentionally not used, as
  they force the C preprocessor on lowercase `.f90` files with this `gfortran`.
