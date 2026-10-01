# Retomada: JAGS 20 mil, Stan 2 mil e frente Bolívia

Data: 01/10/2026. Este documento substitui o registro intermediário
`handoff_progress.md` como ponto de retomada. O estado da revisão/entrega
fica em `state.json` e, após encerramento, `completion.json`. O resultado
computacional observado não é uma aprovação inferencial.

## Resultado do experimento

Executamos as três rodadas autorizadas no mesmo dado D.C. 2010 dos autores:
143 unidades, sem exclusões. A é o qbl literal; D é a alternativa
multinomial experimental. Não houve nova estimação brasileira.

A entrega está encerrada e a revisão independente foi aceita em escopo de
fidelidade, conforme `completion.json` e `results_adjudication.json`.
O revisor verificou os quatro CSVs contra os RDS, recompôs os 23 globais
e 860 internos e reaplicou as 1.742 decisões comuns. Conferiu também as
quatro páginas do PDF. Os R-hat/ESS locais não foram todos recalculados:
esse limite permanece explícito no parecer. Não há aprovação inferencial.

| Rodada | Cadeias e draws retidos por cadeia | Geração, s | Geração + diagnóstico + compilação separada, s | R-hat global máximo | ESS bulk/cauda mínimos globais |
|---|---|---:|---:|---:|---:|
| A/JAGS | 4 x 20.000 | 385,84 | 592,54 | 3,0969 | 4,48 / 5,26 |
| D/JAGS | 4 x 20.000 | 261,65 | 464,26 | 1,5176 | 7,36 / 11,18 |
| D/Stan | 4 x 2.000 | 2.030,23 | 2.125,92 | 2,6928 | 4,69 / 18,08 |

As três rodadas continuam **computacionalmente inconclusivas**. Reprovaram
14/23, 13/23 e 10/23 alvos globais, respectivamente; nenhuma dessas falhas
globais depende de estatística indefinida. Aumentar JAGS para 20 mil não
resolveu a mistura. Stan 2 mil também não demonstrou precisão suficiente.

Stan teve zero divergências, zero atingimentos da profundidade máxima e
E-BFMI de 0,916/0,880/0,588/0,827. Mesmo assim, 291/860 parâmetros internos
falharam nos critérios R-hat/ESS. Portanto, o bom comportamento local de
HMC não atesta concordância entre cadeias nem exploração de todos os modos.
Não se infere disso que as prioris estejam erradas ou que uma engine seja
sempre superior à outra.

As médias amostrais de `pi[1]` em D/JAGS e D/Stan foram 0,9748 e 0,5706;
as de `M_total`, 382,7 e 4.807,8. Dado o diagnóstico ruim, são descrições
dos draws, não estimativas validadas de fraude nem prova de equivalência
entre engines. Os 23 contrastes com MCSE combinado estão em
`comparison_final01/D_engine_differences.csv`, explicitamente descritivos.

## O que ficou implementado

O modelo Stan é uma tradução do **mesmo D**, não de A. Marginaliza a classe
discreta com soma das três probabilidades multinomiais e usa parametrização
não centrada para seis efeitos locais. Mantém `v ~ Exp(5)` nas variâncias,
`sqrt(v)` como desvio-padrão, os demais priors e a prior efetiva parcialmente
ordenada dos pesos. Reconstrói uma única classe por unidade/draw para os
funcionais conjuntos M/S. As médias Rao-Blackwellizadas são secundárias.

Fontes: `models/experimental/mebane_ad_stan/d_multinomial.stan` e
`R/experimental/mebane_ad_stan/`. Preflight: 183 testes do executor,
comparação de densidades/gradientes e revisão independente em `review/stan/`.
A foi preservada byte a byte. Não houve mudança de prior para obter ajuste.

JAGS: adaptação 1.000, warmup 5.000, pós 20.000, quatro cadeias, thin=1.
Stan: warmup 2.000, pós 2.000, quatro cadeias, adapt_delta=0,99,
max_treedepth=12. Uma execução empírica por modelo; não houve resampling.
Todas as cadeias desta rodada foram **seriais**. JAGS 2k/20k reutilizam
sementes/inicializações, portanto não constituem replicações independentes.

O total Stan inclui 43,164 s de compilação do executável e da interface C++
usada para checar densidades/gradientes, uma única vez. Desenvolvimento e
QA não entram no total produtivo. Não houve isolamento completo de outros
aplicativos do computador; houve trabalho documental leve durante o ajuste.

