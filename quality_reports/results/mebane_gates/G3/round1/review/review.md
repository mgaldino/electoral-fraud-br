# Parecer final independente: G3 round1, revision3

**Status: inconclusive. Produção não validada.** O reparo de forma dos diagnósticos foi confirmado, mas F1/F2 da fonte e o critério congelado de ESS de cauda continuam impedindo a aprovação. Há uma pendência documental independente: sete versões efetivas de código de tentativas antigas não integram o candidato. Portanto, `manifest_complete=false`, apesar de todos os arquivos declarados conferirem.

Revisor: `01a0ee05-aeaf-7492-a8ea-fa731dd6214a`; executor: `01a0ee04-c901-7831-8ac6-0160da2e3883`. QA não participou da implementação nem alterou candidato, fonte ou ledger.

| Identidade revisada | SHA-256 |
|---|---|
| Manifesto revision3, 350 arquivos | `63855471a88dbfc3840b1172aef71118f7cffbdfe425e0241f1d689bf5e67966` |
| Contrato estático G3 | `1b26bbed0577e159a57af93567f14d38d511ea7f26216ca6d5aba22e56a2dacf` |
| Benchmark G2/round2 | `63b61fb0594d0302a03d999bcff6c62967b6e999f37b4c9a8821f0f8e9ed18d2` |
| Fonte integral JAGS | `f8360126424b7a463f76a1c99efc89a8a5cb81339213bd4931559f14595fbab6` |
| RDS revision2, reutilizado sem alteração | `66ddb0aaef7448b25e817e25c931d5608ee9c7141165842613925e9e145baf6d` |

O hash de revision3 foi observado no manifesto congelado e no evento bruto do comando de fechamento do executor, não presumido a partir de uma mensagem. Todos os 350 itens foram conferidos independentemente, assim como o contrato estático e os três vínculos atuais de aprovação G2/round3. O parecer integral de revision2, `review_revision2.json`, SHA `3339732a4e76409136c3fcfea429e0846a23897ac013b273dfbeceaa7a01acf6`, permanece preservado e fundamenta as partes científicas inalteradas deste adendo final.

## Finding aberto

**G3-QA-R2-INPUT-01, major: fechamento histórico incompleto.** Sete versões efetivas de código usadas em cinco tentativas antigas não estão nos manifestos revision2 ou revision3: determinísticos 1/2 e JAGS 1/2/4. A origem é localizável em `revision2/run.json:42`, herdado por `revision3/predecessor_files.json`. `input_closure_revision2.json` e `history_audit.json` identificam cada hash e comando; `revision3_documentary_01/checks.json` confirma a persistência da lacuna.

Os logs estão preservados. Os 321 itens de revision2, os 287 de revision1 e os 116 do candidato original continuam disponíveis por path original ou snapshot byte-idêntico. Não há corrupção desses pacotes. A lacuna antecede seus congelamentos: o código efetivamente executado em cada tentativa não se deduz do path canônico atual. QA reconstruiu esses estados em memória a partir de diferenças dos eventos brutos, sem restaurar arquivos. O reparo documental possível é arquivá-los em paths novos e ligar comandos a hashes, sem nova MCMC. Até adjudicação ou fechamento efetivo, não atesto o histórico completo.

## Reparos verificados

**G3-QA-R2-DIAG-01 / G3-COORD-DIAG-01: resolvido em revision3.** O pós-processador congelado, SHA `00148841e1032f8acfb5b271e28c9789c1063f02e0dfc807caecc4a3c1676a20`, agora passa matriz numérica 2000 × 4 diretamente a Rhat/ESS. A função rejeita array 2000 × 4 × 1, matriz concatenada 8000 × 1 e matriz transposta. O código e o diff completos foram lidos; não há nova amostragem ou mudança de alvo/tolerância.

QA reabriu o RDS, recalculou os alvos e reexecutou o código congelado em seu próprio diretório. Todos os outputs de pós-processamento foram reproduzidos byte a byte. Os 8000 funcionais e os 48 estados exatos são também byte-idênticos aos de revision2. Passaram 55 checks numéricos e 338 checks documentais, além da conferência das 350 entradas do manifesto.

A regressão adversarial do candidato retorna Rhat=1.73364677702875 preservando quatro cadeias e 0.999874992186523 no caminho antigo. Uma fixture independente de QA retorna 1.7325134200315644 contra 0.99987499218652331. O reparo detecta, portanto, uma falha que poderia ocultar desacordo entre cadeias, não apenas uma diferença pequena de arredondamento.

**G3-COORD-DRAW-01: resolvido apenas quanto à persistência autorizada.** A reprodução nova de revision2 salvou quatro cadeias e foi reaberta em outro processo; revision3 usa exatamente esses bytes. Isso não recupera draws históricos, não valida geração irrestrita e não equivale a nova evidência de produção.

**G3-QA-R2-META-01: resolvido nos metadados ativos.** Revision3 classifica os artefatos herdados/QA como inputs, não outputs do executor, e lista seus resultados atuais sem ponteiros ativos obsoletos. Os erros de metadados de revision2 permanecem preservados como histórico, sem reescrita.

## Evidência científica e limites

