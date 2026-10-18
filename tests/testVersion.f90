! AI Generated
program testVersion
    !! Verify the library version reporting of `get_version`.
    !!
    !! Checks that the string returned by the library equals the expected
    !! VERSION-synced string (currently '0.0.1') and that its allocation
    !! length matches the expected string's length exactly. Prints
    !! `PASS testVersion` on success; prints a `FAIL testVersion ...`
    !! message and aborts with `error stop 1` on any mismatch.

    use mFortranNeuralNetwork, only: get_version

    implicit none

    ! Test name reused in every message so failures identify the suite entry.
    character(len=*), parameter :: test_name = 'testVersion'  !! Name used in PASS/FAIL messages
    character(len=*), parameter :: expected_version = '0.0.1'  !! Version matching the VERSION file

    character(len=:), allocatable :: version  !! Version string returned by the library

    ! The library must report the version kept in sync with the VERSION file.
    version = get_version()

    if (version /= expected_version) then
        print '(A, 1X, A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'unexpected version value:', version
        error stop 1
    end if

    ! The expected string has exactly five characters; guard against a
    ! silently wrong allocation length even if the comparison above passed.
    if (len(version) /= len(expected_version)) then
        print '(A, 1X, A, 1X, A, 1X, I0)', 'FAIL', test_name, &
            'unexpected version length:', len(version)
        error stop 1
    end if

    print '(A, 1X, A)', 'PASS', test_name

end program testVersion
