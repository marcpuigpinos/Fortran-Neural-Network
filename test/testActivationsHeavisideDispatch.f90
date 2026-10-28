! AI Generated
program testActivationsHeavisideDispatch
    !! Verify polymorphic dispatch of `Heaviside` through `Activation`.
    !!
    !! Declares a `class(Activation), allocatable` handle allocated to
    !! `Heaviside`, calls the deferred `%fn` and `%deriv` bindings through
    !! the abstract base on a negative/zero/positive vector, and asserts
    !! the handle runs the Heaviside arithmetic: `fn` yields the {0, 1}
    !! pattern `{0, 1, 1}` (pinning the documented H(0) = 1 convention
    !! reached via the vtable) and `deriv` yields the all-zero pattern
    !! `{0, 0, 0}`. This confirms the abstract interface / `procedure ::`
    !! override wiring (vtable dispatch) selects the Heaviside
    !! implementations of both deferred bindings. Prints
    !! `PASS testActivationsHeavisideDispatch` on success; prints a
    !! `FAIL testActivationsHeavisideDispatch ...` message and aborts with
    !! `error stop 1` on any mismatch.

    use, intrinsic :: iso_fortran_env, only: real64
    use mActivations, only: Activation, Heaviside

    implicit none

    ! Test name reused in every PASS/FAIL message so failures identify the suite entry.
    character(len=*), parameter :: test_name = 'testActivationsHeavisideDispatch'
    real(real64), parameter :: tol = 1.0e-12_real64  ! Absolute tolerance for element comparisons

    ! Negative/zero/positive input so dispatch exercises the kink convention.
    real(real64), parameter :: z(3) = [-2.0_real64, 0.0_real64, 3.0_real64]
    real(real64), parameter :: fn_expect(3) = [0.0_real64, 1.0_real64, 1.0_real64]
    real(real64), parameter :: d_expect(3) = [0.0_real64, 0.0_real64, 0.0_real64]

    class(Activation), allocatable :: handle  ! Abstract handle allocated to a Heaviside
    real(real64) :: a(3)  ! fn result obtained through the abstract handle
    real(real64) :: d(3)  ! deriv result obtained through the abstract handle

    allocate (Heaviside :: handle)

    ! Dispatch through the abstract base; must select the Heaviside bindings.
    a = handle%fn(z)
    d = handle%deriv(z)

    ! fn reached through the abstract handle must give the {0, 1} step with
    ! H(0) = 1, which pins the kink convention through the vtable.
    if (any(abs(a - fn_expect) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'class(Activation) holding Heaviside did not dispatch fn to the (z >= 0) step'
        error stop 1
    end if

    ! fn at z = 0 through the abstract handle equals exactly 1 (H(0) = 1).
    if (abs(a(2) - 1.0_real64) > tol) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'Heaviside handle fn at z = 0 is not 1'
        error stop 1
    end if

    ! deriv reached through the abstract handle must be identically 0.
    if (any(abs(d - d_expect) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'class(Activation) holding Heaviside did not dispatch deriv to the zero map'
        error stop 1
    end if

    print '(A, 1X, A)', 'PASS', test_name

end program testActivationsHeavisideDispatch
