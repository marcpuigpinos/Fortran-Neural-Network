! AI Generated
! Template standalone test program. File must be named test<Name>.f90 and the
! program statement must match the file name (e.g. tests/testThing.f90 ->
! program testThing). Discovered automatically by `make test` via tests/test*.f90.
program testThing
    !! Verify example behavior: <one-line description of the property>.
    !!
    !! Asserts <property 1> and <property 2>. Prints `PASS testThing` on
    !! success; prints `FAIL testThing <reason>` and aborts with `error stop
    !! 1` on any violation.

    use, intrinsic :: iso_fortran_env, only: real64

    use mLayerExample, only: Layer, layer_init

    implicit none

    ! Test name reused in every message so failures identify the suite entry.
    character(len=*), parameter :: test_name = 'testThing'  ! Name used in PASS/FAIL messages

    ! Relative tolerance scaled to the kind under test.
    real(real64), parameter :: tol = 100.0_real64 * epsilon(1.0_real64)  ! Comparison tolerance

    ! NOTE: a variable may not share a derived-type name (Fortran is
    ! case-insensitive), hence 'l' rather than 'layer' next to type 'Layer'.
    type(Layer) :: l               ! Layer exercised by this test
    real(real64) :: x(2)           ! Fixed test input
    real(real64), allocatable :: y(:)  ! Output from the layer
    real(real64) :: want           ! Expected analytic value

    ! --- Arrange: deterministic data, no I/O needed ---------------------------
    l = layer_init(n_in=2, n_out=1)
    l%weights(1, :) = [2.0_real64, 3.0_real64]
    l%bias = [1.0_real64]

    x = [1.0_real64, 2.0_real64]

    ! --- Act ------------------------------------------------------------------
    y = l%forward(x)

    ! --- Assert: size ---------------------------------------------------------
    if (size(y) /= 1) then
        print '(A, 1X, A, 1X, A, 1X, I0)', 'FAIL', test_name, &
            'unexpected output size:', size(y)
        error stop 1
    end if

    ! --- Assert: value with explicit tolerance (never == on reals) -----------
    want = 2.0_real64 * 1.0_real64 + 3.0_real64 * 2.0_real64 + 1.0_real64
    if (abs(y(1) - want) > tol) then
        print '(A, 1X, A, 1X, A, 1X, ES15.6, 1X, A, 1X, ES15.6)', 'FAIL', &
            test_name, 'got', y(1), 'want', want
        error stop 1
    end if

    print '(A, 1X, A)', 'PASS', test_name

    ! Shared test helpers, if needed, belong under a `contains` section here.

end program testThing
