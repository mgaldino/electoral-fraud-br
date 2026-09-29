# Adjudicação do checker, rodada 1

Artefato: `scripts/mebane_gates.py`, SHA-256 `480c0b88674513f6cd4ffb1f34f59ab19efbf4cfaf50c0b403fd105aef8e33b6`.

Parecer: `review_checker_round1.json`; contrato argumental de manuscrito não se aplica. Veredicto: **READY_FOR_IMPLEMENTATION**. Seis achados confirmados, dois parciais, nenhum não resolvido.

| Finding | Decisão | Evidência reproduzida | Reparo autorizado |
|---|---|---|---|
| C-F001 | CONFIRMED | cross_gate [] | Exigir gate_id, round e contract_sha256 em manifesto, revisão e adjudicação; hash determinístico do contrato estático exclui estados e records. |
| C-F002 | CONFIRMED | identity_alias [] | Exigir UUID canônico de agente, tipo string e identidade coerente com run/records; recusar alias textual. |
| C-F003 | PARTIAL | external_text [] | Exigir atestação estruturada por requisito, gate, turno, fonte oficial, snapshot/hash, cobertura e revisor independente. A ferramenta valida rastreabilidade; o revisor verifica o conteúdo oficial. |
| C-F004 | PARTIAL | omitted_code [] | Vincular run.json e suas entradas/código/configuração/saídas ao manifesto e exigir atestação do revisor sobre completude. Não prometer descobrir automaticamente dependências não declaradas. |
| C-F005 | CONFIRMED | changed_review [] | Vincular adjudicação ao SHA-256 da revisão; reconciliar IDs/classificações/resolução dos findings. |
| C-F006 | CONFIRMED | render_schema []; render_error KeyError | Validar todos os campos e tipos consumidos antes de renderizar. |
| C-F007 | CONFIRMED | bad_status unhandled TypeError | Validar tipos antes de testes em sets e reportar falhas de schema sem traceback. |
| C-F008 | CONFIRMED | diagram_title [] | Escapar rótulos Mermaid ou rejeitar caracteres que quebrem a sintaxe, mantendo o grafo fiel. |

C-F003 e C-F004 são parciais porque oficialidade de dados e descoberta de código não declarado não podem ser provadas só por hashes. O reparo exigirá atestação independente e vínculo às entradas/código/saídas declarados. A checagem semântica continua com o revisor e o coordenador. Os demais casos têm contraprovas mecânicas diretas. Não há decisão substantiva do modelo eleitoral ou instalação nesta adjudicação.
