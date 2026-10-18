> **AI Generated**

# Neural Network Library — API Design Memory

> **Pre-implementation design record.** This document captures an agreed
> architectural direction for the public API of the library. It targets no
> specific released version yet (`VERSION` is unchanged); the implementation it
> describes will land in a later feature cycle.

This file records the architectural direction we agreed for the dense
(fully-connected) MLP library, derived from a design conversation between the
human and the orchestrator on **2026-10-18**. It is intentionally self-contained
so it can be re-attached as context in future sessions: when work resumes, hand
this document to the orchestrator as the source of truth and pick up from the
decisions recorded here, rather than re-deriving them from scratch.

The mathematical foundations behind these shapes — losses, backpropagation,
activations, and the training loop — are **not** restated here; they live in
[`../NEURAL_NETWORK_THEORY.md`](../NEURAL_NETWORK_THEORY.md). The current,
already-implemented layout lives in [`../ARCHITECTURE.md`](../ARCHITECTURE.md).
Style, FFI, and build conventions are governed by
[`../../AGENTS.md`](../../AGENTS.md). Implementation-side checklists and
correctness pairings (activation `fn`/`deriv`, loss/gradient, the paired-record
rule, gradient checking) are in
[`../../.github/skills/neural-networks/SKILL.md`](../../.github/skills/neural-networks/SKILL.md).

## 1. Scope

What is being designed here is the **public API surface** of
`mFortranNeuralNetwork` (declared in `src/fortranNeuralNetwork.f90`) for a
dense, fully-connected feedforward (MLP) library, covering three concerns:

- **Forward inference** through a stack of layers,
- **Training**, with plain SGD as the first (and only v1) optimizer,
- **Persistence** — saving and loading a configured/trained network.

Today the library is a thin shell: `mFortranNeuralNetwork` exposes only
`get_version()` (see [`../ARCHITECTURE.md`](../ARCHITECTURE.md)). This design
extends it into a real network library without breaking the existing
entry-point contract.

## 2. Two-surface architecture

The framing principle — mandatory, and the lens for every later decision — is
**rich polymorphic OOP inside, a flat procedural `bind(C)` façade outside**.
This is the pattern used by high-quality numeric libraries where the boundary
must be a stable C ABI while the interior stays idiomatic: BLAS/LAPACK, and the
libtorch C API in particular. The interior is a class hierarchy; the boundary
knows nothing about classes.

```
mFortranNeuralNetwork (bind(C) procedural façade)  ← THE ONLY public surface
        ▲
        │ implemented with
mNetwork / mLayer / mActivations / mLosses / mOptimizers   ← private types, abstract bases + concrete derivatives
        ▲
        │ uses (currently)
intrinsic matmul + real64 + random_init/random_number (seedable)
```

The two rules that follow from this and that must not be violated:

- `mFortranNeuralNetwork` is the **only** module a consumer ever `USE`s.
  Everything else is internal machinery reached through it.
- All other modules and types are **`private`** to the library. There is no
  `public :: Layer`-style export anywhere except what the façade itself
  re-exports. Concrete types, abstract bases, and type-bound procedures never
  cross the public boundary.

## 3. Module layout

The `src/` modules planned for the implementation, and what each holds (agreed
file names; all use the `.f90` free-form extension required by `AGENTS.md`):

- **`src/fortranNeuralNetwork.f90`** → module `mFortranNeuralNetwork`: the
  procedural `bind(C)` façade — the sole public entry point. This is the
  existing file, which will be extended with the new API.
- **`src/network.f90`** → module `mNetwork`: the `Network` type owning an
  ordered collection of layers, plus the forward/backward and train driver.
- **`src/layer.f90`** → module `mLayer`: the `Layer` type — weights
  `W(n_out, n_in)`, biases `b(n_out)`, an activation, and an activation-kind
  integer tagging which activation it uses.
- **`src/activations.f90`** → module `mActivations`: an abstract `Activation`
  base with deferred `fn`/`deriv` bindings, and the concrete `Sigmoid`, `Tanh`,
  `ReLU`, `Softmax`, and `Linear` types **in the same module**, private; a
  single factory `new_activation(kind_code)` returns a
  `class(Activation), allocatable`.
