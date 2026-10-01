# Revisão independente B1: Bolívia 2019, round1

**Veredicto: PASS restrito à preparação B1.** Os 51 registros correspondem ao PDF arquivado e as limitações materiais estão declaradas. Não há discrepância material de transcrição pendente. Este parecer não registra aprovação do gate no plano, não atesta prontidão de uma replicação histórica integral e não libera estimação. A adjudicação pertence ao coordenador.

Revisor: **Codex independent B1 source/reference reviewer**, chat `01a0f756-1646-7910-ac2f-986ab89aac82`, 01/10/2026. Este agente não implementou o candidato. Não leu, importou nem executou `extract_reference.py`; escreveu um extrator independente usando a ordem bruta de texto do PDF e conferiu imagens das páginas. Goal nativo finito, sem orçamento de tokens, limitado a este parecer.

## Achados

### B1-R1-F01: divergência de 107 votos na fonte publicada

**P2, CONFIRMED; observação da fonte para B2/B3, não defeito da transcrição B1.** Nas páginas impressas 25 e 33 (PDF 26 e 34), os nove totais partidários somam:

`2240920 + 23725 + 76827 + 25283 + 2889359 + 260316 + 539081 + 42334 + 39826 = 6137671`.

A coluna `Votos.V..lidos` imprime `6137778`: diferença de **−107 votos**. O código publicado redefine `NValid` como a soma das colunas partidárias 15:23; não copia a coluna de votos válidos. Com `Inscritos=7314446`, essa fórmula implica soma de `NAbst=1176775`. Branco e nulo continuam fora de `NValid`, portanto dentro do complemento usado como `NAbst`; isso não atesta adequação substantiva dos dados.

**Encaminhamento concreto:** preservar ambos os totais em B2, investigar a divergência no input quando ele estiver disponível e não impor `6137778` como soma exata do `NValid` reconstruído. Não corrigir votos, denominadores ou o CSV de referência silenciosamente. Não identificamos quais mesas originam a diferença nem sua causa. Evidência: `arithmetic_checks.json` e páginas renderizadas 26/34. Esta revisão não executou B2.

### B1-R1-F02: descrição imprecisa da Tabela 1

**P3, CONFIRMED; não bloqueante.** `reference_values_dictionary.md:77-78` descreve as Tabelas 1–18 como saídas por mesa. A Tabela 1, na p. impressa 4/PDF 5, contém diagnósticos de dígitos/distribuição para MAS e CC e intervalos bootstrap, não linhas de mesas do `qbl`.

**Reparo concreto:** em revisão documental autorizada posterior, distinguir a Tabela 1 das Tabelas 2–18. A exclusão da Tabela 1 do alvo declarado de 51 registros está correta; não há célula faltante nesse alvo. Não alterei o candidato congelado.

## Identidade e procedimento

| Objeto | SHA-256 conferido |
|---|---|
| Manifesto candidato | `afa7b901b85b97b5c369023d75d3e68a88679a487fef37cdb873796644ccf729` |
| PDF arquivado e original da descoberta | `ddcdb42bebf8160abf80b6c189db37951db8ead7f0f763d5469423778f870fb7` |
| CSV candidato | `d4b15199b6191a22fde1bae8609db7c2a9a13a143b2e966c1b9c9f82d3021fdd` |

As 12 entradas do manifesto foram reconferidas. Os fontes `DESCRIPTION`, `ef_models.R` e `ef_summary.R` também coincidem com as cópias na árvore arquivada da descoberta. O PDF tem 36 páginas, 6.174.103 bytes, versão PDF 1.5 e capa de 13/11/2019. A capa não tem número; as células alvo obedecem a `página impressa = página PDF − 1`.

Li `CLAUDE.md`, os dois planos de 01/10 e o `user_request.txt` exato. O pedido atual autoriza esta revisão, não alterações do candidato. A inspeção e as escritas ficaram separadas do trabalho D.C. do coordenador. Todos os outputs desta revisão estão em `review/`.

`independent_check.py` executa uma nova extração `pdftotext -raw`. Seu parser acompanha os cabeçalhos de cadeia entre páginas, associa por número de linha o bloco separado `HPD.upper` e lê os vetores COMBO pelos rótulos publicados. Só depois compara a extração com o CSV candidato. A etiqueta de Chain 3 está no fim da página PDF 31; os seus nove valores estão na página PDF 32. Essa quebra foi conferida visualmente, evitando deslocamento de cadeia.

