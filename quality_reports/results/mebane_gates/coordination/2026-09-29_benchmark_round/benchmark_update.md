# Mebane: benchmark e replicação externa

Atualização de 29 de setembro de 2026. Escopo: fechamento do contrato de
comparação, reparo de interface e preparação de replicação dos autores.
Nenhuma nova estimação eleitoral, amostragem MCMC ou execução nacional foi feita.

## 1. Resultado desta rodada

As escolhas metodológicas para reproduzir o qbl/JAGS estão definidas e passaram
na revisão independente delimitada: 56 testes determinísticos do executor e
59 verificações próprias do revisor. O candidato G2 tem 163 arquivos íntegros.
A assinatura geral ficou inconclusiva por uma mudança concorrente no inventário
G0, descrita abaixo, não por um novo erro na derivação do modelo.

O alvo autorizado é o código qbl do pacote UMeforensics 0.0.4, commit
`3017de5`, com JAGS 4.3.2. Esse benchmark de software não é uma certificação de
que o código coincide com todas as equações dos artigos, define um gerador de
contagens fisicamente coerente ou permite inferência eleitoral válida.

- Preservar a ordenação parcial da mistura: o peso do componente sem fraude
  excede os outros dois, sem ordenar estes entre si. Manter a prior exponencial
  sobre a variância hierárquica efetiva do código, os seis efeitos por observação
  e ambos os interceptos. O primeiro teste usa apenas interceptos nas matrizes
  fixas; a geografia de produção ainda precisa ser escolhida.
- Manter quatro contagens latentes binomiais, suas transformações e a expressão
  literal que usa a abstenção observada. Não substituir latentes pelas médias,
  limitar artificialmente probabilidades ou renormalizar o modelo em silêncio.
- Calcular os funcionais de votos manufactured/stolen dentro de cada amostra
  conjunta da posterior, preservando classes e latentes. Médias condicionais
  devem ser separadas da distribuição completa. Limites da margem são
  condicionais ao mecanismo e à viabilidade, sem identificar um vencedor
  contrafactual nem tratar quantidades modeladas como fraude observada.

## 2. Erro de interface identificado

A consulta ao exemplo dos autores confirmou que o pacote recebe votos em
`formula1` e abstenções em `formula2`. Quatro chamadas em dois runners antigos
nossos estavam invertidas. Foram corrigidas em
`R/05_eforensics_umeforensics_qbl.R` e `R/07_brasil_full_qbl.R`, conservando a
variável explicativa de cada resposta. As versões anteriores estão preservadas.

O teste do executor passou as quatro chamadas reais pelo wrapper instalado,
com contagens diferentes de votos e abstenções e covariáveis distintas. Conferiu
as respostas e as seis matrizes de desenho; detectou quatro inversões
deliberadas. A amostragem foi interceptada antes da função original e nenhuma
compilação JAGS ocorreu. A revisão independente repetiu o teste e detectou
também uma troca só das covariáveis, mantendo as respostas corretas. A
coordenação conferiu os 20 hashes da QA e aceitou o reparo delimitado. Os fits
não foram reestimados; G3 completo não foi aprovado por essa checagem.

As listas diretas dos scripts fresh_v2 e zone_fe não têm essa inversão. Portanto,
o novo achado não explica seus problemas de convergência. O fresh_v2 histórico
levou 1.921,9 segundos, cerca de 32 minutos, e o diagnóstico clássico recalculado
anteriormente em G0 mostrou R-hat de aproximadamente 1,25 para pi[2]. Terminar
uma execução não prova convergência. O Stan n2000 anterior tinha outro alvo e
outra configuração; seus tempos não constituem comparação controlada.

<!-- pagebreak -->

# Replicação dos autores e integridade

## 3. Replicação externa obrigatória

G10 foi acrescentado entre G3, testes de implementação, e G4, validação
inferencial. Seu contrato de comparação deve ser revisado antes de executar
o ajuste: dados, versão, tabela/figura ou resultado alvo, estimandos, sementes,
tolerâncias e critérios para resultado inconclusivo. Um exemplo sintético nosso
não substitui a aplicação empírica dos autores. O sucesso externo também não
dispensa a validação específica para o Brasil.

A descoberta por um agente Sol e a conferência por outro estão concluídas.
A QA verificou 12 hashes/tamanhos de fontes pertinentes, 50 membros do arquivo
do repositório, a aritmética de D.C. e os números citados de Bolívia e
Pennsylvania. A busca foi delimitada: não localizar um material não prova que
ele inexista. Nenhum ajuste externo foi executado e G10 não está aprovado.

- **Washington, D.C., eleição para prefeito de 2010:** a vignette dos autores
  fornece a base de 143 precincts e a chamada qbl. É um caso pequeno e concreto
  para preparar a reprodução. Não foi localizado um output numérico externo
  congelado; o Rmd calcula os números ao renderizar. Reexecutar esse código,
  sozinho, não satisfaz o confronto quantitativo externo previsto no gate.
- **Bolívia 2019:** há comando e resultados numéricos publicados. A tabela de
  Chain 1 começa na página impressa 30, física 31 do PDF; o comando summary
  aparece na página anterior. Essa é a errata do localizador inicial da
  descoberta. O arquivo limpo usado pelo autor não foi localizado, e seus
  34.551 registros tornam o caso maior que D.C.
