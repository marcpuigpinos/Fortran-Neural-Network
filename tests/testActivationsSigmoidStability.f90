! AI Generated
program testActivationsSigmoidStability
    !! Verify `Sigmoid` stays finite and bounded at extreme pre-activations.
    !!
    !! Feeds very large magnitude inputs (z = +/-1000) to `Sigmoid%fn` and
    !! `Sigmoid%deriv` and uses `ieee_arithmetic` to assert every result is
    !! finite (never Inf or NaN) and lies within the analytic bounds. This
    !! is the regression net for the branch-stabilised implementation: a
    !! naive 1/(1 + exp(-z)) overflows the exponential for large negative z
    !! (and the mirrored form for large positive z), whereas the library
    !! form promises a clean saturation. Asserts fn(+1000) ~ 1,
    !! fn(-1000) ~ 0, both inside [0, 1], and deriv(+/-1000) ~ 0. Prints
    !! `PASS testActivationsSigmoidStability` on success; prints a
    !! `FAIL testActivationsSigmoidStability ...` message and aborts with
    !! `error stop 1` on any violation.

    use, intrinsic :: iso_fortran_env, only: real64
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    use mActivations, only: Sigmoid

    implicit none

    ! Test name reused in every PASS/FAIL message so failures identify the suite entry.
    character(len=*), parameter :: test_name = 'testActivationsSigmoidStability'

    type(Sigmoid) :: act  ! Concrete sigmoid activation under test
    ! Extreme saturation inputs: +/-1000 overflow a naive exp yet must stay finite here.
    real(real64), parameter :: z(2) = [1000.0_real64, -1000.0_real64]
    real(real64) :: a(2)  ! Sigmoid activation values at the extreme inputs
    real(real64) :: d(2)  ! Sigmoid derivative values at the extreme inputs
    real(real64), parameter :: sat_tol = 1.0e-12_real64  ! Saturation tolerance near 0 / 1

    a = act%fn(z)
    d = act%deriv(z)

    ! fn must never produce Inf/NaN even at these extreme magnitudes.
    if (.not. all(ieee_is_finite(a))) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'fn produced a non-finite value (Inf/NaN) at large |z|'
        error stop 1
    end if

    ! fn must remain inside its analytic range [0, 1].
    if (any(a < 0.0_real64) .or. any(a > 1.0_real64)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'fn left the [0, 1] range at large |z|'
        error stop 1
    end if

    ! Saturating limits: fn(+1000) ~ 1 and fn(-1000) ~ 0.
    if (abs(a(1) - 1.0_real64) > sat_tol) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'fn at z = +1000 does not saturate to 1'
        error stop 1
    end if
    if (abs(a(2) - 0.0_real64) > sat_tol) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'fn at z = -1000 does not saturate to 0'
        error stop 1
    end if

    ! deriv must likewise be finite and within [0, 0.25].
    if (.not. all(ieee_is_finite(d))) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'deriv produced a non-finite value (Inf/NaN) at large |z|'
        error stop 1
    end if
    if (any(d < 0.0_real64) .or. any(d > 0.25_real64)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'deriv left the [0, 0.25] range at large |z|'
        error stop 1
    end if

    ! deriv saturates to ~0 once the activation is fully saturated.
    if (any(abs(d) > sat_tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'deriv at |z| = 1000 does not vanish toward 0'
        error stop 1
    end if

    print '(A, 1X, A)', 'PASS', test_name

end program testActivationsSigmoidStability
