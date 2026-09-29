# G0 round4: reparo de proveniência do input de construção

O único achado material de round3 foi G0-R3-QA-F01, equivalente a G0-R3-COORD-F01. Este candidato preserva integralmente os 171 arquivos do manifesto round3, inclusive os 157 arquivos ativos inventariados; o PDF incompleto e Info.plist continuam ausentes. Nenhum arquivo histórico foi alterado, excluído ou restaurado.

construction_input.json fixa contrato, status, IDs e evidence dos quatro todos da projeção G0 do ledger before da coordenação. O build lê esse arquivo, identificado em run.json por SHA-256 bee1e870b49052601c5e5c574edf87d5d0811f75940a57a82cbac389a7be8a74; o ledger canônico não é lido. O checker importado é o snapshot arquivado, SHA-256 15601b30477b940bda011a7370d3a2edc269c7ffd89fe92e09d8dd9d34a93480. O contrato estático é byte-idêntico ao de round3; o hash estático sozinho não é apresentado como fechamento dos metadados dinâmicos.

O review formal round3 e a adjudicação delimitada entram como histórico de reparo, não como aprovação deste candidato. Hashes e tamanhos dos 171 arquivos foram conferidos agora; cálculos e testes científicos anteriores não foram reexecutados. Verificação: python3 -B quality_reports/results/mebane_gates/G0/round4/build_candidate.py verify.
