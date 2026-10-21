! AI Generated
program testActivationsDispatch
    !! Verify polymorphic dispatch of the deferred `Activation%fn`/`%deriv`.
    !!
    !! Declares two `class(Activation), allocatable` handles, one allocated
    !! to `ReLU` and one to `Sigmoid`, calls the deferred `%fn` and
    !! `%deriv` bindings through the abstract base, and asserts each handle
    !! runs the arithmetic of its concrete type: the ReLU handle yields
    !! a = max(0, z) and the documented 0/1 derivative, while the Sigmoid
    !! handle yields sigma(0) = 0.5 and the sigmoid derivative 0.25 at 0.
    !! This confirms the abstract interface / `procedure :: fn =>` override
    !! wiring (vtable dispatch) selects the correct implementation of each
    !! deferred binding. Prints `PASS testActivationsDispatch` on success;
    !! prints a `FAIL testActivationsDispatch ...` message and aborts with
    !! `error stop 1` on any mismatch.

    use, intrinsic :: iso_fortran_env, only: real64
    use mActivations, only: Activation, ReLU, Sigmoid

    implicit none

    ! Test name reused in every PASS/FAIL message so failures identify the suite entry.
    character(len=*), parameter :: test_name = 'testActivationsDispatch'
    real(real64), parameter :: tol = 1.0e-12_real64  ! Absolute tolerance for element comparisons

    ! Shared mixed-sign input so both handles see negative, zero and positive z.
    real(real64), parameter :: z(5) = [-2.0_real64, -0.5_real64, 0.0_real64, 1.0_real64, 3.0_real64]
    real(real64), parameter :: relu_fn_expect(5) = [ &
        0.0_real64, 0.0_real64, 0.0_real64, 1.0_real64, 3.0_real64]
    real(real64), parameter :: relu_d_expect(5) = [ &
        0.0_real64, 0.0_real64, 0.0_real64, 1.0_real64, 1.0_real64]
    real(real64) :: s_expect(5)  ! Naive sigmoid recomputed independently via exp
    real(real64) :: sd_expect(5)  ! Expected sigmoid derivative s * (1 - s)

    class(Activation), allocatable :: relu_handle  ! Abstract handle allocated to a ReLU
    class(Activation), allocatable :: sig_handle  ! Abstract handle allocated to a Sigmoid
    real(real64) :: relu_a(5)  ! fn result obtained through the ReLU handle
    real(real64) :: relu_d(5)  ! deriv result obtained through the ReLU handle
    real(real64) :: sig_a(5)  ! fn result obtained through the Sigmoid handle
    real(real64) :: sig_d(5)  ! deriv result obtained through the Sigmoid handle

    allocate (ReLU :: relu_handle)
    allocate (Sigmoid :: sig_handle)

    ! Dispatch through the abstract bases; must select the ReLU bindings.
    relu_a = relu_handle%fn(z)
    relu_d = relu_handle%deriv(z)

    if (any(abs(relu_a - relu_fn_expect) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'class(Activation) holding ReLU did not dispatch fn to max(0, z)'
        error stop 1
    end if
    if (any(abs(relu_d - relu_d_expect) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'class(Activation) holding ReLU did not dispatch deriv to the 0/1 step'
        error stop 1
    end if

    ! Dispatch through the abstract base; must select the Sigmoid bindings.
    sig_a = sig_handle%fn(z)
    sig_d = sig_handle%deriv(z)

    ! Sigmoid activation must match the naive form and stay in (0, 1),
    ! which distinguishes it sharply from the ReLU result above.
    s_expect = 1.0_real64 / (1.0_real64 + exp(-z))
    if (any(abs(sig_a - s_expect) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'class(Activation) holding Sigmoid did not dispatch fn to the sigmoid'
        error stop 1
    end if

    ! sigmoid(0) reached through the abstract handle equals 0.5 (index 3).
    if (abs(sig_a(3) - 0.5_real64) > tol) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'Sigmoid handle fn at z = 0 is not 0.5'
        error stop 1
    end if

    ! Sigmoid derivative reached through the abstract handle equals s(1 - s).
    sd_expect = s_expect * (1.0_real64 - s_expect)
    if (any(abs(sig_d - sd_expect) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'class(Activation) holding Sigmoid did not dispatch deriv to s(1 - s)'
        error stop 1
    end if

    ! sigmoid derivative at z = 0 equals 0.25 through the abstract handle.
    if (abs(sig_d(3) - 0.25_real64) > tol) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'Sigmoid handle deriv at z = 0 is not 0.25'
        error stop 1
    end if

    print '(A, 1X, A)', 'PASS', test_name

end program testActivationsDispatch
