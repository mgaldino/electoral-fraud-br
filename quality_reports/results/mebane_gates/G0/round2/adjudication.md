# Adjudicação G0, round2

**G0 aprovado no alcance do baseline.** O parecer independente é `pass`, com
`manifest_complete=true` e nenhum achado vigente. O coordenador conferiu as
identidades do manifesto e parecer, os testes independentes, os reparos e a
correspondência entre o lockfile atual e o snapshot.

Manifesto: `f71333db477385fc78dad8a7a1a7ca78e48479226dcdbde80ce97d724409fec7`.
Parecer: `ef624cb4b2d8ad098b87e196d87add358ce1eba93165d44fcc1939ff303f5376`.
Contrato operacional: `e5ba78d6f8d314c2bf94738df85fce0a31d8e9986ef974f6c69ee9e30ee06ca3`.

Os dois achados confirmados e o alcance confirmado do parcial de round1 foram
resolvidos. Isso não torna os achados históricos falsos: suas classificações e
evidências permanecem preservadas. A rechecagem abrangeu 158 arquivos diretos,
22 produtos herdados indiretamente, 37 snapshots e a clausura de 179 pacotes.
Não houve divergências nos checks registrados. Carga de fit/dados, identificação
dos PDFs e comparação do qbl são testes da primeira revisão, reutilizados após
conferência dos hashes inalterados, não apresentados como novas execuções.

A aprovação não demonstra recuperação externa do ZIP, restauração fria do
ambiente, equivalência JAGS–Stan, identificação, convergência ou validade de
inferências. Esses limites são explícitos. G1 e G2 podem começar sujeitos aos
próprios contratos e à checagem de suas entradas.

Durante a revisão, outra atividade acrescentou uma seção ao README sobre
denominadores e uma nota associada. O diff foi inspecionado e preservado. Essa
adição não modifica o snapshot aprovado, não foi avaliada substantivamente
neste gate e não é evidência de aprovação dos denominadores; G1/G2 continuam
responsáveis por essa avaliação.

Veredicto da skill: `NO_CONFIRMED_DEFECTS` no candidato round2. A promoção no
ledger requer ainda o checker mecânico de integridade e dependências.
