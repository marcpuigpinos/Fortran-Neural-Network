# AI Generated
#
# Thin build front-end for the Fortran Neural Network library. The actual
# compilation and dependency ordering is delegated to fpm (Fortran Package
# Manager, see fpm.toml). This Makefile keeps the historical target names and
# does exactly two things: (a) inject the version (VERSION -> generated
# src/mVersion.f90), and (b) invoke fpm for the requested profile. Conventions
# come from AGENTS.md: gfortran on Fortran 2008, artifacts confined to build/,
# automatic discovery of sources (src/) and tests (test/).

# Toolchain note: fpm drives gfortran itself. The per-profile optimization and
# checked flags come from fpm's built-in profiles (`--profile release` ~= -O2,
# `--profile debug` ~= -g -fcheck=all -Wall -Wextra). The project's Fortran
# 2008 rule is enforced by passing FFLAGS to every fpm invocation below, since
# fpm 0.12 has no manifest key selecting the standard.
FFLAGS := -std=f2008

BUILD := build

# --- Version as the single source of truth ----------------------------------
# The root VERSION file is the sole authority for the library version. The
# first non-blank token, with all whitespace stripped, becomes VERSION_TEXT;
# it is injected into a generated Fortran module (mVersion) and into the FORD
# configuration at build time so no version literal is hand-maintained.
VERSION_TEXT := $(shell awk '{gsub(/[[:space:]]/,""); if ($$0!="") {print; exit}}' VERSION)

# Parse-time guard: abort make immediately, before any rule runs, when the
# version cannot be derived (VERSION missing or empty). The in-recipe check in
# the generated-mVersion rule below stays as a secondary safety net.
ifeq ($(strip $(VERSION_TEXT)),)
$(error VERSION file at repo root is missing or empty; cannot derive the library version)
endif

# The generated version module lives in src/ so fpm compiles it as part of the
# library. It is derived from VERSION and is git-ignored (never committed).
VERSION_MODULE := src/mVersion.f90

# --- Top-level targets (thin wrappers over fpm) ------------------------------
# Each profile target first (re)generates the version module from VERSION, then
# hands off to fpm. fpm owns compilation, module dependency ordering and the
# build/ output tree. The historical target names are preserved.

release: $(VERSION_MODULE)
	fpm build --profile release --flag "$(FFLAGS)"

debug: $(VERSION_MODULE)
	fpm build --profile debug --flag "$(FFLAGS)"

# fpm test builds against the default/debug profile and runs every discovered
# test<Name>.f90 program, failing on the first failing test. fpm runs the test
# executables with CWD = the fpm.toml directory (repo root), so tests that read
# the VERSION file relative to CWD (e.g. testVersion) keep working.
test: $(VERSION_MODULE)
	fpm test --flag "$(FFLAGS)"

# FORD HTML API documentation, rendered from the `!!` doc comments into
# build/docs (inside $(BUILD), so `clean` removes it along with everything).
# The version shown in the docs is substituted from VERSION into build/ford.md
# (generated from ford.md.in), keeping the rendered version in sync.
docs: $(VERSION_MODULE)
	mkdir -p $(BUILD)
	sed 's/@NN_VERSION@/$(VERSION_TEXT)/g' ford.md.in > $(BUILD)/ford.md
	ford $(BUILD)/ford.md

# --- Generated version module -----------------------------------------------
# src/mVersion.f90 is regenerated from VERSION whenever VERSION changes, so
# editing VERSION triggers a regeneration and a downstream fpm rebuild. The
# recipe aborts on a missing/empty VERSION, then emits a tiny module holding
# the version constant with the same FORD doc comments as before.
$(VERSION_MODULE): VERSION
	@ver='$(VERSION_TEXT)'; \
	if [ -z "$$ver" ]; then \
		echo "ERROR: VERSION file at repo root is missing or empty; cannot derive library version." >&2; \
		exit 1; \
	fi; \
	printf '%s\n' \
		'! AI Generated' \
		'! Generated from the VERSION file at build time. Do not edit by hand.' \
		'module mVersion' \
		'    !! Library version constant.' \
		'    !!' \
		'    !! Single source of truth for the library version: derived at build' \
		'    !! time from the VERSION file at the repository root. Do not edit this' \
		'    !! generated file directly; change VERSION instead.' \
		'    !!' \
		"    !! @author Fortran-Neural-Network project" \
		"    !! @version $$ver" \
		'    !! @license MIT' \
		'    implicit none' \
		'' \
		'    private' \
		'' \
		'    public :: library_version' \
		'' \
		"    character(len=*), parameter :: library_version = \"$$ver\"  !! Library version string" \
		'end module mVersion' > $@

# fpm clean operates on its own build tree; --skip avoids its interactive
# confirmation prompt so the target stays automatable. Also remove build/ (and
# thus any legacy build/generated, build/version.stamp) and the generated module
# for a full reset.
clean:
	fpm clean --skip || true
	rm -rf $(BUILD)
	rm -f $(VERSION_MODULE)

.PHONY: release debug test docs clean
