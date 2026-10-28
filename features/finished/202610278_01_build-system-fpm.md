> **AI Assisted**
> Status: finished
> Branch: feature/build-system-fpm
> Merge commit: 510d3cae1582acd96a063533375e53502cb48662

# Fortran Package Manager Build System

As `make` file has some limitations, I would like you to evaluate, the modification of the project to use `Fortran Package Manager` as a build system. If you think it is feasible (my opinion is that is the path to follow), please modify the project to work with `fpm` and remove the MakeFile.20261027_01_basic_layer copy

## Progress

- 2026-10-28: v0.4.1 committed on feature/build-system-fpm (e5c2eea) — Migrated the build to the Fortran Package Manager (fpm) while keeping the Makefile as a thin front-end. The version-injection (VERSION -> src/mVersion.f90) and FORD docs target are preserved; fpm owns compilation and dependency ordering, with `-std=f2008` passed via --flag and the test directory renamed tests/ -> test/ for fpm auto-discovery.
- 2026-10-28: merged into main (510d3cae1582acd96a063533375e53502cb48662); branch deleted. Build system migrated to fpm with a thin Makefile front-end; shipped as v0.4.1.