# Entrega congelada: D em Stan, tentativa 03

Executor: `01a0f4b5-4434-7b83-91b9-69ced11b40ba`.
Status: candidato implementado e validado deterministicamente, sujeito a
revisão independente. Nenhum MCMC empírico foi executado. Este documento
foi acrescentado depois do congelamento e não altera fontes ou manifestos.

## Candidato e hashes

Repositório: `/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud`.
Diretório relativo da preparação:

`quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/stan_impl/run-20261001T105406Z-attempt03-01a0f4b5/preparation`

| Artefato | SHA-256 |
| --- | --- |
| `preparation/manifest.json`, vínculo obrigatório do parecer independente | `2ad3246c3b1a5b5e0c676a85434824644b440cc75c386bc45feeabc34b789bfb` |
| `preparation/preflight_manifest.json`, fontes, testes e produtos compilados | `7169d8b0e2536739ad2b2a9a9b9f6bfb471b9e6da3424aaad7cf86bd801d0c23` |
| `launcher_manifest.json`, inventário externo após encerramento de R | `c22a46d42522ab95838d10a1cc286f4de176a8b588f919de03b5abbf16e0beb0` |
| `models/experimental/mebane_ad_stan/d_multinomial.stan` | `b38de93ef22b826233f35898b5d3becfae1fb46df774ead065b8d4133c127c9b` |
| `R/experimental/mebane_ad_stan/run_stan.R` | `d80cf227ddc0a026b0e05584e23394de71cdd66e1c354f8d22e168e1ebc93433` |
| `R/experimental/mebane_ad_stan/supervise_stan.py` | `631e65bb49dc193cd593a14e77738cd88439add6adda9f0ea4bb340ba500f4ef` |
| `tests/mebane/ad_stan/test_stan.R` | `ec9b672590124ae888f6f2e6297e0358afc1d23d474df3a453179d3f881b71ef` |
| `preparation/build/d_multinomial`, executável usado na validação | `c2d882526d9893236c2ebaeec92a8eacdfa0d327f6f19de7f961d936ab6d65f1` |

As 59 entradas de `preparation/SHA256SUMS` foram verificadas por
`shasum -a 256 -c SHA256SUMS`, a partir desse diretório: todas OK.
O preflight também confirmou identidade entre as fontes vivas e os snapshots
ao término da tentativa, inclusive os inputs históricos protegidos.

## Resultados executados

- 183 verificações R passaram; nenhuma falhou.
- Quatro testes do supervisor passaram, inclusive o líder encerrar antes
  de descendentes persistentes e o SIGKILL incondicional ao grupo após a
  tentativa de SIGTERM. São testes de regressão com processos simulados,
  não uma demonstração de timeout de um fit empírico real.
- Dez comparações da logdensidade compilada com o oráculo R independente,
  com e sem Jacobiano, tiveram erro absoluto máximo de
  `3.6379788070917101e-12`.
- 380 coordenadas de gradiente foram comparadas com diferenças finitas
  independentes em R. O erro máximo escalado por `1+abs(gradiente_R)` foi
  `1.5748601785718701e-07`, abaixo da tolerância predeclarada de `3e-5`.
- Os testes cobriram probabilidades e logmassas em fronteiras, normalização
  para N=0..4, mistura correta de classes, transformação da priori parcial,
  Jacobiano centrado/não centrado, parametrização irrestrita, valores
  extremos e variâncias pequenas.
- A única execução de amostragem foi `fixed_param`, com três unidades
  sintéticas, uma cadeia, 256 iterações, zero warmup e seed 1001267. Nenhum
  parâmetro foi atualizado. Responsabilidades, mu, Z, pA/pW/pO, funcionais
  por classe, ativos, totais e RB foram conferidos contra cálculos independentes.

As evidências numéricas são `tests/density_comparisons.csv` e
`tests/gradient_comparisons.csv`. Chamadas, sementes e argumentos estão em
`tests/calls.json`, no snapshot do teste e nos logs. O modelo Stan não mudou
entre as tentativas; as correções foram no harness/API e nos metadados.

## Tempos e ambiente

`compile_seconds = 43.1641881465912`: executável CmdStan **mais** interface
C++ de métodos de densidade/gradiente. Este total não é exclusivamente
compilação produtiva. `compile_scope` está no manifesto e será propagado
para `timing.json` pelo runner.

A interface de funções standalone consumiu separadamente
`8.45390295982361` segundos, registrada em `tests/calls.json`. A duração
da seção de preflight registrada em `result.json` foi aproximadamente
52,89 segundos; inclui compilação e testes, mas antecede o inventário final.
O launcher registra separadamente seu walltime externo completo.

