# Adjudicação G7 round1

**changes_requested; READY_FOR_IMPLEMENTATION para reparos seguros.**

Candidato e QA íntegros: 275 + 809 arquivos conferidos. Dois defeitos materiais e uma omissão de escopo confirmados.

## G7-R1-COORD-F03

A coordenação reproduziu a rejeição do UTF-8 válido e a QA confirmou com arquivos próprios, controle ASCII e comparação de bytes. read.csv(fileEncoding='UTF-8') converte para o locale C. O contrato promete CSV UTF-8, portanto a falha é material. Reparar a leitura sem alterar locale global, preservar o nome exato e rejeitar bytes inválidos.

## G7-R1-QA-F01

Código e contraprova própria confirmam que 03/10/2022 é aceito como T1, embora a data correta do fixture seja 02/10/2022. A data deve ser ancorada por turno. O calendário TSE arquivado documenta 04/10/2026 e eventual 25/10/2026; fixar a data condicional de T2 não presume sua ocorrência nem seu código de eleição.

## G7-R1-QA-F02

O recibo omite abrangência e chama complete à completude relativa aos EA16 fornecidos. Uma única seção recebe complete=true. Isso não é aprovação nacional: ambas as flags de liberação continuam falsas. Confirmado somente como omissão de escopo/denominador; corrigir nomes/metadados e declarar UFs esperadas, sem fingir que presença de UFs prova cobertura nacional.

## Encaminhamento

Preservar fontes e fixtures anteriores; reparar somente UTF-8, data ancorada por turno e escopo territorial/completude. Criar round2, repetir regressões afetadas e obter revisão independente. G7 não é data-ready/inference-ready real. Não alterar G1/G2 ou seu alvo.
