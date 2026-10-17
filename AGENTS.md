> **AI Generated**

# Fortran Neural Network — Agent Instructions

Neural network library implemented in modern Fortran. This file is the single
source of truth for project conventions. All agents (orchestrator and
subagents) must follow it.

## AI-generated attribution

This project is developed with AI assistance: every file created in this
project — Fortran sources, tests, Markdown documents, the Makefile, scripts
and config files — must state that it is AI-generated, right at the top of
the file, using the comment syntax of its type:

- Fortran (`*.f90`): `! AI Generated` before the `module` / `program`
  statement.
- Markdown (`*.md`): `> **AI Generated**` as the first line of the file
  (immediately after any YAML frontmatter).
- Makefiles, shell scripts and config files (including dotfiles such as
  `.gitignore`): `# AI Generated` as the first line.

The marker is permanent: the reviewer flags any new or modified file missing
it as an ERROR.

## Toolchain

- Compiler: `gfortran`, standard **Fortran 2008** (`-std=f2008`).
- Build system: GNU `make`, single `Makefile` at the repo root.
  - `make release` — optimized build (`-O2`), artifacts in `build/release/`
  - `make debug`   — checked build (`-g -fcheck=all -Wall -Wextra`), artifacts in `build/debug/`
  - `make test`    — build and run the test suite against the debug build
  - `make docs`    — generate FORD HTML documentation into `build/docs/`
  - `make clean`   — remove build artifacts (including `build/docs/`)
- Documentation generator: **FORD** (`ford`, invoked via `make docs`; the
  builder owns the FORD config file at the repo root).
- Version: semantic versioning, stored in the `VERSION` file at the repo root.

## Repository layout

```
src/        Fortran sources (library modules), one module per file
tests/      Test programs, one per file, named test_*.f90 (f90 for tests)
docs/       Design docs and CHANGELOG.md (per-version entries)
build/      Generated artifacts (never committed)
```

## Code style (enforced by the reviewer)

- Free-form source files with `.f90` extension; file name equals the module
  name it contains (case-insensitive).
- `implicit none` in **every** scoping unit.
- Everything in a module is `private` by default; exports are listed
  explicitly in a `public :: ...` statement right after the accessibility
  attribute.
- Derived types: `PascalCase`. Modules, procedures, variables, constants:
  `snake_case`. Named constants instead of magic numbers.
- 4-space indentation, no tabs, maximum line length 100 characters.
- All dummy arguments carry an explicit `intent(...)`.
- Pure functions where possible; no I/O inside library code except through
  explicitly documented procedures.
- Comments start with `! ` and explain *why*, not *what*. Public API and
  procedures are documented in FORD style (see "Documentation (FORD)").
- Every source file declares the module it belongs to and is compilable
  independently given its `use` dependencies.

## Documentation (FORD)

All documentation comments use **FORD** (Fortran Documentation) style. Note
that FORD differs from most doc systems: the doc block goes **immediately
below** the entity it describes, and arguments/components use a **trailing**
`!!` comment.

Rules:

- Every `module`, `procedure`, and derived `type` gets a `!!` doc block on the
  line(s) right after its opening statement: a one-line summary, then an
  optional description.
- Every dummy argument, result, and public derived-type component gets a
  trailing `!! ...` description on the same declaration line.
- Use `=====` to open a free-form "extended" prose section inside an entity
  block, and `== Heading` for sub-sections.
- Put `@author`, `@version` and `@license` metadata in the top module block of
  each source file. `@version` tracks the `VERSION` file.
- Regular implementation comments keep the normal `! ` prefix; only
  documentation uses `!!`.

```fortran
module nn_layer
    implicit none
    private

    public :: Layer

    !! A dense (fully-connected) neural network layer.
    !!
    !! Stores a weight matrix and bias vector and applies an activation
    !! to the affine transform of its input.
    !!
    !! @author Fortran-Neural-Network project
    !! @version 0.1.0
    !! @license MIT
    type :: Layer
        real(real64), allocatable :: weights(:,:)  !! Weight matrix (out x in)
        real(real64), allocatable :: bias(:)       !! Bias vector (out)
    contains
        procedure :: forward => layer_forward      !! Evaluate the layer
    end type Layer

contains

    pure function layer_forward(self, x) result(y)
        !! Apply the affine transform and activation of `self` to `x`.
        class(Layer), intent(in) :: self   !! The layer to evaluate
        real(real64), intent(in) :: x(:)   !! Input vector (length = n_in)
        real(real64) :: y(size(self%bias))  !! Activated output vector
        ! ...implementation...
    end function layer_forward

end module nn_layer
```

## Testing

- Each test is a standalone program `test_<topic>.f90` that exits with a
  non-zero status on failure (`error stop 1`) and prints a one-line
  `PASS <name>` / `FAIL <name> ...` result.
- The Makefile discovers `tests/test_*.f90` automatically; adding a test must
  not require Makefile edits. If it does, report it so the builder fixes the
  Makefile.

## Multi-agent workflow

Agent definitions live in `.github/agents/`. The `orchestrator` is the only
agent that talks to the human; every other subagent communicates **only**
with the orchestrator and reports results back to it.

Standard feature flow:

1. Human gives the specification to `orchestrator`.
2. `git-manager` updates the repo and creates a feature branch.
3. `implementer` writes the Fortran code on that branch.
4. `builder` builds the project (release + debug); failures loop back to `implementer`.
5. `tester` writes new tests if needed.
6. `builder` builds the tests.
7. `tester` runs the full suite; failures loop back to `implementer` (rebuild + retest).
8. `reviewer` checks style and formal correctness; findings are routed by the
   orchestrator to the responsible agent and **every resulting change is
   rebuilt and retested**.
9. `git-manager` bumps the version in `VERSION`.
10. `documenter` documents the changes in `docs/`, referencing the new version.
11. `builder` generates the FORD documentation (`make docs`) as the final
    build task before committing.
12. `git-manager` commits everything on the feature branch.
13. Merging into `main` happens only when the human explicitly instructs the
    orchestrator.
