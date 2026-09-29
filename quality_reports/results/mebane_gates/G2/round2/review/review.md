# Parecer independente G2 round2

**Status: `inconclusive`. O fechamento metodológico de D1–D3 passou no escopo do benchmark literal, mas a integridade completa da dependência G0 mudou durante a revisão.** Nenhum defeito material novo foi encontrado nas decisões, na interface documentada ou nos funcionais. Não há aprovação inferencial, de G3, de Stan exato ou do projeto como um todo.

Revisor/goal: `01a0ed49-99a4-7892-af77-e62f82667860`, QA-MÉTODO independente, sem participação na implementação. Executor: `01a0eaee-01df-7773-bd63-d321db26a47c`. Escritas restritas a este diretório `review/`; nenhum candidato, fonte, ledger, produção, renv ou resultado antigo foi alterado pelo revisor.

## 1. Achado e condição de assinatura

### G2-R2-QA-I1: dependência G0 perdeu um arquivo durante a QA

**Severidade major, fato CONFIRMED; efeito científico não demonstrado.** O manifesto congelado `G0/round2/candidate_manifest.json:792` inclui `ssrn-4073770.pdf.download/ssrn-4073770.pdf`, 1360 bytes, SHA-256 `524dc82c59612ec91b3a6ab475dd34f0607546a37823c9a9b1fd652677a8acdf`.

Em 29/09/2026, 13:13:46 UTC, esse arquivo existia e o hash conferia. Em 13:19:25 UTC, estava ausente. `ls` confirmou que a pasta `.download` não existe, e `git status` mostra remoção dos dois arquivos rastreados nessa pasta. A QA não realizou a remoção. Os registros próprios `integrity_initial.json` e `integrity_final.json` preservam a mudança observada.

A materialidade é delimitada: G0 já classificava esse PDF como `invalid_or_incomplete` em `G0/round1/inventory.json:610`. Ele não é fonte científica de G2, nem integra os 163 arquivos diretos do candidato G2. O literal JAGS, a interface, contratos, aprovação congelada G0 e evidência matemática de round1 permanecem íntegros. A ausência não constitui contraprova de D1–D3. Ainda assim, não posso atestar a recuperabilidade integral do manifesto G0 aprovado depois da alteração concorrente, nem tratar uma mudança de proveniência como autorização automática para desconsiderar um item.

**Encaminhamento restrito:** a coordenação deve registrar o tratamento autorizado do arquivo removido e reconciliar a dependência. Depois basta uma checagem de integridade/vínculo direcionada. Não é necessário reabrir a matemática, repetir round1 ou mudar as decisões D1–D3 por causa desse arquivo. Foi perguntado ao usuário se prefere o registro `inconclusive` ou aguardar essa regularização; nenhuma restauração foi feita por iniciativa do revisor.

## 2. Identidade, autorização e preservação

Os seguintes hashes completos foram recalculados, sem uso do ledger mutável:

| Objeto | SHA-256 |
|:--|:--|
| Manifesto do candidato | `5c4b39aaa1c2a273b1c7f4e9370291172d35d0f4a5a17afd079396c3a1984170` |
| Contrato do benchmark, bytes do arquivo | `63b61fb0594d0302a03d999bcff6c62967b6e999f37b4c9a8821f0f8e9ed18d2` |
| Contrato estático G2, JSON canônico | `f834bc1d12d88b4bc82fb2ada95120a838451c5809332630a75cd9abf03cf4d1` |
| Run congelado | `a549043d82fa34856e56148d233037e761ca8f0c57a0b1f1af9d955ec959d359` |

O JSON canônico usa UTF-8, chaves ordenadas, `ensure_ascii=false` e separadores compactos. Seu hash não deve ser confundido com o hash dos bytes indentados do arquivo. O contrato estático é igual ao de round1 e exige apenas G0. Manifesto, parecer e adjudicação congelados de G0 concordam entre si, inclusive nos hashes de candidato e contrato; a única divergência final é o arquivo ausente descrito acima.

Todos os **163 arquivos diretos de G2 conferem**. Os campos `inputs`, `code`, `configuration`, `outputs` e `executed_code` do run estão cobertos pelo manifesto. A recuperação histórica foi conferida com substituição somente do antigo appendix pela cópia `inherited/appendix_round1.md`; não houve restauração sobre o documento atual. Foram preservados os manifestos antigos, a classificação histórica `changes_requested` e as três decisões CONFIRMED.

