# Mebane: Brasil 2022 e 2026

Resumo da execução coordenada e roteiro de retomada. Este documento registra trabalho de dados e auditoria; não apresenta estimativas eleitorais novas.

Estado extraído do ledger em 29/09/2026 04:50 UTC.

## 1. O que está pronto

| Gate | Estado | Alcance |
|---|---|---|
| G0 | pass | Ambiente, fontes, dados e fits inventariados; baseline aprovado. |
| G1 | pass | Pipeline de dados 2022 reparado, reproduzido e aprovado independentemente. |
| G2 | changes_requested | Auditoria matemática rederivada; seleção do alvo e estimandos pendente. |
| G7 | pass | Staging ensaiado e aprovado após reparos e QA; sem votos reais de 2026. |

Tabela 1. Estado operacional dos ramos executados. Pass aprova somente o contrato do gate indicado; não é aprovação geral de inferência.

Sol executou inventário e dados; outro agente Sol fez a QA independente. A auditoria matemática e sua revisão foram atribuídas a agentes separados do modelo principal. O coordenador conferiu evidências e adjudicou os achados; nenhum executor aprovou seu próprio gate.

## 2. Dados de 2022

O pipeline conserva 944.150 registros seção-turno, 472.075 em cada turno. Retém os 99 casos de votos nominais zero. Há 47 seções não instaladas por turno, com 657 aptos; seus 94 registros permanecem no arquivo, sinalizados como não elegíveis. Restam 472.028 linhas elegíveis por turno, sem que isso constitua ainda uma amostra inferencial aprovada.

N corresponde aos eleitores aptos; a = N - comparecimento; w aos votos do candidato-alvo. Brancos/nulos são preservados nas contagens e no comparecimento. A abstenção reportada original permanece separada. Exterior e seções pequenas são sinalizados, sem exclusão automática para gráficos.

A QA reproduziu controles nacionais, 56 UF-turnos e 364 candidato-UF-turnos a partir dos brutos e controles oficiais. Passaram 43 contraprovas próprias e 64 regressões do executor. Nove produtos centrais foram byte-idênticos em quatro execuções; as 70 colunas anteriores dos Parquet mantiveram valores e tipos. Os três defeitos encontrados foram reparados e rechecados.

Limite: a igualdade dos agregados com extratos oficiais posteriores não autentica a aquisição histórica do ZIP dos autores nem prova identidade de todos os campos entre versões. Não houve restauração fria integral do ambiente.

# 3. Decisão metodológica pendente

A auditoria e a revisão independente confirmam que o qbl/JAGS instalado, o texto dos artigos e o Stan histórico não definem o mesmo modelo. A QA executou 75 testes próprios e 162 enumerações pequenas, com erro máximo 4,44e-16; a coordenação fez nove verificações adicionais. Nenhum erro material foi encontrado nas derivações, mas os achados impedem aprovar uma portagem equivalente sem fixar o alvo.

## Três escolhas que precisam ficar explícitas

Alvo e suporte. O qbl admite combinações latentes que fazem a expressão de p.w sair de [0,1]; um caso mínimo gera 499,5. A política runtime do JAGS ainda não foi testada. O Stan limita artificialmente probabilidades (clamp) e substitui contagens latentes pela média, alterando o alvo. Mesmo em caso válido sem clamp, a likelihood exata 0,4116 difere do plug-in 0,4872. Normalização no retângulo de contagens não garante o suporte físico a + w <= N.

Priors e desenho. O JAGS aplica Exp(5) à variância hierárquica; o texto dos artigos, ao desvio-padrão. Isso implica variâncias residuais médias de 0,2 e 0,08. A prior de mistura ordena apenas o componente sem fraude acima dos outros dois, sem ordenar esses dois entre si. Interceptos e codificação geográfica também precisam ser preservados ou alterados explicitamente. Essas diferenças não demonstram que as priors causaram a falha de convergência.

Incerteza e margem. Quantis da esperança condicional não são quantis do total com classes latentes incertas. Totais devem ser agregados no mesmo draw. O modelo binário não identifica de qual candidato vieram votos stolen; brancos/nulos continuam no grupo residual mesmo em T2. Recomenda-se manter limites de identificação parcial, sem afirmar vencedor contrafactual.

## Recomendação encaminhada ao usuário

Primeiro reproduzir fielmente o qbl/JAGS como benchmark de software, mantendo suas priors e testando sua semântica. Esse benchmark não seria liberado automaticamente para inferência. A alternativa é desenvolver um modelo gerador de contagens fisicamente coerente, explicitamente distinto do qbl. A escolha foi perguntada; ausência de resposta não foi tratada como aprovação.

## O comentário sobre JAGS foi preservado

Comentário do usuário: "em JAGS rodou direito, então nao acho que seja prioris. HMC deveria ser melhor que MCMC padrao."

O fresh_v2 histórico terminou em 1.921,9 s, cerca de 32 minutos: 6.748 seções, quatro cadeias, adaptação 1.500, burn-in 5.000 e 5.000 draws por cadeia. G0 recarregou o fit e obteve R-hat clássico de 1,2468 para pi[2] e 1,7138 para iota.s.alpha. Terminar a execução não demonstrou convergência. São diagnósticos clássicos, não os rank-normalized exigidos pelo protocolo novo.

O Stan n2000 registrou 541,7 s de sampling/warmup e 9,62 s de compilação, com duas cadeias, R-hat máximo 1,2294 e ESS bulk mínimo 8,24. Dados, iterações, cadeias e alvo diferem do JAGS: não é benchmark controlado. HMC também é MCMC e não tem superioridade universal. Nenhuma nova estimação foi executada neste lote.

