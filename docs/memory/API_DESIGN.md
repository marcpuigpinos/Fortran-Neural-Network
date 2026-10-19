> **AI Generated**

# Neural Network Library — API Design Memory

> **Pre-implementation design record.** This document captures an agreed
> architectural direction for the public API of the library. It targets no
> specific released version yet (`VERSION` is unchanged at 0.0.2); the
> implementation it describes will land in a later feature cycle.

This file records the architectural direction we agreed for the dense
(fully-connected) MLP library. It was **revised on 2026-10-19** from the design
conversation of **2026-10-18**; the revision **replaces** the earlier draft's
public-facing design and is now the source of truth. It is intentionally
self-contained so it can be re-attached as context in future sessions: when work
resumes, hand this document to the orchestrator as the source of truth and pick
up from the decisions recorded here, rather than re-deriving them from scratch.

**Why the direction changed.** The original draft was built around a flat
procedural `bind(C, name="fnn_*")` façade with opaque integer handles, chosen
to serve a C-ABI boundary reached from Python through `ctypes`. The human
rejected this: a C façade compromises the Fortran API (no derived types, no
type-bound procedures, explicit-shape arrays, NUL-terminated buffers) and
forces `ctypes` when `f2py`/`numpy.f2py` lets Python talk to Fortran natively
and cleanly. The new direction is a **modern object-oriented Fortran public
API** — a derived type is the public surface — designed so it is both (a)
idiomatic to call from Fortran and (b) wrappable by `f2py` for Python. All
`bind(C)`/`fnn_`/opaque-handle/`ctypes`/NUL-buffer material from the earlier
draft is dropped; where a concern (error signalling, dispatch kinds, Python
interop) survives, it is restated below in the new idiom. Throughout, the
working precision is `real64` (equivalent to `real(c_double)`), used as the v1
floating-point kind.

The mathematical foundations behind these shapes — losses, backpropagation,
activations, and the training loop — are **not** restated here; they live in
[`../NEURAL_NETWORK_THEORY.md`](../NEURAL_NETWORK_THEORY.md). The current,
already-implemented layout lives in [`../ARCHITECTURE.md`](../ARCHITECTURE.md).
Style, interop, and build conventions are governed by
[`../../AGENTS.md`](../../AGENTS.md). Implementation-side checklists and
correctness pairings (activation `fn`/`deriv`, loss/gradient, the paired-record
rule, gradient checking) are in
[`../../.github/skills/neural-networks/SKILL.md`](../../.github/skills/neural-networks/SKILL.md).
Language and `f2py`/interop notes are in
[`../../.github/skills/fortran/references/language.md`](../../.github/skills/fortran/references/language.md)
and
[`../../.github/skills/fortran/references/debugging.md`](../../.github/skills/fortran/references/debugging.md).

## 1. Scope

What is being designed here is the **public API surface** of a dense,
fully-connected feedforward (MLP) library, covering three concerns:

- **Forward inference** through a stack of layers,
- **Training**, with plain SGD as the first (and only v1) optimizer,
- **Persistence** — saving and loading a configured/trained network.

The public surface is the `Network` derived type, reached through the single
module a consumer `USE`s: `mFortranNeuralNetwork`, declared in
`src/fortranNeuralNetwork.f90`. Today that module is a thin shell exposing only
`get_version()` (see [`../ARCHITECTURE.md`](../ARCHITECTURE.md)). This design
extends it into a real network library — adding the `Network` type and its
supporting constants — without breaking the existing entry-point contract or
`get_version()`.

## 2. Public surface: a derived-type (OOP) API, no procedural façade

The framing principle is **rich polymorphic OOP inside, a single derived type
(`Network`) as the public surface**. The interior keeps the abstract-base +
concrete-derivative hierarchy (Activations / Losses / Optimizers) exactly as
before; what changes is the exterior — it is **not** a procedural C-style
façade. State belongs to the object; there is no module-level registry and no
opaque handle. A consumer constructs a `type(Network)` variable and calls
type-bound procedures on it:

