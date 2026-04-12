# Plano: Reconstrução Metodológica da Nota Técnica sobre Fraude Eleitoral (Brasil 2022)

**Status**: APPROVED — pronto para execução
**Data**: 2026-04-10
**Escopo**: apenas questões de método, apenas eleição de 2022. Framing teórico, reescrita de introdução, literatura sobre *fraud claims*, e benchmark com 2018 ficam de fora deste plano (trabalho futuro).

## Contexto

A research note `research_note.md` aplica *electoral fingerprint analysis* (inspeção visual da distribuição conjunta turnout × vote share) aos dados TSE do 1º e 2º turnos da presidencial de 2022 e conclui que "não há evidência de fraude sistemática". Os dois pareceres em `quality_reports/reviews/` convergem num ponto central: a análise atual é inspeção visual, não teste estatístico; a inferência "ausência de assinatura visual = ausência de fraude" carece de (i) formalização, (ii) análise de poder, (iii) triangulação, (iv) discussão de aplicabilidade do método a urna eletrônica, (v) robustez a escolhas arbitrárias (binning, candidato, região, tamanho de seção), (vi) benchmark temporal (2018).

Este plano reconstrói a evidência metodológica do zero em R, mantendo o fingerprint como ponto de partida descritivo mas cercando-o com testes formais, Monte Carlo de poder, e triangulação. O objetivo final é produzir todo o material quantitativo (scripts, figuras, tabelas, seção metodológica reescrita) para uma versão R&R-capable da nota.

**Materiais dos autores recebidos (2026-04-10)**: os autores enviaram zip com dados TSE brutos de 2022 + um único script R. Conteúdo em `replication_authors/extracted/fingerprint_brazil/`. Revisão técnica do script em `quality_reports/reviews/2026-04-10_review-r-authors-script.md` — bloqueia pela rubrica, mas serve como referência para construção das variáveis no Bloco 1. Achado importante dessa revisão: os autores usam denominadores aparentemente diferentes entre níveis (município = `validos` do Nexojornal; seção = `QT_VOTOS_NOMINAIS`).

**Esclarecimento do autor (2026-04-10, pós-revisão)**: o autor afirmou que acha que são os *mesmos* denominadores, só com nomes diferentes na origem — isto é, a "inconsistência aparente" seria apenas nomenclatura do Nexojornal vs. TSE. **A verificar empiricamente no Bloco 1**: agregar os vote shares de Lula e Bolsonaro das seções para nível município e comparar com os vote shares do Nexojornal para os mesmos municípios. Se a diferença for numericamente nula (ou abaixo de arredondamento), o claim do autor está correto e a crítica do parecer cai. Se houver diferença material, o achado original vale. Qualquer que seja o resultado, **documentar explicitamente** no log do Bloco 1 e só então decidir se o denominador `QT_VOTOS_NOMINAIS` precisa ser trocado por `QT_COMPARECIMENTO` como primário ou mantido como alternativa.

**Escopo temporal**: apenas 2022 (1º e 2º turnos). O benchmark 2018 × 2022 é trabalho futuro — fora do escopo desta execução. Isso **não é bloqueio**: a literatura de fingerprint analysis roda em eleição única sem problema; benchmark é reforço, não pré-requisito.

## Recursos existentes a reutilizar

Verificado via web search:

