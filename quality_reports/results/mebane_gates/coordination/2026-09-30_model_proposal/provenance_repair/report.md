# G3-QA-R2-INPUT-01: suplemento documental para revisão independente

As sete identidades históricas apontadas pela QA foram reconstruídas dos eventos brutos e arquivadas em novos caminhos. Todos os SHA-256 coincidiram exatamente com os alvos adjudicados. Este pacote complementa a revision3, sem substituir seu manifesto e sem declarar o achado resolvido pela revisão independente. G3 permanece **inconclusivo**.

## Vínculo e método

O candidato herdado é `quality_reports/results/mebane_gates/G3/round1/revision3/candidate_manifest.json`, SHA-256 `63855471a88dbfc3840b1172aef71118f7cffbdfe425e0241f1d689bf5e67966`. Seus 350 arquivos declarados foram conferidos por caminho, tamanho e hash antes e depois da reconstrução e novamente na verificação documental.

A adjudicação `CONFIRMED / READY_FOR_IMPLEMENTATION`, o parecer, a lista das sete lacunas, a auditoria histórica, seu código e os eventos brutos estão congelados em `delivery/frozen_inputs/`. O mapa de origens e hashes é `delivery/input_manifest.json`. O arquivo bruto `executor_event_sequence.json` tem SHA-256 `2ba52fc1909b9148b4e05a286ae8a75fac527aa6f28433346f002c606b88439f`.

`reconstruct_sources.py` aplica adições e diffs em memória, usando bytes UTF-8, contexto exato, posições e contagens dos hunks. Não faz busca aproximada, normalização de linhas, correção manual de conteúdo nem substituição por código canônico atual. Os 21 estados de edição e as fontes nos 12 comandos R temporizados da sequência coincidiram com `history_audit.json`. Cada fonte recuperada está ligada ao comando em que era efetiva e à sequência de eventos que produziu seus bytes.

## Fontes recuperadas

Os caminhos abaixo são relativos a `delivery/snapshots/`. São fontes históricas, inclusive de tentativas falhas; não são uma recomendação de execução.

| Caminho | SHA-256 |
| --- | --- |
| `deterministic1/tests/mebane/likelihood/g3_deterministic.R` | `8b0012b3e3b54a3b759745a0c846f3c384fae9484266b3e6baf8886328969341` |
| `deterministic1/R/lib/mebane_model.R` | `53b8672a2b840e1519a1ed2bd7a94c76321ee4b7c879d5a9f6f7ffd0f130c582` |
| `deterministic2/tests/mebane/likelihood/g3_deterministic.R` | `86fab7d3bff353d08b12f80a8d1c9a2d1976eb2f8bc43a9dd9183df7a49e5c16` |
| `deterministic2/R/lib/mebane_model.R` | `cded39d1bbf5cc22101ad8454d255a3016f21a263df91f76ec4592888d189136` |
| `jags1/tests/mebane/likelihood/g3_jags.R` | `15b48452923289dcdea8fc1dc32192b1305c3f246dad554ccc885340be801a42` |
| `jags2/tests/mebane/likelihood/g3_jags.R` | `19ed250a7c53f88b30ded695f55113a715c862c3b9bc07aa0917ef242007db3b` |
| `jags4/tests/mebane/likelihood/g3_jags.R` | `6ecae09f28159803ec93a3da654b661a129a44da630acba17e853969c9549583` |

`delivery/command_source_map.json` contém os comandos literais, IDs dos eventos, fontes efetivas, linhagem das edições, hashes, caminhos arquivados, logs e códigos de saída. As sete versões pertencem a cinco comandos: deterministic1, deterministic2, jags1, jags2 e jags4. Seus códigos históricos de saída foram, respectivamente, 1, 0, 0, 1 e 1. Código de saída zero não é reinterpretado como aprovação científica. Os cinco logs originais foram copiados integralmente para `delivery/historical_logs/`. As durações provenientes dos eventos são identificadas como tais e não substituem os tempos registrados nos logs originais.

## Verificações e reprodução

`repair_plan.json` foi gravado antes das execuções documentais. `runs/build01/` registra a reconstrução; `runs/replay_check01/` registra a reprodução a partir dos inputs congelados. Ambos terminaram com código zero, em aproximadamente 0,17 s e 0,08 s. Cada execução preserva stdout, stderr, comando, tempo, versão do Python e snapshots do código de reparo e do plano efetivamente utilizados. Não houve tentativa documental falha nem alteração desses scripts após os testes.

A verificação reproduziu as sete fontes byte a byte, o mapa de comandos e o histórico de edições. Também passou em quatro fixtures do aplicador de diffs e em cinco controles negativos: contexto incorreto, contagem inconsistente, base ausente, hash-alvo alterado e bytes recuperados alterados. Esses controles usam apenas objetos em memória; não adulteram os arquivos congelados.

Para repetir a verificação, sem escrita e sem executar qualquer fonte R:

```sh
python3 -B quality_reports/results/mebane_gates/coordination/2026-09-30_model_proposal/provenance_repair/reconstruct_sources.py verify-seal
```

`closure_manifest.json` fecha os arquivos locais do pacote. `runs/final_verification/` contém a checagem destacada desse manifesto, vinculada ao seu hash exato; fica expressamente fora dele para evitar autorreferência. O inventário dos 350 arquivos herdados é uma referência somente de leitura, não uma nova cópia nem produção deste executor. As fontes QA congeladas conservam sua atribuição de origem.

## Limites

Nenhuma ambiguidade impediu a reconstrução dos sete alvos. A sequência, porém, não contém a adição ou atualização-base de `test_ar02_interface.R`; seu estado continua marcado como indisponível nessa sequência, fora do reparo adjudicado. Não foi inventada uma versão histórica a partir do arquivo atual. O mapa cobre os entrypoints e a dependência explícita `source("R/lib/mebane_model.R")` examinados pela QA, não todo o grafo de dependências de execução. Tampouco é possível excluir edições não registradas por uma evidência independente dos eventos salvos; a coincidência com todos os hashes-alvo e estados da auditoria é a evidência documental disponível.

Não foram executados comandos históricos, MCMC, estimação, recálculo de diagnósticos ou testes científicos. Não foram modificados revision3, fontes canônicas, protocolos, priors, seeds, critérios, ledger, README/CLAUDE ou diretório review. Não houve instalação, exclusão, restauração nem limpeza. F1/F2 e as limitações científicas permanecem fora do reparo. A próxima decisão cabe à QA e à coordenação; este executor entrega um suplemento verificável e não promove G3.
