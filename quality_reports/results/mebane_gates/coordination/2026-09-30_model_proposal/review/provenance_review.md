# Parecer independente: suplemento de proveniência

**Resultado:** `pass` documental, restrito à recuperação das **sete identidades históricas** adjudicadas em `G3-QA-R2-INPUT-01`. Não há novo achado nesse suplemento. Há evidência suficiente para a coordenação encerrar esse defeito delimitado. Não foi adjudicado o ledger por esta QA e não se declara fechamento universal dos inputs históricos. G3 permanece **inconclusivo**.

Revisor: `01a0ee05-aeaf-7492-a8ea-fa731dd6214a`. Parecer: `G3-PROVENANCE-QA-20260930-01`, 30/09/2026. O objeto é `provenance_repair/closure_manifest.json`, SHA-256 `b6b56b80a7b40863d34f5f48b1de6641c1c54572121d949e9e6052ec46723965`, com 42 arquivos. O pai permanece revision3, SHA `63855471a88dbfc3840b1172aef71118f7cffbdfe425e0241f1d689bf5e67966`.

## Evidência independente

Passei **914 verificações documentais**, sem executar as fontes R recuperadas. O inventário confere caminho, bytes e SHA de todos os 42 arquivos, dos 350 arquivos herdados de revision3 e dos 419 arquivos do manifesto da QA anterior. Os inputs e os cinco logs copiados coincidem com seus originais. Não há arquivo adicional no pacote fora das exclusões expressas para o próprio manifesto e a verificação destacada.

Reimplementei a aplicação exata dos diffs em memória e reconstruí a sequência a partir de `G3/round1/review/executor_event_sequence.json`, não das conclusões do executor. Obtive os sete hashes esperados, comparei os bytes completos aos snapshots e conferi a linhagem até os cinco comandos afetados. Os 12 comandos temporizados e 21 estados de edição coincidem com o mapa entregue. IDs reais, paths e códigos históricos de saída estão preservados em `documentary_attempt01/recovered_sources.json` e `replayed_event_history.json`.

Li integralmente o reconstrutor e o runner documental. Executei apenas o modo de leitura `verify-seal`, em cerca de 0,13 segundo, capturando novos logs na pasta da QA. Reproduziu as fontes e rejeitou seus controles negativos; a verificação final destacada está vinculada ao hash exato do manifesto. A aprovação não depende apenas desse verificador do executor: os hashes, a reconstrução e o cotejo dos eventos foram feitos separadamente pelo código da QA.

## Limites preservados

`test_ar02_interface.R` continua sem base reconstruível nesta sequência, conforme `report.md`, seção Limites, e `delivery/result.json`, campo `limits`. Está fora dos sete alvos. O mapa cobre entrypoints e a dependência explícita auditada de `R/lib/mebane_model.R`; não inventaria todo o grafo transitivo do runtime. A coincidência dos eventos e hashes não exclui edições não registradas por evidência externa.

Consequentemente, o fechamento positivo vale para o **inventário do suplemento e os sete alvos**, não para todos os inputs de qualquer execução histórica. O manifesto e o parecer anteriores não foram reescritos retroativamente. Falhas antigas continuam falhas: fonte recuperada não é execução aprovada.

Não houve instalação, limpeza, exclusão, restauração, estimação, nova cadeia ou alteração de protocolos, seeds, tolerâncias e fontes canônicas. F1/F2, a ausência de gerador integral validado e os nove ESS de cauda indefinidos permanecem fora deste reparo. Não autorizam produção nem inferência eleitoral.
