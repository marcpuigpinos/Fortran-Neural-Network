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

Exception: in markdown-based FORD configuration files (e.g. the `ford.md.in`
template), the `> **AI Generated**` marker is the first body line *after*
FORD's leading `key: value` meta block, as FORD's Markdown "meta" parser only
reads leading key/value lines.

Exception: feature files in `features/` are human-authored specifications
maintained by the `feature-manager`, so their marker is `> **AI Assisted**`
instead of `> **AI Generated**`. The human may or may not write it when
creating the file; `feature-manager` adds `> **AI Assisted**` if no
attribution marker is present and leaves an existing marker untouched.

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
tests/      Test programs, one per file, named test<Name>.f90 (PascalCase)
docs/       Design docs and CHANGELOG.md (per-version entries)
features/   Feature specification files (finished ones in features/finished/)
build/      Generated artifacts (never committed)
```

## Feature tracking

Each feature is a Markdown file in `features/` named
`YYYYMMDD_NN_<short-name>.md` (creation date plus a two-digit sequence for
the day). The human writes the specification; the `feature-manager` agent is
the only one allowed to edit these files.

- Every feature file starts with this metadata header, in this exact order:

  ```markdown
  > **AI Assisted**
  > Status: pending | ongoing | finished
  > Branch: feature/<short-name> (or — when not started)
  > Merge commit: <full hash> (or — when not merged)
  ```

- `Status: pending` when created, `ongoing` once a branch exists, `finished`
  only after the merge into `main`.
- A `## Progress` section at the end of the file holds dated one-line
  entries appended by `feature-manager` (summaries of committed work).
- When a feature is finished, `feature-manager` records the full merge
  commit hash in the header and moves the file to `features/finished/`.
  The bookkeeping commit on `main` is made by `git-manager`.

## Code style (enforced by the reviewer)

- Free-form source files with a `.f90` extension. A file's name does NOT
  have to match the module it contains: one `.f90` file may define a module
  named differently (e.g. `fortranNeuralNetwork.f90` defines
  `mFortranNeuralNetwork`).
- `implicit none` in **every** scoping unit.
- Everything in a module is `private` by default; exports are listed
  explicitly in a `public :: ...` statement right after the accessibility
  attribute.
- Derived types: `PascalCase`. Procedures, variables and constants:
  `snake_case`. Modules: `m` immediately followed by a `PascalCase` name
  (e.g. `mLayer`, `mNeuralNetwork`). Named constants instead of magic
  numbers.
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
module mLayer
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

end module mLayer
```

## Testing

- Each test is a standalone program in a file named
  `test<MainNameInPascalCase>.f90` (e.g. `testVersion.f90`), where the main
  thing under test is written in `PascalCase`. The `program` statement uses
  the same name as the file (e.g. `program testVersion`). A test exits with
  a non-zero status on failure (`error stop 1`) and prints a one-line
  `PASS <name>` / `FAIL <name> ...` result.
- The Makefile discovers `tests/test*.f90` automatically; adding a test must
  not require Makefile edits. If it does, report it so the builder fixes the
  Makefile.

## Multi-agent workflow

Agent definitions live in `.github/agents/`. The `orchestrator` is the only
agent that talks to the human; every other subagent communicates **only**
with the orchestrator and reports results back to it.

Standard feature flow:

1. Human gives the specification to `orchestrator`.
2. `git-manager` updates the repo and creates a feature branch.
3. `feature-manager` marks the feature file `ongoing` and records the branch
   (`start`).
4. `implementer` writes the Fortran code on that branch.
5. `builder` builds the project (release + debug); failures loop back to `implementer`.
6. `tester` writes new tests if needed.
7. `builder` builds the tests.
8. `tester` runs the full suite; failures loop back to `implementer` (rebuild + retest).
9. `reviewer` checks style and formal correctness; findings are routed by the
   orchestrator to the responsible agent and **every resulting change is
   rebuilt and retested**.
10. `git-manager` bumps the version in `VERSION`.
11. `documenter` documents the changes in `docs/`, referencing the new version.
12. `builder` generates the FORD documentation (`make docs`) as the final
    build task before committing.
13. `git-manager` commits everything on the feature branch.
14. `feature-manager` appends a progress entry to the feature file with a
    summary, commit hash, branch and version (`update`).
15. Merging into `main` happens only when the human explicitly instructs the
    orchestrator: `git-manager` merges (`--no-ff`) and deletes the branch;
    `feature-manager` marks the file `finished`, records the merge commit
    hash and moves it to `features/finished/`; `git-manager` commits that
    bookkeeping change on `main`.