```fortran
type(Network) :: net
integer :: ierr
call net%initialize(optimizer = OPT_SGD, ierr = ierr)
call net%add_layer(LAYER_DENSE, 16, ACT_TANH,    seed = 1, ierr = ierr)
call net%add_layer(LAYER_OUTPUT, 1,  ACT_SIGMOID, seed = 2, ierr = ierr)
call net%train(x, y, epochs, learning_rate, LOSS_MSE, batch_size, final_loss, ierr)
call net%predict(x1, yhat, ierr)
call net%save("model.txt", ierr)
```

There is **no `fnn_` prefix anywhere** on public procedures — that prefix
belonged to the C façade and is gone.

The invariants that carry over from the old design, restated for the new shape:

- `mFortranNeuralNetwork` is the **only** module a consumer ever `USE`s.
  Everything else is internal machinery reached through it.
- All concrete types, abstract bases, and the activation/loss/optimizer
  hierarchy stay **`private`**, re-exported only as far as needed: the `Network`
  type, the typed kind constants (§4.2), the factories used internally by
  `add_layer`/`initialize`, and `get_version()`. Type-bound procedures belong to
  `Network`; nothing else leaks a class or an abstract type across the boundary.

## 3. Module layout

The `src/` modules planned for the implementation (agreed file names; all use
the `.f90` free-form extension required by `AGENTS.md`):

- **`src/fortranNeuralNetwork.f90`** → module `mFortranNeuralNetwork`: the
  umbrella module consumers `USE`. It `USE`s the internal modules and re-exports
  the public `Network` type, the typed dispatch-kind constants (§4.2), the
  error-code constants and `error_message`, and `get_version`. There is no
  `bind(C)` here.
- **`src/network.f90`** → module `mNetwork`: the public `Network` type owning an
  ordered collection of layers, plus the type-bound `initialize`, `add_layer`,
  `train`, `predict`, `save`, `load`, and `last_error` procedures, and the
  forward/backward driver behind them.
- **`src/layer.f90`** → module `mLayer`: the `Layer` type — weights
  `W(n_out, n_in)`, biases `b(n_out)`, and an activation.
- **`src/activations.f90`** → module `mActivations`: an abstract `Activation`
  base with deferred `fn`/`deriv` bindings, and the concrete `Sigmoid`, `Tanh`,
  `ReLU`, `Softmax`, and `Linear` types **in the same module**, private; an
  internal factory selects the right instance exactly once from an
  `ActivationKind`.
- **`src/losses.f90`** → module `mLosses`: the same parallel pattern as
  `mActivations`; concrete `MSE`, `BinaryCrossEntropy`, and
  `CategoricalCrossEntropy`.
- **`src/optimizers.f90`** → module `mOptimizers`: an abstract `Optimizer` with
  a deferred `update` binding; concrete `SGD` for v1. Momentum and Adam are
  noted as future derivatives of the same base.
  - **Implemented 2026-10-19 (v0.1.0):** `mOptimizers` landed with the abstract
    `Optimizer` (deferred `update(self, weights, bias, d_weights, d_bias,
    learning_rate)`) and a concrete type named **`GradientDescent`** rather
    than `SGD`, per the human's note on `features/20261018_01_optimizer-gd.md`.
    The strategy is batch-agnostic (full-batch GD for whole-set gradients, SGD
    for mini-batch gradients), so the more precise name was chosen. The
    `OPT_SGD` kind constant and the rest of this document's references to "SGD"
    should be read as referring to this `GradientDescent` strategy. Momentum
    and Adam remain deferred (§11). The module is currently internal-only and
    not yet re-exported through `mFortranNeuralNetwork` (no `Network` type
    yet).

There are **no `include` / `*.fi` files** in this design — the human explicitly
rejected that mechanism in favor of modern Fortran modules. There is likewise
deliberately **no `mPerceptron` module**: a `Layer` already bundles its neurons
together with per-layer weights, biases, and the loss/gradient contribution, so
a separate single-perceptron abstraction adds nothing the layer does not already
provide.

## 4. Settled decisions

