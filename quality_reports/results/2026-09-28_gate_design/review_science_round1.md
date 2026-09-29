# QA-PLANO: revisão científica e de governança, round1

**Status: `changes_requested`.** O candidato tem um DAG coerente, separação explícita entre execução e revisão e salvaguardas contra conclusões eleitorais indevidas. Faltam três requisitos materiais para que a aprovação futura seja determinada pelo protocolo: regra operacional de calibração inferencial, vínculo imutável ao contrato de aceite e estado individual por turno em G8. Não há julgamento de validade empírica do qbl nem recomendação de executar novos MCMC neste turno.

- Data local: 2026-09-28, America/Sao_Paulo.
- Revisor: QA-PLANO; contexto nativo `01a0ea8e-ac85-76d1-8470-271c7dc6e6bd`.
- Goal próprio: emitir este parecer completo, independentemente de aprovação. Criado sem `token_budget`, após `get_goal` retornar ausência de goal. Nenhum goal de outro contexto foi alterado.
- Independência: este revisor não escreveu o candidato, não o modificou e não leu as notas Sol preparatórias, a nota de autoavaliação ou o parecer separado sobre o validator. O manifesto não informa o ID nativo do autor; não foi inventada uma identidade para ele.
- Autoridade: `quality_reports/plans/mebane_2022_2026_gates.json`. Prompts e MD foram confrontados com esse arquivo. Instruções e plano antigos foram usados apenas como contexto, não como autoridade concorrente.

## 1. Identidade do Candidato Científico

Raiz de todos os caminhos relativos: `/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud`.

Manifesto: `quality_reports/results/2026-09-28_gate_design/candidate_round1.json`.

SHA-256 do manifesto round1 de referência: `ae5f84bef1186ad1f6d1500e5a308bc7d500c0e447cb39bbfee07eed5027da7a`.

Por delimitação explícita do usuário recebida durante a revisão, **o vínculo de validade deste parecer abrange somente os três documentos científicos abaixo**. SOL-REPARO pode modificar `scripts/mebane_gates.py` e `tests/test_mebane_gates.py` em uma revisão de código separada. Esses dois arquivos foram conferidos apenas na entrada e não são alvos da reconferência final nem condicionam este parecer.

| Arquivo do manifesto | SHA-256 esperado e observado | Escopo da inspeção |
|---|---|---|
| `quality_reports/plans/mebane_2022_2026_gates.json` | `bcb3c384960d87924178128fe4c7ce3db0a841e4e7941df26864c1f35b2dab7f` | Leitura integral, autoridade |
| `quality_reports/plans/mebane_gate_agent_prompts.md` | `173bf29b1a6bd21247591a49f2d9ce3b3475d2e7cf0c748a446d60ab69c40838` | Leitura integral |
| `quality_reports/plans/2026-09-28_mebane_2022_2026_gates.md` | `59dc46f99f5ed059cd334f84cbdbb4952b1994870f96c653cf7c66a3c10af3bb` | Leitura integral e comparação textual |

Os cinco hashes originais conferiram na entrada. Isso é um registro histórico da conferência, não uma afirmação sobre o estado atual do checker em reparo. Na entrega, os **três documentos científicos** foram reconferidos contra os hashes round1, sem `hash mismatch`. A leitura tem validade para esses bytes, não para uma versão posterior do protocolo. O JSON preserva separadamente a conferência inicial completa e a conferência final delimitada.

## 2. Findings

### S-F001 | Alta / P1 | Falta uma regra verificável de aceite da calibração

**quoted_finding:** "G4 exige medir recuperação, cobertura e falsos positivos, mas não exige congelar uma regra de detecção e critérios de aprovação dessas medidas antes da avaliação confirmatória; G6 herda essa lacuna ao concluir a análise de poder."

**Localizadores:** JSON, `gates[G4].todos[G4-T2,G4-T5]`, linhas 143 e 146; `gates[G4].acceptance`, linha 149; `gates[G6].todos[G6-T4]` e `acceptance`, linhas 188 e 192. Prompts, linhas 65 e 73-76.

**Evidência direta:** G4-T2 manda "medir recuperação, cobertura e falso positivo com incerteza Monte Carlo". G4-T5 fixa especificações, número de réplicas e precisão dos testes "conforme o piloto". Os critérios de G4 definem quatro cadeias, Rhat e ESS, mas para recuperação exigem apenas "checar" e verificar um cenário independentemente. G6-T4 manda "Concluir a avaliação de recuperação/poder/falsos positivos dimensionada em G4". Não há tarefa ou requisito que defina o evento de detecção usado para calcular falso positivo/poder, sua unidade de avaliação, os critérios de recuperação/cobertura nem a consequência de exceder a tolerância aprovada.

