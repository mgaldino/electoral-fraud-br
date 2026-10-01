# Diagnóstico e proposta para confirmação

01/10/2026. Entrega encerrada; **nenhum novo MCMC, compilação ou mudança de priori**. As três rodadas existentes continuam inconclusivas. A questão conceitual classes/mecanismos está na resposta do coordenador: `../clarificacao_classes_mecanismos.md`.

## Principais resultados

`pi[3]` satisfaz os critérios contínuos nos três ajustes: ESS bulk/cauda de 16.996,63/17.420,22 em A/JAGS, 17.651,97/17.819,04 em D/JAGS e 9.005,57/4.049,83 em D/Stan. `pi[1]` e `pi[2]` falham nos três; suas ESS bulk são, respectivamente, 14,12/11,67; 15,24/12,94; 7,78/7,78.

Tabela 1. Cinco piores globais por ESS bulk, em ordem crescente. Cauda e R-hat completos constam no ranking CSV.

| Ajuste | Parâmetros e ESS bulk | Globais reprovados |
|---|---|---:|
| A/JAGS20k | `iota.m.alpha` 4,48; `iota.s.alpha` 4,61; `S_total` 4,79; `M_total` 5,08; `chi.s.alpha` 5,46 | 14/23 |
| D/JAGS20k | `M_total` 7,36; `S_total` 8,53; `iota.m.alpha` 10,40; `pi[2]` 12,94; `pi[1]` 15,24 | 13/23 |
| D/Stan2k | `S_total` 4,69; `nu.alpha` 5,27; `nb` 5,46; `iota.s.alpha` 5,87; `pi[2]` 7,78 | 10/23 |

Bulk <400: 14/13/10 globais; cauda <400: 12/11/9, na mesma ordem. Nenhum global tem ESS indefinida. Os seis interceptos `beta.*1` passam em cada ajuste. Em JAGS, amplitudes incrementais/extremas e várias variâncias apresentam baixa ESS; em Stan, sobressaem o bloco legítimo `nu`, sua variância `nb`, as amplitudes incrementais e M/S. `tb,nb,imb,isb,cmb,csb` são variâncias, não desvios-padrão.

Nos locais, os quatro blocos `mu.iota.*`/`mu.chi.*` têm todos os 572 alvos com bulk <10 em A/JAGS e <50 em D/JAGS. Em Stan, os problemas concentram-se em `mu.iota.*`, `mu.nu` e `mu.tau`; os dois blocos `mu.chi.*` passam. Dos 860 internos não centrados Stan, 291 falham, incluindo todos os 143 `z[,1]` e 143 `z[,2]`. Logo, os problemas não se limitam a classes raras.

Os indicadores/contagem da classe 3 ficaram sempre zero, com diagnósticos indefinidos; isso não prova probabilidade posterior zero e não transforma `pi[3]` no gargalo. Discretos, contagens auxiliares e funcionais M/S são separados nos CSVs. Nos traces, a discordância persiste até os últimos quartos: mais draws não garantem resolver multimodalidade, nem a redução de warmup é uma correção demonstrada.

## Proposta exata, não executada

Tabela 2. Quatro processos independentes de cadeia, um thread por cadeia, **um ajuste pesado por vez**. Uma tentativa fixa por ajuste, sem retry/extensão automática, thin=1.

| Ajuste | Cadeias paralelas | Adaptação/cadeia | Burn-in ou warmup/cadeia | Retidas/cadeia |
|---|---:|---:|---:|---:|
| A/JAGS100k | 4 | 1.000 | 2.000 burn-in | 100.000 |
| D/JAGS100k | 4 | 1.000 | 2.000 burn-in | 100.000 |
| D/Stan5k | 4 | incluída no warmup | 1.000 warmup | 5.000 |

Em Stan: `parallel_chains=4`, `adapt_delta=0.99`, `max_treedepth=12`. Preservar alvos, priors, dados, critérios e variáveis monitoradas; congelar sementes/inicializações por cadeia antes da liberação. A redução de 5.000 para 2.000 burn-in JAGS e de 2.000 para 1.000 warmup Stan é uma escolha de custo ainda não validada. Não juntar os draws antigos e novos. **O usuário precisa confirmar as propostas antes de qualquer amostragem ou alteração de priori.**

## Recursos e limites

Contexto recebido e incorporado: `../resource_snapshot.json`, observado às 12:23:57 UTC, informa **14 núcleos lógicos/físicos, 36 GiB de RAM física, swap total/usado zero e 268 GiB livres em disco**. Não mede RAM disponível nem pico de RSS. Refrescar memória/disco antes de executar; quatro processos são condicionais à capacidade efetiva. Os diretórios antigos de 2,9G/1,5G são ocupação de disco, não RAM.

Cargas numéricas simples, fora CSVs, warmup, estados dos processos, overhead, cópias, ponte e diagnósticos: A/JAGS100k = **6.016.000.000 bytes**; D/JAGS100k = **4.643.200.000 bytes**; Stan5k ponte comum de 1.451 variáveis = **232.160.000 bytes**; Stan5k array integral de 4.890 variáveis = **782.400.000 bytes**. Nenhuma dessas cargas é RAM total/pico de RSS. `payload_sizes.csv` foi preservado; o adendo explicita as bases.

Monitoramento proposto: progresso/tempo, RSS individual/agregado, pressão de memória/swap e disco a cada 30 s; persistir draws antes dos diagnósticos, sem diagnósticos completos repetidos durante sampling. Limites de interrupção dependem do preflight de recursos do coordenador; qualquer interrupção preserva os parciais e não autoriza recomeço automático. Não foi medido pico paralelo nem speedup. Cenários ilustrativos de fases antigas resultam em aproximadamente 28/25/15 min sob paralelismo ideal, versus 44/35/50 min serial, com pós-processamento escalado: **não são previsões, intervalos ou limites de duração**.

## Artefatos e verificação

- Ranking dos 69 globais: `analysis01/global_rankings.csv`; cauda, bulk, R-hat e rankings separados. O coordenador conferiu 69 globais/897 células contra tabelas revisadas.
- Todos os alvos e grupos canônicos: `addenda02/all_target_rankings_corrected.csv` e `addenda02/grouped_diagnostics_corrected.csv`. As correções são somente anotações de contagens secundárias discretas e R-hat infinito; métricas/decisões originais foram preservadas.
- Evidência focada: `analysis01/within_chain_summaries.csv`, `rare_class_diagnostics.csv`, `focused_metric_checks.csv` e `focused_traces.pdf`. As 78 recomputações focadas coincidem; preservadas iteração x cadeia e métricas sem thinning. Só os traces exibem 1.000 pontos por cadeia. Locais/NCP reutilizam as métricas válidas existentes.
- Protocolo/recursos: `addenda02/proposed_protocol.csv` e `addenda02/resource_payload_addendum.csv`. Scripts R separam cálculos desta narrativa. `addenda01` parcial e todos os demais artefatos permanecem preservados.
- Integridade: `candidate_manifest.json` + `artifact_hashes.csv` inventariam a entrega anterior; `closing_manifest.json` acrescenta este resumo sem sobrescrevê-los. Não se alega revisão independente desta proposta pelo executor. B1, modelos, dados e rodadas anteriores permanecem intocados.
