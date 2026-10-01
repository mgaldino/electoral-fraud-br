# Presentation only: all numerical summaries are calculated by compare_engines.R.
source("R/experimental/mebane_ad/io.R")
ad_setup()
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==2L,!file.exists(args[2]))
input <- args[1]
t <- read.csv(file.path(input,"timings_diagnostics.csv"),check.names=FALSE)
g <- read.csv(file.path(input,"global_functionals.csv"),check.names=FALSE)
groups <- read.csv(file.path(input,"diagnostic_groups.csv"),check.names=FALSE)
diff_path <- file.path(input,"D_engine_differences.csv")
d <- if(file.exists(diff_path))read.csv(diff_path,check.names=FALSE) else NULL
fmt <- function(x,digits=2L) {
  if(length(x)!=1L||!is.finite(x))return("NA")
  formatC(x,digits=digits,format="f",decimal.mark=",",big.mark=".")
}
table_rows <- function(values)apply(values,1,function(row) paste0("| ",paste(row,collapse=" | ")," |"))
lines <- c("# JAGS 20 mil e Stan 2 mil: comparação no mesmo caso",
  "", "Experimento de 1 de outubro de 2026. Dados D.C. 2010, 143 unidades. Preserva A, estuda D e compara D entre JAGS e Stan. Não é uma nova estimação para o Brasil nem uma validação inferencial do modelo.",
  "", "## 1. Pergunta e protocolo", "",
  "A hipótese proposta pelo usuário é que JAGS necessita de cadeias mais longas, enquanto 2 mil amostras por cadeia podem ser suficientes em Stan. Esta rodada testa essa possibilidade, sem pressupor que o número nominal de iterações determine a precisão.",
  "", "A é o qbl literal, mantido byte a byte. D é a alternativa multinomial experimental, com as mesmas prioris hierárquicas compartilhadas, mas sem as contagens auxiliares binomiais de A. A versus D é sensibilidade ao modelo. D/JAGS versus D/Stan compara o mesmo alvo posterior, sujeito à verificação numérica e aos diagnósticos de cada algoritmo.",
  "", "JAGS: quatro cadeias, 1.000 iterações de adaptação, 5.000 de aquecimento e 20.000 retidas por cadeia. Stan: quatro cadeias, 2.000 de aquecimento e 2.000 retidas por cadeia, adapt_delta=0,99 e profundidade máxima 12. Thin=1. As cadeias são processadas serialmente em ambos os casos. Há limite externo de 3.600 segundos por processo e nenhuma repetição automática.",
  "", "As rodadas JAGS de 2 mil e 20 mil reutilizam dados, inicializações e sementes; não são replicações independentes. O ajuste Stan usa semente-base 1001261 com identificadores de cadeia 1 a 4. Os processos intensivos do experimento foram separados para não contaminar os relógios. Desenvolvimento e leitura estática ocorreram em paralelo; não se presume controle de todos os demais aplicativos do computador.",
  "", "Stan integra a classe discreta usando a soma das três verossimilhanças ponderadas, em escala logarítmica. A parametrização não centrada preserva as seis variâncias com prior Exp(5), usando raiz quadrada para os desvios-padrão. Os pesos são (1,r2,r3)/(1+r2+r3), com r2 e r3 uniformes independentes: essa é a prior efetiva do esquema auxiliar ordenado de JAGS, não uma Dirichlet flat nem uma ordenação total entre as classes 2 e 3.",
  "", "Uma classe posterior condicional é reconstruída por unidade e draw; essa mesma classe determina probabilidades e funcionais M/S. Médias Rao-Blackwellizadas, que integram também essa reconstrução, ficam em resultados secundários separados. Nenhuma alteração de prior foi usada como solução para dificuldades de mistura.",
  "", "## 2. Tempos e critérios computacionais", "",
  "Tabela 1. Relógios de parede por execução, em segundos, e diagnósticos dos 23 alvos globais. Geração inclui o processo completo e gravação dos draws. A compilação JAGS já está dentro desse processo; a compilação Stan é medida separadamente e somada uma única vez no total. O relógio de compilação Stan inclui a interface C++ de checagem de densidade e gradientes; outras verificações e tentativas de desenvolvimento ficam fora do tempo do ajuste. Total = geração + diagnóstico + essa compilação Stan, quando aplicável. As duas primeiras linhas são o piloto histórico preservado.",
  "", "| Rodada | Geração (s) | Diagnóstico (s) | Total (s) | R-hat máximo | ESS mínimo bulk/cauda |",
  "|---|---|---|---|---|---|")
