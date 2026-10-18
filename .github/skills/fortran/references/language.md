> **AI Generated**

# Fortran Language Idioms (Modern, F2008+)

Deep reference for language-level constructs. All examples are free-form
F2008-compatible unless marked otherwise.

## 1. Modules and encapsulation

- One module per file. A module is the only unit of separate compilation with
  type safety: `use` it, never `include` source.
- Start every module with `private`, then a single `public ::` list. Types,
  constants, and procedures not in the list stay internal.
- `use, intrinsic ::` for standard modules (`iso_fortran_env`, `iso_c_binding`)
  marks them as intrinsic and is F2008-clean.
- Restrict imports at the use site too: `use mFoo, only: bar` prevents
  namespace pollution and documents dependencies (the build system may parse
  `use` lines for dependency discovery).
- Module variables: keep them `private`; expose accessors if needed. Avoid
  mutable module state — it breaks thread-safety (OpenMP) and re-entrancy.

```fortran
module mExample
    use, intrinsic :: iso_fortran_env, only: real64
    implicit none
    private
    public :: Example, make_example
contains
    ...
end module mExample
```

## 2. Derived types as "classes"

- Components private by default via module `private`; document public ones.
- Add a boundary-check constructor function (`init` pattern) so invariants are
  enforced in one place.
- Type-bound procedures use `procedure :: name => type_proc` with the binding
  in the type and the implementation in the same module (external `module
  procedure` requires an interface body; keep it simple).
- `class(type)` for the `self` argument enables polymorphism; `type(type)` is
  fine (and slightly clearer + optimizable) when no polymorphism is needed.
- `final ::` finalizers free resources deterministically on scope exit for
  local variables and on explicit `deallocate` — not for `move_alloc` targets
  or assignment of the parent object.
- Abstract types + `extends` + deferred procedures = strategy/polymorphism;
  store polymorphic components as `class(base), allocatable`.

```fortran
type, public :: Layer
    real(real64), allocatable :: w(:,:)   !! Weights (out x in)
contains
    procedure :: forward => layer_forward
end type Layer

pure function layer_forward(self, x) result(y)
    class(Layer), intent(in) :: self
    real(real64), intent(in) :: x(:)
    real(real64) :: y(size(self%w, 1))
    y = matmul(self%w, x)
end function layer_forward
```

## 3. Procedures

- `pure` = no I/O, no global state mutation; allows compiler reordering,
  use in OpenMP work-sharing, and constant expressions. `elemental` = pure +
  scalar-conforming arguments, auto-promotes over arrays. A procedure can only
  be `elemental` if it is `pure`.
- Limitations to know: elemental functions must be recursive-capable in F2018
  for some uses; gfortran in F2008 mode forbids recursion in `pure` functions.
- `result(...)` clause: always use it when the function name would shadow a
  used symbol, or for clarity; required for character functions with
  `allocatable` results.
- Character return values: prefer `character(len=:), allocatable` result —
  exact length, no truncation gotchas of `character(len=*)` dummies.
  Assigning to it allocates automatically.
- Optional dummies: gate every use with `if (present(x))`, give safe defaults
  at the top (`xval = 0.0_real64; if (present(x)) xval = x`).
- `only:` interface blocks for procedure-pointer arguments when an interface
  is needed (avoid bare `external`).
- Generic interfaces (`interface name ... module procedure a, b ... end
  interface`) for kind- or type-overloaded APIs; prefer over `select type` at
  call sites where possible.

## 4. Arrays

- Fortran arrays are column-major: leftmost subscript is contiguous. Loop
  inner-most index over the leftmost dimension; store matrices so that the
  traversed order is contiguous.
- Explicit-shape dummy arguments (`real(real64) :: a(n, m)`) or assumed-shape
  (`a(:,:)`) — assumed-shape requires an explicit interface (module procedure
  or interface block) and enables bounds checks and vectorization.
- Assumed-size `a(*)` / `a(*)` forms: legacy only, avoid — no bounds info.
- Array constructor `[ ... ]` / `[real(real64) :: ... ]`. Use `spread`,
  `reshape`, `transpose` rather than manual reindexing.
- Slicing creates views when contiguous; otherwise the compiler copies.
  `y = matmul(A, x)` on a slab `A(:, j)` may copy — acceptable, but matter
  to know when profiling.
- `where` / `elsewhere` for conditional element assignment; `count`, `pack`,
  `unpack`, `any`, `all`, `maxloc`, `minloc`, `findloc` replace hand-rolled
  loops.
- Allocatable components of derived types and allocatable arrays of derived
  types are F2003+/F2008-fine and the idiomatic container. Automatic
  deallocation at scope exit (for allocatables) prevents most leaks.

## 5. Strings and I/O

- Fixed-length `character(len=n)` pads and compares with trailing blanks
  (`'ab' == 'ab   '` is true!). Prefer `character(len=:), allocatable` for
  dynamic strings; `trim`/`adjustl` when comparing fixed-length values;
  `len_trim` for meaningful length.
- Concatenation `//` allocates a new string: in loops this is O(n^2). Prefer
  writing to a buffered character variable or accumulating in chunks.
- Internal files: `write(str, '(...)')` and `read(str, '(...)')` for
  formatting/parsing without disk I/O.
- Files: `open(newunit=unit, ...)` always — never hard-coded unit numbers
  (collision and thread-safety bugs). `close(unit)` when done;
  `ioStat=`/`ioMsg=` for recoverable errors; `is_iostat_end`/`is_iostat_eor`
  to test status.
- `error stop` (F2008) terminates with nonzero exit status — the right
  failure signal in tests; plain `stop` may return success.

## 6. Select type / polymorphism dispatch

```fortran
select type (obj)
type is (LayerDense)
    ...
class is (LayerBase)
    ...
class default
    error stop 'unknown layer type'
end select
```

- Prefer virtual dispatch (type-bound procedures) over `select type`.
- `same_type_as` / `extends_type_of` for type queries as an expression.

## 7. Interop and binding (summary)

- `bind(C)` + `iso_c_binding` types for any symbol crossing the Fortran/C
  boundary; `intent` still applies; `value` attribute for by-value scalars.
- Fortran-name mangling: gfortran usually lowercases and appends `_` —
  `bind(C, name='...')` pins the symbol.
- From Python: prefer `iso_c_binding` + `ctypes`, or generate wrappers with
  `f2py`/`numpy.f2py` (f2py handles arrays and optional args natively).

## 8. Concurrency safety notes

- `pure` procedures are safe to call from OpenMP parallel regions.
- Mutable module state is a data race; if unavoidable, protect with
  `atomic` (F2008 coarray) or OpenMP critical sections.
- `random_number` state is per-thread with `random_init` (F2008/
  gfortran extension support); seed each thread with a distinct stream.

## Sources

- Fortran Best Practices: https://fortran-lang.org/learn/best_practices/
- Metcalf, Reid, Cohen, Bader, "Modern Fortran Explained", 6th ed. (Oxford).
- Curcic, "Modern Fortran: Building Efficient Parallel Applications" (Manning).
- gfortran intrinsics reference: https://gcc.gnu.org/onlinedocs/gfortran/
