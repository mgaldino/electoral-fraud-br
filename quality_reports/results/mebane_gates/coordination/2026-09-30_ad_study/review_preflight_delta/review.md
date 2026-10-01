# Delta-review independente: preflight_full02

**Status: PASS. Sem achados novos.** Os reparos de `AD-PREFLIGHT-01` e `AD-PREFLIGHT-02` foram confirmados em execução sintética. A revisão anterior das partes científicas inalteradas permanece aplicável; cabe ao coordenador adjudicar este delta e fechar os reparos.

Revisor: `01a0f4b8-962b-77a3-a418-6247c6219e8b`, confirmado pelo próprio goal/thread. Executor: `019d795a-acfa-72c2-a210-d55a46c606c2`. Data local: 30/09/2026; UTC: 01/10/2026. Nenhum candidato foi editado.

## Vínculo do Parecer

- Manifesto full02: `7875d46b09301906dc3e7211b8319e53c43f3f19c21e141687d55a65cb65a337`.
- Manifesto full01 anterior: `67a7336cd187dc2914066deba349b1a96a7e5cd6896beb3fb2651283f10db28a`.
- Contrato v2, inalterado: `d17b7f508a7ce87eec3ca71ed7df67666b528c755e005ec9e1299e5ff9deb509`.
- Adjudicação anterior: `85658238e5be22feaf2c0ad2f52684d8a122d9c7af576cc4fe422a92787796e7`.

Conferidos os **146 arquivos congelados do full02**, os 75 snapshots anteriores e os 171 artefatos do manifesto da revisão anterior. Quatro arquivos existentes mudaram: runner R, diagnóstico R, supervisor Python e teste do supervisor. Os outros 71 permaneceram byte-idênticos; nenhum foi removido. Os acréscimos são documentação, fixture de tempo e registros/fontes de revisão e testes. Modelos A/D, helper D, RDA, dados preparados, contrato, seeds e critérios científicos permanecem inalterados.

## Fechamento dos Achados

**AD-PREFLIGHT-01: reparo aceito.** Setup agora inclui leituras, validação, carregamento do engine, snapshots e persistência dos inputs/inits/metadata ([runner congelado, linha 101](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/preflight_full02/sources/R/experimental/mebane_ad/run_jags.R:101)). `persist_raw` está separado ([linha 139](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/preflight_full02/sources/R/experimental/mebane_ad/run_jags.R:139)). `on.exit` registra duração parcial e `completed=FALSE` em erros ordinários ([linha 90](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/preflight_full02/sources/R/experimental/mebane_ad/run_jags.R:90)).

A reexecução sintética em **ambos** os modelos confirmou o novo nome `ess_*_per_internal_generation_second` e o cálculo exato ESS dividido por `run_result.elapsed_seconds` ([diagnostics, linha 207](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/preflight_full02/sources/R/experimental/mebane_ad/diagnostics.R:207)). O denominador continua parcial, mas já não é apresentado como total-process. [timing.md, linha 13](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/preflight_full02/sources/R/experimental/mebane_ad/timing.md:13) fixa o que entra em cada relógio; geração e diagnóstico possuem limites externos separados de 1200 s, sem extensão de MCMC. A futura síntese dos totais externos permanece fora desta revisão.

**AD-PREFLIGHT-02: reparo aceito.** O supervisor agora envia SIGKILL ao grupo após a espera, mesmo se o líder já terminou ([linha 44](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/preflight_full02/sources/R/experimental/mebane_ad/run_pair.py:44)). Reutilizei o mesmo contraexemplo independente que falhou no full01, alterando apenas a pasta de saída. O filho ignorando SIGTERM não escreveu tardiamente; o hash permaneceu `5bf052464cc1690cd9b95bf39b2580e751656fa4489c6535b36cc30942b9a780` após a observação adicional de 1,2 s.

## Verificações Executadas

Tabela 1. Testes próprios de delta; nenhum chama compilação ou amostragem real de modelo.

| Controle | Resultado |
|---|---|
| Encaminhamento do engine | `identical()` confirmou as quatro funções originais: `jags.model`, `adapt`, `stats::update` e `coda.samples`. Não há wrappers alterando argumentos. |
| Preservação científica | Corpos/formais de validação, seleção de dados, inits e monitores idênticos; chamadas capturadas preservam dados, inits, quatro chains, 1000/5000/2000 e thin=1. |
| Fases e erros | Sucesso A/D, falhas injetadas em todas as seis fases e erro de leitura: duração parcial, estágio, evento, resultado e interrupção na fase correta. |
| Pós-processamento | Mesmos draws sintéticos anteriores; 2171 alvos A e 1742 D; diagnósticos idênticos salvo as duas colunas ESS/s e seus denominadores. |
| Saídas científicas sintéticas | CSVs de funcionais conjuntos e classes byte-idênticos; objeto de contagens secundárias D idêntico; regras e veredictos preservados. |
| Supervisor | Nove checks passaram: sucesso, falha, timeout, descendente, anti-overwrite, sequência A/D, ausência de retry e rejeição de hash inválido. |

**49 checks R de delta + 9 checks Python passaram.** Os 67 controles comuns e 27 de D da revisão anterior foram reutilizados por vínculo de hashes, sem repetir enumeração matemática, auditoria histórica ou preparação dos dados. As suítes fornecidas `runner_checks03`, `timing_checks01` e `supervisor_checks02` foram inspecionadas como evidência congelada, não contadas como testes próprios reexecutados.

Em `run_result.phases`, a duração de `persist_raw` está completa; dentro do próprio `raw_chains.rds`, aparecem apenas as fases anteriores à sua escrita. Isso é consistente com a posição da serialização. Encerramento forçado pode impedir a última gravação de R; o registro externo continua sendo a evidência de timeout, como documentado prospectivamente.

[review.json](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/review_preflight_delta/review.json) registra hashes, comandos, evidência por linha e resultados. `source_delta.json` preserva o diff de hashes; `checks_delta.json/log` e `checks_supervisor.json` preservam a execução; `integrity_final.json` e `evidence_manifest.json` selam fontes e artefatos. Os scripts recusam sobrescrita.

**Limite:** PASS do reparo de preflight, não avaliação empírica. Não houve MCMC, instalação, exclusão ou edição de candidato. `compare_runs.R`, convergência, eficiência empírica e resultados futuros não foram revisados. As limitações deliberadas anteriores de A/D continuam válidas; G3, G10 e produção não recebem aprovação. O coordenador adjudica este parecer antes de eventual release do piloto limitado ao contrato v2.
