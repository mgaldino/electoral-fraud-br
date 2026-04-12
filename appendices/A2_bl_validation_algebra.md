# Algebra da forma de `p.w` no JAGS

Data: 2026-04-10

Esta nota mostra por que a formula de `p.w` no JAGS nao contradiz Mebane (2023), apesar de parecer diferente em primeira leitura.

## Caso incremental

No paper:

- `w* = tau * nu + iota.m * (1 - tau) + iota.s * tau * (1 - nu)`
- `a* = (1 - tau) * (1 - iota.m)`

Defina `A = a/N`. Sob fraude incremental:

- `A = (1 - tau)(1 - iota.m)`
- `tau = 1 - A / (1 - iota.m)`

Substituindo em `w*`:

`w* = nu * (1 - A / (1 - iota.m)) + iota.m * A / (1 - iota.m) + iota.s * (1 - A / (1 - iota.m)) * (1 - nu)`

Reorganizando:

`w* = nu * ((1 - iota.s) / (1 - iota.m)) * (1 - iota.m - A) + A * ((iota.m - iota.s) / (1 - iota.m)) + iota.s`

Que e exatamente a forma usada no JAGS para `Z = 2`.

## Caso extremo

O mesmo argumento vale trocando:

- `iota.m -> chi.m`
- `iota.s -> chi.s`

e usando:

- `A = (1 - tau)(1 - chi.m)`.

## Implicacao

A equacao de `p.w` no JAGS:

- nao muda o modelo substantivo;
- apenas escreve a probabilidade de votos no leader em funcao da abstencao observada `a/N`.
