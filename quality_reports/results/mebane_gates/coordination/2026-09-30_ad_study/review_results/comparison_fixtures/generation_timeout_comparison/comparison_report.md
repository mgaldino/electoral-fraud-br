# A e D no mesmo caso: primeiro estudo experimental

Caso: Washington, D.C. 2010, dados empacotados pelos autores. Contrato: AD-DC2010-v2. Relatório gerado de resultados persistidos; nenhuma estimação ocorre nesta etapa.

## 1. Resultado e alcance

A comparação terminou **computacionalmente inconclusiva** pelos critérios prospectivos. Execução concluída, quando presente, não basta para tratar os resumos como estimativas posteriores confiáveis. Os valores abaixo descrevem as amostras geradas e permanecem sujeitos às falhas diagnósticas registradas.

A foi preservado integralmente. D muda a distribuição conjunta para uma multinomial e remove as contagens auxiliares Binomial(N) do qbl. As diferenças combinam essas alterações; não isolam o efeito causal de uma única mudança. Ambas as execuções usam JAGS, para não acrescentar uma troca de engine ao contraste.

## 2. Dados e protocolo

Foram usadas as mesmas 143 unidades, na ordem original, sem exclusões. Totais: N=452.992, A=320.943, W=97.978, O=34.071. Nesta base A=NVoters-NValid é a codificação dos autores; não equivale automaticamente à abstenção efetiva brasileira. O resíduo não é identificado como votos de um único adversário.

Quatro cadeias por modelo, 1.000 iterações de adaptação, 5.000 de aquecimento e 2.000 amostras retidas por cadeia; mesmas prioris compartilhadas, desenho intercept-only com seis efeitos por unidade, sementes e inicializações predefinidas. Um objeto rjags por modelo, A seguido de D, sem modelos concorrentes e sem extensão automática. As mesmas sementes não tornam os draws dos modelos pareados ou de igual precisão.

## 3. Tempo e diagnósticos

Tabela 1. Tempo de processo por modelo e diagnósticos dos 23 alvos globais. Os totais de falhas incluem também alvos locais e discretos. NA não é aprovação. Tempo, sozinho, não mede qualidade ou eficiência estatística.

| Medida | A: qbl literal | D: multinomial |
|---|---|---|
| Geração: processo completo (s) | 20,00 | 20,00 |
| Preparação interna (s) | 1,00 | 1,00 |
| Amostragem (s) | 6,00 | 6,00 |
| Persistência dos draws (s) | 1,00 | 1,00 |
| Pós-processamento: processo (s) | 5,00 | 5,00 |
| Geração + pós-processamento (s) | 25,00 | 25,00 |
| R-hat máximo, globais | 1,000 | 1,000 |
| ESS bulk mínimo, globais | 800,00 | 800,00 |
| ESS cauda mínimo, globais | 600,00 | 600,00 |
| Alvos obrigatórios reprovados | 0 | 0 |
| Alvos com diagnóstico obrigatório indefinido | 0 | 0 |

R-hat menor que 1,01 e ESS bulk/cauda de pelo menos 400 são exigidos para todos os alvos obrigatórios. Indicadores e contagens de classe têm também teto de cinco pontos percentuais para a amplitude das médias entre cadeias, com contagens divididas por 143 nessa checagem. Indicadores raros podem ter diagnósticos indefinidos; isso mantém o resultado inconclusivo e não prova ausência de uma classe nem, isoladamente, não convergência.

## 4. Comparação descritiva das saídas

Tabela 2. Médias das amostras geradas, não estimativas validadas de fraude. pi são pesos da mistura, não proporções observadas de seções fraudulentas. M e S são funcionais análogos em unidades de votos esperados, calculados e agregados dentro de cada draw conjunto; as variáveis latentes subjacentes diferem entre A e D. Quantis, resultados por cadeia e diagnósticos individuais estão nos CSVs.

| Funcional | A | D |
|---|---|---|
| pi[1] | 1,0000 | 1,0000 |
| pi[2] | 1,0000 | 1,0000 |
| pi[3] | 1,0000 | 1,0000 |
| M_total | 1,0 | 1,0 |
| S_total | 1,0 | 1,0 |

