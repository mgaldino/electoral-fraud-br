# Electoral Fraud — Parecer Metodologico

Reconstrucao metodologica do parecer sobre a research note "Is there evidence of fraud in Brazil's 2022 presidential election?" (Figueiredo, Carvalho, Santano).

## Replicacao

### Pre-requisitos

- R >= 4.4, com `renv` instalado
- JAGS >= 4.3 (`brew install jags` no macOS)
- CmdStan >= 2.35 (opcional, para validacao Stan)

### Dados

Os dados brutos do TSE 2022 (~1.8 GB) nao estao no repositorio. Para replicar:

1. Obter os CSVs do TSE 2022 (votacao por secao, presidente) e o xlsx do Nexo Jornal
2. Colocar em `replication_authors/extracted/fingerprint_brazil/raw-data/`

Arquivos esperados:
```
raw-data/
  votacao_secao_2022_BR.csv
  detalhe_votacao_secao_2022_BR.csv
  votos_presidente_muni_nexojornal_2022.xlsx
```

### Setup

```bash
git clone git@github.com:mgaldino/electoral-fraud-br.git
cd electoral-fraud-br
Rscript -e 'renv::restore()'
```

### Pipeline

Executar os scripts em ordem:

```bash
# Bloco 0-1: infraestrutura + construcao de variaveis
Rscript R/00_setup.R          # carregado automaticamente pelos demais
Rscript R/01_load_tse.R       # carrega CSVs → parquet
Rscript R/02_build_vars.R     # turnout, vote shares, flags

# Bloco 2: fingerprint visual (baseline)
Rscript R/03_fingerprint_base.R   # → output/figures/fig1_fingerprint_*.pdf

# Bloco 3: testes formais suplementares
Rscript R/05_kobak_integer.R      # → output/tables/tab_kobak_integer_pct.csv
Rscript R/06_beber_scacco.R       # → output/tables/tab_beber_scacco_last_digit.csv
Rscript R/07_benford_2bl.R        # → output/tables/tab_benford_2bl.csv
Rscript R/08_spikes_rozenas.R     # → output/tables/tab_spikes_rozenas.csv (~37 min)

# Bloco 3: eforensics (JAGS qbl) — Brasilia
Rscript R/05_eforensics_qbl_fresh_diagnostic.R   # JAGS intercept-only (~32 min)
Rscript R/05_jags_qbl_zone_fe.R                  # JAGS com zone FE (~26 min)

# Diagnosticos
Rscript R/05_dip_test_diagnostics.R   # → quality_reports/results/05_dip_test_diagnostics.txt
Rscript R/05_compare_fits.R           # → quality_reports/results/05_compare_fits.md
```

### Stan (opcional)

O modelo Stan e uma portagem do JAGS qbl para validacao cruzada. Requer CmdStan.

```bash
# Smoke test intercept-only
Rscript R/05_stan_eforensics_qbl_calibrate.R

# Smoke test com zone FE
STAN_EFORENSICS_QBL_ZONE_FE=1 Rscript R/05_stan_eforensics_qbl_calibrate.R
```

### Pendente

Os seguintes blocos ainda nao estao implementados:

- `R/04_eforensics_mebane.R` — pipeline eforensics consolidado (Brasil inteiro, UF FE, steps 3a-3k)
- Bloco 4 — Monte Carlo de poder (fraude sintetica injetada)
- Blocos 5-7 — robustez, benchmark externo, matriz de detectabilidade

## Estrutura

```
R/                    Scripts do pipeline (executar em ordem numerica)
stan/                 Modelos Stan (.stan)
data/processed/       Dados processados (parquet, gerados pelo pipeline)
output/figures/       Figuras (PDFs)
output/tables/        Tabelas de resultados (CSVs)
quality_reports/
  plans/              Planos metodologicos
  results/            Logs, diagnosticos, handoffs
  reviews/            Pareceres sobre a research note
replication_authors/  Materiais originais dos autores
```
