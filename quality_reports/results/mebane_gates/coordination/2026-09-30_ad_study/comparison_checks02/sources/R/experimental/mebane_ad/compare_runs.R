# Summaries of an already completed paired pilot; this script never samples.
source("R/experimental/mebane_ad/io.R")
ad_setup()
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 4L)
run_root <- args[1]; contract_path <- args[2]; data_path <- args[3]; out <- args[4]
ad_new_dir(out)
contract <- jsonlite::read_json(contract_path, simplifyVector = TRUE)
data <- readRDS(data_path)
inputs <- c(contract_path, data_path, "R/experimental/mebane_ad/io.R",
            "R/experimental/mebane_ad/compare_runs.R", file.path(run_root,"execution.json"))
load_json <- function(path) {
  if (!file.exists(path)) return(NULL)
  inputs <<- c(inputs,path)
  jsonlite::read_json(path,simplifyVector=TRUE)
}
load_csv <- function(path) {
  if (!file.exists(path)) return(NULL)
  inputs <<- c(inputs,path)
  read.csv(path,stringsAsFactors=FALSE,check.names=FALSE)
}
runs <- diagnostics <- tables <- classes <- supervisors <- post_supervisors <- list()
for (model in c("A","D")) {
  runs[[model]] <- load_json(file.path(run_root,model,"run_result.json"))
  diagnostics[[model]] <- load_json(file.path(run_root,paste0(model,"_diagnostics"),"diagnostic_result.json"))
  tables[[model]] <- load_csv(file.path(run_root,paste0(model,"_diagnostics"),"diagnostics.csv"))
  classes[[model]] <- load_csv(file.path(run_root,paste0(model,"_diagnostics"),"class_probabilities.csv"))
  supervisors[[model]] <- load_json(file.path(run_root,paste0(model,"_supervisor.json")))
  post_supervisors[[model]] <- load_json(file.path(run_root,paste0(model,"_diagnostics_supervisor.json")))
  for (directory in c(model,paste0(model,"_diagnostics"))) {
    manifest <- load_json(file.path(run_root,directory,"manifest.json"))
    if (!is.null(manifest)) for (i in seq_len(nrow(manifest$files))) {
      stopifnot(ad_sha(manifest$files$path[i]) == manifest$files$sha256[i])
    }
  }
  for (record in list(supervisors[[model]],post_supervisors[[model]])) {
    if (!is.null(record)) stopifnot(ad_sha(record$log) == record$log_sha256)
  }
}
ad_snapshot(inputs,file.path(out,"consumed_sources"))
process_ok <- function(record) !is.null(record) && identical(record$returncode,0L) &&
  identical(record$timed_out,FALSE)
completed <- vapply(c("A","D"),function(model)
  !is.null(runs[[model]]) && identical(runs[[model]]$status,"sampled_not_diagnosed") &&
    !is.null(diagnostics[[model]]) && process_ok(supervisors[[model]]) &&
    process_ok(post_supervisors[[model]]),logical(1))
precision <- vapply(c("A","D"),function(model)
  !is.null(diagnostics[[model]]) &&
    identical(diagnostics[[model]]$status,"diagnostics_met_for_this_model"),logical(1))
