# Setup no desktop da USP para rodar `R/07_brasil_full_qbl.R`

**Objetivo**: transferir o repositório `electoralFraud` para o desktop da USP (máquina dedicada, sempre ligada) e executar o run full qbl em Brasil T2, que deve levar ~1.7 dias por chain (~1.7 dias wall clock com 4 chains paralelas em cores distintos). O notebook pessoal fica livre.

## Pré-requisitos no desktop

- **macOS ou Linux** (o script foi desenvolvido em macOS ARM64; Linux deve funcionar idêntico)
- **R ≥ 4.4** (testado em 4.4.2)
- **Homebrew** (ou apt/yum) para instalar JAGS
- **Git**
- **Espaço em disco**: ~15 GB
  - Dados processados + raw: ~2 GB
  - `renv/library`: ~4 GB
  - Fit rds (output, pode ser grande): ~1-5 GB
- **RAM**: ≥ 16 GB recomendado. O fit com ~40k random effects × 7000 iter × 4 chains pode usar 8-16 GB.
- **CPU**: ≥ 4 cores para paralelização das cadeias. Mais cores não ajudam (parComp = TRUE roda 1 chain por core).

## Passos de setup (ordem obrigatória)

### 1. Transferir o repositório

```bash
cd ~                              # ou outro diretório de trabalho
git clone <URL-DO-REPO>           # quando o repo remoto existir
cd electoralFraud
```

Se o repo ainda não estiver em git remoto, transferir via rsync/scp:

```bash
# no notebook pessoal
rsync -av --exclude='renv/library' --exclude='.Rproj.user' \
      ~/Documents/DCP/Papers/electoralFraud/ \
      usuario@desktop.usp:~/electoralFraud/
```

**Importante**: os parquets em `data/processed/` são essenciais e **não** estão no `.gitignore` só se transferidos via rsync (estão ignorados no git). Verificar que `brasil_2022_secao_clean.parquet` (~52 MB) chega no desktop.

Alternativa: deixar o desktop regenerar os parquets a partir de `replication_authors/` rodando `R/01_load_tse.R` + `R/02_build_vars.R`. Nesse caso, `replication_authors/extracted/fingerprint_brazil/raw-data/*.csv` também precisa ser transferido (são arquivos grandes: 1.5 GB + 263 MB).

### 2. Instalar JAGS

**macOS (Homebrew)**:
```bash
brew install jags
```

**Linux (Debian/Ubuntu)**:
```bash
sudo apt-get update
sudo apt-get install jags
```

Verificar:
```bash
which jags
jags --help  # ou simplesmente `jags` (vai mostrar algo -- nao precisa rodar nada)
```

### 3. Restaurar ambiente R via renv

No diretório `electoralFraud`, iniciar R e rodar:

```r
renv::restore()
```

Isso vai instalar todos os ~125 pacotes listados em `renv.lock` na library local do projeto, incluindo:
- `eforensics` 0.0.4 de `UMeforensics/eforensics_public`
- `rjags` 4.17 (vai tentar compilar contra o libjags do JAGS system)
- `runjags`, `coda`, e ~120 outros

**Se `rjags` falhar a compilar** (erro de "libjags not found"):

```r
# Descobrir o path do jags:
system("brew --prefix jags")   # macOS
# ou:
system("dpkg -L jags | grep lib")   # Linux

# Instalar com configure.args explícitas:
Sys.setenv(PKG_CONFIG_PATH = "/opt/homebrew/opt/jags/lib/pkgconfig")  # macOS
# Ou no Linux: PKG_CONFIG_PATH = "/usr/lib/pkgconfig" ou similar

renv::install("rjags",
              type = "source",
              rebuild = TRUE)
```

### 4. Smoke test rápido

Antes de kickar o run de ~1.7 dias, confirmar que o setup funciona:

```bash
Rscript R/00_setup.R
```

