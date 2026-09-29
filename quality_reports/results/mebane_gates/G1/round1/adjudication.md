# Adjudicação G1 round1

**READY_FOR_IMPLEMENTATION**, sem aprovação do gate. Candidato
`009e0fd39f8ab495e52fcb214476fcc7b6095f895381006a924df6a2ffbd7003`, parecer
`5702f2bf4dd306bdfb7af86e81477faceecd54a4b3b4024cdfdf1d048b5d2c5f`.
Os 53 arquivos declarados foram novamente conferidos por hash e tamanho.
O contrato operacional G1 permanece o mesmo; não há contrato de argumento
de manuscrito aplicável à revisão de código e dados.

| Achado | Decisão | Evidência | Reparo autorizado |
|---|---|---|---|
| G1-R1-QAD-F01 | CONFIRMED, major | O coordenador reproduziu a aceitação de código 999 e data de 2020 em ambas as fontes, com controles numéricos ativos. | Vincular código, data e tipo esperados à configuração por turno; regredir casos concordantes porém errados; reexecutar 2022. |
| G1-R1-QAD-F02 | CONFIRMED, major | O congelador lê o ledger mutável, omitido do run e do manifesto. | Consumir entrada estática vinculada ou snapshot imutável do ledger; declarar insumos e comando em nova rodada. |

Comandos e resultados: `adjudication_checks.R/.csv` e
`adjudication_integrity.py/.json` nesta pasta. Os exits 0 dos testes de
contraprova significam que os defeitos foram reproduzidos, não que foram
reparados. Nenhum arquivo do candidato foi modificado nesta adjudicação.

Os controles independentes de totais e a reprodução byte-idêntica permanecem
evidências positivas delimitadas. Não resolvem a validação de identidade
eleitoral nem autorizam inferência. A correção não exige escolher nova
especificação estatística, alterar brutos ou instalar componentes.

O executor deve preservar esta rodada e guardar cópias dos fontes anteriores
antes de editá-los, com mapeamento aos hashes revisados. Round2 receberá novos
manifesto, testes e parecer. Os dois achados estão pendentes de reparo, mas
nenhuma classificação permanece UNRESOLVED. O registro JSON é a referência
autoritativa desta adjudicação.
