# Implementação do checker/renderer, rodada 2

**Estado:** candidato entregue para rechecagem independente. Este relatório não aprova nenhum gate científico. Base: `adjudication_round1.json` validada, findings C-F001 a C-F008. Escopo editado: apenas `scripts/mebane_gates.py`, `tests/test_mebane_gates.py` e este relatório. Ledger e prompts foram tratados como entradas; a alteração paralela do coordenador introduziu G4-T5/T6, G8/T1 e G9/T2.

## Reparos

- **C-F001:** contrato SHA-256 canônico de cada gate estático; `gate_id`, `round` e `contract_sha256` coerentes em run, manifesto, review e adjudication. Alterar critério/escopo invalida a aprovação sem tornar mudanças de status/evidência circulares.
- **C-F002:** `executor_id` e `reviewer_id` são UUIDs canônicos, distintos, e coerentes entre `records`, run, review e atestações.
- **C-F003:** requisito externo exige atestação JSON por texto exato e turno, URL HTTPS no domínio TSE, data, ano, snapshot existente/hash, cobertura e revisor independente. O checker verifica forma e rastreabilidade, não oficialidade ou conteúdo substantivo.
- **C-F004:** run declara inputs, code, configuration e outputs; todos os paths e o próprio run devem estar no manifesto. O revisor atesta `manifest_complete:true`. Dependências não declaradas continuam exigindo QA humano.
- **C-F005:** adjudication vincula `review_sha256`, reconcilia IDs de todos os findings e não aceita falha material pendente.
- **C-F006/C-F007:** campos/tipos usados pelo renderer são validados; entradas malformadas recebem `FAIL` sem traceback; erro de escrita do render também é controlado.
- **C-F008:** título Mermaid rejeita aspas, colchetes e separadores/controles de linha.
- **Extensão solicitada:** `not_applicable` só para gate T2 de 2026 com `allow_not_applicable:true` e atestação independente de `turn_not_held`; não exige todos analíticos `done` nem produz inferência. `run.dependency_manifests` detecta nova versão de manifesto de dependência.

## Schema exato

`contract_sha256` é SHA-256 de UTF-8 de `json.dumps(static_gate, sort_keys=True, ensure_ascii=False, separators=(",", ":"))`. `static_gate` exclui `gate.status` e `gate.records`; de cada item de `gate.todos`, exclui `status` e `evidence`. Todo o resto do objeto gate, inclusive `election_scope`, `allow_not_applicable`, dependências e critérios, entra no hash.

Para um gate `pass`, `records` tem os campos obrigatórios abaixo (paths relativos à raiz do repositório):

```json
{
  "executor_id": "UUID-canônico",
  "reviewer_id": "UUID-canônico-distinto",
  "run": "path/run.json",
  "candidate_manifest": "path/candidate_manifest.json",
  "review": "path/review.json",
  "adjudication": "path/adjudication.json",
  "external_evidence": ["path/attestation.json"]
}
```

`external_evidence` só é obrigatório quando `external_prerequisites` não está vazio. Para gate externo em `running`, `submitted` ou `under_review`, bastam os IDs canônicos distintos e `external_evidence` válido em `records`; ainda não se exigem run/review/adjudication. `queued` e `waiting_external` aceitam `records:null`.

```json
{
  "run.json": {
    "gate_id": "Gx", "round": "round1", "contract_sha256": "sha256-hex",
    "executor_id": "UUID-canônico", "inputs": ["path/input"],
    "code": [], "configuration": [], "outputs": ["path/output"],
    "dependency_manifests": {"Gparent": "sha256-hex-do-manifesto-atual"}
  },
  "candidate_manifest.json": {
    "gate_id": "Gx", "round": "round1", "contract_sha256": "sha256-hex",
    "files": [{"path": "path/run.json", "sha256": "sha256-hex"}]
  },
  "review.json": {
    "gate_id": "Gx", "round": "round1", "contract_sha256": "sha256-hex",
    "candidate_manifest_sha256": "sha256-hex", "status": "pass",
    "executor_id": "UUID-canônico", "reviewer_id": "UUID-canônico-distinto",
    "manifest_complete": true,
    "findings": [{"id": "F1", "severity": "critical|major|minor"}]
  },
  "adjudication.json": {
    "gate_id": "Gx", "round": "round1", "contract_sha256": "sha256-hex",
    "candidate_manifest_sha256": "sha256-hex", "review_sha256": "sha256-hex",
    "status": "pass", "unresolved_material_findings": 0,
    "findings": [{"id": "F1", "status": "CONFIRMED|PARTIAL|REFUTED|UNRESOLVED", "resolution": "explicação não vazia", "resolved": true}]
  }
}
```

