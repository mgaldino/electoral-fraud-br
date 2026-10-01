# Preparação da revisão D/Stan

Estado: **leitura estática e preparação; nenhum PASS emitido**. Data: 01/10/2026.

Revisor: `01a0f4b8-962b-77a3-a418-6247c6219e8b`. Coordenador: `019d795a-acfa-72c2-a210-d55a46c606c2`. O goal permanece ativo até parecer `PASS` ou `needs_revision` sobre o freeze completo. Escrever somente nesta pasta. Não executar MCMC, instalar, apagar ou modificar candidatos.

O coordenador informou que JAGS20k ainda mede geração/diagnóstico. Nesta etapa foram somente lidos os fontes e calculados hashes de arquivos pequenos. Os oráculos em `oracles.R` foram preparados, mas **não executados**, nem mesmo contra os fontes vivos. Não se invocaram compilação, sampler, funções de diagnóstico ou testes fornecidos.

## Derivações Novas

Para o prior original, a densidade conjunta é `1/u1^2` no domínio `0<u1<1`, `0<u2,u3<u1`. A transformação `(u1,r2,r3) -> (u1,u1*r2,u1*r3)` tem determinante `u1^2`. Portanto, a densidade transformada é 1 no cubo unitário: `u1` é independente e pode ser integrado exatamente. Resultam dois ratios independentes Uniforme(0,1) e `pi=(1,r2,r3)/(1+r2+r3)`. O ponto `u1=0` tem medida zero. Não se impõe ordenação entre `pi2` e `pi3`; um prior uniforme na região ordenada do simplex seria outro prior, com Jacobiano diferente. O Stan declara os ratios limitados, não um parâmetro simplex livre.

Para cada bloco, `h=alpha+sqrt(v)*z`, `z~N(0,1)` e `v~Exp(rate=5)`. A comparação de densidades centrada e não centrada deve incluir `n/2 * sum(log(v))` quando ambas são escritas nas coordenadas de `z`. Esse ajuste é para o teste de mudança de variáveis; não se acrescenta um segundo prior/Jacobiano de `h` ao modelo não centrado. Mantêm-se `alpha~N(0,1)` e `b0~N(0,0.01^2)` separados.

A contribuição de uma unidade é `log(sum_c pi[c] * Multinomial(y|p[c])))`, com uma classe compartilhada pelos três componentes de `y=(A,W,O)`. A distribuição condicional usada na reconstrução é proporcional a essas mesmas três massas, no mesmo draw. Isso difere de avaliar uma multinomial na média das probabilidades. M/S e probabilidades ativas devem usar a mesma realização de Z. Expectativas Rao-Blackwell são saídas distintas e não substituem esses alvos aumentados nem resgatam diagnósticos obrigatórios.

## Inspeção Estática

No modelo lido, `d_multinomial.stan:60-98` declara os ratios e priors esperados, usa `sqrt(v)` e soma massas por `log_sum_exp`. As linhas `120-149` usam as massas da observação inteira para `responsibility`; `Z=Z_rng` seleciona simultaneamente as probabilidades e M/S, com saídas Rao-Blackwell separadas. Isto é uma leitura do fonte vivo, não confirmação executável ou aprovação do port.

`stan_bridge.R:6-31` mapeia 1451 variáveis comuns para quatro matrizes de 2000 linhas, preservando o índice de cadeia. A revisão executável comparará todas as colunas, não apenas exemplos. `stan_bridge.R:34-50` exige zero divergências e zero hits de treedepth >=12 em cada cadeia, E-BFMI >=0.3 e precisão de 860 variáveis internas (858 z e dois r). O teste independente conferirá o conjunto de nomes efetivamente emitido pelo modelo, além do número de linhas.

`postprocess_stan.R:24-56` mantém HMC/NCP e as duas somas Rao-Blackwell separados, e só permite precisão comum se HMC/NCP também passarem. O processador comum é uma derivação do diagnóstico 2k já revisado. A identidade será confirmada por bytes depois do freeze; não se repetirá a história matemática do helper D.

O wrapper informa que `generation_wall_seconds` é o tempo da chamada Stan, não o processo externo completo. Na revisão, conferir o denominador efetivamente propagado e preservar sua distinção em relação à compilação, persistência e tempos externos. Não há ainda achado formal sobre este ponto.

## Testes Preparados