| Referência | Página impressa / PDF | Linhas | Resultado |
|---|---|---:|---|
| Cadeias 1–2, nove globais cada | 30 / 31 | 18 | Correspondência exata |
| Cadeias 3–4, nove globais cada | 31 / 32 | 18 | Correspondência exata |
| Nove globais combinados | 34 / 35 | 9 | Correspondência exata |
| Dois totais, níveis 95% e 99,5% | 35 / 36 | 4 | Correspondência exata; tipo desconhecido |
| Contagens `no fraud` e `fraud` | 35 / 36 | 2 | Correspondência exata |

Resultado mecânico: **51 registros únicos, 194 células numéricas de médias/SD/limites/contagens, 765 comparações de campos, zero diferenças**. Campos comparados incluem cadeia, parâmetro, covariável, estatística, unidade, fase e páginas. O número 765 inclui os níveis inferidos; não significa que o PDF imprima 95% para os 45 globais. Notas, qualificações e localizadores textuais foram avaliados pelo revisor, não certificados pela simples igualdade de strings. `independent_reference.csv` e `cell_comparison.json` preservam a conferência linha a linha.

Foram renderizadas e visualmente inspecionadas as páginas PDF **1, 2, 3, 5 e 25–36**. Os 16 PNGs permanecem em `visual/`; `visual_qa.json` registra cobertura e limites. Os números alvo estão legíveis. Há linhas de código/log cortadas na margem direita do próprio PDF, sobretudo no pós-processamento; elas não foram reconstruídas por conjectura.

## Intervalos, fases e código

