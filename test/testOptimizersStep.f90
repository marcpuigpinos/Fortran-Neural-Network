! AI Generated
program testOptimizersStep
    !! Verify the exact arithmetic of one `GradientDescent%update` step.
    !!
    !! Applies a single gradient-descent step to a known 2x3 weight matrix
    !! and a length-2 bias vector with a known learning rate and asserts the
    !! in-place results satisfy `W_new == W - lr*dW` and `b_new == b - lr*db`
    !! within a tight tolerance. Also asserts the gradient arrays
    !! `d_weights`/`d_bias` are left unmodified by the update (they are
    !! `intent(in)` and the implementation must not write through them).
    !! Prints `PASS testOptimizersStep` on success; prints a
    !! `FAIL testOptimizersStep ...` message and aborts with `error stop 1`
    !! on any mismatch.

    use, intrinsic :: iso_fortran_env, only: real64
    use mOptimizers, only: GradientDescent

    implicit none

    ! Test name reused in every PASS/FAIL message so failures identify the suite entry.
    character(len=*), parameter :: test_name = 'testOptimizersStep'
    real(real64), parameter :: tol = 1.0e-14_real64  ! Absolute tolerance for element comparisons

    type(GradientDescent) :: opt  ! Concrete optimizer under test
    real(real64) :: weights(2, 3)  ! Initial weight matrix (out x in)
    real(real64) :: bias(2)  ! Initial bias vector (out)
    real(real64) :: d_weights(2, 3)  ! Weight gradient fed to update
    real(real64) :: d_bias(2)  ! Bias gradient fed to update
    real(real64) :: expect_w(2, 3)  ! Independently computed expected weights
    real(real64) :: expect_b(2)  ! Independently computed expected biases
    real(real64) :: w0(2, 3)  ! Saved copy of the initial weight matrix
    real(real64) :: b0(2)  ! Saved copy of the initial bias vector
    real(real64) :: dw0(2, 3)  ! Saved copy of the initial weight gradient
    real(real64) :: db0(2)  ! Saved copy of the initial bias gradient
    real(real64), parameter :: lr = 0.3_real64  ! Learning rate (eta) for the step

    weights = reshape([1.0_real64, 2.0_real64, 3.0_real64, &
                       4.0_real64, 5.0_real64, 6.0_real64], [2, 3])
    bias = [10.0_real64, 20.0_real64]
    d_weights = reshape([0.5_real64, -0.25_real64, 1.5_real64, &
                         -1.0_real64, 0.125_real64, 2.0_real64], [2, 3])
    d_bias = [3.0_real64, -4.0_real64]

    ! Preserve the inputs so the no-write-through check below has a baseline.
    w0 = weights
    b0 = bias
    dw0 = d_weights
    db0 = d_bias

    ! Expected result computed independently of the library code path.
    expect_w = w0 - lr*d_weights
    expect_b = b0 - lr*d_bias

    call opt%update(weights, bias, d_weights, d_bias, lr)

    if (any(abs(weights - expect_w) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'updated weights differ from W - lr*dW'
        error stop 1
    end if

    if (any(abs(bias - expect_b) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'updated biases differ from b - lr*db'
        error stop 1
    end if

    ! The gradients are intent(in); update must not mutate them at all.
    ! Bit-preservation check: no arithmetic happens here, so any nonzero
    ! difference is a failure. Written as abs(diff) > 0 to avoid comparing
    ! reals for equality (-Wcompare-reals).
    if (any(abs(d_weights - dw0) > 0.0_real64) .or. &
        any(abs(d_bias - db0) > 0.0_real64)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'update modified the intent(in) gradient arrays'
        error stop 1
    end if

    print '(A, 1X, A)', 'PASS', test_name

end program testOptimizersStep
