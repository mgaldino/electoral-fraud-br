# Despacho e coordenação dos goals Mebane

Fonte de verdade: `quality_reports/plans/mebane_2022_2026_gates.json`.
Validação: `python3 scripts/mebane_gates.py check`.
Renderização: `python3 scripts/mebane_gates.py render`.

Este é um protocolo para o coordenador desta conversa. Não exige criar novas
conversas de usuário. Usar subagentes nativos; cada execução tem objetivo finito,
todos verificáveis e revisão independente. A atribuição inicial de Sol é uma
heurística; manter ou escalar com base nos artefatos e testes, sem inventar taxas
de sucesso comparativas entre modelos.

## Ciclo do coordenador

1. Ler o ledger e verificar dependências, requisitos externos, hashes vigentes,
   disponibilidade dos dados e write scopes. Despachar no máximo dois executores
   com arquivos disjuntos; reservar outro agente para revisão. Não iniciar G8
   enquanto faltar publicação oficial e aprovação dos gates prévios.
2. Preencher o prompt abaixo com o contrato integral do gate e caminhos exatos.
   Registrar agente, modelo solicitado, esforço e objetivo. Não definir orçamento
   de tokens: o usuário não especificou um. Criar um goal de coordenação por lote
   finito se necessário, sem incluir datas futuras como obrigação já executável.
3. Acompanhar por saída/logs e notificação do agente; usar wait_agent quando o
   resultado estiver no caminho crítico, por no máximo 60 segundos por chamada.
   Enquanto isso, trabalhar no outro ramo ou em integração não concorrente.
4. Congelar candidato e manifesto. Guardar os artefatos em
   `quality_reports/results/mebane_gates/Gx/roundN/`. Iniciar revisor novo com
   `fork_context=false`; o revisor recebe contrato, fontes e candidato, sem o
   parecer de autoaprovação do implementador.
5. Adjudicar cada finding contra os arquivos exatos: CONFIRMED, PARTIAL, REFUTED
   ou UNRESOLVED. Usar a skill adjudicate-review para a revisão substantiva.
   Correções seguras já abrangidas pelo pedido seguem para o implementador;
   mudança de estimando precisa de decisão substantiva do usuário.
6. Reabrir somente a parte afetada, gerar novos hashes e pedir rechecagem
   independente. Não declarar pass com falha material pendente. Um bloqueio de
   ramo não impede trabalho comprovadamente independente.
7. Atualizar todos e evidências, preencher records e executar o validador.
   Somente então declarar o gate pass e liberar dependentes. Fechar agentes
   concluídos que não serão reutilizados; preservar relatórios e IDs.

## Prompt do executor

```text
Você é [role], subagente executor do gate [gate_id] no projeto
/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud.

O usuário autorizou gates executados como goals, com todos e revisão independente.
Seu objetivo delimitado é: [goal], entregando um candidato para checagem.
Use get_goal e, se não houver goal próprio ativo, create_goal com esse objetivo.
Não defina token_budget. Se o runtime não oferecer goal nativo, registre a
limitação; não finja que foi criado. Não altere goal de outro contexto.

Contrato integral do gate:
[gate JSON: dependências, todos, entregáveis, aceitação, on_failure]

Dependências aprovadas e fontes:
[caminhos, hashes, decisões de engine/especificação e verificações pertinentes]

Você pode editar SOMENTE:
[write_scope resolvido em caminhos exatos]

Outros agentes trabalham no repositório. Preserve mudanças preexistentes e
arquivos brutos. Use apply_patch para edições manuais, R para análise e scripts
separados de relatórios. Não instale nem atualize componentes fora do escopo
autorizado. Cumpra os critérios definidos antes de olhar os resultados.

Execute cada todo, registre comando/teste/output e atualize seu relatório.
Entregue run.json, candidate_manifest.json e implementation.md em [round_path].
Faça distinguir evidência inspecionada, histórica e executada agora. O manifesto
inclui hashes de inputs, código, configuração e outputs efetivamente usados.
Não altere o ledger principal: solicite ao coordenador a mudança de estado.

Se um teste falhar, investigue e corrija dentro de seu escopo; se houver decisão
substantiva, registre a questão exata e conclua o trabalho independente. Não
relaxe critérios para obter pass. Se não houver evidência para inferência, registre
o resultado como inconclusivo, com causa e próximo teste útil.

Finalize seu goal nativo quando o objetivo de entregar o candidato revisável
estiver cumprido. O gate ainda depende de revisão e adjudicação. Seu retorno
inclui goal/estado, todos realizados, arquivos alterados, testes, tempos e limites.
```

