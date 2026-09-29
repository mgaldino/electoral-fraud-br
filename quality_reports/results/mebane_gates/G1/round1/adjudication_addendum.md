# Adendo de adjudicação G1 round1

**G1-R1-COORD-F03: CONFIRMED, major; READY_FOR_IMPLEMENTATION.**
O helper em `R/lib/mebane_data.R:167` verifica apenas controles dos candidatos
13 e 22. A contraprova independente do coordenador, em
`adjudication_candidate_controls.R/.csv`, configura candidato 12 elegível
com um voto e verifica que controle 999 é aceito. O hash do helper coincidiu
com o manifesto original após a execução.

Reparo autorizado: iterar e validar todos os controles de candidato declarados
na configuração, com regressões para candidato diferente de 13/22 e controle
incompatível. Não escolher candidato de 2026 nem alterar dados ou estimando.
Este achado não nega os agregados de 2022 já conferidos; impede certificar
a interface genérica prometida por G1. Não substitui F01/F02 ou a adjudicação
anterior. Os três achados deverão ser rechecados independentemente em round2.

O JSON deste adendo vincula o CSV da contraprova por SHA-256. O exit 0 do
script comprova reprodução da falha e não sucesso do pipeline.
