# Handoff: diagnóstico e protocolo candidato

Status: entregue para consolidação/revisão; nenhuma autorização de execução.

- Entrada principal: `diagnostic_proposal.md`; rankings globais em `analysis01/global_rankings.csv` (69 linhas).
- `pi[3]` passa nos três ajustes; `pi[1:2]`, amplitudes incrementais e M/S falham. A/JAGS tem 14/23 globais reprovados, D/JAGS 13/23, D/Stan 10/23. Nenhuma falha global depende de ESS indefinida.
- Proposta: quatro processos, um ajuste pesado por vez; JAGS 1.000 adaptação + 2.000 burn-in + 100.000 retidos por cadeia; Stan 1.000 warmup + 5.000 retidos, thin=1, demais controles preservados. Requer confirmação do usuário antes de amostragem/priori; nenhuma extensão automática.
- Adendo obrigatório de memória: `addenda02/resource_payload_addendum.csv`. Stan integral = 782.400.000 bytes; ponte = 232.160.000. JAGS A/D = 6.016.000.000/4.643.200.000 bytes. Nenhum é RAM total/pico de RSS. Refrescar memória/disco antes de qualquer liberação.
- Usar `addenda02/*_corrected.csv` para agrupamentos/tipos. Métricas originais preservadas; a correção é somente anotação de discretos secundários e R-hat infinito. `addenda01` parcial permanece arquivado, não canônico.
- Verificação do executor: 78 recomputações focadas concordantes, sem thinning; seis páginas de traces vistas. Coordenador informou 69 globais/897 células conferidos contra tabelas revisadas. Não é autodeclaração de revisão independente.
- Questão conceitual classes/mecanismos e proposta matemática/de prioris ficam com coordenador/Curie. B1 permanece fechado e intocado.

Integridade: `candidate_manifest.json` e `artifact_hashes.csv`; fontes de cálculo em `analysis01/input_manifest.json`, reconferência em `addenda02/input_rechecks.csv`, contexto preservado em `addenda02/context_snapshots/`. Não houve MCMC, instalação, compilação, exclusão ou alteração de arquivos anteriores à tarefa.
