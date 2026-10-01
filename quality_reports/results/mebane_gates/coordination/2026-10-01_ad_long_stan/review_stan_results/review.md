# Revisão independente dos resultados Stan2k e da entrega final

**Status: PASS de fidelidade da entrega, sem achados bloqueantes.** Os resultados, a comparação, o Markdown e o PDF correspondem aos inputs congelados e aos diagnósticos verificados. **Stan permanece `computationally_inconclusive`**, assim como JAGS. Este PASS não aprova precisão posterior, equivalência entre engines, inferência eleitoral, produção ou gates históricos.

Revisor: `01a0f717-7535-72e3-baf8-4db20da81abb`. Executores distintos: coordenador `019d795a-acfa-72c2-a210-d55a46c606c2` e implementação Stan `01a0f4b5-4434-7b83-91b9-69ced11b40ba`. Data: 01/10/2026. O escopo explicitamente liberado foi concluído sem novas amostragens ou alterações nas candidatas.

## Vínculo Exato

A candidata é `../results_candidate_manifest.json`, SHA-256 **`d4479f0c060e0cf757bada81c916c852b639fbbed86be73a857211b295ce45f8`**, com 45 arquivos explícitos. Foram conferidos seus vínculos e os manifests da preparação, adaptador, amostragem, diagnóstico 02 e comparação. Ao final, os **202 arquivos vinculados** permaneciam com os mesmos hashes.

Os hashes completos dos resultados, fontes, contratos, revisão/adjudicação do reparo, Markdown e PDF estão em [review.json](review.json). Em particular:

- Diagnóstico produtivo: `../stan_diagnostics02/manifest.json`, SHA-256 `aa8bdbf8596b511eb1093cab14ef03cb934c6e67c221a83eac0bc64c9122ef44`.
- Comparação: `../comparison_final01/manifest.json`, SHA-256 `2a1afc49e27ba653cec39ebeed6c19cae95ed32d96e6f759a9ed8a6262889537`.
- Markdown: `../comparison_report.md`, SHA-256 `32a899467b576754fe1cb13350b8d0aa1dfcca5258268b993a6fe5286f35a602`.
- PDF de quatro páginas: `../comparison_JAGS20k_Stan2k_DC2010_v1.pdf`, SHA-256 `cf53dffcb5e13d259b3f63aacb20dbff73c105245621a5f7adace9f8c5204888`.

O [parecer do reparo](repair_review.md) permanece separado e imutável. A adjudicação do coordenador foi conferida: `../diagnostic_repair_adjudication.json`, SHA-256 `329be8dd8ff7c0da2126fa352620fc0f980af18c1c5021655130319bb7a7bb2b`. O diagnóstico 01 continua preservado como tentativa falha, não como resultado produtivo.

## Verificação Numérica

A tentativa independente `attempt02` completou **21.551/21.551 asserções numéricas** e **83/83 checagens nomeadas da entrega**, além das comparações numéricas de campos nas tabelas. Não houve divergência acima das tolerâncias registradas. A recomposição usa código próprio em R e `posterior` 1.7.0; não executa o adaptador de produção.

Os quatro CSVs foram confrontados integralmente com os RDS originais, separando as 2.000 linhas de warmup das 2.000 retidas por cadeia. Foram confirmados identificadores 1–4, semente-base 1001261, thin 1, warmup salvo, `adapt_delta=.99`, profundidade 12 e inicializações congeladas. Draws: `2000 × 4 × 4890`; sampler: `2000 × 4 × 6`. A diferença máxima de leitura CSV/RDS foi `7,28e-12`.

Foram recompostos os **23 globais**: três pesos, seis interceptos, seis coeficientes, seis variâncias e M/S. `mu` foi reconstruído de `alpha + b0 + sqrt(v)*z`; M/S foram somados dentro de cada draw conjunto, com o mesmo Z. R-hat de ranks, ESS bulk/cauda, MCSE, quantis e quatro médias de cadeia foram recalculados. Também foram recalculados todos os **860 internos NCP**, os critérios HMC e os dois funcionais Rao-Blackwellizados secundários.

| Grupo comum | Alvos | Reprovados | Indefinidos, já incluídos nas falhas |
|---|---:|---:|---:|
| Globais | 23 | 10 | 0 |
| Contínuos locais | 1.287 | 582 | 0 |
| Contagens de classes | 3 | 3 | 2 |
| Indicadores de classes | 429 | 429 | 418 |
| **Total obrigatório comum** | **1.742** | **1.024** | **420** |

Todas as 1.742 decisões foram reaplicadas com `Rhat < 1.01`, ESS bulk/cauda `>= 400` e faixa de classes `<= .05`; contagens de classes usam divisor 143. NA não aprova e não foi tratado como grupo adicional a somar. Médias/faixas dos 429 indicadores e as três contagens foram recompostas dos Z brutos.

