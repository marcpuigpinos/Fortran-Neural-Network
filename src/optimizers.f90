! AI Generated
module mOptimizers
    !! Parameter-update strategies for training a dense neural network.
    !!
    !! This internal module defines the optimizer abstraction prescribed by
    !! `docs/memory/API_DESIGN.md` (sections 3, 4, 5, 6, 10). It follows the
    !! "separate update pass" pattern from the neural-network implementation
    !! skill: forward and backward passes stay pure and only the optimizer's
    !! `update` mutates parameters (W -= lr*dW, b -= lr*db). Keeping it as a
    !! deferred type-binding lets future strategies (momentum, Adam) drop in
    !! without touching backpropagation.
    !!
    !! The module deliberately depends on nothing but `iso_fortran_env`: it
    !! must compile independently of `mLayer`/`mNetwork`, which do not exist
    !! yet. `Optimizer` is an opaque strategy — it carries no state, so plain
    !! gradient descent needs no constructor.
    !!
    !! Design note (rank/shape): `update` operates on a single layer's weight
    !! matrix and bias vector rather than a generic shape-erased buffer. This
    !! keeps the binding strongly typed (matching the `W(n_out, n_in)`,
    !! `b(n_out)` layout throughout the library) at the cost of one binding
    !! shape; per-layer parameters are simply looped over by the training
    !! driver. An abstract/rank-agnostic `class(real(real64))` array would be
    !! more general but loses the explicit weight/bias distinction this design
    !! wants.
    !!
    !! @author Fortran-Neural-Network project
    !! @version 0.1.0
    !! @license MIT

    use, intrinsic :: iso_fortran_env, only: real64

    implicit none

    private

    public :: Optimizer
    public :: GradientDescent

    !! Abstract base for parameter-update strategies.
    !!
    !! A concrete extension supplies the `update` binding, which performs one
    !! in-place optimization step for a single layer's weights and biases from
    !! their gradients. The base holds no state; stateful optimizers (momentum,
    !! Adam) add their own components in their own extension.
    type, abstract :: Optimizer
    contains
        procedure(update_interface), deferred :: update  !! Apply one optimization step
    end type Optimizer

    !! Contract for a single parameter-update step (see `Optimizer%update`).
    !!
    !! Declared after `Optimizer` so its `class(Optimizer)` dummy resolves; the
    !! reference to this interface in the type-binding above is an allowed
    !! forward reference for a type-bound procedure.
    abstract interface
        subroutine update_interface(self, weights, bias, d_weights, d_bias, &
                                    learning_rate)
            !! One optimization step: in-place gradient-based parameter update.
            import :: Optimizer, real64
            implicit none
            class(Optimizer), intent(inout) :: self  !! The optimizer applying the step
            real(real64), intent(inout) :: weights(:, :)  !! Weight matrix (out x in) (in-place)
            real(real64), intent(inout) :: bias(:)        !! Bias vector (out), updated in place
            real(real64), intent(in) :: d_weights(:, :)   !! Gradient dL/dW, same shape as W
            real(real64), intent(in) :: d_bias(:)         !! Gradient dL/dbias, same shape as `bias`
            real(real64), intent(in) :: learning_rate     !! Step size (eta), non-negative
        end subroutine update_interface
    end interface

    !! Plain (full-batch) gradient descent: W = W - lr*dW, b = b - lr*db.
    !!
    !! The first concrete optimizer in the hierarchy. It computes the classic
    !! deterministic gradient-descent step over the gradients it is given; when
    !! the caller backpropagates over the whole training set this is full-batch
    !! gradient descent, and over a mini-batch it is stochastic gradient
    !! descent — the optimizer itself is agnostic to how the gradients were
    !! formed. Future derivatives of `Optimizer` (momentum, Adam) are planned;
    !! per `docs/memory/API_DESIGN.md` (section 11) they are deferred and are
    !! NOT implemented here.
    type, extends(Optimizer) :: GradientDescent
    contains
        procedure :: update => gradient_descent_update  !! Apply the gradient-descent step
    end type GradientDescent

contains

    subroutine gradient_descent_update(self, weights, bias, d_weights, d_bias, &
                                       learning_rate)
        !! Apply one plain gradient-descent step to `weights` and `bias`.
        !!
        !! Implements W = W - learning_rate*dW and b = b - learning_rate*db
        !! element-wise. The routine mutates its arguments by design and is
        !! therefore NOT `pure`; the forward/backward passes that produce the
        !! gradients remain side-effect-free, isolating all mutation here.
        !!
        !! Shapes must match: `d_weights` conforms to `weights` and `d_bias`
        !! conforms to `bias`. The `self` argument is unused by this concrete
        !! strategy but is required by the deferred-binding contract and is
        !! used by future stateful optimizers.
        ! `self` is intentionally unused here: plain gradient descent is
        ! stateless, but the deferred binding contract requires the dummy.
        class(GradientDescent), intent(inout) :: self  !! This optimizer (state unused for plain GD)
        real(real64), intent(inout) :: weights(:, :)  !! Weight matrix (out x in), updated in place
        real(real64), intent(inout) :: bias(:)        !! Bias vector (out), updated in place
        real(real64), intent(in) :: d_weights(:, :)   !! Gradient dL/dW, same shape as W
        real(real64), intent(in) :: d_bias(:)         !! Gradient dL/dbias, same shape as `bias`
        real(real64), intent(in) :: learning_rate     !! Step size (eta), non-negative

        weights = weights - learning_rate * d_weights
        bias = bias - learning_rate * d_bias
    end subroutine gradient_descent_update

end module mOptimizers
