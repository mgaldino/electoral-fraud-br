# D.C. 2010: diagnóstico e proposta de cadeias maiores

01/10/2026. **Proposta para confirmação do usuário; nenhuma nova amostragem ou mudança de priori autorizada por esta entrega.** A/JAGS20k, D/JAGS20k e D/Stan2k continuam computacionalmente inconclusivos. A revisão final da rodada antiga verificou fidelidade, não convergência. A questão conceitual classes/mecanismos e as alternativas de prioris pertencem à frente do coordenador/Curie.

## 1. Resultado do diagnóstico

**`pi[3]` não é o gargalo contínuo observado:** satisfaz R-hat, ESS bulk e ESS de cauda nos três ajustes. `pi[1]` e `pi[2]` falham nos três. O problema também envolve amplitudes incrementais, variâncias e os funcionais conjuntos M/S; no Stan, destaca-se ainda o bloco de voto legítimo `nu`.

Tabela 1. Globais nos mesmos 143 locais: quatro cadeias, 20.000 draws retidos por cadeia em JAGS e 2.000 em Stan. Os limites <10 e <50 são descrições de gravidade, não novos critérios. Mantidos R-hat <1,01 e ambas as ESS >=400; estatística indefinida não passa.

| Ajuste | Globais reprovados | Bulk <10 | Bulk <50 | Bulk <400 | Cauda <400 | R-hat máximo |
|---|---:|---:|---:|---:|---:|---:|
| A/JAGS20k | 14/23 | 8 | 12 | 14 | 12 | 3,0969 |
| D/JAGS20k | 13/23 | 2 | 8 | 13 | 11 | 1,5176 |
| D/Stan2k | 10/23 | 6 | 9 | 10 | 9 | 2,6928 |

Tabela 2. **ESS bulk / ESS de cauda**, sem thinning. Ordem de ajustes igual à Tabela 1. Os 69 globais, inclusive os seis `beta.*1` de cada ajuste, têm ranking bulk e ranking de cauda completos em `analysis01/global_rankings.csv`. Nenhum global tem ESS indefinida. Os seis `beta.*1` passam nos três ajustes.

| Parâmetro | A/JAGS20k | D/JAGS20k | D/Stan2k |
|---|---:|---:|---:|
| `pi[1]` | 14.12 / 33.40 | 15.24 / 116.51 | 7.78 / 18.08 |
| `pi[2]` | 11.67 / 29.73 | 12.94 / 103.86 | 7.78 / 18.28 |
| `pi[3]` | 16996.63 / 17420.22 | 17651.97 / 17819.04 | 9005.57 / 4049.83 |
| `tau.alpha` | 186.74 / 2027.76 | 273.82 / 14979.65 | 99.29 / 647.57 |
| `nu.alpha` | 28095.63 / 66323.73 | 2407.55 / 65653.15 | 5.27 / 24.57 |
| `iota.m.alpha` | 4.48 / 11.44 | 10.40 / 28.09 | 10.87 / 25.51 |
| `iota.s.alpha` | 4.61 / 11.01 | 21.56 / 80.15 | 5.87 / 29.14 |
| `chi.m.alpha` | 5.48 / 11.06 | 39.89 / 104.48 | 16342.97 / 5370.89 |
| `chi.s.alpha` | 5.46 / 15.63 | 24.53 / 44.77 | 17933.40 / 5667.68 |
| `tb` | 141.26 / 565.60 | 1659.39 / 19340.76 | 22.76 / 110.42 |
| `nb` | 2190.91 / 27463.57 | 35990.01 / 37712.60 | 5.46 / 30.09 |
| `imb` | 9.92 / 12.52 | 61.28 / 266.99 | 879.98 / 1817.67 |
| `isb` | 47.38 / 126.35 | 178.21 / 198.99 | 2690.88 / 4877.97 |
| `cmb` | 9.49 / 75.24 | 186.68 / 250.25 | 8764.56 / 3910.89 |
| `csb` | 37.09 / 84.88 | 194.49 / 441.75 | 9446.90 / 4089.67 |
| `M_total` | 5.08 / 5.26 | 7.36 / 11.18 | 24.52 / 85.16 |
| `S_total` | 4.79 / 5.26 | 8.53 / 11.18 | 4.69 / 21.52 |