M representa transferências esperadas do grupo inicialmente não votante para votos no candidato focal; S representa transferências esperadas de votos inicialmente destinados aos demais candidatos. São rótulos internos do mecanismo estatístico, não eventos observados. Em cada unidade: M=N(1-tau)m e S=N tau(1-nu)s; tau é a participação inicial, nu é a preferência inicial pelo candidato focal, m e s são intensidades dependentes da classe.

D também permite reconstruir contagens condicionadas a W, preservando a mesma classe e parâmetros de cada draw. Essas contagens secundárias ficam separadas dos funcionais M/S da tabela; não podem ser comparadas a A como se fossem o mesmo estimando, nem usadas para resgatar diagnósticos da posterior primária.

## 5. O que ainda falta

O qbl A conserva os contraexemplos já confirmados de probabilidades inválidas em certos estados e de contagens fora do suporte físico. D corrige o suporte por construção, mas probabilidades por seção também podem ser reproduzidas sem transferências quando os parâmetros são livres. É necessário estudar identificação, restrições hierárquicas, prioris e heterogeneidade legítima antes de qualquer conclusão eleitoral.

Não há saída numérica externa imutável localizada para o exemplo D.C. Assim, este piloto não certifica reprodução de uma tabela publicada pelos autores e não aprova G10. G3 histórico permanece inconclusivo; os gates de validação e escala para o Brasil não foram liberados.

A sequência posterior é diagnosticar os limites evidenciados aqui, comparar D em JAGS e Stan no mesmo alvo, completar a replicação externa e só depois avançar aos testes de identificação e ao caso brasileiro aprovado. Qualquer nova rodada deve preservar esta e fixar prospectivamente seus ajustes; não se prevê repetir até obter concordância.

## 6. Fontes e reprodução

Fonte empírica: Ferrari, Diogo; McAlister, Kevin; Mebane, Walter R., Jr.; Wu, Patrick Y. (2019). eforensics 0.0.4, commit 3017de537450f97a01872d0157462a68bea348ee; vignette Introduction to eforensics, 16/08/2019, exemplo D.C. 2010. Código e RDA arquivados no projeto. D é derivação experimental própria, não implementação exata dessa fonte.

Mebane, Walter R., Jr.; Ferrari, Diogo; McAlister, Kevin; Wu, Patrick Y. (2022). Measuring Election Frauds. Manuscrito, versão de 6 de março de 2022, especificação nas páginas impressas 3-7. [Texto dos autores](https://websites.umich.edu/~wmebane/measfrauds.pdf). Cópia local preservada no projeto.

Mebane, Walter R., Jr. (2023). Lost Votes and Posterior Multimodality in the eforensics Model. PolMeth 2023, Stanford, 9-11 de julho; versão de 2 de julho de 2023, páginas impressas 5-8. [Texto do autor](https://websites.umich.edu/~wmebane/pm23.pdf). Cópia local preservada no projeto.

Vehtari, Aki; Gelman, Andrew; Simpson, Daniel; Carpenter, Bob; Bürkner, Paul-Christian (2021). Rank-Normalization, Folding, and Localization: An Improved R-hat for Assessing Convergence of MCMC (with Discussion). Bayesian Analysis, 16(2), 667-718. [DOI: 10.1214/20-BA1221](https://doi.org/10.1214/20-BA1221). Referência dos diagnósticos; este estudo não replica os experimentos do artigo.

As medidas de custo separam fases internas e relógios externos. O tempo geração + pós-processamento soma os dois processos, sem contar duas vezes adaptação ou amostragem, e exclui espera pelo outro modelo, supervisor e elaboração do relatório. Os CSVs distinguem ESS/s de amostragem, geração interna, geração externa e computação total. Sem aprovação diagnóstica, esses valores não estabelecem superioridade de uma alternativa.

Entrada comum SHA-256: `b2ef611dabb751f9286acbaae841a23c34948ed0a4b6306364cbe94d9d24903e`. Modelo A preservado SHA-256: `f8360126424b7a463f76a1c99efc89a8a5cb81339213bd4931559f14595fbab6`. Contrato, scripts, entradas e saídas usados são vinculados pelos manifestos do estudo. O script de reprodução deste relatório é R/experimental/mebane_ad/compare_runs.R; a renderização do PDF é separada dos cálculos.