paired_status <- if (all(completed & precision)) "exploratory-comparison-only" else "computationally_inconclusive"
safe_extreme <- function(x,fun) if (length(x) && any(is.finite(x))) fun(x[is.finite(x)]) else NA_real_
runtime <- do.call(rbind,lapply(c("A","D"),function(model) {
  r <- runs[[model]]; d <- diagnostics[[model]]; t <- tables[[model]]
  phase <- function(name) if (!is.null(r$phases[[name]]$elapsed)) r$phases[[name]]$elapsed else NA_real_
  globals <- if (!is.null(t)) t[t$group=="global",] else NULL
  data.frame(model=model,completed=completed[[model]],
             adaptation_adequate=if(!is.null(r$adaptation_adequate))r$adaptation_adequate else FALSE,
             total_process_seconds=if(!is.null(supervisors[[model]]))supervisors[[model]]$elapsed_seconds else NA_real_,
             internal_generation_seconds=if(!is.null(r))r$elapsed_seconds else NA_real_,
             setup_seconds=phase("setup"),persistence_seconds=phase("persist_raw"),
             compile_seconds=phase("compile"),adapt_seconds=phase("adapt"),
             burn_seconds=phase("burn"),sample_seconds=phase("sample"),
             postprocess_seconds=if(!is.null(post_supervisors[[model]]))post_supervisors[[model]]$elapsed_seconds else NA_real_,
             required_targets=if(!is.null(d))d$mandatory_targets else NA_integer_,
             failed_targets=if(!is.null(d))d$failed_targets else NA_integer_,
             undefined_targets=if(!is.null(d))d$undefined_required_targets else NA_integer_,
             global_rhat_max=safe_extreme(globals$rhat,max),
             global_bulk_ESS_min=safe_extreme(globals$ess_bulk,min),
             global_tail_ESS_min=safe_extreme(globals$ess_tail,min),
             diagnostic_status=if(!is.null(d))d$status else "not_available")
}))
runtime$end_to_end_compute_seconds <- runtime$total_process_seconds + runtime$postprocess_seconds
write.csv(runtime,file.path(out,"timings_diagnostics.csv"),row.names=FALSE)
common <- do.call(rbind,lapply(c("A","D"),function(model) {
  t <- tables[[model]]
  if(is.null(t))return(NULL)
  t <- t[t$group %in% c("global","scaled_functional"),]
  clock <- runtime[runtime$model==model,]
  t$ess_bulk_per_generation_process_second <- t$ess_bulk / clock$total_process_seconds
  t$ess_tail_per_generation_process_second <- t$ess_tail / clock$total_process_seconds
  t$ess_bulk_per_end_to_end_compute_second <- t$ess_bulk / clock$end_to_end_compute_seconds
  t$ess_tail_per_end_to_end_compute_second <- t$ess_tail / clock$end_to_end_compute_seconds
  t$ess_bulk_per_sampling_second <- t$ess_bulk / clock$sample_seconds
  t$ess_tail_per_sampling_second <- t$ess_tail / clock$sample_seconds
  cbind(model=model,t)
}))
if (!is.null(common)) write.csv(common,file.path(out,"common_functionals.csv"),row.names=FALSE)
class_comparison <- NULL
if (all(vapply(classes,is.data.frame,logical(1))) && length(classes)==2L) {
  ca <- classes$A; cd <- classes$D
  stopifnot(identical(ca$precinct,cd$precinct),identical(ca$class,cd$class))
  class_comparison <- data.frame(precinct=ca$precinct,class=ca$class,
                                 probability_A=ca$probability,probability_D=cd$probability,
                                 difference_D_minus_A=cd$probability-ca$probability,
                                 modal_A=ca$modal,modal_D=cd$modal)
  write.csv(class_comparison,file.path(out,"class_probabilities_compared.csv"),row.names=FALSE)
}
summary <- list(status=paired_status,case="dc2010",units=length(data$precinct),
                same_input_sha256=ad_sha(data_path),contract_sha256=ad_sha(contract_path),
                A_preserved_sha256=ad_sha(contract$A$source),
                totals=list(N=sum(data$A$N),A=sum(data$A$a),W=sum(data$A$w),
                            O=sum(data$A$N-data$A$a-data$A$w)),
                runs_complete=as.list(completed),precision_met=as.list(precision),
                production_approved=FALSE,G10_approved=FALSE,
                no_new_MCMC_in_this_script=TRUE,
                interpretation="A/D is model sensitivity, not an equality test, author-result numeric replication or evidence of electoral fraud")
ad_json(summary,file.path(out,"comparison_result.json"))
fmt <- function(x,digits=2) if(length(x)!=1L || !is.finite(x)) "NA" else
  formatC(x,format="f",digits=digits,decimal.mark=",",big.mark=".")
