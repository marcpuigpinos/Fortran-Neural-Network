---
name: neural-networks
description: "Language-agnostic implementation knowledge for dense (fully-connected) feedforward neural networks. Use when: implementing or debugging an MLP from scratch (Layer, Network, forward/backward passes); designing activation, loss, or optimizer code; writing the SGD/mini-batch training loop; computing gradients or verifying them (gradient checking); choosing weight initialization; structuring batched tensor/array layout for matmul-based layers; fixing non-converging or NaN training. Conceptual derivations live in docs/NEURAL_NETWORK_THEORY.md; this skill is the implementation side."
---

> **AI Generated**

# Dense Neural Network Implementation

Pseudocode-level engineering knowledge for building a dense/fc feedforward
network (MLP) in any language. The theory, notation and formulas are the ones
defined in [`docs/NEURAL_NETWORK_THEORY.md`](../../../docs/NEURAL_NETWORK_THEORY.md)
— this skill assumes them and focuses on *how to code it* correctly.

## When to use

- Implementing `Layer` / `Network` types, forward or backward passes.
- Adding an activation, loss, or optimizer; pairing it with its derivative.
- Writing or tuning the training loop (epochs, mini-batches, updates).
- Debugging: loss not decreasing, NaN/inf, vanishing gradients, wrong shapes.
- Designing array layout and batching for a given language.

## Notation (shared with the theory doc)

Layer $l$: `z(l) = W(l) · a(l-1) + b(l)`, `a(l) = sigma(z(l))`, with
`a(0) = x` and `a(L) = y_hat`. The error vector is `delta(l) = dL/dz(l)`.
Weights are stored as **`W(n_out, n_in)`** so the layer forward is one
matrix–vector (or matrix–matrix) product.

## Core algorithms (pseudocode)

### Forward pass — must CACHE per-layer `z` and `a`

```text
function forward(network, x):
    a = x
    cache = []                      # per layer: (z, a)
    for l in 1..L:
        z = W[l] * a + b[l]         # (n_out) or (n_out, batch)
        a = activation[l].fn(z)
        cache.append((z, a), prefixed with previous a)
    return a, cache                 # a == y_hat
```

The cache is what makes backprop cheap; do not recompute activations backward.

### Backward pass — delta recurrence

```text
function backward(network, cache, y_target, loss):
    # 1. output-layer error
    delta = loss.grad_output(a[L], y_target) * activation[L].deriv(z[L])
    # 2. march backwards
    for l in L down to 1:
        dW[l] = outer(delta, a[l-1])            # (n_out) x (n_in)
        db[l] = delta                            # copy, not alias
        if l > 1:
            delta = transpose(W[l]) * delta * activation[l-1].deriv(z[l-1])
    return dW, db          # * = element-wise (Hadamard), not matmul
```

Mini-batch: `a` are columns; sum (or average) the outer products over columns,
or compute `dW = delta_matrix * transpose(a_prev_matrix)` in one `matmul`.
Average the loss gradient over `1/N` consistently with how the loss itself was
reduced.

### Update step

```text
for l in 1..L:
    W[l] -= eta * dW[l]
    b[l] -= eta * db[l]
```

Plain SGD is the baseline. Keep the update as a separate pass so optimizers
(momentum, Adam, lr schedules) can replace it without touching backprop.

### Full training loop

```text
init weights (see initialization below)
for epoch in 1..max_epochs:
    shuffle training set
    for mini_batch (size 32..256) in training set:
        y_hat, cache = forward(X_batch)
        grads        = backward(cache, Y_batch)
        update(W, b, grads, eta)
    monitor loss on held-out validation set
    stop when validation loss plateaus (early stopping)
```

## Activation / loss pairs (implement both halves together)

Every activation used in a trainable network needs its derivative; every loss
needs its gradient w.r.t. the network output. Implement them as a paired
record/interface so they cannot drift apart.

| Activation | fn(z) | deriv(z) — express via a=sigma(z) when possible |
|---|---|---|
| sigmoid | `1 / (1 + exp(-z))` | `a * (1 - a)` |
| tanh | `tanh(z)` | `1 - a*a` |
| ReLU | `max(0, z)` | `1 if z > 0 else 0` |
| softmax | see stability note | use with categorical CE: `a - y` |

