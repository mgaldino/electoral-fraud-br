# AD-4: preparação da revisão independente de resultados

Status: **em andamento; aguardando aviso de persistência da execução e comparação**. Este arquivo não é parecer final, aprovação dos resultados ou encerramento do goal.

Revisor: `01a0f4b8-962b-77a3-a418-6247c6219e8b`. Executor: `019d795a-acfa-72c2-a210-d55a46c606c2`.

## Restrição Durante o Piloto

Somente leitura estática do comparador e de seus testes, registro de hashes e preparação textual/código de checagens. Não carregar draws, executar testes, recalcular diagnósticos, monitorar intensivamente arquivos em escrita ou iniciar MCMC. Todos os novos arquivos desta revisão ficam em `review_results/`. O usuário avisará quando execução e comparação estiverem persistidas.

## Leitura Estática Inicial

- `compare_runs.R:23-40` carrega resultados persistidos e confere hashes dos manifests disponíveis e logs do supervisor. Na revisão final será conferido o vínculo desses artefatos aos raw, à release e ao contrato; verificar um hash local não substitui conferir a identidade do input de cada modelo.
- `compare_runs.R:41-50` exige sucesso dos processos de geração/diagnóstico e status de execução, mas recebe o status de precisão do produtor dos diagnósticos. A revisão independente recalculará os checks necessários e comparará contagens de reprovação/NA antes de aceitar o status pareado.
- `compare_runs.R:52-84` mantém fases internas separadas dos dois processos externos. End-to-end é geração externa + diagnóstico externo, sem somar novamente as fases internas. Há denominadores distintos de geração interna, geração externa, amostragem e end-to-end.
- `compare_runs.R:51,67-69` calcula extremos somente entre valores finitos. Conferir nos resultados quantos dos 23 globais são finitos, para interpretar corretamente a tabela e impedir que um extremo parcial seja apresentado como aprovação dos alvos indefinidos.
- `compare_runs.R:119-159` diferencia execução, precisão, médias amostrais e inferência; também distingue DC2010 de Brasil, os funcionais M/S das contagens secundárias D e o mesmo caso de uma replicação numérica externa. A avaliação final será sobre o relatório realmente gerado, inclusive eventuais edições posteriores.
- `test_comparison.R:11-60` contém quatro cenários sintéticos de estado e aritmética de denominadores. Seu caso positivo tem cinco linhas de tabela e contagens declaradas simplificadas; testa a agregação de status, não a integridade dos 2171/1742 alvos nem a extração dos raw. Essa cobertura complementar já está prevista abaixo, sem transformar simplificação de fixture em achado científico.

Nenhuma conclusão sobre resultados foi emitida nesta etapa. Pontos a conferir não são findings confirmados. A fonte entregue ao fim será vinculada por hash e comparada à leitura inicial; não será presumida idêntica.

## Checagens Após o Aviso

1. Fixar fontes e artefatos finais com SHA-256: release consumida, contrato v2, inputs reais/inits/metadata, fonte A literal, fonte D, raw, run_result, supervisores/logs, diagnósticos, comparação e relatório. Validar a cadeia de manifests e registrar se houve mudança do comparador após esta leitura.
2. Conferir identidade das 143 unidades, ordem e dados A/D, parâmetros de execução, quatro chains, 2000 iterações retidas e adaptação. Tratar falhas/ausências como incompletude, não presumir duas execuções bem-sucedidas.
3. Recalcular independentemente os 23 globais em matrizes iteração × cadeia: pi[1:3], seis alpha, seis variâncias, seis b0 e M/S. M e S usam Z do mesmo draw; A preserva frações auxiliares e endpoint .999, D usa magnitudes contínuas. Confrontar médias, SD, quantis, médias por cadeia, R-hat, ESS bulk/tail e MCSE com tabelas persistidas.
4. Conferir o universo obrigatório completo, nomes únicos, grupos e contagens 2171A/1742D. Reavaliar decisões v2 a partir das métricas de todas as linhas, contagens de falhas/indefinições e critério conjunto de execução/adaptação. NA obrigatório não passa; secundárias não resgatam precisão. Não repetir a auditoria matemática nem recalcular indiscriminadamente todos os diagnósticos locais já validados no preflight.
5. Conferir contagens condicionais D persistidas quanto a dimensões, identidade das unidades, suporte, inteireza e agregação; mantê-las separadas de M/S esperados e da comparação de estimandos A/D.
6. Reconciliar tempos dos supervisores e fases internas. Verificar cada denominador ESS/s com a tabela-base correta e a soma de geração + diagnóstico, sem dupla contagem, sem atribuir custo da fila ou da revisão aos modelos. Não ranquear eficiência como validada se a precisão não passou.
7. Conferir números, rótulos, narrativa, tabelas e, se fornecido, PDF final. Status inconclusivo deve acompanhar médias brutas e limitações de precisão; nenhum salto para fraude observada, identificação validada, G3/G10 aprovado ou reprodução de saída externa inexistente.
8. Entregar `review.json` e `review.md` vinculados aos hashes finais, com findings reais, severidade, evidência por linha/artefato e limitações. O goal AD-4 só será concluído após essa entrega, não com esta preparação.

Não haverá nova MCMC, instalação, exclusão, mudança de limiar, calibração de potência ou nova auditoria histórica. Aprovação de etapas anteriores é evidência delimitada, não aprovação automática do resultado final.
