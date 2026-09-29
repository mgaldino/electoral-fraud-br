# Consulta documental para a prontidão 2026

Consulta do coordenador em 28/09/2026. Preparação de fontes, sem executar G7,
receber votos reais, aprovar schema ou liberar G8/G9. Páginas consultadas pelo
navegador de pesquisa; não foi arquivado seu HTML integral.

O [calendário informado pelo TSE](https://www.tse.jus.br/comunicacao/noticias/2026/Marco/eleicoes-2026-confira-as-principais-datas-do-calendario-eleitoral)
fixa 04/10/2026 para T1 e 25/10/2026 para eventual T2. Hoje antecede T1; uma
resposta HTTP ou arquivo com votos não demonstra publicação eleitoral real.

A [documentação técnica vigente](https://www.tse.jus.br/eleicoes/informacoes-tecnicas-sobre-a-divulgacao-de-resultados)
informa ambiente `oficial`, pleito 3220 e eleição federal 6257 para T1, e
orienta conferir identificadores no arquivo de configuração `ele-c.json`.
Há ambiente separado `simulado2026`; os testes podem chegar a 100% de seções.
Não inferir turno, ambiente real ou completude apenas do nome de arquivo.
A página contém trechos antigos do FAQ; as configurações efetivamente
recebidas e a documentação vigente precisam ser conciliadas, sem assumir
código de T2 por analogia.

A mesma página publica EA11 (configuração de eleições), EA16 (seções), EA18
(auxiliar da seção), EA20 (resultado unificado) e instruções de download.
O identificador IDG é único por arquivo, não comum a uma carga. A documentação
alerta para alterações de leiaute, limite de acesso e bloqueios por 404
repetidos. Evitar sondagens de URLs adivinhadas e preservar cada versão.

## Encaminhamento para G7

Recomendação operacional do coordenador: a prova `data-ready` deve verificar
proveniência, ambiente, ano, cargo, turno, cobertura e totais. Fixture sintética
com 100% de cobertura e ambiente simulado deve continuar impedida de abrir
G8/G9. Mesmo dados reais prontos não implicam `inference-ready` sem G6.
Esses controles são uma interpretação operacional a testar em G7, não um
resultado de execução já obtido nem promessa de inferência validada.

## PDFs oficiais arquivados

Aquisição em 28/09/2026 pelo navegador integrado, aba Documentos da página
técnica. `downloadMedia` retornou arquivos em `~/Downloads`, copiados sem
sobrescrita para esta pasta. Não houve desafio humano ou login. `pdfinfo`
abriu os cinco arquivos sem erro; `shasum -a 256` gerou os hashes abaixo.
Essa checagem confirma arquivos PDF legíveis, não a validação do intake G7.

Tabela 1. Integridade das referências técnicas do Tribunal Superior Eleitoral
(TSE), *Divulgação de Resultados das Eleições 2026*.

| Referência | Arquivo nesta pasta | Páginas | Bytes | SHA-256 |
|---|---|---:|---:|---|
| Instruções para download, versão 1.0, 25/05/2026 | `tse-instrucoes-para-download-dos-arquivos-da-divulgacao-2026.pdf` | 9 | 478948 | `7ec5b47839466ce306ae290b962a8a368c458900e44c13f48603ad9493ed7df5` |
| EA11, Arquivo de configuração de eleições | `tse-ea11-arquivo-de-configuracao-de-eleicoes.pdf` | 6 | 197905 | `5d3f8eb301d8602868b1e8bcf5f4eaf86ce7fb2c34548b952ca06d96b9c0ff84` |
| EA16, Arquivo de configuração de seções eleitorais | `tse-ea16-arquivo-de-configuracao-de-secoes-eleitorais.pdf` | 4 | 154377 | `5018d918c947595b82cec899e5e008424e618a4d6f02ddc5756fecafa5aaa0ab` |
| EA18, Arquivo auxiliar de seção | `tse-ea18-arquivo-auxiliar-de-secao.pdf` | 3 | 137682 | `acac3f3cb53c95209e1a5d3ec718fa20fe971c4f3e0a974b9a46f9a736d305e1` |
| EA20, Arquivo de resultado unificado | `tse-ea20-arquivo-de-resultado-unificado.pdf` | 22 | 595629 | `441a36ddc6ec45693eb55a27e3a51e04cfaf237261fd42c949291ed61748b74c` |

Fontes exatas: [Instruções](https://www.tse.jus.br/eleicoes/eleicoes-2026-content/arquivos/divulgacao-de-resultados/tse-instrucoes-para-download-dos-arquivos-da-divulgacao-2026),
[EA11](https://www.tse.jus.br/eleicoes/eleicoes-2026-content/arquivos/divulgacao-de-resultados/tse-ea11-arquivo-de-configuracao-de-eleicoes),
[EA16](https://www.tse.jus.br/eleicoes/eleicoes-2026-content/arquivos/divulgacao-de-resultados/tse-ea16-arquivo-de-configuracao-de-secoes-eleitorais),
[EA18](https://www.tse.jus.br/eleicoes/eleicoes-2026-content/arquivos/divulgacao-de-resultados/tse-ea18-arquivo-auxiliar-de-secao),
[EA20](https://www.tse.jus.br/eleicoes/eleicoes-2026-content/arquivos/divulgacao-de-resultados/tse-ea20-arquivo-de-resultado-unificado).

Os metadados de criação dos PDFs EA11/EA16/EA18/EA20 são, respectivamente,
23/06, 22/05, 22/05 e 10/07/2026. Não confundir datas de metadados do PDF com
versão declarada no texto nem assumir que futuras versões conservarão esses
bytes. Não foram adquiridos dados de votação real de 2026 nesta etapa.