for(i in seq_len(nrow(t))) lines <- c(lines,paste0("| ",t$id[i]," | ",fmt(t$generation_process_seconds[i]),
  " | ",fmt(t$diagnostic_process_seconds[i])," | ",fmt(t$total_compute_including_compilation_seconds[i]),
  " | ",fmt(t$max_global_Rhat[i],3)," | ",fmt(t$min_global_bulk_ESS[i],1)," / ",fmt(t$min_global_tail_ESS[i],1)," |"))
lines <- c(lines,"", "R-hat é um diagnóstico de concordância entre cadeias. ESS é o tamanho efetivo da amostra, distinto do número nominal de draws. Exigem-se R-hat < 1,01 e ESS bulk e cauda >= 400 para todos os alvos obrigatórios; as classificações têm também limite prospectivo de discrepância entre cadeias. Estatísticas indefinidas não recebem aprovação automática, mas sua indefinição isolada tampouco demonstra não convergência.",
  "", "Tabela 2. Falhas dos critérios prospectivos. A coluna de indefinidos é subconjunto das falhas, não um grupo a somar. Falhas globais e locais são separadas dos indicadores de classes raras no CSV diagnostic_groups.csv.",
  "", "| Rodada | Globais reprovados / 23 | Obrigatórios reprovados | Obrigatórios totais | Indefinidos |",
  "|---|---|---|---|---|")
for(i in seq_len(nrow(t)))lines <- c(lines,paste0("| ",t$id[i]," | ",fmt(t$global_failures[i],0)," | ",
  fmt(t$failed_targets[i],0)," | ",fmt(t$mandatory_targets[i],0)," | ",fmt(t$undefined_targets[i],0)," |"))
for(i in 3:5)lines <- c(lines,"",paste0(t$id[i],": execução e diagnóstico completos = ",t$completed[i],"; status = ",t$status[i],"."))
hmc_path <- "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/stan_diagnostics01/HMC_by_chain.csv"
if(file.exists(hmc_path)) {
  h <- read.csv(hmc_path)
  lines <- c(lines,"", "Tabela 3. Diagnósticos específicos de Hamiltonian Monte Carlo (HMC). Exigem-se zero divergências, zero atingimentos da profundidade máxima e E-BFMI >= 0,3 em cada cadeia. E-BFMI mede a exploração da distribuição de energia. Os 860 parâmetros internos da parametrização não centrada recebem também os critérios R-hat/ESS, separadamente dos alvos comuns.",
    "", "| Cadeia | Divergências | Profundidade máxima atingida | E-BFMI |", "|---|---|---|---|")
  for(i in 1:4)lines <- c(lines,paste0("| ",h$chain[i]," | ",h$divergences[i]," | ",h$treedepth_hits[i]," | ",fmt(h$ebfmi[i],3)," |"))
  lines <- c(lines,"",paste0("Critérios HMC atendidos: ",t$HMC_pass[5],". Parâmetros internos reprovados: ",fmt(t$NCP_failed[5],0)," de 860. A precisão dos resultados comuns continua sujeita à Tabela 2; bom comportamento HMC não dispensa esses controles."))
}
lines <- c(lines,"", "## 3. Comparação descritiva entre engines", "",
  "Os resumos seguintes descrevem draws, não eventos eleitorais observados. pi são pesos de mistura. M=N(1-tau)m e S=N tau(1-nu)s representam transferências esperadas no mecanismo estatístico: tau é participação inicial, nu é preferência inicial pelo candidato focal, m e s são intensidades da classe latente. As somas são feitas dentro de cada draw conjunto, preservando dependência.")
if(!is.null(d)) {
  lines <- c(lines,"", "Tabela 4. D no mesmo alvo: médias amostrais JAGS 20 mil versus Stan 2 mil. A última coluna divide a diferença Stan-JAGS pela raiz da soma dos quadrados dos erros-padrão Monte Carlo (MCSE). É descritiva, não um teste de equivalência; MCSE não é uma referência confiável se a exploração posterior falhou.",
    "", "| Funcional | JAGS 20 mil | Stan 2 mil | Diferença | Diferença / MCSE combinado |", "|---|---|---|---|---|")
  for(target in c("pi[1]","pi[2]","pi[3]","M_total","S_total")) {
    r <- d[d$target==target,];digits <- if(startsWith(target,"pi"))4 else 1
    lines <- c(lines,paste0("| ",target," | ",fmt(r$JAGS_mean,digits)," | ",fmt(r$Stan_mean,digits)," | ",fmt(r$difference_Stan_minus_JAGS,digits)," | ",fmt(r$descriptive_MCSE_units)," |"))
  }
}
lines <- c(lines,"", "Tabela 5. Médias de M e S por cadeia nas novas rodadas. Diferenças persistentes entre cadeias são importantes mesmo quando uma média agregada parece plausível. Estes valores não são contagens comprovadas de fraude.",
  "", "| Rodada / funcional | Cadeia 1 | Cadeia 2 | Cadeia 3 | Cadeia 4 |", "|---|---|---|---|---|")