These choices were nailed down first and shape everything else. Both are
recorded here so future sessions do not reopen them.

### 4.1 The derived type as the state carrier (replaces opaque handles)

State and ownership live in the `Network` object. Multiple independent networks
are simply multiple `type(Network)` instances; thread-safety comes from each
thread owning its own `net` (see §8). The old draft reached the same end —
no shared mutable state — by way of opaque integer handles into an internal
registry; the new design reaches it more idiomatically, by making the object
itself the handle, so the registry disappears entirely.

The standing stance against a **module singleton** is retained but justified on
new grounds: not C-ABI mapping, but **thread-safety** (mutable module-level
state is a data race when the library is called concurrently) and
**idiomatic-modern-Fortran ergonomics** (a caller already holding a `net` does
not need a global store). Module-level mutable state remains forbidden.

On the Python side, `f2py` creates and owns the object; wrapping type-bound
procedures so Python can hold and mutate it needs care, recorded honestly in
§7.

### 4.2 Typed integer-backed enum constants for dispatch fields — typed derived types, not bare integers

Every dispatch-flavored field — `optimizer`, `activation`, `layer`, `loss` — is
a **typed constant**, not a bare integer and not a string. The two-part
rationale the human chose:

- A misspelled name (`OTP_SGD` for `OPT_SGD`) **fails to resolve at compile
  time**, because there is no such named entity. A string literal would compile
  happily and fail only at runtime — this compile-time-vs-runtime failure mode
  was the deciding argument (compare §4.2 of the old string-vs-int reasoning,
  now flipped in favor of typed constants).
- Giving **each category its own derived type** prevents mixing families: with
  bare integers for everything, `ACT_SIGMOID` could be passed into a `loss` slot
  and compile. Separate types make that a type error.

So define one lightweight derived type per category, each wrapping a single
integer code, with `UPPER_SNAKE` named constants:

```fortran
type :: ActivationKind ; integer :: code ; end type ActivationKind
type(ActivationKind), parameter :: ACT_SIGMOID = ActivationKind(1)
type(ActivationKind), parameter :: ACT_TANH    = ActivationKind(2)
type(ActivationKind), parameter :: ACT_RELU    = ActivationKind(3)
type(ActivationKind), parameter :: ACT_SOFTMAX = ActivationKind(4)
type(ActivationKind), parameter :: ACT_LINEAR  = ActivationKind(5)
```

and analogously `LayerKind` (`LAYER_DENSE`, `LAYER_OUTPUT`), `OptimizerKind`
(`OPT_SGD`; later `MOMENTUM`, `ADAM`), and `LossKind` (`LOSS_MSE`,
`LOSS_BINARY_CE`, `LOSS_CATEGORICAL_CE`). Codes start at **1**, with **0
reserved as unset/invalid**.

Internally, each kind selects the right concrete instance exactly **once** — at
`add_layer` / `initialize` via the internal factory. After construction,
ordinary polymorphic type-bound procedures dispatch the work virtually; there is
no `select case` on the kind on the hot path.

These typed kind constants are also what `f2py` re-exports as module
`parameter`s, so a Python user can write `mod.ACT_TANH` rather than a magic
number (§7). The names keep a documented **`UPPER_SNAKE` enum-like convention**,
a deliberate exception to the `snake_case` procedure/variable rule in `AGENTS.md`
— recorded explicitly so a future reviewer treats it as intentional rather than
a style violation.

## 5. Public OOP API (illustrative type-bound signatures)

The planned public procedures, as type-bound procedures on `Network`, in a
`fortran` block below. Names are exactly as the human wants them — **no
`fnn_` prefix, no handles**. These are **illustrative**: the exact
dummy-argument order may be fine-tuned at implementation time, but the shapes,
types, and the absence of handles/`fnn_` are the contract.

