# Fechamento do desenho dos gates Mebane

**Resultado: protocolo pronto para execução, com revisão independente aprovada.**
Data: 2026-09-28. Coordenador: `019d795a-acfa-72c2-a210-d55a46c606c2`.
Este fechamento não aprova resultados eleitorais nem executa os gates analíticos.

## Entrega

O plano tem 10 gates e 45 todos, com objetivos finitos, agentes executores,
revisores separados, modelos/esforços, dependências, arquivos de escrita,
entregáveis, critérios de aceite, evidências e procedimento em caso de falha.
O ledger JSON é a autoridade; o Markdown é gerado e os prompts especificam
despacho, goals nativos e coordenação. As referências completas permanecem
no plano.

Sol foi atribuído a nove dos dez gates de execução, com high ou xhigh conforme
o trabalho. O modelo principal fica com G2 e revisões científicas de alto
impacto. Essa é uma alocação inicial baseada no tipo de tarefa, não um benchmark
comparativo de qualidade, velocidade ou custo entre modelos.

## Evidência e adjudicação final

- Revisão científica `review_science_round2.json`: **pass**, SHA-256
  `798fb4980488473d7bf99acb06ad7dec721a211e5df26fe072d6115c21cf8b16`.
  S-F001 a S-F003 resolvidos: contrato de calibração anterior à confirmação,
  identidade do contrato e estados separados por turno.
- Manifesto científico `candidate_science_round2.json`: SHA-256
  `65acd106397a115c73b0ae50ee256091d9c892c9238f3cac25f05fba2f50a6c1`.
  Seus três documentos foram reconferidos na integração, sem mudança após o
  parecer científico.
- Revisão técnica `review_checker_round3.json`: **pass** para o reparo C-F009,
  SHA-256 `203970e23a17c286ac393863074d5bf80025b967253ae8df43ea3a3fbb762f37`.
  A rodada 2 já havia conferido C-F001 a C-F008; a rodada 3 reproduziu sem os
  helpers da suíte as trocas de review e adjudication do predecessor e confirmou
  a invalidação do dependente. O coordenador também reproduziu o defeito antes
  do reparo e executou as regressões após ele.
- Manifesto técnico `candidate_checker_round3.json`: SHA-256
  `d96172668ad59c705167e46aa6031bd5f3a87f13fe87188e1d75b82cc6ebb024`.
  Checker final `15601b30477b940bda011a7370d3a2edc269c7ffd89fe92e09d8dd9d34a93480`;
  testes `2509b41b2cea142f2a4e17e64e2f3842ead8abff71409f3cf8462f50cd5d169e`.

O coordenador aceita os reparos confirmados nos pareceres acima. Não há finding
material pendente no desenho/reparo revisado. C-F003 e C-F004 continuam com
limites explícitos: a estrutura de uma URL/atestação não prova oficialidade ou
cobertura; arquivos usados mas não declarados e o snapshot do contrato exigem
conferência do revisor. O checker não substitui a avaliação científica nem a
verificação de identidade efetiva dos agentes.

Verificações executadas: 26 testes unitários/adversariais; `check` com 10 gates
e 45 todos; igualdade textual do Markdown com o renderer; hashes dos candidatos;
DAG acíclico e dependências; `git diff --check`. As adjudicações anteriores
foram validadas contra os candidatos vigentes antes dos reparos e preservadas.
Não houve QA visual do diagrama Mermaid, reestimação, novo cálculo de poder ou
instalação. As notas sobre JAGS/Stan e dados históricos vieram de inspeção dos
artefatos, não de nova execução estatística.

## Retomada

Estado conferido: G0 a G7 `queued`, G8/T1 e G9/T2 `waiting_external`, todos os
45 todos `todo`, todos os `records` nulos. Nenhuma execução analítica foi
liberada apenas por este fechamento documental.

Iniciar por G0. Após seu pass, despachar G1 e G2 em paralelo, com arquivos
disjuntos. G7 pode iniciar após G1 enquanto G2/G3/G4 seguem no ramo metodológico.
G8/G9 requerem G6/G7 aprovados e publicação oficial adequada; T2 só é
`not_applicable` se sua não ocorrência for oficialmente comprovada.

Usar `mebane_gate_agent_prompts.md` com o contrato integral de cada gate. Para
preencher o run, consultar o schema em `implementation_checker_round2.md` e
sua extensão obrigatória `dependency_approvals` em
`implementation_checker_round3.md`. Não criar todos os goals futuros antes de
suas dependências: cada subagente recebe um objetivo finito executável, e seu
revisor recebe outro goal independente.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 scripts/mebane_gates.py check
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_mebane_gates.py' -v
```
