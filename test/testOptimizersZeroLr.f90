! AI Generated
program testOptimizersZeroLr
    !! Verify that `GradientDescent%update` is a no-op when lr = 0.
    !!
    !! Runs one update with `learning_rate = 0` on a non-trivial weight
    !! matrix and bias vector with non-zero gradients and asserts the
    !! parameters are bit-for-bit unchanged (W == W0, b == b0). This pins
    !! the degenerate lr = 0 case of `W - lr*dW` against accidental
    !! assignment bugs. Prints `PASS testOptimizersZeroLr` on success;
    !! prints a `FAIL testOptimizersZeroLr ...` message and aborts with
    !! `error stop 1` on any change.

    use, intrinsic :: iso_fortran_env, only: real64
    use mOptimizers, only: GradientDescent

    implicit none

    ! Test name reused in every PASS/FAIL message so failures identify the suite entry.
    character(len=*), parameter :: test_name = 'testOptimizersZeroLr'

    type(GradientDescent) :: opt  ! Concrete optimizer under test
    real(real64) :: weights(2, 3)  ! Weight matrix updated in place
    real(real64) :: bias(2)  ! Bias vector updated in place
    real(real64) :: d_weights(2, 3)  ! Non-zero weight gradient
    real(real64) :: d_bias(2)  ! Non-zero bias gradient
    real(real64) :: w0(2, 3)  ! Saved copy of the initial weight matrix
    real(real64) :: b0(2)  ! Saved copy of the initial bias vector
    real(real64), parameter :: lr = 0.0_real64  ! Zero learning rate (no-op)

    weights = reshape([1.1_real64, -2.2_real64, 3.3_real64, &
                       -4.4_real64, 5.5_real64, -6.6_real64], [2, 3])
    bias = [7.7_real64, -8.8_real64]
    d_weights = reshape([9.0_real64, 9.0_real64, 9.0_real64, &
                         9.0_real64, 9.0_real64, 9.0_real64], [2, 3])
    d_bias = [-9.0_real64, 9.0_real64]

    w0 = weights
    b0 = bias

    call opt%update(weights, bias, d_weights, d_bias, lr)

    ! Bit-preservation check: no arithmetic happens when lr is zero, so any
    ! nonzero difference is a failure. abs(diff) > 0 avoids comparing reals
    ! for equality (-Wcompare-reals).
    if (any(abs(weights - w0) > 0.0_real64)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'weights changed even though learning_rate is zero'
        error stop 1
    end if

    if (any(abs(bias - b0) > 0.0_real64)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'biases changed even though learning_rate is zero'
        error stop 1
    end if

    print '(A, 1X, A)', 'PASS', test_name

end program testOptimizersZeroLr
