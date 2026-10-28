! AI Generated
program testDenseLayerDispatch
    !! Verify polymorphic dispatch of `DenseLayer` through `AbstractLayer`.
    !!
    !! This is the headline deliverable of the abstract-layer feature: a
    !! `class(AbstractLayer), allocatable` handle allocated from a
    !! `DenseLayer` source must resolve `%output_size`, `%parameter_count`
    !! and `%forward` to the concrete dense implementations. Concretely,
    !! a 3x2 W (rows [1,2], [3,4], [5,6]) with bias [10, 20, 30] yields
    !! y = W*x + b = [13, 27, 41] for x = [1, 1]; the same expected array
    !! is recomputed independently with the row-wise sum formula, and the
    !! output_size / parameter_count queries must return 3 and 3*2 + 3 = 9
    !! respectively. Any vtable wiring error in `mDenseLayer` shows up
    !! here as a wrong-shape or wrong-value answer through the base type.
    !! Prints `PASS testDenseLayerDispatch` on success; prints a
    !! `FAIL testDenseLayerDispatch ...` message and aborts with
    !! `error stop 1` on any mismatch.

    use, intrinsic :: iso_fortran_env, only: real64
    use mAbstractLayer, only: AbstractLayer
    use mDenseLayer, only: DenseLayer, dense_init

    implicit none

    ! Test name reused in every PASS/FAIL message so failures identify the suite entry.
    character(len=*), parameter :: test_name = 'testDenseLayerDispatch'
    real(real64), parameter :: tol = 1.0e-14_real64  ! Absolute tolerance for element comparisons

    integer, parameter :: n_in = 2    ! Input dimension for the concrete source layer
    integer, parameter :: n_out = 3   ! Output dimension for the concrete source layer
    integer, parameter :: expect_params = n_out * n_in + n_out  ! 3*2 + 3 = 9

    real(real64), parameter :: x(n_in) = [1.0_real64, 1.0_real64]  ! Fixed input vector
    ! Independently recomputed reference for y = W*x + b on the fixed weight matrix.
    real(real64) :: expect_y(n_out)
    integer :: i  ! Implied-do index for the row-wise reference constructor

    ! Build the concrete source first so init + weight assignment happen
    ! via the concrete type (avoids needing a SELECT TYPE on a polymorphic
    ! handle before the dispatch is exercised).
    type(DenseLayer) :: dense_src  ! Concrete layer used as the source of allocation

    class(AbstractLayer), allocatable :: layer  ! Abstract handle allocated from dense_src
    real(real64), allocatable :: y(:)  ! Result of polymorphic layer%forward(x)

    call dense_init(dense_src, n_in, n_out)
    dense_src%weights(1, :) = [1.0_real64, 2.0_real64]
    dense_src%weights(2, :) = [3.0_real64, 4.0_real64]
    dense_src%weights(3, :) = [5.0_real64, 6.0_real64]
    dense_src%bias = [10.0_real64, 20.0_real64, 30.0_real64]

    ! Allocate the polymorphic entity from the concrete source: this copies
    ! the components AND retains the dynamic type, so vtable dispatch via
    ! the abstract bindings must resolve to the dense implementations.
    allocate (layer, source=dense_src)

    ! output_size dispatched through AbstractLayer must return n_out.
    if (layer%output_size() /= n_out) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'polymorphic output_size did not dispatch to DenseLayer implementation'
        error stop 1
    end if

    ! parameter_count dispatched through AbstractLayer must equal n_out*n_in + n_out.
    if (layer%parameter_count() /= expect_params) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'polymorphic parameter_count did not dispatch to DenseLayer implementation'
        error stop 1
    end if

    ! forward dispatched through AbstractLayer must return the affine result.
    y = layer%forward(x)
    if (.not. allocated(y)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'polymorphic forward returned an unallocated vector'
        error stop 1
    end if
    if (size(y) /= n_out) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'polymorphic forward result length does not equal n_out'
        error stop 1
    end if

    ! Recompute W*x + b independently from the concrete source's weights
    ! (same values, different code path), and compare against the
    ! dispatch-produced y. Equality proves the polymorphic call really
    ! ran DenseLayer's arithmetic rather than some other binding.
    expect_y = [(sum(dense_src%weights(i, :) * x) + dense_src%bias(i), i = 1, n_out)]
    if (any(abs(y - expect_y) > tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'polymorphic forward result does not match independent W*x + b'
        error stop 1
    end if

    print '(A, 1X, A)', 'PASS', test_name

end program testDenseLayerDispatch