```fortran
subroutine initialize(self, optimizer, ierr)
    !! Construct an empty network with the given optimizer.
    class(Network), intent(inout) :: self
    type(OptimizerKind), intent(in) :: optimizer  !! OPT_* kind constant
    integer, intent(out) :: ierr                  !! 0 on success, non-zero on error

subroutine add_layer(self, layer, n_neurons, activation, seed, ierr)
    !! Append a layer to the network.
    class(Network), intent(inout) :: self
    type(LayerKind), intent(in) :: layer           !! LAYER_DENSE / LAYER_OUTPUT
    integer, intent(in) :: n_neurons               !! Neuron count for this layer
    type(ActivationKind), intent(in) :: activation !! ACT_* kind constant
    integer, intent(in) :: seed                    !! RNG seed for weight init
    integer, intent(out) :: ierr

subroutine train(self, x, y, epochs, learning_rate, loss, batch_size, &
                 final_loss, ierr)
    !! Train the network with mini-batch (or full-batch) SGD.
    class(Network), intent(inout) :: self
    real(real64), intent(in) :: x(:,:)        !! Input batch, column-major
    real(real64), intent(in) :: y(:,:)        !! Target batch, column-major
    integer, intent(in) :: epochs
    real(real64), intent(in) :: learning_rate
    type(LossKind), intent(in) :: loss        !! LOSS_* kind constant
    integer, intent(in) :: batch_size         !! 0 => full-batch
    real(real64), intent(out) :: final_loss
    integer, intent(out) :: ierr

subroutine predict(self, x, y, ierr)
    !! Single-example forward inference.
    class(Network), intent(inout) :: self
    real(real64), intent(in) :: x(:)   !! One input example
    real(real64), intent(out) :: y(:)  !! One output example
    integer, intent(out) :: ierr

subroutine save(self, filename, ierr)
    !! Persist the configured/trained network to `filename`.
    class(Network), intent(inout) :: self
    character(len=*), intent(in) :: filename  !! Plain Fortran filename
    integer, intent(out) :: ierr

subroutine load(self, filename, ierr)
    !! Read a persisted network into `self`.
    class(Network), intent(inout) :: self
    character(len=*), intent(in) :: filename  !! Plain Fortran filename
    integer, intent(out) :: ierr

subroutine last_error(self, code, message)
    !! Retrieve the last error recorded on this network.
    class(Network), intent(in) :: self
    integer, intent(out) :: code              !! Numeric status of the last error
    character(len=:), allocatable, intent(out) :: message  !! Rich, dynamic message

pure function error_message(code) result(message)
    !! Baseline static description for any status code (stateless).
    integer, intent(in) :: code
    character(len=:), allocatable :: message

function get_version() result(version)
    !! Current library version string (the existing allocatable-result
    !! function, RETAINED as the version API — f2py handles an allocatable
    !! character result natively).
    character(len=:), allocatable :: version
```

Notes carrying over from the revision:

- In `train`, `x(:,:)` and `y(:,:)` are **assumed-shape** (`(:,:)`), now allowed
  freely; the explicit-shape `X(n_in, n_samples)` form that the old draft used
  existed only because `bind(C)` forbids assumed-shape array arguments — that
  hack is gone.
- `save` / `load` take a normal Fortran `character(len=*)` filename; there are
  no NUL-terminated `c_char` buffers. The persistence format is deferred
  (§11).
- `get_version()` keeps its existing allocatable-character result.

## 6. Error model — the "A + B" blend

The old "status code + caller buffer" idiom is replaced by a blend of two
mechanisms, both of which survive:

- **Every fallible procedure carries `integer, intent(out) :: ierr`** —
  mandatory on the fallible operations (`initialize`, `add_layer`, `train`,
  `predict`, `save`, `load`), and `optional` on pure/compute procedures where
  that is reasonable, at implementation discretion (which ones, deferred to
  §11).
- **Option A — stateless baseline.** `ierr` is a numeric status code, and the
  **pure** module function `error_message(code)` maps any code to its baseline
  static description. A code is therefore always independently interpretable
  without holding any object.
- **Option B — object-attached detail.** A stateful procedure ALSO records a
  richer, dynamic, per-`Network` message, retrievable via
  `net%last_error(code, message)`. Keeping the detail on the object the caller
  already holds means two threads on two different networks never race over a
  shared "last error" slot.

