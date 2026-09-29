# Requisitos do próximo teste de implementação

Preparado pela coordenação antes da execução G3. Este memorando não autoriza
executar G3 sem G2 aprovado e não altera o contrato estático dos gates.

## Escopo

O alvo é o benchmark literal qbl/JAGS aprovado em G2 round2, não o Stan
histórico aproximado nem uma nova distribuição generativa. O teste inicial deve
ser pequeno, reproduzível e limitado em tempo. Não rodar n2000, Brasília completa
ou Brasil nacional neste lote. Não instalar pacotes.

O executor deve congelar seu protocolo de comparação antes de observar resultados:
casos, sementes, número de cadeias/iterações, tolerâncias determinísticas e
Monte Carlo, critérios de diagnóstico, limite de execução e tratamento de
falhas. Registrar esse arquivo como input do run. Se o runtime impedir uma
comparação, preservar a falha e marcar o contraste correspondente inconclusivo;
não trocar parâmetros ou aumentar tolerâncias silenciosamente para obter PASS.

## Verificações prioritárias

1. Compilar e exercitar o arquivo literal qbl identificado por hash, distinguindo
   dados observados, valores latentes condicionados e inits. Quando usar uma
   redução analítica ou um modelo auxiliar para isolar o problema, rotulá-lo como
   tal e cotejá-lo com o comportamento da fonte integral inalterada.
2. Testar suporte inválido na inicialização e nas atualizações do JAGS. Abranger
   classes ativas e inativas, quatro contagens binomiais e a expressão ponderada
   literal de p.w. Não supor que somente o componente ativo importe ao runtime
   antes de observar a execução. Guardar mensagens, versões e exit codes.
3. Enumerar pequenos N e casos de fronteira para uma referência numérica da
   likelihood. Distinguir kernel com estados inválidos zerados, normalização e
   semântica efetivamente observada no JAGS. Testar separadamente suporte
   probabilístico e suporte físico a + w <= N.
4. Um gerador literal deve conservar e contar tentativas inválidas, sem clamp,
   redraw silencioso ou renormalização. Se o qbl não define um gerador completo
   nesse suporte, entregar um auditor de geração com falha explícita, não uma
   correção implícita. Essa entrega não torna G3-T1 automaticamente satisfeito.
5. Conferir as priors efetivas, a ordem parcial de pi, os seis efeitos por
   observação, o desenho e ambos os interceptos. Testar funcionais por draw e
   agregação conjunta. Preservar incerteza das classes; esperanças condicionais
   devem receber outro nome e não substituir intervalos da distribuição completa.
6. Comparar engines apenas no mesmo alvo. Na falta de Stan equivalente executável,
   uma comparação JAGS versus enumeração exata de um problema condicionado pequeno
   é evidência delimitada, não equivalência da portagem completa. Não acrescentar
   Stan exato apenas para preencher uma lista se a semântica ainda estiver aberta.
7. Testar a interface de dados com sentinela assimétrica, a != w: no wrapper do
   commit 3017de5, `formula1` alimenta `w`/`Xw` e `formula2` alimenta `a`/`Xa`.
   As versões anteriores de `R/05_eforensics_umeforensics_qbl.R` e
   `R/07_brasil_full_qbl.R` invertiam essas chamadas. AR-02 corrigiu os quatro
   pares e passou em QA independente; ver `interface_repair_closure.json`
   adjacente. Não sobrescrever outputs antigos nem tratar essa aceitação
   delimitada como PASS de G3. `fresh_v2` e `zone_fe` usam listas diretas com
   campos corretos, portanto o achado não lhes é imputado.

## Decisão esperada

Identificar o código e a versão testados e distinguir: execução, concordância
numérica, convergência, fidelidade da portagem e validade inferencial. A decisão
pode manter JAGS como referência de software e rejeitar equivalência do Stan
histórico. Problemas de especificação ou suporte sem resolução impedem declarar
uma implementação de produção validada. Nesse caso, G3 deve voltar a G2 ou ficar
inconclusivo, com contraprova mínima e próximo teste útil, sem liberar G4.

G10 exige reprodução externa dos autores após G3. Descobrir dados e código antes
disso é preparação; não constitui execução da replicação nem sua aprovação.