A frase de autorização está congelada no contrato do benchmark, cujo hash é vinculado pelo run. O arquivo externo `coordination/2026-09-29_benchmark_round/authorization.md` **não consta dos inputs do run**; não atribuo a ele um congelamento que o run não fez. A QA confrontou a frase e congelou o arquivo em `snapshots/authorization.md`. O pedido atual também confirma explicitamente a autorização. Os arquivos de orientação consultados receberam snapshots próprios; o ledger não foi lido como evidência decisória.

`candidate_manifest_complete=true` refere-se aos inputs e artefatos diretos conferidos. O campo geral `manifest_complete=false` é conservador diante da ausência posterior de um input da dependência G0. O `review_manifest.json` explicita o hash inicial e a ausência atual, em vez de esconder esse item.

## 3. Fechamento de D1–D3

### D1: reprodução literal de software

A escolha do usuário resolve a pendência de alvo para este benchmark: commit `3017de537450f97a01872d0157462a68bea348ee`, JAGS 4.3.2 requerido, sem tratar o software como gerador físico certificado. O literal foi confrontado com a função primária `qbl()` extraída sem executar o arquivo inteiro. As quatro Binomiais latentes, N tentativas nas duas respostas, dependência de A observado e átomo manufactured de 0,999 permanecem.

O contraexemplo mínimo continua produzindo `pW=499.5` algebricamente; um controle válido produz `0.4625`. Nenhum desses cálculos informa o comportamento runtime do JAGS. Clamp, normalização, piso de denominador e repetição até validade continuam proibidos. Falhas e todas as tentativas devem ser preservadas em G3. As limitações F1/F2 não foram refutadas ou corrigidas por esta escolha.

### D2: priors e desenho do primeiro harness

Foram confrontados diretamente os seis blocos na fonte: variâncias Exp(5), precisão `1/v`, alpha normal com variância 1, coeficiente fixo de intercepto com variância `1e-4`, demais coeficientes com variância 1 e seis efeitos por observação. Os preditores usam `beta.*1`, conservando `alpha+b0`; o vetor reportado `beta.*` não substitui esses preditores.

A ordem é parcial, `pi1>=max(pi2,pi3)`; um exemplo com `pi3>pi2` continua admissível. As seis matrizes do primeiro harness têm uma coluna de uns e dimensão de coeficientes igual a 1, sem eliminar a hierarquia. Testes com covariáveis distintas serviram somente à fidelidade da interface. Não selecionam dummies, contrastes ou geografia de produção, que exigem apreciação em G4 antes de G6.

### D3: distribuição conjunta dos funcionais

Um oráculo escalar próprio, sem importar a álgebra ou os testes do executor, recalculou as oito linhas sintéticas e quatro totais. Usou `M=N*m*(1-tau)` e `S=N*s*tau*(1-nu)`, selecionando magnitudes pela classe e impondo zero em Z=1. O átomo 0,999 foi aplicado apenas a manufactured. Magnitudes de classes inativas não alteram o funcional. Resultados fracionários são preservados, sem ruído binomial adicional.

No primeiro draw, M=8 e S=3; agregando as duas unidades, Dobs=12 dá limites de margem -2 a 1. O terceiro draw tem M=55,944 e S=27,8 e é marcado inviável para a reconstrução necessária, sem exclusão. Os limites `Dobs-M-2S` e `Dobs-M-S` foram conferidos também pela contabilidade separada dos votos do líder e do segundo colocado fixado, variando a fração stolen proveniente deste último. A capacidade de origem permanece desconhecida, não inventada.

Exemplos próprios confirmam que somar quantis não equivale ao quantil do total e que a distribuição completa `(0,0,0,8)` tem média 2 e variância populacional 12, enquanto guardar apenas sua média condicional elimina essa variância. Médias condicionais podem estimar médias posteriores, mas seus quantis não substituem os do funcional completo. Não foi identificado vencedor contrafactual pontual.

### Interface e fronteira G3

Foi executado **somente o trecho primário de formação das matrizes/respostas**, mais a função pura `getRegMatrix`, em ambiente sintético que encerra antes de qualquer chamada de engine. Uma sentinela assimétrica diferente da do executor confirmou `formula1 → w/Xw` e `formula2 → a/Xa`; respostas deliberadamente trocadas foram detectadas. Covariáveis numéricas diferentes também detectariam troca de matrizes. Os valores efetivos estão em `interface_checks.csv`.

As expressões `dat <- list(...)` dos snapshots fresh_v2 e zoneFE foram avaliadas isoladamente com dados sintéticos e conservam a/w corretos. Os três calls do wrapper `05_eforensics_umeforensics_qbl.R` e o call de `07_brasil_full_qbl.R` foram apenas inspecionados na árvore sintática e estão invertidos. Eles não foram corrigidos nesta QA. Esse achado não explica por si os resultados de convergência de fresh_v2/zoneFE.

