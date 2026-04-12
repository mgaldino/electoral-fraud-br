# Prompt para subagente: porting de `eforensics` (Mebane 2023) para Stan

**Contexto**: use este arquivo como prompt para um agente independente que vai reimplementar em Stan o modelo de fraude eleitoral finite mixture de Mebane (2023), atualmente implementado em JAGS no ecossistema `eforensics`. Objetivo: comparar velocidade de execução em Brasília 2022 T2 (~6.748 seções) contra a versão JAGS. **Atualização crítica em 2026-04-11**: a inspeção local do `UMeforensics` 0.0.4 mostrou que o alvo canônico disponível em JAGS é **`qbl()`**, e não `bl()`. O `qbl()` é inclusive o default de `eforensics()` (`model = "qbl"`). O `bl()` / `bl_working` deve ser tratado apenas como baseline legado e não como representação primária do paper.

---

## PROMPT (copiar e colar para o agente)

Você é um engenheiro de modelos Bayesianos experiente em Stan (cmdstanr). Sua tarefa é reimplementar em Stan, **from scratch**, o modelo **`qbl()`** do `UMeforensics`, usando o paper de Mebane como referência substantiva principal e o código JAGS do ecossistema `eforensics` como implementação prática a ser auditada.

### Motivação

Há uma implementação canônica em JAGS (`eforensics::eforensics(model = "qbl")`) mas o MCMC é lento em datasets grandes. Queremos uma versão Stan para comparar:
1. Velocidade de amostragem NUTS vs Gibbs (Stan vs JAGS)
2. Estabilidade de convergência
3. Facilidade de escalar para 472.000 seções eleitorais

O dataset de teste já está pronto: Brasília, 2º turno presidencial brasileiro 2022, **6.748 seções eleitorais**, arquivo parquet `data/processed/brasil_2022_secao_clean.parquet` (no repositório `electoralFraud`). A unidade de observação é a seção eleitoral, cada uma com:

- `N_i` = QT_APTOS = eleitores aptos
- `a_i` = N_i - QT_COMPARECIMENTO = abstenções
- `w_i` = QT_VOTOS do "leader" (Lula em BR 2022 T2; é o candidato que ganhou na unidade agregada)

Note que há votos de não-leader (Bolsonaro + brancos + nulos). O modelo `qbl` não precisa desses separadamente — assume que `N_i - a_i - w_i` é "tudo o resto".

### Estrutura do modelo (Mebane 2023 / `qbl`)

O modelo `qbl` preserva a mistura finita de 3 componentes do `bl`, mas adiciona a camada hierárquica com efeitos aleatórios por observação. Cada seção $i$ pertence latentemente a uma de três classes $z_i \in \{1, 2, 3\}$:

1. $z_i = 1$: **sem fraude** (probabilidade de mistura $\pi_1$)
2. $z_i = 2$: **fraude incremental** (probabilidade $\pi_2$)
3. $z_i = 3$: **fraude extrema** (probabilidade $\pi_3$)

com $\pi_1 + \pi_2 + \pi_3 = 1$.

**Parâmetros latentes por seção**:

- $\tau_i \in (0, 1)$ — taxa de comparecimento "genuína" (antes de fraude)
- $\nu_i \in (0, 1)$ — taxa de voto no leader "genuína" (entre os que compareceriam genuinamente)
- $\iota^m_i \in (0, k)$ — magnitude de fraude incremental *manufactured*
- $\iota^s_i \in (0, k)$ — magnitude de fraude incremental *stolen*
- $\chi^m_i \in (k, 1)$ — magnitude de fraude extrema *manufactured*
- $\chi^s_i \in (k, 1)$ — magnitude de fraude extrema *stolen*

**Likelihood condicional à classe latente** (equações de geração dos observáveis $a_i, w_i$ dado $N_i$):

$$
a_i \mid z_i = 1 \sim \text{Binomial}(N_i, \, 1 - \tau_i)
$$

$$
a_i \mid z_i = 2 \sim \text{Binomial}(N_i, \, (1 - \tau_i)(1 - \iota^m_i))
$$

$$
a_i \mid z_i = 3 \sim \text{Binomial}(N_i, \, (1 - \tau_i)(1 - \chi^m_i))
$$

Interpretação: sob fraude incremental (manufactured), alguns eleitores que não compareceriam "são levados" a comparecer (abstinências diminuem); sob fraude extrema, uma fração muito grande dos não-comparecentes é "manufatura".

