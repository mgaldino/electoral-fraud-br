# Implementação experimental D: tentativas de preflight

Executor: `01a0f4b5-4434-7b83-91b9-69ced11b40ba`. Contrato usado: `AD-DC2010-v2`, SHA-256 `d17b7f508a7ce87eec3ca71ed7df67666b528c755e005ec9e1299e5ff9deb509`.

- `attempt-20261001T001017Z-01a0f4b5`: falha no teste ao converter o objeto de versão de JAGS com `as.numeric()`; nenhuma verificação matemática executada.
- `attempt-20261001T001117Z-01a0f4b5`: grid passou; teste de fronteira falhou por omitir `prob=` em `dmultinom()`.
- `attempt-20261001T001159Z-01a0f4b5`: matemática e auditoria estática passaram; comparação da interface de dados falhou por atributos de nomes de linha.
- `attempt-20261001T001241Z-01a0f4b5`: preflight completo passou; preservado e substituído por checagens ampliadas de hash e prioris.
- `attempt-20261001T001402Z-01a0f4b5`: preflight ampliado passou; preservado e substituído por fixture JAGS com interceptos `b0` não nulos.
- `attempt-20261001T001549Z-01a0f4b5`: **candidato revisável**. Grid, fronteiras, massa condicional conjunta, covariância, mistura, auditoria de prioris, hashes e confronto JAGS condicionado passaram. Ver `manifest.json` e `test.log` neste diretório.

Cada tentativa teve snapshot dos arquivos consumidos antes do teste. Nenhum diretório, log ou manifesto anterior foi apagado ou sobrescrito. O confronto JAGS condicionou todos os nós estocásticos em três linhas sintéticas e amostrou apenas nós determinísticos por uma iteração; não é piloto empírico nem ajuste posterior de D.C. 2010. Diagnósticos de cadeias, decisão do contrato v2 e runner pertencem ao coordenador. Este preflight não aprova gate.