Os dez globais reprovados são `pi[1]`, `pi[2]`, `tau.alpha`, `nu.alpha`, `iota.m.alpha`, `iota.s.alpha`, `tb`, `nb`, `M_total` e `S_total`. O R-hat global máximo é **2,69279480328346**, ESS bulk mínimo **4,69041823012559** e ESS cauda mínimo **18,0753347851395**. Portanto, a inconclusão não se restringe às classes raras ou às estatísticas indefinidas.

HMC atende aos critérios: zero divergências e zero atingimentos da profundidade máxima nas quatro cadeias; E-BFMI = **0,916262; 0,880324; 0,588094; 0,827274**, todos acima de 0,3. Entretanto, **291/860 internos NCP reprovam**. Os internos são verificados separadamente dos 1.742 alvos comuns; o bom resultado HMC não substitui a avaliação de mistura e precisão.

## Comparação, Tempos e PDF

As quatro linhas JAGS já revisadas foram reutilizadas, sem reler seus draws brutos: os 92 registros globais e os 18 grupos JAGS coincidem com a comparação anterior vinculada. As fontes A/D atuais e as cópias consumidas pelo estudo antigo e pela rodada de 20 mil continuam byte-idênticas. JAGS20k conserva 14 globais reprovados em A e 13 em D.

Foram conferidas as cinco linhas finais, os agregados, as 23 diferenças **D/Stan menos D/JAGS20k**, o MCSE combinado pela raiz da soma dos quadrados e os denominadores ESS/segundo. As diferenças padronizadas são descritivas, não testes de equivalência. A narrativa distingue sensibilidade A/D da comparação do mesmo alvo D entre implementações e não transforma os funcionais em contagens eleitorais comprovadas.

| Componente Stan | Segundos |
|---|---:|
| Geração, supervisor externo | 2.030,228732459 |
| Diagnóstico produtivo 02, supervisor externo | 52,524022000 |
| Compilação, contada uma vez | 43,164188147 |
| **Total produtivo** | **2.125,916942606** |
| Tentativa diagnóstica 01, preservada e excluída | 11,425812792 |
| Produtivo mais tentativa falha, apenas para transparência | 2.137,342755398 |

A compilação inclui a interface C++ de densidade/gradientes prevista na preparação. Em JAGS, já integra a geração e não foi adicionada novamente. A exclusão da tentativa malsucedida é explícita em `comparison_final01/result.json`, no Markdown e no PDF. O total produtivo não pretende medir todo o tempo do projeto, desenvolvimento ou QA.

As **quatro páginas do PDF foram inspecionadas visualmente**. As 25 linhas de dados das cinco tabelas conferem com o Markdown e a evidência numérica, e foram também localizadas no texto extraído. A Tabela 5 continua na página 4 com cabeçalhos repetidos; nenhuma linha se perdeu. Não foram encontrados cortes, sobreposições, sinais trocados, problemas de glifos ou desalinhamento que comprometam a leitura. A legenda da Tabela 1 começa na página anterior à tabela, sem perda de conteúdo. Evidência detalhada: [visual_review.json](visual_checks01/visual_review.json).

## Limites e Registro

- Todos os 1.742 critérios foram reaplicados, mas os R-hat/ESS de cada contínuo local e indicador individual não foram recalculados exaustivamente. Foram recalculados os 23 globais, 860 internos, três contagens de classes e médias/faixas dos indicadores. Esse limite está registrado em `attempt02/recomputed_summary.json`.
- A fidelidade do alvo compilado reutiliza o preflight congelado e a preservação dos fontes; não houve nova compilação ou auditoria de identificação. JAGS reutiliza sua QA independente vinculada. Não foi reaberto o inventário histórico nem recalculado o estudo antigo.
- Os resultados permanecem computacionalmente inconclusivos. As médias e MCSE não autorizam equivalência, recuperação do alvo ou inferência eleitoral. Os relógios desta rodada serial não estimam diretamente desempenho futuro em paralelo.
- A primeira tentativa do checker parou porque interpretava `save_warmup=true` como número. Foi corrigido apenas o parser independente; `attempt01` e seus logs permanecem preservados. A execução corrigida completa é `attempt02`; ver [checker_corrections.md](checker_corrections.md). Isso não foi classificado como defeito da candidata.

O [manifesto final de evidências](final_evidence.json), SHA-256 `2d525564a26810c5072a1bcc1226542d76afc1f634bfe9ff52166abacc805c29`, vincula scripts, inputs, resultados independentes, inspeção visual e adjudicação. O código e os comandos de reprodução estão neste diretório; `attempt02/reviewer_sources/` preserva os fontes usados. Nenhuma candidata ou revisão JAGS anterior foi editada. Não houve MCMC, resampling empírico, instalação, exclusão ou execução duplicada do pós-processador completo.

**O escopo finito da revisão está concluído.** A aceitação é da fidelidade da entrega congelada, não da precisão científica dos resultados.
