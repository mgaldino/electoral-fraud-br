# Parecer independente: G0 round3

**`changes_requested`; `manifest_complete=false`.** Há um achado material de proveniência do construtor, sem defeito demonstrado no inventário reconciliado ou nos dados científicos. Manifesto: `42406b1ecb8ee843c95ef75a902ab15e6468c7bb7900b5ac8717d6476afd08bf`. Revisor: `01a0edd1-ae42-7973-8cf9-2fda610d33cf`; executor: `01a0edcd-cd1f-70f0-b9f5-95fb470b6c40`. Este parecer não altera o gate.

## F01: entrada dinâmica do construtor não congelada

**Major, CONFIRMED.** `build_candidate.py:79` lê o ledger vivo; `:82-85` exclui status/evidências dos todos da igualdade estática; `:169-182` usa esses mesmos campos para produzir `todo_evidence.json`. O run/manifest não congela o ledger nem sua projeção consumida. O trace de `verify` confirmou a leitura, e os snapshots antigos não têm a mesma projeção de todos (`source_checks.json`).

Na contraprova somente em memória, substituí `G0.todos[0].evidence[0].path` pelo tombstone já ativo. `check_contract` aceitou o mesmo contrato, mas o bloco real de emissão produziu outro JSON. O controle não alterado reproduziu exatamente o todo congelado. Nenhum `build` foi executado; candidato e ledger permaneceram intocados. Evidência: `run01/ledger_counterexample.json` e `run01/executor_reads.json`.

**Contraprova considerada:** o checker canônico completo é byte-idêntico ao snapshot round1, SHA-256 `15601b30477b940bda011a7370d3a2edc269c7ffd89fe92e09d8dd9d34a93480`; a função `contract_sha256` também tem AST idêntica. Portanto a importação não constitui um segundo achado ou relaxamento do checker. Essa equivalência não protege os campos dinâmicos do ledger. O achado não afirma que o conteúdo atual dos todos esteja errado.

**Reparo mínimo proposto:** em candidato sucessor, preservar o congelamento revisado, fixar por hash uma entrada imutável com o contrato e os todos efetivamente consumidos e fazer `build/verify` lerem essa entrada. Pode-se reutilizar o checker já congelado e idêntico. Outra opção é derivar os todos explicitamente de uma fonte histórica congelada apropriada, com correspondência documentada. Revalidar apenas proveniência, hashes e vínculos. Não mudar contrato, dado, modelo, teste científico ou histórico. O snapshot próprio da QA não sana retroativamente o candidato.

## Integridade confirmada

- **171/171 arquivos:** hashes e tamanhos recalculados, sem divergências; 4.248.559.025 bytes no candidato direto.
- **157/158 itens anteriores retidos:** 4.247.644.144 bytes íntegros; somente o PDF inválido de 1.360 bytes saiu da relação ativa. `Info.plist` não era item direto. Tombstone preserva autorização e autoria/causa desconhecidas.
- **22 artefatos transitivos round1:** íntegros, incluindo qbl e DESCRIPTION. Não usei o rótulo histórico para dispensar dados/modelos usados. Os manifestos antigos continuam registrando o PDF ausente como observação histórica intencional.
- Contrato estático preservado; identidades corretas; G0 sem dependências; listas declaradas do run e evidências dos quatro todos cobertas. Loads, versões e cálculos anteriores estão claramente rotulados como históricos, sem nova execução.

## Testes e limites

`audit_g0.py run01` completou 39/40 checagens; saiu com código 1 somente pelo fechamento incompleto das leituras do construtor. Duas contraprovas de omissão extra, inclusive remoção coordenada de manifest/run/inventory, foram recusadas pela QA. O checker não alterado aceitou o controle sintético e recusou três vínculos de dependência errados. Seu `verify` nominal passou, mas não cobre F01. `source_checks.py` confirmou a equivalência do checker e delimitou o achado ao ledger.

Não houve R, MCMC, instalação, rede, nova análise eleitoral ou auditoria matemática. Nenhum arquivo foi apagado/restaurado; todas as escritas ficaram nesta pasta. Scripts usam arquivos novos e preservam resultados existentes. Evidência executada: `run01/results.json`, contraprovas e `source_checks.json`; selo: `review_manifest.json`. Revisão G0 entregue para adjudicação, sem aguardar G1/G2/G7.
