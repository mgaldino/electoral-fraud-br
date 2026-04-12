# Revisao do script R dos autores — `script_paper_sig.R`

**Data**: 2026-04-10
**Arquivo revisado**: `replication_authors/extracted/fingerprint_brazil/script_paper_sig.R` (449 linhas, 12 KB)
**Paper associado**: "Is there evidence of fraud in Brazil's 2022 presidential election?" (Figueiredo, Carvalho, Santano)
**Skill usada**: `review-r` + revisao pareada (agente + revisor principal)
**Rubrica aplicada**: `~/.claude/rules/quality-gates.md` (R Scripts)

> **Adendum 2026-04-10 (pos-revisao)**: o autor afirmou que acha que os denominadores de municipio e secao sao os *mesmos*, apenas com nomes diferentes na origem (Nexojornal vs TSE). Se verdadeiro, a critica #1 dos "Achados especificos nao-triviais" abaixo cai. **A verificar no Bloco 1 do plano**: agregar vote shares por secao ate o nivel municipio e comparar numericamente com os vote shares do Nexojornal nos mesmos municipios. As demais criticas do parecer (denominador nao-padrao vs Klimek/Kobak/Mebane, `x13/x22` como nomes de coluna, filtros silenciosos, correlacao Pearson vazia, `bins = 35` fixo, ausencia de testes formais) permanecem validas independentemente.

## Resumo executivo

Script curto, legivel, nao-destrutivo. Reproduz fielmente o que a nota tecnica descreve — fingerprint visual em dois niveis (municipio e secao) + correlacao Pearson entre turnout e vote share. Mas confirma e aprofunda os problemas que os pareceristas P1 e P2 ja haviam apontado, e **adiciona um achado novo**: denominadores inconsistentes entre niveis, nenhum dos quais corresponde ao padrao da literatura de fingerprint. Score: efetivamente **0/100** pela rubrica de R Scripts (dedução saturada). Bloqueia — muito abaixo do threshold de 80.

A revisao nao invalida o plano de reconstrucao metodologica em `quality_reports/plans/2026-04-10_reconstrucao-metodologica.md`: nada do que o plano preve precisa ser revisto a luz do script, porque o script nao implementa nenhum dos testes formais/Monte Carlo/benchmark/triangulacao previstos. Confirma ainda mais a necessidade da reconstrucao.

## Pipeline do script (o que ele faz do comeco ao fim)

1. **Setup (L10-25)**: `pacman::p_load` carrega `dplyr`, `ggplot2`, `patchwork`, `janitor`, `readxl`, `readr`, `scales`, `viridis`, `stringr`, `tidyverse`. `options(scipen = 999)`.
2. **Funcoes auxiliares (L31-117)**: `padronizar_chaves_secao`, `fazer_fingerprint` (histograma 2D via `geom_bin_2d`, 35 bins fixos), `resumir_votos_turno`, `preparar_base_fingerprint_secao`, `filtrar_candidato`.
3. **Dados municipais (L123-151)**: le `votos_presidente_muni_nexojornal_2022.xlsx` (abas `absoluto-1t-2022` e `absoluto-2t-2022`). Constroi `turnout = comparecimento/eleitores` e `votacao_lula = x13/validos`, `votacao_bolsonaro = x22/validos`, `votacao_tebet = x15/validos`, `votacao_ciro = x12/validos`, `votacao_soraia = x44/validos`. **Denominador: `validos` do Nexojornal.**
4. **Fingerprints municipais (L153-209)**: 4 paineis (PT/PL × 1º/2º turno), combinados via `patchwork` em `fig_final`.
5. **Dados por secao (L216-272)**: le `votacao_secao_2022_BR.csv` (1.6 GB) e `detalhe_votacao_secao_2022_BR.csv` (276 MB) via `read_csv2` com `encoding = "latin1"`. Filtra `DS_CARGO == "PRESIDENTE"` e turnos 1/2. `left_join` entre os dois. Constroi `turnout = QT_COMPARECIMENTO / QT_APTOS` e `vote_share = QT_VOTOS / QT_VOTOS_NOMINAIS`. **Denominador: apenas nominais — brancos e nulos excluidos.**
6. **Checagens agregadas (L278-282)**: `resumir_votos_turno` por turno. Nunca exportado.
7. **Base fingerprint por secao (L92-112, 288-289)**: filtra `between(turnout, 0, 1)` e `between(vote_share, 0, 1)`; `distinct()` com chave incluindo `NM_VOTAVEL`. Nao filtra brasileiros no exterior (ZZ), nao trata `QT_APTOS == 0` ou `QT_VOTOS_NOMINAIS == 0` (produzem `NaN/Inf` silenciosamente e somem pelo `between`).
8. **Selecao e graficos (L295-344)**: apenas Lula e Bolsonaro. 4 fingerprints combinados via `patchwork`.
9. **Correlacoes (L348-448)**: Pearson entre `turnout` e `vote_share` por candidato×turno. Plot lollipop com faixa sombreada ±0.2 como "weak association".

