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
   com arquivos disjuntos; reservar outro agente para revisão. Não iniciar G8/T1
   ou G9/T2 enquanto faltar publicação oficial e aprovação dos gates prévios.
2. Preencher o prompt abaixo com o contrato integral do gate e caminhos exatos.
   Registrar agente, modelo solicitado, esforço e objetivo. Não definir orçamento
   de tokens: o usuário não especificou um. Criar um goal de coordenação por lote
   finito se necessário, sem incluir datas futuras como obrigação já executável.
3. Acompanhar por saída/logs e notificação do agente; usar wait_agent quando o
   resultado estiver no caminho crítico, por no máximo 60 segundos por chamada.
   Enquanto isso, trabalhar no outro ramo ou em integração não concorrente.
4. Congelar contrato, candidato e manifesto. Guardar os artefatos em
   `quality_reports/results/mebane_gates/Gx/roundN/`, sem sobrescrever rodadas.
   Para G8/G9, incluir ano/turno/SHA-do-snapshot oficial no caminho da rodada.
   Vincular o contrato estático e as aprovações exatas dos predecessores.
   Iniciar revisor novo com
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

Em G4 há um checkpoint interno obrigatório: o revisor principal aprova o
`calibration_contract.json` de G4-T5 antes de começar G4-T6. Registrar esse
parecer, hashes, timestamps e sementes; usar simulações novas na confirmação.
O contrato fixa regra de detecção, unidade, cenários, estimandos, tolerâncias,
precisão Monte Carlo, tratamento de falhas e afirmações permitidas por poder.
Não ajustar os critérios após observar os testes confirmatórios. Esse checkpoint
não equivale à aprovação final de G4.

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
Entregue gate_contract.json, run.json, candidate_manifest.json e
implementation.md em [round_path].
Faça distinguir evidência inspecionada, histórica e executada agora. O manifesto
inclui hashes de inputs, código, configuração e outputs efetivamente usados,
assim como o run e o snapshot do contrato. Registre gate_id, round,
contract_sha256 e as aprovações exatas das dependências. Use seu ID real de
agente, nunca um papel genérico como "executor". Não omita uma dependência
utilizada apenas para fazer o manifesto passar.
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
revisado, gate_id, round, contract_sha256, status
pass/changes_requested/inconclusive, critérios verificados,
comandos/resultados, severidade e IDs dos findings, localização exata, evidência,
risco e sugestão de reparo. Reporte lacunas de teste. Não aprove com falha material
ou inferência sem evidência. Não edite o ledger ou os arquivos do executor.

Antes de atestar manifest_complete, confira o run, o código, as fontes e a
configuração; o checker não consegue descobrir sozinho inputs omitidos. IDs
devem ser UUIDs reais, canônicos e diferentes entre executor e revisor. Para
2026, confira conteúdo da publicação oficial, cobertura e turno; uma URL do
TSE e seu hash isoladamente não provam suficiência dos dados.

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
- `not_applicable`: somente G9, por não ocorrência oficial de segundo turno,
  documentada e checada independentemente. Não significa dado ausente,
  indisponível ou inferência concluída; não marca os todos analíticos como feitos.

Todos admitem `todo`, `in_progress` e `done`. `done` exige evidência localizável.
Cada evidência é um objeto com `path` relativo ao projeto e `basis` igual a
`historical`, `inspected` ou `executed`; `locator` pode indicar página, linha ou
resultado específico. Em gates aprovados, o arquivo de evidência integra o
manifesto congelado. Exemplo: `{"path": "quality_reports/results/mebane_gates/G0/round1/inventory.md", "basis": "executed", "locator": "tabela de hashes"}`.
Os estados do ledger não são estados dos goals nativos. O checker valida estrutura,
dependências e rastreabilidade básica; não substitui a avaliação científica.

## Contrato e artefatos da rodada

O contrato estático é o objeto do gate excluindo apenas `status` e `records`,
e, em cada todo, `status` e `evidence`. Seu SHA-256 usa JSON canônico com chaves
ordenadas, sem espaços, em UTF-8. O snapshot `gate_contract.json` integra o
manifesto. Mudar critério de aceitação, objetivo, tarefa ou dependência invalida
a aprovação, mesmo se o código ficar igual.

