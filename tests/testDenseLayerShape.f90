! AI Generated
program testDenseLayerShape
    !! Verify `dense_init` establishes shape invariants on `DenseLayer`.
    !!
    !! Initialises two differently-shaped layers (n_in/n_out = 3/2 and
    !! 4/3) and asserts `size(weights, 1) == n_out`, `size(weights, 2) ==
    !! n_in` and `size(bias) == n_out` in both cases, so the (out x in)
    !! weight layout is pinned. An un-initialised `type(DenseLayer)` is
    !! then checked to have `output_size() == 0`, `parameter_count() == 0`
    !! and unallocated `weights`, confirming the default state is a fully
    !! empty layer rather than something with dangling dimensions.
    !! Prints `PASS testDenseLayerShape` on success; prints a
    !! `FAIL testDenseLayerShape ...` message and aborts with
    !! `error stop 1` on any mismatch.

    use, intrinsic :: iso_fortran_env, only: real64
    use mDenseLayer, only: DenseLayer, dense_init

    implicit none

    ! Test name reused in every PASS/FAIL message so failures identify the suite entry.
    character(len=*), parameter :: test_name = 'testDenseLayerShape'

    integer, parameter :: n_in_a = 3    ! First layer input dimension
    integer, parameter :: n_out_a = 2   ! First layer output dimension
    integer, parameter :: n_in_b = 4    ! Second layer input dimension
    integer, parameter :: n_out_b = 3   ! Second layer output dimension

    type(DenseLayer) :: layer_a  ! First shaped layer under test
    type(DenseLayer) :: layer_b  ! Second shaped layer under test
    type(DenseLayer) :: fresh    ! Never-initialised layer: default empty state

    call dense_init(layer_a, n_in_a, n_out_a)
    if (size(layer_a%weights, 1) /= n_out_a) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'layer_a weights rows do not equal n_out'
        error stop 1
    end if
    if (size(layer_a%weights, 2) /= n_in_a) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'layer_a weights columns do not equal n_in'
        error stop 1
    end if
    if (size(layer_a%bias) /= n_out_a) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'layer_a bias length does not equal n_out'
        error stop 1
    end if

    call dense_init(layer_b, n_in_b, n_out_b)
    if (size(layer_b%weights, 1) /= n_out_b) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'layer_b weights rows do not equal n_out'
        error stop 1
    end if
    if (size(layer_b%weights, 2) /= n_in_b) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'layer_b weights columns do not equal n_in'
        error stop 1
    end if
    if (size(layer_b%bias) /= n_out_b) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'layer_b bias length does not equal n_out'
        error stop 1
    end if

    ! A freshly-declared DenseLayer must be completely empty: zero-size
    ! reports from output_size/parameter_count and no allocations.
    if (fresh%output_size() /= 0) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'un-initialised layer reports non-zero output_size'
        error stop 1
    end if
    if (fresh%parameter_count() /= 0) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'un-initialised layer reports non-zero parameter_count'
        error stop 1
    end if
    if (allocated(fresh%weights)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'un-initialised layer has allocated weights'
        error stop 1
    end if
    if (allocated(fresh%bias)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'un-initialised layer has allocated bias'
        error stop 1
    end if

    print '(A, 1X, A)', 'PASS', test_name

end program testDenseLayerShape
