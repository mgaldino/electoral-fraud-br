# Revisão independente do checker e renderer, rodada 1

**Revisor:** QA-LEDGER-SOL (`01a0ea8e-acec-7211-a061-220d8547fc6c`).  
**Goal:** revisão independente do protocolo de coordenação e da ferramenta de ledger.  
**Status:** `changes_requested`. Há contraexemplos de aprovação estrutural indevida. Este parecer não avalia a validade científica dos gates.

## Base congelada e verificações

O SHA-256 de `candidate_round1.json` é `ae5f84bef1186ad1f6d1500e5a308bc7d500c0e447cb39bbfee07eed5027da7a`. Recalculei os cinco hashes nele registrados, todos iguais:

| Arquivo | SHA-256 |
|---|---|
| `scripts/mebane_gates.py` | `480c0b88674513f6cd4ffb1f34f59ab19efbf4cfaf50c0b403fd105aef8e33b6` |
| `tests/test_mebane_gates.py` | `f192968af7d7988421541ea6a92f012ac357c7a4aa301c44b9fe469261232c74` |
| `quality_reports/plans/mebane_2022_2026_gates.json` | `bcb3c384960d87924178128fe4c7ce3db0a841e4e7941df26864c1f35b2dab7f` |
| `quality_reports/plans/mebane_gate_agent_prompts.md` | `173bf29b1a6bd21247591a49f2d9ce3b3475d2e7cf0c748a446d60ab69c40838` |
| `quality_reports/plans/2026-09-28_mebane_2022_2026_gates.md` | `59dc46f99f5ed059cd334f84cbdbb4952b1994870f96c653cf7c66a3c10af3bb` |

Executei `python3 -m unittest discover -s tests -p 'test_mebane_gates.py' -v`: 16 testes, todos `ok`. Executei `python3 scripts/mebane_gates.py check`: `PASS: 9 gates, 40 todos; structural checks only`. O texto de `render(ledger)` coincide byte a byte com o Markdown gerado existente (27.396 caracteres). Os casos adversariais abaixo foram executados com `PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY' ... PY`, importando o script original, copiando o ledger em memória e usando `tempfile.TemporaryDirectory(dir='/tmp')` para os fixtures. Nenhum arquivo do candidato foi alterado.

## Findings

**C-F001, alta, revisão de outro gate aceita.** Em `scripts/mebane_gates.py:71-83` e `:84-87`, os records de aprovação não são vinculados ao ID do gate nem aos seus critérios. Fixture: G0 e G1 `pass`, todos os todos `done` com a mesma evidência, mesmo manifesto e mesmos `review.json`/`adjudication.json`; ambos os JSON trazem explicitamente `"gate_id": "G0"`. Com G0 aprovado para satisfazer a dependência de G1, `validate(plan, tmp_root)` retornou `[]`. Uma revisão exclusiva de G0 pode liberar G1 sem avaliação de seus critérios. Exigir identidade de gate/rodada em manifesto, revisão e adjudicação, e conferir sua coerência com o gate aprovado; a existência de um arquivo de evidência não demonstra os todos de outro gate.

**C-F002, média, independência burlável por alias textual.** Em `scripts/mebane_gates.py:52-55`, basta que as strings de `executor_id` e `reviewer_id` sejam diferentes. Fixture com `executor_id="agent"` e `reviewer_id="agent "` tanto em records quanto em review, manifesto válido e G0 `pass`: `validate(...) == []`. O mesmo agente pode aparecer como dois identificadores quase iguais. Exigir IDs canônicos de agente e conferir com a atribuição/registro do despacho; no mínimo validar tipo e normalização antes da comparação.

**C-F003, alta, requisito externo aceita arquivo irrelevante.** Em `scripts/mebane_gates.py:144-157` e `:88-94`, o requisito de G8 é reduzido à existência de qualquer arquivo. Fixture: os nove gates `pass` com um único manifesto contendo `note.txt` de conteúdo `not official TSE data`; todos os todos apontam para ele e `G8.records.external_evidence=["note.txt"]`. `validate(...)` retornou `[]`. Assim o checker pode sinalizar G8 como aprovado antes dos dados oficiais publicados. O checker deve exigir um registro estruturado de fonte oficial, turno, publicação e cobertura validada para G8, ou recusar automatizar essa condição e exigir uma atestação independente verificável do coordenador. Um path genérico não deve satisfazer o requisito.

