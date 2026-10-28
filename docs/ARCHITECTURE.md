> **AI Generated**

# Architecture

This document describes the module layout of the Fortran Neural Network
library and the public API as currently implemented. It reflects only code
present in the tree; see [`CHANGELOG.md`](CHANGELOG.md) for per-version
changes and [`AGENTS.md`](../AGENTS.md) for the authoritative style rules.

## Overview

As of version **0.4.1** the library consists of a single entry-point module,
augmented by a small version module (`mVersion`) that the build generates
from the `VERSION` file, plus the internal implementation modules of the
planned architecture: `mOptimizers` (optimizer strategies), `mActivations`
(element-wise activation functions) and the layer modules `mAbstractLayer`
(abstract layer base) and `mDenseLayer` (fully-connected affine layer; see
below). Since 0.4.1 compilation is delegated to **fpm** (the Fortran Package
Manager); the Fortran sources and public API themselves are unchanged from
0.4.0. The overall repository layout (per `AGENTS.md`) is:

```
src/        Fortran library sources (one module per file)
test/       Standalone test programs, test/test*.f90
docs/       Design docs (this file) and CHANGELOG.md
build/      Generated artifacts (never committed; owned by fpm)
fpm.toml    fpm manifest (library + test auto-discovery)
Makefile    thin front-end: release / debug / test / docs / clean targets
VERSION     semantic version (MAJOR.MINOR.PATCH)
```

The root `Makefile` is a thin front-end: it generates the version module from
`VERSION` and then invokes `fpm` (Fortran Package Manager, see `fpm.toml`),
which drives `gfortran` and owns compilation, module dependency ordering and
the `build/` tree, using fpm's built-in profiles `release` (optimized) and
`debug` (checked: bounds checking plus extra warnings). The project's Fortran
2008 rule (`-std=f2008`) is passed to fpm via `--flag`, as fpm 0.12 has no
manifest key for the language standard. Library sources under `src/` and test
programs under `test/` are discovered automatically by fpm.

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
not a hand-maintained literal: the `Makefile` front-end derives it from the
`VERSION` file at the repo root and fpm compiles it (see Build-system notes
below).

#### Version source (`mVersion`)

`mFortranNeuralNetwork` itself holds no version literal; `get_version` simply
returns the `library_version` parameter `USE`d from the generated `mVersion`
module (`src/mVersion.f90`), which the `Makefile` front-end recreates whenever
`VERSION` changes and fpm then compiles into the library:

| Symbol | Kind | Origin | Description |
|---|---|---|---|
| `mVersion::library_version` | `public` named constant, `character(len=*)` | Generated at build time from `VERSION` into `src/mVersion.f90` (git-ignored, never edited by hand) so fpm compiles it as part of the library | Single source of truth for the library version string. |

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

### `mActivations` — element-wise activations (internal)

Defined in `src/activations.f90` (version **0.2.0**). This is the second
internal module of the architecture planned in
[`memory/API_DESIGN.md`](memory/API_DESIGN.md) (section 3) to land. Like
`mOptimizers` it is **not** currently re-exported through
`mFortranNeuralNetwork`: no `Network`/`Layer` type exists yet, so today it is
consumed directly (by the tests below) and will be wired into the umbrella
module when the network layer arrives. It depends on nothing but
`iso_fortran_env` (`real64`), so it compiles independently of the
not-yet-written `mLayer`/`mNetwork`. The planned `ACT_*` dispatch-kind
constants were deferred to that feature, parallel to how `OPT_SGD` was left
out of `mOptimizers`.

The design follows the activation/derivative pairing: forward and backward
passes stay pure, and each activation supplies both its value and its
derivative with respect to the pre-activation `z`.

#### Public API

| Symbol | Kind | Description |
|---|---|---|
| `Activation` | `abstract type` | Base for element-wise activations. Two deferred bindings `fn(self, z)` (the value `a = f(z)`) and `deriv(self, z)` (the derivative `d = df/dz`), both applied element-wise to a 1-D `real(real64)` array `z(:)` and returning a same-shape array. Both are `pure`; the base carries no state. Further activations (tanh, softmax, linear) are planned as extensions in a later feature. |
| `ReLU` | `type, extends(Activation)` | Rectified Linear Unit: `a = max(0, z)`; derivative `1` for `z > 0` else `0`, with the documented convention `deriv(0) = 0` at the kink. |
| `Sigmoid` | `type, extends(Activation)` | Logistic sigmoid `a = 1/(1 + exp(-z))` in `(0, 1)`, evaluated via a branch-stabilised form (the `z >= 0` branch uses `1/(1+exp(-z))`, the `z < 0` branch `exp(z)/(1+exp(z))`) so the exponential never overflows for any finite `z`. Derivative expressed through the activation value `d = a*(1 - a)`, reusing the stable evaluation. |

