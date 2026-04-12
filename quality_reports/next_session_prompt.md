# Prompt para sessão nova — electoralFraud

Copie o bloco abaixo no início de uma sessão nova aberta em `/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/`.

---

```
Estou retomando o projeto `electoralFraud`. Contexto curto:

- Sou parecerista metodológico da research note "Is there evidence of fraud in
  Brazil's 2022 presidential election?" (Figueiredo, Carvalho, Santano), que
  aplica electoral fingerprint analysis aos dados TSE 2022 e conclui ausência
  de fraude por inspeção visual. NÃO sou autor da nota.

- Na sessão anterior produzimos três pareceres convergentes (todos em
  `quality_reports/reviews/`):
  1. Edmans execution (score 4/10)
  2. Review-paper duplo P1+P2 com carta editorial (rejeitar)
  3. Revisão do script R dos autores (score 0/100, bloqueia)

- E um plano metodológico aprovado em
  `quality_reports/plans/2026-04-10_reconstrucao-metodologica.md`.

- Os autores enviaram zip de replicação com dados TSE 2022 brutos + script R
  único. Tudo em `replication_authors/extracted/fingerprint_brazil/` (1.8 GB
  descompactado). Zip original preservado em `replication_authors/original_zip/`.

- Escopo fechado: apenas método, apenas 2022. Ficam FORA: reescrita de
  abstract/introdução/conclusões, reformulação teórica da pergunta, literatura
  de fraud claims, benchmark 2018 (trabalho futuro), recomendações de policy.

**Próximo passo**: começar a execução do plano pelo Bloco 0 (infra) e Bloco 1
(load + build vars a partir dos CSVs dos autores).

**Antes de tocar em qualquer código, leia em ordem**:
1. `CLAUDE.md` (raiz do projeto) — instruções curtas e estado atual
2. `quality_reports/plans/2026-04-10_reconstrucao-metodologica.md` — plano
   completo em 8 blocos, com os 11 passos do pipeline Mebane no Bloco 3
3. `quality_reports/reviews/2026-04-10_review-r-authors-script.md` — achados da
   revisão do script dos autores (referências para o Bloco 1)
4. `PA2024.pdf` (raiz) — Mebane 2025, "eforensics Analysis of the 2024 President
   Election in Pennsylvania". Template literal para o Bloco 3.

**Decisões pendentes a confirmar antes de executar cada bloco**:

- **Bloco 1 — claim do autor sobre denominadores**: os autores usam
  denominadores aparentemente diferentes entre níveis (município = `validos` do
  Nexojornal; seção = `QT_VOTOS_NOMINAIS`). O autor afirmou que acha que são os
  *mesmos* denominadores com nomes diferentes. Verificar empiricamente: agregar
  vote shares seccionais até município e comparar com Nexojornal nos mesmos
  municípios. Reportar resultado no log de build antes de seguir.

- **Bloco 1 — encoding dos CSVs TSE**: autores usam `latin1`. TSE recente
  geralmente é UTF-8. Verificar lendo 100 linhas em cada encoding e comparando
  `NM_MUNICIPIO` em cidades com acento (São Paulo, Brasília, Goiânia). Documentar.

- **Bloco 4 — decisão A/B/C (Monte Carlo de poder)**: adiada. Três opções
  listadas no plano. Ordem natural de preferência A > B > C, mas decisão real
  depende do tempo de convergência medido na primeira execução do pipeline
  Mebane no Bloco 3. Não escolher de cabeça — medir primeiro.

**Regras operacionais**:

- Trabalho em R. Reprodutibilidade via `renv`. Pastas `R/`, `data/raw/`,
  `data/processed/`, `output/figures/`, `output/tables/`, `quality_reports/results/`.
- NÃO executar o script dos autores (`script_paper_sig.R`) — apenas referência.
  Já revisto; a revisão está em `quality_reports/reviews/`.
- Dados brutos ficam em `replication_authors/` (imutáveis). Nosso pipeline lê
  direto dali e persiste versões limpas em `data/processed/*.parquet`.
- Bloco metodologicamente mais importante: **Bloco 4** (Monte Carlo de poder
  com injeção de fraude). Killer experiment = regime 3 (adulteração uniforme
  da totalização), onde o fingerprint tem poder zero por desenho — exatamente o
  vetor de fraude mais plausível em urna eletrônica centralizada. Esse resultado
  é o principal payoff do paper revisado.

Antes de começar qualquer coisa, leia os 4 arquivos listados acima e me diga o
que entendeu ser o estado do projeto e qual é o próximo passo concreto. Só
depois da minha confirmação, entre em plan mode para detalhar o Bloco 0.
```

---

## Notas sobre uso

- O prompt assume sessão aberta **dentro** de `/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/`, não na pasta pai `Papers/` (que é só coordenação).
- A última instrução ("antes de começar... leia os 4 arquivos... me diga o que entendeu...") é deliberada: força o agente novo a validar a compreensão do contexto antes de agir, evitando execução prematura.
- Se quiser pular o passo de validação e ir direto ao trabalho, remova o último parágrafo do prompt — mas recomendo manter.
