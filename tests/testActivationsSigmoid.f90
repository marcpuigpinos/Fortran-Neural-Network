! AI Generated
program testActivationsSigmoid
    !! Verify `Sigmoid%fn` and `Sigmoid%deriv` against analytic values.
    !!
    !! Cross-checks the branch-stable sigmoid against the naive form
    !! sigma(z) = 1/(1 + exp(-z)) for moderate `z`, and asserts the
    !! documented analytic properties on `n > 1` vectors: `fn` is exactly
    !! 0.5 at z = 0, symmetric (sigma(z) + sigma(-z) = 1), monotonic
    !! non-decreasing on an increasing `z`, and matches the known value at
    !! z = 1; `deriv` equals 0.25 at z = 0 (its maximum), is symmetric
    !! (d(z) = d(-z)), matches s(1 - s) for a spread of `z`, and stays in
    !! [0, 0.25]. Expected values are recomputed here with `exp` so the
    !! assertions are independent of the library's stable-branch code.
    !! Prints `PASS testActivationsSigmoid` on success; prints a
    !! `FAIL testActivationsSigmoid ...` message and aborts with
    !! `error stop 1` on any mismatch.

    use, intrinsic :: iso_fortran_env, only: real64
    use mActivations, only: Sigmoid

    implicit none

    ! Test name reused in every PASS/FAIL message so failures identify the suite entry.
    character(len=*), parameter :: test_name = 'testActivationsSigmoid'
    real(real64), parameter :: tol = 1.0e-12_real64  ! Tolerance for analytic cross-checks

    type(Sigmoid) :: act  ! Concrete sigmoid activation under test
    real(real64) :: z(4)  ! Moderate spread of pre-activation inputs
    real(real64) :: neg_z(4)  ! Negated inputs z, for the symmetry checks
    real(real64) :: a(4)  ! Sigmoid activation values from fn
    real(real64) :: neg_a(4)  ! Sigmoid values sigma(-z) from fn
    real(real64) :: d(4)  ! Sigmoid derivative values from deriv
    real(real64) :: neg_d(4)  ! Derivative values at -z, for the symmetry check
    real(real64) :: expected(4)  ! Naive sigma recomputed independently with exp
    real(real64) :: s(4)  ! Naive sigma used to build the expected derivative
    real(real64) :: expect_d(4)  ! Expected derivative s * (1 - s)
    real(real64) :: mono_z(6)  ! Strictly increasing inputs for the monotonic test
    real(real64) :: mono_a(6)  ! Activations on the increasing inputs
    real(real64) :: zero_z(1)  ! Single-element input (z = 0) for the exact-point checks
    real(real64) :: a0(1)  ! fn value at z = 0
    real(real64) :: d0(1)  ! deriv value at z = 0
    integer :: i  ! Element index

    z = [-2.0_real64, -0.5_real64, 1.0_real64, 3.0_real64]
    neg_z = -z

    a = act%fn(z)
    neg_a = act%fn(neg_z)
    d = act%deriv(z)
    neg_d = act%deriv(neg_z)

    ! fn(z) must agree with the naive 1/(1 + exp(-z)) for moderate z.
    expected = 1.0_real64 / (1.0_real64 + exp(-z))
    if (any(abs(a - expected) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'fn disagrees with the naive 1/(1+exp(-z)) form'
        error stop 1
    end if

    ! Known reference value at z = 1 (index 3 of z).
    if (abs(a(3) - 0.7310585786300049_real64) > tol) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'fn(1) differs from sigmoid(1) = 1/(1+exp(-1))'
        error stop 1
    end if

    ! fn(0) is exactly 0.5.
    zero_z = [0.0_real64]
    a0 = act%fn(zero_z)
    if (abs(a0(1) - 0.5_real64) > tol) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'fn at z = 0 is not 0.5'
        error stop 1
    end if

    ! Symmetry: sigma(z) + sigma(-z) = 1.
    if (any(abs((a + neg_a) - 1.0_real64) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'fn(z) + fn(-z) is not 1 (sigmoid symmetry violated)'
        error stop 1
    end if

    ! Monotonic non-decreasing on a strictly increasing input vector.
    mono_z = [-4.0_real64, -1.0_real64, 0.0_real64, 1.0_real64, 2.0_real64, 6.0_real64]
    mono_a = act%fn(mono_z)
    do i = 2, size(mono_z)
        if (mono_a(i) < mono_a(i - 1)) then
            print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
                'fn is not monotonic non-decreasing on an increasing input'
            error stop 1
        end if
    end do

    ! deriv(0) is exactly 0.25 (maximum of the derivative).
    d0 = act%deriv(zero_z)
    if (abs(d0(1) - 0.25_real64) > tol) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'deriv at z = 0 is not 0.25'
        error stop 1
    end if

    ! deriv symmetry: d(z) = d(-z), since d = a(1 - a) is symmetric.
    if (any(abs(d - neg_d) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'deriv(z) differs from deriv(-z) (derivative symmetry violated)'
        error stop 1
    end if

    ! deriv must equal s * (1 - s) with s the naive sigmoid, recomputed here.
    s = 1.0_real64 / (1.0_real64 + exp(-z))
    expect_d = s * (1.0_real64 - s)
    if (any(abs(d - expect_d) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'deriv differs from s * (1 - s)'
        error stop 1
    end if

    ! deriv stays within [0, 0.25] across the tested spread.
    if (any(d < -tol) .or. any(d > 0.25_real64 + tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'deriv leaves the analytic range [0, 0.25]'
        error stop 1
    end if

    ! Output shape for fn and deriv must match the input shape.
    if (size(a) /= size(z) .or. size(d) /= size(z)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'fn/deriv result length does not match the input length'
        error stop 1
    end if

    print '(A, 1X, A)', 'PASS', test_name

end program testActivationsSigmoid
