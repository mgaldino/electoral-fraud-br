# Parecer independente QA-DADOS: G1 round1

**Resultado: `changes_requested`; `manifest_complete=false`.** Revisor
`01a0eb01-0a01-7a10-b432-d1f2cdbd12f8`, distinto do executor
`01a0eaee-0164-7530-884d-adec564a8327`. Candidato SHA-256
`009e0fd39f8ab495e52fcb214476fcc7b6095f895381006a924df6a2ffbd7003`;
contrato canônico SHA-256
`f985ab97469aa66755b977a09781b30608afa6e245896d9d9788b4461190975d`.
Os três hashes fornecidos para manifesto, parecer e adjudicação de G0 round2
foram recalculados e coincidem; a adjudicação de G0 registra `pass`.

## Achados

### G1-R1-QAD-F01 (major): identidade eleitoral pode estar errada nos dois CSVs

**Local:** `R/lib/mebane_data.R:100-115`, `R/lib/mebane_data.R:179-184` e
`config/mebane/2022.json:2-8`. A validação exige apenas que `CD_ELEICAO` e
`DT_ELEICAO` coincidam entre detalhe e votação; não os vincula à configuração
de ano/turno, nem lê `CD_TIPO_ELEICAO`. Nas fixtures próprias, substituí
`CD_ELEICAO` por 999 em ambos os arquivos e, em outro caso, a data eleitoral
por `02/10/2020`, mantendo `ANO_ELEICAO=2022`, cargo Presidente, os dois turnos
e todos os controles numéricos ativos. Ambos foram aceitos. Evidência:
`adversarial_review.R` e `adversarial_results.csv`, casos
`wrong_election_code_both_sources` e `wrong_election_year_both_sources`.

**Impacto:** é possível rotular um pleito/snapshot incorreto como o ano e o
turno pretendidos quando as duas fontes concordam. A ambiguidade importa
especialmente ao parametrizar outro ano ou ao distinguir eleições ordinárias
de suplementares. **Reparo sugerido:** declarar por turno código, data e tipo
de eleição esperados na configuração; ler e conferir os campos em ambos os
CSV antes de agregar; testar o erro compartilhado pelas duas fontes.

### G1-R1-QAD-F02 (major): insumo do congelamento ausente do manifesto

**Local:** `quality_reports/results/mebane_gates/G1/round1/freeze_candidate.py:39-47,63-85`
e `quality_reports/results/mebane_gates/G1/round1/run.json:22-50`.
`freeze_candidate.py` lê `quality_reports/plans/mebane_2022_2026_gates.json`
para derivar `gate_contract.json`, mas não o inclui em `run.inputs` nem em
`candidate_manifest.files`. A auditoria de bytes confirmou os 53 arquivos
declarados, seus tamanhos e hashes e o fechamento *somente do conjunto
declarado* (`manifest_bytes.txt`). O hash canônico do contrato derivado do
ledger no momento desta revisão ainda coincide, mas isso não vincula os bytes
do ledger no momento em que o candidato foi congelado.

**Impacto:** o `run` não identifica todos os insumos usados para gerar o
contrato; portanto, o manifesto não é completo conforme o protocolo. **Reparo
sugerido:** em nova rodada, congelar uma cópia imutável ou um hash verificável
do ledger efetivamente lido, registrá-lo em `run.inputs` e no manifesto e
registrar o comando de congelamento. Não reescrever esta rodada.

## Controles executados

- `Rscript --vanilla review/review_checks.R`, a partir da raiz com o caminho
  completo do script: releu os dois CSVs brutos e os membros exclusivos
  `_BR.csv` dos ZIPs oficiais, sem chamar helpers do executor. Passaram 56
  comparações UF-turno, 364 candidato-UF-turno, quatro pares UF-turno e 84
  zonas com seções não instaladas, além dos históricos nacionais de T1 e T2.
  `independent_controls.csv`, `independent_uf_turn.csv`,
  `independent_national.csv` e `independent_summary.json` são as saídas.
- A leitura direta encontrou 944.150 linhas de detalhe, 5.380.736 linhas de
  votação, 99 seções-turno com nominais zero (51/48) e 94 sem qualquer linha de
  categoria de voto (47 por turno). O detalhe e o voto reconciliam nominais,
  brancos e nulos por chave. As 94 discrepâncias de abstenção são 47 por turno,
  657 aptos por turno, coincidentes com as seções/eleitores não instalados no
  extrato oficial inclusive por município/zona. Não foram imputadas
  abstenções aos campos originais.
- Nacionalmente, T1 tem 472.075 seções, 156.454.011 aptos, 123.682.372
  comparecimentos, 32.770.982 abstenções reportadas, 118.229.719 nominais,
  1.964.779 brancos e 3.487.874 nulos. T2 tem os mesmos aptos/seções,
  124.252.796 comparecimentos, 32.200.558 abstenções reportadas, 118.552.353
  nominais, 1.769.678 brancos e 3.930.765 nulos. O derivado `N-V` excede o
  reportado em 657 em cada turno; o arquivo de controle oficial posterior
  identifica as seções não instaladas.
- `Rscript --vanilla tests/mebane/data/test_g1.R` passou. As fixtures próprias
  rejeitaram duplicata divergente, omissão de voto positivo, candidato inelegível
  no turno e `QT_APTOS` ausente, mas aceitaram os dois erros de identidade acima.
- A CLI foi executada em `review/cli_2022` com `R/01_load_tse.R` e
  `R/02_build_vars.R`, sem tocar o candidato. Os testes existentes `test_g1.R
  --full`, `check_official_histories.R` e `check_official_munzona.R` passaram
  nessa saída isolada. Nove produtos centrais são byte-idênticos aos congelados
  (`cli_byte_comparison.csv`). O parquet limpo tem 944.150 linhas, retém as 99
  de nominais zero, marca 47 por turno inelegíveis por discrepância e não
  viola `0 <= a <= N` ou `0 <= w <= N-a`. Exterior e seções pequenas são
  sinalizados, sem exclusão automática; o líder nacional é 13 em ambos os
  turnos.

## Escopo e limites

O detalhe e a votação por município/zona têm `DT_GERACAO=28/09/2026`, enquanto
os CSVs de seção dos autores têm `01/11/2022`. A coincidência observada vale
para os agregados e chaves testados, não para todos os campos/linhas nem para
autenticidade externa do ZIP dos autores. Foram lidos apenas os membros
`_BR.csv`, sem extrair os 8,6 GB do ZIP nominal nem concatenar `_BR` e
`_BRASIL`. Os históricos oficiais não têm campo de abstenção; as notícias TSE
usadas na configuração não têm HTML arquivado, e o controle local posterior
por município/zona não torna os snapshots intercambiáveis. Não houve MCMC ou
inferência; este parecer não aprova uso inferencial nem altera código, brutos,
ledger ou candidato.
