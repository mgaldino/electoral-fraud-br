# Preflight JAGS 20k: PASS

**Resultado:** nenhum achado impeditivo ou defeito novo no delta revisado. O candidato JAGS está tecnicamente apto para adjudicação e release do novo lote. Este parecer não aprova Stan nem precisão posterior. O coordenador delimitou esta entrega a JAGS; o pedido do usuário inclui Stan também, com revisão em etapa própria.

Data: 01/10/2026. Executor: `019d795a-acfa-72c2-a210-d55a46c606c2`. Revisor independente: `01a0f4b8-962b-77a3-a418-6247c6219e8b`, confirmado pelo próprio `get_goal`.

Manifesto vinculante: `jags_candidate/manifest.json`, SHA-256 `61ad865465a2696bf5986d2253defbf6fe64c09aaa2d7f290c8ce64f15692066`.

Contrato `AD-DC2010-LONG-v1`: SHA-256 `fb4a296c9bf0af25812d7d8dd2ab63340fe10d4e73e806e64b5dba3f7dcf481a`.

## Evidência

Os 21 arquivos do manifesto foram conferidos contra originais e snapshots antes e depois dos testes. Nove coincidem também com hashes de `preflight_full02`. Fontes históricas 2k, contrato v2, modelos A/D e dados permanecem íntegros.

As duas fontes R foram reconstruídas independentemente a partir das antigas e coincidem byte a byte após **somente** três substituições: identificador LONG, `2000 -> 20000` e path do próprio snapshot. Os diffs estão preservados. `case`, `A`, `D`, `monitoring`, `diagnostics` e `preflight_tests` do contrato são estruturalmente idênticos a v2; as demais mudanças foram enumeradas em `source_delta.json`. Não há mudança de prior, likelihood, inicialização, semente ou critério diagnóstico.

O runner usa quatro cadeias no mesmo objeto, adaptação 1000, burn 5000, pós 20000 e thin 1 (`run_jags.R:103-105,129-138`). Os diagnósticos mantêm iteração por cadeia, agora `20000 x 4`, inclusive validação de raw, índices dos funcionais e loop das contagens secundárias (`diagnostics.R:32-38,76-87,148-151,181-187,234`). O universo obrigatório continua 2171 A/1742 D, sem dispensar NA ou constantes apenas amostrais.

O novo `run.py:26-47` foi executado com `run_command` falso, sem abrir subprocessos de modelos. Em sucesso, a ordem é geração A, geração D, diagnóstico A, diagnóstico D. Nos cenários de erro/timeout A sem raw, D termina e somente seus diagnósticos são chamados. Todas as chamadas recebem entrypoints e argumentos corretos, uma tentativa por processo e 3600 s. Reutilizar output ou alterar hash do release é rejeitado antes de novas chamadas. O encerramento real por grupo é o mesmo `run_command` já revisado, hash inalterado, importado por `run.py:7-9`.

**Precedência dos limites:** nesta rodada, `contract.json:126-142` e `run.py:34,41` fixam **3600 s por geração e 3600 s por diagnóstico**. Os 1200 s em `timing.md:3-5` pertencem ao lote anterior. Apenas as definições dos relógios são reutilizadas: seis fases, total interno explicitamente parcial, supervisor externo por processo e soma geração+diagnóstico sem dupla contagem. O ESS/s interno mantém nome e denominador próprios (`diagnostics.R:206-208`).

As referências de linha acima pertencem aos paths originais sob `R/experimental/mebane_ad_long/`, salvo indicação do módulo histórico; os mesmos bytes estão no snapshot `jags_candidate/<path>`. Evidências completas por path/linha constam do JSON.

## Verificações Executadas

- **92 controles do delta passaram**, incluindo hashes por arquivo antes/depois, diferenças estruturais e orquestração falsa. Não são 92 testes científicos distintos.
- **69 checks do runner foram reexecutados em shape 20k**, com interfaces, inicializações, cadeia separada versus pooling, NA, constantes amostrais e regras de decisão.
- **Três cenários de timing passaram com engine falsa:** sucesso, falha de compile e falha de setup; preservação dos estágios e durações parciais conferida.
- Reaproveitados os controles científicos/extração e timeout do parecer anterior, SHA-256 `fad1ec65544cb5e43647a3bee359b30f2eb379bc2bfb6f34f31d3d1fe7f3f37d`, somente para código cuja identidade foi verificada.

Comando, executado na raiz do repositório:

```sh
env PYTHONDONTWRITEBYTECODE=1 python3 quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/review/check_jags_delta.py > quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/review/check_jags_delta.log 2>&1
```

As chamadas R e seus logs estão em `checks_jags_delta.json`, `runner_repeat.log` e `timing_repeat.log`. Nenhum teste estava ativo na interrupção solicitada pelo coordenador; não houve teste abortado. Todos os outputs foram preservados somente em `review/`. Os marcadores `raw_chains.rds` da orquestração falsa são texto explicitamente identificado como fixture, não draws empíricos.

## Escopo e Limites

Não se repetiu o pós-processamento integral de 143 unidades em 20k: a derivação byte-exata e os fixtures da nova forma cobrem o delta, reaproveitando a extração e reconstrução já revisadas. Tampouco se executou MCMC, mediu desempenho/RAM ou certificou adaptação e precisão empíricas. Os cenários novos de timeout são simulados; a rotina real de encerramento de descendentes não mudou e sua evidência anterior foi reaproveitada.

A autorização atual cria lote novo e não viola nem altera retrospectivamente o limite do lote antigo. Por delimitação do coordenador, o parecer e o goal finito desta etapa cobrem **apenas JAGS para adjudicação**; Stan continua no pedido do usuário e seguirá em novo goal após envio do freeze. Os resultados ficam para seus checkpoints independentes. Nada aqui aprova produção, G3, G10, identificação, poder ou inferência eleitoral. A ausência de referência numérica externa e a distinção de DC2010 para Brasil permanecem.