**C-F004, média, código omitido do manifesto não invalida aprovação.** Em `scripts/mebane_gates.py:59-70`, só se recalculam hashes dos paths declarados. Fixture: G0 `pass`, manifesto contendo apenas `note.txt`, enquanto `analysis.py` também existe no diretório temporário. Alterar `analysis.py` de `model = 1` para `model = 2` manteve `validate(...) == []`. Isso não contradiz a detecção já testada de mudanças em arquivos *incluídos*, mas quebra a regra de reabertura quando código usado fica fora do manifesto. Conferir a completude por gate contra entregáveis/run e entradas efetivas antes de aceitar `pass`; a ferramenta isolada não consegue inferir quais arquivos foram usados.

**C-F005, média, alteração posterior da revisão não invalida adjudicação.** Em `scripts/mebane_gates.py:70-83`, a adjudicação é vinculada apenas ao hash do manifesto, não ao hash da revisão, e o checker não reconcilia findings. Após uma aprovação G0 válida, regravei `review.json` com `status: pass` e `findings: [{"id":"C-RED","severity":"critical","status":"unresolved"}]`, mantendo `adjudication.json` antigo com `unresolved_material_findings: 0`. `validate(...)` permaneceu `[]`. Um parecer modificado após a adjudicação pode deixar um achado material sem nova decisão. Vincular a adjudicação ao digest da revisão e conferir os IDs/classificações dos findings antes do `pass`; preservar os arquivos de rodadas anteriores.

**C-F006, média, `check` aprova ledger que quebra `render`.** `validate` em `scripts/mebane_gates.py:100-188` não verifica campos usados por `render` em `:212-259`; `main` em `:273-283` só trata erros de leitura/validação. Com cópias JSON em `/tmp`, removi `date`, troquei `routing` por `[]` e troquei `G0.write_scope` por `[42]`. Cada `python3 scripts/mebane_gates.py check --ledger /tmp/...json` retornou código 0 e `PASS: 9 gates, 40 todos`; `render --ledger /tmp/...json --output /tmp/...md` retornou código 1 com, respectivamente, `KeyError: 'date'`, `AttributeError: 'list' object has no attribute 'items'` e `TypeError: can only concatenate str (not "int") to str`. Um update válido segundo o checker pode interromper a geração do plano. Validar integralmente os campos consumidos pelo renderer e reportar erro controlado antes de escrever.

**C-F007, baixa, JSON malformado produz traceback em vez de diagnóstico.** Em `scripts/mebane_gates.py:123` e `:178-184`, `status=[]` ou `evidence=[{"path":"anything","basis":[]}]` causa `TypeError: unhashable type: 'list'`. O comando `check --ledger /tmp/...json` retorna 1, mas sem linha `FAIL` e com traceback. Não gera aprovação errada, porém prejudica a correção de updates e automações que esperam erros estruturados. Validar tipos antes de testar pertença a sets e capturar a falha de schema em `main`.

**C-F008, baixa, título pode forjar aresta no diagrama.** Em `scripts/mebane_gates.py:223-226`, o título entra em Mermaid sem escape. Em cópia do ledger, usei `G0.title='Title"]\n    G8 --> G0\n    x["extra'`; `validate(...) == []`, e as primeiras linhas renderizadas incluem `G8 --> G0`, uma aresta inexistente que cria ciclo visual. Não muda o grafo computado pelo checker, mas torna a representação de dependências enganosa. Escapar ou rejeitar aspas, quebras de linha e sintaxe Mermaid em rótulos.

## Limites

Os fixtures usam aprovações sintéticas e demonstram comportamento do checker, não que algum gate real foi aprovado; o ledger congelado mantém G0-G7 em `queued` e G8 em `waiting_external`. Não executei R, MCMC, instalação de pacotes, validação de dados eleitorais nem revisão matemática. O teste de renderer foi de equivalência textual e contraexemplos de geração; não fiz QA visual do Markdown. A documentação já avisa que o checker é estrutural e que o coordenador deve adjudicar; os findings identificam casos em que confiar apenas no `PASS` estrutural resultaria em liberação errada ou em falha de atualização.
