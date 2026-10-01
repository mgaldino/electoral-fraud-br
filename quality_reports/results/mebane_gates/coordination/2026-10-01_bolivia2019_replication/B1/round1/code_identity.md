# Identidade do código: limites da evidência B1

**Demonstrado localmente, mas somente para A em D.C.** O contrato congelado
`2026-09-30_ad_study/contract_v2.json` aponta o modelo A para
`G0/round1/qbl_installed_3017de5.jags` (SHA-256
`f8360126424b7a463f76a1c99efc89a8a5cb81339213bd4931559f14595fbab6`).
O registro `G0/round1/loads_environment.json` declara `eforensics` 0.0.4,
`RemoteSha=3017de537450f97a01872d0157462a68bea348ee` e
`qbl_reference_equal=true` para a comparação feita naquele gate entre o
`qbl()` instalado e o fonte arquivado. B1 leu esse registro e reconferiu
hashes dos fontes copiados; **não reexecutou** a comparação nem um modelo.
Isso não vincula o pacote instalado por Mebane em outubro de 2019.

**Compatibilidade cronológica, não identidade boliviana.** O JSON da API
GitHub arquivado atribui ao commit candidato `3017de5...` a data UTC
27/10/2019 04:11:09 e a mensagem `version 0.0.4 misc fixes including output
of samples`. Seu `DESCRIPTION` diz 0.0.4. O log da Bolívia no PDF mostra
JAGS iniciando em 28/10/2019 (fase inicial) e 29/10/2019 (amostra final),
logo esse commit antecede as execuções e **poderia** ter sido instalado.
O PDF imprime `library(eforensics)` e a chamada `model="qbl"`, mas não
`packageVersion()`, `sessionInfo()`, `RemoteSha`, tarball ou hash de fonte.
Assim, o commit exato e mesmo a versão instalada na Bolívia são **desconhecidos**.
Nome do modelo e datas não provam igualdade byte a byte nem semântica exata
do wrapper. O pacote 0.0.4 é uma candidata contemporânea para B3, não uma
reconstrução certificada do ambiente histórico.

**Ambiente efetivamente impresso no PDF.** `runef4 Bolivia2019Clean 4c.Rout`,
p. impressa 24 (PDF 25), identifica R 3.4.4, plataforma
`x86_64-pc-linux-gnu`. As pp. 26-29 (PDF 27-30) identificam JAGS 4.3.0,
`basemod` e `bugs`, quatro simulações paralelas e os arquivos nomeados
`inits1.txt`, `inits2.txt`, `inits3.txt` nas partes visíveis. O log não
publica o conteúdo das inicializações, sementes, estados finais, versões de
`rjags`, `runjags`, `coda`, `mcmcse` ou do sistema. Não há certificação de
seeds/inits históricos. O arquivo de saída `runef4_Bolivia2019Clean_4c.RData`
é nomeado na p. 29, não fornecido pelo PDF.

**Precisão dos intervalos globais.** O resumo impresso usa cabeçalhos
`HPD.lower` e `HPD.upper`. No `archive/ef_summary_3017de5.R`, a função
`summary.eforensics` chama `coda::HPDinterval` sem argumento `prob`; o padrão
documentado de `coda` é 0,95. O CSV registra 95% HPD com essa qualificação.
A função externa `effrauds_obs` e os scripts `wrkef.R` e `obsfrauds_ciS.R`
não estão no snapshot encontrado, de modo que o **tipo** de intervalo dos
totais 95%/99,5% e a regra operacional de classificação não podem ser
certificados a partir do fonte disponível.

**Sem convergência presumida.** O log mostra um diagnóstico MCMCSE como
tibble vazia, não um certificado. As médias de `beta.chi.m` por cadeia são
-0.3338680365, -0.1868573970, -0.3449911565 e -1.5187331400 (pp.
impressas 30-31). A média combinada de -0.5961124325 não apaga essa
discordância. A qualidade da amostragem deve ser avaliada depois e não
pode ser inferida de `Estimation Completed`.

Fontes primárias: [PDF do autor](https://websites.umich.edu/~wmebane/Bolivia2019.pdf),
[commit candidato do pacote](https://github.com/UMeforensics/eforensics_public/commit/3017de537450f97a01872d0157462a68bea348ee),
[documentação de `coda::HPDinterval`](https://rdrr.io/cran/coda/man/HPDinterval.html).
