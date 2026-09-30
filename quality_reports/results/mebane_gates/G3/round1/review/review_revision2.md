# QA-FIDELIDADE G3: revision2

**Parecer: inconclusive. Produção não validada.** O candidato contém evidência delimitada de fidelidade numérica, mas F1/F2 continuam impedindo um gerador literal validável e nove diagnósticos de cauda não satisfazem o critério congelado. Há também defeitos reparáveis do pacote, separados abaixo. Este parecer preserva revision2; o goal permanece ativo até revisar revision3.

Revisor independente: `01a0ee05-aeaf-7492-a8ea-fa731dd6214a`. Executor: `01a0ee04-c901-7831-8ac6-0160da2e3883`.

| Vínculo | SHA-256 |
|---|---|
| Manifesto revision2, 321 entradas | `de779221e40964b9729bdd928a814e7e7dfd9738df866b91f6ee97307a14bd0f` |
| Contrato estático G3 | `1b26bbed0577e159a57af93567f14d38d511ea7f26216ca6d5aba22e56a2dacf` |
| Benchmark G2/round2 | `63b61fb0594d0302a03d999bcff6c62967b6e999f37b4c9a8821f0f8e9ed18d2` |
| Fonte integral JAGS G0 | `f8360126424b7a463f76a1c99efc89a8a5cb81339213bd4931559f14595fbab6` |
| RDS bruto revision2 | `66ddb0aaef7448b25e817e25c931d5608ee9c7141165842613925e9e145baf6d` |

Os três vínculos de aprovação vigente de G2/round3 foram conferidos. Os indicadores históricos do contrato G2 não substituem essa aprovação. O relatório JSON contém os hashes completos e os resultados por todo.

## Findings reparáveis

**G3-QA-R2-DIAG-01, major, confirmado; alias G3-COORD-DIAG-01.** Em `revision2/snapshots/tests/mebane/likelihood/g3_draw_postprocess.R:87`, um `draws_array` é passado às funções escalares de `posterior`. A coerção transforma quatro cadeias de 2000 draws em uma cadeia de 8000, antes do split. Os onze diagnósticos não constantes publicados reproduzem esse caminho errado. Para N.iota.s, Rhat correto é 1.00120757086769, não 1.00020832622997. Reparo seguro: matriz numérica 2000 × 4 diretamente nas funções, regressão determinística adversarial e novo pós-processamento do mesmo RDS, sem MCMC. Detalhes e código em `review_diagnostic_preliminary.json/md` e `diagnostic_shape_counterexample/`.

**G3-QA-R2-INPUT-01, major, confirmado.** Os 321 hashes e tamanhos conferem, mas isso não fecha todas as entradas efetivamente usadas. Sete versões de código de cinco execuções históricas não constam do manifesto: determinísticos 1/2 e JAGS 1/2/4. Logs e bytes declarados pelos candidatos original e revision1 estão preservados; o antigo `g3_jags.R` congelado foi recuperado com hash correto. A lacuna é anterior a esses congelamentos e foi localizada reconstruindo diferenças de eventos brutos, sem usar conclusões do implementador. `history_audit.json` e `input_closure_revision2.json` discriminam os hashes. O fechamento pode ser reparado por novos snapshots e mapas comando/hash, sem reexecutar ou restaurar canônicos. Até lá, `manifest_complete=false`.

**G3-QA-R2-META-01, minor, confirmado.** A coleta recursiva em `revision2/build_candidate.py:82` classifica 198 paths de QA independente como outputs do executor. O `run.json` ainda aponta `comparison_result` para jags_attempt5 e `todo_evidence` para revision1, embora os arquivos novos estejam presentes. Classificação e ponteiros devem distinguir evidência independente, resultado atual e histórico. A inclusão por hash não transfere autoria nem demonstra execução pelo implementador.

## Evidência e limites

**Suporte da fonte.** A expressão literal, linhas 187–197 do JAGS, dá pA=0.0005 e pW=499.5 em N=A=1, m=.999, s=0, tau=nu=.5, classe ativa de fraude. Esse evento parental tem massa positiva e o JAGS integral rejeita pais ativos inválidos. F1 permanece. Separadamente, Z=1, N=2, A=1, W=2 tem massa 1/32, apesar de A+W>N: F2 permanece. Zerar estados inválidos define um kernel diagnóstico, não prova likelihood normalizada. Os problemas exigem decisão substantiva em G2, não ajuste silencioso da implementação.

**Enumeração e gerador.** Os 87 casos independentes N=1,2,3 concordam com as duas implementações do kernel, erro máximo 6.106226635438361e-16; os 29 casos publicados e os 48 estados conjuntos condicionados reproduzem. As 32 tentativas do auditor gerativo reproduzem com seed 31101 e sem redraw/clamp adicional, mas terem sido válidas não certifica o gerador. Em 792 casos aritméticos separados, há 108 pais exatamente inválidos e três fronteiras racionalmente zero que ficam negativas em binary64. Nenhuma tolerância tornou p fora de [0,1] válida. O NA do primeiro determinístico era outro problema: nomes herdados dos vetores R quebravam a indexação; a correção é observável no diff preservado.

