# Registro intermediário: 01/10/2026

Este arquivo registra o início da execução Stan; não é o relatório final.
Consulte `state.json` e, quando existir, `handoff.md` para o encerramento.

## Escopo autorizado

Pedido: JAGS com 20 mil amostras e adaptação para Stan com 2 mil, preservando
A e estudando D no mesmo caso. Caso mantido: D.C.2010, 143 unidades, sem
exclusões. Nada nesta rodada libera Brasil/2026, G3, G10 ou produção.

JAGS A e D: quatro cadeias, adapt 1000, warmup 5000, pós 20000. Dados,
prioris, sementes e inicializações do piloto anterior foram mantidos.
Stan D: quatro cadeias seriais, warmup 2000, pós 2000, seed 1001261 e IDs
1:4, adapt_delta 0.99, max_treedepth 12. Timeout externo 3600 segundos,
uma tentativa empírica, sem repetição automática. Prioris não foram
alteradas. A classe é marginalizada e reconstruída condicionalmente.

## JAGS concluído

As saídas estão em `jags20k01/`. Revisão independente e adjudicação de
fidelidade quantitativa foram concluídas, sem aprovação de precisão.

| Medida | A | D |
|---|---:|---:|
| Geração, incluindo persistência, s | 385,84 | 261,65 |
| Diagnóstico externo, s | 206,70 | 202,61 |
| Geração + diagnóstico, s | 592,54 | 464,26 |
| R-hat global máximo | 3,0969 | 1,5176 |
| ESS bulk global mínimo | 4,4842 | 7,3593 |
| Globais reprovados | 14/23 | 13/23 |

Ambos continuam computacionalmente inconclusivos, não somente devido a
indicadores de classes raras. Parecer em `review_jags_results/review.json`;
adjudicação em `jags_results_adjudication.json`. A comparação parcial,
sem Stan e com sua linha explicitamente NA, está em `comparison_jags01/`.

## Stan iniciado

Preparação congelada:
`stan_impl/run-20261001T105406Z-attempt03-01a0f4b5/preparation/`.
Manifesto SHA-256:
`2ad3246c3b1a5b5e0c676a85434824644b440cc75c386bc45feeabc34b789bfb`.

Passaram 183 checks do implementador; o revisor separado confirmou
densidade, gradientes, GQ, dados, inicializações e todo o adapter diagnóstico.
Parecer `review/stan/review.json`, adjudicação `stan_adjudication.json`.
Tentativas de desenvolvimento que falharam foram preservadas e não são
tentativas de amostragem empírica.

Execução empírica: `stan2k01/`, log `console.log`, metadados externos em
`supervisor_started.json` e, ao terminar, `supervisor_finished.json`.
Sessão de terminal desta conversa: 89681. Não iniciar outro ajuste só
porque o log não contém uma atualização recente. O supervisor controla
o timeout e guarda os artefatos parciais. Não executar benchmarks ou
testes intensivos concorrentes durante a medição.

O relógio de compilação é 43,164 s, incluindo executável e interface C++
de checagem. A compilação standalone adicional e testes de desenvolvimento
não fazem parte desse relógio do ajuste. Houve edição documental e uma
renderização rotineira do plano durante a amostragem, mas nenhum outro
ajuste ou compilação do experimento. Os tempos são observações nesta
máquina, não um benchmark com isolamento completo do sistema operacional.

## Encerramento ainda necessário

1. Esperar o supervisor terminar; inspecionar código de saída e preservar
   eventual timeout sem repetição automática.
2. Se o fit completo existir, executar `R/experimental/mebane_ad_long/supervise_diagnostics.py`
   com `stan2k01` e uma saída nova `stan_diagnostics01`, na raiz do projeto.
3. Executar `compare_engines.R` em uma saída nova, mantendo a comparação
   parcial. Escrever relatório com `write_report.R` e renderizador preservado
   do estudo anterior. O marcador de criação PDF já foi executado nesta
   solicitação; não repeti-lo nesta mesma operação.
4. QA independente dos resultados Stan, dos números comparativos e do PDF;
   depois adjudicação, documentação final e manifestos. O revisor JAGS
   `01a0f717-7535-72e3-baf8-4db20da81abb` pode ser retomado para esse goal
   distinto. Ele não implementou o modelo nem os diagnósticos.
5. Atualizar README, CLAUDE e descrição do estudo no ledger, preservando
   todos os objetos históricos de gates. Os quatro documentos vivos antes
   desta rodada estão em `before_live_docs/`; conferir a preservação com
   `R/experimental/mebane_ad_long/check_history.py`.

Os subagentes de implementação e preflight terminaram seus goals e foram
fechados. Nenhum pacote foi instalado. Não excluir arquivos, inclusive
tentativas e produtos de compilação. Draws e binários grandes são locais;
as exclusões do Git não removem esses arquivos.
