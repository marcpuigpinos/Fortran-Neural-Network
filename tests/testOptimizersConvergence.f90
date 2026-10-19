! AI Generated
program testOptimizersConvergence
    !! Sanity-check repeated `GradientDescent%update` steps on a quadratic.
    !!
    !! Minimizes the simple quadratic 0.5 * ||W - W*||^2 + 0.5 * ||b - b*||^2
    !! whose gradient is (W - W*) and (b - b*). With a fixed step size
    !! lr = 0.5 in (0, 1), iterated gradient descent contracts the error by
    !! a factor (1 - lr) per step, so after enough steps the parameters must
    !! approach (W*, b*). The test iterates updates until the parameter
    !! change falls below a tolerance and asserts the final parameters match
    !! the target W*/b*, exercising the repeated-update path. Prints
    !! `PASS testOptimizersConvergence` on success; prints a
    !! `FAIL testOptimizersConvergence ...` message and aborts with
    !! `error stop 1` if convergence is not reached.

    use, intrinsic :: iso_fortran_env, only: real64
    use mOptimizers, only: GradientDescent

    implicit none

    ! Test name reused in every PASS/FAIL message so failures identify the suite entry.
    character(len=*), parameter :: test_name = 'testOptimizersConvergence'
    real(real64), parameter :: tol = 1.0e-10_real64  ! Convergence tolerance on final parameters
    integer, parameter :: max_iter = 1000  ! Hard cap on iterations to avoid an infinite loop

    type(GradientDescent) :: opt  ! Concrete optimizer driving the loop
    real(real64) :: weights(3, 2)  ! Current iterate for the weight matrix
    real(real64) :: bias(3)  ! Current iterate for the bias vector
    real(real64) :: target_w(3, 2)  ! Quadratic minimiser W* for weights
    real(real64) :: target_b(3)  ! Quadratic minimiser b* for biases
    real(real64) :: d_weights(3, 2)  ! Gradient W - W* for the current iterate
    real(real64) :: d_bias(3)  ! Gradient b - b* for the current iterate
    real(real64), parameter :: lr = 0.5_real64  ! Fixed step size, in (0, 1)
    integer :: iter  ! Iteration counter

    target_w = reshape([1.0_real64, -2.0_real64, 0.5_real64, &
                        3.0_real64, -1.5_real64, 2.5_real64], [3, 2])
    target_b = [4.0_real64, -3.0_real64, 0.25_real64]

    ! Start from a clearly different point so movement is observable.
    weights = 0.0_real64
    bias = 0.0_real64

    do iter = 1, max_iter
        ! Gradient of 0.5*||x - target||^2 is simply (x - target).
        d_weights = weights - target_w
        d_bias = bias - target_b
        call opt%update(weights, bias, d_weights, d_bias, lr)
        if (maxval(abs(weights - target_w)) < tol .and. &
            maxval(abs(bias - target_b)) < tol) exit
    end do

    if (iter > max_iter) then
        print '(A, 1X, A, 1X, A, 1X, I0)', 'FAIL', test_name, &
            'failed to converge within iteration cap:', max_iter
        error stop 1
    end if

    if (any(abs(weights - target_w) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'weights did not converge to the quadratic minimiser'
        error stop 1
    end if

    if (any(abs(bias - target_b) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'biases did not converge to the quadratic minimiser'
        error stop 1
    end if

    print '(A, 1X, A)', 'PASS', test_name

end program testOptimizersConvergence