**Risco concreto:** duas execuções podem entregar todos os produtos descritos, usar regras de detecção diferentes e produzir taxas incomparáveis. Mesmo com cadeias adequadas, uma cobertura insuficiente ou falso positivo excessivo não encontra um critério operacional que determine a reprovação. O revisor futuro teria de definir o que constitui "falha material" depois de observar a avaliação. Este é um defeito de especificação do gate, não uma alegação de que algum modelo ou resultado já falhou.

**Salvaguardas consideradas:** o prompt já proíbe relaxar critérios e manda defini-los antes dos resultados; G4 exige incerteza Monte Carlo e registro de fits falhos; G6 proíbe prova automática de fraude/ausência. Essas regras são pertinentes, mas não atribuem a ninguém a entrega e aprovação do contrato de calibração faltante. Não se exige que a exploração de pilotos seja cega ou que todo cenário tenha alto poder.

**Reparo delimitado:** tornar obrigatória uma etapa anterior à avaliação confirmatória, com configuração versionada e aceite independente, que fixe: evento/regra de detecção e unidade; cenários e estimandos cobertos; tolerâncias justificadas para recuperação, cobertura e falsos positivos, avaliadas com a incerteza Monte Carlo; tratamento das réplicas falhas; e quais afirmações cada faixa de poder permite ou impede. Pilotos podem dimensionar custo e precisão, mas seus resultados devem ser separados da avaliação confirmatória que decidirá o aceite. O protocolo deve atribuir responsável, artefato e precedência a essa etapa. Valores numéricos podem ser decididos no gate apropriado, antes da avaliação correspondente.

**Critério de rechecagem:** deve ser possível, dado um resultado de simulação, aplicar a regra congelada e obter `pass`, `changes_requested` ou `inconclusive` sem inventar um limiar depois. Uma taxa de poder baixa pode sustentar um limite de detectabilidade; não autoriza conclusão de ausência de fraude nem precisa ser escondida para aprovar o trabalho documental.

### S-F002 | Média / P2 | O parecer não fica obrigatoriamente vinculado à versão do contrato

**quoted_finding:** "O contrato do gate é entregue ao revisor, mas o protocolo não exige arquivar seu snapshot e hash no vínculo de aprovação; mudanças de critérios ou dependências podem conservar um parecer cujo manifesto continua idêntico."

**Localizadores:** JSON, `operating_rules[6]`, linha 23, e `evidence_contract`, linhas 31-37; prompts, linhas 87-93, 131-159.

**Evidência direta:** o manifesto deve conter código, configuração, dados e saídas. Review e adjudication referenciam `candidate_manifest_sha256`. O prompt entrega `[gate_contract]` ao revisor, mas não exige um `gate_contract_sha256`, a inclusão de um snapshot do contrato no manifesto ou uma identidade imutável equivalente. A regra de reabertura enumera mudanças de entrada, código e configuração; o procedimento dos prompts verifica arquivos do manifesto. Não há exigência expressa de reabrir a aprovação por mudança material de critério, estimando, dependência ou condição externa do próprio gate.

**Risco concreto:** após uma revisão, o coordenador pode revisar legitimamente o ledger, que também contém os critérios. Se o contrato não integrou o manifesto, os mesmos artefatos e o mesmo `candidate_manifest_sha256` permanecem, mas já não é possível determinar documentalmente qual regra de aceite foi aprovada. O finding trata da rastreabilidade científica exigida pelo protocolo, não afirma que o validator tenha um bug nem que ocorreu alteração indevida neste candidato.

**Salvaguardas consideradas:** o protocolo exige fontes congeladas, hashes, adjudicação, proíbe relaxar critérios e exige rechecagem de alterações materiais. Isso protege os artefatos explicitamente manifestados. Falta tornar o contrato um desses artefatos obrigatórios, em vez de depender de uma interpretação implícita de "inputs" ou "configuração".

**Reparo delimitado:** em cada despacho, arquivar uma projeção imutável do contrato do gate, incluindo todos, aceitação, dependências aprovadas, estimando/especificação, requisitos externos e âmbito de inferência. Incluí-la no manifesto ou registrar seu hash em run/review/adjudication. Definir que alteração material desse contrato invalida a aprovação correspondente e reabre os dependentes afetados. Não é necessário hashear todo o ledger mutável: mudanças meramente operacionais de status podem ficar fora da projeção.

