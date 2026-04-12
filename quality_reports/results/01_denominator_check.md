
# Verificacao empirica do denominador

Data/hora: 2026-04-10 18:17:23 -03

## Procedimento

1. Agregar a base TSE secao-nivel para municipio somando numeradores (votos de cada candidato) e denominadores candidatos (`QT_COMPARECIMENTO`, `QT_VOTOS_NOMINAIS`, `QT_VOTOS_NOMINAIS + QT_VOTOS_BRANCOS`), por turno.
2. Calcular tres versoes de `vote_share` por candidato x municipio x turno:
   - `comparecimento`: `sum(votos) / sum(QT_COMPARECIMENTO)`
   - `validos`: `sum(votos) / sum(QT_VOTOS_NOMINAIS + QT_VOTOS_BRANCOS)`
   - `nominais`: `sum(votos) / sum(QT_VOTOS_NOMINAIS)`
3. Do lado Nexojornal: `voto_candidato / validos`.
4. Merge por `CD_MUNICIPIO (TSE)` = `tse` (Nexojornal).
5. Para cada cenario TSE, reportar mean/median/p95/max da diferenca absoluta contra Nexojornal e N de municipios com diferenca > 1 p.p.

### TSE agregado
- municipios-turno no TSE agregado: 11,502
- amostra de totais:

```
Chave: <CD_MUNICIPIO, NR_TURNO>
   CD_MUNICIPIO NR_TURNO sum_comp sum_nominais sum_validos votos_lula_tse
          <int>    <int>    <int>        <int>       <int>          <int>
1:           19        1    20962        20555       20702           7028
2:           19        2    20379        19839       19994           6838
3:           35        1   276890       269018      271968          92037
4:           35        2   271850       261935      264956          92636
5:           51        1    69558        67955       68616          16470
   votos_bolsonaro_tse
                 <int>
1:               12157
2:               13001
3:              152878
4:              169299
5:               47429
```

### Nexojornal
- municipios-turno: 11,502
- nao-NA no share Lula: 11417

### Merge TSE-agregado x Nexojornal
- chave: `CD_MUNICIPIO` (int) <-> `tse` (Nexojornal, leading zeros removidos)
- municipios-turno em TSE agregado: 11502
- municipios-turno em Nexojornal: 11502
- municipios-turno no merge (inner): 11502
- municipios-turno sem match TSE->Nexo: 0

### Tabela de diferencas

#### lula_1T

| denominador | mean abs diff | median abs diff | p95 abs diff | max abs diff | N munis >0.1pp | N munis >1pp |
|---|---:|---:|---:|---:|---:|---:|
| comparecimento | 0.0221 | 0.0200 | 0.0431 | 0.1071 | 5680 | 5045 |
| validos | 0.007387 | 0.007022 | 0.0136 | 0.1071 | 5662 | 1155 |
| nominais | 0 | 0 | 0 | 0 | 0 | 0 |

#### lula_2T

| denominador | mean abs diff | median abs diff | p95 abs diff | max abs diff | N munis >0.1pp | N munis >1pp |
|---|---:|---:|---:|---:|---:|---:|
| comparecimento | 0.0229 | 0.0200 | 0.0498 | 0.1078 | 5687 | 5000 |
| validos | 0.006854 | 0.006553 | 0.0121 | 0.0447 | 5658 | 781 |
| nominais | 0 | 0 | 0 | 0 | 0 | 0 |

#### bolsonaro_1T

| denominador | mean abs diff | median abs diff | p95 abs diff | max abs diff | N munis >0.1pp | N munis >1pp |
|---|---:|---:|---:|---:|---:|---:|
| comparecimento | 0.0155 | 0.0147 | 0.0304 | 0.0618 | 5681 | 4077 |
| validos | 0.006006 | 0.005193 | 0.0137 | 0.0323 | 5395 | 1027 |
| nominais | 0 | 0 | 0 | 0 | 0 | 0 |

#### bolsonaro_2T

| denominador | mean abs diff | median abs diff | p95 abs diff | max abs diff | N munis >0.1pp | N munis >1pp |
|---|---:|---:|---:|---:|---:|---:|
| comparecimento | 0.0171 | 0.0160 | 0.0336 | 0.0845 | 5688 | 4362 |
| validos | 0.005857 | 0.005184 | 0.0127 | 0.0379 | 5490 | 826 |
| nominais | 0 | 0 | 0 | 0 | 0 | 0 |


## VEREDITO

Criterio: um denominador 'bate' se `max_abs_diff <= 0.001` em todos os 4 cenarios (Lula 1T, Lula 2T, Bolsonaro 1T, Bolsonaro 2T).

| denominador | pior max_abs_diff | pior mean_abs_diff | N total munis diff>1pp | bate? |
|---|---:|---:|---:|:-:|
| comparecimento | 0.1078 | 0.0229 | 18484 | nao |
| validos | 0.1071 | 0.007387 | 3789 | nao |
| nominais | 0 | 0 | 0 | SIM |

**Veredito: `nominais` bate. Claim do autor parece CORRETO.**