Ambiente registrado: R 4.4.2; cmdstanr 0.9.0; CmdStan 2.37.0; posterior
1.7.0. O compilador registrado no log é Apple clang 16.0.0, SDK MacOSX15.2.
Não houve instalação nem necessidade de escalar permissões nesta compilação.

## APIs e arquivos prospectivos

As APIs R são `ad_stan_prepare(repo, out, executor_id)` e
`ad_stan_sample(preparation, qa_path, out)`. A preparação usa o launcher
Python para iniciar R com temporários no escopo autorizado; a amostragem
só é permitida através do supervisor externo.

O schema prospectivo é `draws_array.rds` com 2000×4×variáveis pós-warmup,
`sampler_diagnostics.rds` com 2000×4×diagnósticos HMC, `fit.rds` lazy,
CSVs por cadeia com warmup salvo, logs, `chain_timing.csv` e `timing.json`.
`fit.rds` depende dos CSVs nos caminhos absolutos preservados.

Os nomes para a integração são alpha[1:6], b0[1:6], v[1:6], mu[i,b],
pi[1:3], Z[i], pA[i], pW[i], pO[i], M_total e S_total. A tabela
`name_map.csv` contém os nomes anteriores correspondentes. z[i,b] e r[1:2]
são preservados para diagnóstico NCP. Quantidades RB permanecem separadas
dos ativos, que usam o mesmo Z por unidade e draw. Nenhum diagnóstico LONG
está acoplado ao runner.

## Comandos

Definições para uso a partir de qualquer diretório:

```sh
REPO=/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud
BASE="$REPO/quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/stan_impl"
PREP="$BASE/run-20261001T105406Z-attempt03-01a0f4b5/preparation"
```

Repetição prospectiva do preflight, sempre com diretório novo:

```sh
python3 -B "$REPO/R/experimental/mebane_ad_stan/prepare_stan.py" \
  preflight "$REPO" "$BASE/NOVA_TENTATIVA_PREFLIGHT"
```

Verificação do pacote existente sem recompilar:

```sh
cd "$PREP"
LC_ALL=C LANG=C shasum -a 256 -c SHA256SUMS
```

Amostragem futura, somente depois do PASS independente vinculado a este
manifesto e sob autorização da fase empírica:

```sh
python3 -B "$PREP/sources/R/experimental/mebane_ad_stan/supervise_stan.py" \
  "$PREP" /CAMINHO/PARECER_INDEPENDENTE.json "$BASE/NOVO_RUN_EMPIRICO"
```

O JSON do revisor deve conter `status: "PASS"`, `reviewer_id` real e
distinto do executor de implementação, e
`preparation_manifest_sha256: "2ad3246c3b1a5b5e0c676a85434824644b440cc75c386bc45feeabc34b789bfb"`.
O supervisor verifica novamente os hashes antes de iniciar. A configuração
é fixa: quatro cadeias seriais, warmup 2000, retained 2000, seed 1001261,
IDs 1:4, thin 1, adapt_delta 0,99 e max_treedepth 12. O timeout externo é
3600 segundos, com preservação de saída parcial e sem retry automático.

## Falhas preservadas

1. `run-20261001T105000Z-attempt01-01a0f4b5`: erro de parse por um parêntese
   excedente no harness R, antes de compilar. Snapshot, log e manifesto
   externos preservados. SHA-256 do `launcher_manifest.json`:
   `464951b9195d1079a8f1cf44410ed784ae58980056a690241f9c10f0bfe4f8c0`.
2. `run-20261001T105028Z-attempt02-01a0f4b5`: executável e interfaces
   compilaram, mas a exposição de funções no ambiente global impediu o
   lookup esperado pelo teste. Quatro verificações estáticas precederam
   a falha. Fontes, executável, produtos C++, logs e manifestos preservados.
   SHA-256 do `launcher_manifest.json`:
   `1267d019558d9382315756055975e999bddf566d8788dd0877d56fd2d49c29fb`.

Esses custos são desenvolvimento separado; não compõem o tempo produtivo
do candidato. Nenhum manifesto antigo foi editado ou arquivo removido.

## Limites da entrega

O preflight não executou HMC real, não demonstrou convergência ou precisão
empírica e não validou a exportação de um fit real de quatro cadeias. O
roundtrip de fit/CSV foi exercitado no fixture condicionado. O PASS técnico
desta suíte não substitui revisão independente, não aprova G10 e não afirma
identificação eleitoral nem equivalência empírica com JAGS ou A.
