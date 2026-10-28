! AI Generated
module mAbstractLayer
    !! Abstract base type for all neural network layers.
    !!
    !! This internal module defines the layer abstraction prescribed by
    !! `docs/memory/API_DESIGN.md` (section 3): an abstract `AbstractLayer`
    !! base with deferred `forward`, `output_size`, and `parameter_count`
    !! bindings. Concrete layer types (starting with `DenseLayer` in
    !! `mDenseLayer`) extend this base and supply the implementations.
    !!
    !! The forward-only design is intentional for v1: backward/gradient
    !! methods are deliberately excluded here because the network driver
    !! owns backpropagation (see `docs/memory/API_DESIGN.md` section 3).
    !! The `parameter_count` binding lets the driver size flat gradient
    !! buffers without knowing layer internals.
    !!
    !! Design note (allocatable result): the abstract `forward` interface
    !! cannot fix the output length from the base type alone (only the
    !! concrete implementation knows `n_out`), so the result is declared
    !! `allocatable`. Concrete implementations allocate the correct size;
    !! callers receive the right dimension automatically.
    !!
    !! The module deliberately depends on nothing but `iso_fortran_env`:
    !! it must compile independently and carries no activation or weight
    !! logic of its own.
    !!
    !! @author Fortran-Neural-Network project
    !! @version 0.4.0
    !! @license MIT

    use, intrinsic :: iso_fortran_env, only: real64

    implicit none

    private

    public :: AbstractLayer

    !! Abstract base for all neural network layer kinds.
    !!
    !! A concrete extension supplies three deferred bindings: `forward`
    !! (pure evaluation of the layer's output for a single input vector),
    !! `output_size` (the output dimension this layer produces), and
    !! `parameter_count` (total trainable scalars: weights plus biases).
    !! The base holds no state; all shape and parameter data live in the
    !! concrete extensions.
    type, abstract :: AbstractLayer
    contains
        procedure(layer_forward_interface), deferred :: forward              !! Evaluate the layer
        procedure(layer_output_size_interface), deferred :: output_size  !! Query output dimension
        procedure(layer_param_count_interface), deferred :: parameter_count  !! Count parameters
    end type AbstractLayer

    !! Contract for a pure forward pass through a layer (see `AbstractLayer%forward`).
    !!
    !! Declared after `AbstractLayer` so its `class(AbstractLayer)` dummy
    !! resolves; the reference to this interface in the type-binding above
    !! is an allowed forward reference for a type-bound procedure (same
    !! pattern used in `mActivations` and `mOptimizers`).
    !!
    !! The result is allocatable because the abstract interface cannot
    !! determine the output length from its arguments alone — only the
    !! concrete implementation knows `n_out`.
    abstract interface
        pure function layer_forward_interface(self, x) result(y)
            !! Produce the layer output for input vector `x`.
            import :: AbstractLayer, real64
            implicit none
            class(AbstractLayer), intent(in) :: self  !! The layer to evaluate
            real(real64), intent(in) :: x(:)  !! Input vector (length = layer input dim)
            real(real64), allocatable :: y(:)         !! Output vector of length output_size(self)
        end function layer_forward_interface
    end interface

    !! Contract for querying the output dimension (see `AbstractLayer%output_size`).
    !!
    !! Declared after `AbstractLayer` for the same forward-reference reason
    !! as `layer_forward_interface`. The network driver uses this value to
    !! validate layer-to-layer shape compatibility and to allocate caches.
    abstract interface
        pure function layer_output_size_interface(self) result(n)
            !! Return the number of outputs this layer produces.
            import :: AbstractLayer
            implicit none
            class(AbstractLayer), intent(in) :: self  !! The layer to query
            integer :: n                              !! Output dimension (n_out), positive
        end function layer_output_size_interface
    end interface

    !! Contract for counting trainable parameters (see `AbstractLayer%parameter_count`).
    !!
    !! Declared after `AbstractLayer` for the same forward-reference reason.
    !! The network driver calls this to size flat gradient vectors and
    !! optimizer state buffers. For a dense layer the count is
    !! `n_out * n_in + n_out`.
    abstract interface
        pure function layer_param_count_interface(self) result(n)
            !! Return the total number of trainable scalars in the layer.
            import :: AbstractLayer
            implicit none
            class(AbstractLayer), intent(in) :: self  !! The layer to query
            integer :: n                              !! Total trainable parameters, non-negative
        end function layer_param_count_interface
    end interface

end module mAbstractLayer