| Binding | Arguments | Notes |
|---|---|---|
| `fn` | `class(Activation), intent(in) :: self`; `real(real64), intent(in) :: z(:)`; result `a(size(z))` | Element-wise activation value. `pure`. Not `elemental` by design: the deferred binding's passed-object dummy is polymorphic (`class(Activation)`), which `elemental` forbids, so the formula is applied element-wise in the implementation. |
| `deriv` | `class(Activation), intent(in) :: self`; `real(real64), intent(in) :: z(:)`; result `d(size(z))` | Element-wise derivative w.r.t. the pre-activation `z`, which backpropagation multiplies the upstream gradient by. `pure`. |

### `mAbstractLayer` — abstract layer base (internal)

Defined in `src/mAbstractLayer.f90` (version **0.4.0**). This is the third
internal module of the architecture planned in
[`memory/API_DESIGN.md`](memory/API_DESIGN.md) (section 3, `AbstractLayer`) to
land. Like `mOptimizers` and `mActivations` it is **not** currently
re-exported through `mFortranNeuralNetwork`: no `Network` type exists yet, so
today it is consumed directly (by the tests below, alongside
`mDenseLayer`) and will be wired into the umbrella module when the network
layer arrives. It depends on nothing but `iso_fortran_env` (`real64`), so it
compiles independently of the not-yet-written `mNetwork`.

The forward-only design is intentional for v1: backward/gradient methods are
deliberately excluded because the network driver owns backpropagation
(`API_DESIGN.md` §3). The `parameter_count` binding lets that driver size
flat gradient buffers without knowing layer internals.

#### Public API

| Symbol | Kind | Description |
|---|---|---|
| `AbstractLayer` | `abstract type` | Base for all neural network layer kinds. Three deferred bindings `forward`, `output_size` and `parameter_count`, all `pure`. The base carries no state; all shape and parameter data live in the concrete extensions (starting with `DenseLayer` in `mDenseLayer`). Its abstract interfaces are declared after the type using the same forward-reference pattern as `mActivations`/`mOptimizers`. |

| Binding | Arguments | Notes |
|---|---|---|
| `forward` | `class(AbstractLayer), intent(in) :: self`; `real(real64), intent(in) :: x(:)`; result `allocatable y(:)` | Pure evaluation of the layer on a single 1-D input vector. The result is `allocatable` because the abstract interface cannot fix the output length from the base type alone — only the concrete implementation knows `n_out`. |
| `output_size` | `class(AbstractLayer), intent(in) :: self`; result `integer n` | The number of outputs the layer produces (`n_out`), used to validate layer-to-layer shapes and allocate caches. `pure`. |
| `parameter_count` | `class(AbstractLayer), intent(in) :: self`; result `integer n` | Total trainable scalars (weights plus biases), used by the future driver to size flat gradient/optimizer buffers. For a dense layer this is `n_out * n_in + n_out`. `pure`. |

### `mDenseLayer` — fully-connected affine layer (internal)

Defined in `src/mDenseLayer.f90` (version **0.4.0**). This module provides
`DenseLayer`, the first concrete `extends(AbstractLayer)` type: a
fully-connected affine transform `y = matmul(W, x) + b`. Like the other
internal modules it is **not** currently re-exported through
`mFortranNeuralNetwork`: no `Network` type exists yet, so it is consumed
directly (by the tests below) and will be wired into the umbrella module when
the network layer arrives. The module depends on `iso_fortran_env` (`real64`)
and `mAbstractLayer`.

The layer applies **no** activation: pairing each layer with an `Activation`
from `mActivations` is the future network driver's job, keeping this type a
pure affine transform. The weights are stored as `W(n_out, n_in)` per
`.github/skills/neural-networks/SKILL.md`, so the forward pass is a single
`matmul` call and backpropagation needs no transpose convention.

#### Public API

| Symbol | Kind | Description |
|---|---|---|
| `DenseLayer` | `type, extends(AbstractLayer)` | A dense (fully-connected) layer with public components `weights(:,:)` (`n_out x n_in`), `bias(:)` (`n_out`), `n_in` and `n_out` (both `0` until `dense_init`), mirroring the open-component simplicity of `mActivations`/`mOptimizers`. Implements the three deferred bindings: `forward` (pure) as `matmul(W, x) + b`, `output_size` (pure) as `n_out`, `parameter_count` (pure) as `n_out * n_in + n_out`. |
| `dense_init(self, n_in, n_out)` | `public module subroutine` | Allocates and ZERO-fills the parameters, establishing the shape invariants `size(weights,1) == n_out`, `size(weights,2) == n_in`, `size(bias) == n_out` and recording the dimensions. Allocates, so it is not `pure`; it releases any existing allocations first, so repeated init/resize is safe. Randomized init (Xavier/He + seed) is deliberately deferred to a future feature; the symmetric-zero caveat of zero weights is documented at the source level rather than hidden. |

