# electoralFraud — Parecer metodologico

## O que e este projeto

Parecer sobre a research note de terceiros "Is there evidence of fraud in Brazil's 2022 presidential election?" (Figueiredo, Carvalho, Santano). A nota aplica electoral fingerprint analysis (joint distribution turnout x vote share) aos dados TSE 2022 e conclui ausencia de fraude por inspecao visual.

**Papel do usuario**: parecerista / reconstrutor metodologico. Nao e autor da nota.

## Estado atual

O protocolo vigente é `quality_reports/plans/mebane_2022_2026_gates.json`. O usuário autorizou o benchmark literal qbl/JAGS e replicação externa dos autores (novo G10 entre G3 e G4). D1-D3 de G2 round2 passaram em 59 checagens metodológicas independentes; preservam priors efetivas, desenho inicial intercept-only com hierarquia e funcionais conjuntos, sem aprovação inferencial. Consultar `appendices/mebane_model_contract.md` e `quality_reports/results/mebane_gates/G2/round2/benchmark_contract.json`.

O usuário decidiu em 29/09 manter a exclusão do download incompleto `ssrn-4073770.pdf.download/ssrn-4073770.pdf` e atualizar o inventário. O arquivo não era fonte do modelo. A autoria e a causa da remoção são desconhecidas; o checkpoint automático do Git apenas registra a ausência. A reconciliação documental foi concluída: G0 round4 e G1/G2/G7 round3 têm hashes reconferidos, revisão independente e adjudicação aprovadas, sem repetir análises científicas. A pendência de integridade foi encerrada; G3 e G10 não foram executados. Os inventários e pareceres anteriores são preservados. Ver `coordination/2026-09-29_inventory_rebaseline/decision.md` e `completion.json`, sob `quality_reports/results/mebane_gates/`.

### Preservação de arquivos

Não excluir arquivos ou diretórios sem autorização explícita prévia do usuário,
inclusive em rotinas de limpeza, remoção de temporários e tarefas delegadas a
subagentes. Não interpretar aprovação de análise, gate ou plano como autorização
para excluir. A decisão de manter uma ausência já existente não autoriza novas
exclusões. Se houver remoção inesperada, registrar o fato sem atribuir autoria
sem evidência e não restaurar silenciosamente uma possível alteração do usuário.

G7 cobre staging ensaiado de CSV normalizado, não conversor bruto oficial nem atestação de votos reais de 2026. A descoberta de materiais de replicação dos autores foi revisada, mas nenhum ajuste externo foi reproduzido e G10 não passou. Blocos 0-2 e testes suplementares têm artefatos históricos; não equivalem a validação atual. O pipeline nacional e as conclusões inferenciais continuam pendentes; o ledger prevalece sobre este resumo.

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
3. Ler o ledger vigente, verificar `integrity_hold` e as evidências congeladas. A decisão sobre o download incompleto já foi dada: manter a ausência e reconciliar o inventário; não voltar a pedir a mesma escolha nem restaurar os arquivos. Não rodar análise nacional antes de G1-G5 e G10 aprovados, sobretudo o preflight de recursos.
4. O benchmark literal foi escolhido; engine de produção, geografia e critérios inferenciais continuam sujeitos aos gates pertinentes. Não usar handoffs de abril como aprovação. G10 exige contrato de replicação revisado antes da execução comparativa.
5. Os loaders G1 exigem `CONFIG_JSON` e diretório de saída explícitos. Não usar as chamadas antigas sem argumentos nem ligar automaticamente seus produtos aos scripts históricos. Ver comandos vigentes no README; preservar rounds congelados e `data/processed/`.

### Evidencia historica e limites
- O pacote `eforensics` 0.0.4 instalado declara `RemoteSha` `3017de537450f97a01872d0157462a68bea348ee`; G0 arquiva o codigo `qbl` e o commit correspondente. O alvo de producao e sua fidelidade matematica serao decididos em G2-G3.
- O fit JAGS Brasilia fresh_v2 tem quatro cadeias, mas o R-hat classico recalculado de `pi[2]` e cerca de 1.25; o fit zone FE registra cerca de 4.62 no resumo historico. A observacao de `iota.s.alpha` negativo nao autoriza conclusao de ausencia de fraude.
- O log Stan de 2.000 observacoes identifica o modelo como aproximado e registra `rhat_max` 1.229 e `ess_bulk_min` 8.2. Igualdade com o JAGS nao foi demonstrada.
- O handoff de abril usa limites de R-hat mais permissivos que os criterios definidos no plano atual G4; resultados historicos nao os substituem.
- O PDF local `ssrn-4073770.pdf` e um artigo de Kirill Kalinin (2022), nao um paper de Mebane. O download incompleto que ficava na pasta `.download` foi removido e permanece ausente por decisao do usuario; nunca foi fonte valida.
- A interface UMeforensics usa formula1=w/Xw e formula2=a/Xa. Dois wrappers históricos inverteram as chamadas; o reparo AR-02 é independente da pendência de integridade e não reestima resultados. As listas diretas fresh_v2/zoneFE estão corretas nesse ponto.
