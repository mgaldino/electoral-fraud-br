# Adjudicação G1 round2

**G1 aprovado (`pass`).** O candidato reparado satisfaz o contrato de dados e os cinco todos. Os achados F01/F02 da QA anterior e F03 da coordenação permanecem confirmados como problemas históricos, agora com resolução verificada. Não há novo achado material.

A QA independente conferiu os controles diretamente nos CSVs e ZIPs oficiais, executou 43 contraprovas próprias e reproduziu duas cargas/builds limpos. Os nove produtos centrais foram byte-idênticos nas quatro execuções comparadas; as 70 colunas anteriores dos Parquet conservaram tipos e valores. A única coluna adicionada foi `CD_TIPO_ELEICAO`.

A coordenação leu a implementação e o parecer, reaplicou cinco casos mínimos e confirmou a rejeição dos erros de código/data/tipo e de controle de candidato não líder. O congelador agora usa contrato estático. Foram conferidos todos os 194 arquivos do candidato, além de 197 inputs e 89 artefatos da QA, contra os hashes declarados. Os resultados estão em `adjudication_checks.csv` e `adjudication_integrity.json`.

## Identidades aprovadas

- Manifesto: `517c17c724cca82a820519c476981d47c8892c7383dd2c3dded9373eba6d31e8`.
- Contrato canônico: `f985ab97469aa66755b977a09781b30608afa6e245896d9d9788b4461190975d`.
- Revisão: `727f6b234e3a580c329cc5e898018bb68c02063717c292b6d91e4fbe12d86941`.
- Manifesto QA: `694664f05d53c7d2bf839d19e074beb0736ee72d3be268c3cf091134e2eb5b0f`.

## Alcance

A aprovação cobre o pipeline e o contrato de dados presidencial de 2022. Permanecem 472.075 seções por turno e 472.028 linhas sinalizadas como elegíveis por turno. Os 99 casos de nominais zero foram retidos. As 47 seções não instaladas por turno, com 657 aptos, explicam a diferença entre abstenção reportada e derivada; os 94 registros permanecem no arquivo, sem correção silenciosa.

Os controles oficiais posteriores não autenticam por si a aquisição histórica dos autores, nem provam igualdade de todos os campos entre snapshots. O gate não aprova inferência, priors, ausência de fraude ou estimativa nacional. Nenhuma estimação foi executada.

A transição autoriza iniciar G7, cuja única dependência é G1. As decisões abertas de G2 continuam bloqueando o ramo metodológico correspondente.