- **`src/losses.f90`** → module `mLosses`: the same parallel pattern as
  `mActivations`; concrete `MSE`, `BinaryCrossEntropy`, and
  `CategoricalCrossEntropy`.
- **`src/optimizers.f90`** → module `mOptimizers`: an abstract `Optimizer` with
  a deferred `update` binding; concrete `SGD` for v1. Momentum and Adam are
  noted as future derivatives of the same base.

There are **no `include` / `*.fi` files** in this design — the human explicitly
rejected that mechanism in favor of modern Fortran modules.

There is deliberately **no `mPerceptron` module**. A `Layer` already bundles its
neurons together with per-layer weights, biases, and the loss/gradient
contribution, so a separate single-perceptron abstraction adds nothing the
layer does not already provide.

## 4. The two settled decisions

These two choices were nailed down first and shape everything else. Both are
recorded here so future sessions do not reopen them.

### 4.1 Opaque integer handles, not a module singleton

Public procedures take an `integer(c_int)` **handle** as their first argument.
The library maintains an internal mapping handle → allocated `Network`
instance, and `free_network(handle)` (publicly, `fnn_free_network`) releases
it. Reasons, retained for future sessions:

- **Thread-safety.** Mutable module-level state is a data race when the
  library is called concurrently; the FFI/OpenMP path (see Section 7) requires
  us to avoid it.
- **Multiple networks per process.** Handles let one process hold many
  independent networks at once.
- **Clean ownership semantics** that map cleanly onto `ctypes`/`c_void_p` and
  pointer-style C handles at the boundary.

### 4.2 Integer kinds (named constants), not character strings, for dispatch fields

Every dispatch-flavored parameter at the public surface — `optimizer`,
`activation`, `layer_type`, `loss` — is an `integer(c_int)` **named constant**
(Fortran 2008 has no `enum`). They map directly to `ctypes.c_int`, to a C
`enum`, and to plain integers from Python/numpy, and they sidestep the
NUL-termination and length-handling hazards of passing Fortran `character`
across the language boundary. Planned names:

```text
LAYER_DENSE   LAYER_OUTPUT
ACT_SIGMOID   ACT_TANH   ACT_RELU   ACT_SOFTMAX   ACT_LINEAR
OPT_SGD       (later: OPT_MOMENTUM, OPT_ADAM)
LOSS_MSE      LOSS_BINARY_CE   LOSS_CATEGORICAL_CE
```

Internally, an integer kind selects the right concrete instance exactly **once**
— at `add_layer` / the relevant `new_*` factory. After construction, ordinary
polymorphic type-bound procedures dispatch the work virtually; there is no
later `select case` on the kind on the hot path.

## 5. Public procedural façade (the `bind(C)` API)

The planned public procedures and their C-interoperable signatures, in a
`fortran` block below. These are **illustrative** — exact procedure names and
dummy-argument order may be fine-tuned at implementation time; the shapes,
types, and rules are the contract.

