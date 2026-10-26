> **AI Assisted**
> Status: ongoing
> Branch: feature/activation-heviside
> Merge commit: —

# Heaviside activation function

https://en.wikipedia.org/wiki/Heaviside_step_function

Implement, test, and document the heviside activation function:

$$
H(x) =
\begin{cases}
0, & x < 0, \\
1, & x \geq 0
\end{cases}
$$

## Progress

- 2026-10-26: v0.3.0 committed on feature/activation-heviside (d519754) — implemented the `Heaviside` activation (third `extends(Activation)` type in `mActivations`) with H(0)=1 and classical-0 derivative (distributional derivative is the Dirac delta, hence not SGD-trainable), plus 2 new tests (suite 11/11 PASS, warning-free builds), CHANGELOG 0.3.0, FORD docs regenerated clean.