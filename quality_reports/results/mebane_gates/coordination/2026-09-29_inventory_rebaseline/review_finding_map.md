# Correspondência do achado de construção

O parecer independente final de G0 round3 identifica como `G0-R3-QA-F01`
a entrada dinâmica dos todos consumida pelo construtor sem congelamento.
Seu `review.json` tem SHA-256
`058f951892a72fd8b76b6d811c22c614aa12fc57d01ce923f2aeae95d6e0dcc7`.

A adjudicação `adjudication_build_input.json`, produzida a partir dos registros
parciais de QA já concluídos, normalizou o mesmo achado como
`G0-R3-COORD-F01`. A coordenação leu o parecer final e confirmou a identidade
do defeito, da contraprova e do reparo proposto. Os dois IDs são preservados;
não são dois defeitos diferentes. Os hashes dos registros parciais permanecem
iguais aos usados na adjudicação.

O parecer final não acrescentou outro achado material. A integridade dos 157
arquivos retidos e o conteúdo do inventário já estavam corretos. O reparo fica
limitado aos metadados consumidos pela construção, em nova round4, sem alterar
o candidato round3 ou suas evidências. A rechecagem independente deve confirmar
a resolução antes da assinatura do inventário sucessor.
