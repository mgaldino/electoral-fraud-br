# electoralFraud — Parecer metodologico

## O que e este projeto

Parecer sobre a research note de terceiros "Is there evidence of fraud in Brazil's 2022 presidential election?" (Figueiredo, Carvalho, Santano). A nota aplica electoral fingerprint analysis (joint distribution turnout x vote share) aos dados TSE 2022 e conclui ausencia de fraude por inspecao visual.

**Papel do usuario**: parecerista / reconstrutor metodologico. Nao e autor da nota.

## Estado atual

O protocolo vigente e `quality_reports/plans/mebane_2022_2026_gates.json`: baseline G0, validacao de dados/modelo/inferencia de 2022 e preparacao separada para os turnos de 2026. Blocos 0-2 e testes suplementares tem artefatos historicos; nao equivalem a validacao atual. O pipeline qbl nacional e as conclusoes inferenciais continuam pendentes. O candidato reparado G0 encontra-se em `quality_reports/results/mebane_gates/G0/round2/` para revisao independente.

- Manuscrito: `research_note.md`
- Plano metodologico aprovado: `quality_reports/plans/2026-04-10_reconstrucao-metodologica.md`
- Handoff qbl (Stan/JAGS): `quality_reports/results/05_stan_qbl_session_handoff.md`
- Handoff Bloco 3: `quality_reports/results/bloco3_session_handoff.md`
- Pareceres: `quality_reports/reviews/2026-04-10_*.md`

### Progresso dos blocos

| Bloco | Status | Scripts |
|-------|--------|---------|
| 0 (infra) | Completo | `R/00_setup.R` |
| 1 (dados) | Completo | `R/01_load_tse.R`, `R/02_build_vars.R` |
| 2 (fingerprint visual) | Completo | `R/03_fingerprint_base.R` → 8 PDFs |
| 3a (eforensics Brasilia) | Parcial | `R/05_eforensics_*.R`, `R/05_jags_qbl_zone_fe.R` |
| 3 suplementares | Execucoes historicas; interpretacao nao validada neste gate | `R/05_kobak_integer.R`, `R/06_beber_scacco.R`, `R/07_benford_2bl.R`, `R/08_spikes_rozenas.R` |
| 3a-k (eforensics Brasil) | **Pendente** | `R/04_eforensics_mebane.R` nao existe; `R/07_brasil_full_qbl.R` existe sem fit nacional correspondente |
| 4 (Monte Carlo poder) | Pendente | — |
| 5-7 (robustez) | Pendente | — |

## Escopo

**Dentro**: reconstruir e validar 2022 e preparar a recepcao de dados oficiais de 2026 conforme o plano vigente. Estimacoes de 2026 dependem de publicacao oficial e dos gates anteriores aprovados.

**Fora** (por decisao do usuario):
- Reescrita de abstract/introducao, reformulacao teorica da pergunta, literatura sobre fraud claims, recomendacoes de policy.
- **Benchmark 2018 x 2022**: trabalho futuro. Segundo ciclo de revisao, com dados de 2018 fornecidos pelos autores.

## Stack

R. O baseline qbl usa `eforensics` 0.0.4 de `UMeforensics/eforensics_public` no commit `3017de537450f97a01872d0157462a68bea348ee`, nao o fork antigo `DiogoFerrari`. Outras dependencias historicas/planejadas incluem `electionsBR`, `spikes`, `BenfordTests`, `data.table`/`arrow`, `future.apply` e `renv`; a disponibilidade efetiva esta no relatorio G0.

## Ao retomar a sessao

1. Ler este CLAUDE.md e o handoff mais recente:
   - `quality_reports/results/bloco3_session_handoff.md` (estado geral)
   - `quality_reports/results/05_stan_qbl_session_handoff.md` (detalhes qbl)
2. Checar `git log --oneline -10` e `git status`.
3. Ler o ledger vigente e as evidencias congeladas da rodada G0 round2. Nao rodar a analise nacional antes de G1-G5 aprovados, sobretudo o preflight de recursos.
4. Tratar escolhas de engine, especificacao e criterios inferenciais como pendentes dos gates G2-G4, nao como decisoes aprovadas pelos handoffs de abril.

### Evidencia historica e limites
- O pacote `eforensics` 0.0.4 instalado declara `RemoteSha` `3017de537450f97a01872d0157462a68bea348ee`; G0 arquiva o codigo `qbl` e o commit correspondente. O alvo de producao e sua fidelidade matematica serao decididos em G2-G3.
- O fit JAGS Brasilia fresh_v2 tem quatro cadeias, mas o R-hat classico recalculado de `pi[2]` e cerca de 1.25; o fit zone FE registra cerca de 4.62 no resumo historico. A observacao de `iota.s.alpha` negativo nao autoriza conclusao de ausencia de fraude.
- O log Stan de 2.000 observacoes identifica o modelo como aproximado e registra `rhat_max` 1.229 e `ess_bulk_min` 8.2. Igualdade com o JAGS nao foi demonstrada.
- O handoff de abril usa limites de R-hat mais permissivos que os criterios definidos no plano atual G4; resultados historicos nao os substituem.
- O PDF local `ssrn-4073770.pdf` e um artigo de Kirill Kalinin (2022), nao um paper de Mebane. O arquivo na pasta `.download` e incompleto; nao usar como fonte valida.
