! AI Generated
program testDenseLayerInit
    !! Verify `dense_init` records dimensions and deliberately zero-fills.
    !!
    !! v1 of the layer API zero-initialises weights and biases on purpose
    !! (see `dense_init` in `mDenseLayer.f90`): randomised Xavier/He init
    !! lands with the training driver, so the tests below pin the current
    !! contract that every entry is zero (compared within `tol`, since
    !! exact real equality is not portable) and that `n_in`/`n_out`
    !! match the requested dims. `output_size` must equal `n_out`
    !! immediately after init, before any weights have been assigned.
    !! A second shape is checked to prove the invariant survives repeated
    !! init calls. Prints `PASS testDenseLayerInit` on success; prints a
    !! `FAIL testDenseLayerInit ...` message and aborts with
    !! `error stop 1` on any mismatch.

    use, intrinsic :: iso_fortran_env, only: real64
    use mDenseLayer, only: DenseLayer, dense_init

    implicit none

    ! Test name reused in every PASS/FAIL message so failures identify the suite entry.
    character(len=*), parameter :: test_name = 'testDenseLayerInit'
    real(real64), parameter :: tol = 1.0e-14_real64  ! Absolute tolerance for the zero comparisons

    integer, parameter :: n_in = 5   ! Requested input dimension for the init check
    integer, parameter :: n_out = 4  ! Requested output dimension for the init check
    integer, parameter :: n_in2 = 2  ! Second requested input dimension (repeat init)
    integer, parameter :: n_out2 = 6  ! Second requested output dimension (repeat init)

    type(DenseLayer) :: layer  ! Layer whose zero-fill / bookkeeping is under test

    call dense_init(layer, n_in, n_out)

    ! The stored dimensions must equal what the caller asked for; the
    ! forward arithmetic itself depends on these counters matching the
    ! allocated shape.
    if (layer%n_in /= n_in) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'dense_init did not record the requested n_in'
        error stop 1
    end if
    if (layer%n_out /= n_out) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'dense_init did not record the requested n_out'
        error stop 1
    end if

    ! v1 deliberately zero-fills: pin every entry at zero within `tol`
    ! (comparing reals with `==` trips -Wcompare-reals and is not
    ! trustworthy). A future randomised-init feature MUST update this test
    ! alongside the initialiser change (do not silently relax it to a range check).
    if (.not. all(abs(layer%weights - 0.0_real64) <= tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'dense_init weights are not all zero (v1 contract)'
        error stop 1
    end if
    if (.not. all(abs(layer%bias - 0.0_real64) <= tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'dense_init bias is not all zero (v1 contract)'
        error stop 1
    end if

    ! output_size must reflect n_out the moment dense_init returns, with
    ! no parameters set. This is the read the future network driver uses
    ! for shape-checking between stacked layers.
    if (layer%output_size() /= n_out) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'output_size after dense_init does not equal n_out'
        error stop 1
    end if

    ! Re-running dense_init on a differently-shaped layer must fully
    ! overwrite the previous bookkeeping (not append or partially keep).
    call dense_init(layer, n_in2, n_out2)
    if (layer%n_in /= n_in2) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'repeated dense_init did not update n_in'
        error stop 1
    end if
    if (layer%n_out /= n_out2) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'repeated dense_init did not update n_out'
        error stop 1
    end if
    if (.not. all(abs(layer%weights - 0.0_real64) <= tol)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'repeated dense_init left non-zero weights'
        error stop 1
    end if

    print '(A, 1X, A)', 'PASS', test_name

end program testDenseLayerInit
