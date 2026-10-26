! AI Generated
program testActivationsHeaviside
    !! Verify `Heaviside%fn` and `Heaviside%deriv` on a hand-computed vector.
    !!
    !! Applies the Heaviside step activation a = 1 if z >= 0 else 0 and the
    !! classical derivative d = 0 to a 1-D vector `z` covering strictly
    !! negative, exactly zero, and strictly positive entries. The expected
    !! `{0, 1}` pattern is recomputed independently with `merge` so the
    !! assertion does not reuse the library's own expression shape blindly.
    !! Explicitly pins the documented H(0) = 1 convention at the kink via a
    !! dedicated single-element call so a future refactor cannot silently
    !! flip the boundary to H(0) = 0 (the mixed-sign mask also expects 1 at
    !! the zero entry, pinning the kink a second way), asserts every `fn`
    !! result is one of `{0, 1}` within tolerance, and asserts `deriv` is
    !! identically 0 for every element including `z = 0`. Output shapes are
    !! checked to match
    !! the input shape for both bindings. Prints `PASS testActivationsHeaviside`
    !! on success; prints a `FAIL testActivationsHeaviside ...` message and
    !! aborts with `error stop 1` on any mismatch.

    use, intrinsic :: iso_fortran_env, only: real64
    use mActivations, only: Heaviside

    implicit none

    ! Test name reused in every PASS/FAIL message so failures identify the suite entry.
    character(len=*), parameter :: test_name = 'testActivationsHeaviside'
    real(real64), parameter :: tol = 1.0e-14_real64  ! Absolute tolerance for element comparisons

    type(Heaviside) :: act  ! Concrete Heaviside activation under test
    ! Mixed-sign pattern: strictly negative entries must give 0, the exact
    ! zero entry exercises the H(0) = 1 convention, positive entries give 1.
    real(real64), parameter :: z(5) = [-3.0_real64, -1.0_real64, 0.0_real64, 2.0_real64, 5.0_real64]
    real(real64) :: expect_fn(5)  ! Expected {0, 1} pattern recomputed with merge
    real(real64) :: a(5)  ! Heaviside activation values returned by fn
    real(real64) :: d(5)  ! Heaviside derivative values returned by deriv
    real(real64) :: zero_z(1)  ! Single-element input (z = 0) for the exact-point check
    real(real64) :: a0(1)  ! fn value at z = 0
    integer :: i  ! Element index for the {0, 1} membership loop

    a = act%fn(z)
    d = act%deriv(z)

    ! Activation values must match {0, 1} with 1 at and above the origin,
    ! recomputed independently here via merge on the same mask condition.
    ! The zero entry of the mixed-sign vector is covered by this mask (its
    ! expected value is 1), so the kink is pinned through the main vector too.
    expect_fn = merge(1.0_real64, 0.0_real64, z >= 0.0_real64)
    if (any(abs(a - expect_fn) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'fn does not equal the (z >= 0) step pattern on the mixed-sign vector'
        error stop 1
    end if

    ! Pin the documented kink convention at the exact boundary: fn at a
    ! lone z = 0 is 1 (H(0) = 1), checked within the standard tolerance.
    zero_z = [0.0_real64]
    a0 = act%fn(zero_z)
    if (abs(a0(1) - 1.0_real64) > tol) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'fn at z = 0 is not exactly 1 (H(0) = 1 convention violated)'
        error stop 1
    end if

    ! Every fn result must be one of {0, 1} within tolerance.
    do i = 1, size(a)
        if (min(abs(a(i) - 0.0_real64), abs(a(i) - 1.0_real64)) > tol) then
            print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
                'fn produced a value outside the {0, 1} range'
            error stop 1
        end if
    end do

    ! Derivative must be identically 0 everywhere, including at the kink
    ! z = 0 (the classical-0 convention); the all-elements check below covers
    ! every entry of the mixed-sign vector, so no separate kink assertion is
    ! needed.
    if (any(abs(d - 0.0_real64) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'deriv is not identically 0 on the mixed-sign vector'
        error stop 1
    end if

    ! Output shape for fn and deriv must match the input shape element-wise.
    if (size(a) /= size(z) .or. size(d) /= size(z)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'fn/deriv result length does not match the input length'
        error stop 1
    end if

    print '(A, 1X, A)', 'PASS', test_name

end program testActivationsHeaviside
