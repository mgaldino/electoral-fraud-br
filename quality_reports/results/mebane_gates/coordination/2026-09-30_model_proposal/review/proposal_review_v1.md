# Parecer técnico independente: proposta v1

**Resultado:** sem achados técnicos que exijam alteração da proposta. Parecer favorável (`pass`) exclusivamente à coerência matemática, à comparação das alternativas e aos limites declarados de uma proposta para decisão. Não aprova modelo, estimação, identificação de fraude ou produção. G3 permanece **inconclusivo**.

Revisor: `01a0ee05-aeaf-7492-a8ea-fa731dd6214a`. Revisão: `G3-PROPOSAL-QA-V1-01`, 30/09/2026. Li integralmente `proposal_v1.md`, linhas 1-94, SHA-256 `7fe462ed99561dee68d49fe1c5595845664249060459d018b4d01829fd61153c`. Os localizadores abaixo se referem a esses bytes, não ao renderizador ou ao PDF.

## Achados e cobertura

Não há finding candidato nem correção obrigatória. Isso não transforma as alternativas em especificações implementadas. A cobertura linha a linha por blocos está em `proposal_review_v1.json`.

- **Normalização, linhas 21-23:** as três escolhas são diferentes. Normalizar por componente conserva pi como prior de classe, mas induz `P(R|z,theta) = base(R|theta) C(z,R,theta)/C(z,theta)`. Normalizar globalmente também altera os pesos das classes. Os normalizadores não podem ser omitidos. A afirmação de custo O(N³) descreve a soma direta com duas contagens ativas e A, após integrar W por CDF; não é limite inferior nem benchmark.
- **Mecanismo e likelihood, linhas 33-58:** a soma de microestados produz exatamente a multinomial proposta. A fatorização sequencial usa a probabilidade condicional correta; conserva totais e capacidades. A mudança de dependência em relação às binomiais independentes e a retirada das quatro contagens auxiliares estão explícitas. Exp(5) sobre variância, seis efeitos, alpha+b0 e a ordem parcial de pi foram conferidos na fonte JAGS. Isso não conserva todo o alvo literal, nem o texto afirma fazê-lo.
- **M/S posteriores, linhas 60-62:** o desdobramento multinomial da célula W é correto, condicionado à classe e aos parâmetros de sua posterior com todos os dados. A e O entram nessa posterior; sua ausência no desdobramento interno da célula W não é omissão de condicionamento. Sortear Z da prior seria errado. O procedimento descrito mantém draws conjuntos ao agregar.
- **Identificação e resíduo, linhas 33, 62 e 64:** a equivalência sem transferências é local, condicional a parâmetros livres. Ela não demonstra equivalência depois de integrar hierarquias distintas. O resíduo inclui brancos/nulos sob a definição de comparecimento; o texto não transforma todo S em perda do adversário.
- **Diagnósticos e roteiro, linhas 68-83:** orientação prospectiva, ainda não protocolo executável. Nenhum NA de ESS de cauda é dispensado retrospectivamente. Constância analítica e constância apenas amostral continuam distintas. Os próximos contratos, escolhas substantivas, G10 e autorizações permanecem pendentes.

## Verificações executadas

Além dos 42 checks de preflight, executei 25 checks novos sobre **336 distribuições**, enumerando microestados ordenados por eleitor, sem importar o código da candidata. Isso contrasta com a enumeração de contagens originais usada pelo executor. A tolerância independente de `1e-12` foi gravada antes da execução. Probabilidades foram verificadas estritamente no intervalo [0,1], sem clamp ou tolerância de suporte.

O maior erro da probabilidade observada foi `5,55e-16`; da **distribuição conjunta condicional** de M/S, `6,66e-16`; da distribuição de M+S, `1,11e-15`; e da covariância, `9,66e-15`. Verifiquei fronteiras, marginais binomiais, capacidade e conservação. As provas gerais e contraexemplos estão em `mathematical_verification.md`; testes finitos apenas corroboram essas identidades.

Reexecutei os três scripts preservados em caminhos novos da QA. A primeira versão falhou na fatorização sequencial e a segunda nos nomes herdados dos escalares, como esperado. A versão final, SHA `f8bb9da0b73216c6422d3292c90de66515631e26bb774170a3482dfb05318083`, passou nas mesmas 332 distribuições. Os diffs não mudam a grade, as equações matemáticas nem as tolerâncias. O caso `0.2/(1-0.8)=1.0000000000000002` foi reproduzido sem validar esse valor como probabilidade; `0.2/(0.2+0)` vale 1. O campo `roundoff_probe` do resultado final usa outro exemplo; a contraprova pertinente está no `boundary_probe` separado e no check independente.

Os quatro processos R desta etapa somaram aproximadamente **10,25 segundos**, cada um abaixo de 4 segundos. Nenhuma amostragem, instalação ou estimação foi realizada. Não executei fontes históricas G3 recuperadas.

## Fontes e limites

Conferi as equações pertinentes nos textos locais de 2022/2023 e nas imagens das páginas, e reli integralmente a fonte JAGS congelada. P23 (4d) omite visualmente o `k` antes do sinal `+`; P22 (2d) e JAGS o contêm. Essa diferença já está explicitada no contrato citado pela proposta, e a fórmula proposta não é apresentada como transcrição literal de P23. As duas cópias PDF preservam os hashes bibliográficos declarados.

A [documentação oficial de multinomiais](https://mc-stan.org/docs/functions-reference/multivariate_discrete_distributions.html) e o [guia de misturas finitas](https://mc-stan.org/docs/stan-users-guide/finite-mixtures.html), ambos versão 2.40, sustentam os usos computacionais citados. A [documentação de ESS de cauda](https://mc-stan.org/posterior/reference/ess_tail.html), versão online 1.7.1, distingue cadeias constantes e valores indefinidos; não certifica a convergência do caso histórico. Essas consultas não atualizaram o ambiente local.

Não testei gradientes, geometria posterior, escala, desempenho, identificação hierárquica, replicação externa ou conversão de dados brasileiros. O PDF da proposta teve somente seu hash conferido; a revisão visual informada pela coordenação não foi apropriada como trabalho desta QA. A escolha da candidata e a autorização de uma nova etapa continuam reservadas ao usuário.
