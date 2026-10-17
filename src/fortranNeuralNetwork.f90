! AI Generated
module mFortranNeuralNetwork

    implicit none

    private

    public :: get_version

    ! Single source of truth for the library version so that callers never
    ! depend on a hard-coded string; kept in sync with the VERSION file.
    character(len=*), private, parameter :: library_version = "0.0.0"

contains

    ! Return the current library version string.
    ! Provided so consumers can query the version at runtime without
    ! reading build metadata; pure and allocation-free beyond the result.
    pure function get_version() result(version)
        character(len=:), allocatable :: version

        version = library_version
    end function get_version

end module mFortranNeuralNetwork
