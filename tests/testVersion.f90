! AI Generated
program testVersion
    !! Verify the library version reporting of `get_version`.
    !!
    !! Reads the VERSION file at the repo root at runtime (the test is
    !! executed from the repo root by `make test`) and asserts that the
    !! string returned by the library equals its trimmed contents and
    !! that the allocation length matches exactly. Prints
    !! `PASS testVersion` on success; prints a `FAIL testVersion ...`
    !! message and aborts with `error stop 1` on any mismatch or read
    !! failure.

    use mFortranNeuralNetwork, only: get_version

    implicit none

    ! Test name reused in every message so failures identify the suite entry.
    character(len=*), parameter :: test_name = 'testVersion'  ! Name used in PASS/FAIL messages

    character(len=:), allocatable :: version  ! Version string returned by the library
    character(len=256) :: raw_line  ! Raw first line read from the VERSION file
    character(len=:), allocatable :: expected_version  ! Trimmed contents of the VERSION file
    integer :: unit  ! Connected unit number for the VERSION file
    integer :: ios  ! I/O status of the VERSION file read

    ! The library must report exactly what the VERSION file contains; the
    ! file is the single source of truth, read here rather than copied.
    version = get_version()

    open (newunit=unit, file='VERSION', status='old', action='read', &
          iostat=ios)
    if (ios /= 0) then
        print '(A, 1X, A, 1X, A, 1X, A, 1X, I0)', 'FAIL', test_name, &
            'cannot read VERSION file, iostat:', ios
        error stop 1
    end if

    raw_line = ''
    read (unit, '(A)', iostat=ios) raw_line
    close (unit)
    if (len_trim(raw_line) == 0) then
        print '(A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'VERSION file is empty'
        error stop 1
    end if

    ! Trim handles both a trailing newline artefact and stray whitespace.
    expected_version = trim(adjustl(raw_line))

    if (expected_version /= version) then
        print '(A, 1X, A, 1X, A, 1X, A, 1X, A, 1X, A)', 'FAIL', test_name, &
            'unexpected version value: got', trim(version), 'expected', &
            expected_version
        error stop 1
    end if

    ! Guard against a silently wrong allocation length even if the
    ! comparison above passed.
    if (len(version) /= len(expected_version)) then
        print '(A, 1X, A, 1X, A, 1X, I0)', 'FAIL', test_name, &
            'unexpected version length:', len(version)
        error stop 1
    end if

    print '(A, 1X, A)', 'PASS', test_name

end program testVersion
