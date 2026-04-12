# Bloco 2 -- Log de fingerprints baseline

Data de execucao: 2026-04-10 18:21:09

## Parametros

- `BINS_X` (turnout): 100
- `BINS_Y` (vote share): 100
- `DENSITY_TRANS`: log
- Dimensoes 1T: 15 x 4 polegadas
- Dimensoes 2T: 8 x 4 polegadas
- Escopo: Brasil only (flag_exterior == FALSE)

## Exclusoes (exterior)

| Nivel | Total | Brasil only | Exterior removidas |
|---|---:|---:|---:|
| secao | 6,136,318 | 6,123,130 | 13,188 |
| muni  | 74,206 | 72,410 | 1,796 |

## Candidatos plotados

| Turno | NR_VOTAVEL | Label | NM_VOTAVEL (dados) |
|---:|---:|---|---|
| 1 | 13 | Lula (13) | LUIZ INÁCIO LULA DA SILVA |
| 1 | 22 | Bolsonaro (22) | JAIR MESSIAS BOLSONARO |
| 1 | 12 | Ciro Gomes (12) | CIRO FERREIRA GOMES |
| 1 | 15 | Simone Tebet (15) | SIMONE NASSAR TEBET |
| 1 | 44 | Soraya Thronicke (44) | SORAYA VIEIRA THRONICKE |
| 2 | 13 | Lula (13) | LUIZ INÁCIO LULA DA SILVA |
| 2 | 22 | Bolsonaro (22) | JAIR MESSIAS BOLSONARO |

## N por (turno x nivel x spec)

N = soma de observacoes plotadas (uma linha por candidato x unidade) no composto.

| Turno | Nivel | Spec | N |
|---:|---|---|---:|
| 1 | secao | nominais | 2,355,050 |
| 1 | secao | comparecimento | 2,355,050 |
| 1 | muni | nominais | 27,850 |
| 1 | muni | comparecimento | 27,850 |
| 2 | secao | nominais | 942,020 |
| 2 | secao | comparecimento | 942,020 |
| 2 | muni | nominais | 11,140 |
| 2 | muni | comparecimento | 11,140 |

## Arquivos gerados

| Arquivo | Tamanho (KB) | Existe | Sanity OK (>10 KB) |
|---|---:|:---:|:---:|
| `fig1_fingerprint_T1_secao_nominais.pdf` | 74.9 | sim | sim |
| `fig1_fingerprint_T1_secao_comparecimento.pdf` | 73.8 | sim | sim |
| `fig1_fingerprint_T1_muni_nominais.pdf` | 27.8 | sim | sim |
| `fig1_fingerprint_T1_muni_comparecimento.pdf` | 27.4 | sim | sim |
| `fig1_fingerprint_T2_secao_nominais.pdf` | 56.6 | sim | sim |
| `fig1_fingerprint_T2_secao_comparecimento.pdf` | 56.0 | sim | sim |
| `fig1_fingerprint_T2_muni_nominais.pdf` | 21.1 | sim | sim |
| `fig1_fingerprint_T2_muni_comparecimento.pdf` | 21.0 | sim | sim |

Sanity: 8/8 arquivos passam (existem e > 10 KB).

## Observacoes visuais

Pendente: validacao visual pelo autor. Abrir os PDFs em `output/figures/`.
As figuras geram (turnout x vote_share) bin2d para cada candidato nos 8 cortes
(turno x nivel x spec de denominador). Ler qualitativamente para identificar:

- Presenca/ausencia de clusters descolados do corpo principal da distribuicao
- Forma do modo (unimodal, bimodal regional) por candidato e turno
- Diferenca qualitativa entre specs `nominais` vs `comparecimento`
- Comportamento na borda (turnout -> 1, vote share -> 1) -- assinatura classica
  de ballot stuffing se houver cluster no canto superior direito

Essa leitura alimenta o desenho do Bloco 3 (testes formais) mas nao substitui teste.

## Tempo de execucao

- Inicio: 2026-04-10 18:21:09
- Fim:    2026-04-10 18:21:18
- Total:  8.8 segundos

