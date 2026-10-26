! AI Generated
module mActivations
    !! Element-wise activation functions for dense neural network layers.
    !!
    !! This internal module defines the activation abstraction prescribed by
    !! `docs/memory/API_DESIGN.md` (section 3): an abstract `Activation` base
    !! with deferred `fn`/`deriv` bindings and the concrete `ReLU`, `Sigmoid`
    !! and `Heaviside` types in the same module. The activation/derivative pairing
    !! follows the implementation checklist in
    !! `.github/skills/neural-networks/SKILL.md`: every trainable activation
    !! supplies both halves, and the sigmoid derivative is expressed via
    !! a = sigma(z) so backpropagation never recomputes an exponential.
    !!
    !! The module deliberately depends on nothing but `iso_fortran_env`: it
    !! must compile independently of `mLayer`/`mNetwork`, which do not exist
    !! yet. No `ACT_*` dispatch-kind constants live here — those belong to
    !! the later Network/layer feature, exactly as `OPT_SGD` was deliberately
    !! left out of `mOptimizers`.
    !!
    !! Design note (why `fn`/`deriv` are not `elemental`): the deferred
    !! bindings must accept the passed-object dummy, which is polymorphic
    !! (`class(Activation)`), and `elemental` procedures forbid polymorphic
    !! dummies. The bindings therefore take a 1-D assumed-shape array `z(:)`
    !! and apply their formula element-wise in their implementations. Both
    !! activations are stateless, so the concrete implementations are `pure`;
    !! the abstract interfaces are `pure` as well so the specific bindings
    !! conform (a deferred binding and its implementation must agree on
    !! purity).
    !!
    !! @author Fortran-Neural-Network project
    !! @version 0.3.0
    !! @license MIT

    use, intrinsic :: iso_fortran_env, only: real64

    implicit none

    private

    public :: Activation
    public :: ReLU
    public :: Sigmoid
    public :: Heaviside

    !! Abstract base for element-wise activation functions.
    !!
    !! A concrete extension supplies the `fn` and `deriv` bindings: the
    !! activation value and its derivative with respect to the pre-activation
    !! `z`, both applied element-wise to a 1-D array. The base holds no
    !! state; further activations (tanh, softmax, linear) are planned as
    !! extensions of this same base in a later feature.
    type, abstract :: Activation
    contains
        procedure(fn_interface), deferred :: fn        !! Evaluate the activation
        procedure(deriv_interface), deferred :: deriv  !! Evaluate the derivative
    end type Activation

    !! Contract for evaluating an activation function (see `Activation%fn`).
    !!
    !! Declared after `Activation` so its `class(Activation)` dummy resolves;
    !! the reference to this interface in the type-binding above is an allowed
    !! forward reference for a type-bound procedure.
    abstract interface
        pure function fn_interface(self, z) result(a)
            !! Element-wise activation value a = f(z) (see `Activation%fn`).
            import :: Activation, real64
            implicit none
            class(Activation), intent(in) :: self  !! The activation applied (state unused)
            real(real64), intent(in) :: z(:)       !! Pre-activation values (1-D)
            real(real64) :: a(size(z))             !! Activated values, same shape as `z`
        end function fn_interface
    end interface

    !! Contract for evaluating the activation derivative (see `Activation%deriv`).
    !!
    !! Declared after `Activation` for the same forward-reference reason as
    !! `fn_interface`. The derivative is with respect to the pre-activation
    !! `z`, which backpropagation multiplies the upstream gradient by.
    abstract interface
        pure function deriv_interface(self, z) result(d)
            !! Element-wise derivative d = df/dz (see `Activation%deriv`).
            import :: Activation, real64
            implicit none
            class(Activation), intent(in) :: self  !! The activation differentiated (state unused)
            real(real64), intent(in) :: z(:)       !! Pre-activation values (1-D)
            real(real64) :: d(size(z))             !! Derivative values, same shape as `z`
        end function deriv_interface
    end interface

    !! Rectified Linear Unit activation: a = max(0, z).
    !!
    !! The piecewise-linear activation favoured for hidden layers: cheap to
    !! evaluate and free of the saturating vanishing gradients that plague
    !! deep sigmoid stacks (see `.github/skills/neural-networks/SKILL.md`
    !! troubleshooting notes; note the complementary dead-ReLU risk is a
    !! training-loop concern, not an evaluation one).
    type, extends(Activation) :: ReLU
    contains
        procedure :: fn => relu_fn        !! Evaluate the ReLU
        procedure :: deriv => relu_deriv  !! Evaluate the ReLU derivative
    end type ReLU

    !! Logistic sigmoid activation: a = 1 / (1 + exp(-z)), in (0, 1).
    !!
    !! The classic output-layer activation for single binary units. The
    !! evaluation uses the branch-stabilised formulation so the exponential
    !! never overflows for large |z|; see `sigmoid_fn` for the details.
    type, extends(Activation) :: Sigmoid
    contains
        procedure :: fn => sigmoid_fn        !! Evaluate the sigmoid
        procedure :: deriv => sigmoid_deriv  !! Evaluate the sigmoid derivative
    end type Sigmoid

    !! Heaviside step activation: a = 0 if z < 0, else 1, with H(0) = 1.
    !!
    !! The discontinuous two-valued step function
    !! (https://en.wikipedia.org/wiki/Heaviside_step_function), outputting
    !! values in `{0, 1}` (a subset of `[0, 1]`). Unlike `ReLU` and `Sigmoid`
    !! this activation is not trainable by standard SGD: its derivative is
    !! zero almost everywhere (see `heaviside_deriv`), so gradients vanish
    !! and no useful weight updates flow through it. It is provided as a
    !! hard-threshold/indicator building block rather than as a hidden-layer
    !! activation.
    type, extends(Activation) :: Heaviside
    contains
        procedure :: fn    => heaviside_fn     !! Evaluate the Heaviside step
        procedure :: deriv => heaviside_deriv  !! Evaluate the Heaviside derivative
    end type Heaviside

contains

    pure function relu_fn(self, z) result(a)
        !! Evaluate the ReLU activation a = max(0, z) element-wise.
        !!
        !! Stateless and side-effect-free, hence `pure`. `self` is required
        !! by the deferred-binding contract but carries no state here.
        ! `self` is intentionally unused here: ReLU is stateless, but the
        ! deferred binding contract requires the dummy (declared as the
        ! extending type, as an override of a deferred binding demands).
        class(ReLU), intent(in) :: self  !! This activation (state unused)
        real(real64), intent(in) :: z(:)       !! Pre-activation values (1-D)
        real(real64) :: a(size(z))             !! Activated values, same shape as `z`

        a = max(0.0_real64, z)
    end function relu_fn

    pure function relu_deriv(self, z) result(d)
        !! Evaluate the ReLU derivative d = 1 if z > 0, else 0, element-wise.
        !!
        !! Convention: deriv(0) = 0. The ReLU has no derivative at z = 0, so
        !! the subgradient 0 is chosen — the documented, testable convention
        !! for this library (the alternative subgradient 1 would silently
        !! revive units sitting exactly at the kink).
        ! `self` is intentionally unused here: ReLU is stateless, but the
        ! deferred binding contract requires the dummy (declared as the
        ! extending type, as an override of a deferred binding demands).
        class(ReLU), intent(in) :: self  !! This activation (state unused)
        real(real64), intent(in) :: z(:)       !! Pre-activation values (1-D)
        real(real64) :: d(size(z))             !! Derivative values, same shape as `z`

        d = merge(1.0_real64, 0.0_real64, z > 0.0_real64)
    end function relu_deriv

    pure function sigmoid_fn(self, z) result(a)
        !! Evaluate the sigmoid a = 1 / (1 + exp(-z)) element-wise, stably.
        !!
        !! Numerical stability: a naive 1/(1 + exp(-z)) overflows the
        !! exponential for very negative z (exp(-z) -> +INF, and 1/INF does
        !! yield 0 but only through an overflow flag / INF intermediate,
        !! while the mirrored 1/(1 + exp(z)) fails for very positive z). The
        !! branch-stable form keeps the exponential's argument non-positive
        !! in magnitude on the safe side: z >= 0 uses 1/(1 + exp(-z)) and
        !! z < 0 uses exp(z)/(1 + exp(z)). Both branches are algebraically
        !! identical; this one never overflows to INF/NaN for any finite z.
        ! `self` is intentionally unused here: the sigmoid is stateless, but
        ! the deferred binding contract requires the dummy (declared as the
        ! extending type, as an override of a deferred binding demands).
        class(Sigmoid), intent(in) :: self  !! This activation (state unused)
        real(real64), intent(in) :: z(:)       !! Pre-activation values (1-D)
        real(real64) :: a(size(z))             !! Activated values in (0, 1), shape `z`
        real(real64) :: ez                     !! exp(z) on the stable (z < 0) branch
        integer :: i                           !! Element index

        do i = 1, size(z)
            if (z(i) >= 0.0_real64) then
                a(i) = 1.0_real64 / (1.0_real64 + exp(-z(i)))
            else
                ez = exp(z(i))
                a(i) = ez / (1.0_real64 + ez)
            end if
        end do
    end function sigmoid_fn

    pure function sigmoid_deriv(self, z) result(d)
        !! Evaluate the sigmoid derivative d = a * (1 - a), a = sigma(z).
        !!
        !! Per the activation/derivative pairing
        !! (`.github/skills/neural-networks/SKILL.md`), the sigmoid
        !! derivative is expressed through the activation value itself:
        !! d(sigma)/dz = sigma(z) * (1 - sigma(z)). It reuses the stable
        !! `sigmoid_fn` internally, so this path inherits the same
        !! overflow-safety and needs no separate branch logic.
        ! `self` is intentionally unused here: the sigmoid is stateless, but
        ! the deferred binding contract requires the dummy (declared as the
        ! extending type, as an override of a deferred binding demands).
        class(Sigmoid), intent(in) :: self  !! This activation (state unused)
        real(real64), intent(in) :: z(:)       !! Pre-activation values (1-D)
        real(real64) :: d(size(z))             !! Derivative values in (0, 0.25], shape `z`
        real(real64) :: a(size(z))             !! sigma(z), reused for the derivative

        a = sigmoid_fn(self, z)
        d = a * (1.0_real64 - a)
    end function sigmoid_deriv

    pure function heaviside_fn(self, z) result(a)
        !! Evaluate the Heaviside step a = 0 if z < 0, else 1, element-wise.
        !!
        !! The H(0) = 1 convention is used: the step returns 1 at and above
        !! the origin (https://en.wikipedia.org/wiki/Heaviside_step_function).
        !! Stateless and side-effect-free, hence `pure`. `self` is required
        !! by the deferred-binding contract but carries no state here.
        ! `self` is intentionally unused here: Heaviside is stateless, but the
        ! deferred binding contract requires the dummy (declared as the
        ! extending type, as an override of a deferred binding demands).
        class(Heaviside), intent(in) :: self  !! This activation (state unused)
        real(real64), intent(in) :: z(:)       !! Pre-activation values (1-D)
        real(real64) :: a(size(z))             !! Activated values in {0, 1}, shape `z`

        a = merge(1.0_real64, 0.0_real64, z >= 0.0_real64)
    end function heaviside_fn

    pure function heaviside_deriv(self, z) result(d)
        !! Evaluate the Heaviside derivative as the classical value d = 0.
        !!
        !! The generalized/distributional derivative of the Heaviside step is
        !! the Dirac delta delta(x), which has no finite real-number
        !! representation; that is exactly why a pure step activation is not
        !! trainable by standard SGD gradient descent. The library therefore
        !! returns the classical pointwise derivative, which is 0 everywhere
        !! off the kink, and takes the value 0 also at z = 0 — the documented,
        !! testable convention (consistent with the ReLU kink choosing 0).
        ! `self` is intentionally unused here: Heaviside is stateless, but the
        ! deferred binding contract requires the dummy (declared as the
        ! extending type, as an override of a deferred binding demands).
        class(Heaviside), intent(in) :: self  !! This activation (state unused)
        real(real64), intent(in) :: z(:)       !! Pre-activation values (1-D)
        real(real64) :: d(size(z))             !! Derivative values (all 0), shape `z`

        d = 0.0_real64
    end function heaviside_deriv

end module mActivations
