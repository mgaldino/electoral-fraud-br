# Preparação D.C. 2010: histórico local

- `run-20260930T234951Z-pid61383`: primeira tentativa, preservada. O CSV, RDS e manifesto foram gerados e o teste R passou, mas `SHA256SUMS` usou um separador inválido (um espaço). `shasum -a 256 -c SHA256SUMS` recusou o arquivo. **Substituída; não usar como candidato.**
- `run-20260930T235038Z-pid61600`: candidato revisável. O teste R e `shasum -a 256 -c SHA256SUMS` passaram. Os hashes e comandos exatos constam do manifesto deste run.

O `executor_id` real de ambos os runs é `01a0f4b5-4434-7b83-91b9-69ced11b40ba` (ID da tarefa retornado por `get_goal`/`create_goal`). O identificador não constava dos manifestos ou logs originais, que permanecem intactos. O atestado aditivo [verification_2026-09-30.log](verification_2026-09-30.log), SHA-256 `12da7e344ac5f6bc0bbba33647876a4e61a82a5161c49c16cf746ce42423f4bd`, associa o executor, os comandos e a verificação atual a cada `run_id`.

- Primeira tentativa: a [fonte histórica do script](historical_sources/run-20260930T234951Z-pid61383/prepare_dc2010.R) tem SHA-256 `4696f938688dc42b0a8574c6c9c289407fefee7a38c67e1cc12e7c436b611c8e`; a [fonte histórica do teste](historical_sources/run-20260930T234951Z-pid61383/test_dc2010.R) tem `a33745f6d979334912a2dd11b169d2cd9ae9161185a80a874e8d70a10fec9662`. Ambos coincidem byte a byte com os hashes do primeiro manifesto.
- Candidato: o script atual tem SHA-256 `051f0421448bd349ffdfa9a668ac78ac22bccc09bf4b8ff5718cd80c7e788313` e o teste atual `70039df8c8597e96f26ad837c8467a69ea97ae71362f68080f0cd0dbecddf1ca`. Ambos coincidem com o segundo manifesto. Nos dois runs, os seis hashes de entrada e três de saída foram conferidos em 30/09/2026.

Nenhum dos runs executou estimação, MCMC ou aprovou gate. O primeiro run não foi apagado nem sobrescrito.
