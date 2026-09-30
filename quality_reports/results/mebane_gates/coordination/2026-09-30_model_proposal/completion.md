# Retomada: entrega de 30/09/2026

O lote autorizado foi entregue: fechamento documental da rodada G3, proposta
comparativa, exemplos determinísticos e revisão independente. Não houve nova
estimação, instalação, exclusão, comunicação externa ou alteração do modelo
literal. Nenhum resultado nacional foi produzido.

## Estado atual

- G3 está registrado como inconclusivo, com parecer e adjudicação vinculados.
  Os todos permanecem parciais. Não há engine de produção aprovada.
- As sete versões históricas faltantes foram recuperadas e revisadas. Esse
  reparo não atesta todo o grafo de inputs históricos; a limitação sobre
  `test_ar02_interface.R` continua explícita.
- A proposta v1 e seu PDF de cinco páginas receberam revisão técnica favorável.
  A coordenação inspecionou visualmente todas as páginas. A candidata multinomial
  foi recomendada para estudo, não adotada.
- G0/G1/G2/G7, seus contratos e suas aprovações delimitadas não mudaram.
  G10 permanece não executado; os requisitos de dados/resultados dos autores
  continuam pendentes. G4/G6 não estão liberados.

## Evidência desta entrega

O script de demonstração passou em 332 distribuições pequenas. A QA refez esses
resultados e usou enumeração independente em 336 distribuições, verificando a
lei completa das transferências condicionais. O suplemento documental passou
914 checagens independentes. Duas falhas iniciais do script demonstrativo e suas
correções delimitadas foram reproduzidas pela QA e permanecem arquivadas.

O checker do plano verifica integridade estrutural dos 11 gates e 49 todos;
seu PASS não é aprovação científica de G3. `verify_delivery.py` compara os
contratos antes/depois, verifica os artefatos e preserva o estado documental
final. `delivery_check.json` e `delivery_manifest.json` registram a conferência
final, quando existentes. A última checagem não reexecuta MCMC.

## Próxima decisão

Escolher a candidata D, ou uma alternativa, para um novo contrato matemático.
O contrato deverá fixar a likelihood, as prioris, o papel de brancos/nulos,
os estimandos e os diagnósticos prospectivos antes da implementação/estimação.
Depois vêm comparação de engines no mesmo alvo, replicação externa dos autores,
pilotos, escala e Brasil 2022. A adaptação do conversor bruto de 2026 pode seguir
em escopo separado, mas não substitui a validação inferencial.

Pontos de entrada: `proposal_v1.md`, `mebane_model_proposal_v1.pdf`,
`proposal_adjudication.json`, `review/review.md` e o ledger central em
`quality_reports/plans/mebane_2022_2026_gates.json`. O qbl literal e todos os
resultados anteriores devem ser preservados.
