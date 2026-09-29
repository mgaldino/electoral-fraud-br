# G0 round3: reconciliação documental candidata

O usuário decidiu manter ausentes `ssrn-4073770.pdf.download/ssrn-4073770.pdf` e `Info.plist`, atualizar o inventário e exigir consulta prévia antes de futuras exclusões. O registro canônico da coordenação é `quality_reports/results/mebane_gates/coordination/2026-09-29_inventory_rebaseline/decision.md`, incluído como input congelado. Esta rodada não removeu nem restaurou arquivo algum. O checkpoint Git `122e74a` registra a deleção de ambos os caminhos, mas não identifica quem operou o filesystem ou por quê. A decisão do usuário não recebe um horário inventado.

## Escopo e evidência

O PDF da pasta `.download` tinha 1.360 bytes, SHA-256 `524dc82c59612ec91b3a6ab475dd34f0607546a37823c9a9b1fd652677a8acdf` e já era `invalid_or_incomplete` no inventário round1. A QA observou sua presença às 13:13:46 UTC e ausência às 13:19:25 UTC em 29/09/2026. `Info.plist` permanece ausente, mas não constava diretamente do manifesto G0 round2. O novo `tombstone.json` registra a ausência autorizada a permanecer, sem promover nenhum dos dois arquivos a fonte científica.

O construtor conferiu integralmente os 158 itens do manifesto G0 round2: 157 arquivos presentes têm bytes e SHA-256 exatos, somando 4.247.644.144 bytes; apenas o PDF incompleto está ausente. `inventory_current.json` lista os 157 arquivos verificados, distingue o inventário round1 e suas cinco adições round2 como observações históricas, e não afirma que todos os caminhos originais históricos existem hoje. O novo manifesto preserva as demais entradas verificadas e a evidência de todos os quatro todos G0. Somente o caminho ausente foi retirado das listas ativas.

O contrato estático é uma cópia byte-idêntica de round2 e mantém SHA-256 canônico `e5ba78d6f8d314c2bf94738df85fce0a31d8e9986ef974f6c69ee9e30ee06ca3`. `run.json` vincula o candidato à rodada e documenta a reutilização das checagens antigas. Os hashes foram reconferidos agora; loads de dados e fits, cálculos, R, MCMC, instalação e análise científica não foram reexecutados. Nenhum `review`, `adjudication`, `PASS` ou ledger foi escrito nesta rodada.

## Reprodução e limite

Em checkout com os mesmos arquivos, executar `python3 -B quality_reports/results/mebane_gates/G0/round3/build_candidate.py verify`. O subcomando `build` só cria o candidato uma vez e recusa sobrescrever a rodada congelada. A verificação é documental e não substitui a QA independente. G1, G2 e G7 exigem novas rodadas e vínculos às aprovações dos predecessores antes de qualquer candidato dependente; G2 limita-se ao contrato benchmark literal, e G7 ao staging CSV normalizado, não ao conversor bruto oficial.
