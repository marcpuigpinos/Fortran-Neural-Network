! AI Generated
program testDenseLayerForward
    !! Verify `DenseLayer%forward` produces y = matmul(W, x) + b numerically.
    !!
    !! Builds a hand-computed 3x2 dense layer (n_in = 2, n_out = 3) with
    !! rows of `W` set to [1, 2], [3, 4], [5, 6] and bias [10, 20, 30],
    !! then evaluates the affine forward pass on x = [1, 1]. The expected
    !! result [13, 27, 41] is checked BOTH as a hard-coded constant AND as
    !! `sum(W(i, :) * x) + b(i)` recomputed independently per row, so a
    !! future refactor that mutates the weight layout or the forward
    !! arithmetic is caught by either angle. Also asserts the result
    !! vector length equals `output_size` (and the `n_out` component).
    !! Prints `PASS testDenseLayerForward` on success; prints a
    !! `FAIL testDenseLayerForward ...` message and aborts with
    !! `error stop 1` on any mismatch.

    use, intrinsic :: iso_fortran_env, only: real64
    use mDenseLayer, only: DenseLayer, dense_init

    implicit none

    ! Test name reused in every PASS/FAIL message so failures identify the suite entry.
    character(len=*), parameter :: test_name = 'testDenseLayerForward'
    real(real64), parameter :: tol = 1.0e-14_real64  ! Absolute tolerance for element comparisons

    integer, parameter :: n_in = 2    ! Input dimension for this hand-built layer
    integer, parameter :: n_out = 3   ! Output dimension for this hand-built layer

    type(DenseLayer) :: layer  ! Concrete dense layer under test
    real(real64), parameter :: x(n_in) = [1.0_real64, 1.0_real64]  ! Fixed input vector
    ! Hard-coded expected y = W*x + b for the pinned weights and bias.
    real(real64), parameter :: expected_const(n_out) = [13.0_real64, 27.0_real64, 41.0_real64]
    real(real64), allocatable :: y(:)  ! Result of layer%forward(x) (allocatable by API)
    real(real64) :: expect_row(n_out)  ! Expected y recomputed independently per row
    integer :: i  ! Implied-do index for the row-wise reference constructor

    call dense_init(layer, n_in, n_out)

    ! Set parameters directly so the arithmetic test has non-zero weights
    ! and biases independent of the (currently zero-filling) initialiser.
    layer%weights(1, :) = [1.0_real64, 2.0_real64]
    layer%weights(2, :) = [3.0_real64, 4.0_real64]
    layer%weights(3, :) = [5.0_real64, 6.0_real64]
    layer%bias = [10.0_real64, 20.0_real64, 30.0_real64]

    y = layer%forward(x)

    ! The result length must equal n_out on every allocation-based call; a
    ! wrong shape here would silently propagate through a network stack.
    if (allocated(y)) then
        if (size(y) /= n_out) then
            print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
                'forward result length does not equal n_out'
            error stop 1
        end if
    else
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'forward returned an unallocated vector'
        error stop 1
    end if

    ! Cross-check against the hand-computed constant values [13, 27, 41].
    if (any(abs(y - expected_const) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'forward result does not match the hard-coded W*x + b values'
        error stop 1
    end if

    ! Cross-check against an independent row-wise sum, so a change in the
    ! hard-coded constant alone (or a subtle matmul transpose) is caught.
    expect_row = [(sum(layer%weights(i, :) * x) + layer%bias(i), i = 1, n_out)]
    if (any(abs(y - expect_row) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'forward result does not match an independent W(i,:)*x + b(i)'
        error stop 1
    end if

    print '(A, 1X, A)', 'PASS', test_name

end program testDenseLayerForward