## Tests

Tests are standalone programs under `test/` named
`test<MainNameInPascalCase>.f90` (e.g. `testVersion.f90`), where the `program`
statement uses the same name as the file. Each prints `PASS <name>` on success
or aborts with `error stop 1` and a `FAIL <name> <reason>` message on failure,
and is auto-discovered by fpm and run by `make test` (→ `fpm test`).

| Test | Covers |
|---|---|
| `test/testVersion.f90` | `get_version()` equals the `VERSION` file contents (read from disk and trimmed at runtime; fpm runs test executables with CWD = the repo root) and has the same length. |
| `test/testOptimizersStep.f90` | One `GradientDescent%update` step matches `W - lr*dW` / `b - lr*db` exactly (independently computed), and the `intent(in)` gradients are left unmodified. |
| `test/testOptimizersZeroLr.f90` | `learning_rate = 0` leaves weights and biases unchanged (no-op step). |
| `test/testOptimizersConvergence.f90` | Repeated gradient-descent steps minimise a quadratic and converge to its analytic minimum. |
| `test/testOptimizersDispatch.f90` | Virtual dispatch through a `class(Optimizer)` polymorphic variable reaches the `GradientDescent` implementation. |
| `test/testActivationsRelu.f90` | ReLU `fn`/`deriv`, including the `deriv(0) = 0` kink convention. |
| `test/testActivationsSigmoid.f90` | Sigmoid `fn`/`deriv`: value at 0, symmetry, monotonicity, known values, and the derivative range `(0, 0.25]`. |
| `test/testActivationsSigmoidStability.f90` | `±1000` inputs stay finite and in-bounds via `ieee_arithmetic`, proving the overflow-safe branch. |
| `test/testActivationsDispatch.f90` | Polymorphic dispatch through a `class(Activation)` polymorphic variable proves the deferred bindings resolve correctly. |
| `test/testDenseLayerForward.f90` | `DenseLayer%forward` numeric correctness on a hand-built 3x2 layer (`x = [1,1]` → `[13,27,41]`), checked against hardcoded constants and an independently recomputed row-wise `W(i,:) * x + b(i)`; asserts the result length equals `n_out`. |
| `test/testDenseLayerShape.f90` | `dense_init` shape invariants on two shapes (3/2 and 4/3); an un-initialized layer reports `output_size() == 0`, `parameter_count() == 0` and unallocated arrays. |
| `test/testDenseLayerInit.f90` | `dense_init` records `n_in`/`n_out`, zero-fills weights and bias, yields `output_size() == n_out`; repeated init on an already-allocated layer works and fully overwrites the bookkeeping. |
| `test/testDenseLayerParamCount.f90` | `parameter_count == n_out * n_in + n_out` for two shapes and equals `size(weights) + size(bias)`; zero before init. |
| `test/testDenseLayerDispatch.f90` | Polymorphic dispatch through a `class(AbstractLayer), allocatable` variable allocated from a `DenseLayer` source: `output_size`, `parameter_count` and `forward` all resolve to the concrete dense implementations. |

## Build-system notes

### Version generation

`VERSION` is the single source of truth for the version string; every other
copy is derived by the build:

- **Library:** `VERSION` → `src/mVersion.f90` (module `mVersion` exposing
  the `library_version` parameter) → `get_version()`. The `Makefile`
  front-end generates the file into `src/` (git-ignored via `.gitignore`,
  never committed) so fpm compiles it as part of the library; it is
  regenerated whenever `VERSION` changes, and the `Makefile` aborts with a
  parse-time `$(error ...)` if `VERSION` is missing or empty.
- **Documentation:** `VERSION` → `ford.md.in` (template whose `version:` key
  holds the `@NN_VERSION@` placeholder) → `build/ford.md` → `build/docs/`
  (`make docs` substitutes the version and runs FORD; template paths are
  relative to `build/`, where the rendered config lives).

### Build engine (fpm)

Since `0.4.1` (see [`CHANGELOG.md`](CHANGELOG.md)) compilation is delegated to
**fpm** (Fortran Package Manager). fpm owns module dependency ordering, the
`build/` output tree, and running the discovered test programs; the root
`Makefile` is a thin front-end that injects the version module and then calls
`fpm build --profile release|debug` / `fpm test`.

- The Fortran 2008 strictness flag `-std=f2008` is passed to every fpm
  invocation via `--flag`, since fpm 0.12 has no manifest key for selecting
  the language standard. The `gfortran` toolchain is otherwise unchanged.
- The earlier hand-written gfortran rules and the `awk`-based `MODULE`/`USE`
  dependency discovery (recorded in the `0.0.0` release) were removed: that
  ordering is now fpm's responsibility.