**Fonte integral e probes.** Doze ensaios independentes usaram o arquivo integral inalterado, com condicionamentos explicitados. Pais ativos inválidos falharam; os componentes inativos inválidos testados não invalidaram a soma ponderada. As quatro contagens continuam no grafo. Estados livres foram atualizados, mas propostas internas não foram observadas. Ausência de a/w foi rotulada. Um ensaio curto bem-sucedido com respostas ausentes não certifica geração irrestrita.

**Priors, interface e funcionais.** Conferidos Exp(5) sobre seis variâncias, suas precisões recíprocas, seis efeitos, alpha+b0, quatro contagens discretas, transformação .999 da própria fonte e ordem parcial pi1>=max(pi2,pi3), sem impor ordem entre pi2 e pi3. O wrapper efetivo alimenta formula1=w/Xw e formula2=a/Xa; sentinelas assimétricas foram verificadas no limite real de entrada do runjags, e os corpos das funções instaladas comparados aos arquivados. A agregação conjunta é feita dentro de cada draw, preservando Z e a dependência entre funcionais. Dobs=1 em N=1,A=0,W=0 é deslocamento algébrico incompatível com margem eleitoral observada; flags de capacidade/factibilidade não autorizam um contrafactual físico.

**Persistência: G3-COORD-DRAW-01 resolvido no escopo autorizado.** O RDS contém quatro cadeias de 2000 draws, seeds 31102:31105, 200 de adaptação, 500 burn-in e thin=1. Uma reprodução nova, declarada, foi salva e reaberta por outro processo. QA reabriu os mesmos bytes e refez os 8000 funcionais, os 48 estados e todas as médias/MCSE. Isso resolve persistência para a reprodução nova; não recupera draws históricos nem resolve DIAG-01.

**MCSE e constantes.** O MCSE congelado combina corretamente as variâncias das médias de quatro cadeias, com 40 lotes de 50 draws por cadeia. As 12 médias satisfazem max(1e-3,6MCSE). Para M: exato 0.0964248170254317; média 0.0939684375; MCSE 0.00254792161217076; tolerância 0.0152875296730245. S é exatamente zero no suporte condicionado positivo: A=0 implica pW=(1+s)/2; s ativo=1 torna W=0 impossível. A classificação constante correta já estava prevista no protocolo, sem mudança de alvo.

**Diagnósticos não são aprovação.** Recalculando corretamente as quatro cadeias, Rhat máximo=1.00120757086769 e ESS bulk mínimo=4495.26249801662. Permanecem nove ESS tail indefinidos porque indicadores de quantis em átomos discretos são constantes. Não são prova automática de não convergência, mas o critério congelado de todos os alvos não constantes não foi satisfeito. Nenhum critério substituto foi aceito. Os indicadores explicativos iniciais de QA baseados em igualdade de massa a 1 foram corrigidos estruturalmente em uma contraprova nova, preservando os primeiros outputs.

**Preregistro, reruns e conservação.** Eventos brutos de comandos e alterações mostram v2 antes de todos os testes científicos; v1 foi preservado e não há execução científica v1. Por isso não se ativou a condição para usar seeds 31202:31205. A errata atribui corretamente o preflight à coordenação sem reescrever v2. Tentativas 4/5 corrigem constante no suporte positivo e propagação de NA no status; não alteram seeds, alvo, iterações ou tolerâncias. Os 12 comandos têm logs/exit codes, total declarado 6.46 s e máximo 0.81 s, compatíveis com os eventos observados. Nenhuma nova MCMC foi executada por QA para revisar o RDS.

## Julgamento por todo

| Todo | Parecer e escopo |
|---|---|
| G3-T1 | Inconclusive: auditor reproduzível, mas gerador completo impedido por F1/F2. |
| G3-T2 | Inconclusive no alvo integral; concordância do kernel diagnóstico e do caso condicionado confirmada. |
| G3-T3 | Verificações locais de prior/interface/álgebra confirmadas; validade física e produção não estabelecidas. |
| G3-T4 | Inconclusive: médias condicionadas concordam; defeito de diagnóstico reparável e critério tail ESS não satisfeito. |

JAGS pode continuar como referência literal de software. Não houve validação do Stan histórico como equivalente, portagem Stan exata, ajuste nacional ou replicação externa G10. Não há liberação de G4/G10. O próximo passo permitido é conferir revision3, apenas pós-processamento/proveniência, mantendo as decisões F1/F2 retidas. QA não alterou candidato, fonte, contrato ou ledger; somente a coordenação adjudica.

Evidência preservada: `revision2_integrity/`, `revision1_math/`, `revision2_diagnostics/`, `diagnostic_shape_counterexample/`, `history_audit.json`, `executor_event_sequence.json`, `input_closure_revision2.json` e a preparação congelada anterior. Os resultados originais de testes de QA que falharam, bem como suas correções delimitadas, não foram apagados ou sobrescritos.