**Saidas**: apenas objetos `ggplot` impressos no device ativo. **Nenhum `ggsave`, nenhum `write_csv`, nenhuma tabela exportada, nenhum artefato persistido em disco.**

## Issues pela rubrica R Scripts

| Linha | Issue | Severidade | Dedução |
|---|---|---|---|
| L128-134 vs L271 | **Denominadores inconsistentes entre niveis**: municipio usa `validos` (Nexojornal, ambiguo); secao usa `QT_VOTOS_NOMINAIS`. Os dois niveis nao sao comparaveis entre si. | Critico — bug de dominio | −30 |
| L271 | **Denominador nao-padrao na literatura**: Klimek/Kobak/Mebane usam validos+brancos+nulos (=comparecimento) ou validos. Usar so nominais e escolha nao justificada no paper nem no codigo. | Critico — especificacao errada | −30 |
| L128-134 | **`x13`, `x22`, `x15`, `x12`, `x44` como nomes de colunas** — artefatos de `clean_names()` sobre cabecalhos numericos (provavelmente codigos de coligacao). Se o Nexojornal mudar a planilha, `x13` deixa de ser Lula sem que nada avise. Nenhuma checagem de sanidade. | Critico — bug latente | −20 |
| L124, L217, L222 | Paths relativos sem `here::here()` nem checagem de `getwd()`. Falha silenciosa se rodado fora de `fingerprint_brazil/`. | Critico — caminhos efetivamente fixos | −10 |
| L98-99 | `between(turnout, 0, 1)` e `between(vote_share, 0, 1)` descartam secoes silenciosamente. Sem log, sem diagnostico de quantas. Secoes com `QT_APTOS = 0` ou `QT_VOTOS_NOMINAIS = 0` viram `NaN/Inf` e somem sem rastro. | Major — decisao metodologica nao documentada | −5 |
| L238-242 | `distinct(..., .keep_all = TRUE)` em `sections_seats_pres` descarta duplicatas silenciosamente. Se TSE tiver retotalizacoes, a primeira linha ganha arbitrariamente. Deveria ser diagnostico, nao fix. | Major | −5 |
| L44, L48 | `bins = 35` fixo em `fazer_fingerprint`. Histograma 2D e sensivel a binning; sem robustez a 50/100/200/500. | Major — especificacao arbitraria | −5 |
| L10 | `pacman::p_load` instala silenciosamente na biblioteca default do usuario. Sem `renv`, sem lockfile, sem `sessionInfo()`. | Major — reprodutibilidade | −5 |
| L12-23 | Redundancia: `tidyverse` importado alem de `dplyr`, `ggplot2`, `readr`, `stringr` individualmente. | Major — pacotes desorganizados | −5 |
| L348-448 | **Correlacao de Pearson com N ≈ 470k sem estratificar** por regiao/porte/urbano-rural. Com esse N, qualquer `r ≠ 0` da significante a p < 0.001 — teste estatisticamente vazio. Faixa ±0.2 como "weak association" e ad hoc, sem justificativa. | Major — teste sem valor inferencial | −5 |
| Geral | Nenhum `ggsave`, nenhuma tabela formatada (`gt`/`modelsummary`/`kableExtra`), `resultados_cor` apenas impresso no console. | Major — resultados nao formatados | −5 |
| L216 | `read_csv2` para CSV de 1.6 GB — `data.table::fread` ou `vroom` seriam 5-10× mais rapidos e usariam menos RAM. | Minor — eficiencia | −2 |
| L153-201, 310-344 | Codigo duplicado nas 8 chamadas a `fazer_fingerprint`. Deveria ser `purrr::map` / loop. | Minor | −1 |
| Geral | Nomes mistos PT/EN (`dados_municipio_t1` + `fp_lula_t2` + `sections_votes_2022`) + `x13`/`x22` nao-descritivos. | Minor | −2 |
| Geral | Sem comentarios metodologicos nas decisoes-chave (filtro `between`, `bins = 35`, `distinct` silencioso, escolha de denominador). | Minor | −3 |

**Total: 100 − 133 = score saturado em 0/100.** Mesmo sendo um score teoricamente negativo, o resultado pratico e o mesmo: **bloqueia**, muito abaixo do threshold de commit (80).

