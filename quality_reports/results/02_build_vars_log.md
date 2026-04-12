# Bloco 1 Fase B -- Log de build de variaveis

Data de execucao: 2026-04-10 18:20:19

## Leitura

- Arquivo: `/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/data/processed/brasil_2022_secao.parquet`
- Linhas: 8,025,275
- Colunas: 24

## Limpeza de colunas i.*

- Colunas `i.*` detectadas: 4 (i.ANO_ELEICAO, i.NM_MUNICIPIO, i.CD_CARGO, i.DS_CARGO)
- Colunas `i.*` removidas (identicas a base): 4
- Colunas apos limpeza: 20

## Flags e edge cases

- Total de secoes-turno unicas: 944,150

Contagens por secao-turno (nao por linha-candidato):

| Flag | N secoes-turno | % |
|---|---:|---:|
| `flag_aptos_zero` | 0 | 0.000% |
| `flag_comparecimento_zero` | 97 | 0.010% |
| `flag_nominais_zero` | 99 | 0.010% |
| `flag_comparecimento_excede` | 0 | 0.000% |
| `flag_exterior` | 2,128 | 0.225% |

- Secoes-turno Brasil (SG_UF != ZZ): 942,022
- Secoes-turno Exterior (SG_UF == ZZ): 2,128

## Exclusoes hard

Motivos de exclusao (podem se sobrepor):

| Motivo | N secoes-turno |
|---|---:|
| QT_APTOS == 0 (turnout indefinido)            | 0 |
| QT_COMPARECIMENTO == 0 (share_compar indef.)  | 97 |
| QT_VOTOS_NOMINAIS == 0 (share_nominais indef.) | 99 |
| **Uniao (excluidas do dataset)**              | **99** |
| Intersecao (todos os tres motivos)            | 0 |

- Linhas antes da exclusao: 8,025,275
- Linhas depois da exclusao: 8,024,420
- Secoes-turno unicas remanescentes: 944,051 (de 944,150)

- Linhas de pseudo-candidato (NR_VOTAVEL 95/96) removidas: 1,888,102
- Linhas restantes (candidatos reais): 6,136,318
  Justificativa: branco/nulo nao sao numerador valido para
  `vote_share_nominais` (ja excluidos do denominador por construcao).
  Manter geraria vote_share > 1 em secoes com muitos nulos.

## Construcao de variaveis

Sanity check das razoes (uma linha por candidato x secao-turno):

| Variavel | min | max | N < 0 | N > 1 | N NA |
|---|---:|---:|---:|---:|---:|
| `turnout` | 0.001475 | 1.000000 | 0 | 0 | 0 |
| `vote_share_nominais` | 0.000000 | 1.000000 | 0 | 0 | 0 |
| `vote_share_comparecimento` | 0.000000 | 1.000000 | 0 | 0 | 0 |

- Todas as razoes estao em [0, 1]. Sanity check OK.

- UFs sem regiao apos crosswalk: 0

## Persistencia

- Colunas dropadas (constantes/redundantes): ANO_ELEICAO, CD_CARGO, DS_CARGO, QT_VOTOS_LEGENDA, QT_VOTOS_ANULADOS_APU_SEP
- Parquet secao-nivel: `/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/data/processed/brasil_2022_secao_clean.parquet` (51.2 MB)
- Linhas: 6,136,318, colunas: 22

## Agregacao municipio

Padrao de agregacao: evita double-counting separando (1) totais por
secao-turno unicos e (2) votos por candidato; combina via inner join
no nivel municipio x turno.

- Tabela de secoes-turno unicas: 944,051 linhas
- Totais municipio x turno: 11,417 linhas
- Votos por municipio x turno x candidato: 74,206 linhas
- N municipios unicos: 5,709 (Brasil: 5,570; Exterior: 139)

Linhas por turno x candidato (quantos municipios tem cada):

| NR_TURNO | NR_VOTAVEL | NM_VOTAVEL | N municipios |
|---:|---:|---|---:|
| 1 | 12 | CIRO FERREIRA GOMES | 5,708 |
| 1 | 13 | LUIZ INÁCIO LULA DA SILVA | 5,708 |
| 1 | 14 | KELMON LUIS DA SILVA SOUZA | 5,708 |
| 1 | 15 | SIMONE NASSAR TEBET | 5,708 |
| 1 | 16 | VERA LUCIA PEREIRA DA SILVA SALGADO | 5,708 |
| 1 | 21 | SOFIA PADUA MANZANO | 5,708 |
| 1 | 22 | JAIR MESSIAS BOLSONARO | 5,708 |
| 1 | 27 | JOSE MARIA EYMAEL | 5,708 |
| 1 | 30 | LUIZ FELIPE CHAVES D AVILA | 5,708 |
| 1 | 44 | SORAYA VIEIRA THRONICKE | 5,708 |
| 1 | 80 | LEONARDO PÉRICLES VIEIRA ROQUE | 5,708 |
| 2 | 13 | LUIZ INÁCIO LULA DA SILVA | 5,709 |
| 2 | 22 | JAIR MESSIAS BOLSONARO | 5,709 |

Sanity check das razoes no nivel municipio:

| Variavel | min | max | N < 0 | N > 1 | N NA |
|---|---:|---:|---:|---:|---:|
| `turnout` | 0.004831 | 0.941359 | 0 | 0 | 0 |
| `vote_share_nominais` | 0.000000 | 1.000000 | 0 | 0 | 0 |
| `vote_share_comparecimento` | 0.000000 | 1.000000 | 0 | 0 | 0 |

## Verificacao-espelho denominador

- Nexojornal carregado: 11,502 linhas
Comparacao municipio-a-municipio contra Nexojornal (vote_share_nominais):

| Candidato | Turno | N pareado | max abs diff | mean abs diff |
|---|---:|---:|---:|---:|
| Lula       | 1 | 5,708 | 0.000000 | 0.000000 |
| Bolsonaro  | 1 | 5,708 | 0.000000 | 0.000000 |
| Lula       | 2 | 5,709 | 0.000000 | 0.000000 |
| Bolsonaro  | 2 | 5,709 | 0.000000 | 0.000000 |

- Max abs diff overall (Lula+Bolsonaro, 1T+2T): 0.00000000

- Verificacao-espelho OK: agregacao secao->municipio reproduz
  `validos` do Nexojornal dentro de 1e-6 (numericamente exato).

- Parquet municipio-nivel: `/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/data/processed/brasil_2022_muni_clean.parquet` (3.0 MB)
- Linhas: 74,206, colunas: 19

---

**Tempo total de execucao: 10.0 segundos**