Deve imprimir `Setup carregado. R 4.x.x, data.table threads: X, seed: 20260410` sem erros.

Depois, rodar o compile test de Brasília (verifica que o eforensics está OK):

```bash
Rscript R/05_eforensics_umeforensics_qbl.R
```

Esse script roda as fases 1 (smoke sintético) e 3 (compile Brasília). Deve terminar em ~3 minutos. Se chegar ao fim com `Phase 3 qbl PASS`, o setup está OK.

**NÃO** rodar com `EFORENSICS_FULL=1` aqui — isso dispara o Phase 4 de ~35 min que não é o objetivo do smoke.

### 5. Canary primeiro (OBRIGATÓRIO antes do full run)

**Motivação**: a calibração em São Paulo (26k seções) mostrou **scaling super-linear em N** no teste de compilação — per_iter_per_obs cresceu 2.25× indo de 6.7k (Brasília) para 26k (SP). Com só dois pontos, não dá pra distinguir se:

- (A) a super-linearidade está toda no overhead de compilação (então 7000 iter amortiza e Brasil full = ~1.7 dias), ou
- (B) steady-state também é super-linear (então Brasil full pode levar 5-14 dias)

O canary resolve isso: roda Brasil full com iterações pequenas (200 burn + 300 post + 200 adapt = 700 iter total) pra medir steady-state real antes de kick off do full run.

**Wall clock esperado do canary**:
- Cenário A: ~2-4 horas
- Cenário B: ~8-24 horas
- Qualquer coisa acima de 24h já é sinal vermelho

Kick off em background:

```bash
cd ~/electoralFraud
BURN_IN=200 N_ITER=300 N_ADAPT=200 RUN_TAG=canary \
  nohup Rscript R/07_brasil_full_qbl.R > /tmp/brasil_canary_qbl.log 2>&1 &
echo $! > /tmp/brasil_canary_qbl.pid
```

Monitorar:
```bash
tail -f /tmp/brasil_canary_qbl.log
```

Quando terminar, inspecionar:

```bash
cat quality_reports/results/07_brasil_full_qbl_T2_canary_timings.csv
```

A coluna `per_iter_per_obs_us` comparada com Brasília qbl (45.1 μs) e SP qbl (~100 μs em full, extrapolado) indica se a super-linearidade compensa. Se `per_iter_per_obs_us` do canary Brasil < 120 μs, **full run é viável em 1.5-2 dias**. Se > 200 μs, full run pode ser > 5 dias — aí é preciso repensar (município? subset? Stan?).

### 6. Full run (só depois do canary OK)

Se o canary apontar viabilidade, rodar o full run:

```bash
cd ~/electoralFraud
nohup Rscript R/07_brasil_full_qbl.R > /tmp/brasil_full_qbl.log 2>&1 &
echo $! > /tmp/brasil_full_qbl.pid
```

(Sem env vars — usa os defaults: BURN_IN=2000, N_ITER=5000, N_ADAPT=1000, RUN_TAG=full, autoConv=TRUE.)

Anotar o PID (`/tmp/brasil_full_qbl.pid`) pra conseguir matar o processo se precisar.

Para monitorar progresso:

```bash
tail -f /tmp/brasil_full_qbl.log
```

JAGS imprime barras de progresso para cada chain — útil pra saber onde está.

Para verificar se o processo ainda está rodando:

```bash
ps -p $(cat /tmp/brasil_full_qbl.pid) && echo "rodando" || echo "morto"
```

### 7. Colher os resultados

Quando terminar (barras ****100% em todas as 4 chains + `Run concluido` no log), os outputs estão em (com `_full` ou `_canary` no nome dependendo de `RUN_TAG`):

- `data/processed/07_brasil_full_qbl_T2_<tag>_fit.rds` — fit completo (grande)
- `quality_reports/results/07_brasil_full_qbl_T2_<tag>_timings.csv` — timing
- `quality_reports/results/07_brasil_full_qbl_T2_<tag>_summary.txt` — posterior summary
- `quality_reports/results/07_brasil_full_qbl_T2_<tag>_sessioninfo.txt` — sessionInfo + renv