`tau` e `nu` são os blocos legítimos de comparecimento e voto no vencedor; `iota.m/s` e `chi.m/s`, as amplitudes incrementais e extremas de fabricação/transferência. `tb,nb,imb,isb,cmb,csb` são **variâncias**, nessa ordem de blocos, não desvios-padrão. `*.alpha` são hiperparâmetros globais; `beta.*1` são interceptos. M/S são os funcionais conjuntos primários, calculados com a mesma classe reconstruída por local/draw: soma de `N*(1-tau)*m` e `N*tau*(1-nu)*s`. Não são as contagens secundárias discretas `M_count_total/S_count_total`. ESS bulk e de cauda medem aspectos distintos; ESS estimada acima do número nominal de draws não foi truncada.

**Locais e parametrização não centrada (NCP).** Em A/JAGS, cada um dos quatro blocos de 143 `mu.iota.*`/`mu.chi.*` tem bulk <10 em todos os locais, assim como as 572 contagens auxiliares `N.*`. Em D/JAGS, os mesmos quatro blocos contínuos têm bulk <50 nos 572 alvos. Em D/Stan, `mu.iota.m` tem 143/143 bulk <400, `mu.iota.s` tem 143/143 <10, `mu.nu` tem 135/143 <400 e `mu.tau`, 127/143 <400; os dois blocos `mu.chi.*` passam. Entre os 860 internos Stan, falham 291: todos os 143 `z[,1]` e 143 `z[,2]`, um `z[,3]`, três `z[,4]` e `r[1]=pi[2]/pi[1]`. `r[2]=pi[3]/pi[1]` passa. Portanto, retirar apenas os indicadores discretos não elimina as falhas.

**Discretos/raros, separadamente.** Os 143 indicadores da classe 3 e sua contagem são zero em todos os draws dos três ajustes; R-hat/ESS indefinidos não demonstram probabilidade posterior exatamente zero. Isso não contradiz os bons diagnósticos do peso contínuo `pi[3]`. Empates também tornam ESS de cauda indefinida em indicadores variáveis das classes 1/2; não agrupar todo NA como problema exclusivo da classe 3. Contagens de classe, indicadores e contagens auxiliares/ secundárias têm categorias próprias nos CSVs corrigidos.

**Persistência entre e dentro das cadeias.** Em A, `iota.m.alpha` tem ESS bulk dentro de cada cadeia entre 1,44 e 3,09, além de forte discordância entre cadeias. Em Stan, as médias de `iota.s.alpha` no último quarto são 3,255; 2,540; -1,278; 3,226. A separação não ficou restrita ao começo da amostra. Os traces e os resumos por quarto documentam exploração lenta e regiões persistentes distintas; não identificam sozinhos quantos modos existem. Zero divergências/atingimentos de treedepth em Stan não resolve essa discordância. **Mais draws podem apenas prolongar a permanência nas mesmas regiões; não há garantia de corrigir multimodalidade.**

## 2. Protocolo proposto, não executado

Tabela 3. Uma nova execução fixa por ajuste, somente depois da confirmação do usuário. Não combinar os draws antigos com os novos.

| Ajuste | Cadeias/processos simultâneos | Adaptação por cadeia | Burn-in/warmup por cadeia | Amostra por cadeia | Total retido | Thin |
|---|---:|---:|---:|---:|---:|---:|
| A/JAGS100k | 4 / 4 | 1.000 | 2.000 burn-in | 100.000 | 400.000 | 1 |
| D/JAGS100k | 4 / 4 | 1.000 | 2.000 burn-in | 100.000 | 400.000 | 1 |
| D/Stan5k | 4 / 4 | incluída no warmup | 1.000 warmup | 5.000 | 20.000 | 1 |

- Manter o alvo, os priors, os critérios e os alvos monitorados da rodada correspondente. Em Stan, `adapt_delta=0.99`, `max_treedepth=12`, `parallel_chains=4` e um thread por cadeia; em JAGS, quatro processos independentes. Congelar o mapeamento de sementes/inicializações por cadeia antes da liberação, sem retuning após resultados.
- O burn-in JAGS cai de 5.000 para 2.000; warmup Stan, de 2.000 para 1.000. A adaptação JAGS fica em 1.000. São escolhas fixas de custo, **não suficiência demonstrada** pelos traces. Adaptação incompleta encerra a tentativa como tal, sem aumento automático.
- Um ajuste pesado por vez. Persistir draws antes dos diagnósticos; em JAGS, propor blocos fixos de 5.000 retidos mantendo o estado contínuo da cadeia até o total de 100.000. Blocos são persistência, não novas tentativas. Preservar CSVs/warmup Stan. Não agregar todas as cadeias em cópias desnecessárias na RAM.
- Registrar, a cada 30 s, progresso/tempo, RSS por processo e agregado, pressão de memória/swap e disco disponível. Não rodar diagnósticos completos repetidamente durante a amostragem. Coordenador define limites de interrupção no preflight de recursos; interrupção preserva o parcial e exige nova decisão, sem retry, extensão, redução silenciosa do número de cadeias ou alteração de priori.

