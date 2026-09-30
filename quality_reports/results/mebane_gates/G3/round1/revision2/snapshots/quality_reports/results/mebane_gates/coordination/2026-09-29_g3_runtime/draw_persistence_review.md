# G3-COORD-DRAW-01: persistência das cadeias

O candidato `G3/round1/revision1/candidate_manifest.json`, SHA-256
`4b84fe6996a72321225fd3e5f4713439b77b74fc8a7f039d09e3dcaf7beb72a9`,
informa em `implementation.md` que os draws JAGS não foram salvos. O coordenador
conferiu o código `tests/mebane/likelihood/g3_jags.R`: a amostragem retorna um
objeto em memória, e o script grava estados exatos, CSV de resumos e JSON, mas
não grava o objeto de cadeias. Consequentemente, a QA não pode recalcular MCSE,
diagnósticos e funcionais a partir dos draws que originaram os números salvos.

O defeito é de reprodutibilidade do candidato, independente dos problemas de
suporte do qbl e do diagnóstico para alvos discretos. Reparo seguro: preservar
revision1 e todas as tentativas; acrescentar persistência das cadeias e de seus
metadados; executar uma nova reprodução pequena do protocolo v2 sem mudar
modelo, caso, sementes, adaptação, burn-in, amostragem ou critérios. Registrar
que são draws de uma nova execução, não recuperação das cadeias que não foram
salvas. Recalcular os resumos exclusivamente a partir do RDS reaberto, verificar
identidades por draw e entregar novo candidato ligado ao anterior.

Este encaminhamento não autoriza corrigir F1/F2, mudar o alvo, aumentar a
amostragem para tentar passar o diagnóstico ou considerar os NAs de tail ESS
como prova automática de não-convergência. O candidato revisado ainda exige QA.
