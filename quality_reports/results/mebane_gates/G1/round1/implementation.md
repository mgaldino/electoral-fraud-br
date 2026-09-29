# G1 round1: candidato de dados (SOL-DADOS)

Estado: candidato entregue para QA independente; **não é PASS do gate**. Nenhuma estimação foi executada.

## Interface e contrato

Na raiz do projeto, executar `Rscript --vanilla R/01_load_tse.R config/mebane/2022.json NOVO_DIRETORIO` e, após sucesso, `Rscript --vanilla R/02_build_vars.R config/mebane/2022.json MESMO_DIRETORIO`. O primeiro comando recusa diretório preexistente; o segundo recusa produtos preexistentes ou configuração alterada após o load. Não existe default que escreva em `data/processed`. Os parquets legados, os fits e os snapshots G0 não foram alterados. Os scripts legados são preservados em G0; consumidores existentes de `data/processed` continuam lendo os produtos históricos, não os novos arquivos G1. Para outro ano é necessária nova configuração validada; nenhuma configuração 2026 foi criada.

A unidade é ano-turno-cargo-UF-município-zona-seção. A votação acrescenta número do candidato. A configuração especifica candidatos elegíveis e alvo por turno; 95/96 são categorias branco/nulo. Duplicatas de qualquer espécie, chaves faltantes, categorias não elegíveis, schema obrigatório ausente, contagens não inteiras, datas inválidas, metadados de eleição divergentes e joins com cardinalidade errada falham. Textos de origem são lidos como Latin-1 e convertidos a UTF-8. A ausência de uma linha de candidato em uma seção vira zero somente após reconciliar **todos** os votos nominais, brancos e nulos dessa seção com o detalhe; caso contrário o load falha. Os controles nacionais transcritos das notícias do TSE também são bloqueantes para os campos cobertos.

`model_counts.parquet` conserva cada seção-turno, inclusive exterior e nominais zero. `N=QT_APTOS`, `a=N-QT_COMPARECIMENTO`, `w=QT_VOTOS` do candidato alvo. As contagens físicas originais permanecem em colunas separadas. `a` derivado não substitui `QT_ABSTENCOES`. Asserções impõem `0 <= a <= N` e `0 <= w <= N-a`; não há proporções indefinidas nem exclusão pensada para gráficos. `model_eligible` é falso nos 47 registros por turno com discrepância de abstenção. Não se declara aqui que o modelo efetivo, priors ou engine estejam definidos: continuam desconhecidos/pendentes dos gates posteriores. Nenhuma amostra inferencial deve ser extraída ignorando esse flag e o contrato dos gates seguintes.

Exterior (`ZZ`) e seções com menos de 10 aptos são mantidos e marcados, sem corte automático. O líder nacional é determinado, separadamente por turno, pelo maior total nominal bruto entre candidatos; em 2022 é 13 nos dois turnos. A unidade de candidatura é o número do candidato por turno; coligações não são somadas como votos adicionais. O extrato oficial de 2026 fornece metadados de agremiação/coligação em arquivo separado, não altera o numerador. Empate no líder bloqueia o build.

## Resultados executados

Tabela 1. Reconciliação nacional dos CSVs dos autores (geração 01/11/2022), por turno. Todos os valores são contagens.

| Turno | Seções | Aptos | Comparecimento | Abstenções reportadas | Abstenções N menos comparecimento | Nominais | Brancos | Nulos |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 472075 | 156454011 | 123682372 | 32770982 | 32771639 | 118229719 | 1964779 | 3487874 |
| 2 | 472075 | 156454011 | 124252796 | 32200558 | 32201215 | 118552353 | 1769678 | 3930765 |

Cada turno tem 47 seções com `aptos > 0`, `comparecimento = 0` e `QT_ABSTENCOES = 0`: 46 em `ZZ` e uma em `AM`, totalizando 657 aptos. Os registros permanecem na reconciliação, constam de `abstention_exceptions.csv` e são inelegíveis para modelo, sem corrigir os brutos. O extrato oficial de detalhe por município/zona gerado em 28/09/2026 registra 47 seções não instaladas por turno, com correspondência exata inclusive nas 84 combinações município-zona-turno afetadas. Essa é evidência administrativa para a discrepância, não uma imputação de abstenções ao campo original.