## Prompt do revisor independente

```text
Você é [reviewer_role], revisor independente do gate [gate_id]. Você não escreveu
o candidato e não deve modificá-lo. Crie seu próprio goal: emitir revisão
verificável do candidato [manifest_sha256] contra [gate_contract]. Não crie
orçamento de tokens. Seu write scope é somente [review_directory].

Receba o contrato do gate, as fontes congeladas, candidate_manifest.json e os
artefatos. Primeiro confira seus hashes. Não herde a conversa do implementador;
não aceite seu resumo como substituto de abrir os arquivos.

Reproduza as verificações críticas usando código ou raciocínio independente.
Busque especificamente [riscos do gate]. Diferencie fidelidade matemática,
correção de código, qualidade dos dados, convergência, identificação e alcance
substantivo; o sucesso em uma dimensão não substitui as demais.

Emita review.json e review.md contendo reviewer_id, executor_id, hash do manifesto
revisado, status pass/changes_requested/inconclusive, critérios verificados,
comandos/resultados, severidade e IDs dos findings, localização exata, evidência,
risco e sugestão de reparo. Reporte lacunas de teste. Não aprove com falha material
ou inferência sem evidência. Não edite o ledger ou os arquivos do executor.

Complete seu goal quando o parecer estiver entregue, mesmo se reprovar o gate.
O coordenador adjudicará cada finding e decidirá o avanço.
```

## Estado do ledger

- `queued`: não iniciado ou aguardando dependência.
- `running`: executor produzindo candidato, com dependências aprovadas.
- `submitted`: candidato e manifesto entregues, aguardando revisão.
- `under_review`: candidato congelado sob checagem independente.
- `changes_requested`: há reparos delimitados a fazer.
- `pass`: critérios atendidos, revisão independente aprovada e adjudicação sem
  pendência material; o coordenador registrou as evidências.
- `inconclusive`: a execução não sustenta o uso pretendido. Não libera dependentes.
- `waiting_external`: requisito externo ainda não disponível; não é uma instrução
  para usar `update_goal(blocked)` em desacordo com as regras do tool.

Todos admitem `todo`, `in_progress` e `done`. `done` exige evidência localizável.
Cada evidência é um objeto com `path` relativo ao projeto e `basis` igual a
`historical`, `inspected` ou `executed`; `locator` pode indicar página, linha ou
resultado específico. Em gates aprovados, o arquivo de evidência integra o
manifesto congelado. Exemplo: `{"path": "quality_reports/results/mebane_gates/G0/round1/inventory.md", "basis": "executed", "locator": "tabela de hashes"}`.
Os estados do ledger não são estados dos goals nativos. O checker valida estrutura,
dependências e rastreabilidade básica; não substitui a avaliação científica.

Um records de gate aprovado deve conter caminhos relativos à raiz:

```json
{
  "executor_id": "id-real-do-executor",
  "reviewer_id": "id-real-do-revisor-independente",
  "candidate_manifest": "quality_reports/results/mebane_gates/Gx/roundN/candidate_manifest.json",
  "review": "quality_reports/results/mebane_gates/Gx/roundN/review.json",
  "adjudication": "quality_reports/results/mebane_gates/Gx/roundN/adjudication.json"
}
```

O manifesto mínimo é `{"files": [{"path": "caminho-relativo", "sha256":
"hash-real"}]}`; deve incluir código/configuração/dados/outputs usados, mas não
incluir a si próprio. Review e adjudication referenciam seu SHA-256 em
`candidate_manifest_sha256`, com `status: "pass"`. A adjudicação deve declarar
`unresolved_material_findings: 0`. Para G8, o records também inclui
`external_evidence`, uma lista de caminhos de evidências dos requisitos externos.
Quando usada a skill de adjudicação, esse record mínimo funciona como índice para
o relatório completo e validado da skill.

## Reabertura

Se qualquer arquivo do manifesto mudou, invalidar pass antes de reutilizar o
resultado. Devolver o gate a `changes_requested`, limpar sua aprovação no ledger
mantendo os arquivos da rodada, e devolver todos os descendentes afetados a
`queued`. Gate já em execução usa o snapshot antigo somente se isso continuar
pertinente e a divergência estiver documentada. Nunca sobrescrever evidências
de uma rodada para que coincidam com um novo candidato.