Observacao importante: mesmo que todos os issues acima fossem corrigidos, o teto do script seria ≈ 65/100, porque a analise em si e apenas fingerprint visual + correlacao — nao ha teste formal, nao ha triangulacao, nao ha poder. O score baixo nao e problema cosmético; reflete a distancia entre o que o script entrega e o que a literatura de election forensics hoje considera minimo aceitavel.

## Achados especificos nao-triviais

### 1. Denominadores inconsistentes entre niveis (achado novo)

Esse ponto **nao aparece nos pareceres anteriores** (Edmans + review-paper) porque eles revisaram so o texto. O codigo revela:

- **Nivel municipio (L128-134)**: `votacao_lula = x13 / validos` onde `validos` vem da planilha do Nexojornal. O que o Nexojornal chama de "validos" e ambiguo — provavelmente votos nominais + brancos (exclui nulos), mas nao esta verificado no codigo nem explicitado no paper.
- **Nivel secao (L271)**: `vote_share = QT_VOTOS / QT_VOTOS_NOMINAIS` — exclui brancos E nulos.

Resultado: **os dois niveis analisados no paper nao sao comparaveis**. O vote share de Lula em BH no nivel municipio e numericamente diferente do vote share de Lula em BH agregado a partir das secoes, mesmo sem nenhum erro de dado — porque os denominadores sao distintos. Qualquer comparacao cross-scale (que e parte do design da nota) carrega esse vies construido.

Alem disso, **nenhum dos dois denominadores corresponde ao padrao da literatura**. Klimek et al. 2012, Kobak et al. 2016, Mebane 2016 usam **comparecimento** (= nominais + brancos + nulos) como denominador. A literatura russa de fingerprint tambem. Usar so nominais distorce sistematicamente o vote share para cima, especialmente em lugares com muitos brancos/nulos — o que e justamente caracteristico de certas regioes brasileiras. Sem justificativa documentada, a escolha e indefensavel.

### 2. `x13`, `x22`: nomes de coluna como codigos de coligacao

As linhas L130-134 usam `x13`, `x22`, `x15`, `x12`, `x44` como se fossem nomes de candidato. Esses sao artefatos do `clean_names()` aplicado a uma planilha do Nexojornal que provavelmente tem cabecalhos numericos (numeros de coligacao: PT=13, PL=22, etc.). **O codigo nao verifica** que `x13` de fato corresponde a Lula em ambas as abas do Excel. Se o Nexojornal mudar a ordem das colunas, ou a numeracao, o script continua rodando mas passa a plotar o candidato errado.

Fix trivial: `stopifnot(names(dados_municipio_t1)[c("x13","x22")] == c(esperado_lula, esperado_bolsonaro))` ou, melhor, ler a aba e renomear explicitamente por nome legivel apos inspecao.

### 3. Filtros silenciosos descartam dado sem log

`between(turnout, 0, 1)` remove:
- Secoes com `QT_APTOS = 0` → `NaN`
- Secoes com `QT_COMPARECIMENTO > QT_APTOS` → `turnout > 1` (possivel em edge cases de migracao intra-municipal)
- Secoes com `QT_VOTOS_NOMINAIS = 0` → `vote_share = NaN`

`distinct(..., .keep_all = TRUE)` em L238 resolve duplicatas mantendo **a primeira linha arbitrariamente**. Se o TSE tiver retotalizacoes (e tem, em eleicoes grandes), a primeira entrada ganha sem nenhum criterio. Isso vira "correcao silenciosa de dado" sem nenhuma documentacao.

O paper declara "minimizing manual intervention and reducing the risk of replication errors" (research_note.md:20). O script contradiz essa alegacao — ha varios pontos de intervencao nao-documentada.

### 4. Correlacao Pearson com N = 470k

A analise de correlacao (L348-448) e apresentada como segunda linha de evidencia contra fraude. Problemas:

- **N gigante faz qualquer coeficiente ser "significante"**. Com ~470k secoes, `p < 0.001` para `r = 0.01`. O teste nao discrimina.
- **Sem estratificacao**: populacao e altamente heterogenea (urbano vs rural, regiao, porte, IDH). Pearson global agrega tudo e captura composicao, nao relacao.
- **Faixa ±0.2 como "weak"** e ad hoc. Nao ha referencia na literatura justificando esse corte.
- **Sem controles**: Pearson simples nao controla confounders socioeconomicos. Qualquer interpretacao causal/"ausencia de fraude" a partir desse numero e vazia.

Um parecerista metodologico descartaria essa secao inteira.