O primeiro pós-processamento falhou após 11,426 s: a classe S3
`posterior::draws_array` fazia `as.matrix()` concatenar cadeias. O novo
wrapper `postprocess_stan_v2.R` remove a classe apenas da representação em
memória. O revisor conferiu os 39.120.000 valores dos draws e os 48.000 do
sampler, preservação exata e fixtures com a classe real. Parecer e adjudicação
em `review_stan_results/repair_review.json` e
`diagnostic_repair_adjudication.json`. A tentativa `stan_diagnostics01` foi
preservada; a válida é `stan_diagnostics02`, 52,524 s. A falha não integra o
total produtivo da tabela, mas seu custo permanece explicitamente registrado.

## Artefatos e verificação

- `jags20k01/`: draws A/D, logs, supervisores, fases e diagnósticos completos.
- `stan2k01/`: CSVs com warmup/amostra, arrays RDS, sampler, fit, logs e timings.
- `stan_diagnostics02/`: diagnósticos HMC, 860 internos, 1.742 alvos comuns e M/S.
- `comparison_final01/`: cinco linhas comparativas, incluindo o piloto JAGS 2k preservado, e fontes de cada cálculo.
- `comparison_report.md` e `comparison_JAGS20k_Stan2k_DC2010_v1.pdf`: relatório com fontes completas, tabelas e limitações.
- `review_jags_results/`: recomputação independente JAGS; `review_stan_results/`: reparo e recomputação independente Stan/entrega.
- `visual_qa_parent.json`: quatro páginas renderizadas e inspecionadas; a revisão independente é registrada separadamente.
- `history_preservation.json`: reconferência do manifesto anterior, distinguindo os quatro documentos vivos cujos bytes antigos estão em `before_live_docs/`.
- `final_manifest.json`: integridade dos arquivos explicitamente incluídos no encerramento; não auditoria irrestrita de toda a história do projeto.

Scripts coordenadores em `R/experimental/mebane_ad_long/`. O comando do
diagnóstico válido é `python3 -B R/experimental/mebane_ad_long/supervise_diagnostics_v2.py RUN_DIR NEW_OUTPUT_DIR`.
A comparação vem de `compare_engines.R`; a apresentação, de `write_report.R`.
Usar diretórios novos se uma reprodução for autorizada; os atuais recusam
sobrescrita. O `fit.rds` Stan depende dos CSVs; não mover/excluir esses
arquivos. Nenhum pacote foi instalado. Binários, draws e tentativas falhas
permanecem locais, mesmo quando ignorados pelo Git.

## Próxima frente autorizada

O novo pedido do usuário está em
`../2026-10-01_bolivia2019_replication/user_request.txt`. O plano está em
`quality_reports/plans/2026-10-01_bolivia2019_replication.json` e `.md`.
São cinco gates B1-B5: fontes, dados, modelo/protocolo/recursos, execução e
checagem/entrega. Sol entregou o primeiro candidato de fontes B1, com 51
registros numéricos. A transcrição de 194 células numéricas foi confirmada
independentemente, mas B1 completo permanece inconclusivo: faltam definições
operacionais de certos intervalos/agregados e a identidade histórica do código.
A soma dos partidos difere em 107 votos do total válido impresso; preservar
ambos e investigar em B2/B3, sem correção silenciosa. Ver a adjudicação B1.

Essa frente usa o **qbl publicado da Bolívia**, sem substituição por D.
Seu protocolo já está autorizado depois de aprovação independente dos
gates prévios, com limites de recursos congelados e sem sobreposição com
os timings D.C./Stan. O CSV limpo e dois scripts externos não foram
localizados na busca inicial renovada; não tratar a ausência como definitiva.
Nenhum ajuste boliviano foi iniciado nesta entrega D.C.

O usuário também determinou cadeias **paralelas e mais núcleos sempre que
possível nas próximas rodadas**. A regra está em `CLAUDE.md` e
`future_parallel_chains.md`; verificar RAM/cores/disco e registrar a
concorrência. Não reiniciar a rodada serial concluída só para mudar timings.

G3 permanece inconclusivo; G10 não está automaticamente aprovado. Nenhuma
engine de produção foi adotada nem análise nacional foi liberada. A
preparação de 2026 continua dependente dos gates de dados, identificação,
diagnósticos e escala. Não excluir arquivos nem instalar dependências sem
autorização explícita.

## Pedido posterior: propostas antes de rodar novamente

O usuário pediu JAGS com 100 mil e Stan com 5 mil draws, burn-in/warmup fixos
menores e investigação dos parâmetros com ESS bulk muito baixo. Pediu
expressamente conferir as propostas dos agentes antes de confirmar.
O registro atual é `../2026-10-01_longer_chains_proposals/decision.md`.
Dois goals finitos preparam diagnóstico dos draws existentes e alternativas
de prioris/precisão. Nenhuma nova amostragem ou alteração de priori foi
iniciada. Os critérios antigos e todos os resultados acima são preservados.
