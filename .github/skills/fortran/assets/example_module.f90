! AI Generated
! Template F2008 library module. Copy, rename, and adapt. Follow AGENTS.md:
! marker at top, m+PascalCase module name, private-by-default, FORD '!!' docs
! BELOW the entity, component/argument docs with trailing '!!', 4-space indent.
module mLayerExample
    !! Dense (fully-connected) layer example module.
    !!
    !! Stores a weight matrix and bias vector and applies a linear
    !! activation. Demonstrates the canonical module skeleton: encapsulation,
    !! a constructor enforcing invariants, and a pure type-bound procedure.
    !!
    !! @author Fortran-Neural-Network project
    !! @version 0.0.0
    !! @license MIT
    use, intrinsic :: iso_fortran_env, only: real64, error_unit

    implicit none

    private

    public :: Layer
    public :: layer_init

    !! A dense neural network layer holding weights and biases.
    type :: Layer
        real(real64), allocatable :: weights(:,:)  !! Weight matrix (n_out x n_in)
        real(real64), allocatable :: bias(:)       !! Bias vector (n_out)
    contains
        procedure :: forward => layer_forward  !! Evaluate the affine transform
        procedure :: size_in => layer_size_in  !! Number of inputs
        procedure :: size_out => layer_size_out  !! Number of outputs
    end type Layer
contains

    function layer_init(n_in, n_out) result(self)
        !! Construct a Layer with given input and output sizes, uninitialized.
        integer, intent(in) :: n_in   !! Number of input units (> 0)
        integer, intent(in) :: n_out  !! Number of output units (> 0)
        type(Layer) :: self           !! The constructed layer
        integer :: stat                !! Allocation status

        if (n_in <= 0 .or. n_out <= 0) then
            write (error_unit, '(A, 1X, I0, 1X, I0)') 'layer_init: bad sizes', &
                n_in, n_out
            error stop 1
        end if

        allocate (self%weights(n_out, n_in), stat=stat)
        if (stat /= 0) error stop 'layer_init: weight allocation failed'
        allocate (self%bias(n_out), stat=stat)
        if (stat /= 0) error stop 'layer_init: bias allocation failed'
    end function layer_init

    pure function layer_forward(self, x) result(y)
        !! Apply the affine transform of `self` to input vector `x`.
        class(Layer), intent(in) :: self   !! The layer to evaluate
        real(real64), intent(in) :: x(:)   !! Input vector (length = size_in)
        real(real64) :: y(size(self%bias))  !! Output vector (length = size_out)

        ! Contract: caller must pass x of length size_in; bounds are checked
        ! only under -fcheck=all, so tests assert length explicitly.
        y = matmul(self%weights, x) + self%bias
    end function layer_forward

    pure function layer_size_in(self) result(n)
        !! Return the number of inputs the layer expects.
        class(Layer), intent(in) :: self  !! The layer to query
        integer :: n                       !! Input dimension, 0 if unallocated

        if (allocated(self%weights)) then
            n = size(self%weights, 2)
        else
            n = 0
        end if
    end function layer_size_in

    pure function layer_size_out(self) result(n)
        !! Return the number of outputs the layer produces.
        class(Layer), intent(in) :: self  !! The layer to query
        integer :: n                       !! Output dimension, 0 if unallocated

        if (allocated(self%bias)) then
            n = size(self%bias)
        else
            n = 0
        end if
    end function layer_size_out

end module mLayerExample