Isso não é teste do wrapper completo, nem da lista efetivamente consumida pelo JAGS. Esses testes e reparos continuam em G3. A função histórica emite avisos `non-list contrasts argument ignored`, preservados em log; os casos numéricos passaram, sem certificação de contrastes de fatores. O comentário do usuário sobre JAGS/prioris/HMC permanece literal no appendix, e execução histórica não foi convertida em evidência de convergência.

## 4. Evidência herdada, runner e reprodução

G2-T1/T2/T3 herdam a auditoria anterior e recebem a checagem de fechamento acima. T4 recebe recálculo independente dos funcionais. **T5 mantém a rederivação independente de round1**, com hashes dos 75 checks, 162 enumerações e nove checks de adjudicação conferidos; esses testes não foram reexecutados. A seção 5 do appendix, sobre marginalização, é idêntica byte a byte. O kernel diagnóstico continua distinto da semântica runtime e de um alvo automaticamente normalizado; a complexidade teórica não se tornou benchmark nacional medido.

### Ponto solicitado sobre o runner selado

É verdadeiro que `tests/mebane/algebra/test_benchmark_round2.R:1-8` exige exatamente o diretório existente `G2/round2/results` e não permite destino alternativo. Isso foi confirmado avaliando **apenas a guarda**, sem executar qualquer escrita do runner. O comando publicado em `implementation.md:46`, se usado na árvore original congelada, regrava os artefatos.

Entretanto, `implementation.md:50` já declara essa consequência, identifica `R_session.txt` e instrui explicitamente cópia isolada ou script/diretório próprio após o freeze. Assim, a hipótese de omissão documental ou impossibilidade de toda reprodução segura é **REFUTED**; a restrição real fica registrada como limite operacional, sem novo finding bloqueante. Não se exige modificar o candidato selado para aprovar suas decisões matemáticas.

Para reproduzir o runner do executor, use uma cópia isolada da árvore necessária, preservando os caminhos relativos de código, contratos e fontes, e execute a partir da raiz dessa cópia. Não basta criar outro diretório de saída ou copiar só o script. Esta QA não executou esse procedimento integral; usou scripts próprios. Não rodar nenhum runner de round1 ou o runner selado de round2 na árvore original.

As checagens próprias podem ser reproduzidas da raiz do projeto com:

```sh
python3 quality_reports/results/mebane_gates/G2/round2/review/execute_qa.py
```

Esse comando escreve somente em `review/`. Ele executa o script R independente, revalida os hashes e registra `git diff --check` no escopo. Enquanto o arquivo G0 estiver ausente, sua saída global será não zero, embora os 59 checks de fechamento passem. Para preservar também este parecer selado, execute futuras reproduções em uma cópia isolada, pois os logs de QA são regravados.

## 5. Resultados e limites

- **59/59 checks próprios passaram**, com tolerância numérica absoluta de `1e-11`; a lista separa fonte, contrato, interface, funcionais, margem e guarda do runner. Não foram reutilizadas as funções algébricas ou assertions do executor.
- **Integridade inicial: 719/719. Integridade final: 719/720.** O check adicional conferiu os nove registros de adjudicação; a única falha é o arquivo G0 removido durante a execução. Os 163 arquivos diretos do candidato passaram em ambas as checagens.
- `commands.json` contém comandos, ambiente, tempos, exit codes e logs. `development_checks.json` registra correções locais da própria QA: nome de coluna CSV, reconhecimento de assignment na árvore sintática e literal UTF-8 sob locale C. Nenhuma tolerância matemática foi relaxada.
- `git diff --check` não acusou erro, mas `review/` é novo e não rastreado. O selo verifica adicionalmente os arquivos novos, a sintaxe JSON, os resultados declarados e os hashes; não usa o diff vazio como prova suficiente.

Não houve MCMC, JAGS/Stan, instalação, download, ajuste, validação de inferência, convergência, identificação, potência ou desempenho nacional. As nove limitações raiz do benchmark foram preservadas. Não foi repetida uma auditoria integral dos papers nem de round1. O arquivo parcial de G0 não será restaurado ou removido pela QA, nem a integridade será declarada completa com base apenas no fato de ele ser uma fonte rejeitada.

O status `inconclusive` não pede novas escolhas metodológicas: pede somente a regularização documentada da dependência que mudou. A adjudicação final continua com a coordenação. Entrega em JSON/Markdown conforme o pedido; o registro congelado `implementation.md:54` reserva o PDF consolidado à coordenação.
