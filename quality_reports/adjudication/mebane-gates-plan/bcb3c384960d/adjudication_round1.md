# Adjudicação científica do protocolo, rodada 1

Fonte: `mebane_2022_2026_gates.json`, SHA-256 `bcb3c384960d87924178128fe4c7ce3db0a841e4e7941df26864c1f35b2dab7f`. A avaliação é de um protocolo operacional, não de manuscrito; contrato argumental de paper não se aplica.

Veredicto: **READY_FOR_IMPLEMENTATION**. Os três achados são CONFIRMED, sem pendência material não resolvida.

- **S-F001:** G4-T2 mede recuperação/cobertura/falso positivo, mas acceptance fixa somente critérios MCMC; G4-T5 não exige regra de detecção, unidade e limiares. Reparo: Adicionar contrato de calibração versionado, revisão independente antes das simulações confirmatórias, critérios de pass/inconclusive e limites de afirmação; separar dados/seeds de piloto e avaliação.
- **S-F002:** review/adjudication mínimos referenciam apenas candidate_manifest_sha256; contrato do gate não é artefato obrigatório. Reparo: Vincular snapshot do contrato estático a contract_sha256 em run/manifest/review/adjudication e verificar hashes de aprovações predecessoras; alteração material reabre gate.
- **S-F003:** G8 contém status/records/todos únicos apesar de operar por turno; não há composição explícita ou instâncias. Reparo: Separar G8 2026 T1 e G9 2026 T2 condicional, com election_scope próprio e estado not_applicable fundamentado oficialmente. Versionar snapshot/rodada em diretórios imutáveis.

Mudanças autorizadas pelo pedido atual de gates/goals. Critérios numéricos de calibração serão propostos e aprovados dentro do G4 antes da avaliação confirmatória, sem escolhê-los após observar os resultados. A aprovação deste protocolo não aprova inferência.
