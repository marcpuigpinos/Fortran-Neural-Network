> **AI Generated**

# Changelog

All notable changes to this project are documented here, in [Keep a
Changelog](https://keepachangelog.com/) format, following [semantic
versioning](https://semver.org/). The current release is also recorded in the
`VERSION` file at the repository root. Entries are listed newest first.

## [0.4.0] - 2026-10-27

### Added

- **Abstract layer base `mAbstractLayer`** (`src/mAbstractLayer.f90`), the
  third internal module of the architecture planned in
  [`memory/API_DESIGN.md`](memory/API_DESIGN.md) (section 3, `AbstractLayer`)
  to land. It defines the abstract base type `AbstractLayer` for all layer
  kinds, with three deferred `pure` type-bound bindings:

  - `forward(self, x) result(y)` — pure evaluation of the layer on a 1-D
    input vector `x(:)`, returning a 1-D output vector `y(:)`. The result is
    declared `allocatable` because the abstract interface cannot fix the
    output length from the base type alone (only the concrete implementation
    knows `n_out`); each concrete implementation allocates the correct size.
  - `output_size(self) result(n)` — the output dimension the layer produces,
    used by the future network driver to validate layer-to-layer shape
    compatibility and allocate caches.
  - `parameter_count(self) result(n)` — the total number of trainable
    scalars (weights plus biases), used by the future driver to size flat
    gradient and optimizer state buffers.

  The forward-only v1 design is intentional: backward/gradient methods are
  deliberately excluded here because the network driver owns backpropagation
  (`docs/memory/API_DESIGN.md` section 3). Like `mOptimizers`/`mActivations`
  the module depends solely on `iso_fortran_env` (`real64`), its abstract
  interfaces use the same forward-reference-after-declaration pattern as
  those modules, and it is **not** re-exported through
  `mFortranNeuralNetwork`: no `Network` type exists yet, so it is consumed
  directly (by the tests below) and will be wired into the umbrella module
  when the network layer arrives.

- **Concrete dense layer `mDenseLayer`** (`src/mDenseLayer.f90`), the first
  concrete `extends(AbstractLayer)` type, implementing the fully-connected
  affine transform `y = matmul(W, x) + b`. No activation is applied —
  pairing a layer with an `Activation` from `mActivations` is the future
  network driver's job, which keeps this type a pure affine transform. The
  weights are stored as `W(n_out, n_in)` per
  `.github/skills/neural-networks/SKILL.md`, so the forward pass is a single
  `matmul` call and backpropagation needs no transpose convention. Exports:

  - `DenseLayer` — the layer type with public components `weights(:,:)`
    (`n_out x n_in`), `bias(:)` (`n_out`), `n_in` and `n_out` (both `0`
    until initialized), mirroring the pragmatic open-component simplicity
    of `mActivations`/`mOptimizers`. It implements the three deferred
    bindings: `forward` (pure) as `matmul(W, x) + b`, `output_size` (pure)
    as `n_out`, and `parameter_count` (pure) as `n_out * n_in + n_out`.
  - `dense_init(self, n_in, n_out)` — the public module subroutine that
    (re)establishes the shape invariants `size(weights, 1) == n_out`,
    `size(weights, 2) == n_in` and `size(bias) == n_out` and records the
    dimensions. It allocates, so it is deliberately not `pure`; it
    ZERO-fills weights and biases and releases any existing allocations
    first, so calling it repeatedly (or resizing) an already-allocated
    layer is safe.

  Randomized weight initialization (Xavier/He with a stored seed, per
  `.github/skills/neural-networks/SKILL.md`) is deliberately **deferred** to
  a future feature alongside the network driver. The symmetric-zero caveat
  of zero-initialized weights — every neuron of a trained layer would be
  identical and symmetry would never break — is documented at the source
  level rather than hidden, and real training must replace the zero fill
  first. Like `mAbstractLayer`, the module is **not** re-exported through
  `mFortranNeuralNetwork`.

- **Five test programs** for `mAbstractLayer`/`mDenseLayer` (all passing;
  the suite is now 16 tests, all green; release and debug builds
  warning-free):

  | Test | Covers |
  |---|---|
  | `tests/testDenseLayerForward.f90` | `DenseLayer%forward` numeric correctness on a hand-built 3x2 layer (W rows `[1,2]`, `[3,4]`, `[5,6]`, bias `[10,20,30]`, `x = [1,1]` → `[13,27,41]`), checked against both hardcoded constants and an independently recomputed row-wise `W(i,:) * x + b(i)`; asserts the result length equals `n_out`. |
  | `tests/testDenseLayerShape.f90` | `dense_init` shape invariants on two shapes (3/2 and 4/3): `size(weights,1) == n_out`, `size(weights,2) == n_in`, `size(bias) == n_out`; an un-initialized layer reports `output_size() == 0`, `parameter_count() == 0` and unallocated arrays. |
  | `tests/testDenseLayerInit.f90` | `dense_init` records `n_in`/`n_out`, zero-fills weights and bias (the v1 contract), yields `output_size() == n_out`; repeated init on an already-allocated layer works and fully overwrites the bookkeeping. |
  | `tests/testDenseLayerParamCount.f90` | `parameter_count == n_out * n_in + n_out` for two shapes and equals `size(weights) + size(bias)`; zero before init. |
  | `tests/testDenseLayerDispatch.f90` | Polymorphic dispatch through a `class(AbstractLayer), allocatable` variable allocated from a `DenseLayer` source: `output_size`, `parameter_count` and `forward` all resolve to the concrete dense implementations (the headline deliverable). |

### Notes

- Both new modules are **not** re-exported through `mFortranNeuralNetwork`
  yet (consistent with `mOptimizers` and `mActivations`); they will be wired
  into the umbrella module when `Network` lands.
- The `mAbstractLayer` and `mDenseLayer` module `@version` FORD tags were
  synced to `0.4.0` to track the `VERSION` file, per the documentation rule
  that `@version` mirrors `VERSION`.
- The library version moves `0.3.0 → 0.4.0` (new functionality,
  backward-compatible); `get_version()` and the generated `mVersion` module
  derive `0.4.0` from `VERSION` automatically (no source changes needed).

## [0.3.0] - 2026-10-26

### Added

- **`Heaviside` activation** (`src/activations.f90`), the third concrete
  `extends(Activation)` type in `mActivations`, added alongside the existing
  `ReLU` and `Sigmoid`. The abstract `Activation` base and its deferred
  `fn`/`deriv` bindings (`docs/memory/API_DESIGN.md` section 3,
  `.github/skills/neural-networks/SKILL.md`) are unchanged; `Heaviside` simply
  supplies a third pair of overrides following the same activation/derivative
  pairing. It implements the Heaviside step function
  ([Wikipedia](https://en.wikipedia.org/wiki/Heaviside_step_function)),
  `H(x) = 0` for `x < 0` and `H(x) = 1` for `x >= 0`, with the documented
  `H(0) = 1` convention. Like the other activations its bindings are `pure`
  and applied element-wise to a 1-D `real(real64)` array `z(:)`:

  - `fn` returns the `{0, 1}` values directly via
    `merge(1.0_real64, 0.0_real64, z >= 0.0_real64)`, so the result is exactly
    `1` at and above the origin and `0` below it (a subset of `[0, 1]`).
  - `deriv` returns the classical pointwise derivative `0` for every element,
    including `z = 0` (consistent with the ReLU kink choosing the `0`
    subgradient). NOTE: the generalized/distributional derivative of the step
    function is the Dirac delta `delta(x)`, which has no finite real-number
    representation — this is exactly why a pure step activation is not
    trainable by standard SGD gradient descent (the gradient vanishes almost
    everywhere, so no useful weight updates flow through it). The type is
    therefore provided as a hard-threshold/indicator building block rather
    than as a hidden-layer activation; see `heaviside_deriv` for the same
    explanation at the source level, mirroring how the ReLU/Sigmoid entries
    document their derivative conventions.

  As with `ReLU`/`Sigmoid` and `mOptimizers`, `mActivations` remains **not**
  re-exported through `mFortranNeuralNetwork` (no `Layer`/`Network` type exists
  yet) and this feature only added `public :: Heaviside`. The module still
  depends solely on `iso_fortran_env` (`real64`).

- **Two test programs** for `Heaviside` (all passing; the suite is now 11
  tests, all green; release and debug builds warning-free):

  | Test | Covers |
  |---|---|
  | `tests/testActivationsHeaviside.f90` | Direct `Heaviside` `fn`/`deriv` checks on a mixed-sign vector: the `{0, 1}` membership of every `fn` result, the `H(0) = 1` kink convention (pinned both by a dedicated single-element call and by the mixed-sign mask), and that `deriv` is identically `0` for every element including `z = 0`. |
  | `tests/testActivationsHeavisideDispatch.f90` | Polymorphic dispatch through a `class(Activation)` variable allocated to `Heaviside`, proving the deferred bindings resolve to the Heaviside implementations (`fn` → `{0, 1, 1}`, `deriv` → `{0, 0, 0}` on a negative/zero/positive input). |

### Notes

- The `mActivations` module `@version` FORD tag was synced to `0.3.0` to track
  the `VERSION` file, per the documentation rule that `@version` mirrors
  `VERSION`.
- The library version moves `0.2.0 → 0.3.0` (new functionality,
  backward-compatible); `get_version()` and the generated `mVersion` module
  derive `0.3.0` from `VERSION` automatically (no source changes needed).

## [0.2.0] - 2026-10-21

### Added

- **Internal activation module `mActivations`** (`src/activations.f90`), the
  second piece of the architecture planned in
  [`memory/API_DESIGN.md`](memory/API_DESIGN.md) (section 3, `mActivations`)
  to land. It follows the activation/derivative pairing prescribed by the
  neural-network implementation skill
  (`.github/skills/neural-networks/SKILL.md`): every trainable activation
  supplies both halves, and the derivative is taken with respect to the
  pre-activation `z`, which is exactly what backpropagation multiplies the
  upstream gradient by. Exports:

  - `Activation` — abstract base type for element-wise activations with two
    deferred bindings, `fn(self, z)` (the activation value `a = f(z)`) and
    `deriv(self, z)` (the derivative `d = df/dz`), both applied element-wise
    to a 1-D `real(real64)` array `z(:)` and returning a same-shape array.
    The base is stateless and both bindings are `pure`.
  - `ReLU` — first concrete extension, `a = max(0, z)`, with derivative `1`
    for `z > 0` else `0`. The ReLU kink at `z = 0` has no true derivative;
    the documented convention `deriv(0) = 0` is used (the alternative
    subgradient `1` would silently revive units sitting exactly at the kink).
  - `Sigmoid` — second concrete extension, `a = 1 / (1 + exp(-z))`, evaluated
    via a branch-stabilised form (`1/(1+exp(-z))` for `z >= 0`,
    `exp(z)/(1+exp(z))` for `z < 0`) so the exponential never overflows to
    `INF`/`NaN` for any finite `z`. The derivative reuses that stable value as
    `d = a * (1 - a)`, so backpropagation never recomputes an exponential and
    the derivative path inherits the same overflow-safety.

  Like `mOptimizers`, the module depends only on `iso_fortran_env` (`real64`)
  and is deliberately **not yet re-exported** through
  `mFortranNeuralNetwork`: no `Network`/`Layer` type exists yet, so
  `mActivations` is consumed directly by tests today and will be wired into
  the umbrella module when the network layer arrives. The planned `ACT_*`
  typed dispatch-kind constants were likewise deferred to that feature,
  parallel to how `OPT_SGD` was left out of `mOptimizers`.

- **Four test programs** for `mActivations` (all passing; the suite is now 9
  tests, all green; debug and release builds warning-free):

  | Test | Covers |
  |---|---|
  | `tests/testActivationsRelu.f90` | ReLU `fn`/`deriv`, including the `deriv(0) = 0` kink convention. |
  | `tests/testActivationsSigmoid.f90` | Sigmoid `fn`/`deriv`: value at 0, symmetry, monotonicity, known values, and the derivative range `(0, 0.25]`. |
  | `tests/testActivationsSigmoidStability.f90` | `±1000` inputs stay finite and in-bounds via `ieee_arithmetic`, proving the overflow-safe branch. |
  | `tests/testActivationsDispatch.f90` | Polymorphic dispatch through a `class(Activation)` polymorphic variable proves the deferred bindings resolve correctly. |

### Notes

- **Why `fn`/`deriv` are not `elemental`.** The deferred bindings must accept
  the passed-object dummy, which is polymorphic (`class(Activation)`), and
  `elemental` procedures forbid polymorphic dummies. They therefore take a 1-D
  assumed-shape array `z(:)` and apply their formula element-wise in their
  implementations; both concrete implementations are `pure`, and the abstract
  interfaces are `pure` as well so the specific bindings conform (a deferred
  binding and its implementation must agree on purity).
- The library version moves `0.1.0 → 0.2.0` (new functionality,
  backward-compatible); `get_version()` and the generated `mVersion` module
  derive `0.2.0` from `VERSION` automatically (no source changes needed).

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
