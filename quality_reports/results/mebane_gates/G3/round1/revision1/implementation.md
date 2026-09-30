# Adendo ao candidato G3 round1

Este pacote `revision1` substitui somente o **manifesto do candidato** e a
classificação da degenerescência no teste condicionado. O manifesto inicial
da raiz de round1, seus logs e suas saídas são preservados como histórico.
Seu único caminho canônico que mudou foi `tests/mebane/likelihood/g3_jags.R`;
os bytes antigos foram reconstruídos em
`snapshots/root_candidate_old/tests/mebane/likelihood/g3_jags.R` e conferidos
contra hash e tamanho do manifesto inicial, como registra `old_code_mapping.json`.
O manifesto inicial sozinho não preservava esses bytes. Protocolo v2, seeds,
iterações e limiares permaneceram intocados.

Na tentativa 3, `S` foi incorretamente marcado não constante por incluir
estados de peso posterior zero na verificação de degenerescência. A tentativa
4 corrigiu essa classificação, mas o serializador de status encontrou NA ao
agregar diagnósticos ausentes. A tentativa 5 usa `is.na` para marcar esses
diagnósticos como não aprovados, enquanto `S=0` no suporte positivo recebe
checagem analítica sem Rhat/ESS. O resultado continua **inconclusivo** porque
`ess_tail` é NA para outros alvos discretos. Todos os alvos tiveram média
dentro da tolerância MCSE congelada, e nenhuma inferência física/nacional é
autorizada. Ver `../g3_jags_attempt4.log`, `../g3_jags_attempt5.log`,
`../jags_attempt5/conditional_comparison.csv` e `../jags_attempt5/comparison_result.json`.

A errata de proveniência identifica o coordenador como autor do preflight.
`Dobs=1` é apenas offset algébrico; a flag de compatibilidade observada é
falsa e não se declara contrafactual físico válido. A fonte de votos stolen
e a capacidade de origem não foram verificadas; as flags existentes são
necessárias, não suficientes. O gate não está fechado e não foi promovido.
Os draws JAGS brutos não foram salvos pelo harness em nenhuma tentativa; só
estados exatos, resumos por alvo, probes e logs permanecem. Por isso não se
afirma que a QA possa recalcular MCSE a partir dos draws desta rodada. Essa
lacuna de artefato é uma limitação adicional do candidato.
