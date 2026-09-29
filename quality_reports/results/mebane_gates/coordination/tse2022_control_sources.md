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

Fontes: [TSE, totalização T2](https://www.tse.jus.br/comunicacao/noticias/2022/Outubro/100-das-secoes-totalizadas-confira-como-ficou-o-quadro-eleitoral-apos-o-2o-turno/)
e [TRE-RN, números do segundo turno](https://www.tre-rn.jus.br/comunicacao/noticias/2022/Outubro/eleicoes-2022-numeros-do-2o-turno-no-rn).
Ambas reportam 60345999 votos para Lula e 58206354 para Bolsonaro. A notícia
do TSE associa o total de aptos a uma abstenção que não fecha aritmeticamente
com seu comparecimento; a diferença é verificada no script, não interpretada
como evidência de fraude. Não substituir campos dos dados para reproduzir essa
inconsistência editorial. G1 deve conferir snapshots e escopo dos denominadores.

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

Uma tentativa de consultar a antiga rota JSON
`https://resultados.tse.jus.br/oficial/ele2022/545/dados-simplificados/br/br-c0001-e000545-r.json`
retornou HTTP 404 após a liberação da rede; antes dela houve falha de DNS no
sandbox. Não considerar esse endpoint uma fonte disponível. Nenhum dado
desconhecido foi substituído por inferência ou copiado de fonte secundária.

## Uso no próximo gate

G1 recebe estas referências como ponto de partida, não como tabela de aceitação
já aprovada. Deve derivar totais dos brutos preservados, separar exterior e
exclusões, conferir datas/versões e resolver diferenças. Os controles por UF e
T1 ainda precisam de fonte adequada. Preservar explicitamente lacunas de acesso.
