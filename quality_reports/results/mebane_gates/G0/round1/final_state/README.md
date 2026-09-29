# Electoral Fraud — Parecer Metodologico

Reconstrucao metodologica do parecer sobre a research note "Is there evidence of fraud in Brazil's 2022 presidential election?" (Figueiredo, Carvalho, Santano).

## Estado e protocolo vigentes

O plano [Mebane 2022-2026](quality_reports/plans/mebane_2022_2026_gates.json) inclui a analise presidencial de 2022 e a preparacao para dados oficiais de 2026. Os gates analiticos ainda exigem execucao e revisao independente. O baseline G0 esta em `quality_reports/results/mebane_gates/G0/round1/`; a entrega de um candidato nao significa gate aprovado. Nao ha resultado nacional qbl validado nem inferencia de 2026 neste repositorio. Os fits historicos de Brasilia e os testes suplementares nao demonstram fraude nem sua ausencia.

## Replicacao

### Pre-requisitos

- R 4.4.2 no baseline observado, com `renv` 1.1.4
- JAGS >= 4.3 (`brew install jags` no macOS)
- CmdStan 2.37.0 no baseline observado (opcional; o Stan atual e uma aproximacao, nao validacao de equivalencia qbl)

O `renv.lock` registra o commit instalado de `UMeforensics/eforensics_public` e a cadeia de dependencias observada em G0. O carregamento local usa a biblioteca ja existente em `renv/library/macos/R-4.4/aarch64-apple-darwin20`; restauracao fria completa nao foi executada. JAGS e CmdStan tambem dependem de instalacoes de sistema externas ao lockfile.

### Dados

Os CSVs e o XLSX usados em abril de 2026 estao presentes localmente em `replication_authors/extracted/fingerprint_brazil/raw-data/`, junto com o ZIP original em `replication_authors/original_zip/`. Sao materiais de replicacao dos autores, nao um snapshot oficial TSE revalidado neste gate. O inventario G0 registra hashes, tamanhos e correspondencia com o ZIP. Se estiverem ausentes em outro checkout, para reconstruir o baseline historico:

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
Rscript -e 'renv::restore()'  # somente apos revisar as dependencias externas; nao executado no G0
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

O modelo Stan existente relaxa contagens binomiais latentes do JAGS qbl para magnitudes continuas. E um smoke test de uma aproximacao, nao uma portagem exata nem validacao cruzada concluida. Requer CmdStan.

```bash
# Smoke test intercept-only
Rscript R/05_stan_eforensics_qbl_calibrate.R

# Smoke test com zone FE
STAN_EFORENSICS_QBL_ZONE_FE=1 Rscript R/05_stan_eforensics_qbl_calibrate.R
```

### Pendente

Os seguintes blocos ainda nao estao implementados:

- `R/04_eforensics_mebane.R` — pipeline eforensics consolidado (Brasil inteiro, UF FE, steps 3a-3k); ainda nao existe. `R/07_brasil_full_qbl.R` existe como runner historico intercept-only, sem fit nacional correspondente no inventario G0.
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