```fortran
integer(c_int) function fnn_new_network(optim, ierr) bind(C, name="fnn_new_network")
    !! Create an empty network with the given optimizer. Returns an opaque handle.
    integer(c_int), value :: optim   !! OPT_* kind code
    integer(c_int), intent(out) :: ierr  !! 0 on success, non-zero on error

subroutine fnn_free_network(handle) bind(C, name="fnn_free_network")
    !! Release a network handle and all storage it owns.
    integer(c_int), value :: handle  !! Handle from fnn_new_network / fnn_load_network

integer(c_int) function fnn_add_layer(handle, layer_type, n_neurons, &
                                      activation, seed, ierr) &
                                      bind(C, name="fnn_add_layer")
    integer(c_int), value :: handle       !! Target network
    integer(c_int), value :: layer_type   !! LAYER_DENSE / LAYER_OUTPUT
    integer(c_int), value :: n_neurons    !! Neuron count for this layer
    integer(c_int), value :: activation   !! ACT_* kind code
    integer(c_int), value :: seed         !! RNG seed for weight init
    integer(c_int), intent(out) :: ierr   !! 0 on success

integer(c_int) function fnn_train(handle, n_samples, n_in, n_out, &
                                  X, Y, epochs, learning_rate, loss, &
                                  batch_size, final_loss, ierr) &
                                  bind(C, name="fnn_train")
    integer(c_int), value :: handle
    integer(c_int), value :: n_samples  !! Number of training examples
    integer(c_int), value :: n_in       !! Input width
    integer(c_int), value :: n_out      !! Output width
    real(c_double), intent(in) :: X(n_in, n_samples)   !! Inputs, column-major
    real(c_double), intent(in) :: Y(n_out, n_samples)  !! Targets, column-major
    integer(c_int), value :: epochs
    real(c_double), value :: learning_rate
    integer(c_int), value :: loss        !! LOSS_* kind code
    integer(c_int), value :: batch_size  !! 0 => full-batch
    real(c_double), intent(out) :: final_loss
    integer(c_int), intent(out) :: ierr

integer(c_int) function fnn_predict(handle, n_in, n_out, x, y, ierr) &
                                     bind(C, name="fnn_predict")
    !! Single-example forward pass (for now).
    integer(c_int), value :: handle
    integer(c_int), value :: n_in, n_out
    real(c_double), intent(in) :: x(n_in)
    real(c_double), intent(out) :: y(n_out)
    integer(c_int), intent(out) :: ierr

integer(c_int) function fnn_save_network(handle, filename, ierr) &
                                        bind(C, name="fnn_save_network")
    integer(c_int), value :: handle
    character(kind=c_char, len=*), intent(in) :: filename
    integer(c_int), intent(out) :: ierr

integer(c_int) function fnn_load_network(filename, ierr) &
                                       bind(C, name="fnn_load_network")
    !! Read a persisted network, returning a valid handle.
    character(kind=c_char, len=*), intent(in) :: filename
    integer(c_int), intent(out) :: ierr

subroutine fnn_last_error(buffer, buffer_len) bind(C, name="fnn_last_error")
    !! Copy the human-readable message for the last non-zero ierr into a
    !! caller-supplied NUL-terminated buffer.
    character(kind=c_char), intent(out) :: buffer(*)
    integer(c_int), value :: buffer_len

subroutine fnn_version(buffer, buffer_len) bind(C, name="fnn_version")
    !! NUL-terminated library version string from the build-generated mVersion.
    character(kind=c_char), intent(out) :: buffer(*)
    integer(c_int), value :: buffer_len
```

Note in `fnn_train` that `X(n_in, n_samples)` and `Y(n_out, n_samples)` are
declared **explicit-shape**, not assumed-shape `(:)` — `bind(C)` forbids
assumed-shape array arguments.

### Why a status code out, not `error stop`

A fatal abort (`error stop`) inside the library would kill a hosting Python
interpreter or panic a C host process. So **every** public procedure returns an
`integer(c_int)`, `intent(out)` status code `ierr`, and the human-readable
message for the last non-zero `ierr` is fetched **lazily** via
`fnn_last_error`. This also keeps the I/O out of the library except through
explicitly documented procedures, per the style rules in `AGENTS.md`.

The specific error conditions the human explicitly required to be reported:

- A network handle that does not correspond to a live internal `Network`
  (missing/already-freed network).
- A network with **no output layer** at `train`, `predict`, or `save` time.

## 6. FFI design rules (Python & C/C++ compatibility)

Hard rules that all future façade code must follow (from the `AGENTS.md`
FFI/skill notes and this conversation):

- Public façade procedures use `bind(C, name="fnn_*")` — the symbol name is
  pinned explicitly so callers can rely on it regardless of the Fortran
  identifier.
- Only C-interoperable types appear on the boundary: `integer(c_int)`,
  `real(c_double)`, `character(kind=c_char, len=*)` (NUL-terminated),
  `type(c_ptr)` where genuinely needed, and plain derived types — which we
  mostly side-step by using integer handles instead.
- **Never** put on the public façade: `allocatable` results, `character(len=*)`
  results, polymorphic `class(...)`, abstract types, type-bound procedures, or
  Fortran assumed-shape `(:)` arrays.
- Arrays are **column-major**, matching NumPy `order="F"`. A caller in Python
  with an `ndarray(order="C")` must copy or transpose before passing; this must
  be documented in the binding docstrings.

## 7. OpenMP

