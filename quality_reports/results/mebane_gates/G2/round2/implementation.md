# G2 round2: fechamento autorizado, candidato para QA

## Resultado e decisões

O candidato seleciona **reprodução literal do qbl/JAGS como benchmark de software**, preservando os defeitos científicos documentados. Não aprova um gerador, qualquer fit ou inferência. G2 permanece pendente de QA independente e adjudicação desta versão.

Executor/goal nativo: `01a0eaee-01df-7773-bd63-d321db26a47c`. Goal novo e finito, criado neste lote sem token_budget, para entregar este candidato. Modelo/esforço efetivos permanecem desconhecidos; `inherit/xhigh` é somente configuração solicitada. Concluir esse goal não altera o ledger nem libera G3.

As três pendências CONFIRMED da adjudicação anterior recebem escolhas do usuário, não refutação:

- **D1:** literal commit `3017de537450f97a01872d0157462a68bea348ee`, JAGS 4.3.2, k=.7, quatro Bin(N,mu), mapa manufactured 1→.999. Sem clamp, plug-in, piso, normalização/truncamento silenciosos ou reparo F1/F2. Runtime inválido será observado em G3. Falha gerativa deve ser registrada, nunca removida por repetição até validade.
- **D2:** ordem parcial de pi, variâncias Exp(5), precisão 1/v, alpha e pequeno intercepto b0 separados, inclinações N(0,var=1), seis efeitos por observação. Primeiro desenho: seis matrizes fixas de uma coluna de uns, hierarquia completa. Geografia nacional não selecionada; aprovação G4 antes de G6. Escolha diferente reabre a decisão G2 afetada.
- **D3:** funcionais completos conjuntos M/S por draw com Z e latentes, não contagens observadas. Sem binomial extra de cédulas. Agregação no draw; médias condicionais separadas. Margem entre Dobs-M-2S e Dobs-M-S somente sob viabilidade e 0<=S_R<=S; nenhum vencedor contrafactual pontualmente identificado.

`benchmark_contract.json` registra autorização do usuário, `inferential_approval=false`, nove limitações mantidas e oito critérios adicionais go/no-go de G3. Esses critérios não substituem seu gate nem autorizam execução agora. G10, replicação de caso dos autores antes de G4, fica com coordenador/outro agente; não houve procura ou execução da replicação neste lote.

## Interface e evidência nova

O achado adicional fornecido pelo usuário foi conferido em `ef_main.R:667–675`, fonte primária do commit fixado: **formula1=w~... → w/Xw; formula2=a~... → a/Xa**. A cópia consumida está em `sources/ef_main_3017de5.R`, SHA-256 `ee626c0c939f84567c0ee74a100954229567911711193716a46837e1d6e3ce8b`. `interface_sources.json` fornece os hashes diretos e a origem; o manifesto de descoberta foi congelado somente como proveniência desse arquivo, sem adotar outros casos/resultados nele listados.

Os snapshots G0 de `05_eforensics_umeforensics_qbl.R:103–104,153–154,187–188` e `07_brasil_full_qbl.R:150–151` invertem as duas respostas. Os snapshots fresh_v2:68–76 e zoneFE:64–72 usam listas diretas `w=bsb$w,a=bsb$a` corretas. Nenhum desses scripts foi alterado. É bug de interface dos wrappers antigos, não mudança de modelo nem diagnóstico causal de priors/convergência.

G3-L8 exige sentinela assimétrica a!=w, inspeção da lista e matrizes efetivamente enviadas ao JAGS e controle negativo com respostas trocadas. Round2 apenas inspecionou a fonte e testou a especificação da sentinela com funções base de R. Não executou o wrapper completo, código de ajuste ou engine.

## Preservação e revisão anterior

Antes da edição, o appendix foi copiado byte a byte para `inherited/appendix_round1.md` (SHA-256 `ec0046bd386d048aec4ef5652ad149f5d7276455a6bf6d662878ded30cc59567`). `round1_recovery_map.json` mapeia somente seu caminho original para a cópia histórica ao validar round1. Não altera manifestos antigos, não restaura arquivos automaticamente e não apresenta o appendix atual como aquele revisado anteriormente.