1. Vincular manifesto de preparação, executável, fontes, contratos, dados e manifesto do adapter. Comparar os hashes lidos agora ao freeze final; qualquer mudança será tratada como delta, não incorporada silenciosamente a um PASS.
2. Conferir a mudança exata do prior pi, a igualdade centrada/NCP, densidades compiladas com e sem Jacobiano das restrições e gradientes por diferenças finitas. Usar dados sintéticos pequenos e métodos determinísticos do artefato compilado. Os oráculos não chamam `sample()`.
3. Ler a saída sintética de parâmetros fixos produzida pelo implementador, caso incluída no freeze, e recompor independentemente responsabilidades, probabilidades e M/S de cada classe, escolha por Z e somas conjuntas. Não gerar novas cadeias.
4. Exercitar todos os nomes e posições de `2000 x 4`, incluindo sentinelas que distinguem cadeia, iteração, unidade e bloco; rejeitar ausência de variável, pooling ou forma errada. Executar um fluxo sintético completo de diagnóstico quando autorizado.
5. Conferir diretamente os 860 internos e as quatro estatísticas de cadeia. Controles negativos: uma divergência; um hit de treedepth; energia constante/indefinida; E-BFMI abaixo de 0.3; um interno sem variação ou com cadeias separadas. Nenhum NA obrigatório pode passar. Saídas Rao-Blackwell favoráveis não devem alterar o veredicto dos alvos aumentados.
6. Conferir snapshots, inicializações, argumentos do sampler e supervisão sem chamar o sampler real. Reutilizar os testes de timeout já aprovados onde o código for byte-idêntico; testar somente diferenças necessárias.

O arquivo `oracles.R` define verificadores, mas não é um driver de execução. A localização dos artefatos congelados e sua ligação por hash serão fixadas no driver após o envio dos freezes e a liberação de CPU. Nenhum parecer final será baseado somente em compilação ou na concordância de médias.

## Hashes Lidos Antes do Freeze

| Fonte | SHA-256 |
|---|---|
| `models/experimental/mebane_ad_stan/d_multinomial.stan` | `b38de93ef22b826233f35898b5d3becfae1fb46df774ead065b8d4133c127c9b` |
| `R/experimental/mebane_ad_stan/common.R` | `1c2eeb260d034326f0dab2513049a241232be20d85833317ea3528ca3c4dc4e5` |
| `R/experimental/mebane_ad_stan/reference.R` | `6f7e15ddeb0d98d76c103fa98d2aa547da9f50dcc31c6e5cda589319e4ddad5d` |
| `R/experimental/mebane_ad_stan/run_stan.R` | `3e414ceee1578fe70291d24443f0bb6538767924dbe373d8b6ce0c8fe100b3e7` |
| `R/experimental/mebane_ad_stan/supervise_stan.py` | `2901d8267ec4f8a5786ab9abfb124f4903708b47622cce571397c5bf0c618313` |
| `R/experimental/mebane_ad_long/stan_bridge.R` | `aec0a5c70564b2f39fd8504240bb425cd74f2ce587f138b5839f953ff66242cc` |
| `R/experimental/mebane_ad_long/postprocess_stan.R` | `2bb6b838f206a0b0de16a9ea86ed5fddc562d137c96a04c9c2484ba27bef80e1` |
| `R/experimental/mebane_ad_long/diagnostics_stan.R` | `a5a19974731ad2f19a13a27afe8b2641e138751e61898dbb35f77bc1b13ac1b9` |
| `R/experimental/mebane_ad_long/prepare_stan_diagnostics.R` | `07ad322508cae42bfb076ea0735cc8cf1ebf19813accbd8bac959d48c51f678a` |
| `R/experimental/mebane_ad_long/supervise_diagnostics.py` | `7af9fcf1cd3ff0b9330757298b95309d04cfd1ba98468bf23c30afc00a641df2` |
| `tests/mebane/ad_stan/test_stan.R` | `b715a4a6d239663a2ebe35e3ecbd8500d2ade0c523b909ea6453d1ed4585b4e3` |
| `tests/mebane/ad_stan/test_supervisor.py` | `d69b6bbae956c1d5c6f7b3ef1d15ab9cdf0647aa4507e9c23bdd4677e1529983` |
| `tests/mebane/ad_long/test_stan_bridge.R` | `f2f91006ab67a57582218589d527a884e033044d4b57b6824c7c81a6f2142523` |
| `contract_stan_diagnostics.json` | `e33a59939f0d55513fea6ae05a2cc90fac617f3385193ec56e4a2a7a9b6df264` |

Comandos de inspeção: `nl -ba <fonte>`, `cat <fonte>` e `shasum -a 256 <fontes>`, executados na raiz do repositório. O aviso de locale do `shasum` informou fallback para `C`; não houve erro de leitura/hash. Estes hashes documentam a leitura prévia e **não constituem um freeze aprovado**.
