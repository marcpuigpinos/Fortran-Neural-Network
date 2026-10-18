> **AI Generated**

# Numeric & Scientific Computing in Fortran

Reference for numerically robust, performant Fortran.

## 1. Kind system and literals

- `use, intrinsic :: iso_fortran_env, only: real32, real64, int32, int64`
  — the portable names. Never assume `real == real32` or `real(kind=8)`
  means IEEE double on every compiler (gfortran: `real64` is kind 8; other
  compilers differ).
- Suffix every literal used in mixed-precision math: `0.5_real64`,
  `10_int64`. `1.0d0` is a legacy non-standard spelling — avoid.
- Mixed-mode arithmetic (`real32 * real64`) happens implicitly; write
  explicit conversions (`real(x, real64)`, `int(y, int64)`) so intent is
  visible.
- Integer division truncates: `1/2 == 0`. Use `0.5` or
  `real(a, kind)/real(b, kind)`.
- Derived kind via inquiry when needed: `kind(1.0_real64)`,
  `selected_real_kind(p=15, r=300)`, `precision(x)`, `epsilon(x)`,
  `huge(x)`, `tiny(x)`, `radix(x)`.

## 2. Floating-point robustness

- **Never `==` on reals.** Comparison tolerance should scale with magnitude:
  `abs(a - b) <= atol + rtol * max(abs(a), abs(b))`. `epsilon(real64)`
  (~2.2e-16) is the relative spacing, not a usable absolute epsilon.
- Order of summation matters; `sum()` uses naive addition. For long sums use
  pairwise/Kahan (`sum(x, kind=int64)` does NOT fix reals — pairwise exists
  in library packages, e.g. FLIBS' `kahan_sum`), or mathematically stable
  recurrences.
- Avoid subtractive cancellation: use algebraic reformulation or `hypot(x, y)`
  instead of `sqrt(x**2 + y**2)` (overflow-safe), `log1p`-style identities,
  `real(exp(x) - 1, ...)` rewritten via series for small `x`.
- Overflow/underflow: prefer scaling (log-sum-exp, `spacing`, `scale`,
  `exponent`) over raw exponentials. `range(real64)` ≈ 308 decimal digits.
- `nan`/`inf`: test with `ieee_is_nan` (from `ieee_arithmetic`, gfortran
  supports it) — `x == x` is the portable trick pre-F2003 compilers.
- Fused multiply-add changes rounding: don't demand bitwise-identical results
  across `-ffp-contract=fast|off|balanced` builds; use `-ffp-contract=off`
  for regression-sensitive comparisons.
- Random numbers: `call random_number(u)`, `u ∈ [0,1)`. Seed once with
  `random_seed` (or `random_init`/F2018 style). Multiple threads/streams
  need explicit `random_seed` handling to avoid identical streams.

## 3. Array-level numerics

- `matmul`, `dot_product`, `matmul(A, B)` for matrix products; for large dense
  algebra prefer BLAS/LAPACK via `isofortranenv`-free `dgemm` interfaces or a
  package (LAPACK's `iso_fortran_env` bindings module, `fortran-lapack`, or
  `stdblas`).
- Norms: `norm2(x)` (F2008) is overflow-scaled; avoids `sqrt(sum(x*x))`
  overflow.
- Masked reductions: `sum(x, dim=2, mask=mask)` or apply `where` first —
  `where` evaluates both sides, so guard divisions: use `merge` to dodge
  `0/0`: `c = merge(a/b, 0.0_real64, b /= 0.0_real64)`.
- Eigenvalues/solves in LAPACK (`dsyev`, `dgesv`, ...): always check `info`.
- Stencils: `a(2:n-1) = (u(1:n-2) + u(3:n))/2` — boundary indices explicit;
  ensure slices remain in range; compiler vectorizes stride-1 contiguous work.

## 4. Performance

- **Memory layout first**: column-major. Inner loop over the fastest index:

```fortran
do j = 1, n
    do i = 1, m          ! i contiguous: cache-friendly
        b(i, j) = a(i, j) * 2.0_real64
    end do
end do
```

- `intent(in out)` vs `intent(in)`: `intent(out)` may skip initialization and
  lets the compiler assume undefinedness; aliasing rules (no overlapping
  `intent(out)` inputs) let compilers vectorize more aggressively.
- Contiguity: non-contiguous actual arguments (slices with stride) cause
  hidden copies. `is_contiguous(x)` to test. Keep leading dimension = extent.
- Temporaries: expressions like `A = B + C + D` allocate workspace. Use BLAS
  (`?axpy`) or loop fusion (`forall` rarely helps; plain loops fuse best).
- `pure elemental` procedures vectorize well and inline when co-compiled; put
  them in modules so the compiler sees bodies.
- gfortran auto-vectorization: `-O2`/`-O3` enable it; check with
  `-fopt-info-vec-missed` (or `-fopt-info-optimized`, older:
  `-fopt-info`) to learn what vectorized and why not.
- `-fno-range-check`, assumptions from `!dir$ ivdep`/`$OMP simd` (with care)
  express loop-independence the compiler can't prove.

| Situation | Pattern |
|---|---|
| Small fixed-size vectors/mats | Explicit-shape locals `real(real64) :: v(3)` (stack) |
| Big temporaries | Allocate once, reuse; avoid per-call `allocate` |
| Matrix storage | (out, in) column-major matches BLAS `dgemm` |
| Row-major from C | Transpose on boundary or `bind` wrappers; `matmul(transpose(A), x)` |
| Reductions in loops | `fold`-style scalar accumulator; OpenMP `reduction` clause |

## 5. Parallelism

- OpenMP (`-fopenmp`): `!$omp parallel do` is Fortran's usual entry. Use
  `reduction(+:s)` for sums. Only parallelize `pure`/side-effect-free loops.
  `!$omp` sentinel must be recognized: free-form uses `!$omp`, fixed `c$omp`.
  `-fopenmp-simd` for SIMD-only without threads.
- Coarrays (F2008 `-fc=...`, gfortran shared-memory or OpenCoarrays):
  `real(real64) :: a(:)[:]` for global arrays; `sync all`, `co_sum`,
  image selectors `a[n]`. Modern alternative: MPI with Fortran bindings
  (`use mpi_f08` — type-safe, F2008-friendly, requires an MPI install).
- Threading + libraries: if BLAS is threaded, nested threading via OpenMP
  usually degrades performance — set `OMP_NUM_THREADS=1` for inner BLAS.

## 6. Reproducibility & testing numerics

- Pin tolerances per dtype: e.g. `real(real64), parameter :: tol = 100*epsilon(1.0_real64)`.
- Test against analytically known values, not previous-output snapshots.
- Determinism: avoid OpenMP reductions in nondeterministic accumulation order
  when bit-exact reproduction matters (documented, deliberate choice).
- Check `status=`/`stat=` and `info`: never ignore failure of allocation,
  LAPACK calls, or file reads in library code.

## Sources

- Fortran Best Practices + float comparisons: https://fortran-lang.org/learn/
- "Modern Fortran Explained" ch. on intrinsic procedures; LAPACK Users' Guide.
- gfortran options: https://gcc.gnu.org/onlinedocs/gfortran/
- Fortran optimization patterns (SIG-RPC): https://sig-rpc.github.io/optimisations/fortran/
