# Fontes preliminares de controle TSE 2022

Consulta: 2026-09-28. Preparação documental do coordenador para G1, sem executar
o pipeline nem aprovar dados. Valores abaixo foram lidos em fontes públicas,
não calculados dos CSVs do projeto. O script adjacente verifica somente sua
coerência aritmética; não valida uma eleição.

## Fontes primárias

O [Portal de Dados Abertos do TSE, Resultados 2022](https://dadosabertos.tse.jus.br/dataset/resultados-2022)
informa que o arquivo BR de votação por seção cobre Presidente em todas as UFs,
inclusive ZZ (exterior). Contém os recursos oficiais de histórico da totalização
por turno. Registrar a data de geração de cada arquivo; não tratar notícias,
registro de eleitorado e arquivo final como snapshots intercambiáveis.

| Fonte | Eleitores aptos | Comparecimento | Abstenções | Nominais/válidos | Brancos | Nulos |
|---|---:|---:|---:|---:|---:|---:|
| TSE, notícia de 100% da totalização T2, 31/10/2022 | 156454011 | 124252796 | 32200558 | 118552353 | 1769678 | 3930765 |
| TRE-RN, estatísticas nacionais T2 | 156454011 | 124252796 | 32201215 | 118552353 | 1769678 | 3930765 |
| TSE, notícia de 100% da totalização T1, 04/10/2022 | 156454011 | 123682372 | 32770982 | 118229719 | 1964779 | 3487874 |

Fontes: [TSE, totalização T2](https://www.tse.jus.br/comunicacao/noticias/2022/Outubro/100-das-secoes-totalizadas-confira-como-ficou-o-quadro-eleitoral-apos-o-2o-turno/)
e [TRE-RN, números do segundo turno](https://www.tre-rn.jus.br/comunicacao/noticias/2022/Outubro/eleicoes-2022-numeros-do-2o-turno-no-rn).
Ambas reportam 60345999 votos para Lula e 58206354 para Bolsonaro. Para T1,
a [notícia do TSE de totalização completa](https://www.tse.jus.br/comunicacao/noticias/2022/Outubro/100-das-secoes-totalizadas-confira-como-ficou-o-quadro-eleitoral-apos-o-1o-turno)
reporta Lula 57259504 e Bolsonaro 51072345, além de 472075 seções apuradas.
Há outros candidatos em T1; o residual entre votos nominais e esses dois
candidatos não é uma discrepância de totalização.

As notícias do TSE associam o total de aptos a abstenções que não fecham
aritmeticamente com os respectivos comparecimentos: a diferença é 657 nos dois
turnos. O script verifica essa diferença, sem interpretá-la como evidência de
fraude ou atribuir sua causa sem investigação. Não substituir campos dos dados
para reproduzi-la. G1 deve conferir snapshots e escopo dos denominadores. Em
particular, não confundir a notícia anterior de T1 com 99,99% de seções apuradas,
publicada em 03/10/2022, com esta notícia de totalização completa de 04/10/2022.

## Recursos oficiais localizados e limites de acesso

- [Histórico T1, metadados](https://dadosabertos.tse.jus.br/dataset/resultados-2022/resource/47f692af-7309-4a21-b536-0d1386d449b9):
  recurso ZIP/CSV, metadados atualizados em 05/11/2022, arquivo anunciado como
  carga única após T1. URL de download publicada:
  `https://cdn.tse.jus.br/estatistica/sead/eleicoes/eleicoes2022/Historico_Totalizacao_Presidente_BR_1T_2022.zip`.
- [Histórico T2, metadados](https://dadosabertos.tse.jus.br/dataset/resultados-2022/resource/7cd53725-5dc5-4954-aee9-7dbf4097d26c):
  recurso ZIP/CSV, metadados atualizados em 05/11/2022, carga única após T2.
  URL publicada:
  `https://cdn.tse.jus.br/estatistica/sead/eleicoes/eleicoes2022/Historico_Totalizacao_Presidente_BR_2T_2022.zip`.

Os metadados acima foram abertos pelo navegador de pesquisa. O fetch de ZIP por
esse mecanismo não expôs o conteúdo (tipo ZIP não suportado). A consulta HEAD
via curl, com permissão de rede escalada, retornou HTTP 403 nos dois recursos;
nenhum ZIP foi arquivado nessa tentativa. Não era falta de autorização do
usuário. O download posterior pelo navegador foi bem-sucedido, conforme o
registro abaixo; o 403 não é mais um impedimento de aquisição dessas fontes.

Tentativas posteriores de arquivar o HTML das três notícias acima por
`curl -fL --max-time 30`, com rede escalada, também retornaram HTTP 403
(exit 56). Nenhum HTML foi salvo. Os valores desta nota foram conferidos nos
resultados de pesquisa das fontes primárias, não em snapshots HTML locais.
Essa distinção deve acompanhar qualquer uso posterior; os links e valores
transcritos não equivalem a uma cópia de bytes autenticada do arquivo TSE.

Uma tentativa de consultar a antiga rota JSON
`https://resultados.tse.jus.br/oficial/ele2022/545/dados-simplificados/br/br-c0001-e000545-r.json`
retornou HTTP 404 após a liberação da rede; antes dela houve falha de DNS no
sandbox. Não considerar esse endpoint uma fonte disponível. Nenhum dado
desconhecido foi substituído por inferência ou copiado de fonte secundária.

## Uso no próximo gate

G1 recebe estas referências como ponto de partida, não como tabela de aceitação
já aprovada. Deve derivar totais dos brutos preservados, separar exterior e
exclusões, conferir datas/versões e resolver diferenças. Os controles por UF
ainda precisam de fonte adequada; T1 e T2 acima são referências documentais
nacionais, não substituem a reconciliação dos arquivos oficiais de apuração.
Preservar explicitamente lacunas de acesso.

## Aquisição posterior pelo navegador

Em 28/09/2026, entre 23:19 e 23:22 (America/Sao_Paulo), o coordenador abriu os
recursos no navegador integrado do Codex e acionou o link publicado
"Ir para recurso" via `locator.downloadMedia`. Não houve CAPTCHA, login,
aceitação de termos ou alteração de segurança. Os downloads retornaram caminhos
em `~/Downloads`; cópias sem sobrescrita (`cp -n`) foram preservadas nesta pasta.
Nenhum dado do projeto foi enviado ao TSE. A aquisição não é ainda validação
semântica dos totais nem aprovação de G1.

| Arquivo local nesta pasta | Bytes | SHA-256 |
|---|---:|---|
| `Historico_Totalizacao_Presidente_BR_1T_2022.zip` | 1625754 | `55961aa1ecc87d0fd9c02730864f1b69a9f2eb3456327542dfc507217cd74a05` |
| `Historico_Totalizacao_Presidente_BR_2T_2022.zip` | 825276 | `1f12128fbcfacab755e0e83d9c0a350ed99ae68ea3d024aaa7bc58fe0c1dda3c` |
| `detalhe_votacao_munzona_2022.zip` | 4409303 | `c4d5b6eb679e0c22ecc2842052d3472324101b0632b9c0820b4c18206c25f930` |
| `votacao_candidato_munzona_2022.zip` | 659610562 | `319bd123d933e04c23c5920abe8455f48890b561e6dad98c1003cfd461ab8fd1` |

Os dois históricos usam os links registrados acima. Os recursos adicionais são:

- [Detalhe da apuração por município e zona](https://dadosabertos.tse.jus.br/dataset/resultados-2022/resource/0e59001a-3c9f-4a0d-a8db-7befdba22330),
  download `https://cdn.tse.jus.br/estatistica/sead/odsele/detalhe_votacao_munzona/detalhe_votacao_munzona_2022.zip`.
- [Votação nominal por município e zona](https://dadosabertos.tse.jus.br/dataset/resultados-2022/resource/40fdcf49-256a-4c81-87cf-711545bd1528),
  download `https://cdn.tse.jus.br/estatistica/sead/odsele/votacao_candidato_munzona/votacao_candidato_munzona_2022.zip`.

Ambos informam atualização frequente, inclusive por decisões judiciais; os
metadados da página datam de 05/11/2022, mas os CSVs do ZIP são gerados em
28/09/2026. Essa distinção é obrigatória na reconciliação com os brutos antigos.
O arquivo de detalhe `_BR.csv` exibe `DT_GERACAO=28/09/2026` e
`HH_GERACAO=04:18:05` na primeira linha inspecionada. Datas dos membros ZIP
não substituem o campo de geração nem a data da última totalização.

Os quatro ZIPs passaram `unzip -t` (todos os membros, zero erros), inclusive
o arquivo nominal completo, que terminou com exit 0. Os quatro hashes foram
calculados com `shasum -a 256`; os tamanhos, com `stat -f '%N %z'`.

Para processamento, evitar extrair tudo: o ZIP nominal contém cerca de 8,64 GB
descompactados e duplica abrangências. Seu membro
`votacao_candidato_munzona_2022_BR.csv` tem 38.289.147 bytes; o correspondente
do detalhe, `detalhe_votacao_munzona_2022_BR.csv`, tem 3.451.986 bytes. G1 deve
verificar a abrangência e cargo de cada membro, especialmente `BR` versus
`BRASIL`, em vez de concatená-los e duplicar votos. A política de Git exclui
somente os quatro ZIPs grandes desta aquisição; permanecem disponíveis
localmente e vinculados por hash. Não substituir os dados dos autores por
esses snapshots sem tornar explícita a mudança de versão.
