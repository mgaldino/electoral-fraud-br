# Parecer independente: preflight executável A/D

**Status: `changes_requested`. Um impeditivo delimitado de instrumentação de tempo.** A extração dos alvos, os funcionais conjuntos, as regras diagnósticas v2, os dados comuns e a implementação congelada de D passaram nas verificações descritas abaixo. Este parecer não libera MCMC empírica; reparo, delta-review e adjudicação continuam necessários.

Data local: 30/09/2026, America/Sao_Paulo; verificações também registradas em UTC de 01/10/2026. Executor: `019d795a-acfa-72c2-a210-d55a46c606c2`. Revisor independente: `01a0f4b8-962b-77a3-a418-6247c6219e8b`, confirmado pelo próprio goal/thread. Não implementei os candidatos.

## Achados

### AD-PREFLIGHT-01: P2, impeditivo

**Setup não tem medição separada, e ESS/s está rotulado com total parcial.** O contrato exige setup, compilação, adaptação, burn, amostragem, pós-processamento e total separados ([contrato congelado, linha 139](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/preflight_full01/sources/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/contract_v2.json:139)).

O relógio interno começa depois da leitura/validação dos dados e do carregamento de dependências ([runner congelado, linha 75](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/preflight_full01/sources/R/experimental/mebane_ad/run_jags.R:75)). Apenas compile/adapt/burn/sample entram em `phases`; a persistência recebe um nome de estágio, mas nenhuma duração ([linha 125](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/preflight_full01/sources/R/experimental/mebane_ad/run_jags.R:125)). `elapsed_seconds` termina antes da escrita de `run_result.json` e do manifesto. Esse número é usado como `ess_*_per_total_run_second` ([diagnostics congelado, linha 207](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/preflight_full01/sources/R/experimental/mebane_ad/diagnostics.R:207)), sem incorporar pós-processamento ou o total externo. O relógio externo protege o processo, mas não recupera a decomposição ausente.

**Reparo delimitado:** medir setup desde o início pertinente, distinguir persistência de amostragem, explicitar fronteiras dos totais interno/externo e fixar prospectivamente o denominador ESS/s. Um denominador apenas de geração pode ser mantido se nomeado corretamente e acompanhado de total end-to-end separado; se o denominador for end-to-end, deve incorporar o pós-processamento sem dupla contagem. Não mudar modelos, dados, sementes, iterações ou critérios. A persistência como subfase é uma recomendação para reconciliar os tempos; a exigência textual inequívoca ausente é setup separado.

O supervisor concede 1200 s ao processo de geração e outros 1200 s ao diagnóstico ([linha 73](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/preflight_full01/sources/R/experimental/mebane_ad/run_pair.py:73), [linha 88](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/preflight_full01/sources/R/experimental/mebane_ad/run_pair.py:88)). Registrar explicitamente essa cobertura na adjudicação/reparo de instrumentação. Não encontrei retry ou extensão de cadeias. O reparo pode ser verificado com relógios e engine simulados, sem executar MCMC.

### AD-PREFLIGHT-02: P3, não impeditivo neste escopo

Após enviar SIGTERM ao grupo, o supervisor espera somente o líder; SIGKILL só ocorre se esse líder continuar vivo ([supervisor congelado, linha 34](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/preflight_full01/sources/R/experimental/mebane_ad/run_pair.py:34)). No fixture próprio, um filho que ignora SIGTERM sobreviveu ao retorno de timeout e escreveu depois de o hash do log ser registrado. Hash registrado: `5bf052464cc1690cd9b95bf39b2580e751656fa4489c6535b36cc30942b9a780`; hash final: `3c8a3874bd78e5d2eee04284e13e560a24fbbb7fbf155d3b8223e561e22a775a`.

O filho terminou sozinho após intervalo curto; falha e fontes estão preservadas em [checks_supervisor.json](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/review_preflight/checks_supervisor.json). **Não foi demonstrado esse trajeto no runner atual**, que usa um único objeto rjags no processo R e não cria subprocessos explicitamente. Portanto, não acrescento um bloqueio ao piloto por esse fixture adversarial. Antes de reutilizar o supervisor para árvores de processos, tratar sobreviventes mesmo após a saída do líder e só então selar o log.

## Escopo Validado

Tabela 1. Verificações executadas sobre fontes congeladas; nenhum resultado é posterior empírica.