Para $w_i$ (votos no leader), o modelo é ligeiramente mais intrincado porque distingue votos *manufactured* (novos votos criados) de *stolen* (votos roubados de outros candidatos):

$$
w_i \mid z_i = 1 \sim \text{Binomial}(N_i - a_i, \, \nu_i)
$$

$$
w_i \mid z_i = 2 \sim \text{Binomial}(N_i, \, \tau_i \nu_i + (1 - \tau_i) \iota^m_i + \tau_i (1 - \nu_i)\iota^s_i)
$$

(A fórmula exata para $z_i = 2$ e $z_i = 3$ deve ser **verificada em duas frentes**: contra o código fonte do pacote (`R/ef_models.R`, `R/ef_simulate_data.R`, `R/ef_main.R`) e independentemente contra o paper/documentação de Mebane. A auditoria local já mostrou que a forma de `p.w` no JAGS é **algebricamente consistente** com Mebane quando reescrita em função de `a_i/N_i`, mas o `simulate_bl()` não deve ser tratado como fonte canônica única. Se houver divergência entre implementações e Mebane, documente explicitamente.)

**Parametrização via link logit** (por seção, seguindo Mebane/Ferrari):

- $\tau_i = \sigma(\mu^\tau_i)$ onde $\sigma(\cdot)$ é a logística
- $\nu_i = \sigma(\mu^\nu_i)$
- $\iota^m_i = k \cdot \sigma(\mu^{\iota m}_i)$
- $\iota^s_i = k \cdot \sigma(\mu^{\iota s}_i)$
- $\chi^m_i = k + (1 - k) \cdot \sigma(\mu^{\chi m}_i)$
- $\chi^s_i = k + (1 - k) \cdot \sigma(\mu^{\chi s}_i)$

**Atenção**: o `simulate_bl()` do fork antigo usa $k_1 = 0{,}5$ e $k_2 = 0{,}8$, mas isso **não** coincide com o `bl()` em JAGS nem com Mebane (2023). Para o modelo `bl` estimado, a auditoria local indica que a referência correta é **$k = 0{,}7$**. Não usar $0.5/0.8$ como default canônico do estimador.

**Linear predictors** (seguindo Mebane):

$$
\mu^\tau_i = X^\tau_i \beta^\tau, \quad \mu^\nu_i = X^\nu_i \beta^\nu
$$

$$
\mu^{\iota m}_i = X^{\iota}_i \beta^{\iota m}, \quad \text{idem para } \iota s, \chi m, \chi s
$$

Para esta calibração de Brasília, use **intercept-only** (sem covariáveis):

$$
X^\tau = X^\nu = X^\iota = X^\chi = [\mathbf{1}_i]
$$

isto é, cada $\beta^\cdot$ é um escalar. **Mas cuidado**: em `qbl`, "intercept-only" se refere apenas aos efeitos fixos. O modelo principal continua hierárquico porque mantém os seis efeitos aleatórios por observação, além das variáveis latentes discretas (`Z`, `N.iota.*`, `N.chi.*`) que em Stan exigem marginalização ou reformulação adicional.

### Priors (Mebane 2023 / `qbl`)

A auditoria local mostrou que **há divergência relevante** entre fontes:

- No paper de Mebane (2023), cada coeficiente tem prior `Normal(0, 1/10000)` e $\pi$ usa prior ordenado com auxiliares uniformes para fazer $\pi_1$ fracamente maior e desincentivar label switching.
- No fork antigo `DiogoFerrari/eforensics`, o `bl()` usa coeficientes com variância `10^2` e $\pi \sim \text{Dirichlet}(1,1,1)`.
- No repositório público `UMeforensics/eforensics_public`, o `qbl()` vai além: usa prior ordenado para $\pi`, `k = 0.7`, seis efeitos aleatórios por observação e hiperparâmetros `Exp(5)` no bloco hierárquico.

Logo:

- **não** assumir Dirichlet flat como canônico;
- **não** assumir que `simulate_bl()` descreve os priors do estimador;
- registrar explicitamente qual alvo está sendo portado: paper de Mebane, `bl()` do fork antigo, ou `bl()` do repositório público.

### Tarefa do agente Stan

1. **Ler o source do pacote `eforensics`** para extrair exatamente o modelo JAGS do `"qbl"` que está sendo usado na prática. Pontos de referência:
   - `UMeforensics/eforensics_public/R/ef_main.R` — como os dados são empacotados para JAGS
   - `UMeforensics/eforensics_public/R/ef_models.R` — definição do `qbl()`
   - `UMeforensics/eforensics_public/R/ef_simulate_data.R` — como o pacote gera dados sintéticos
   - `DiogoFerrari/eforensics/R/ef_models.R` — fork antigo a ser auditado, não referência canônica automática
   
