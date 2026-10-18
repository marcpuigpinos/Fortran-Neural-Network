> **AI Generated**

# Fortran Toolchain: gfortran, Make, FORD, Testing

Reference for building, checking, documenting, and testing Fortran — matching
this repository's setup and generalizable elsewhere.

## 1. gfortran flags that matter

| Flag | Purpose |
|---|---|
| `-std=f2008` (or `gnu`, `f2018`) | Lock the standard; `gnu` allows extensions — CI with `f2008` |
| `-Wall -Wextra` | Real diagnostics: unused vars, interface mismatches in call to implicit externals, etc. |
| `-g -fcheck=all` | Debug build: bounds, temporaries, contract (assert), recursion checks |
| `-fbacktrace` | Stack trace on runtime crash (pairs with `-g`) |
| `-ffpe-trap=invalid,zero,overflow` | SIGFPE on FP exceptions in debug runs |
| `-fbounds-check` | Included in `-fcheck=all`; never rely on it in release perf paths |
| `-J <dir>` / `-I <dir>` | Where `.mod` files are written / read. Per-build-dir to keep profiles separated |
| `-c` then link | Compile once per module; link `.o` lists. Order does not matter for modern linkers, but `.mod` consumption does: compile dependencies first |
| `-O2` / `-O3` | `-O3` rarely beats `-O2` for numeric loops; measure |
| `-ffast-math` | Dangerous: enables reassociation; only with explicit numerical sign-off |
| `-fopenmp` | OpenMP support; link same flag |
| `-ffp-contract=off` | Deterministic FP for regression tests |
| `-Wl,--warn-common`, `-static` | as needed |

Classic build recipe used by this repo (see `Makefile`):

```make
$(BUILD)/debug/%.o: src/%.f90 | $(BUILD)/debug
	gfortran -std=f2008 -g -fcheck=all -Wall -Wextra -I $(@D) -J $(@D) -c $< -o $@
```

Key subtleties:

- **`.mod` ordering.** A module's `.mod` must exist before any file that
  `use`s it compiles. Either list dependencies explicitly or parse `use`
  statements (this Makefile parses with awk, lowercasing names — Fortran is
  case-insensitive).
- **Separate build dirs** per profile (`build/debug`, `build/release`) so
  `.mod`/`.o` of different flag sets never mix (mixing = ABI confusion).
- Case-insensitive filesystems collide when two modules differ only in case.

## 2. Minimal portable alternatives

For new projects, consider **CMake** (with `enable_language(Fortran)` +
`set(CMAKE_Fortran_MODULE_DIRECTORY ...)`) or **fpm**
(https://fpm.fortran-lang.org — manifest + automatic module dependency
tracking; Fortran-lang package manager). fpm layout: `src/<pkg>/`,
`test/<name>/test_name.f90`, `fpm.toml`. Keep the choice aligned with
project conventions (`AGENTS.md` here mandates GNU make).

## 3. FORD documentation style (used project-wide)

- Doc block goes **immediately below** the entity; dummy args/components use a
  **trailing** `!!`. `===` opens extended prose, `== Heading` subsections.
- Metadata `@author`, `@version`, `@license` in the top module block; keep
  `@version` in sync with `VERSION` (this repo generates it at build time via
  `ford.md.in` + `sed`).
- Template:

```fortran
module mExample
    !! One-line summary of the module.
    !!
    !! Longer description here.
    !!
    !! @author Project name
    !! @version X.Y.Z
    !! @license MIT
    implicit none
    private
    public :: do_thing

contains

    pure function do_thing(x) result(y)
        !! One-line summary of the procedure.
        real(kind=8), intent(in) :: x  !! Input value
        real(kind=8) :: y              !! Output value, 2*x
        y = 2.0_real64 * x
    end function do_thing

end module mExample
```

- Rebuild: `make docs` (rendered from FORD config; output under
  `build/docs/`). Run it only when finalizing — FORD parses all sources.

## 4. Testing conventions (free programs, no framework)

- One standalone program per file, named after its file
  (`program testThing`); `error stop 1` on failure; single summary line
  `PASS <name>` / `FAIL <name> [why...]`. Discoverable via `tests/test*.f90`.
- Link against the **debug** library build so runtime checks (`-fcheck=all`)
  active during tests.
- Compare numbers with documented tolerance; on mismatch print got vs. want:

```fortran
if (abs(got - want) > tol) then
    print '(A,1X,A,1X,A,ES15.6,1X,A,ES15.6)', 'FAIL', test_name, &
        'got', got, 'want', want
    error stop 1
end if
print '(A,1X,A)', 'PASS', test_name
```

- `newunit=` for all I/O in tests; exit code is the contract (`make test`
  stops on first failure).
- Optional heavier frameworks as a project grows: test-drive, ftz, pFunit.

## 5. Static checks and formatting

- `findent --check`, `fprettify` formatting; `fortitude` (linter) and for
  `ford` warnings: watch for undocumented public entities.
- Sanitizers: gfortran supports ASan/UBSan via `-fsanitize=address,undefined`
  — helpful for allocatable/pointer bugs beyond `-fcheck=all`.

## Sources

- gfortran manual (options, coarrays, interop):
  https://gcc.gnu.org/onlinedocs/gfortran/
- FORD manual: https://forddocs.readthedocs.io/
- fpm: https://fpm.fortran-lang.org/
- Fortran-lang "Building programs": https://fortran-lang.org/learn/building_programs/
