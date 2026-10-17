> **AI Generated**

# Architecture

This document describes the module layout of the Fortran Neural Network
library and the public API as currently implemented. It reflects only code
present in the tree; see [`CHANGELOG.md`](CHANGELOG.md) for per-version
changes and [`AGENTS.md`](../AGENTS.md) for the authoritative style rules.

## Overview

As of version **0.0.0** the library consists of a single entry-point module.
The overall repository layout (per `AGENTS.md`) is:

```
src/        Fortran library sources (one module per file)
tests/      Standalone test programs, tests/test_*.f90
docs/       Design docs (this file) and CHANGELOG.md
build/      Generated artifacts (never committed)
Makefile    release / debug / test / clean targets
VERSION     semantic version (MAJOR.MINOR.PATCH)
```

The build is driven entirely by the root `Makefile` using `gfortran`
(`-std=f2008`) with two profiles: `release` (`-O2`) and `debug`
(`-g -fcheck=all -Wall -Wextra`). Sources under `src/` and tests under
`tests/test_*.f90` are discovered automatically.

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
side effects and performs no I/O. At release `0.0.0` it returns `"0.0.0"`.

#### Internal state

| Symbol | Kind | Value | Description |
|---|---|---|---|
| `library_version` | `private` named constant, `character(len=*)` | `"0.0.0"` | Single source of truth for the version string inside the library; kept in sync with the `VERSION` file. |

The private constant exists so callers depend on a runtime query rather than
a hard-coded literal.

#### Example

```fortran
use mFortranNeuralNetwork, only: get_version

implicit none

print '(A, 1X, A)', 'library version:', get_version()
```

#### Naming exception (approved)

The file `fortranNeuralNetwork.f90` and module `mFortranNeuralNetwork` are a
deliberate, human-approved departure from two `AGENTS.md` rules ("file name
equals the module name" and "modules are `snake_case`"). This exception is
granted for this entry-point module only; subsequent modules must follow the
standard naming rules. See the `0.0.0` entry in
[`CHANGELOG.md`](CHANGELOG.md).

## Tests

Tests are standalone programs under `tests/` named `test_<topic>.f90`. Each
prints `PASS <name>` on success or aborts with `error stop 1` and a
`FAIL <name> <reason>` message on failure, and is discovered and run by
`make test`.

| Test | Covers |
|---|---|
| `tests/test_version.f90` | `get_version()` returns `"0.0.0"` with the expected length. |

## Build-system notes

Two host-specific adaptations are recorded in `CHANGELOG.md` (`0.0.0`) and
should be preserved unless the underlying tooling changes:

- `MODULE`/`USE` dependency discovery is implemented with `awk` (not `grep`)
  for portability across `grep` builds.
- Compiler-generated depfiles (`-MMD`/`-MD`) are intentionally not used, as
  they force the C preprocessor on lowercase `.f90` files with this `gfortran`.
