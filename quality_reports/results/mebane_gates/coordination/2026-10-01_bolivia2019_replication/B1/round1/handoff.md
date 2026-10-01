# Handoff do executor B1, rodada 1

**Estado:** candidato entregue para revisão independente; B1 não foi
adjudicado nem aprovado. O escopo foi somente fontes e referência externa.
Não houve execução de código dos autores, estimação, MCMC, compilação,
instalação, download volumoso, exclusão, alteração de ambiente, mensagem
externa ou escrita fora deste diretório.

## Referência entregue

`reference_values.csv` contém 51 linhas rastreáveis: 36 resumos de nove
parâmetros globais nas cadeias 1-4, 9 resumos combinados, 4 intervalos de
totais de votos modelados como fraudulentos/manufaturados (95% e 99,5%) e
2 contagens de classificação. `extract_reference.py` recria o CSV do PDF
arquivado com `pdftotext -layout` e exige o hash do PDF e a contagem de
linhas; uma reexecução igual não sobrescreve nada. Páginas e semântica
estão em `reference_values_dictionary.md`.

Valores de referência centrais, **não** estimativas novas: total
`Nfraudtotalmean=22519.818`, intervalos 95% [20842.281, 24395.891] e
99,5% [20479.794, 24663.779]; componente manufaturado
`Ntfraudtotalmean=5295.798`, intervalos 95% [4910.488, 5734.178] e
99,5% [4751.090, 5880.218], todos na p. impressa 35/PDF 36. O log
imprime 274 mesas `fraud` e 34.277 `no fraud`. Os intervalos dos totais
são rotulados por nível, mas seu **tipo e algoritmo exatos continuam
desconhecidos** sem o pós-processamento externo. Não convertê-los em HPD.

Há discrepância entre cadeias: `beta.chi.m` vai de -0.1868573970 na
cadeia 2 a -1.5187331400 na cadeia 4, pp. impressas 30-31/PDF 31-32.
O diagnóstico MCMCSE vazio na p. 29 não é demonstração de convergência.

## Fontes e dependências

`source_manifest.json` registra cópias aditivas do PDF e dos fontes 0.0.4
de 27/10/2019, com hashes. O PDF local foi relido, inspecionado e tem
metadados de 13/11/2019. O índice público do autor mostrou o mesmo título,
data e trechos de log; a busca não conseguiu obter o PDF público diretamente,
portanto **a identidade byte a byte com o URL atual não foi certificada**.

`search_log.json` registra a busca delimitada. `Bolivia2019Clean.csv`,
`wrkef.R`, `obsfrauds_ciS.R` e o `.RData` citado não foram localizados
nesta busca, o que não prova inexistência. A URL da planilha eleitoral do
Órgano Electoral Plurinacional está na nota 5, p. impressa 2/PDF 3,
mas o workbook não foi recuperado. Nenhum espelho não oficial foi adotado.

`code_identity.md` separa: A em D.C. localmente vinculado ao qbl no commit
`3017de5`; esse commit é anterior ao log boliviano e cronologicamente
compatível; **o commit/versão de `eforensics` instalado na Bolívia é
desconhecido**. R 3.4.4 e JAGS 4.3.0 estão impressos; sementes, conteúdo
das inicializações e demais versões históricas não estão.

## Checagem independente solicitada

1. Reabrir PDF 31-32 e 35-36 e conferir cada linha, ordem, cadeia, sinal,
   expoente, algarismos, nível e localizador do CSV. Verificar p. 1/PDF 2
   contra os totais arredondados, sem substituir os valores exatos da p. 35.
2. Reexaminar se a inferência de 95% HPD para parâmetros é válida com a
   evidência disponível e preservar a incerteza sobre o commit boliviano.
3. Conferir em p. 35 a rotulagem dos funcionais e decidir se os tipos de
   intervalo e a classificação ausentes impedem a aceitação de B1 ou se
   requerem um alvo de comparação explicitamente mais estreito. Registrar
   discrepâncias materiais para adjudicação do coordenador.
4. Se houver acesso posterior à URL pública, conferir bytes/versão remota;
   não tratar a falha de acesso atual como alteração do artigo.

B2, B3, execução boliviana, G10 e qualquer aprovação de produção ficam
fora deste handoff. O coordenador controla revisão, adjudicação e release.