get_stat <- function(model,target,field) {
  t <- tables[[model]]
  if (is.null(t)) return(NA_real_)
  value <- t[t$target==target,field]
  if (length(value)==1L) value else NA_real_
}
markdown <- c("# A e D no mesmo caso: primeiro estudo experimental",
  "",paste0("Caso: Washington, D.C. 2010, dados empacotados pelos autores. Contrato: ",contract$contract_id,". Relatório gerado de resultados persistidos; nenhuma estimação ocorre nesta etapa."),
  "", "## 1. Resultado e alcance", "",
  if (paired_status=="computationally_inconclusive")
    "A comparação terminou **computacionalmente inconclusiva** pelos critérios prospectivos. Execução concluída, quando presente, não basta para tratar os resumos como estimativas posteriores confiáveis. Os valores abaixo descrevem as amostras geradas e permanecem sujeitos às falhas diagnósticas registradas." else
    "Os dois ajustes atenderam aos critérios computacionais prospectivos deste piloto. Isso permite apenas a comparação exploratória de suas saídas; não valida a identificação do mecanismo, o modelo literal A ou inferências eleitorais.",
  "", "A foi preservado integralmente. D muda a distribuição conjunta para uma multinomial e remove as contagens auxiliares Binomial(N) do qbl. As diferenças combinam essas alterações; não isolam o efeito causal de uma única mudança. Ambas as execuções usam JAGS, para não acrescentar uma troca de engine ao contraste.",
  "", "## 2. Dados e protocolo", "",
  paste0("Foram usadas as mesmas ",length(data$precinct)," unidades, na ordem original, sem exclusões. Totais: N=",fmt(sum(data$A$N),0),", A=",fmt(sum(data$A$a),0),", W=",fmt(sum(data$A$w),0),", O=",fmt(sum(data$A$N-data$A$a-data$A$w),0),". Nesta base A=NVoters-NValid é a codificação dos autores; não equivale automaticamente à abstenção efetiva brasileira. O resíduo não é identificado como votos de um único adversário."),
  "", "Quatro cadeias por modelo, 1.000 iterações de adaptação, 5.000 de aquecimento e 2.000 amostras retidas por cadeia; mesmas prioris compartilhadas, desenho intercept-only com seis efeitos por unidade, sementes e inicializações predefinidas. Um objeto rjags por modelo, A seguido de D, sem modelos concorrentes e sem extensão automática. As mesmas sementes não tornam os draws dos modelos pareados ou de igual precisão.",
  "", "## 3. Tempo e diagnósticos", "",
  "Tabela 1. Tempo de processo por modelo e diagnósticos dos 23 alvos globais. Os totais de falhas incluem também alvos locais e discretos. NA não é aprovação. Tempo, sozinho, não mede qualidade ou eficiência estatística.",
  "", "| Medida | A: qbl literal | D: multinomial |", "|---|---|---|")
labels <- c(total_process_seconds="Geração: processo completo (s)",setup_seconds="Preparação interna (s)",
            sample_seconds="Amostragem (s)",persistence_seconds="Persistência dos draws (s)",
            postprocess_seconds="Pós-processamento: processo (s)",
            end_to_end_compute_seconds="Geração + pós-processamento (s)",
            global_rhat_max="R-hat máximo, globais",global_bulk_ESS_min="ESS bulk mínimo, globais",
            global_tail_ESS_min="ESS cauda mínimo, globais",failed_targets="Alvos obrigatórios reprovados",
            undefined_targets="Alvos com diagnóstico obrigatório indefinido")
for (name in names(labels)) {
  digits <- if(name=="global_rhat_max")3L else if(name %in% c("failed_targets","undefined_targets"))0L else 2L
  markdown <- c(markdown,paste0("| ",labels[[name]]," | ",fmt(runtime[runtime$model=="A",name],digits)," | ",fmt(runtime[runtime$model=="D",name],digits)," |"))
}
markdown <- c(markdown,"", "R-hat menor que 1,01 e ESS bulk/cauda de pelo menos 400 são exigidos para todos os alvos obrigatórios. Indicadores e contagens de classe têm também teto de cinco pontos percentuais para a amplitude das médias entre cadeias, com contagens divididas por 143 nessa checagem. Indicadores raros podem ter diagnósticos indefinidos; isso mantém o resultado inconclusivo e não prova ausência de uma classe nem, isoladamente, não convergência.",
  "", "## 4. Comparação descritiva das saídas", "",
  "Tabela 2. Médias das amostras geradas, não estimativas validadas de fraude. pi são pesos da mistura, não proporções observadas de seções fraudulentas. M e S são funcionais análogos em unidades de votos esperados, calculados e agregados dentro de cada draw conjunto; as variáveis latentes subjacentes diferem entre A e D. Quantis, resultados por cadeia e diagnósticos individuais estão nos CSVs.",
  "", "| Funcional | A | D |", "|---|---|---|")
