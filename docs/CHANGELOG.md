> **AI Generated**

# Changelog

All notable changes to this project are documented here, in [Keep a
Changelog](https://keepachangelog.com/) format, following [semantic
versioning](https://semver.org/). The current release is also recorded in the
`VERSION` file at the repository root. Entries are listed newest first.

## [0.1.0] - 2026-10-19

### Added

- **Internal optimizer module `mOptimizers`** (`src/optimizers.f90`), the
  first piece of the architecture planned in
  [`memory/API_DESIGN.md`](memory/API_DESIGN.md) (sections 3, 4, 5, 6, 10) to
  land. It follows the "separate update pass" pattern prescribed by the
  neural-network implementation skill: forward and backward passes stay pure
  and only the optimizer mutates parameters. Exports:

  - `Optimizer` — abstract base type for parameter-update strategies with a
    single deferred binding `update(self, weights, bias, d_weights, d_bias,
    learning_rate)`. The base is an opaque, stateless strategy (no
    constructor needed); stateful optimizers extend it with their own
    components.
  - `GradientDescent` — first concrete extension, implementing the plain
    in-place step `W = W - lr*dW`, `b = b - lr*db` over a single layer's
    weight matrix `W(n_out, n_in)` and bias vector `b(n_out)`. Given
    whole-training-set gradients this is full-batch gradient descent; given
    mini-batch gradients it is SGD — the optimizer is agnostic to how the
    gradients were formed.

  The module depends only on `iso_fortran_env` (`real64`) and is
  deliberately **not yet re-exported** through `mFortranNeuralNetwork`: no
  `Network` type exists yet, so `mOptimizers` is consumed directly by tests
  today and will be wired into the umbrella module when the network layer
  arrives.

- **Four test programs** for `mOptimizers` (all passing; debug and release
  builds warning-free):

  | Test | Covers |
  |---|---|
  | `tests/testOptimizersStep.f90` | Exact single-step arithmetic (`W - lr*dW`, `b - lr*db`) against independently computed expectations, and that `update` never writes through the `intent(in)` gradient arrays. |
  | `tests/testOptimizersZeroLr.f90` | `learning_rate = 0` is a no-op: weights and biases are left bit-identical. |
  | `tests/testOptimizersConvergence.f90` | Repeated steps minimise a quadratic and converge to its known analytic minimum. |
  | `tests/testOptimizersDispatch.f90` | Virtual dispatch: a `class(Optimizer)` polymorphic variable calls the `GradientDescent` implementation. |

### Notes

- **`GradientDescent`, not `SGD`.** `API_DESIGN.md` originally named the v1
  optimizer `SGD`; per the human's feature note (`features/20261018_01_optimizer-gd.md`)
  the concrete type is named `GradientDescent`, since the strategy itself is
  batch-agnostic (see above). Momentum and Adam remain deferred per
  `API_DESIGN.md` section 11 and are **not** implemented.
- The library version moves `0.0.2 → 0.1.0` (new functionality,
  backward-compatible); `get_version()` and the generated `mVersion` module
  derive `0.1.0` from `VERSION` automatically (no source changes needed).

## [0.0.2] - 2026-10-18

### Changed

- **Version single source of truth (build-derived).** The version string was
  previously hand-maintained in four places — `VERSION`, the `library_version`
  constant in `src/fortranNeuralNetwork.f90`, `expected_version` in
  `tests/testVersion.f90` and `version:` in `ford.md` — and could desync. It is
  now derived from `VERSION` alone at build time (pure Fortran 2008, no C
  preprocessor):
  - The `Makefile` reads `VERSION` into `VERSION_TEXT` (with a parse-time
    `$(error ...)` guard when the file is missing or empty) and generates
    `build/generated/mVersion.f90`, defining module `mVersion` with
    `public :: library_version` as a character parameter. The generated file
    lives in git-ignored `build/` and is regenerated whenever `VERSION`
    changes.
  - `src/fortranNeuralNetwork.f90` no longer holds a version literal; it
    `use`s `mVersion, only: library_version` and `get_version()` returns it.
    The library public API (`get_version`) is unchanged.
  - `tests/testVersion.f90` no longer hard-codes the expected version: it
    reads the `VERSION` file at runtime (the working directory is the repo
    root under `make test`), trims it, and asserts `get_version()` equals it
    with equal length; the `PASS`/`FAIL`/`error stop` convention is preserved.
  - `ford.md` was replaced by the template `ford.md.in`, whose `version:` key
    holds a `@NN_VERSION@` placeholder; `make docs` substitutes `VERSION_TEXT`
    into `build/ford.md` (template paths are relative to `build/`: `src_dir
    ../src`, `output_dir ../build/docs`, `exclude_dir ../tests ../build`) and
    runs FORD on it.

### Notes

- The version literal now exists only in `VERSION`; `get_version()`, the
  generated `mVersion` module and the rendered FORD documentation all derive
  `0.0.2` from it, and editing `VERSION` alone propagates everywhere.

## [0.0.1] - 2026-10-18

### Changed

- **Naming conventions (supersedes the `0.0.0` "approved naming exception").** The
  rules in `AGENTS.md` were relaxed and a module-naming convention adopted:
  - A source `.f90` file's name no longer has to equal the module it contains
    (e.g. `fortranNeuralNetwork.f90` defining `mFortranNeuralNetwork` is now the
    standard, not an exception).
  - Modules follow `m` + `PascalCase` (e.g. `mLayer`, `mFortranNeuralNetwork`);
    derived types remain `PascalCase` and procedures/variables/constants remain
    `snake_case`.
  - Tests are named `test<MainNameInPascalCase>.f90` with a same-named `program`
    (e.g. `testVersion.f90` / `program testVersion`); the `Makefile` now discovers
    `tests/test*.f90` instead of `tests/test_*.f90`.

### Notes

- The library version string, the test's expected value, the `@version` FORD tag
  and `ford.md` were all synced to `0.0.1`.
- `ford.md` carries its `> **AI Generated**` marker as the first body
  line below the FORD `key: value` meta block, because FORD's
  Markdown "meta" parser cannot carry a leading `#`-style comment as
  the file's first line. This mirrors the build-system adaptation
  style of the `0.0.0` entry.

## [0.0.0] - 2026-10-17

Initial project bootstrap (branch `feature/project-bootstrap`). Establishes
the library entry point, the build system, the first test, and the version
file.

### Added

- **Library entry-point module `mFortranNeuralNetwork`**
  (`src/fortranNeuralNetwork.f90`). Public API:

  - `pure function get_version() result(version)` →
    `character(len=:), allocatable` — returns the library version string
    (`"0.0.0"` at this release).

  The version string is held in the private named constant `library_version`,
  kept in sync with the `VERSION` file, so consumers never depend on a
  hard-coded literal.

- **Root `Makefile`** with the four standard targets:

  | Target | Behavior |
  |---|---|
  | `make release` | Optimized build (`-O2`), artifacts in `build/release/` |
  | `make debug`   | Checked build (`-g -fcheck=all -Wall -Wextra`), artifacts in `build/debug/` |
  | `make test`    | Builds and runs every `tests/test_*.f90` against the debug build |
  | `make clean`   | Removes all build artifacts |

  Compiler: `gfortran` with `-std=f2008`. Library sources under `src/` and
  tests under `tests/test_*.f90` are discovered automatically; adding a source
  or test requires no `Makefile` edits.

- **Test `tests/test_version.f90`** — verifies that `get_version()` returns
  `"0.0.0"` and that the returned string has the expected length; exits with
  `error stop 1` and a `FAIL` message on mismatch, prints `PASS test_version`
  on success.

- **`VERSION` file** initialized to `0.0.0` at the repository root.

- **This changelog and `docs/ARCHITECTURE.md`** describing the module layout
  and the entry-point API.

### Documented exceptions

- **Entry-point module naming (approved).** The main library file is named
  `fortranNeuralNetwork.f90` and its module `mFortranNeuralNetwork`. This is a
  deliberate, human-approved deviation from two `AGENTS.md` style rules —
  "file name equals the module name it contains" and "modules are
  `snake_case`" — required for this entry-point module only. Reviewers should
  treat this naming as sanctioned and must not re-flag it; the exception
  applies solely to `src/fortranNeuralNetwork.f90` / `mFortranNeuralNetwork`
  and does not extend to future modules, which follow the standard rules.

### Notes on the toolchain (build-system adaptations)

Two verified adaptations to this host's tooling, recorded so future reviews
do not treat them as defects:

- **Module/USE dependency discovery uses `awk`, not `grep`.** `grep` builds on
  this host vary in behavior (build variants/locale), so `MODULE`/`USE` name
  discovery in the `Makefile` is done with `awk` (case folding via `tolower`),
  assuming the project's single-line `USE` statement style.
- **`-MMD`/`-MD` dependency files were dropped.** With this `gfortran`,
  `-MMD`/`-MD` force the C preprocessor on lowercase `.f90` files, which
  breaks compilation; dependencies are therefore resolved through the `awk`
  discovery above instead of compiler-generated depfiles.