Transferir esses 4 arquivos de volta pro notebook pessoal via rsync/scp/git push (o .rds provavelmente não vai no git por causa de tamanho; usar rsync).

## Gotchas conhecidos

1. **`fatal error: lipo: can't open input file: /opt/homebrew/libexec/jags-terminal`**: aparece repetidamente no stderr do JAGS. É cosmético (rjags tenta detectar arquitetura do jags-terminal num path hardcoded que não existe em ARM, mas JAGS roda direto mesmo assim). Ignorar.

2. **`monkey-patch order.formulas`**: todos os scripts que chamam `eforensics()` (`R/04_*.R`, `R/05_*.R`, `R/06_*.R`, `R/07_*.R`) incluem um monkey-patch no topo que corrige o bug do `stringr::str_detect` com objeto formula. Não remover.

3. **`autoConv = TRUE` + `max.auto = 3`**: se a diagnose de convergência MCMCSE falhar (precisão > 0.05 em π), o pacote reinicia as cadeias até 3 vezes. Isso pode adicionar 3x ao tempo total no pior caso. Se a precisão não for atingida após 3 tentativas, retorna o último fit com warning. É importante reportar esse warning no log.

4. **Swap/OOM**: se a máquina tiver < 16 GB RAM e entrar em swap, o wall clock pode explodir. Monitorar via `htop`. Se swap for > 20%, considerar matar e reduzir iter ou subset.

5. **JAGS SIGINT vs SIGKILL**: JAGS roda como processo filho. `kill -9 <pid>` em cima do Rscript também mata o JAGS. Não deixar o process como zombie.

6. **Reboot durante o run**: se o desktop reiniciar (update, queda de energia), o run morre — não há checkpoint intermediário. Desabilitar auto-update de OS antes de kickar. Usar `nohup` impede apenas logoff do SSH, não reboot.

7. **T1 não incluído**: este script roda só o 2o turno. Para rodar T1 (11 candidatos em vez de 2), duplicar o script e ajustar o filtro. Mas atenção: em T1 o conceito de "leader" no `bl`/`qbl` precisa ser reavaliado — Mebane define "leader" como candidato com mais votos na unidade agregada, que em BR 2022 T1 também é Lula, mas o modelo pode se comportar diferente com 11 candidatos disputando nominais.

## Tempo esperado

| Fase | Tempo estimado | Cumulativo |
|---|---|---|
| Compile graph + adaptation | 30 min - 2 h | 2 h |
| Burn-in (2000 iter) | ~12 h | 14 h |
| Post-burn (5000 iter) | ~28 h | 42 h |
| `autoConv` restart (pior caso) | até +3× o acima | até 126 h (5 dias) |

**Expectativa realista (sem restarts)**: 40-45 horas de wall clock, ~1.7 dias.

**Pior caso (convergência difícil)**: 5 dias. Se chegar aos 5 dias sem convergir, matar e reduzir iter ou usar subset.

## Checkpoint intermediário

Não há checkpoint nativo no eforensics. Se precisar salvar estado, é possível adaptar para:
1. Reduzir `n.iter` para, por ex., 1000 por chunk
2. Salvar fit parcial após cada chunk
3. Continuar do último estado

Isso exige modificações no script. Por ora, assumir rodar sem checkpoint e aceitar que crash = começar do zero.

## Contato em caso de problema

Se algo der errado durante o run e precisar de debug, os logs têm tudo necessário. Re-sincronizar com notebook e pedir ajuda:

```bash
rsync -av quality_reports/results/ usuario@notebook:~/electoralFraud/quality_reports/results/
```

E o `/tmp/brasil_full_qbl.log` com saída stderr do JAGS.
