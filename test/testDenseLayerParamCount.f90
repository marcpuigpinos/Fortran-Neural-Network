! AI Generated
program testDenseLayerParamCount
    !! Verify `DenseLayer%parameter_count` on two hand-computed shapes.
    !!
    !! For a weight matrix laid out W(n_out, n_in) plus a bias of length
    !! n_out, the trainable parameter count is `n_out * n_in + n_out`. The
    !! 3/2 and 4/3 shapes below cover two different (in, out) pairings to
    !! detect swapped formulas; the same count must also equal
    !! `size(weights) + size(bias)` at runtime, which guards against a
    !! mismatch between the analytic count and the actual allocation. An
    !! un-initialised layer reports zero. Prints `PASS
    !! testDenseLayerParamCount` on success; prints a
    !! `FAIL testDenseLayerParamCount ...` message and aborts with
    !! `error stop 1` on any mismatch.

    use, intrinsic :: iso_fortran_env, only: real64
    use mDenseLayer, only: DenseLayer, dense_init

    implicit none

    ! Test name reused in every PASS/FAIL message so failures identify the suite entry.
    character(len=*), parameter :: test_name = 'testDenseLayerParamCount'

    integer, parameter :: n_in_a = 3     ! First shape input dimension
    integer, parameter :: n_out_a = 2    ! First shape output dimension
    integer, parameter :: n_in_b = 4     ! Second shape input dimension
    integer, parameter :: n_out_b = 3    ! Second shape output dimension
    integer, parameter :: expect_a = n_out_a * n_in_a + n_out_a  ! 2*3 + 2 = 8
    integer, parameter :: expect_b = n_out_b * n_in_b + n_out_b  ! 3*4 + 3 = 15

    type(DenseLayer) :: layer_a  ! First shaped layer under test
    type(DenseLayer) :: layer_b  ! Second shaped layer under test
    type(DenseLayer) :: fresh    ! Un-initialised layer: zero parameter count

    call dense_init(layer_a, n_in_a, n_out_a)

    ! Analytic n_out*n_in + n_out formula (hand-computed to 8 above).
    if (layer_a%parameter_count() /= expect_a) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'parameter_count does not equal n_out*n_in + n_out (shape 3x2)'
        error stop 1
    end if
    ! Same count derived from the allocation itself: catches a mismatch
    ! between the formula and the array dimensions allocated by init.
    if (layer_a%parameter_count() /= size(layer_a%weights) + size(layer_a%bias)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'parameter_count does not equal size(weights) + size(bias) (shape 3x2)'
        error stop 1
    end if

    call dense_init(layer_b, n_in_b, n_out_b)

    ! A different shape guards against a swapped-formula bug: with n_in=4
    ! and n_out=3 the count 15 differs from any 4*3+3 vs 3*4+4 confusion.
    if (layer_b%parameter_count() /= expect_b) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'parameter_count does not equal n_out*n_in + n_out (shape 4x3)'
        error stop 1
    end if
    if (layer_b%parameter_count() /= size(layer_b%weights) + size(layer_b%bias)) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'parameter_count does not equal size(weights) + size(bias) (shape 4x3)'
        error stop 1
    end if

    ! Fresh state must be reported as zero trainable scalars: this is the
    ! value the future driver sees before any dense_init has run.
    if (fresh%parameter_count() /= 0) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'un-initialised layer reports a non-zero parameter_count'
        error stop 1
    end if

    print '(A, 1X, A)', 'PASS', test_name

end program testDenseLayerParamCount
