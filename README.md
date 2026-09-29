# Electoral Fraud — Parecer Metodologico

Reconstrucao metodologica do parecer sobre a research note "Is there evidence of fraud in Brazil's 2022 presidential election?" (Figueiredo, Carvalho, Santano).

## Estado e protocolo vigentes

O plano [Mebane 2022-2026](quality_reports/plans/mebane_2022_2026_gates.json) inclui a análise presidencial de 2022 e a preparação para dados oficiais de 2026. G0, G1 e G7 foram aprovados após revisão independente e adjudicação em suas pastas `round2/`. G7 aprova somente a prontidão ensaiada do staging de CSV normalizado; ainda faltam conversor auditado dos arquivos oficiais brutos e atestação dos dados reais. A auditoria matemática G2 foi rederivada, mas a escolha do alvo, das priors e dos estimandos continua pendente; o [contrato matemático](appendices/mebane_model_contract.md) e a [adjudicação](quality_reports/results/mebane_gates/G2/round1/adjudication.md) registram as diferenças entre paper, JAGS e Stan. O ledger é a fonte do estado atualizado. Não há resultado nacional qbl validado nem inferência de 2026 neste repositório. Os fits históricos de Brasília e os testes suplementares não demonstram fraude nem sua ausência.

## Replicacao

### Pre-requisitos

- R 4.4.2 no baseline observado, com `renv` 1.1.4
- JAGS >= 4.3 (`brew install jags` no macOS)
- CmdStan 2.37.0 no baseline observado (opcional; o Stan atual e uma aproximacao, nao validacao de equivalencia qbl)

O `renv.lock` registra o commit instalado de `UMeforensics/eforensics_public` e a cadeia de dependencias observada em G0. O carregamento local usa a biblioteca ja existente em `renv/library/macos/R-4.4/aarch64-apple-darwin20`; restauracao fria completa nao foi executada. JAGS e CmdStan tambem dependem de instalacoes de sistema externas ao lockfile.

### Dados

Os CSVs e o XLSX usados em abril de 2026 estão presentes neste checkout em `replication_authors/extracted/fingerprint_brazil/raw-data/`, junto com o ZIP em `replication_authors/original_zip/fingerprint_brazil.zip`. O ZIP tem SHA-256 `88857251458aceecf6a8fdb2501a1e38d4f0f9aeda7c6693bb986464521c4422`, e os quatro membros de `raw-data/` extraídos correspondem aos bytes nele contidos. A aquisição externa histórica do ZIP não foi reconstruída: URL, data original e método de obtenção são desconhecidos. A restauração **exata** do baseline em outro checkout depende de uma cópia íntegra desse ZIP, conferida pelo hash antes da extração; sua disponibilidade fora deste checkout não foi verificada. Baixar genericamente CSVs do TSE e uma planilha do Nexo pode produzir outros bytes e não restaura por si só este baseline. Uma nova obtenção de dados oficiais será versionada e validada separadamente no G1.

Membros esperados no ZIP histórico:
```
raw-data/
  votacao_secao_2022_BR.csv
  detalhe_votacao_secao_2022_BR.csv
  votos_presidente_muni_nexojornal_2022.xlsx
```

### Denominadores do eforensics

A [nota sobre eleitorado, votos depositados, brancos e nulos](quality_reports/results/2026-09-28_mebane_denominadores_brancos_nulos.md) documenta as definições de Mebane, as entradas dos scripts e as verificações das contagens. O baseline usa eleitores aptos como `N` e abstenções efetivas como `a`, de modo que `V = N - a` corresponde ao comparecimento, incluindo brancos e nulos. Há precedente dessa inclusão nas aplicações do autor; isso não constitui validação empírica da escolha para o Brasil. A nota explicita as limitações das fontes e a sensibilidade ainda não testada.

### Setup

```bash
git clone git@github.com:mgaldino/electoral-fraud-br.git
cd electoral-fraud-br
Rscript -e 'renv::restore()'  # somente apos revisar as dependencias externas; nao executado no G0
```

### Pipeline de dados vigente

Executar na raiz com um diretório de saída ainda inexistente. O loader recusa
sobrescrita; o builder exige a mesma configuração usada na carga. Estes
comandos não alteram `data/processed/` nem iniciam estimação:

```bash
Rscript --vanilla R/01_load_tse.R config/mebane/2022.json output/mebane/data/2022/run_novo
Rscript --vanilla R/02_build_vars.R config/mebane/2022.json output/mebane/data/2022/run_novo
Rscript --vanilla tests/mebane/data/test_g1.R --full output/mebane/data/2022/run_novo
```

Para cada repetição, usar outro diretório novo. A configuração identifica fontes,
ano, cargo, turnos, identidade eleitoral e controles. As saídas da validação
vigente estão em `quality_reports/results/mebane_gates/G1/round2/`, com revisão
e adjudicação aprovadas. A aprovação de dados não libera estimação sem os gates
metodológicos e de recursos correspondentes.

### Scripts históricos

Os comandos abaixo descrevem o pipeline de abril, não uma sequência aprovada
para nova estimação. Usam os dados históricos preservados em `data/processed/`;
não consomem automaticamente as saídas versionadas do G1. A integração ao modelo
depende dos gates posteriores, e os scripts de análise podem escrever sobre
suas próprias saídas históricas. Não os executar como continuação automática
da carga acima.

```bash
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
