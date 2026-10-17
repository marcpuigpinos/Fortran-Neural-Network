! AI Generated
module mFortranNeuralNetwork
    !! Fortran Neural Network library.
    !!
    !! Provides the public API of the library; currently exposes the
    !! library version so that callers never depend on a hard-coded
    !! string. The internal version constant is kept in sync with the
    !! VERSION file at the repo root.
    !!
    !! @author Fortran-Neural-Network project
    !! @version 0.0.0
    !! @license MIT

    implicit none

    private

    public :: get_version

    ! Single source of truth for the library version; kept in sync with
    ! the VERSION file.
    character(len=*), private, parameter :: library_version = "0.0.0"

contains

    pure function get_version() result(version)
        !! Return the current library version string.
        !!
        !! Provided so consumers can query the version at runtime without
        !! reading build metadata; pure and allocation-free beyond the
        !! result.
        character(len=:), allocatable :: version  !! Current library version string

        version = library_version
    end function get_version

end module mFortranNeuralNetwork