Error codes are named integer constants, using the same `UPPER_SNAKE` enum-like
convention as §4.2 (e.g. `ERR_NONE = 0`, `ERR_NO_LAYERS`, `ERR_NO_OUTPUT_LAYER`,
`ERR_SHAPE_MISMATCH`, `ERR_INVALID_KIND`, `ERR_IO`, `ERR_NOT_INITIALIZED`).

`error stop` remains **forbidden** inside the library — it would kill a hosting
Python interpreter — so status codes are the signalling mechanism. But the old
caller-buffer (`buffer(*)` / `buffer_len`) idiom is **gone**: Fortran returns
allocatable strings directly.

Retained / dropped error conditions from the old required list:

- **Dropped:** "bad handle" — there are no handles any more.
- **Retained:** a network with **no layers** or **no output layer** at
  `train`/`predict`/`save` time; shape mismatch between data and layer widths;
  file I/O failure; and — because Python can pass an out-of-range integer for a
  dispatch field — a **runtime invalid-kind** check (`ERR_INVALID_KIND`).

## 7. f2py / Python compatibility rules

There is no C-ABI boundary any more; `f2py`/`numpy.f2py` reads Fortran module
metadata directly. The rules:

- **No `bind(C)`** and **no pinned symbol names**; `iso_c_binding` and `ctypes`
  are **not** used.
- Use **assumed-shape** arrays (`(:)`, `(:,:)`) freely; `f2py` maps NumPy arrays
  to them (no copy when contiguous). Provide an explicit
  `intent(in/out/inout)` on **every** dummy — `f2py` needs these and allocates
  `intent(out)` arrays for the caller.
- Dispatch values are the typed kind constants of §4.2; `f2py` re-exports module
  `parameter`s, so a Python user writes `mod.ACT_TANH` rather than a magic
  number.
- **Column-major / Fortran order** for the 2-D batch arrays: this matches NumPy
  `order="F"`; a row-major `ndarray` must be `np.asfortranarray`'d (or
  transposed) before passing. Document this in the binding.
- **Honest limitation** (recorded so it is not rediscovered the hard way):
  `f2py` wraps numeric arrays and **simple** derived types well, but does **not**
  cleanly wrap (a) polymorphic `class(...)` dummy arguments, (b) abstract types
  with deferred binding, or (c) a type-bound-procedure API where Python holds
  and mutates a derived-type object whose components are allocatable/polymorphic
  — and `Network` will hold an allocatable array of `class(Layer)`, each
  carrying a polymorphic activation. Therefore:
  1. **All polymorphism (`class(Activation)`, `class(Loss)`,
     `class(Optimizer)`) stays strictly internal.** Public procedures deal only
     in `type(Network)`, scalars, plain numeric arrays, and the integer-backed
     kind codes.
  2. Making the type-bound procedures callable from Python is a
     **bounding/implementation-time task**: a thin module-procedure forwarding
     layer (free procedures that take `type(Network)` and forward to the
     type-bound ones) and/or `f2py` signature / `pymod` customisation. **That
     layer is for Python only** — it does not change the Fortran-first OOP
     public surface. The Fortran OOP API is primary; the `f2py` path is the
     supported second surface.
- `pure`, module-state-free compute procedures remain `f2py`-friendly and
  thread-safe.

## 8. OpenMP

OpenMP compatibility is **decided: supported**, now justified on per-object
state rather than the C boundary:

- It is precisely the **per-object state** of §4.1 that makes the API safe
  inside a parallel region — each thread owns its own `Network`, with no shared
  mutable module state. The module singleton stays forbidden.
- Compute forward/backward procedures are `pure`; the optimizer update is a
  separate, side-effecting pass (the split prescribed in
  [`.github/skills/neural-networks/SKILL.md`](../../.github/skills/neural-networks/SKILL.md)).
- Per-thread RNG is seeded `random_init(seed + thread_num)` — an extension
  available with `gfortran` — so ensembles and hyperparameter sweeps get
  independent random streams.