**Critério de rechecagem:** uma alteração apenas do critério de aceite deve produzir uma nova identidade de contrato e tornar o parecer antigo inadequado para liberar o gate novo, ainda que código, dados e resultados tenham os mesmos hashes.

### S-F003 | Média / P2 | G8 precisa de instâncias e estados por turno

**quoted_finding:** "G8 exige execução, espera e inconclusividade por turno, mas oferece somente um status, um conjunto de todos e um records; falta a regra que permita concluir T1 sem aprovar, sobrescrever ou manter indefinidamente ativo o trabalho de T2."

**Localizadores:** JSON, `operating_rules[12]`, linha 29; `gates[G8]`, linhas 218-236, especialmente `status`, `todos`, `on_failure` e `records`; prompts, linhas 21-22, 26-29, 78-80 e 110-148.

**Evidência direta:** o goal manda aplicar "por turno"; a condição externa se refere ao turno efetivamente realizado; o tratamento de falha manda "Manter o turno afetado inconclusive ou waiting_external". Entretanto, o objeto G8 tem um único `status: waiting_external`, quatro todos únicos e um único `records: null`. O contrato mínimo de run/records não exige chave de instância por ano/turno/snapshot, nem há regra de composição do estado global de G8. `roundN` designa rodadas de candidato/revisão, sem distinguir uma correção de T1 de uma primeira execução de T2.

**Risco concreto:** quando T1 estiver revisado e T2 ainda não tiver dados, não há representação definida para ambos os estados. Um coordenador pode marcar G8 globalmente `pass` com evidência apenas de T1; outro pode deixar o goal de T1 aberto à espera de T2; outro pode substituir o único records pela rodada de T2. As três interpretações comprometem, respectivamente, escopo de aprovação, conclusão finita por goal ou auditabilidade. Não se afirma que o protocolo presuma a existência de T2: ele explicitamente a condiciona.

**Reparo delimitado:** definir instâncias por ano, turno e versão oficial de entrada, com todos, goal de execução, goal de revisão, manifesto, revisão, adjudicação e status próprios. Alternativamente, separar os subgates condicionais por turno. Definir como o estado global é composto e como se registra que T2 oficialmente não ocorreu, sem tratar isso como inferência realizada. Uma revisão posterior do arquivo TSE deve abrir nova versão apenas da instância afetada e preservar a anterior.

**Critério de rechecagem:** representar sem perda os casos T1 aprovado/T2 aguardando, T1 aprovado/T2 inconclusivo e T2 oficialmente não aplicável; nenhum deles pode atribuir resultados não executados a T2. O goal de T1 deve poder terminar após a entrega revisável, independentemente do calendário de T2.

## 3. Critérios Conferidos