## Riscos ao executar na maquina

- `pacman::p_load` instala pacotes sem avisar, polui biblioteca default. **Nao-destrutivo, mas indesejavel.**
- `read_csv2` de 1.6 GB com `latin1`: consome 4-6 GB de RAM, pode demorar 3-5 minutos. Se o encoding estiver errado (TSE recente e UTF-8), caracteres acentuados corrompem silenciosamente sem erro.
- **Sem `setwd()`**, sem chamadas de rede, sem paths absolutos do Windows, sem `rm()`. Razoavelmente seguro de executar dentro da pasta `fingerprint_brazil/`.
- **Nada e persistido**: executar o script nao gera artefatos em disco.

## Correspondencia com o paper

- O script **reproduz** o que a nota descreve. Nao ha discrepancia silenciosa entre texto e codigo.
- Mas **codifica decisoes nao documentadas no texto**: escolha de denominador, filtros silenciosos, `bins = 35`, `distinct` como descarte de duplicatas, nomes `x13/x22/x15/x12/x44`.
- A analise de correlacao Pearson nao e destacada no texto do paper, mas aparece no codigo como adendo. Um revisor leitor do paper nao saberia da existencia dela sem ver o script.

## Relacao com o plano de reconstrucao metodologica

**O script nao implementa nenhuma das analises previstas no plano**:

| Plano (Blocos 3-7) | Presente no script? |
|---|---|
| Klimek parametric mixture via `eforensics` | Nao |
| Kobak integer percentages | Nao |
| Beber-Scacco last-digit | Nao |
| 2BL Benford | Nao |
| Rozenas spikes | Nao |
| Monte Carlo de poder (injecao sintetica de fraude) | Nao |
| Robustez a binning | Nao (35 fixo) |
| Estratificacao por regiao/UF/tamanho de secao | Nao |
| Benchmark 2018 × 2022 | Nao |
| Matriz de detectabilidade vetor-fraude × metodo | Nao |

**O que e aproveitavel no Bloco 1 do plano**:
- Funcao `padronizar_chaves_secao` (L31-38) — util como referencia.
- Pipeline de `left_join` entre `sections_votes_pres` e `sections_seats_pres` (L256-272) — util como referencia, **depois de reescrita em `data.table`/`arrow` e com denominador corrigido**.
- Conhecimento de que os CSVs do TSE sao `read_csv2` com separador `;` e **encoding ambiguo** (script usa `latin1`, mas deve ser verificado contra `dadosabertos.tse.jus.br`).

**O que precisa ser reescrito do zero**:
- Denominadores: uniformizar entre niveis, usar padrao da literatura (`QT_COMPARECIMENTO` como denominador default, reportar robustez com alternativas).
- Tratamento de missing, secoes com `QT_APTOS = 0`, brasileiros no exterior (ZZ): com log explicito.
- Leitura e renomeacao explicita das colunas do Excel do Nexojornal (nao confiar em `x13/x22`).
- Robustez a binning.
- Tudo mais: testes formais, Monte Carlo, benchmark, triangulacao, matriz de detectabilidade.

## Veredicto

Bloqueia pela rubrica. Serve como **scaffold de leitura e manipulacao dos dados brutos do TSE**, nao como analise. Confirma em codigo os problemas que os pareceristas ja haviam apontado em texto, e adiciona o achado dos denominadores inconsistentes entre niveis — que deve entrar no parecer final como ponto adicional.

O plano de reconstrucao metodologica (`quality_reports/plans/2026-04-10_reconstrucao-metodologica.md`) segue integralmente valido. Quando a execucao comecar, o Bloco 1 deve **refazer a construcao das variaveis do zero**, usando apenas o pipeline de chaves do script dos autores como referencia, e corrigindo:
1. Denominador padrao (`QT_COMPARECIMENTO` + reportar robustez com alternativas)
2. Renomeacao explicita das colunas do Excel do Nexojornal
3. Log explicito de exclusoes (N de secoes com `QT_APTOS = 0`, `vote_share` fora de [0,1], duplicatas)
4. Verificacao de encoding do TSE (latin1 vs UTF-8)
5. Binning como parametro variavel (entra na robustez do Bloco 5)

## Score final

**0/100** (rubrica R Scripts, dedução saturada). Bloqueia.

Teto teorico do script apos correcao de todos os issues editoriais: ≈ 65/100. Ainda bloquearia, porque a limitacao fundamental — ausencia de teste formal, Monte Carlo, triangulacao — nao e issue de codigo, e issue de design metodologico. Esse e o espaco que o plano de reconstrucao vem preencher.