O bloco acima mostra as **estruturas de quatro arquivos separados**, não um JSON combinado. `round` é string `round[1-9][0-9]*`, igual nos quatro; hashes usam 64 caracteres hexadecimais minúsculos. `manifest.files` deve incluir o run, cada path declarado nas quatro listas do run e cada evidência de todo; não pode conter duplicatas nem autorreferência. `inputs` deve ter ao menos um path e a união de `code`, `configuration`, `outputs` ao menos um; listas individuais podem ser vazias; run não pode declarar a si próprio. `dependency_manifests` tem exatamente as chaves de `depends_on` e os hashes atuais dos manifestos dos pais (objeto vazio para G0). `review.findings` e `adjudication.findings` podem ser listas vazias. Cada ID da revisão deve aparecer exatamente uma vez na adjudicação. Finding `critical`/`major` com `UNRESOLVED` ou `CONFIRMED`/`PARTIAL` sem `resolved:true` bloqueia `pass`; o contador exige inteiro `0`.

Gate externo ativo deve ter `election_scope:{"year":2026,"turn":1|2}` com inteiros exatos. Cada path em `records.external_evidence` aponta para JSON com:

```json
{
  "gate_id": "G8", "requirement": "texto exato de external_prerequisites",
  "source_url": "https://www.tse.jus.br/...",
  "publication_date": "2026-09-28", "election_year": 2026, "turn": 1,
  "snapshot_path": "path/snapshot", "snapshot_sha256": "sha256-hex",
  "coverage_pass": true, "reviewer_id": "UUID-canônico-independente",
  "checked_at": "2026-09-28T12:00:00+00:00"
}
```

Exige-se uma atestação por requisito do gate, sem duplicata requisito/turno. O turno deve coincidir com `election_scope.turn`; ano e turno são `int` exatos (não `bool`), e cobertura é `true` exato. URL deve ser HTTPS em `tse.jus.br` ou subdomínio como `www.tse.jus.br`/`cdn.tse.jus.br`, com path, sem credenciais e sem porta fora de 443. `publication_date` é ISO `YYYY-MM-DD` não futura; `checked_at` é datetime ISO com fuso, não anterior à data da publicação. Snapshot precisa existir e bater com SHA-256. **No estado `pass`, tanto a atestação quanto seu snapshot são obrigatórios em `manifest.files`** com hashes válidos. Estados externos ativos anteriores a `pass` conferem atestação/snapshot antes de executar, sem exigir manifesto prematuro.

Para G9 `not_applicable`, o gate precisa de `allow_not_applicable:true` e `election_scope:{"year":2026,"turn":2}`. `records` exige `executor_id`, `reviewer_id` UUIDs distintos e `applicability_evidence` não vazio. Cada path aponta a JSON com os mesmos campos `gate_id`, `source_url`, `publication_date`, `election_year`, `turn`, `snapshot_path`, `snapshot_sha256`, `reviewer_id`, `checked_at` e suas validações acima, mas `requirement` é exatamente `turn_not_held`, `occurrence` é exatamente `not_held` e **`coverage_pass` deve estar ausente**. Esse estado não exige run, manifesto, review/adjudication ou todos `done`. A atestação de não ocorrência continua sujeita a auditoria independente do conteúdo oficial.

## Verificações e limites

- `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_mebane_gates.py' -v`: 24 testes, todos `ok`, inclusive fixtures adversariais e migração do ledger real com `records:null`.
- `PYTHONDONTWRITEBYTECODE=1 python3 scripts/mebane_gates.py check`: `PASS: 10 gates, 45 todos; structural checks only` no ledger observado em 2026-09-28.
- `PYTHONDONTWRITEBYTECODE=1 python3 scripts/mebane_gates.py render --output /tmp/mebane-gates-checker-round2-render.md`: gerado; G8/T1 e G9/T2 aparecem separados e `waiting_external`. Saída em `/tmp` para não editar o Markdown do plano fora do escopo.
- SHA-256 do candidato: `scripts/mebane_gates.py` = `2effb4bc77697ba4a60b108de42b797d7b211268e0209f1000c93baddb7b13aa`; `tests/test_mebane_gates.py` = `84f98dbe3a4b397c21a64dc2936f827742b835cf3a6cb5efcab493ba39b0749b`. Ledger observado no check = `fc44b2c192b432f0b8754adf974ffc582f7f942fa091df0edef14b081b6a0e39`; edição paralela posterior exige novo check.

Não houve consulta web, execução de R/MCMC, instalação, validação semântica de fonte oficial, QA visual do Mermaid nem revisão científica dos gates. Hash/URL/atestado não provam oficialidade, cobertura efetiva ou completude de código/inputs não declarados; essas decisões permanecem com o revisor independente e o coordenador.