2. **Validar independentemente** se esse código JAGS de fato implementa corretamente Mebane:
   - Reconstruir o modelo diretamente a partir de Mebane (2023) e do `PA2024.pdf`, sem depender apenas do código do Ferrari.
   - Comparar, equação por equação e prior por prior, o que o paper diz versus o que o JAGS implementa.
   - Produzir uma nota curta de validação dizendo quais partes batem, quais são ambíguas e quais diferem.
   - Se houver divergência material entre Mebane e Ferrari, **não copiar cegamente o JAGS para Stan**. Nesse caso, documente a divergência, explique a decisão de implementação e, se necessário, reporte duas versões: "Stan fiel ao JAGS" e "Stan fiel ao Mebane".
   - A auditoria local já identificou três discrepâncias que precisam ser tratadas explicitamente:
     1. `simulate_bl()` usa $k_1=0.5$ e $k_2=0.8$, mas o `bl()` estimado e o paper usam $k=0.7$;
     2. o prior de $\pi$ no fork antigo não coincide com Mebane (2023);
     3. o `bl()` do pacote não inclui os random effects do paper de 2023.

3. **Reimplementar em Stan** o modelo `qbl` com as seguintes decisões:
   - Marginalizar as variáveis latentes discretas $z_i$ (Stan não suporta parâmetros discretos — mandatório marginalizar via `log_sum_exp` sobre as 3 componentes).
   - Intercept-only nos efeitos fixos, **mantendo** os 6 efeitos aleatórios por observação do `qbl`.
   - Priors alinhados ao `qbl`: prior ordenado para $\pi$, interceptos globais com prior `Normal(0, 1)` e hiperparâmetros `Exp(5)` exatamente como no JAGS oficial.
   - Parametrização via $\sigma$ (logística) com **$k = 0.7$**.
   - Reportar em `generated quantities` as quantidades que Mebane reporta na Tabela 2 do PA2024.pdf: $\pi_1, \pi_2, \pi_3$, manufactured votes totais $F_t$, stolen votes totais $F_w - F_t$, e fraudulent votes totais $F_w$.
   - Se também produzir uma versão `bl` simplificada para baseline, salvá-la em arquivos separados e rotulá-la explicitamente como legado.

4. **Rodar Stan** no dataset Brasília T2 com **4 chains, 5000 post-warmup iterations, 2000 warmup** (mesma config que a versão JAGS). Dataset a ser construído:
   ```r
   library(arrow); library(data.table)
   secao <- setDT(as.data.frame(read_parquet(
     "data/processed/brasil_2022_secao_clean.parquet")))
   bsb <- secao[CD_MUNICIPIO == 97012L & NR_TURNO == 2L &
                  NR_VOTAVEL %in% c(13L, 22L)]
   bsb_wide <- bsb[, .(
     N = first(QT_APTOS),
     comparecimento = first(QT_COMPARECIMENTO),
     w = sum(QT_VOTOS[NR_VOTAVEL == 13L])
   ), by = .(SG_UF, CD_MUNICIPIO, NR_ZONA, NR_SECAO)]
   bsb_wide[, a := N - comparecimento]
   # 6.748 linhas -> stan data list: N_obs = 6748, N_i, a_i, w_i como int
   ```

5. **Reportar tempo de execução wall clock**, ESS bulk e tail dos 6 parâmetros, $\hat R$ máximo, e posterior means (com 95% HPD ou quantile intervals) para comparação direta com a versão JAGS.

6. **Salvar o fit Stan** em `data/processed/stan_eforensics_brasilia_fit.rds` e as métricas em `quality_reports/results/05_stan_brasilia_timings.csv`.

### Restrições