**F1, suporte probabilístico.** Nas linhas 187–197 da fonte, N=A=1, contagem ativa manufaturada=1, roubada=0, tau=nu=.5 produz m=.999, pA=.0005 e pW=499.5. O evento parental tem massa positiva; o JAGS integral rejeita os pais ativos inválidos testados. Atribuir zero a estados inválidos gera um kernel diagnóstico, não demonstra uma likelihood literal normalizada. Nenhum clamp, redraw ou nova normalização foi aprovado.

**F2, suporte físico.** Em Z=1, N=2, A=1, W=2 e tau=nu=.5, a fonte atribui massa 1/32, apesar de A+W>N. Validade de parâmetros binomiais não garante factibilidade eleitoral. Dobs=1 em N=1,A=0,W=0 continua sendo deslocamento algébrico incompatível com uma margem observada. Flags de capacidade e factibilidade não foram convertidas em aprovação física.

**Likelihood, priors e interface.** Os 87 casos small-N independentes concordam com as implementações do kernel, erro máximo 6.106226635438361e-16; os 29 casos publicados e os 48 estados condicionados reproduzem. Foram conferidos seis priors Exp(5) sobre variâncias, precisões recíprocas, seis efeitos, alpha+b0, ordem parcial de pi, quatro contagens discretas e a transformação .999 da própria fonte. Sentinelas assimétricas verificaram formula1=w/Xw e formula2=a/Xa no limite real do wrapper. A agregação dos funcionais preserva a realização conjunta dentro de cada draw.

**Geração e runtime.** As 32 tentativas do auditor gerativo reproduzem, sem descarte ou redraw oculto; não certificam o gerador diante de F1/F2. Doze probes independentes exercitaram a fonte integral com condicionamentos explicitados, classes ativas/inativas e ausência de respostas rotulada. Sucesso em um probe curto não prova segurança de todas as propostas internas. Dados latentes condicionados não foram tratados como inits. Em verificações aritméticas separadas, três fronteiras racionalmente zero ficam negativas em binary64; continuam numericamente inválidas, sem tolerância ou clamp para validá-las. O NA inicial do auditor era um bug distinto de nomes/indexação em R, documentado e preservado.

**MCSE e diagnóstico.** As 12 médias satisfazem max(1e-3,6MCSE), com o MCSE preregistrado calculado por 40 lotes de tamanho 50 em cada uma das quatro cadeias. Rhat corrigido máximo=1.00120757086769; ESS bulk mínimo=4495.26249801662. S é exatamente zero no suporte condicionado positivo: A=0 implica pW=(1+s)/2 e s ativo=1 torna W=0 impossível. Essa constante usa a exceção analítica já prevista.

Permanecem **nove ESS de cauda indefinidos**, pois indicadores de quantis em átomos discretos são constantes. Isso não demonstra automaticamente falta de convergência, mas também não satisfaz o critério congelado para todos os alvos não constantes. O reparo não substituiu esse critério. Não há validação da hierarquia irrestrita por uma comparação que condiciona efeitos, coeficientes e auxiliares de pi.

**Protocolo e tentativas.** V1, v2 e errata de atribuição à coordenação foram preservados. A cronologia bruta confirma v2 antes dos testes científicos; não foi observada execução científica v1, logo a condição de trocar para seeds 31202:31205 não foi ativada. Permaneceram 31102:31105, quatro cadeias, 200 adapt, 500 burn-in e 2000 pós por cadeia. Reruns anteriores corrigiram código, não alvo/iterações/tolerâncias. Revision3 registra apenas dois processos de pós-processamento/regressão, 1.13 s adicionais, total declarado da rodada 7.59 s; os eventos brutos confirmam suas execuções e zero MCMC nova.

Uma primeira tentativa de QA de reproduzir a regressão a partir do CSV arredondado falhou em um check: erro de coordenadas de cerca de 5e-15 alterava empates usados por estatísticas de ranks. Ela permanece em `revision3_checks_01`. A repetição regenerou a fórmula preregistrada, com a ordem de operações original e as mesmas tolerâncias, e passou 55/55 em `revision3_checks_02`. Nenhum draw bruto ou critério científico mudou.

| Todo | Julgamento |
|---|---|
| G3-T1 | Inconclusive: auditor reproduzível; gerador completo impedido por F1/F2. |
| G3-T2 | Concordância do kernel e do caso condicionado confirmada; alvo integral não validado. |
| G3-T3 | Priors, interface e álgebra conjunta verificadas; validade física/inferencial não estabelecida. |
| G3-T4 | Reparo de diagnóstico confirmado e médias condicionadas concordantes; critério tail ESS não satisfeito, sem equivalência integral entre engines. |

JAGS permanece referência literal de software, não engine de produção aprovada. O Stan histórico não foi validado como portagem exata; não houve ajuste nacional ou replicação externa G10. Não há liberação de G4/G10. A tarefa independente de revisão termina com este parecer; somente a coordenação adjudica os findings e altera o ledger.

Entregáveis: `review.json`, `review.md`, `review_manifest.json` e recibo de validação. O parecer revision2, o finding preliminar, todas as tentativas de QA e as correções delimitadas foram preservados.
