# Roteamento e execução do desenho dos gates

Data: 2026-09-28. Escopo desta rodada: transformar o plano em protocolo com goals,
todos, responsabilidades e checagem independente. Nenhum gate de estimação foi
aprovado por esta atividade.

## Base da escolha dos modelos

Foi aplicada a skill `adaptive-codex-router`. Seus arquivos ainda usam nomes da
família 5.6, com catálogo datado de 2026-07-10. O tool atual de subagentes oferece
GPT-6 Sol e permite `high`/`xhigh`; o usuário pediu expressamente examinar o uso
de Sol. Por isso, as recomendações antigas foram usadas somente como heurística
de complexidade, não como instrução literal para selecionar a família anterior.

Foram executadas duas consultas determinísticas ao roteador:

```sh
python3 /Users/manoelgaldino/.codex/skills/adaptive-codex-router/scripts/route_task.py 'Construir pipeline R TSE parametrizado 2022 2026 com testes deterministas e revisao independente' --stage internal --task-type coding --ambiguity medium --stakes medium --scope medium
python3 /Users/manoelgaldino/.codex/skills/adaptive-codex-router/scripts/route_task.py 'Auditar equivalencia matematica do modelo Mebane qbl entre artigo JAGS e Stan e validar inferencia com checagem independente' --stage final --task-type formal --ambiguity high --stakes high --scope large --decomposable
```

A primeira retornou `gpt-5.6-terra/high`, `single-agent`, com benchmark
`uncalibrated`. A segunda retornou `gpt-5.6-sol/xhigh`, trabalho decomposto,
revisão independente e adversarial, também `uncalibrated`. Os comandos sugeridos
de `codex exec` e tier Fast **não foram executados**. O pedido explícito de revisão
independente prevalece também sobre a primeira recomendação automática.

Decisão inicial: Sol high para dados/infraestrutura/execução; Sol xhigh para
implementação estatística e diagnósticos delimitados; modelo principal herdado
para contrato matemático e revisão metodológica decisiva. A seleção será avaliada
por artefatos e testes de cada gate. Não foi feito benchmark comparativo de modelos
nem medido ganho de custo ou velocidade. O tier efetivo não é exposto pelo tool.

## Subagentes desta rodada

| Papel | ID | Modelo solicitado | Esforço | Entrega |
|---|---|---|---|---|
| SOL-DADOS | 01a0ea81-82cb-7fb2-94b1-76cfb2b46e71 | gpt-6-sol | high | sol_dados.md |
| SOL-METODO | 01a0ea81-834a-7f43-b6b1-bdf174f14103 | gpt-6-sol | xhigh | sol_metodo.md |
| QA-PLANO | 01a0ea8e-ac85-76d1-8470-271c7dc6e6bd | herdado, sem override | xhigh | review_science_round1/round2.md/json |
| QA-LEDGER-SOL | 01a0ea8e-acec-7211-a061-220d8547fc6c | gpt-6-sol | xhigh | review_checker_round1/round2/round3.md/json |
| SOL-REPARO | 01a0ea96-c9e9-77e3-b931-0d448e1cc876 | gpt-6-sol | xhigh | implementation_checker_round2.md |

Cada subagente recebeu uma tarefa finita e instrução de criar goal próprio, sem
orçamento de tokens, com todos e escopo exclusivo. Os dois executores preparatórios
declararam seus goals completos e foram encerrados após a entrega. As revisões
receberam os arquivos congelados em `candidate_round1.json`, sem herdar conversa
dos executores. O andamento e desfecho das revisões ficam nos respectivos pareceres
e na adjudicação; esta tabela não antecipa seu veredicto.

## Correspondência com o pedido

- Dez gates operacionais, G0 a G9, com 45 todos, objetivos, dependências,
  responsabilidades, entregáveis, critérios verificáveis e resposta à falha.
- Um goal de entrega por executor, outro de revisão por agente independente,
  e coordenação do fechamento pelo agente principal.
- Ramo de prontidão 2026 separado da liberação inferencial para 2026.
- Fonte de verdade JSON e apresentação Markdown gerada; prompts reutilizáveis.
- Validador e testes adversariais para rastreabilidade básica. O validador não
  decide correção científica nem substitui os revisores.

As notas preparatórias registram inspeção de código e logs históricos; não
constituem reestimação ou prova de equivalência entre paper, JAGS e Stan. Os
arquivos `ssrn-4073770.pdf` e `ssrn-4073770.pdf.download/` eram preexistentes e foram
preservados. Nenhum pacote foi instalado nesta rodada.

## Revisões e reparos

A primeira revisão científica encontrou três lacunas, adjudicadas e corrigidas:
calibração aprovada antes dos testes confirmatórios, vínculo ao contrato exato e
estados individuais para os turnos de 2026. A rechecagem independente
`review_science_round2.json` aprovou os três documentos científicos pelos seus
hashes, sem aprovar estimativas ou resultados eleitorais.

A revisão técnica levou aos reparos C-F001 a C-F008. A segunda rodada confirmou
esses reparos e encontrou C-F009, reproduzido pelo coordenador: substituir o
parecer do predecessor não alterava seu manifesto, deixando o filho aprovado.
O coordenador implementou o reparo delimitado e o devolveu ao revisor Sol.
O estado final é o do parecer `review_checker_round3.json`, não o relato do
implementador.

Fechamento: `review_checker_round3.json` aprovou C-F009 após reprodução
independente, 26 testes e conferência do candidato. A aprovação consolidada do
protocolo está em [closure.md](closure.md); oito gates seguem `queued` e dois
`waiting_external`. Nenhum gate analítico foi marcado como executado.

Os detalhes mecânicos de despacho do `run.json` estão em
[implementation_checker_round2.md](implementation_checker_round2.md), com a
extensão obrigatória `dependency_approvals` em
[implementation_checker_round3.md](implementation_checker_round3.md). Essa
extensão inclui hashes de review/adjudication dos predecessores e concretiza
a regra já aprovada de vincular a aprovação exata. Não altera o contrato
científico, o ledger, os prompts ou o Markdown aprovados.

As adjudicações preservadas ficam em `quality_reports/adjudication/`.
O candidato original da rodada 1 é recuperável no checkpoint Git automático
`eabe93a624dd`: ledger `bcb3c384960d` e checker `480c0b886745` (prefixos
de SHA-256 conferidos). Esses registros históricos não são pass da versão
atual nem execução dos gates analíticos.
