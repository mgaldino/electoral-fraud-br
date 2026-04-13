# Handoff Bloco 3 — testes formais

Data: 2026-04-13

## Contexto

Sessao focada em implementar os testes suplementares do Bloco 3 (Kobak, Beber-Scacco,
Benford 2BL, Spikes/Rozenas) e consolidar o estado do pipeline de testes formais.

## Estado dos testes suplementares

| Teste | Script | Status | Resultado |
|---|---|---|---|
| Kobak integer pct | `R/05_kobak_integer.R` | Implementado + rodado | `output/tables/tab_kobak_integer_pct.csv` |
| Beber-Scacco last digit | `R/06_beber_scacco.R` | Implementado + rodado | `output/tables/tab_beber_scacco_last_digit.csv` |
| Benford 2BL | `R/07_benford_2bl.R` | Implementado + rodado | `output/tables/tab_benford_2bl.csv` |
| Spikes/Rozenas | `R/08_spikes_rozenas.R` | Implementado; run em andamento (~longo, 471k obs x 1000 resamples) | `output/tables/tab_spikes_rozenas.csv` (quando terminar) |

## Estado do eforensics pipeline (3a-3k)

### Feito (sessoes anteriores)
- qbl JAGS calibrado em Brasilia T2 (6748 secoes) — intercept-only e zone FE
- Stan port generalizado para covariáveis — backward compat validada
- Dip test implementado (Hartigan)
- Ft/Fw computado pelo Stan (generated quantities)
- Nula confirmada para Brasilia: iota.s.alpha claramente negativo

### Pendente (proximo passo pesado)
- **Script consolidado `R/04_eforensics_mebane.R`**: Nao existe. Precisa sintetizar
  os scripts exploratorios `R/05_*` em um pipeline producao com:
  - UF state FE (27 estados), nao zone FE (que foi exploratoria em Brasilia)
  - Brasil inteiro (471k secoes, nao so Brasilia)
  - Steps 3a-3k completos: mixture probs, decomposicao Ft/Fw, magnitudes por UF,
    fingerprint residualizado, listagem de UFs flagged
  - Tabelas: `tab1a_eforensics_mixture.csv`, `tab1b_eforensics_frauds_by_uf.csv`
  - Figuras: `fig_eforensics_residualized.pdf`, `fig_eforensics_frauds_magnitudes_uf.pdf`

### Decisoes pendentes
1. **Modelo**: qbl (Mebane 2023, hierarquico) vs bl (mais simples). qbl e o padrao
   Mebane mas e mais lento. Recomendacao: usar qbl como no PA2024.
2. **Sampler**: JAGS (mais rapido para qbl) vs Stan. Recomendacao: JAGS para producao,
   Stan para validacao cruzada (opcional, ~6-28h).
3. **Escala**: Brasil inteiro com UF FE no JAGS pode levar horas (471k secoes).
   Considerar rodar por regiao ou por estado se escala for proibitiva.
4. **Step 3d (escalation)**: Se dip test detectar multimodalidade com UF FE, escalar
   para municipio FE (5570 municipios). Isso pode ser computacionalmente inviavel
   no JAGS — considerar Stan ou subsample.

## Tabela consolidada de testes (Bloco 3 completo)

Quando todos os testes estiverem prontos, consolidar em:
`output/tables/tab1_tests_brazil_2022.csv`

Formato: test_name | candidate | round | level | statistic | ci_or_pvalue | decision

## Proximos passos (em ordem)

1. Revisar resultados dos testes suplementares (CSVs em output/tables/)
2. Implementar `R/04_eforensics_mebane.R` — pipeline consolidado:
   - Escolher modelo (qbl recomendado) e sampler (JAGS recomendado)
   - Rodar no Brasil inteiro com UF FE
   - Gerar todas as tabelas e figuras de 3a-3k
3. Step 3h: fingerprint residualizado (remover UF FE dos dados, replotar)
4. Consolidar tab1_tests_brazil_2022.csv com todos os testes
5. Bloco 4: Monte Carlo de poder (o argumento central do parecer)

## Arquivos de referencia

- Plano: `quality_reports/plans/2026-04-10_reconstrucao-metodologica.md`
- Handoff qbl: `quality_reports/results/05_stan_qbl_session_handoff.md`
- PA2024 (Mebane): `PA2024.pdf`
- Dados: `data/processed/brasil_2022_secao_clean.parquet`
