! AI Generated
program testOptimizersDispatch
    !! Verify polymorphic dispatch of the deferred `Optimizer%update` binding.
    !!
    !! Declares a `class(Optimizer), allocatable` entity allocated to a
    !! concrete `GradientDescent`, calls the type-bound `%update` through the
    !! abstract base, and asserts the concrete gradient-descent arithmetic
    !! (`W - lr*dW`, `b - lr*db`) actually runs. This confirms the deferred
    !! binding and `procedure :: update =>` override are wired up correctly.
    !! Prints `PASS testOptimizersDispatch` on success; prints a
    !! `FAIL testOptimizersDispatch ...` message and aborts with
    !! `error stop 1` on any mismatch.

    use, intrinsic :: iso_fortran_env, only: real64
    use mOptimizers, only: Optimizer, GradientDescent

    implicit none

    ! Test name reused in every PASS/FAIL message so failures identify the suite entry.
    character(len=*), parameter :: test_name = 'testOptimizersDispatch'
    real(real64), parameter :: tol = 1.0e-14_real64  ! Absolute tolerance for element comparisons

    class(Optimizer), allocatable :: opt  ! Abstract-handle allocated to a GradientDescent
    real(real64) :: weights(2, 2)  ! Weight matrix updated via the abstract handle
    real(real64) :: bias(2)  ! Bias vector updated via the abstract handle
    real(real64) :: d_weights(2, 2)  ! Weight gradient fed to the polymorphic update
    real(real64) :: d_bias(2)  ! Bias gradient fed to the polymorphic update
    real(real64) :: expect_w(2, 2)  ! Independently computed expected weights
    real(real64) :: expect_b(2)  ! Independently computed expected biases
    real(real64), parameter :: lr = 0.25_real64  ! Learning rate (eta) for the step

    allocate (GradientDescent :: opt)

    weights = reshape([5.0_real64, 6.0_real64, 7.0_real64, &
                       8.0_real64], [2, 2])
    bias = [1.0_real64, 2.0_real64]
    d_weights = reshape([1.0_real64, 2.0_real64, 3.0_real64, &
                         4.0_real64], [2, 2])
    d_bias = [0.5_real64, -0.5_real64]

    expect_w = weights - lr*d_weights
    expect_b = bias - lr*d_bias

    ! Dispatch through the abstract base; must select GradientDescent%update.
    call opt%update(weights, bias, d_weights, d_bias, lr)

    if (any(abs(weights - expect_w) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'polymorphic update did not run the gradient-descent step on weights'
        error stop 1
    end if

    if (any(abs(bias - expect_b) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'polymorphic update did not run the gradient-descent step on biases'
        error stop 1
    end if

    print '(A, 1X, A)', 'PASS', test_name

end program testOptimizersDispatch
