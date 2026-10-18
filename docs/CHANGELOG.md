> **AI Generated**

# Changelog

All notable changes to this project are documented here, in [Keep a
Changelog](https://keepachangelog.com/) format, following [semantic
versioning](https://semver.org/). The current release is also recorded in the
`VERSION` file at the repository root. Entries are listed newest first.

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
