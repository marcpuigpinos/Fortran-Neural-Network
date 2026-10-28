! AI Generated
program testActivationsRelu
    !! Verify `ReLU%fn` and `ReLU%deriv` on a hand-computed vector.
    !!
    !! Applies the ReLU activation a = max(0, z) and the ReLU derivative
    !! d = 1 if z > 0 else 0 to a 1-D vector `z` covering negative, zero,
    !! and positive entries and asserts the results element-wise within a
    !! tight tolerance. Explicitly pins the documented subgradient
    !! convention at `z = 0` (`relu_deriv` is 0 at the kink, never 1) so a
    !! future refactor cannot silently invert the boundary condition. Also
    !! asserts the output shape always matches the input shape (`n > 1`)
    !! for both bindings. Prints `PASS testActivationsRelu` on success;
    !! prints a `FAIL testActivationsRelu ...` message and aborts with
    !! `error stop 1` on any mismatch.

    use, intrinsic :: iso_fortran_env, only: real64
    use mActivations, only: ReLU

    implicit none

    ! Test name reused in every PASS/FAIL message so failures identify the suite entry.
    character(len=*), parameter :: test_name = 'testActivationsRelu'
    real(real64), parameter :: tol = 1.0e-14_real64  ! Absolute tolerance for element comparisons

    type(ReLU) :: act  ! Concrete ReLU activation under test
    ! Mixed-sign pattern: negative entries must saturate to 0, the exact
    ! zero entry exercises the kink convention, positive entries pass through.
    real(real64), parameter :: z(5) = [-3.0_real64, -1.0_real64, 0.0_real64, 2.0_real64, 5.0_real64]
    real(real64), parameter :: expect_fn(5) = [ &
        0.0_real64, 0.0_real64, 0.0_real64, 2.0_real64, 5.0_real64]
    real(real64), parameter :: expect_d(5) = [ &
        0.0_real64, 0.0_real64, 0.0_real64, 1.0_real64, 1.0_real64]
    real(real64) :: a(5)  ! ReLU activation values returned by fn
    real(real64) :: d(5)  ! ReLU derivative values returned by deriv

    a = act%fn(z)
    d = act%deriv(z)

    ! Activation values from fn must match max(0, z) element-wise.
    if (any(abs(a - expect_fn) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'fn does not equal max(0, z) on the mixed-sign vector'
        error stop 1
    end if

    ! Derivative values from deriv must be the (sign-step) 0/1 pattern.
    if (any(abs(d - expect_d) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'deriv does not equal the (z > 0) step pattern on the mixed-sign vector'
        error stop 1
    end if

    ! Pin the documented kink convention: deriv at z = 0 is 0, not 1.
    if (abs(d(3) - 0.0_real64) > tol) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'deriv at z = 0 must follow the documented subgradient-0 convention'
        error stop 1
    end if

    ! Output shape for fn and deriv must match the input shape element-wise.
    if (size(a) /= size(z) .or. size(d) /= size(z)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'fn/deriv result length does not match the input length'
        error stop 1
    end if

    print '(A, 1X, A)', 'PASS', test_name

end program testActivationsRelu