| Verificação | Evidência observada |
|---|---|
| Integridade | 75 arquivos completos e snapshots conferidos; 19 comuns byte-idênticos; RDA original explicitamente verificado. |
| Dados | 143 linhas/IDs na ordem original; A/W/O e seis matrizes de uns conferidos contra o RDA; swaps e permutações rejeitados. Não houve nova preparação. |
| Extração real | `ad_process_draws` executado sobre `mcmc.list` sintético 2000 × 4: 2171 alvos obrigatórios A e 1742 D, todos únicos. Extrações diretas, probabilidades de classe e identidade iteration/chain conferidas. |
| M/S e contagens | Agregação no mesmo draw/Z; endpoint literal A preservado; médias condicionais D e todos os 1.144.000 sorteios de contagens reproduzidos com seed fixada; inteireza, suporte e totais conferem. |
| Regras v2 | R-hat estrito, ESS inclusivo, range 0,05 e escala count/n corretos; NA/constância amostral não passam; ausência de isenções empíricas; secundárias não resgatam precisão. |
| D executável | Priors, variância Exp(5), alpha+b0, ordem parcial pi, probabilidades e multinomial conferidos; teste próprio com b0 não nulo/variâncias distintas; zero samplers em grafo JAGS totalmente condicionado. |
| Orquestração | Timeout do processo simples, anti-overwrite, A seguido de D, falha A sem retry e continuação D comprovados por fixtures. Ressalvas nos achados. |
| Proveniência | Hashes raw/metadata/data/contrato e manifests de pós-processamento conferidos; snapshots dos inputs reais e inits inspecionados. Manifesto de run empírico não foi produzido nesta revisão. |

Foram **67 checks próprios comuns, 27 próprios de D e 9 do supervisor (8 passaram; um reproduz AD-PREFLIGHT-02)**. As quatro suítes congeladas também foram reexecutadas com exit code zero: 69 checks do runner; três fixtures Python mais anti-overwrite; identidade DC2010; D com 1024 distribuições, 8704 células e 1024 blocos condicionais, além de leitura JAGS condicionada. A reexecução do teste D verifica o código entregue, não reabre a auditoria histórica.

O payload sintético usa os denominadores dos 143 casos, mas seus draws foram construídos sem ajuste dos modelos. Seus resultados `computationally_inconclusive` são deliberados, não evidência de desempenho A/D. A chamada própria ao JAGS usa quatro linhas artificiais, todos os nós estocásticos fixados como dados e uma leitura determinística por cadeia; `list.samplers()` retornou lista vazia.

## Vínculo e Reprodução

- Manifesto completo: `67a7336cd187dc2914066deba349b1a96a7e5cd6896beb3fb2651283f10db28a`.
- Contrato v2: `d17b7f508a7ce87eec3ca71ed7df67666b528c755e005ec9e1299e5ff9deb509`.
- A literal: `f8360126424b7a463f76a1c99efc89a8a5cb81339213bd4931559f14595fbab6`.
- RDA original: `0386dcc86155e543382c2725e9eb61ebf365b2e6f96a2b037324dbee80005196`.
- D JAGS: `6ddb9624f60b15e196cc27ed9694852c40b6553a684a9962003168da4ecfaf5b`.
- D helper: `e5154c01c6f111cc47d5e9d9f49654f1ee081bb4001664038c840b8c0d86710a`.

[review.json](/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/review_preflight/review.json) contém comandos exatos, evidência por linha, severidade e limites. `frozen_fixture_reruns.json` registra comandos internos, diretório, UTC e hashes dos logs. `source_check_full01.json`, `integrity_final.json` e `evidence_manifest.json` vinculam fontes, verificação final e artefatos. Scripts recusam sobrescrita: eventual reprodução deve usar nova pasta e preservar esta tentativa.

Não houve edição de candidatos, instalação, exclusão ou MCMC empírica. A leitura do RDA para conferir vínculos não duplicou sua preparação. A literal continua sujeita a F1/F2; D não recebe prova de identificação; M/S não são contagens observadas de fraude. Em DC2010, `a=NVoters-NValid` não é reinterpretado como medida brasileira. Não existe referência numérica externa contratada. G3/G10/produção não são aprovados. `compare_runs.R`, a síntese pareada e os resultados futuros estão fora deste parecer. Cabe ao coordenador adjudicar o achado e solicitar delta-review do reparo congelado antes de liberar o piloto.
