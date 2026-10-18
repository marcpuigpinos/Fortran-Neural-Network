# AI Generated
#
# Build system for the Fortran Neural Network library. Conventions come from
# AGENTS.md: gfortran on Fortran 2008, artifacts confined to build/, and
# automatic discovery of library sources (src/) and tests (tests/) so that
# adding a source or test never requires editing this file.

FC := gfortran
FFLAGS := -std=f2008
RELEASE_FLAGS := -O2
DEBUG_FLAGS := -g -fcheck=all -Wall -Wextra

BUILD := build
SRCDIR := src
TESTDIR := tests
GENERATED := $(BUILD)/generated

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

# Discovery runs on every make invocation; tests/ may be absent or empty.
SRCS := $(wildcard $(SRCDIR)/*.f90)
TEST_SRCS := $(wildcard $(TESTDIR)/test*.f90)

LIB_STEMS := $(basename $(notdir $(SRCS)))
RELEASE_OBJS := $(addprefix $(BUILD)/release/,$(addsuffix .o,$(LIB_STEMS)))
DEBUG_OBJS := $(addprefix $(BUILD)/debug/,$(addsuffix .o,$(LIB_STEMS)))
TEST_BINS := $(addprefix $(BUILD)/debug/,$(basename $(notdir $(TEST_SRCS))))

# --- Module dependency discovery --------------------------------------------
# Fortran names are case-insensitive, so MODULE/USE names are normalised to
# lowercase before matching.  Parsing is done with awk (case folding via
# tolower) to stay independent of grep build variations and locale.  Single
# -line USE statements are assumed, matching the project coding style.

# mod_name: lowercase name of the module DEFINED by a source file (the leading
# `module <name>` statement; `module procedure` lines are skipped).
mod_name = $(shell awk 'BEGIN{n=""} {l=tolower($$0)} n=="" && l ~ /^[[:space:]]*module[[:space:]]+[a-z_]/ {s=l; sub(/^[[:space:]]*module[[:space:]]+/,"",s); sub(/[^a-z0-9_].*$$/,"",s); if (s!="procedure" && s!="") n=s} END{print n}' $(1))

# use_names: lowercase names of modules IMPORTED (via `use [::] name`) by a
# source file. Forms introducing no module token (e.g. `use, intrinsic ::`)
# do not match and are ignored.
use_names = $(shell awk '{l=tolower($$0)} l ~ /^[[:space:]]*use[[:space:]]*(::[[:space:]]*)?[a-z_]/ {s=l; sub(/^[[:space:]]*use[[:space:]]*(::[[:space:]]*)?/,"",s); sub(/[^a-z0-9_].*$$/,"",s); if (s!="") print s}' $(1))

# Map a lowercase module name to the stem of the library file defining it.
lookup_mod = $(patsubst $(1):%,%,$(filter $(1):%,$(MOD_MAP)))

# Library objects (in build dir $(2)) that must exist before the object of
# source $(1) can compile, derived from its USE statements.
use_objs = $(addprefix $(BUILD)/$(2)/,$(addsuffix .o,$(sort $(foreach u,$(call use_names,$(1)),$(filter $(u),$(patsubst %:*,%,$(MOD_MAP)))))))

MOD_MAP := $(foreach s,$(SRCS),$(call mod_name,$(s)):$(basename $(notdir $(s))))

# Inject discovered cross-module dependencies, but ONLY when a source actually
# USEs another library module. An empty `target:` would otherwise become an
# explicit rule with no recipe, shadowing the pattern rule below and leaving
# the object buildable by no rule at all.
$(foreach s,$(SRCS),$(if $(call use_objs,$(s),debug),\
	$(eval $(BUILD)/debug/$(basename $(notdir $(s))).o: $(call use_objs,$(s),debug))))
$(foreach s,$(SRCS),$(if $(call use_objs,$(s),release),\
	$(eval $(BUILD)/release/$(basename $(notdir $(s))).o: $(call use_objs,$(s),release))))

# --- Rules -------------------------------------------------------------------
release: $(RELEASE_OBJS) $(BUILD)/version.stamp

debug: $(DEBUG_OBJS) $(BUILD)/version.stamp

# Build directories are created as order-only prerequisites of the objects.
$(BUILD)/release $(BUILD)/debug:
	mkdir -p $@

$(BUILD)/release/%.o: $(SRCDIR)/%.f90 | $(BUILD)/release
	$(FC) $(FFLAGS) $(RELEASE_FLAGS) -I $(@D) -J $(@D) -c $< -o $@

$(BUILD)/debug/%.o: $(SRCDIR)/%.f90 | $(BUILD)/debug
	$(FC) $(FFLAGS) $(DEBUG_FLAGS) -I $(@D) -J $(@D) -c $< -o $@

# --- Generated version module -------------------------------------------------
# build/generated/mVersion.f90 is regenerated from VERSION whenever VERSION
# changes, so editing VERSION triggers a regeneration, a downstream rebuild
# and a refreshed FORD config. The recipe aborts on a missing/empty VERSION,
# then emits a tiny module holding the version constant with FORD doc comments.
$(GENERATED)/mVersion.f90: VERSION
	@ver='$(VERSION_TEXT)'; \
	if [ -z "$$ver" ]; then \
		echo "ERROR: VERSION file at repo root is missing or empty; cannot derive library version." >&2; \
		exit 1; \
	fi; \
	mkdir -p $(GENERATED); \
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

# The stamp exists so VERSION changes propagate to the top-level profile
# targets (release/debug) and to docs via a single prereq. It rides after the
# generated source, which carries the real timestamp.
$(BUILD)/version.stamp: $(GENERATED)/mVersion.f90
	touch $@

# Compile the generated version module into the same profile directory as the
# library objects so its .mod is exported (-J) and consumed (-I) there.
$(BUILD)/debug/mVersion.o: $(GENERATED)/mVersion.f90 $(BUILD)/version.stamp | $(BUILD)/debug
	$(FC) $(FFLAGS) $(DEBUG_FLAGS) -I $(@D) -J $(@D) -c $< -o $@

$(BUILD)/release/mVersion.o: $(GENERATED)/mVersion.f90 $(BUILD)/version.stamp | $(BUILD)/release
	$(FC) $(FFLAGS) $(RELEASE_FLAGS) -I $(@D) -J $(@D) -c $< -o $@

# The library module USEs mVersion, but the awk dependency scan only sees
# src/*.f90, so link the generated object in explicitly per profile.
$(BUILD)/debug/fortranNeuralNetwork.o: $(BUILD)/debug/mVersion.o
$(BUILD)/release/fortranNeuralNetwork.o: $(BUILD)/release/mVersion.o

# Tests build against the debug profile and depend on all library objects.
$(BUILD)/debug/%.o: $(TESTDIR)/%.f90 $(DEBUG_OBJS) | $(BUILD)/debug
	$(FC) $(FFLAGS) $(DEBUG_FLAGS) -I $(BUILD)/debug -c $< -o $@

$(BUILD)/debug/%: $(BUILD)/debug/%.o $(DEBUG_OBJS)
	$(FC) $(FFLAGS) $(DEBUG_FLAGS) -o $@ $^

test: $(TEST_BINS)
	@if [ -z "$(TEST_BINS)" ]; then \
		echo "SKIP: no tests found (tests/test*.f90)"; \
	else \
		for t in $(TEST_BINS); do \
			echo "RUN $$t"; \
			$$t || exit 1; \
		done; \
	fi

# FORD HTML API documentation, rendered from the `!!` doc comments into
# build/docs (inside $(BUILD), so `clean` removes it along with everything).
# The version shown in the docs is substituted from VERSION into build/ford.md
# (generated from ford.md.in), keeping the rendered version in sync.
docs: $(BUILD)/version.stamp
	mkdir -p $(BUILD)
	sed 's/@NN_VERSION@/$(VERSION_TEXT)/g' ford.md.in > $(BUILD)/ford.md
	ford $(BUILD)/ford.md

clean:
	rm -rf $(BUILD)

.PHONY: release debug test docs clean