| Critério | Resultado da revisão do protocolo | Evidência |
|---|---|---|
| Identidade do candidato científico | Conferida: três documentos iguais ao round1; cinco arquivos conferidos apenas na entrada | Manifesto de referência e SHA-256 recalculados |
| Estado pendente | Conferido: G0-G7 `queued`, G8 `waiting_external`; 40 todos `todo`; nove `records` nulos | JSON integral; contagem independente |
| DAG | Acíclico, sem referência ausente | Ordenação independente: G0; G1/G2; G3/G7; G4; G5; G6; G8 |
| Dependências inferenciais | G6 herda G0-G5; G8 herda todos os gates anteriores | Fecho transitivo calculado independentemente |
| Paralelismo | G7 pode seguir depois de G1 enquanto o ramo metodológico avança | JSON linhas 70, 92, 114, 135, 200 e 221 |
| Goals e todos | Entrega do executor não equivale a `pass`; revisão tem goal próprio e pode reprovar; sem token budget implícito | JSON linhas 17-20; prompts linhas 47-51, 78-80 e 106-107 |
| Independência | Revisor novo, `fork_context=false`, sem autoaprovação e sem escrever no candidato; adjudicação pelo coordenador | JSON linhas 19-23 e 35-36; prompts linhas 26-38 e 86-107 |
| Sol versus modelo herdado | Alocação é heurística explícita, não afirma superioridade medida; matemática G2 e QA inferencial ficam em `inherit` | JSON linhas 8-14 e executor/reviewer de cada gate |
| Integridade de dados | Contagens, zeros, missing, duplicatas, joins, elegibilidade e totais oficiais são requisitos explícitos | G1-T2 a G1-T5 e acceptance |
| JAGS não presumido correto | G2 requer mapear paper/código; G3 exige referência small-N e fidelidade do alvo | G2-T1 a T5; G3-T1 a T4 |
| Engines distintos | Stan aproximado é rotulado; comparação de equivalência exige mesmo alvo; inviabilidade de Stan não valida JAGS por si | G3 acceptance; G4 acceptance; `stan/eforensics_qbl.stan:1-12` |
| Convergência e identificação | Limiares MCMC não são declarados suficientes; modos, recuperação, MCSE e não identificação não são dispensados | G4-T4 e acceptance; G6-T2 |
| Calibração e poder | Requisito material incompleto | S-F001 |
| Fraude/ausência e margem | Proibição expressa de prova automática; origem dos votos stolen e margem exigem derivação/limites | G2-T4 e G6 acceptance |
| Recursos e parada | G5 exige memória/tempo, interrupção pequena, runner em falha e cota para nacional; sem substituição silenciosa do alvo | G5-T1 a T4 e acceptance; JSON linhas 27-28 |
| 2026 | G7 é apenas data-ready; G8 exige dados oficiais e revalidação inferencial; T2 é condicional | G7/G8 e readiness |
| Granularidade temporal | Requisito material incompleto | S-F003 |
| Governança do contrato | Requisito material incompleto | S-F002 |
| MD versus autoridade | 122 textos de goals/todos/entregáveis/aceitação/on_failure encontrados literalmente; todas as arestas presentes | Checagem Python independente, sem usar o renderer |

Usar o mesmo modelo em executor e revisor não constitui, por si, autoaprovação: o protocolo exige agentes/contextos separados. Não foi verificado se o runtime futuro efetivamente cumprirá essa configuração. O modelo principal herdado não foi identificado por um nome presumido.

## 4. Verificação e Limites

Foram executados SHA-256, leitura de fontes, parsing JSON, contagem de estados/todos, ordenação topológica, cálculo de ancestrais e comparação textual do MD. As verificações usaram Python padrão e ferramentas de leitura; não importaram nem executaram o validator do candidato. `git diff --stat` estava vazio para arquivos rastreados antes da entrega; os arquivos novos do candidato já estavam não rastreados e foram preservados.

O código Stan foi inspecionado apenas para confirmar que a portagem existente se declara aproximada, não para provar suas equações. O script nacional e o script JAGS foram lidos como contexto de execução, não rodados. O resumo histórico JAGS de zone FE contém, por exemplo, `Gelman.diag` de 4.597 para pi[1] e 13.506 para iota.s.alpha (linhas 34-44). São valores históricos inspecionados, de outro diagnóstico, não novos Rhat rank-normalized calculados nesta revisão. Eles corroboram a necessidade dos gates G0/G4; não são novos findings contra um candidato que já manda recalculá-los.

Não foram lidos os PDFs como parte de uma nova auditoria matemática completa; a correspondência paper/qbl permanece tarefa de G2. Não houve reestimação, carregamento/reprocessamento de cadeias, teste empírico de identificação, cálculo novo de poder, consulta de resultados eleitorais de 2026, instalação, mudança de ambiente ou execução dos gates. Não foi conduzida revisão do código do validator. A conclusão é sobre suficiência do protocolo congelado, não sobre existência ou ausência de fraude, convergência de modelos ou disponibilidade de dados eleitorais futuros.

**Encaminhamento:** adjudicar S-F001 a S-F003 contra este candidato e, se confirmados, corrigir apenas o protocolo, gerar novo manifesto e rechecá-lo independentemente. A entrega deste parecer conclui o goal de revisão, mesmo com `changes_requested`; não libera gates operacionais nem modifica a autorização de execução.

Os achados da revisão separada do checker não foram usados para aprovar ou reprovar este protocolo. S-F002 descreve um requisito documental de governança e não é um teste ou veredicto sobre o comportamento do validator, antes ou depois do reparo.

Artefatos exclusivos desta revisão: `quality_reports/results/2026-09-28_gate_design/review_science_round1.md` e `quality_reports/results/2026-09-28_gate_design/review_science_round1.json`. O JSON registra o SHA-256 deste Markdown; os hashes finais dos dois arquivos acompanham a entrega, sem tentar inserir em cada arquivo seu próprio hash.