OpenMP compatibility is **decided: supported**. The contract:

- All compute procedures in the `mLayer` / `mNetwork` forward and backward
  passes are `pure`; the optimizer update is a separate, side-effecting pass
  (the split prescribed in
  [`.github/skills/neural-networks/SKILL.md`](../../.github/skills/neural-networks/SKILL.md)).
- The opaque-handle design is precisely what makes the public façade safe to
  call from inside a parallel region — each thread holds a **distinct** handle.
  (This is a standing reason to never regress to a module singleton.)
- Per-thread RNG is seeded `random_init(seed + thread_num)` — an extension
  available with `gfortran` — so ensembles and hyperparameter sweeps get
  independent random streams.
- The OpenMP use-cases, ranked as discussed: **ensembles** (best payoff, do
  this first), **mini-batch data-parallel** (later), and **in-network `matmul`**
  left to BLAS internal threading to avoid oversubscription.

## 8. Vulkan / GPU (future idea — NOT in scope for v1)

The human intends to potentially write a Fortran→Vulkan GPU shim in the future.
For now this is recorded as a kept idea only, not implemented.

- The two-surface architecture is **already future-compatible**: swapping the
  compute backend later does **not** require any change to the public
  procedural façade.
- Concrete plan for when (if) it lands: introduce an internal `Backend`
  strategy abstraction that `Layer` and `Network` delegate their linear algebra
  to. A Vulkan backend would live in a thin C+Vulkan shared library exposing
  `bind(C)` procedures (e.g. `vnn_matmul(handle_in, handle_out, ...)`), keeping
  Fortran free of `vkCreate*` structures.
- Two precision notes, recorded for that later work — do **not** implement now:
  some GPUs lack `shaderFloat64`, and a `real64`-only API is an obstacle for
  that path, so the design should not *bake in* precision beyond the working
  `real64` default. Relatedly, parameter-array storage should sit behind an
  accessor rather than being poked as raw `self%weights(i, j)` everywhere, so a
  device-resident backing can replace it later. These are **not-urgent refactor
  targets**, not v1 work.
- For v1, use intrinsic `matmul` directly. (Stated explicitly because the human
  asked.)
- Realism note, recorded as stated: dense-MLP GPU speedups require large GEMMs;
  small training tasks are faster on the CPU.

## 9. Naming decisions summary

| Concept | Shape |
|---|---|
| Library entry point | `USE mFortranNeuralNetwork` only |
| Library version (existing) | `get_version()` (Fortran-native); `fnn_version(buf, len)` (FFI) |
| Network handle | `integer(c_int)` opaque identifier |
| Activations / losses / optimizers / layer kinds (public surface) | `integer(c_int)` named constants |
| Activation / loss / optimizer polymorphism (internally) | abstract base + concrete extensions in one module; selected once by `new_*` factory |
| Error signalling (public surface) | `intent(out)` `integer(c_int) ierr` + `fnn_last_error(buf, len)` |
| Persistence | `fnn_save_network` / `fnn_load_network`; plain text format, exact format defined at implementation time |
| Linear algebra (v1) | intrinsic `matmul`, no `Backend` abstraction yet |
| Precision (v1) | `real64` throughout |
| OpenMP | safe; module singleton is forbidden (handle-based) |
| Vulkan (v1) | out of scope |

## 10. Decisions deferred to implementation time

Things we intentionally did **not** resolve, so future sessions do not relitigate
them here:

- The exact training-data flow shape (flat row-major vs a column-major batch
  convention — leaning columns; decided at implementation).
- The persistence file format (plain text; the exact serialization is
  unspecified).
- Whether `predict` accepts a batch across the C boundary or only one example
  (decide after testing ergonomics; likely single-example for v1).
- Whether the façade is built on top of an internal `fnn_predict_batch`
  (probably needed for `train` regardless).
- Optimizer follow-ups — when to add momentum / Adam.

## 11. Out of scope for this design memory

Explicitly outside this document's concern (and outside v1): regularisation
(L2 / dropout), learning-rate schedules and warmup, convolutional layers,
recurrent layers, the *implementation* of gradient checking (the technique is
described in the skill but is not part of the public API), and the `Backend`
abstraction itself.
