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
nenhum ZIP foi arquivado ou analisado. Não é falta de autorização do usuário.

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
