# Registro de execuções do estudo A/D

Todos os diretórios anteriores permanecem preservados. Este registro distingue
fixtures sintéticos de estimação empírica e complementa os manifestos individuais.

- `data/RUNS.md`: duas preparações da mesma entrada dos autores; a segunda corrige
  somente o separador do arquivo de checksums. Fontes antigas recuperadas.
- `implementation_d/RUNS.md`: desenvolvimento e testes determinísticos de D.
- `runner_checks01` e `runner_checks02`: fixtures iniciais dos diagnósticos.
- `preflight_common01`, `preflight_full01`: congelamentos anteriores à revisão.
- `review_preflight`: revisão independente encontrou AD-PREFLIGHT-01 (tempos)
  e AD-PREFLIGHT-02 (descendente resistente a SIGTERM). Nenhuma MCMC empírica.
- `timing_checks01`, `runner_checks03`, `supervisor_checks02`: reparos testados
  com engine falsa, dados sintéticos e subprocessos fictícios; todos passaram.
- `preflight_full02`: novo candidato congelado, sem mudar o contrato científico.
- `comparison_checks01`: o relatório sintético foi produzido, mas o teste do
  retorno do processo falhou por usar `system2(stderr=TRUE)`, que captura stdout
  em vez de devolver apenas o código de saída. Nenhuma MCMC ou erro de modelo.
- `comparison_checks02`: correção apenas do redirecionamento do teste; quatro
  estados do relatório e os denominadores de ESS/s passaram. Saídas sintéticas,
  inclusive o caso chamado `success`, não são resultados sobre D.C. 2010.

- `pilot01`: piloto real, liberado após revisão/adjudicação de full02. Uma
  execução A e uma D, ambas completas, sem timeout ou repetição. Raw preservados.
- `comparison01`: síntese desses outputs; ambos os modelos inconclusivos.
- `review_results`: revisão independente dos raw centrais, das 3.913 decisões
  obrigatórias e do PDF; PASS de fidelidade, não de precisão posterior.
- `results_adjudication.json` e `completion.json`: encerramento do lote finito.

Nenhuma regra do contrato v2 foi relaxada após observar resultados. Falhas de
fixtures da própria revisão estão explicadas e preservadas em `review_results`.