- The `matmul` left in §10 is delegated to BLAS internal threading; do not add
  our own OpenMP around it and oversubscribe.
- The OpenMP use-cases, ranked: **ensembles** (best payoff, do this first),
  **mini-batch data-parallel** (later), and **in-network `matmul`** left to
  BLAS.

## 9. Vulkan / GPU (future idea — NOT in scope for v1)

The human intends to potentially write a Fortran→Vulkan GPU shim in the future.
For now this is recorded as a kept idea only, not implemented.

- The architecture is **already future-compatible**: the `Backend` strategy
  abstraction sits **inside** `Layer`/`Network`, so swapping the compute backend
  later does **not** change the public `Network` API.
- Plan for when (if) it lands: introduce an internal `Backend` strategy that
  `Layer` and `Network` delegate their linear algebra to. A Vulkan backend would
  be a thin C+Vulkan shared library that itself uses `bind(C)` — but note that
  is about the **Vulkan library being C-callable**, which is unrelated to the
  user-facing Fortran API (§2 has no `bind(C)` at all).
- Precision notes for that later work — do **not** implement now: some GPUs lack
  `shaderFloat64`, and a `real64`-only API is an obstacle there, so the design
  must not **bake in** precision beyond the working `real64` default. Relatedly,
  parameter-array storage should sit behind an accessor rather than being poked
  as raw `self%weights(i, j)` everywhere, so a device-resident backing can
  replace it later. These are **not-urgent refactor targets**, not v1 work.
- For v1, use intrinsic `matmul` directly. (Stated explicitly because the human
  asked.)
- Realism note, recorded as stated: dense-MLP GPU speedups require large GEMMs;
  small training tasks are faster on the CPU.

## 10. Naming decisions summary

| Concept | Shape |
|---|---|
| Library entry point | `USE mFortranNeuralNetwork` only |
| Version | `get_version()` (allocatable-result function; `f2py`-friendly) — **no** buffer / `fnn_version` |
| Network state | `type(Network)` object — **no** handle, **no** registry |
| Activations / losses / optimizers / layer kinds | integer-backed typed enum derived types (`ActivationKind`, etc.) with `UPPER_SNAKE` named constants |
| Polymorphism | abstract base + concrete extensions in one private module; **internal only**, never crosses a public procedure |
| Public procedures | type-bound on `Network`, **no** `fnn_` prefix: `net%initialize`, `net%add_layer`, `net%train`, `net%predict`, `net%save`, `net%load`, `net%last_error` |
| Error signalling | `ierr` (integer, mandatory on fallible ops) + pure `error_message(code)` + per-object `net%last_error(code, message)`; **no** caller buffer |
| Python binding | `f2py` (no `ctypes`, no `bind(C)`); thin module-procedure shim if needed; arrays column-major |
| Persistence | `net%save` / `net%load`, plain Fortran filenames; exact format deferred |
| Linear algebra (v1) | intrinsic `matmul`, no `Backend` yet |
| Precision (v1) | `real64` throughout |
| OpenMP | safe; module singleton forbidden (per-object state) |
| Vulkan (v1) | out of scope |

## 11. Decisions deferred to implementation time

Things we intentionally did **not** resolve, so future sessions do not relitigate
them here:

- The persistence file format (plain text; the exact serialization is deferred).
- The exact batch data layout for `train` (column-major assumed-shape is the
  lean; finalize at implementation).
- Whether `predict` / a public `forward` accepts a **batch** in v1 or only a
  single example.
- The `f2py` binding mechanism for the type-bound procedures (module-procedure
  shim vs `f2py` signature / `pymod`) — decided at binding-implementation time.
- On which pure procedures `ierr` is `optional`.
- Optimizer follow-ups — when to add momentum / Adam.

## 12. Out of scope for this design memory

Explicitly outside this document's concern (and outside v1): regularisation
(L2 / dropout), learning-rate schedules and warmup, convolutional layers,
recurrent layers, the *implementation* of gradient checking (the technique is
described in the skill but is not part of the public API), and the `Backend`
abstraction itself.