- **`eforensics`** (Diogo Ferrari, GitHub: `DiogoFerrari/eforensics`) — implementação R do modelo de Mebane (2023, 2025). Mistura finita Bayesiana de 3 componentes: sem fraude ($\pi_1$), fraude incremental ($\pi_2$), fraude extrema ($\pi_3$), com decomposição da fraude incremental em *manufactured votes* ($F_t$, análogo a ballot stuffing) e *stolen votes* ($F_w - F_t$, análogo a vote switching), fixed effects geográficos para turnout / vote choice / frauds magnitudes, diagnósticos MCMC de multimodalidade (dip test + means difference entre cadeias), e interpretação baseada no sinal das active frauds magnitudes (negativo = possível strategic behavior à la Alemanha; positivo = provável malevolent distortion). Não está no CRAN; instalar via `remotes::install_github`.
- **Mebane, W. R. (2025). "eforensics Analysis of the 2024 President Election in Pennsylvania"** — PDF salvo no repo em `PA2024.pdf`. Paper-exemplo do workflow completo: aplicação a PA 2024, com tabelas de parâmetros, figuras residualizadas, diagnósticos de multimodalidade, decomposição manufactured/stolen e interpretação nuanced. Serve como template literal para o Bloco 3 deste plano.
- **`spikes`** (CRAN, Rozenas) — implementa o método de Rozenas 2017 (*Political Analysis*) para detectar spikes em vote-share via kernel density resampling.
- **`electionsBR`** (CRAN, Meireles et al.) — download e limpeza de dados TSE 1998–2024 em nível de seção eleitoral.
- **`dkobak/elections`** (GitHub) — scripts R/Python de Kobak-Shpilkin-Pshenichnikov 2016 para integer percentages test. Referência, não pacote.
- **`BenfordTests`** (CRAN) — implementação genérica de testes Benford; útil para 2BL (second-digit Benford's law), mas exige wrapper.
- **Script e dados dos autores**: `replication_authors/extracted/fingerprint_brazil/`. Script `script_paper_sig.R` serve só como referência para chaves de merge TSE e estrutura dos CSVs — analítico é refeito do zero. Dados brutos `raw-data/votacao_secao_2022_BR.csv` (1.6 GB) e `raw-data/detalhe_votacao_secao_2022_BR.csv` (276 MB) podem ser usados diretamente, evitando re-download via `electionsBR` (sujeito a confirmação de encoding — script dos autores usa `latin1`; TSE recente geralmente é UTF-8).

## Abordagem

A reconstrução se organiza em oito blocos metodológicos, cada um endereçando um item dos pareceres. Todos em R, com reprodutibilidade via `renv` e um Rproj na raiz.

### Bloco 0 — Infraestrutura do projeto

Criar estrutura mínima:

```
electoralFraud/
├── research_note.md            # manuscrito atual (não tocar por ora)
├── electoralFraud.Rproj
├── renv.lock                   # lock de dependências
├── R/                          # todos os scripts numerados
├── data/
│   ├── raw/                    # CSVs TSE originais
│   └── processed/              # .parquet / .rds limpos
├── output/
│   ├── figures/
│   └── tables/
├── quality_reports/
│   ├── plans/                  # este arquivo
│   ├── reviews/                # pareceres Edmans + review-paper
│   └── results/                # logs de Monte Carlo, sessionInfo
└── methods_section.Rmd         # seção metodológica reescrita (Bloco 8)
```

Pacotes a instalar: `electionsBR`, `tidyverse`, `data.table`, `arrow`, `eforensics` (GitHub), `spikes`, `BenfordTests`, `ggplot2`, `patchwork`, `fixest` (para controles), `future.apply` (paralelização Monte Carlo), `renv`, `rmarkdown`.

### Bloco 1 — Aquisição e construção das variáveis

**Objetivo**: reproduzir e documentar a base sobre a qual tudo é calculado, corrigindo omissões apontadas pelos pareceristas (N de seções, denominador, tratamento de seções pequenas, brasileiros no exterior).

Scripts:

- `R/01_load_tse.R` — ler os CSVs TSE 2022 já disponibilizados pelos autores em `replication_authors/extracted/fingerprint_brazil/raw-data/` (`votacao_secao_2022_BR.csv` 1.6 GB + `detalhe_votacao_secao_2022_BR.csv` 276 MB) via `data.table::fread` ou `arrow`, verificar encoding (latin1 vs UTF-8 — script dos autores usa latin1, confirmar), filtrar `DS_CARGO == "PRESIDENTE"` e turnos 1/2, persistir em `data/processed/` como `.parquet`. **Não** usar `electionsBR` nem re-baixar — os autores já forneceram os dados brutos. `electionsBR` fica como fallback se houver problema de leitura.
- `R/02_build_vars.R` — construir:
  - `turnout = QT_COMPARECIMENTO / QT_APTOS`
  - `vote_share_comparecimento = QT_VOTOS / QT_COMPARECIMENTO` (**denominador default — padrão Klimek/Kobak/Mebane**; difere do script dos autores que usa `QT_VOTOS_NOMINAIS`)
  - `vote_share_validos = QT_VOTOS / (QT_VOTOS_NOMINAIS + QT_VOTOS_BRANCOS)` (alternativa para robustez)
  - `vote_share_nominais = QT_VOTOS / QT_VOTOS_NOMINAIS` (especificação dos autores, para comparação direta)
  - `n_eleitores_secao = QT_APTOS` (tamanho da seção — crítico para Johnston-Schroder-Mallawaaratchy 1995)
  - Flags: `exterior` (SG_UF == "ZZ"), `estado`, `região` (via cross-walk UF → região), `municipio`
  - Persistir em `data/processed/` por candidato × turno, nível seção e nível município (agregação via soma dos numeradores e denominadores — **não** média das razões).
- **Reportar explicitamente** em log salvo em `quality_reports/results/01_data_build_log.md`: N de seções totais, N de municípios, N de seções com `QT_APTOS == 0` (excluídas), N de seções com `QT_VOTOS_NOMINAIS == 0`, N de seções no exterior, distribuição de `n_eleitores_secao` (min, p1, p10, p50, p90, p99, max), e qualquer duplicata na chave `(SG_UF, CD_MUNICIPIO, NR_ZONA, NR_SECAO, NR_TURNO)`. Tudo isso que o script dos autores resolvia com `distinct(.keep_all = TRUE)` silenciosamente.

### Bloco 2 — Fingerprint baseline (replicação honesta da análise original)

**Objetivo**: reproduzir o que os autores já fazem, mas com parâmetros explícitos e figuras superiores em qualidade.

- `R/03_fingerprint_base.R` — histograma 2D turnout × vote_share para Lula, Bolsonaro, Ciro, Simone Tebet, Soraya Thronicke (1º turno) e Lula, Bolsonaro (2º turno), nível município e nível seção. Usar `ggplot2::geom_bin_2d` ou `geom_hex`. Escolha de binning **explicitada** (ex.: 100×100 bins em [0,1]×[0,1]) e salva como parâmetro.
- Legendas autocontidas: o leitor deve entender candidato, turno, nível, N, sem ler o corpo do texto.
- Figuras salvas em `output/figures/fig1_fingerprint_baseline_*.pdf`.
- **Nada de novo em termos de inferência** — este bloco é só o baseline visual corrigido. Usar como sanity check contra as figuras originais da nota e contra o que os autores enviarem.

### Bloco 3 — Testes formais (formalização do "teste implícito")

**Objetivo**: substituir a linguagem "teste implícito" por testes genuínos com regra de decisão explícita. Cada teste é rodado nos dados de 2022 (1º e 2º turno, Lula e Bolsonaro separadamente) e reporta uma estatística, um IC e/ou p-valor.

- `R/04_eforensics_mebane.R` — **pipeline completo de Mebane 2025 (PA2024.pdf como template)**, não apenas "ajustar mistura finita". Passos:

  **3a** — Fit inicial do eforensics com fixed effects por **UF** (27 estados brasileiros) para turnout e vote choice (análogo direto ao county FE da Tabela 2 de Mebane). Candidato "leader" = Lula (2º turno) ou Bolsonaro (1º turno) ou ambos separadamente. Unidade = seção eleitoral.

  **3b** — Reportar probabilidades de mistura $\pi_1$ (sem fraude), $\pi_2$ (incremental), $\pi_3$ (extrema) com intervalos HPD 95%.

  **3c** — **Diagnósticos MCMC de multimodalidade** nas probabilidades de mistura:
  - Dip test p-valor $D(\pi_k)$ para cada $k \in \{1,2,3\}$
  - Means difference $M(\pi_k)$ entre maior e menor média de cadeia
  - Critério de "multimodal": $D(\pi_k) < 0.05$ ou $M(\pi_k) > 0.05$

  **3d** — **Protocolo de escalada de FE** (se diagnósticos sinalizam multimodalidade):
  1. Expandir FE para UF em turnout, vote choice **e frauds magnitudes** (análogo Tabela 3 de Mebane). Reestimar. Se diagnóstico ainda sinaliza, ir para (2).
  2. Expandir FE para **município** (5.570 unidades) em turnout, vote choice e frauds magnitudes. Reestimar. Se ainda sinaliza, reportar como limitação.

  **3e** — **Decomposição da fraude incremental**:
  - $F_t$ = posterior mean de votos *manufactured* (= análogo a ballot stuffing: votos inflados do nada)
  - $F_w - F_t$ = posterior mean de votos *stolen* (= análogo a vote switching: transferidos de outro candidato)
  - $F_w$ total de votos flagrados como potencialmente fraudulentos
  - Reportar com IC HPD 99.5%

  **3f** — **Active frauds magnitudes por UF**: coeficientes $\rho_{Mj}$ (incremental manufactured), $\rho_{Sj}$ (incremental stolen), $\delta_{Mj}$ (extreme manufactured), $\delta_{Sj}$ (extreme stolen) com posterior mean e HPD 95% por UF. Figura estilo dot-and-whisker análoga à Figura 2 de Mebane.

  **3g** — **Interpretação discipline baseada no sinal** (o ponto metodologicamente mais importante):
  - UFs com active frauds magnitudes **positivas**: sinal de provável *malevolent distortion* (distorção intencional das intenções dos eleitores)
  - UFs com active frauds magnitudes **negativas**: interpretação ambígua — pode ser fraude OU *strategic voting behavior* (eleitores ajustando voto olhando uns para os outros). Benchmark empírico: eleições federais alemãs, onde ninguém acredita em fraude mas strategic voting é pervasivo, mostram magnitudes consistentemente negativas (Mebane 2025, Section 8.1).
  - Se **todas** ou **quase todas** as UFs brasileiras mostrarem magnitudes negativas, isso é **evidência afirmativa de ausência de fraude malevolente** — não apenas "ausência de assinatura visual". É o tipo de null result disciplinado que os pareceres P1/P2 exigiam.

  **3h** — **Residualized fingerprint plot** (análogo Figura 1b de Mebane): remover FE estado/município dos dados e replotar. Se a bimodalidade observada pelos autores na nota desaparece após residualização, é efeito composicional (heterogeneidade regional — como os autores afirmaram sem testar). Se persiste, é suspeita. **Esta é a resposta formal à crítica da bimodalidade** (muito mais forte que a estratificação visual que estava prevista no Bloco 5).

  **3i** — **Comparação com margem**: $F_w$ total vs. diferença Lula-Bolsonaro no 2º turno (~2,1M votos). Para PA 2024, Mebane reporta $F_w$ = 225k vs. margem 120k = "close call". Para Brasil 2022, se $F_w$ ficar bem abaixo da margem, o resultado é robusto mesmo sob interpretação maximalista.

  **3j** — **Listagem de unidades com frauds ativas** — tabela de UFs/municípios flagrados (análoga à Tabela 4 de Mebane).

  **3k** — **Tratamento de lost votes**: seções com $V_i > N_i$ (votantes > aptos, raríssimo em urna eletrônica mas possível em edge cases). Imputar $N_i := V_i$ e incluir FE por imputation status, seguindo convenção de Mebane.

- `R/05_kobak_integer.R` — implementar (ou portar do `dkobak/elections`) o teste de porcentagens inteiras de Kobak-Shpilkin-Pshenichnikov 2016. Contar frequência observada de turnout e vote share que caem em múltiplos exatos de 5% (ou 10%) e comparar com o baseline esperado sob distribuição suave. Estatística: razão observada/esperada, com IC via bootstrap.
- `R/06_beber_scacco.R` — implementar o last-digit test de Beber & Scacco 2012 *do zero* (trivial: ~30 linhas). Para cada candidato × seção, extrair último dígito da contagem de votos; teste chi-quadrado contra distribuição uniforme discreta em {0,…,9}.
- `R/07_benford_2bl.R` — second-digit Benford usando `BenfordTests::benford` (ou implementação própria) na contagem de votos por candidato × seção. Mantém a crítica de Deckert-Myagkov-Ordeshook 2011 em mente — reportar como *um* teste, não como prova.
- `R/08_spikes_rozenas.R` — aplicar `spikes::spikes()` (método de Rozenas 2017) ao vote share de cada candidato, nível seção. Reportar estatística e curva de densidade com spikes marcadas.

**Output conjunto**: `output/tables/tab1_tests_brazil_2022.csv` (uma linha por teste, colunas: teste, candidato, turno, nível, estatística, IC/p-valor, decisão) + **outputs específicos do pipeline Mebane** (`output/tables/tab1a_eforensics_mixture.csv`, `output/tables/tab1b_eforensics_frauds_by_uf.csv`, `output/tables/tab1c_eforensics_units_flagged.csv`, `output/figures/fig_eforensics_residualized.pdf`, `output/figures/fig_eforensics_frauds_magnitudes_uf.pdf`). Estas tabelas e figuras viram o núcleo do paper revisado.

### Bloco 4 — Monte Carlo de poder (o ponto mais importante)

**Objetivo**: responder à crítica central de ambos os pareceristas ("null result sem poder é indistinguível de teste sem poder"). Demonstrar numericamente quando cada teste detecta fraude e quando é cego.

- `R/09_power_monte_carlo.R` — função `inject_fraud(data, type, fraction, magnitude, candidate)` que toma os dados observados de 2022 (considerados o baseline "limpo") e injeta fraude artificial em três regimes:

  1. **Ballot stuffing localizado** (o que o fingerprint detecta por desenho): selecionar fração $f \in \{0.01, 0.05, 0.10, 0.20\}$ de seções; nessas, adicionar $\delta \in \{0.10, 0.30, 0.50\}$ de votos ao candidato beneficiado e inflar turnout correspondentemente. Move a seção para o canto superior direito.

  2. **Coerção / voto forçado** (parcialmente visível): em fração $f$ de seções, inflar vote share do beneficiado por $\delta$ *sem* inflar turnout (substituição de votos de outros candidatos). Sinal mais fraco.

  3. **Adulteração uniforme da totalização** (invisível ao fingerprint — caso crítico): em *todas* as seções, aplicar shift proporcional $\delta \in \{0.01, 0.03, 0.05\}$ do vote share de um candidato para outro. Não cria cluster; não muda a forma da distribuição.

  Para cada combinação (tipo × $f$ × $\delta$), rodar réplicas Monte Carlo e aplicar os testes do Bloco 3.

- **DECISÃO EM ABERTO — escolher antes de executar este bloco**. Três opções, com trade-offs distintos entre rigor e custo computacional. Decisão pelo autor:

  **Opção A — Eforensics reduzido + outros testes completos**
  Para o Monte Carlo, usar versão *reduzida* do eforensics: mistura de 3 componentes **sem FE geográficos** (só intercepto), com MCMC curto (chains=2, iter=2000). Os outros 4 testes (Kobak, Beber-Scacco, 2BL, spikes) rodam completos. $B = 500$ réplicas. Pipeline completo de Mebane (com FE por UF/município, diagnósticos, decomposição, etc.) roda só uma vez, na análise principal do Bloco 3.
  *Trade-off*: custo computacional manejável (dias, não semanas). Curvas de poder do eforensics são aproximadas — mas a estrutura da curva (positivo em cenário 1, zero em cenário 3) é o que importa, e essa se preserva no modelo reduzido.

  **Opção B — Número reduzido de réplicas com pipeline completo**
  Rodar o pipeline completo de Mebane (com FE + diagnósticos + decomposição) em cada réplica, mas reduzir para $B \in [100, 200]$ réplicas. Idem outros 4 testes.
  *Trade-off*: rigor preservado por réplica, mas menos precisão na taxa de rejeição (IC mais largo). Risco de viés se cadeias MCMC não convergirem em algumas réplicas. Mais lento que Opção A, mas viável.

  **Opção C — Pipeline completo de Mebane, $B = 500$ réplicas**
  Rodar o pipeline completo em todas as 500 réplicas × 3 regimes × 12 combinações $f \times \delta$ × 5 testes. Rigor máximo.
  *Trade-off*: custo computacional proibitivo em máquina local. Provavelmente exige cluster ou várias semanas de execução contínua. Reservar só se houver recursos computacionais dedicados.

  **Decisão adiada** — escolher após rodar o pipeline completo do Bloco 3 uma vez e ter ideia concreta do tempo de ajuste por modelo. A ordem natural de preferência é A > B > C, mas depende do tempo real.

- Paralelização via `future.apply::future_lapply`. Logs, sessionInfo e diagnósticos de convergência salvos em `quality_reports/results/`.

- **Output**: `output/tables/tab2_power_by_scenario.csv` e figura `output/figures/fig2_power_curves.pdf` — uma curva de poder por teste × tipo de fraude, no eixo x a magnitude ($f \times \delta$ ou análogo). Cada entrada da tabela deve reportar qual opção (A/B/C) foi usada.

- **Expectativa analítica** (a confirmar empiricamente): fingerprint e eforensics detectam cenário 1 bem, cenário 2 fracamente, cenário 3 nada; Beber-Scacco e 2BL podem pegar sinais em cenários 1 e 2 mas não em 3; nenhum método detecta 3. Essa é a demonstração numérica de que "ausência de fingerprint ≠ ausência de fraude".

### Bloco 5 — Robustez a escolhas arbitrárias

**Objetivo**: endereçar comentário maior #7 do P2 e comentário maior #10 do P1 sobre binning, estratificação, tamanho de seção, bimodalidade.

**Nota**: a estratificação regional e o teste formal da bimodalidade migraram para o **Bloco 3 (passos 3d e 3h)** via FE por UF/município e residualized fingerprint plots à la Mebane 2025. Este bloco mantém apenas robustez a binning, tamanho de seção, denominador e candidato — dimensões que o pipeline eforensics não cobre diretamente.

- `R/10_robustness_binning.R` — replicar fingerprints visuais (Bloco 2) com diferentes larguras de bin (50×50, 100×100, 200×200, 500×500; autores usam 35). Verificar se a aparência "suave" é robusta. Para o eforensics do Bloco 3, binning não se aplica — o modelo é paramétrico, não histograma.
- `R/11_robustness_sample.R` — refazer fingerprints e reajustar eforensics em subamostras:
  - Estratificado por quartis de `n_eleitores_secao` (resposta direta à crítica Johnston-Schroder-Mallawaaratchy 1995 sobre artefatos em razões de quantidades discretas em seções pequenas).
  - Excluindo seções no exterior (SG_UF == "ZZ").
  - Excluindo seções com `n_eleitores_secao` abaixo de limiares (10, 50, 100).
  - Rodando para todos os candidatos do 1º turno (não só Lula e Bolsonaro).
- `R/12_robustness_denominator.R` — refazer os testes-chave (Bloco 3) com os três denominadores construídos no Bloco 2 (`vote_share_comparecimento`, `vote_share_validos`, `vote_share_nominais`) e verificar se as conclusões são estáveis. Responde à questão do denominador levantada na revisão do script dos autores e ao claim do autor de que "são os mesmos, nomes diferentes".

**Output**: `output/figures/fig3_robustness_grid.pdf` (painel multi-facet) e `output/tables/tab3_robustness_tests.csv`.

### Bloco 6 — Controle positivo externo (opcional)

**Objetivo**: dar ponto de comparação quantitativo com caso conhecidamente fraudado. Sem benchmark, "suave" não tem significado absoluto — mas Monte Carlo do Bloco 4 (injeção de fraude sintética sobre os dados reais de 2022) já supre boa parte dessa função, então este bloco é complementar, não essencial.

- **Benchmark 2018 × 2022**: **fora de escopo desta execução**. Trabalho futuro — os autores têm os dados de 2018 e o Manoel vai buscar depois, em um segundo ciclo. A literatura de fingerprint roda em eleição única sem problema; benchmark é reforço, não pré-requisito.
- `R/13_benchmark_russia.R` (**opcional**, se os dados do `dkobak/elections` forem de baixa fricção de download): aplicar os mesmos testes a Rússia 2011 (caso-controle positivo, conhecido como fraudado). Se todos rejeitam H0 para Rússia 2011 e nenhum rejeita para Brasil 2022, a inferência fica mais forte. Se os dados não estiverem prontamente disponíveis ou o tempo for curto, pular.

**Output** (se Rússia for incluída): `output/tables/tab4_benchmark_russia.csv` e `output/figures/fig4_brazil_vs_russia.pdf`.

### Bloco 7 — Mapeamento: vetores de fraude em urna eletrônica × detectabilidade

**Objetivo**: endereçar diretamente o comentário maior #3 do P2 (o ponto mais importante do parecer técnico). Este bloco é **conceitual + tabela**, não código novo — sintetiza os resultados dos Blocos 3–4 numa matriz de detectabilidade.

- `R/15_detection_matrix.R` — gerar, a partir dos resultados de poder do Bloco 4, uma tabela 2×N com linhas = vetores de fraude plausíveis em urna eletrônica brasileira e colunas = métodos de detecção, entradas = poder empírico contra aquele vetor na magnitude crítica (ex.: $\delta$ = 1pp do resultado nacional).

  Vetores a incluir (enumeração conceitual, não alegação factual):
  - (a) Adulteração do software de totalização central → afeta todas as seções proporcionalmente → invisível ao fingerprint/Klimek.
  - (b) Adulteração do firmware de subconjunto de urnas → visível se geograficamente concentrada, invisível se aleatória.
  - (c) Ballot stuffing físico em seções específicas → assinatura clássica do fingerprint (detectável).
  - (d) Coerção/mobilização irregular de eleitores → parcialmente visível (turnout inflado, vote share menos).
  - (e) Manipulação por mesário em boletins individuais → detectável por Beber-Scacco / 2BL se volumoso.

- Saída em `output/tables/tab5_detection_matrix.csv` e versão formatada para o paper.

**Esta tabela é o principal payoff conceitual do paper revisado**: ela torna explícito o que os testes podem e não podem fazer, evitando a leitura errada "sem fingerprint = sem fraude".

### Bloco 8 — Reescrita da seção metodológica

**Objetivo**: documento Rmd que substituirá a seção *Research Design* + *Results* + *Conclusions (parte técnica)* da nota atual. Puramente metodológico — não toca framing teórico nem introdução.

- `methods_section.Rmd` — estrutura sugerida:
  1. Dados e construção de variáveis (com N, exclusões, distribuição de tamanho de seção).
  2. Baseline descritivo: fingerprints (Bloco 2).
  3. Testes formais e resultados (Bloco 3, Tabela 1).
  4. Análise de poder via Monte Carlo (Bloco 4, Figura 2, curvas de poder).
  5. Robustez (Bloco 5, Figura/Tabela 3).
  6. Benchmark 2018 e, se possível, Rússia 2011 (Bloco 6, Figura/Tabela 4).
  7. Matriz de detectabilidade × vetores de fraude em urna eletrônica (Bloco 7, Tabela 5).
  8. Discussão de limites: qual fraude cada teste detecta, qual é invisível, como a linguagem da conclusão deve ser calibrada.
- Compila via `rmarkdown::render()`.

## Arquivos a criar (ordem sugerida de execução)

- [ ] `electoralFraud.Rproj` — projeto RStudio
- [ ] `renv.lock` — `renv::init()` após instalar pacotes
- [ ] `R/00_setup.R` — paths, pacotes, seeds
- [ ] `R/01_load_tse.R` — Bloco 1 (lê CSVs dos autores, sem download)
- [ ] `R/02_build_vars.R` — Bloco 1
- [ ] `R/03_fingerprint_base.R` — Bloco 2
- [ ] `R/04_eforensics_mebane.R` — Bloco 3 (pipeline completo Mebane 2025; núcleo do paper revisado)
- [ ] `R/05_kobak_integer.R` — Bloco 3
- [ ] `R/06_beber_scacco.R` — Bloco 3
- [ ] `R/07_benford_2bl.R` — Bloco 3
- [ ] `R/08_spikes_rozenas.R` — Bloco 3
- [ ] `R/09_power_monte_carlo.R` — Bloco 4 (central; decisão A/B/C pendente)
- [ ] `R/10_robustness_binning.R` — Bloco 5
- [ ] `R/11_robustness_sample.R` — Bloco 5
- [ ] `R/12_robustness_denominator.R` — Bloco 5
- [ ] `R/13_benchmark_russia.R` — Bloco 6 (opcional)
- [ ] `R/14_detection_matrix.R` — Bloco 7
- [ ] `methods_section.Rmd` — Bloco 8
- [ ] `output/figures/` — 4 figuras principais
- [ ] `output/tables/` — 5 tabelas principais
- [ ] `quality_reports/results/` — logs Monte Carlo + sessionInfo + log de build de dados

## Pontos que ficam explicitamente fora do escopo

- Reescrita de abstract, introdução, conclusões substantivas, título.
- Reformulação da pergunta de pesquisa no nível teórico (comentário maior #1 do P1).
- Engajamento com a literatura sobre *fraud claims* (Beaulieu, Daxecker, Eggers-Garro-Grimmer).
- **Benchmark 2018 × 2022** — trabalho futuro. Em segundo ciclo de revisão, com dados de 2018 fornecidos pelos autores.
- Desenvolvimento das recomendações de policy.

Esses pontos continuam válidos nos pareceres, mas por decisão explícita do autor este plano ataca apenas o lado metodológico e apenas o ciclo de 2022. Um segundo plano (reestruturação teórica + comparação temporal) pode ser feito em paralelo ou depois.

## Verificação

Cada bloco tem um critério de "pronto" verificável:

1. **Bloco 1 pronto quando**: `data/processed/brasil_2022_secao.parquet` existe; `R/02_build_vars.R` roda de ponta a ponta; log em `quality_reports/results/01_data_build_log.md` reporta N de seções, exclusões por `QT_APTOS == 0`, seções no exterior, duplicatas encontradas; N por estado é coerente com publicações do TSE.
2. **Bloco 2 pronto quando**: `fig1_fingerprint_baseline_*.pdf` reproduz visualmente as figuras do paper dos autores com o denominador deles (`vote_share_nominais`) como sanity check, e adicionalmente apresenta o denominador padrão (`vote_share_comparecimento`) como especificação primária.
3. **Bloco 3 pronto quando**: pipeline completo de Mebane 2025 executado (passos 3a-3k); `tab1a_eforensics_mixture.csv`, `tab1b_eforensics_frauds_by_uf.csv` e `tab1c_eforensics_units_flagged.csv` geradas; residualized fingerprint plot em `fig_eforensics_residualized.pdf`; diagnósticos MCMC (dip test + means difference) reportados; sinal das active frauds magnitudes por UF interpretado (malevolent distortion vs strategic behavior); $F_w$ comparado com margem Lula-Bolsonaro. Os outros 4 testes (Kobak, Beber-Scacco, 2BL, Rozenas) também têm linha em `tab1_tests_brazil_2022.csv` com estatística, IC e decisão.
4. **Bloco 4 pronto quando**: decisão A/B/C tomada e documentada; curvas de poder mostram (como esperado) fingerprint/eforensics detectando cenário 1 mas cego ao cenário 3; `tab2_power_by_scenario.csv` permite afirmar "o eforensics tem poder X% contra ballot stuffing afetando f% das seções com magnitude δ, e 0% contra adulteração uniforme da totalização".
5. **Bloco 5 pronto quando**: testes robustos a binning, tamanho de seção, denominador e conjunto de candidatos. (Estratificação regional e teste formal da bimodalidade estão no Bloco 3 via FE Mebane.)
6. **Bloco 6 pronto quando** (se Rússia 2011 incluída): controle positivo rejeita H0 em todos os testes-chave, calibrando a inferência do caso brasileiro.
7. **Bloco 7 pronto quando**: matriz de detectabilidade está completa com números do Bloco 4.
8. **Bloco 8 pronto quando**: `methods_section.Rmd` compila limpo com `rmarkdown::render()` e contém todas as figuras/tabelas referenciadas.

**Verificação de reprodutibilidade final**: `renv::restore()` + executar todos os scripts em ordem em máquina limpa deve regenerar todas as figuras e tabelas sem intervenção manual, a partir dos CSVs em `replication_authors/extracted/fingerprint_brazil/raw-data/`.

## Dependências críticas e riscos

- **`eforensics` fora do CRAN**: depende de GitHub (`DiogoFerrari/eforensics`) e pode ter problemas de instalação (compilação Stan/JAGS). Plano B: implementar o modelo Mebane 2025 à mão em `cmdstanr` baseado na descrição da PA2024.pdf (mais trabalho mas controlado). O pacote Ferrari é a implementação canônica do modelo Mebane — conferir versão/commit mais recente antes de começar.
- **Encoding dos CSVs TSE**: script dos autores usa `latin1`. Verificar no Bloco 1 se é de fato latin1 ou UTF-8 — TSE recente geralmente é UTF-8 e usar latin1 corrompe acentos silenciosamente. Teste: ler 100 linhas em cada encoding, comparar `NM_MUNICIPIO` em cidades com acento conhecido (São Paulo, Brasília, Goiânia).
- **Dados TSE pesados**: 1.87 GB descompactado. `data.table::fread` com `select =` e `nrows =` para prototipagem; `arrow` para persistência. Evitar `readr::read_csv2` puro (lento e pesado em RAM).
- **Custo computacional do pipeline Mebane**: o modelo eforensics com FE por UF (27 níveis) e ~470k seções é pesado. FE por município (5.570 níveis) é substancialmente mais pesado. MCMC pode levar horas por ajuste. Isso impacta a decisão A/B/C do Bloco 4 (ver bloco). Estratégia: primeiro ajustar uma vez no Bloco 3 (análise principal) e medir tempo real de convergência antes de dimensionar o Monte Carlo.
- **Tempo de Monte Carlo**: 3 tipos × 4 frações × 3 magnitudes × $B$ réplicas × 5 testes. Com $B = 500$ e pipeline Mebane completo em cada réplica (Opção C), o custo é proibitivo em máquina local. Opções A e B reduzem custo com trade-offs distintos. Decisão adiada — ver Bloco 4.
