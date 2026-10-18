! AI Generated
module mFortranNeuralNetwork
    !! Fortran Neural Network library.
    !!
    !! Provides the public API of the library; currently exposes the
    !! library version so that callers never depend on a hard-coded
    !! string. The version originates from the generated `mVersion`
    !! module, which the build derives from the VERSION file at the repo
    !! root, keeping a single source of truth.
    !!
    !! @author Fortran-Neural-Network project
    !! @version 0.0.1
    !! @license MIT

    ! The version constant is generated at build time from the VERSION
    ! file (see `mVersion`); no version literal lives in this source.
    use mVersion, only: library_version

    implicit none

    private

    public :: get_version

contains

    pure function get_version() result(version)
        !! Return the current library version string.
        !!
        !! Provided so consumers can query the version at runtime without
        !! reading build metadata; pure and allocation-free beyond the
        !! result. The value is supplied by the generated version module.
        character(len=:), allocatable :: version  !! Current library version string

        version = library_version
    end function get_version

end module mFortranNeuralNetwork
