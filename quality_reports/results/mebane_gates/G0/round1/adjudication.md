# Adjudicação G0, round1

**Decisão: correções autorizadas, gate não aprovado.** Manifesto revisado:
`61649af333a6d2ef6bea20e4ed5e38671bb6d6d5f2b867fbe1d9acdc195169ab`.
Parecer independente:
`0396d243250471cdf9db8e4c0ea8f80cf0bbe9830ddd4629feb0dec2ddb175b0`.
O contrato operacional permanece vigente. Esta revisão de inventário não
requer contrato de argumento de manuscrito.

| Achado | Adjudicação | Encaminhamento seguro |
|---|---|---|
| G0-R1-F1 | CONFIRMED | Incluir snapshots do manuscrito e das quatro tabelas efetivamente citadas, sem alterá-los ou recalculá-los. |
| G0-R1-F2 | CONFIRMED | Acrescentar os seis registros de pacotes já instalados, conferir a clausura dos scripts e preservar os registros anteriores. Sem instalação ou restore. |
| G0-R1-F3 | PARTIAL | Retirar a promessa de reconstrução exata por download genérico. Documentar que a aquisição externa histórica não foi reconstruída e que o ZIP íntegro está disponível localmente. |

O coordenador conferiu os trechos citados e verificou em R que `diptest`,
`spikes`, `bbmle`, `bdsmatrix`, `emdbook` e `plyr` estão instalados mas ausentes
do lockfile do candidato. `inventory.py` omite tabelas e manuscrito, embora
`claims.md` use as tabelas como evidência. Os comandos e localizadores estão
no JSON adjacente.

O terceiro achado não autoriza inventar URL/data nem afirmar que o ZIP é
irrecuperável em qualquer outro lugar: `sources.md` já reconhece a lacuna e
há cópia local íntegra. O problema confirmado é a receita do README que
promete reconstruir os mesmos bytes por downloads não versionados. Corrigir
essa receita basta para tornar o limite explícito; G1 terá de verificar sua
própria proveniência e os controles oficiais.

Preservar round1, preparar round2 e obter rechecagem independente. Nenhum
achado epistemicamente não resolvido ou decisão nova de estimando foi
identificado; os três reparos ainda estão pendentes. Veredicto da skill:
`READY_FOR_IMPLEMENTATION`, não aprovação técnica do gate.