**Globais:** o PDF imprime `Mean`, `SD`, `HPD.lower` e `HPD.upper`. O desvio-padrão não é erro de Monte Carlo. O tipo HPD é uma identificação do cabeçalho publicado, não uma auditoria da construção histórica. Nas linhas 83 e 100 do `ef_summary_3017de5.R`, `summary.eforensics` chama `coda::HPDinterval` sem `prob`. A documentação primária de [coda::HPDinterval](https://search.r-project.org/CRAN/refmans/coda/html/HPDinterval.html) dá o padrão `0.95`. Isso sustenta **95% como inferência condicional ao fonte candidato**, sem identificar a versão histórica de `coda` ou de `eforensics`. A qualificação está no dicionário, linhas 45–50, no `code_identity.md`, linhas 37–44, e nas notas do CSV. Não se deve consumir a coluna `.95` isoladamente como fato histórico certificado.

**Agregados:** os rótulos `95`/`995` são publicados e a p. impressa 1/PDF 2 confirma o nível de 99,5% e a distinção total/manufaturado. As médias são `22519.818` e `5295.798`. Os intervalos são, respectivamente, `[20842.281,24395.891]` e `[4910.488,5734.178]` a 95%; `[20479.794,24663.779]` e `[4751.090,5880.218]` a 99,5%. O tipo HPD versus caudas iguais e o algoritmo permanecem **desconhecidos**. `credible_unspecified` é apropriado. A classificação `34277/274` depende de `CIcombo[["all"]][["Nfraud95"]]`; não é legítimo substituí-la por regra de classe modal ou corte de `pi` sem os scripts.

**Fases:** o comando na p. impressa 26/PDF 27 é `Votes ~ 1, NAbst ~ 1`, `model="qbl"`, quatro cadeias, `burn.in=5000`, `n.adapt=1000`, `n.iter=2000`, `parameters="all"`, `parComp=TRUE`, `autoConv=TRUE`, `max.auto=2`, diagnóstico MCMCSE sobre `pi`, precisão `.05` e `mcmcse.combine=TRUE`. Os logs separam o primeiro bloco 1000/5000/2000, a captura final com nova adaptação 1000 e mais 2000 updates, o `save`/resumo por cadeia e o posterior `load`/resumo combinado/COMBO. O log mostra trechos individuais das cadeias 1/2 no primeiro bloco e 1/3 no final, anunciando quatro simulações em ambos. Não é um registro integral de cada trajetória, nem validação completa do wrapper de B3.

**Código:** o commit candidato tem datas de autor e committer `2019-10-27T04:11:09Z`; o PDF inicia execuções em 28/10 e 29/10. A versão 0.0.4 é cronologicamente compatível. R 3.4.4, plataforma Linux e JAGS 4.3.0 estão impressos. Não há `sessionInfo`, hash, commit ou versão publicada de `eforensics` que certifique a instalação boliviana. Seeds, conteúdo dos inits, versões adicionais e estados históricos continuam desconhecidos. Os nomes `inits1.txt` a `inits3.txt` não revelam o conteúdo dos arquivos.

A string estática do `qbl` arquivado coincide com o snapshot G0 usado por A após desconsiderar apenas espaços externos; o snapshot tem SHA `f8360126424b7a463f76a1c99efc89a8a5cb81339213bd4931559f14595fbab6`. Isso verifica a narrativa local de A, não a instalação na Bolívia. No fonte, `imb`, `isb`, `cmb`, `csb`, `nb` e `tb` recebem `dexp(5)`, e seus recíprocos entram como precisões dos seis efeitos normais locais. Portanto, **Exp(taxa=5) incide nas variâncias**, não nos desvios-padrão. A leitura foi estática, sem executar código dos autores. Não substitui a auditoria de likelihood, wrapper e recursos de B3.

## Aritmética e amostragem

- `34277 + 274 = 34551`; a contagem impressa é internamente compatível com o número de mesas.
- Os nove resumos combinados têm médias iguais à média das quatro médias por cadeia, até `5e-11`, compatível com os algarismos exibidos. Não recomputamos os HPDs conjuntos a partir de médias/SDs, pois isso seria inválido.
- As seis conversões dos totais e limites exatos para uma casa decimal coincidem com a prosa inicial. A diferença entre médias total e manufaturada é `17224.020`; não se deduz um intervalo para essa diferença subtraindo limites marginais.
- As somas das médias de `pi[1:3]` são `1.0000000020`, `1.0000000015`, `1.0000000010`, `0.9999999948` e `0.9999999999` no combinado. Preservamos esses resíduos da fonte, máximo absoluto `5.2e-9`; não atribuímos a causa somente ao arredondamento das casas mostradas nem corrigimos a transcrição.
- As médias de `beta.chi.m` são `−0.3338680365`, `−0.1868573970`, `−0.3449911565` e `−1.5187331400`. A amplitude é `1.3318757430`. Média combinada `−0.5961124325` e SD `0.536580404` não eliminam a discordância. A tibble MCMCSE vazia e `Estimation Completed` não comprovam convergência. Não há novos R-hat, ESS ou MCSE calculados neste parecer.

## Busca e alcance da aprovação

O registro do executor explicita consultas, domínios, URLs tentadas e resultados limitados. Repeti uma busca local dos nomes e uma busca de conteúdo na árvore do pacote arquivado; ambas não encontraram os arquivos/função procurados dentro de seu alcance. A renovação web independente também não localizou downloads primários do CSV ou dos dois scripts. O URL eleitoral foi conferido diretamente na nota 5, p. impressa 2/PDF 3. A referência indexada pelo OEP e o repositório de terceiros são pistas, não prova de identidade do workbook ou do input limpo. As consultas e respostas brutas estão preservadas em `search_review.json` e `web_search*_raw.json`.

As falhas de acesso direto do executor são tratadas como **relato do executor**, não como falhas históricas reproduzidas por mim. Não obtive nem comparei bytes do PDF remoto atual. O objeto validado é a cópia arquivada de hash explicitado, idêntica ao original local fornecido. Nenhum estado “não localizado” foi convertido em “inexistente”.

O PASS refere-se à **qualidade desta preparação documentada e da transcrição**, conforme o pedido atual. Não certifica o critério mais forte de definição operacional completa de todos os intervalos para uma replicação algorítmica futura: nível histórico dos globais é inferido; algoritmos dos agregados e classificação dependem dos scripts ausentes. B3 deverá congelar o que pode ser comparado descritivamente e o que ainda não pode ser chamado de reprodução do mesmo funcional. Recuperação posterior dos insumos pode exigir revisão dessas qualificações.

Não foram executados dados B2, modelos, MCMC, compilação ou instalação. Não houve exclusão, edição do candidato, nova tarefa ou mensagem externa. Não há aprovação de B2/B3, release B4, G10 PASS, validação D/Stan ou inferência brasileira. Somente o goal finito deste parecer é concluído; o coordenador decide a adjudicação e os próximos atos.

## Reprodução

Na raiz do repositório, executar:

```sh
python3 quality_reports/results/mebane_gates/coordination/2026-10-01_bolivia2019_replication/B1/round1/review/independent_check.py
```

O script exige os hashes congelados, escreve somente em `review/` e recusa sobrescrever outputs diferentes. Usa biblioteca padrão Python e Poppler existentes. Renderização usada: `pdftoppm -f 25 -l 36 -scale-to 1700 -png`, além das páginas 1–3 e 5. As imagens já inspecionadas ficam preservadas. `review_manifest.json` vincula os relatórios, o script, as evidências e os PNGs, excluindo apenas o próprio manifesto para evitar autorreferência.