- **Pennsylvania 2024:** o texto de junho de 2025 contém tabelas, mas descreve
  uma planilha recebida por e-mail. Não foi localizado o pacote público
  correspondente com as correções, imputações e especificação da aplicação.

## 4. Pendência de integridade, sem alteração científica

Durante a revisão G2, desapareceu o arquivo
`ssrn-4073770.pdf.download/ssrn-4073770.pdf`, de 1.360 bytes. Ele já estava
classificado como incompleto, não é fonte de Mebane e não integra os 163 arquivos
diretos de G2. Entretanto, consta do inventário G0 aprovado. A QA o verificou
às 13:13 UTC e constatou a ausência às 13:19 UTC. Não foi atribuída autoria
à remoção.

O Git conserva exatamente os bytes esperados, com hash iniciado por
`524dc82c5961`. A coordenação confirmou isso sem restaurar o arquivo. Foi
perguntado ao usuário se prefere recuperar apenas esse item inventariado ou
manter a exclusão e revisar os vínculos do inventário. A resposta está pendente.

O ledger preserva os pareceres anteriores e marca G0 em changes_requested,
G1/G7 em queued e G2 em inconclusive. Essa suspensão formal não transforma
resultados de dados ou derivações intactas em erros científicos. Se os bytes
originais forem recuperados, a revisão adicional pode se limitar à integridade
e aos vínculos. O reparo de interface foi tratado separadamente, por não depender
desse arquivo. Não se iniciou G3 completo sob uma aprovação desatualizada.

<!-- pagebreak -->

# Retomada e referências

## 5. Próximos passos

1. Resolver a escolha de integridade enviada ao usuário e revalidar os vínculos
   afetados. Fechar a assinatura G2 sem repetir a auditoria matemática intacta.
2. Executar G3 com casos pequenos e critérios fixados antes dos resultados:
   comportamento runtime de probabilidades inválidas, fronteiras, enumeração
   exata, priors, interface e pós-processamento conjunto. Comparar engines somente
   no mesmo alvo. Preservar tentativas de geração inválidas, sem repetir até
   obter dados convenientes. Nenhuma promessa de superioridade do HMC é adotada.
3. Fechar o caso e o contrato de G10 com referência externa suficiente; então
   reproduzir e revisar o resultado dos autores. Os materiais atuais são
   preparação, não uma replicação quantitativa concluída.
4. Passar por diagnóstico e calibração inferencial G4, preflight de recursos G5
   e aplicação nacional 2022 G6. Preparar o conversor dos arquivos oficiais
   brutos de 2026; o staging ensaiado de G7 não o substitui. T1 e T2 de 2026
   exigem seus próprios dados oficiais, validações e revisões.

O ledger JSON e sua versão legível estão em quality_reports/plans. O contrato
está em appendices/mebane_model_contract.md; candidato e QA de G2, em
quality_reports/results/mebane_gates/G2/round2. As fontes da replicação, seus
hashes, a revisão independente e a errata estão nas pastas de coordenação.
Os scripts e registros distinguem inspeção, evidência histórica e teste novo.

## 6. Leituras principais

1. Mebane, Walter R., Jr.; Ferrari, Diogo; McAlister, Kevin; Wu, Patrick Y.
   (2022). **Measuring Election Frauds.** Manuscrito de 6 de março.
   [PDF dos autores](https://public.websites.umich.edu/~wmebane/measfrauds.pdf).
2. Mebane, Walter R., Jr. (2023). **Lost Votes and Posterior Multimodality in
   the eforensics Model.** Versão de 2 de julho, preparada para PolMeth 2023.
   [PDF do autor](https://public.websites.umich.edu/~wmebane/pm23.pdf).
3. Ferrari, Diogo; McAlister, Kevin; Mebane, Walter R., Jr.; Wu, Patrick Y.
   (2019). **eforensics**, versão 0.0.4. Repositório UMeforensics, commit
   `3017de537450f97a01872d0157462a68bea348ee`.
   [Código fixado](https://github.com/UMeforensics/eforensics_public/tree/3017de537450f97a01872d0157462a68bea348ee).
   [Vignette com D.C. 2010](https://github.com/UMeforensics/eforensics_public/blob/3017de537450f97a01872d0157462a68bea348ee/vignettes/eforensics.Rmd).
4. Mebane, Walter R., Jr. (2019). **Evidence Against Fraudulent Votes Being
   Decisive in the Bolivia 2019 Election.** Versão de 13 de novembro.
   [PDF do autor](https://websites.umich.edu/~wmebane/Bolivia2019.pdf).
5. Mebane, Walter R., Jr. (2025). **eforensics Analysis of the 2024 President
   Election in Pennsylvania.** Versão de 2 de junho.
   [PDF do autor](https://websites.umich.edu/~wmebane/PA2024.pdf).

Fontes arquivadas com data de acesso e SHA-256 em 29/09/2026. Ler primeiro os
itens 1 e 2 para a especificação e os problemas metodológicos; depois o código
fixado e os exemplos empíricos. Dados e código de terceiros da nota sobre o
Brasil não foram tratados como um pacote de replicação dos autores do eforensics.
