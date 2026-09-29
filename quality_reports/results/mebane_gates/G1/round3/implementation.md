# G1 round3: candidato de revalidação documental

Esta rodada conserva o contrato estático canônico f985ab97469aa66755b977a09781b30608afa6e245896d9d9788b4461190975d e o escopo: Documentary revalidation of the existing 2022 TSE data pipeline; no data rebuild.

Foram reconferidas 194 entradas e 2748230766 bytes do manifesto round2 517c17c724cca82a820519c476981d47c8892c7383dd2c3dded9373eba6d31e8. O mapa inherited_map.json registra os snapshots de código/configuração/testes; cálculos e testes científicos anteriores não foram reexecutados.

O input consumido do ledger foi capturado em ledger_input_snapshot.json (SHA-256 f729008b8179805acda7c24a6c9cb2669cfa767fa76bd48edfb1b320141af0a9) e relido antes de gerar run/todo_evidence. Esse snapshot contém todos, IDs, records e aprovações reais da cadeia predecessora. A decisão da coordenação é input fixado pelo SHA-256 fe62bfd30ffd6e985a6070fb6f575770e5097f6c96de543eed145df3df75007a. O ledger vivo e os documentos canônicos mutáveis não estão no manifesto.

O predecessor direto G0 estava pass com manifesto d73ecc86824fd5eaa66ece7cad41d6c21d913d455af864d32c11c5331fa5bb57, review e6d5bc5e7019a592cdea6ca9c302b50b792607516d20de630ef4d83b83763b38 e adjudicação 51782700132bacb6b57019117fce65c5ac6b4f2ee0f683ca80cda7dd9d0bfcfd no snapshot consumido. Esta entrega ainda requer QA independente e adjudicação próprias.

Verificação documental: python3 -B quality_reports/results/mebane_gates/G1/round3/build_candidate.py verify.