for (target in c("pi[1]","pi[2]","pi[3]","M_total","S_total")) {
  markdown <- c(markdown,paste0("| ",target," | ",fmt(get_stat("A",target,"mean"),if(startsWith(target,"pi"))4L else 1L)," | ",fmt(get_stat("D",target,"mean"),if(startsWith(target,"pi"))4L else 1L)," |"))
}
markdown <- c(markdown,"", "M representa transferências esperadas do grupo inicialmente não votante para votos no candidato focal; S representa transferências esperadas de votos inicialmente destinados aos demais candidatos. São rótulos internos do mecanismo estatístico, não eventos observados. Em cada unidade: M=N(1-tau)m e S=N tau(1-nu)s; tau é a participação inicial, nu é a preferência inicial pelo candidato focal, m e s são intensidades dependentes da classe.",
  "", "D também permite reconstruir contagens condicionadas a W, preservando a mesma classe e parâmetros de cada draw. Essas contagens secundárias ficam separadas dos funcionais M/S da tabela; não podem ser comparadas a A como se fossem o mesmo estimando, nem usadas para resgatar diagnósticos da posterior primária.",
  "", "## 5. O que ainda falta", "",
  "O qbl A conserva os contraexemplos já confirmados de probabilidades inválidas em certos estados e de contagens fora do suporte físico. D corrige o suporte por construção, mas probabilidades por seção também podem ser reproduzidas sem transferências quando os parâmetros são livres. É necessário estudar identificação, restrições hierárquicas, prioris e heterogeneidade legítima antes de qualquer conclusão eleitoral.",
  "", "Não há saída numérica externa imutável localizada para o exemplo D.C. Assim, este piloto não certifica reprodução de uma tabela publicada pelos autores e não aprova G10. G3 histórico permanece inconclusivo; os gates de validação e escala para o Brasil não foram liberados.",
  "", "A sequência posterior é diagnosticar os limites evidenciados aqui, comparar D em JAGS e Stan no mesmo alvo, completar a replicação externa e só depois avançar aos testes de identificação e ao caso brasileiro aprovado. Qualquer nova rodada deve preservar esta e fixar prospectivamente seus ajustes; não se prevê repetir até obter concordância.",
  "", "## 6. Fontes e reprodução", "",
  "Fonte empírica: Ferrari, Diogo; McAlister, Kevin; Mebane, Walter R., Jr.; Wu, Patrick Y. (2019). eforensics 0.0.4, commit 3017de537450f97a01872d0157462a68bea348ee; vignette Introduction to eforensics, 16/08/2019, exemplo D.C. 2010. Código e RDA arquivados no projeto. D é derivação experimental própria, não implementação exata dessa fonte.",
  "", "Mebane, Walter R., Jr.; Ferrari, Diogo; McAlister, Kevin; Wu, Patrick Y. (2022). Measuring Election Frauds. Manuscrito, versão de 6 de março de 2022, especificação nas páginas impressas 3-7. [Texto dos autores](https://websites.umich.edu/~wmebane/measfrauds.pdf). Cópia local preservada no projeto.",
  "", "Mebane, Walter R., Jr. (2023). Lost Votes and Posterior Multimodality in the eforensics Model. PolMeth 2023, Stanford, 9-11 de julho; versão de 2 de julho de 2023, páginas impressas 5-8. [Texto do autor](https://websites.umich.edu/~wmebane/pm23.pdf). Cópia local preservada no projeto.",
  "", "Vehtari, Aki; Gelman, Andrew; Simpson, Daniel; Carpenter, Bob; Bürkner, Paul-Christian (2021). Rank-Normalization, Folding, and Localization: An Improved R-hat for Assessing Convergence of MCMC (with Discussion). Bayesian Analysis, 16(2), 667-718. [DOI: 10.1214/20-BA1221](https://doi.org/10.1214/20-BA1221). Referência dos diagnósticos; este estudo não replica os experimentos do artigo.",
  "", "As medidas de custo separam fases internas e relógios externos. O tempo geração + pós-processamento soma os dois processos, sem contar duas vezes adaptação ou amostragem, e exclui espera pelo outro modelo, supervisor e elaboração do relatório. Os CSVs distinguem ESS/s de amostragem, geração interna, geração externa e computação total. Sem aprovação diagnóstica, esses valores não estabelecem superioridade de uma alternativa.",
  "", paste0("Entrada comum SHA-256: `",ad_sha(data_path),"`. Modelo A preservado SHA-256: `",ad_sha(contract$A$source),"`. Contrato, scripts, entradas e saídas usados são vinculados pelos manifestos do estudo. O script de reprodução deste relatório é R/experimental/mebane_ad/compare_runs.R; a renderização do PDF é separada dos cálculos."))
writeLines(markdown,file.path(out,"comparison_report.md"),useBytes=TRUE)
ad_manifest(out,note="Comparison and report computed from persisted outputs; independent result review pending")
cat(paired_status,"\n")