## 3. Recursos, verificação e entrega

O retrato do coordenador (`../resource_snapshot.json`, 12:23:57 UTC) informa 14 núcleos lógicos/físicos, 36 GiB físicos, swap total/usado zero e 268 GiB livres em disco. **Não informa RAM disponível nem pico de RSS**. Quatro processos e um ajuste pesado por vez são a proposta padrão, condicionada a refrescar memória/disco imediatamente antes de executar. Os diretórios antigos de 2,9G/1,5G são ocupação em disco, não consumo de RAM nem previsão suficiente de armazenamento futuro.

Tabela 4. Carga numérica simples `iterações * 4 * variáveis * 8`, sem overhead. Base explicitada em `addenda02/resource_payload_addendum.csv`; `analysis01/payload_sizes.csv` foi preservado.

| Representação | Variáveis | Bytes propostos | GB decimais |
|---|---:|---:|---:|
| A/JAGS100k | 1.880 | 6.016.000.000 | 6,016 |
| D/JAGS100k | 1.451 | 4.643.200.000 | 4,6432 |
| D/Stan5k: somente ponte comum | 1.451 | 232.160.000 | 0,23216 |
| D/Stan5k: array integral | 4.890 | 782.400.000 | 0,7824 |

Nenhuma linha é RAM total ou pico de RSS. Ficam fora CSVs, warmup, estados dos modelos/processos, overhead dos objetos, cópias temporárias, ponte e arrays diagnósticos. O array Stan integral vem da forma publicada localmente em `stan_diagnostics02/input_representation.json`; 232 MB descrevem apenas a ponte. O pico paralelo e o speedup ainda não foram medidos. Os cenários de tempo em `analysis01/runtime_scenarios.csv` escalam fases antigas: cerca de 28/25/15 min com paralelismo ideal, contra 44/35/50 min no cenário serial, incluindo escalonamento ilustrativo de pós-processamento. **Não são previsão, intervalo ou limite de duração**; contenção, gravação e nova adaptação Stan podem alterar substancialmente os tempos.

Verificação do executor: 78 alvos focados (23 globais + 3 contagens em cada ajuste) recompostos com os draws completos, quatro cadeias e `thin=1`, coincidem com os diagnósticos existentes na tolerância relativa 1e-6. Normalização remove a classe S3 antes do recorte, sem concatenar cadeias. Locais/NCP usam os CSVs válidos existentes, sem alegar recomputação integral. O coordenador informou conferência adicional dos 69 globais/897 células contra tabelas revisadas. Isso não constitui revisão independente desta proposta pelo executor.

Os seis painéis-página de `analysis01/focused_traces.pdf` foram renderizados e inspecionados pelo executor. Só a exibição usa 1.000 pontos igualmente espaçados por cadeia; todas as métricas usam todos os draws. `within_chain_summaries.csv` conserva quatro quartos e a cadeia inteira; ESS de uma cadeia é descritiva, não substitui diagnóstico entre cadeias.

Artefatos canônicos: `analysis01/global_rankings.csv`, `addenda02/all_target_rankings_corrected.csv`, `addenda02/grouped_diagnostics_corrected.csv`, `analysis01/rare_class_diagnostics.csv`, `analysis01/within_chain_summaries.csv`, `addenda02/proposed_protocol.csv`, o adendo de recursos e `candidate_manifest.json`. Os CSVs corrigidos mudam somente anotações: natureza discreta de quatro contagens secundárias e classificação/resumo de R-hat infinito. Métricas e decisões antigas permanecem intactas; diferenças em `addenda02/annotation_corrections.csv`. `addenda01` é uma tentativa parcial preservada: a checagem capturou overflow de aritmética inteira no cálculo de payload antes de gravá-lo; `prepare_addenda_v2.R` usa double e produziu o adendo válido.

Reprodução a partir da raiz: executar `diagnose_existing.R` com um subdiretório novo deste escopo; `plot_traces.R` com esse diretório; `prepare_addenda_v2.R` com o diretório de análise e outro diretório novo de adendo. Os scripts recusam sobrescrita, usam dependências já instaladas e não chamam sampler/compilador. Cálculos ficam nos scripts R; este Markdown apresenta seus resultados. Manifesto e hashes são fechados por `finalize_manifest.R`. B1, modelos, dados, critérios e arquivos da rodada antiga não foram alterados. A proposta aguarda consolidação pelo coordenador e confirmação do usuário.
