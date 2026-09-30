# QA-FIDELIDADE G3: preparação concluída, candidato final pendente

Revisor e goal nativo: `01a0ee05-aeaf-7492-a8ea-fa731dd6214a`.
O goal continua ativo: o parecer final depende do hash que a coordenação enviará.
Não foram lidos arquivos de implementação nem conclusões/tentativas provisórias do executor. O protocolo v2 foi lido por autorização explícita e arquivado como input.

## Evidência independente produzida

- Fonte integral e contrato G2 reconferidos: hashes `f8360126424b7a463f76a1c99efc89a8a5cb81339213bd4931559f14595fbab6` e `63b61fb0594d0302a03d999bcff6c62967b6e999f37b4c9a8821f0f8e9ed18d2`.
- Casos e tolerâncias congelados em `freeze_01/freeze.json`, SHA-256 `ff921ec660050d2df5696a16ed4335deb466c5782d5e27689a2dd5e8fcbbe570`, antes dos resultados correspondentes.
- Enumeração independente de N=1,2,3, três configurações, todas as respostas e quatro contagens: 87 células, 195 checks iniciais. A única falha foi quadratura da prior de pi, reparada separadamente com integração nos dois intervalos analíticos; 194 checks originais e a checagem reparada satisfazem suas tolerâncias originais. Kernel diagnóstico, marginais e estados conjuntos preservados.
- Nos três conjuntos, a soma do kernel zero-inválidos é menor que 1 e depende dos parâmetros. Com N=2,3 existe massa positiva fisicamente inválida. Isso não constitui likelihood normalizada ou política comprovada do JAGS.
- Sentinela passou pelo wrapper público instalado até a entrada real de `runjags::run.jags`, interrompida antes da amostragem. O controle com respostas trocadas foi detectado; matrizes assimétricas e lista direta independente foram conferidas. Corrigidos apenas comparadores de tipos/atributos do QA; payloads originais preservados. O adapter do candidato ainda não foi testado.
- Doze probes da fonte JAGS integral inalterada, no JAGS 4.3.2, com condicionamento e inits separados. Pais inválidos ativos foram rejeitados na inicialização; componentes inativos inválidos executaram nos casos testados. As quatro contagens inativas variaram nos draws. O caso N=2,A=1,W=2 executou apesar de violar suporte físico.
- As atualizações condicionadas com contagem/classe livre executaram e produziram apenas estados válidos nos draws observados. Não foi observada a sequência interna de propostas; isso não prova uma política geral de rejeição nem normalização. A execução curta com a,w ausentes não prova um gerador válido.
- Suporte exato versus aritmética finita: 792 estados racionais examinados, 108 probabilidades exatamente inválidas e três divergências numéricas em fronteiras, sem clamp ou tolerância para aceitar p fora de [0,1]. Os três exemplos numéricos usam nu=1, uma fronteira matemática que requer saturação numérica para surgir via ilogit com entradas finitas; não são prova de erro observado no JAGS ou no candidato.
- Cinquenta e sete checks da fonte confirmam os seis blocos, Exp(5) nas variâncias, precisões recíprocas, alpha e b0 preservados, quatro contagens binomiais e ordem parcial de pi.

## Diagnósticos a verificar no candidato

No caso N=1,A=0,W=0, a derivação própria e os 48 estados enumerados mostram S=0 em todo o suporte de massa positiva. Se a classe ativa tiver s=1, pW=1 e W=0 tem probabilidade zero; para Z=1, S é zero por definição. Uma coluna S empiricamente constante não basta por si só para dispensar diagnóstico, mas aqui a constância é analítica.

Na versão instalada `posterior` 1.7.0, `.ess_quantile` calcula ESS do indicador `x <= quantile(x,prob)`. Se o quantil é o átomo máximo, esse indicador é constante e ESS retorna NA. `ess_tail` toma o mínimo dos resultados dos quantis 0.05 e 0.95. Portanto NA pode refletir inadequação do diagnóstico às massas pontuais, sem evidência de má mistura. O protocolo v2 continua exigindo bulk/tail ESS >=400 para alvos não constantes; qualquer tratamento novo exige descrição e adjudicação, não PASS automático nem relaxamento silencioso.

A fórmula de MCSE declarada no v2 é algebricamente adequada para quatro cadeias independentes, de igual tamanho, usando a variância entre 40 médias de blocos em cada uma. Sua aplicação, a autocorrelação entre blocos e a correspondência dos draws com todos os alvos ainda dependem da revisão do candidato. Nenhuma conclusão antecipada foi extraída dos logs relatados pela coordenação.

## Falhas e reparos do próprio QA

As tentativas originais `attempt_20260929T164404110482Z_math` e `attempt_20260929T164413891477Z_wrapper` ficam preservadas, inclusive exit code 1. A tentativa `attempt_20260929T164446516572Z_runtime_01` foi bloqueada pelo pré-requisito do wrapper antes de iniciar R/JAGS; o registro `not_started.json` explicita que nenhuma semente foi consumida. O reparo `corrections_01` tem congelamento próprio e faz somente pós-processamento, sem mudar tolerâncias, casos, fonte ou seeds. Nenhum arquivo foi excluído ou restaurado.

## Pendências antes do parecer final

Receber e conferir hash do manifesto ativo em `revision1/`; inspecionar código e fechamento real dos inputs; verificar preservação do candidato histórico e de cada código executado, inclusive alterações canônicas e tentativas 4/5; conferir cronologia v1/v2, seeds, limites e justificativas de rerun; recompor MCSE/diagnósticos/funcionais dos draws salvos; verificar errata de atribuição do preflight à coordenação e factibilidade de Dobs. Só então emitir review.json/review.md e manifesto de QA. Integridade técnica não satisfaz G3-T1 nem valida produção se o suporte continuar impedindo gerador fiel.

Este arquivo não é parecer final. `candidate_manifest_sha256` permanece ausente e nenhuma atestação `manifest_complete` é feita para candidato não recebido.