Os exemplos a seguir mostram a estrutura, não registros prontos: substituir
todos os placeholders por valores reais, em especial UUIDs e hashes. O checker
e seus testes são a especificação mecânica executável.

Um `records` de gate aprovado contém caminhos relativos à raiz:

```json
{
  "executor_id": "id-real-do-executor",
  "reviewer_id": "id-real-do-revisor-independente",
  "run": "quality_reports/results/mebane_gates/Gx/roundN/run.json",
  "candidate_manifest": "quality_reports/results/mebane_gates/Gx/roundN/candidate_manifest.json",
  "review": "quality_reports/results/mebane_gates/Gx/roundN/review.json",
  "adjudication": "quality_reports/results/mebane_gates/Gx/roundN/adjudication.json"
}
```

`run.json` declara identidade da rodada, `executor_id`, contrato, caminhos
efetivamente usados em `inputs`, `code`, `configuration`, `outputs` e
`dependency_manifests`: mapa do ID de cada predecessor para o SHA-256 de seu
manifesto vigente. Registrar também comandos, exit codes, seeds, versões,
tempos e identidade dos goals para reprodução.

`candidate_manifest.json` declara a mesma identidade `gate_id`, `round` e
`contract_sha256`, mais `files`, lista de objetos `path`/`sha256` (e tamanho
quando disponível). Incluir o run, o snapshot do contrato e todos os caminhos
declarados na execução; não incluir o próprio manifesto, a revisão posterior
ou a adjudicação posterior, para evitar referências circulares.

`review.json` e `adjudication.json` referenciam a identidade exata da rodada e
`candidate_manifest_sha256`, com `status: "pass"` somente após suas verificações.
O review registra `manifest_complete: true` após inspeção real. A adjudicação
inclui `review_sha256`, `unresolved_material_findings: 0` e todos os IDs de
findings, suas classificações e resolução. Um review alterado após a adjudicação
ou um finding material sem resolução invalida a aprovação. Quando usada a
skill de adjudicação, esse registro funciona como índice para o relatório
completo e validado da skill.

## Publicação de 2026

G8/T1 e G9/T2 têm goals, candidaturas, revisões e estados separados. G8 pode
passar enquanto G9 continua `waiting_external` ou fica `inconclusive`. Em cada
retificação oficial, preservar a rodada anterior e abrir outra com o snapshot
novo. A avaliação futura não deve sobrescrever a referência de 2022.

O `records.external_evidence` lista caminhos de atestações JSON, uma por
requisito externo. Cada atestação registra gate, requisito exato, URL oficial
HTTPS do TSE, data de publicação, ano/turno, snapshot local e SHA-256,
`coverage_pass: true`, revisor independente e data da checagem. O revisor deve
abrir a fonte e confirmar sua adequação; os testes mecânicos de URL, hash,
datas e turno apenas eliminam inconsistências estruturais.

G9 só pode usar `not_applicable` se `allow_not_applicable` estiver habilitado e
`records.applicability_evidence` apontar atestação independente de não ocorrência
oficial de T2: `requirement: "turn_not_held"`, `occurrence: "not_held"`, fonte,
snapshot, datas e identidade do revisor. A ausência de um arquivo de resultados
nunca constitui evidência de que o turno não ocorreu. Encerrar nesse caso apenas
o goal de verificar a aplicabilidade, sem alegar que houve estimação.

## Reabertura

Se contrato, aprovação de predecessor ou qualquer arquivo do manifesto mudou,
invalidar pass antes de reutilizar o
resultado. Devolver o gate a `changes_requested`, limpar sua aprovação no ledger
mantendo os arquivos da rodada, e devolver todos os descendentes afetados a
`queued`. Gate já em execução usa o snapshot antigo somente se isso continuar
pertinente e a divergência estiver documentada. Nunca sobrescrever evidências
de uma rodada para que coincidam com um novo candidato.
