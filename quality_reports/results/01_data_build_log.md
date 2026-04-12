
# Bloco 1 Fase A -- log de build

Data/hora: 2026-04-10 18:17:03 -03
R: 4.4.2 | data.table: 1.18.2.1 | arrow: 23.0.1.2

## Arquivos de entrada

- `votacao_secao_2022_BR.csv`: 1517.4 MB
- `detalhe_votacao_secao_2022_BR.csv`: 263.4 MB
- `votos_presidente_muni_nexojornal_2022.xlsx`: 3.8 MB

## Encoding check

Amostra de 50.000 linhas da base `votacao_secao`:
- linhas lidas (Latin-1): 50000
- linhas lidas (UTF-8):   50000

Exemplos de `NM_MUNICIPIO` encontrados na amostra:

| chave normalizada | latin1 | utf-8 |
|---|---|---|
| SALVADOR | `SALVADOR` | `SALVADOR` |

Exemplos de acentos em `NM_MUNICIPIO` lidos com Latin-1:
`SELVÍRIA`, `POTÉ`, `SÃO JOÃO DE MERITI`, `RIBEIRÃO PRETO`, `MAUÁ`

- latin1 produz acentos validos: **TRUE**
- utf-8  produz mojibake (C3/C2): **FALSE**

- linhas em que latin1 e utf-8 produzem strings diferentes (na amostra de 50k): 1

> Observacao: latin1 produz acentos validos e a leitura 'UTF-8' nao retorna mojibake detectavel porque `fread(encoding='UTF-8')` nao tenta re-decodificar os bytes -- apenas marca o encoding. A diferenca relevante e que latin1 produz strings com Encoding() `latin1`, enquanto 'UTF-8' produz strings com bytes invalidos marcados como UTF-8. Latin-1 e a leitura correta.

**Decisao**: prosseguir com `encoding = 'Latin-1'`.

## Leitura

- `votacao_secao`: lido em 1.6s -- 5,380,736 linhas x 12 colunas.
- `detalhe_votacao`: lido em 0.4s -- 944,150 linhas x 17 colunas.

## Filtro

Filtro aplicado: `DS_CARGO == "PRESIDENTE"` AND `NR_TURNO in {1,2}`.

| base | linhas antes | linhas depois | reducao |
|---|---:|---:|---:|
| votacao_secao  | 5,380,736 | 5,380,736 | 0.0% |
| detalhe_votacao| 944,150 | 944,150 | 0.0% |

Distribuicao por turno (apos filtro):

| base | turno 1 | turno 2 |
|---|---:|---:|
| votacao_secao   | 3,529,844 | 1,850,892 |
| detalhe_votacao | 472,075 | 472,075 |

## Diagnosticos pre-merge

Duplicatas em `detalhe_votacao` pela chave `(SG_UF, CD_MUNICIPIO, NR_ZONA, NR_SECAO, NR_TURNO)`: **0** grupos.
Duplicatas em `votacao_secao` pela chave `(SG_UF, CD_MUNICIPIO, NR_ZONA, NR_SECAO, NR_TURNO, NR_VOTAVEL)`: **0** grupos.

Valores-limite em `detalhe_votacao` (secao-turno, apos filtro):

| condicao | N |
|---|---:|
| `QT_APTOS == 0`              | 0 |
| `QT_COMPARECIMENTO == 0`     | 97 |
| `QT_VOTOS_NOMINAIS == 0`     | 99 |
| `QT_COMPARECIMENTO > QT_APTOS` (edge case) | 0 |
| `SG_UF == "ZZ"` (exterior) | 2,128 |

Distribuicao de `QT_APTOS` (tamanho de secao):

| estatistica | valor |
|---|---:|
| min  | 1 |
| p1   | 120 |
| p10  | 242 |
| p25  | 292 |
| p50  | 340 |
| p75  | 381 |
| p90  | 397 |
| p99  | 489 |
| max  | 800 |

## Densificacao de votacao_secao


Passo critico: o CSV bruto do TSE (`votacao_secao_XXXX_BR.csv`) NAO reporta
linhas (secao, turno, candidato) em que QT_VOTOS = 0. Sem correcao, candidatos
com 0 votos numa secao desaparecem desse registro, quebrando a identidade
formal no 2o turno (Lula 100%% implica Bolsonaro 0%% mas a linha desse Bolsonaro
nao existe no arquivo). Corrigido aqui via cross-join com preenchimento = 0.

| metrica                                            | valor |
|---|---:|
| linhas em `votacao` original (pre-densificacao)    | 5,380,736 |
| secoes-turno em `detalhe` (universo)               | 944,150 |
| candidatos unicos no T1 (inclui brancos/nulos)     | 13 |
| candidatos unicos no T2 (inclui brancos/nulos)     | 4 |
| linhas esperadas pos-densificacao (cartesiano)     | 8,025,275 |
| linhas apos densificacao                           | 8,025,275 |
| linhas adicionadas com `QT_VOTOS = 0`              | 2,644,539 |
| fracao do total densificado que foi preenchida com 0 | 32.95% |

## Merge

Merge LEFT JOIN: `votacao_secao` enriquecido com totais de `detalhe_votacao`.

| metrica | valor |
|---|---:|
| linhas no resultado              | 8,025,275 |
| linhas sem match no detalhe      | 0 |
| candidatos unicos (NR_VOTAVEL)   | 13 |
| secoes-turno unicas              | 944,150 |
| linhas turno 1                   | 6,136,975 |
| linhas turno 2                   | 1,888,300 |

Duplicatas no merged pela chave `(..., NR_VOTAVEL)`: **0** grupos.

## Nexojornal

Colunas observadas em `absoluto-1t-2022`:
`tse, ibge7, municipio, uf, eleitores, comparecimento, abstencoes, validos, nulos, brancos, vencedor, 13, 22, 15, 12, 14, 16, 21, 27, 30, 44, 80`

Colunas observadas em `absoluto-2t-2022`:
`ibge7, tse, municipio, uf, eleitores, comparecimento, abstencao, validos, brancos, nulos, vencedor, x13, x22`

Apos empilhamento 1T+2T:
- linhas: 11,502
- linhas 1T: 5,751
- linhas 2T: 5,751
- municipios unicos (ibge7): 5572
- municipios unicos ((uf, municipio)): 5796
- linhas com `ibge7` vazio/NA: 181

## Persistencia

Linhas com pelo menos 1 char acentuado em `NM_MUNICIPIO` apos UTF-8: 3,405,576
Exemplos: `BRASILÉIA`, `MÂNCIO LIMA`, `JORDÃO`, `EPITACIOLÂNDIA`, `ACRELÂNDIA`, `FEIJÓ`

Parquet gerados:
- `brasil_2022_secao.parquet` -- 142.1 MB
- `nexojornal_muni_2022.parquet` -- 0.6 MB

## Verificacao de denominador (principal)

Comparacao das tres definicoes de denominador TSE (agregado a municipio) contra `validos` do Nexojornal. Veredito abaixo em `01_denominator_check.md`.
