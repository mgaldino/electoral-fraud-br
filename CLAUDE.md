# electoralFraud — Parecer metodologico

## O que e este projeto

Parecer sobre a research note de terceiros "Is there evidence of fraud in Brazil's 2022 presidential election?" (Figueiredo, Carvalho, Santano). A nota aplica electoral fingerprint analysis (joint distribution turnout x vote share) aos dados TSE 2022 e conclui ausencia de fraude por inspecao visual.

**Papel do usuario**: parecerista / reconstrutor metodologico. Nao e autor da nota.

## Estado atual

Pareceres entregues, script dos autores revisado, plano aprovado. **Pronto para executar** — materiais dos autores (dados TSE 2022 + script R) recebidos em `replication_authors/extracted/fingerprint_brazil/`.

- Manuscrito: `research_note.md`
- Plano metodologico aprovado: `quality_reports/plans/2026-04-10_reconstrucao-metodologica.md`
- Parecer Edmans execution: `quality_reports/reviews/2026-04-10_edmans-execution.md`
- Parecer duplo + carta editorial: `quality_reports/reviews/2026-04-10_review-paper.md`
- Revisao do script R dos autores: `quality_reports/reviews/2026-04-10_review-r-authors-script.md`

## Escopo

**Dentro**: reconstrucao metodologica em R **apenas para 2022** — testes formais, Monte Carlo de poder, triangulacao, robustez, matriz de detectabilidade vetor-de-fraude x metodo.

**Fora** (por decisao do usuario):
- Reescrita de abstract/introducao, reformulacao teorica da pergunta, literatura sobre fraud claims, recomendacoes de policy.
- **Benchmark 2018 x 2022**: trabalho futuro. Segundo ciclo de revisao, com dados de 2018 fornecidos pelos autores.

## Stack

R. Dependencias-chave planejadas: `electionsBR`, `eforensics` (GitHub: DiogoFerrari), `spikes` (CRAN), `BenfordTests`, `data.table`/`arrow`, `future.apply`, `renv`.

## Ao retomar a sessao

1. Ler o plano em `quality_reports/plans/2026-04-10_reconstrucao-metodologica.md`.
2. Comecar pelo Bloco 0 (infra: Rproj, renv, estrutura de pastas `R/`, `data/`, `output/`, `quality_reports/results/`).
3. Bloco 1: ler os CSVs dos autores em `replication_authors/extracted/fingerprint_brazil/raw-data/` via `data.table::fread`/`arrow`, verificar encoding (autores usam `latin1` — confirmar contra UTF-8 em municipios com acento), filtrar presidente + turnos 1/2, persistir em `data/processed/` como `.parquet`.
4. **Achado a verificar ja no Bloco 1**: os autores parecem usar denominadores diferentes entre niveis (municipio = `validos` do Nexojornal; secao = `QT_VOTOS_NOMINAIS`). O autor afirmou que *acha* que sao os mesmos denominadores com nomes diferentes na origem. **Verificar empiricamente**: agregar vote shares de secao ate municipio e comparar com Nexojornal nos mesmos municipios. Se baterem, claim do autor esta correto. Se nao, trocar o default para `QT_COMPARECIMENTO` (padrao Klimek/Kobak/Mebane) e manter as outras especificacoes como robustez.

O bloco metodologicamente mais importante e o **Bloco 4** (Monte Carlo de poder): injetar tres tipos de fraude (ballot stuffing localizado, coercao, adulteracao uniforme de totalizacao) e mostrar empiricamente que o fingerprint tem poder zero contra o terceiro cenario — exatamente o vetor de fraude mais plausivel em urna eletronica centralizada.