Tabela 2. Reavaliação das 99 exclusões legadas, unidade seção-turno.

| Turno | Nominais zero | Comparecimento zero | Exterior | Menos de 10 aptos | Votos zero no alvo 13 | Inelegíveis por discrepância | Excluídas do arquivo de contagens |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 51 | 49 | 1064 | 31 | 52 | 47 | 0 |
| 2 | 48 | 48 | 1064 | 31 | 52 | 47 | 0 |

Os 51+48 casos de nominais zero explicam as 99 exclusões do fluxo de gráficos, mas não justificam sua remoção do alvo de contagens. A tabela de modelo contém 944150 linhas, uma por seção-turno para o candidato 13. Há 472028 registros por turno marcados `model_eligible`, sem declarar que esta seja a amostra final autorizada para inferência.

## Fontes e alcance da reconciliação

Os [históricos oficiais do TSE de T1](https://dadosabertos.tse.jus.br/dataset/resultados-2022/resource/47f692af-7309-4a21-b536-0d1386d449b9) e [T2](https://dadosabertos.tse.jus.br/dataset/resultados-2022/resource/7cd53725-5dc5-4954-aee9-7dbf4097d26c), arquivados localmente pela coordenação, têm registros finais de 100% das 472075 seções e coincidem exatamente nos acumulados de aptos, comparecimento, nominais, brancos, nulos, Lula e Bolsonaro. As [notícias do TSE T1](https://www.tse.jus.br/comunicacao/noticias/2022/Outubro/100-das-secoes-totalizadas-confira-como-ficou-o-quadro-eleitoral-apos-o-1o-turno) e [T2](https://www.tse.jus.br/comunicacao/noticias/2022/Outubro/100-das-secoes-totalizadas-confira-como-ficou-o-quadro-eleitoral-apos-o-2o-turno) fornecem os controles de abstenção transcritos em `config/mebane/2022.json`; o HTML não foi arquivado. O histórico ZIP não tem abstenções como campo de controle.

Os membros **somente `_BR.csv`** dos ZIPs oficiais [detalhe município/zona](https://dadosabertos.tse.jus.br/dataset/resultados-2022/resource/0e59001a-3c9f-4a0d-a8db-7befdba22330) e [votação por candidato município/zona](https://dadosabertos.tse.jus.br/dataset/resultados-2022/resource/40fdcf49-256a-4c81-87cf-711545bd1528) cobrem 28 UFs incluindo `ZZ`, cargo Presidente e os dois turnos. A comparação por UF/turno é zero em seções **principais**, aptos, comparecimento, abstenções reportadas, nominais, brancos, nulos e seções não instaladas. Os 13 totais de candidatos-turno também coincidem por UF/turno. `QT_TOTAL_SECOES` do extrato inclui seções agregadas e não é o denominador de 472075; compara-se `QT_SECOES_PRINCIPAIS`.

Esses dois extratos trazem `DT_GERACAO=28/09/2026`, ao passo que os CSVs dos autores trazem 01/11/2022. Não houve drift **nos agregados testados**; revisões em campos não testados, linhas individuais ou autenticidade da aquisição histórica dos autores não foram certificadas. A proveniência e integridade dos quatro ZIPs constam da nota da coordenação, congelada e hasheada no manifesto. A nota lateral sobre denominadores foi contexto inspecionado; a definição de `A=N-V` e a inclusão possível de brancos em votos depositados foram conferidas diretamente no PDF local de Mebane (2023, pp. 5 e 31), sem transformar essa nota em decisão G0/G2.

## Verificação e pendências

Fixtures adversariais: duplicatas de ambos os lados, voto omitido incompatível com o total, campo ausente, candidato de turno errado, contagem faltante, metadado de eleição divergente, texto inválido e quebra da identidade de abstenção falham. A agregação independente relê os CSVs brutos, sem usar a tabela construída, e reproduz UF/turno e candidato/turno. Uma segunda execução da mesma configuração gerou nove produtos centrais byte-idênticos, registrados em `deterministic_replay.csv`. Todos os scripts de comparação encerraram com exit 0; não houve MCMC, instalação ou atualização. A QA independente ainda deve conferir hashes e reproduzir controles próprios. Nenhum resultado G1 foi promovido ao ledger.