- **Não modificar** nenhum arquivo fora de `R/`, `stan/`, `quality_reports/results/`, `quality_reports/plans/`, `appendices/`. O parquet `brasil_2022_secao_clean.parquet` é somente leitura.
- **Não instalar JAGS nem rjags** — eles já estão instalados para a outra versão. Instalar **apenas** `cmdstanr` e `CmdStan` se ainda não estiverem disponíveis. `rstan` já está instalado no renv (`renv.lock`), mas `cmdstanr` geralmente é mais leve — use o que achar mais conveniente.
- **Não mude** a estrutura dos dados em Brasília — deve ser exatamente as 6.748 seções com as mesmas colunas.
- **Não rode em todo o Brasil** — escopo é Brasília apenas, até comparação com JAGS estar feita.
- **Não assuma** que `DiogoFerrari/eforensics` está necessariamente correto só porque roda; a validação independente contra Mebane é parte obrigatória da tarefa.
- **Não trate** `simulate_bl()` como descrição canônica do estimador `bl`; ele diverge do JAGS em pontos relevantes.
- Código **Stan comentado** explicando cada bloco (data, parameters, transformed parameters, model, generated quantities).
- Código **R que invoca o Stan** reutilizando o mesmo pipeline de `R/00_setup.R` (paths, seeds, logging via `log_step`/`log_section`).

### Entregáveis

1. `R/05_stan_eforensics_qbl_calibrate.R` — script que carrega dados, chama Stan, mede tempo, reporta.
2. `stan/eforensics_qbl.stan` — arquivo Stan com o modelo principal `qbl`.
3. `quality_reports/results/05_stan_validation_note.md` — nota curta de validação independente do JAGS contra Mebane, com matching/diferenças/decisão de implementação.
4. `quality_reports/results/05_stan_brasilia_log.md` — log narrativo da execução com timings, diagnostics, comparação com Mebane 2025 PA2024.
5. `quality_reports/results/05_stan_brasilia_timings.csv` — tabela de métricas: wall_seconds, per_iter_ms, ESS_bulk_min, ESS_tail_min, rhat_max, divergent_transitions.
6. `data/processed/stan_eforensics_brasilia_fit.rds` — o fit Stan para análise posterior.

### Fontes de consulta obrigatórias

- Mebane, W. R. Jr. (2023). *Lost Votes and Posterior Multimodality in the eforensics Model* (`pm23.pdf`) — paper base do modelo.
- Mebane, W. R. Jr. (2025). *eforensics Analysis of the 2024 President Election in Pennsylvania* — PDF no repositório `electoralFraud/PA2024.pdf`. Tem as tabelas de parâmetros (Tabela 2 e 3) que servem de sanity check.
- `UMeforensics/eforensics_public` — repositório público mais recente do pacote, a ser usado como referência principal de implementação prática.
- `DiogoFerrari/eforensics` — fork antigo a ser auditado e comparado, não assumido como canônico.

### CORREÇÃO IMPORTANTE — alvo único: `qbl` (não bl + fase 2)

**Descoberta posterior (2026-04-11)**: o pacote `UMeforensics/eforensics_public` tem **dois modelos disponíveis**, não um:

- **`bl`** (binomial-logistic): modelo não-hierárquico simples, sem random effects, com `k = 0.7` e prior ordenado sobre $\pi$ (em UMeforensics; o fork DiogoFerrari usa Dirichlet flat incorretamente).
- **`qbl`** (quasi-bl): **modelo hierárquico COMPLETO Mebane 2023**, com `k = 0.7`, prior ordenado sobre $\pi`, **e** random effects observação-específicos $\kappa_i^\tau, \kappa_i^\nu, \kappa_i^{\iota M}, \kappa_i^{\iota S}, \kappa_i^{\chi M}, \kappa_i^{\chi S}$. No JAGS oficial, os hiperparâmetros `imb`, `isb`, `cmb`, `csb`, `nb`, `tb` seguem `dexp(5)` e entram como inversos de precisão/variância do bloco hierárquico. **É o default do `eforensics()`** em UMeforensics. Disponível via `model = "qbl"`.

A auditoria original se focou em `bl` e não inspecionou `qbl`. O JAGS source de `qbl` está em `eforensics:::qbl` no package `UMeforensics/eforensics_public` e é a referência canônica do modelo do paper Mebane (2023).

**Portanto, a tarefa do Stan agent é UNIFICADA**: porte **apenas `qbl`** para Stan. Não há mais "Fase 1 (sem RE) + Fase 2 (com RE)". A referência é o arquivo `qbl` no package UMeforensics, que já tem tudo o que o paper especifica.

Concretamente, o modelo Stan precisa:

1. **3 componentes de mistura** com prior ordenado via auxiliares:
   ```
   pi_aux[1] ~ uniform(0, 1);
   pi_aux[2] ~ uniform(0, pi_aux[1]);
   pi_aux[3] ~ uniform(0, pi_aux[1]);
   pi = pi_aux / sum(pi_aux);
   ```

2. **6 intercepts globais** (iota.m.alpha, iota.s.alpha, chi.m.alpha, chi.s.alpha, nu.alpha, tau.alpha), todos $\sim \mathcal{N}(0, 1)$.

3. **6 hiperparâmetros hierárquicos** (`imb`, `isb`, `cmb`, `csb`, `nb`, `tb`), todos $\sim \text{Exp}(5)$, e transformados em precisões via inverso no JAGS oficial.

4. **6 random effects por observação** (`th`, `nh`, `imh`, `ish`, `cmh`, `csh`), cada um Normal com média no intercepto global correspondente e precisão definida pelo inverso do hiperparâmetro `Exp(5)` correspondente.

5. **Transformações logísticas bounded**:
   - $\tau_j = \text{logit}^{-1}(th_j + \text{omt}_j)$ onde $\text{omt}_j$ é o predictor linear das covariáveis
   - $\nu_j$ idem
   - $\iota^m_j = k \cdot \text{logit}^{-1}(imh_j + oim_j)$, com $k = 0.7$
   - $\iota^s_j$ idem
   - $\chi^m_j = k + (1-k) \cdot \text{logit}^{-1}(cmh_j + ocm_j)$
   - $\chi^s_j$ idem

6. **Latent binomial counts** que o modelo JAGS introduz:
   - $N^{\iota_m}_j \sim \text{Binomial}(N_j, \iota^m_j)$; depois $\iota^m_j := N^{\iota_m}_j / N_j$ (com fix para evitar 1.0)
   - Idem para $\iota^s$, $\chi^m$, $\chi^s$
   
   **Em Stan**: essas contagens discretas **precisam ser marginalizadas** porque Stan não aceita parâmetros discretos. A marginalização é complexa — pode ser feita via expansão exata (se $N_j$ for pequeno) ou via aproximação Normal (para $N_j$ grande). Discuta a escolha e justifique.

7. **Latent class $Z_j \in \{1, 2, 3\}$**: também precisa ser marginalizada via `target += log_sum_exp(log(pi) + log_lik_por_componente)`.

8. **Data model**:
   - $p_a[j]$ (prob. de abstenção) dado por fórmula paper-exata (ver source `qbl`)
   - $p_w[j]$ (prob. de voto no leader) dado por fórmula paper-exata
   - Likelihoods: $a_j \sim \text{Binomial}(N_j, p_a[j])$ e $w_j \sim \text{Binomial}(N_j, p_w[j])$

**Complexidade esperada**: qbl tem $\sim 6 \cdot N_{\text{obs}}$ parâmetros de random effect, que em Brasília é $\sim 40$ mil params. Stan com NUTS escala melhor que JAGS com Gibbs nesse regime, mas a marginalização das contagens binomiais latentes ($N^{\iota_m}$ etc.) é o ponto mais subtil — pode ser necessário reformular o modelo em vez de marginalizar literalmente.

**Calibração JAGS de referência (já disponível)**:
- Brasília (6.748 seções), `qbl`, 4 chains × 7000 iter: medição em andamento (~40 min esperados)
- Brasília, `bl`, 4 chains × 7000 iter: 12.2 min (baseline não-hierárquico)
- Valores em `quality_reports/results/05_eforensics_qbl_timings.csv` e `04_eforensics_timings.csv`

**Alvo da comparação Stan vs JAGS**: wall clock, per-iteration time, ESS_bulk mínimo, $\hat R$ máximo, divergent transitions (Stan-specific), e posterior means de $\pi_1, \pi_2, \pi_3$ + 6 intercepts.

### Fim do prompt

---

## Notas para quem vai usar este prompt

- O agente vai precisar de acesso a:
  1. O repositório `electoralFraud/` com o parquet de Brasília
  2. `PA2024.pdf` como referência
  3. Internet para clonar `DiogoFerrari/eforensics` e ler o source
  4. R + cmdstanr + CmdStan instalados (ou `rstan`)
- Tempo estimado de trabalho: 2-6 horas para quem sabe Stan. A parte mais tempo-consumidora é o reverse-engineering das equações exatas de Mebane a partir do código JAGS do Ferrari.
- Quando ambas as versões (JAGS e Stan) estiverem prontas e rodadas em Brasília, comparar:
  - Wall clock
  - $\hat R$ máximo
  - ESS_bulk mínimo
  - Posterior means dos 6 intercepts e dos $\pi_k$
  - Se os posterior means batem (± tolerância), validação cruzada OK e podemos confiar em ambas as implementações.
  - Se diferirem materialmente, há bug em um dos dois — investigar.