Manifesto G2 round1: `783cfb036f8f26bf894c36782df4fb94e20351e4df015ca6e24330021d04a5a9`.
Revisão round1: `a027cd5ad0875ffbb92e3b983c2907700fe6e8b4dbfc776df141ef9f5f80ba7c`.
Adjudicação round1: `8f4ba0334c84b32f36e4f6e32751c688cbdff6788c82f314fa833e67498c32af`.

Os 73 arquivos do candidato anterior e 49 do manifesto de QA foram conferidos, com remapeamento apenas do appendix; o inventário adicional protege os 110 arquivos sob round1. `inherited_evidence.json` lista hashes diretos, inclusive dos inputs, código, resultados e revisão. Os 51 testes antigos do implementador, 75 testes da QA, 162 enumerações e nove checagens da adjudicação **não foram reexecutados**. A rederivação independente anterior é evidência histórica; não é uma revisão independente das escolhas novas.

O contrato estático G2 foi preservado sem status/records e sem todos.status/evidence, com hash canônico `f834bc1d12d88b4bc82fb2ada95120a838451c5809332630a75cd9abf03cf4d1`. O ledger mutável não integra o manifesto. G0 aprovado é a única dependência formal de G2, com manifesto `f71333db477385fc78dad8a7a1a7ca78e48479226dcdbde80ce97d724409fec7`, review `ef624cb4b2d8ad098b87e196d87add358ce1eba93165d44fcc1939ff303f5376` e adjudicação `ea1b4905fdfa14f6e3f36c41974ea948ba0c39d1f81f87d6eaf479782216267b`. Esses bytes e o vínculo do predecessor foram conferidos.

## Testes e reprodução

**56/56 testes determinísticos passaram**, em R 4.4.2, usando base R e jsonlite já disponível. Tolerância absoluta das comparações numéricas: 1e-12. Sem RNG, JAGS, Stan, MCMC, instalação ou download. Oito linhas sintéticas descrevem quatro draws conjuntos de duas unidades; não são dados eleitorais ou amostras posteriores. Resultados preservam quantidades fracionárias e casos inviáveis, com capacidade de origem explicitamente não verificada.

A sentinela inicialmente falhou porque `model.response` acrescenta nomes de linha ao vetor; o teste comparava atributos, além dos valores. Removeu-se somente esse atributo com `unname`, mantendo igualdade exata dos valores, tipos e ordem. O controle negativo também compara vetores sem nomes. A execução falha e a execução corrigida estão em `commands.json` e respectivos logs; não houve relaxamento da fórmula, valores esperados ou tolerância.

Da raiz do projeto:

```sh
LC_ALL=C Rscript --vanilla tests/mebane/algebra/test_benchmark_round2.R quality_reports/results/mebane_gates/G2/round2/results
python3 quality_reports/results/mebane_gates/G2/round2/candidate_tools.py verify
```

O primeiro comando reproduz os CSVs determinísticos, mas também regrava `R_session.txt`; após o freeze, a QA deve usar uma cópia isolada do candidato se quiser reexecutá-lo, ou seu próprio script/diretório, para não mudar bytes congelados. O segundo é estritamente de leitura e valida o candidato e a recuperação histórica. Nunca rodar `prepare` novamente nem o runner antigo de round1 com seu output padrão. A implementação deste gate está limitada ao contrato e aos testes próprios; não há código de produção novo.

`todo_evidence.json` marca G2-T1–T5 como done no escopo da entrega, incluindo T5 herdado da QA anterior. O último critério de aceitação continua sujeito à nova revisão independente das decisões e limitações mantidas. Logs contêm comandos, exit codes e tempos; o manifesto usa hashes de arquivo e o hash canônico JSON usa sort_keys=true, ensure_ascii=false, separators=(',',':').

Por instrução atualizada do usuário, não foi gerado novo PDF: a coordenação fará o PDF consolidado. O PDF round1 é somente evidência histórica. Não se leu nem incorporou o novo memorando G3, que não é input necessário deste gate. Ledger, README/CLAUDE, coordenação, G0/G1/G7, QA, raw, fits, renv e produção ficaram fora do write scope; alterações concorrentes do coordenador foram preservadas.