for(id in t$id[3:5])for(target in c("M_total","S_total")) {
  r <- g[g$id==id & g$target==target,]
  if(nrow(r)==1)lines <- c(lines,paste0("| ",id," / ",target," | ",paste(vapply(r[paste0("chain",1:4)],fmt,character(1),digits=1),collapse=" | ")," |"))
}
lines <- c(lines,"", "## 4. Alcance e próximos passos", "",
  "O número de iterações deve ser julgado pela precisão obtida, não pela reputação da engine. Tempos e ESS por segundo somente sustentam uma comparação de eficiência nos alvos cuja precisão esteja demonstrada. Este experimento não decide que uma prior é errada a partir de dificuldade de amostragem e não trata a execução JAGS anterior como prova suficiente de convergência.",
  "", "A implementação Stan preserva o alvo, mas combina HMC, parametrização não centrada e marginalização das classes e da escala auxiliar dos pesos. Assim, uma diferença de desempenho se refere a essas implementações completas; não identifica isoladamente o efeito de trocar Gibbs por HMC.",
  "", "A permanece preservada, com seus limites de suporte já documentados. D corrige o suporte conjunto por construção, mas ainda requer estudo de identificação, heterogeneidade legítima, recuperação em dados sintéticos e replicação externa com referência numérica dos autores. Esses requisitos científicos não são resolvidos apenas por cadeias mais longas ou HMC.",
  "", "Nenhum gate histórico foi retroativamente aprovado. G3 permanece inconclusivo e G10 continua pendente de replicação numérica externa. Não houve nova estimação brasileira, mudança de filtros dos dados ou adoção de engine de produção. Os dados D.C. usam A=NVoters-NValid na codificação dos autores; não se deve transportar esse denominador automaticamente para abstenção no Brasil.",
  "", "O próximo passo deve partir do diagnóstico observado nesta rodada: distinguir dificuldades globais/locais de indicadores discretos raros, examinar a geometria e as cadeias preservadas e definir qualquer nova intervenção prospectivamente. Depois da validação do alvo e da replicação externa, retomar o caso brasileiro aprovado e os gates de escala/ingestão de 2026.",
  "", "## 5. Fontes e reprodução", "",
  "Ferrari, Diogo; McAlister, Kevin; Mebane, Walter R., Jr.; Wu, Patrick Y. (2019). eforensics 0.0.4. Commit 3017de537450f97a01872d0157462a68bea348ee. Vignette Introduction to eforensics, 16/08/2019; dados D.C. 2010. [Repositório dos autores](https://github.com/UMeforensics/eforensics_public). Snapshot local preservado. D é uma derivação experimental deste projeto, não uma implementação publicada pelos autores.",
  "", "Mebane, Walter R., Jr. (2023). Lost Votes and Posterior Multimodality in the eforensics Model. PolMeth 2023, Stanford, 9-11 de julho; versão de 2 de julho de 2023. [Texto do autor](https://websites.umich.edu/~wmebane/pm23.pdf).",
  "", "Vehtari, Aki; Gelman, Andrew; Simpson, Daniel; Carpenter, Bob; Bürkner, Paul-Christian (2021). Rank-Normalization, Folding, and Localization: An Improved R-hat for Assessing Convergence of MCMC (with Discussion). Bayesian Analysis, 16(2), 667-718. [DOI 10.1214/20-BA1221](https://doi.org/10.1214/20-BA1221).",
  "", "Stan Development Team. Stan User's Guide: Latent Discrete Parameters; Diagnostics and Warnings. [Marginalização](https://mc-stan.org/docs/stan-users-guide/latent-discrete.html) e [diagnósticos](https://mc-stan.org/learn-stan/diagnostics-warnings.html), consultados em 01/10/2026. A documentação web consultada é atual; a engine instalada e usada é CmdStan 2.37.0, via cmdstanr 0.9.0.",
  "", "Cálculos: R/experimental/mebane_ad_long/compare_engines.R, a partir dos diagnósticos persistidos. Apresentação: R/experimental/mebane_ad_long/write_report.R. Renderizador PDF preservado do estudo anterior. Contrato, revisão, fontes, dados e resultados estão vinculados pelos manifestos desta rodada; draws/CSV grandes e binários permanecem localmente preservados, sem excluir artefatos históricos nem instalar pacotes.")
writeLines(lines,args[2],useBytes=TRUE)
