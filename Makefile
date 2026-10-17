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

# Discovery runs on every make invocation; tests/ may be absent or empty.
SRCS := $(wildcard $(SRCDIR)/*.f90)
TEST_SRCS := $(wildcard $(TESTDIR)/test_*.f90)

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
release: $(RELEASE_OBJS)

debug: $(DEBUG_OBJS)

# Build directories are created as order-only prerequisites of the objects.
$(BUILD)/release $(BUILD)/debug:
	mkdir -p $@

$(BUILD)/release/%.o: $(SRCDIR)/%.f90 | $(BUILD)/release
	$(FC) $(FFLAGS) $(RELEASE_FLAGS) -J $(@D) -c $< -o $@

$(BUILD)/debug/%.o: $(SRCDIR)/%.f90 | $(BUILD)/debug
	$(FC) $(FFLAGS) $(DEBUG_FLAGS) -J $(@D) -c $< -o $@

# Tests build against the debug profile and depend on all library objects.
$(BUILD)/debug/%.o: $(TESTDIR)/%.f90 $(DEBUG_OBJS) | $(BUILD)/debug
	$(FC) $(FFLAGS) $(DEBUG_FLAGS) -I $(BUILD)/debug -c $< -o $@

$(BUILD)/debug/%: $(BUILD)/debug/%.o $(DEBUG_OBJS)
	$(FC) $(FFLAGS) $(DEBUG_FLAGS) -o $@ $^

test: $(TEST_BINS)
	@if [ -z "$(TEST_BINS)" ]; then \
		echo "SKIP: no tests found (tests/test_*.f90)"; \
	else \
		for t in $(TEST_BINS); do \
			echo "RUN $$t"; \
			$$t || exit 1; \
		done; \
	fi

# FORD HTML API documentation, rendered from the `!!` doc comments into
# build/docs (inside $(BUILD), so `clean` removes it along with everything).
docs:
	ford ford.md

clean:
	rm -rf $(BUILD)

.PHONY: release debug test docs clean