| Loss | value | grad w.r.t. output |
|---|---|---|
| MSE (×½) | `½‖a − y‖²` | `a − y` |
| Binary CE | `−[y·ln a + (1−y)·ln(1−a)]` | combine w/ sigmoid: `a − y` |
| Categorical CE | `−Σ y_c·ln a_c` | combine w/ softmax: `a − y` |

The `a − y` simplifications (softmax+CE, sigmoid+CE) cancel the activation
derivative algebraically; prefer the combined form — it is exact, cheaper, and
far more numerically stable than composing the raw gradients.

## Non-negotiable technical choices

1. **Weight initialization.** Never zero (all neurons would be identical —
   symmetry never breaks). Defaults:
   - Xavier/Glorot for sigmoid/tanh: sample `U(−g, g)`, `g = sqrt(6/(n_in+n_out))`.
   - He for ReLU: `N(0, sqrt(2/n_in))`.
   Biases: zero is fine. Use a seedable RNG; log the seed.
2. **Numerical stability.**
   - Softmax: subtract `max(z)` before `exp` (result unchanged, avoids overflow).
   - Cross-entropy: clamp probabilities (e.g. to `[1e-12, 1−1e-12]`) or use the
     combined `a − y` gradient; never `log(0)`.
   - Prefer `log1p`/`expm1` forms when available in the loss.
3. **Precision.** Use double precision (`real64`/`float64`) for training math
   in a from-scratch library; it makes gradient checking meaningful.
4. **Array layout.** Decide batch convention once: examples down the *columns*
   (matches `W(n_out, n_in) · X(n_in, N)`; contiguous in column-major
   languages like Fortran, also fine row-major). Never mix conventions.
5. **Pure forward, side-effecting update.** The forward pass and every gradient
   computation should be side-effect-free; only the update mutates parameters.
   This keeps tests trivial and rules out whole bug classes.

## Debugging & verification checklist

- **Shape table first.** Write down every tensor shape (`W`, `b`, `z`, `a`,
  `delta`, `dW`) before coding. Most bugs are transposed or mismatched
  dimensions; most languages' error messages point straight at them.
- **Gradient checking (the single most valuable test).** Approximate
  `dL/dθ` with the central difference `(L(θ+ε) − L(θ−ε)) / 2ε`, `ε ≈ 1e-6`
  (double precision), over a few random small networks and parameters;
  require relative agreement `‖g_num − g_bp‖ / (‖g_num‖ + ‖g_bp‖ + tiny) < 1e-6`.
  Keep this test in the suite permanently.
- **Overfit one batch.** A correct network drives the loss of a single
  mini-batch to ~0. If it can't, the bug is in code, not hyperparameters.
- **Symmetry check after init.** Two layers initialized differently must
  produce different outputs for the same input; if gradients of two neurons
  are identical, initialization is degenerate.
- **Watch for NaN/inf.** Inspect `z` magnitudes (overflow ⇒ softmax/sigmoid
  input too large ⇒ missing stabilization or lr too big) and the exact first
  occurrence (update step vs. forward pass localizes the cause).
- **Classic failure signatures:**
  - Loss exactly constant from step 0 → zero initialization, or gradients
    dropped/aliased (e.g. `db` aliasing `delta` which is then overwritten).
  - Loss decreases then plateaus high → dead ReLUs (all-negative pre-activations),
    vanishing gradients (deep sigmoid — consider He + ReLU, fewer layers).
  - Loss oscillates/diverges → learning rate too large; halve it.
  - Loss decreases but validation worsens → overfitting; add data, reduce
    capacity, or early-stop.

## Testing strategy (language-agnostic)

1. **Unit, analytic-first**: each activation `fn`/`deriv` against hand-computed
   values; each loss against a scalar worked example.
2. **Forward determinism**: fixed seed, golden `y_hat` for a tiny network
   (2–3–1, hand-checkable with a calculator).
3. **Gradient check** as above (whole-pipeline correctness in one test).
4. **End-to-end**: XOR (2 hidden ReLU/sigmoid units) and a small regression
   (fit `sin(x)` or a linear function) must converge within a fixed budget of
   epochs/seed; assert loss < threshold, not exact weights.

## Extension points (next theory topics)

Not yet in `docs/NEURAL_NETWORK_THEORY.md`: momentum and Adam, learning-rate
schedules, regularization (L2, dropout), convolutional layers, batching math
for GPU BLAS. Extend the theory doc first, then the implementation.
