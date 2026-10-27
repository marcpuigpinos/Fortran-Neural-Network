! AI Generated
module mDenseLayer
    !! Dense (fully-connected) neural network layer.
    !!
    !! This internal module defines `DenseLayer`, the first concrete
    !! extension of `AbstractLayer`: it stores a weight matrix
    !! `W(n_out, n_in)` and a bias vector `b(n_out)` and applies the pure
    !! affine forward pass `y = matmul(W, x) + b`. The single-matmul layout
    !! (weights as out x in) is mandated by
    !! `.github/skills/neural-networks/SKILL.md` so the forward is one
    !! `matmul` call and backprop (owned by the future network driver)
    !! needs no transpose conventions.
    !!
    !! Construction is a separate non-pure `dense_init` subroutine because
    !! it allocates; the forward evaluation stays `pure`
    !! (`dense_forward`). Weight initialization is deliberately deferred:
    !! v1 zero-fills the parameters, and the randomized-init feature (with
    !! a seeding strategy per `.github/skills/neural-networks/SKILL.md`)
    !! lands with the optimizer/network integration. The symmetric-zero
    !! caveat of zero-initialized weights (identical neurons, symmetry
    !! never broken by training) is acknowledged in `dense_init` and must
    !! be resolved by that future feature before real training, NOT
    !! silently ignored.
    !!
    !! Design note (open components): `weights`, `bias`, `n_in`, and
    !! `n_out` are public components of the public type, mirroring the
    !! pragmatic simplicity of `mActivations` and `mOptimizers` (no getter
    !! ceremony). Tests and the future driver read them directly;
    !! construction/resizing goes through `dense_init` so shape invariants
    !! (`size(bias) == n_out`, `shape(W) == [n_out, n_in]`) are established
    !! in one place.
    !!
    !! @author Fortran-Neural-Network project
    !! @version 0.4.0
    !! @license MIT

    use, intrinsic :: iso_fortran_env, only: real64

    use mAbstractLayer, only: AbstractLayer

    implicit none

    private

    public :: DenseLayer
    public :: dense_init

    !! A dense (fully-connected) layer: y = W*x + b (no activation applied).
    !!
    !! Extends `AbstractLayer`, implementing its three deferred bindings
    !! (`forward`, `output_size`, `parameter_count`). The layer itself
    !! applies no activation function: activation is applied by whatever
    !! composes layers (the future network driver pairs each layer with an
    !! `Activation` from `mActivations`), keeping this type a pure affine
    !! transform.
    type, extends(AbstractLayer) :: DenseLayer
        real(real64), allocatable :: weights(:, :)  !! Weight matrix W (n_out x n_in)
        real(real64), allocatable :: bias(:)        !! Bias vector b (n_out)
        integer :: n_in = 0                         !! Input dimension (0 until dense_init)
        integer :: n_out = 0                        !! Output dimension (0 until dense_init)
    contains
        procedure :: forward => dense_forward                !! Affine forward pass
        procedure :: output_size => dense_output_size        !! Query output dimension
        procedure :: parameter_count => dense_parameter_count  !! Count trainable parameters
    end type DenseLayer

contains

    subroutine dense_init(self, n_in, n_out)
        !! Allocate and zero-initialize an untrained dense layer.
        !!
        !! Establishes the shape invariants `size(weights, 1) == n_out`,
        !! `size(weights, 2) == n_in`, `size(bias) == n_out`, and records
        !! the dimensions. Allocates, so this routine is not `pure`; all
        !! evaluation-side procedures on `DenseLayer` remain pure.
        !!
        !! Both weights and biases are set to zero. Weighted random
        !! initialization (Xavier/He with a stored seed, per
        !! `.github/skills/neural-networks/SKILL.md`) is deferred to a
        !! future feature together with the training driver: zero weights
        !! are fine for unit-testing shapes and forward arithmetic, but
        !! they make every neuron of a trained layer identical (symmetry
        !! never breaks), so real training MUST replace this fill first —
        !! documented here rather than hidden.
        !!
        !! Calling this routine repeatedly on the same layer is safe: any
        !! existing allocations are released first, so re-initializing (or
        !! resizing) an already allocated layer does not abort.
        class(DenseLayer), intent(inout) :: self  !! The layer (re)initialized in place
        integer, intent(in) :: n_in               !! Input dimension, positive
        integer, intent(in) :: n_out              !! Output dimension, positive

        ! Release prior storage so repeated init does not abort on an
        ! already allocated variable under -fcheck=all.
        if (allocated(self%weights)) deallocate(self%weights)
        if (allocated(self%bias)) deallocate(self%bias)

        allocate(self%weights(n_out, n_in))
        allocate(self%bias(n_out))

        self%weights = 0.0_real64
        self%bias = 0.0_real64
        self%n_in = n_in
        self%n_out = n_out
    end subroutine dense_init

    pure function dense_forward(self, x) result(y)
        !! Compute the layer output y = matmul(W, x) + b for one input.
        !!
        !! The result is allocatable to conform with
        !! `layer_forward_interface` (a purely assumed-shape result is not
        !! permitted for functions in standard Fortran; allocatable lets
        !! each implementation return its own length). Stateless given its
        !! arguments and side-effect-free, hence `pure`.
        !!
        !! The input length must equal `self%n_in`; `matmul` then yields
        !! the `n_out`-length pre-activation vector to which the bias is
        !! added.
        class(DenseLayer), intent(in) :: self  !! This layer (weights and bias applied)
        real(real64), intent(in) :: x(:)       !! Input vector (length must equal self%n_in)
        real(real64), allocatable :: y(:)      !! Output vector y = W*x + b (length self%n_out)

        y = matmul(self%weights, x) + self%bias
    end function dense_forward

    pure function dense_output_size(self) result(n)
        !! Return this layer's output dimension (n_out).
        class(DenseLayer), intent(in) :: self  !! This layer to query
        integer :: n                           !! Output dimension (n_out); 0 before dense_init

        n = self%n_out
    end function dense_output_size

    pure function dense_parameter_count(self) result(n)
        !! Return the number of trainable parameters: n_out*n_in + n_out.
        !!
        !! Counts the weight matrix entries plus the bias entries; used by
        !! the future network driver to size flat gradient buffers.
        class(DenseLayer), intent(in) :: self  !! This layer to query
        integer :: n                           !! Total trainable parameters (W entries + b entries)

        n = self%n_out * self%n_in + self%n_out
    end function dense_parameter_count

end module mDenseLayer
