# Preflight anterior aos ensaios G3

O usuário inspecionou `protocol.json` v1 antes dos resultados e identificou que
duas cadeias, Rhat 1.2, ESS 50 e tolerância fixa de 0.12 não sustentam a
comparação "dentro do erro Monte Carlo" de G3-T4. O escopo dos funcionais
monitorados era insuficiente. Classificação: achado confirmado de desenho do
protocolo, antes de qualquer execução dos testes G3.

O único comando R já executado sob v1 sondou versão/disponibilidade de R,
`rjags`, `runjags`, `eforensics`, `jsonlite` e `coda` e, em segunda invocação,
acrescentou a library renv existente para confirmar JAGS 4.3.2. Ambos terminaram
com exit code 0; nenhuma cadeia JAGS, enumeração, gerador ou comparação foi
executada. `g3_deterministic.R` foi escrito, mas não executado. Não havia
processo de teste ativo no momento da interrupção nem output de ensaio a
sobrescrever. O v1 permanece intacto e não será usado para aprovação.

O `protocol_v2.json` registra os critérios confirmatórios antes da primeira
execução. O código dos testes deve registrar MCSE e diagnósticos para cada alvo,
e qualquer dependência ausente torna a comparação inconclusiva, sem instalação.
