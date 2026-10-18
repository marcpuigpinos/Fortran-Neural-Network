---
name: fortran
description: "Modern Fortran development knowledge and patterns. Use when: writing, reviewing, or debugging Fortran (.f90) code; designing modules, derived types, or APIs; numeric/scientific computing in Fortran; gfortran build flags, Makefile Fortran targets, FORD documentation; fixing Fortran errors (type mismatch, rank mismatch, pointer/allocatable bugs); refactoring legacy F77 to modern F2008+ idioms."
---

> **AI Generated**

# Modern Fortran

Domain knowledge for writing clean, safe, portable Fortran (F2008 baseline,
with notes on later standards), tuned for this project's toolchain
(`gfortran -std=f2008`, GNU make, FORD docs) but applicable to any modern
Fortran codebase.

## When to use

- Implementing or modifying `*.f90` sources, tests, or build scripts.
- Reviewing Fortran code for style, safety, or performance.
- Diagnosing gfortran compile/runtime errors.
- Refactoring fixed-form / F77 code to modern free-form idioms.
- Designing a Fortran library API (modules, derived types, generic interfaces).

## Core rules (always apply)

1. **Free-form source, `implicit none` everywhere.** Every scoping unit
   (module, procedure, internal procedure, interface body) declares
   `implicit none`. This catches the classic `do`/`i` typo and undeclared
   variables.
2. **Explicit `intent(...)` on every dummy argument.** Also `allocatable` /
   `pointer` / `optional` as appropriate.
3. **Kind parameters, never default-precision assumptions.** Use
   `iso_fortran_env` names (`real64`, `int32`, ...) or
   `selected_real_kind` / `selected_int_kind`. Write literals with kinds:
   `1.0_real64`, not `1.0d0` (non-standard) or bare `1.0`.
4. `allocatable` over `pointer` for ownership; **`move_alloc()`** to transfer;
   always pair `allocate` with `stat=` in library code where failure matters.
5. **Default accessibility `private`** in modules; export a minimal, explicit
   `public ::` list.
6. **Pure + elemental** for mathematical functions that qualify: enables
   compile-time evaluation, array promotion, and use in `impure`-free contexts.
7. **Array-oriented code** over explicit loops where clarity allows
   (`matmul`, `sum`, `where`, slices, broadcasting); keep memory layout
   column-major in mind (leftmost index contiguous).

## Procedure

1. Identify the task type and load the matching reference:
   - Language idioms, modules, OOP, strings, I/O →
     [references/language.md](./references/language.md)
   - Numerics, arrays, precision, performance, parallelism →
     [references/numeric.md](./references/numeric.md)
   - gfortran flags, Makefile patterns, FORD docs, testing →
     [references/toolchain.md](./references/toolchain.md)
   - Common compile/runtime errors, legacy → modern refactoring →
     [references/debugging.md](./references/debugging.md)
2. Start new files from the templates:
   - Library module: [assets/example_module.f90](./assets/example_module.f90)
   - Standalone test program: [assets/example_test.f90](./assets/example_test.f90)
3. Follow project conventions in `AGENTS.md` (this overrides general advice):
   `m` + `PascalCase` module names, `snake_case` procedures, 4-space indent,
   100-column limit, FORD `!!` doc blocks **below** the entity, `! AI Generated`
   marker at the top of every file.
4. Verify with the debug profile before declaring done: `make debug`
   (`-Wall -Wextra -fcheck=all`), then `make test`. Treat warnings as errors
   to fix.

## Quick anti-pattern table

| Avoid | Use instead |
|---|---|
| Implicit typing, `i-n` rule | `implicit none` in every scoping unit |
| `real*8`, `double precision` | `real(real64)` from `iso_fortran_env` |
| Function arguments without `intent` | Explicit `intent(in/out/inout)` |
| Bare `1.0` in `real64` math | `1.0_real64` (suffixed literals) |
| `==` on reals | Tolerance: `abs(a - b) <= tol` |
| `pointer` for owned data | `allocatable` (+ `move_alloc`) |
| `common` blocks | Modules with `private` state |
| `goto`-based control flow | Structured constructs; `cycle`/`exit` |
| Unformatted + assumed endianness I/O | `convert=` or stream + documented format |
| `equivalence`, Cray pointers | Modern derived types / C descriptors |

## Notes for this repository

- Library code must be I/O-free except through explicitly documented
  procedures; tests print `PASS <name>` / `FAIL <name> ...` and use
  `error stop 1` on failure.
- `make test` auto-discovers `tests/test*.f90`; never edit the Makefile to add
  a test.