# 4. Como retomar

O ledger quality_reports/plans/mebane_2022_2026_gates.json é a fonte de estado. A versão legível, o protocolo de despacho e as evidências por rodada estão na mesma estrutura do projeto. Não sobrescrever rounds congelados; mudanças materiais exigem nova rodada e QA separada.

G2: fechar a escolha do alvo, priors/desenho e distribuição dos estimandos; revisar a decisão antes de promover o gate.

G3: implementar a referência small-N e o gerador compatível, testar suporte e priors, comparar engines somente no mesmo alvo e decidir a viabilidade do Stan exato.

G4: recalcular diagnósticos dos fits históricos, executar pilotos e aprovar contrato de calibração antes das simulações confirmatórias. Quatro cadeias, R-hat rank-normalized < 1,01 e bulk/tail ESS >= 400 são critérios iniciais necessários, não suficientes.

G5/G6: medir tempo por amostra efetiva e memória, aprovar capacidade e só então estimar o Brasil 2022. Não extrapolar linearmente um único tempo de Brasília.

G7/G8/G9: preparar a recepção independentemente do modelo; cada turno de 2026 precisa de dados oficiais com cobertura auditada e inferência aprovada. Ausência de T2 não prova sua não ocorrência. Não existe monitoramento futuro ativo neste lote.

## Limite concreto da preparação 2026

G7 entrega arquivamento e validação preliminar (staging) de CSV normalizado por seção/candidato, com referências EA11/EA16 e controles independentes. Não é ainda um conversor validado dos arquivos oficiais brutos de 2026. Esse adaptador precisa ser confirmado contra a publicação real, incluindo reconciliação completa das categorias. Recibos de ensaio, mesmo rotulados como oficiais, continuam data_ready=false e inference_ready=false.

A aprovação de G7 inclui reparos rechecados para nomes UTF-8 sob locale C, datas exatas por turno e escopo territorial explícito. Completude relativa aos arquivos de referência não equivale a cobertura nacional atestada. A ingestão requer execução serial ou lock externo.

## Fontes para retomada

Contrato matemático: appendices/mebane_model_contract.md; PDF e revisão independente em quality_reports/results/mebane_gates/G2/round1/.

Dados aprovados, configuração e logs: quality_reports/results/mebane_gates/G1/round2/; comandos de execução versionada no README.

Histórico da coordenação: quality_reports/results/mebane_gates/coordination/2026-09-28_execution.md. Os handoffs de abril são contexto histórico, não autorização para ignorar as novas validações.

Fontes técnicas 2026: tse2026_source_preflight.md e cinco PDFs oficiais arquivados na pasta de coordenação. EA20 agregado não deve ser confundido com observações por seção. Arquivos de simulação não são resultados reais, mesmo com 100% de cobertura.

# 5. Referências completas

Ordem sugerida: os dois textos de Mebane, o contrato auditado e o código do commit fixado; depois diagnósticos MCMC e documentação de marginalização. As fontes técnicas do TSE servem à implementação do intake, não à validação do modelo.

Mebane, Walter R., Jr.; Ferrari, Diogo; McAlister, Kevin; Wu, Patrick Y. 2022. Measuring Election Frauds. Working paper, 6 de março. Versão arquivada no baseline. [Fonte](https://public.websites.umich.edu/~wmebane/measfrauds.pdf)

Mebane, Walter R., Jr. 2023. Lost Votes and Posterior Multimodality in the eforensics Model. PolMeth 2023, Stanford University, versão de 2 de julho. Versão arquivada no baseline. [Fonte](https://public.websites.umich.edu/~wmebane/pm23.pdf)

Mebane, Walter R., Jr. 2025. eforensics Analysis of the 2024 President Election in Pennsylvania. Working paper, versão de 2 de junho. [Fonte](https://websites.umich.edu/~wmebane/PA2024.pdf)

Ferrari, Diogo; McAlister, Kevin; Mebane, Walter; Wu, Patrick. 2019. eforensics: Election Forensics: Positive Empirical Models of Election Fraud. Pacote R 0.0.4, commit 3017de537450f97a01872d0157462a68bea348ee, de 27 de outubro de 2019, fixado no baseline. [Fonte](https://github.com/UMeforensics/eforensics_public/commit/3017de537450f97a01872d0157462a68bea348ee)

Vehtari, Aki; Gelman, Andrew; Simpson, Daniel; Carpenter, Bob; Bürkner, Paul-Christian. 2021. Rank-Normalization, Folding, and Localization: An Improved R-hat for Assessing Convergence of MCMC (with Discussion). Bayesian Analysis 16(2): 667-718. [Fonte](https://doi.org/10.1214/20-BA1221)

Stan Development Team. Stan User's Guide: Latent Discrete Parameters. Documentação on-line, consulta em 28 de setembro de 2026. [Fonte](https://mc-stan.org/docs/stan-users-guide/latent-discrete.html)

Tribunal Superior Eleitoral. Resultados - 2022. Portal de Dados Abertos, consulta em 28 de setembro de 2026. [Fonte](https://dadosabertos.tse.jus.br/dataset/resultados-2022)

Tribunal Superior Eleitoral. Resolução nº 23.760, de 2 de março de 2026. Calendário eleitoral de 2026. [Fonte](https://www.tse.jus.br/legislacao/compilada/res/2026/resolucao-no-23-760-de-2-de-marco-de-2026)
