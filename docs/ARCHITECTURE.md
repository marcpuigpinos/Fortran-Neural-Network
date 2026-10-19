> **AI Generated**

# Architecture

This document describes the module layout of the Fortran Neural Network
library and the public API as currently implemented. It reflects only code
present in the tree; see [`CHANGELOG.md`](CHANGELOG.md) for per-version
changes and [`AGENTS.md`](../AGENTS.md) for the authoritative style rules.

## Overview

As of version **0.1.0** the library consists of a single entry-point module,
augmented by a small version module (`mVersion`) that the build generates
from the `VERSION` file, plus the first internal implementation module of the
planned architecture, `mOptimizers` (optimizer strategies; see below). The
overall repository layout (per `AGENTS.md`) is:

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
side effects and performs no I/O. The returned value is **build-generated**,
not a hand-maintained literal: the `Makefile` derives it from the `VERSION`
file at the repo root (see Build-system notes below).

#### Version source (`mVersion`)

`mFortranNeuralNetwork` itself holds no version literal; `get_version` simply
returns the `library_version` parameter `USE`d from the generated `mVersion`
module (`build/generated/mVersion.f90`), which the `Makefile` recreates
whenever `VERSION` changes:

| Symbol | Kind | Origin | Description |
|---|---|---|---|
| `mVersion::library_version` | `public` named constant, `character(len=*)` | Generated at build time from `VERSION` into `build/generated/mVersion.f90` (git-ignored, never edited by hand) | Single source of truth for the library version string. |

Callers still depend on a runtime query rather than a hard-coded literal; the
constant merely moved from a hand-edited source to a build-generated one.

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

### `mOptimizers` — parameter-update strategies (internal)

Defined in `src/optimizers.f90` (version **0.1.0**). This is the first
internal module of the architecture planned in
[`memory/API_DESIGN.md`](memory/API_DESIGN.md) to land. It is **not**
currently re-exported through `mFortranNeuralNetwork`: no `Network` type
exists yet, so today it is consumed directly (by the tests below) and will be
wired into the umbrella module when the network layer arrives. The module
depends on nothing but `iso_fortran_env` (`real64`), so it compiles
independently of the not-yet-written `mLayer`/`mNetwork`.

The design follows the "separate update pass" pattern: forward and backward
passes stay pure, and only the optimizer mutates parameters.

#### Public API

| Symbol | Kind | Description |
|---|---|---|
| `Optimizer` | `abstract type` | Base for parameter-update strategies. Single deferred binding `update(self, weights, bias, d_weights, d_bias, learning_rate)`, applying one in-place step for one layer's parameters `W(n_out, n_in)` / `b(n_out)`. The base carries no state; stateful strategies add components in their own extension. |
| `GradientDescent` | `type, extends(Optimizer)` | Plain gradient descent: `W = W - lr*dW`, `b = b - lr*db`. Batch-agnostic — full-batch GD for whole-set gradients, SGD for mini-batch gradients. Named `GradientDescent` (not `SGD`) per the human's feature note; momentum/Adam deferred per `API_DESIGN.md` §11. |

| Binding | Arguments | Notes |
|---|---|---|
| `update` | `class(Optimizer), intent(inout) :: self`; `real(real64), intent(inout) :: weights(:,:)`, `bias(:)`; `real(real64), intent(in) :: d_weights(:,:)`, `d_bias(:)`; `real(real64), intent(in) :: learning_rate` | Mutates `weights`/`bias` in place; never writes through the gradients. Not `pure` by design — mutation is isolated here. |

## Tests

Tests are standalone programs under `tests/` named
`test<MainNameInPascalCase>.f90` (e.g. `testVersion.f90`), where the `program`
statement uses the same name as the file. Each prints `PASS <name>` on success
or aborts with `error stop 1` and a `FAIL <name> <reason>` message on failure,
and is discovered and run by `make test`.

| Test | Covers |
|---|---|
| `tests/testVersion.f90` | `get_version()` equals the `VERSION` file contents (read from disk and trimmed at runtime; the working directory is the repo root under `make test`) and has the same length. |
| `tests/testOptimizersStep.f90` | One `GradientDescent%update` step matches `W - lr*dW` / `b - lr*db` exactly (independently computed), and the `intent(in)` gradients are left unmodified. |
| `tests/testOptimizersZeroLr.f90` | `learning_rate = 0` leaves weights and biases unchanged (no-op step). |
| `tests/testOptimizersConvergence.f90` | Repeated gradient-descent steps minimise a quadratic and converge to its analytic minimum. |
| `tests/testOptimizersDispatch.f90` | Virtual dispatch through a `class(Optimizer)` polymorphic variable reaches the `GradientDescent` implementation. |

## Build-system notes

### Version generation

`VERSION` is the single source of truth for the version string; every other
copy is derived by the build:

- **Library:** `VERSION` → `build/generated/mVersion.f90` (module `mVersion`
  exposing the `library_version` parameter) → `get_version()`. The generated
  file lives in git-ignored `build/` and is regenerated whenever `VERSION`
  changes; the `Makefile` aborts with a parse-time `$(error ...)` if
  `VERSION` is missing or empty.
- **Documentation:** `VERSION` → `ford.md.in` (template whose `version:` key
  holds the `@NN_VERSION@` placeholder) → `build/ford.md` → `build/docs/`
  (`make docs` substitutes the version and runs FORD; template paths are
  relative to `build/`, where the rendered config lives).

### Host toolchain adaptations

Two host-specific adaptations are recorded in `CHANGELOG.md` (`0.0.0`) and
should be preserved unless the underlying tooling changes:

- `MODULE`/`USE` dependency discovery is implemented with `awk` (not `grep`)
  for portability across `grep` builds.
- Compiler-generated depfiles (`-MMD`/`-MD`) are intentionally not used, as
  they force the C preprocessor on lowercase `.f90` files with this `gfortran`.
