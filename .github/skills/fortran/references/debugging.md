> **AI Generated**

# Debugging & Legacy-to-Modern Refactoring in Fortran

Reference for diagnosing gfortran errors and modernizing old Fortran.

## 1. High-frequency compile errors

| Message (gfortran) | Usual cause | Fix |
|---|---|---|
| `'x' at (1) is invalid as a name of a function` | using a variable/array name that is also an intrinsic (`sum`, `max`, `size` as variables) | Qualify intrinsic calls or rename; `use ..., intrinsic ::` |
| `Type mismatch in argument 'a' ... real(4)/real(8)` | kind mismatch at call site | Suffix literals, `real(x, real64)`; ensure consistent `real64` |
| `Rank mismatch in argument ... (1/2)` | passing array of wrong rank | Slice properly `A(:, j)` to drop rank; `reshape` |
| `Shape mismatch ... (3)/(3,1)` | constructor shape vs target | Match `reshape(..., shape=[...])` |
| `Explicit interface missing for call to 'p'` | external procedure with array/optional/allocatable args, or `intent` ignored | Put procedure in a module (preferred) or add interface block |
| `'allocatable' attribute at (1) conflicts with 'pointer'` | both attributes on one object | Pick one (`allocatable` preferred) |
| `Derived type 't' is not yet defined` | ordering in file / missing `use` | Reorder types, break cycles with deferred (`class(t), pointer/allocatable`) components |
| `More actual than formal arguments` | old-style arg-count mismatch / trailing comma turned args into extra | Remove stray commas — **a comma turns list items into a single array constructor in some contexts** |
| `Symbol 'x' also declared as a type` | variable and derived type share a name modulo case (`Layer` type vs `layer` variable — Fortran ignores case) | Rename the variable or the type; they must differ ignoring case |
| `Interface mismatch ... dummy argument` between generic bindings | type-bound procedures with same binding name but incompatible signature | Keep `self` consistent; use `pass`/`nopass` correctly |
| `Missing ... in 'result'` | function returns without assignment | Assign result name, or `return` early with value set |

## 2. Runtime errors and floating diagnostics

- "index out of bounds" → recompile with `-fcheck=bounds` (or `-fcheck=all`)
  and locate via `-fbacktrace`.
- Misplaced comma in argument calls: `call f(a, b,) ` / `open(10, file='x',)`
  — historically `f(a)(b) == f(a, b)` if `f` is CHARACTER-subscript: comma vs.
  parentheses ambiguity (`f(i)(j)` is array-of-character indexing; a missing
  comma = wrong element or type error).
- Uninitialized reads: use `-finit-real=snan`, `-finit-integer=-99999`,
  `-finit-logical=.false.` in debug: traps silent use-before-set.
- Segfaults at boundary interop: check missing `bind(C)`, wrong assumed-shape
  (`(*), target` vs `c_ptr`), missing `target` for `c_loc`.
- Backtrace env: `export FOR_DISABLE_COREDUMP=1` to force message-only;
  `GFORTRAN_UNBUFFERED_PRECONNECTED=y` to interleave with stdout.
- Reproduce with ASan: `gfortran -g -fsanitize=address,undefined` — catches
  allocatable misuse, dangling pointers after `move_alloc`.
- "Allocation would fail" `stat=`: query `allocated()`, print sizes before
  failing; check intent — writing to an unallocated `intent(out) allocatable`
  dummy is fine (assignment allocates it), reading is not.
- NaNs: run with `-ffpe-trap=invalid,zero,overflow` + `-fbacktrace` to stop at
  the first offending operation and read the frame.

## 3. Legacy → modern refactor recipes

Common conversions with rationale (also improves checkability/perf):

- `COMMON` blocks → module with `private` state + accessors. Keeps types with
  the data; enables separate compilation safety.
- `EQUIVALENCE` → distinct variables, or a single `transfer`-based
  reinterpretation helper (documented), or Fortran 2008+ union via
  `bind(C)`/c10-style.
- Character-based flags and magic numbers → `integer, parameter` named
  constants or enumerations via derived-type wrappers or `enum` patterns.
- `DIMENSION a(100)` + `DATA` → explicit-initialized allocatable:
  `real(real64), allocatable :: a(:)`; `a = [ ... ]`.
- F77 implicit typing with the `i-n` rule → `implicit none` first, then let
  compiler enumerate undeclared names.
- `GO TO` → structured `if`/`do`; `DO label ... label CONTINUE` →
  `do ... end do`; loop-exit tests at bottom → `exit` + `if` at top
  (guard-first).
- Hollerith and FORMAT statements → list-directed or formatted writes to
  internal strings.
- Real `==` comparisons → tolerance (`tol` per kind, as in
  [numeric.md](./numeric.md)).
- Unformatted records without `convert` → stream access + endianness
    conversion (`convert=' little_endian'`), or documented network format.
- `INTEGER*4`, `REAL*8` → `integer(int32)`, `real(real64)`.
- `EXTERNAL` + `CALL sub(arg)` where `arg` is array → module subprogram so
  array descriptors carry bounds; remove hand-passed `n` where `size(a)` works
  (keep `n` only if it is a "use the first n" logical size, distinct from
  `size(a)` — and say so in the name).

## 4. Interoperability gotchas

- C `int` ≠ Fortran default `integer` sizes: use `integer(c_int)` /
  `integer(c_size_t)` when binding.
- Fortran character is not NUL-terminated; bridge with `iso_c_binding`
  `c_f_pointer` over `character(kind=c_char)` arrays ending with `c_null_char`.
- Optional arguments have C ABI quirks (gfortran passes `NULL` pointer for
  absent optional) — only safe across the boundary via documented C wrappers.
- Name mangling: module procedures are mangled (`__mmod_MOD_proc`);
  `bind(C,name='...')` pins names.
- Python/`ctypes`: arrays pass as contiguous C pointers — ensure
  column-major expectations or call `numpy.asfortranarray`.
- `numpy.f2py` builds wrappers automatically, but `intent(inout)` vs
  `intent(out)` semantics matter for array allocation; annotate with f2py
  directives sparingly.

## 5. Debugging workflow that works

1. Reproduce in a debug build: `-g -fcheck=all -fbacktrace` + add
   `-fsanitize=address,undefined` and/or `-ffpe-trap=...` (each run narrows
   the bug class).
2. Minimize: strip to the smallest input + module that still fails; Fortran
   bugs often vanish when the test shrinks, which localizes them.
3. Instrument: `print *`, unit number + snapshot of indices; prefer
   `write(*,'(a,...)')` to keep format visible.
4. Binary-search history with `git bisect` (build/test must be fast in debug).
5. Fix the rule that let it happen (add `implicit none`, `intent`, bounds
   check, kind suffix...) so it cannot recur.

## Sources

- gfortran error messages and options: https://gcc.gnu.org/onlinedocs/gfortran/
- fort wiki / debugging threads: https://fortran-lang.discourse.group/
- "Modern Fortran Explained" ch. 1–4 (legacy constructs) and interop chapters.
