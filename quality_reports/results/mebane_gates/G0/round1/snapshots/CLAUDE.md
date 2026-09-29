# electoralFraud — Parecer metodologico

## O que e este projeto

Parecer sobre a research note de terceiros "Is there evidence of fraud in Brazil's 2022 presidential election?" (Figueiredo, Carvalho, Santano). A nota aplica electoral fingerprint analysis (joint distribution turnout x vote share) aos dados TSE 2022 e conclui ausencia de fraude por inspecao visual.

**Papel do usuario**: parecerista / reconstrutor metodologico. Nao e autor da nota.

## Estado atual

Blocos 0-2 completos. Bloco 3 parcial: testes suplementares rodados (todos suportam nula),
eforensics pipeline Brasil inteiro pendente.

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
| 3 suplementares | Completo | `R/05_kobak_integer.R`, `R/06_beber_scacco.R`, `R/07_benford_2bl.R`, `R/08_spikes_rozenas.R` |
| 3a-k (eforensics Brasil) | **Pendente** | `R/04_eforensics_mebane.R` (nao existe) |
| 4 (Monte Carlo poder) | Pendente | — |
| 5-7 (robustez) | Pendente | — |

## Escopo

**Dentro**: reconstrucao metodologica em R **apenas para 2022** — testes formais, Monte Carlo de poder, triangulacao, robustez, matriz de detectabilidade vetor-de-fraude x metodo.

**Fora** (por decisao do usuario):
- Reescrita de abstract/introducao, reformulacao teorica da pergunta, literatura sobre fraud claims, recomendacoes de policy.
- **Benchmark 2018 x 2022**: trabalho futuro. Segundo ciclo de revisao, com dados de 2018 fornecidos pelos autores.

## Stack

R. Dependencias-chave planejadas: `electionsBR`, `eforensics` (GitHub: DiogoFerrari), `spikes` (CRAN), `BenfordTests`, `data.table`/`arrow`, `future.apply`, `renv`.

## Ao retomar a sessao

1. Ler este CLAUDE.md e o handoff mais recente:
   - `quality_reports/results/bloco3_session_handoff.md` (estado geral)
   - `quality_reports/results/05_stan_qbl_session_handoff.md` (detalhes qbl)
2. Checar `git log --oneline -10` e `git status`.
3. **Proximo passo**: implementar `R/04_eforensics_mebane.R` — pipeline consolidado
   eforensics para Brasil inteiro com UF FE (steps 3a-3k do plano).
   Usar JAGS qbl (mais rapido que Stan para este modelo).
4. Depois: Bloco 4 (Monte Carlo de poder) — o argumento central do parecer.

### Decisoes ja tomadas
- Modelo: **qbl** (Mebane 2023 hierarquico, canonico)
- Sampler producao: **JAGS** (26 min Brasilia; Stan ~6-28h)
- Stan: validacao cruzada opcional, modelo generalizado para covariáveis pronto
- Denominador primario: `QT_COMPARECIMENTO` (padrao Klimek/Kobak/Mebane)
- Zone FE (Brasilia): confirmou nula, iota.s.alpha claramente negativo
- Testes suplementares: todos suportam nula
