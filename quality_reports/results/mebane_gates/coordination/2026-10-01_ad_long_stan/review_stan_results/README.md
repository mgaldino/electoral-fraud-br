# Revisão independente Stan2k

Revisão concluída: [review.md](review.md) e [review.json](review.json) registram PASS de fidelidade da candidata congelada, mantendo os resultados computacionalmente inconclusivos. A execução corrigida completa é `attempt02`; houve inspeção das quatro páginas do PDF. O [manifesto final de evidências](final_evidence.json) vincula os resultados e a QA visual.

`run_repair_checks.py` e `repair_checks.R` foram executados separadamente para o reparo, com evidência em `repair_checks01/` e parecer em `repair_review.json/md`. Depois da liberação completa, o harness final foi atualizado para `stan_diagnostics02` e executado sem duplicar o adaptador de produção. `preparation.json` conserva o registro histórico da fase sem execução; `release.json` registra a autorização posterior. A tentativa falha `stan_diagnostics01` e a tentativa inicial do checker `attempt01` permanecem intactas. Tempos produtivo e falho foram verificados separadamente.

Revisor: `01a0f717-7535-72e3-baf8-4db20da81abb`. Escopo exclusivo de escrita: este diretório. Os arquivos de `review_jags_results/`, as candidatas e os resultados originais são apenas entradas.

## Código Executado

- `run_qa.py` exige registro explícito da janela liberada e hashes dos inputs. Confere os manifests da preparação e do adaptador aprovados, os resultados e a identidade independente. Cria uma tentativa nova, preserva logs e interrompe a execução em divergências. Não inicia engine nem compilação.
- `recompute_stan.R` usa diretamente `draws_array.rds` e `sampler_diagnostics.rds`. Confronta quatro CSVs com os RDS, exclui as 2.000 linhas de warmup, confere as sementes e a ordem das cadeias e recompõe os 23 globais com nomes originais do Stan. Reconstrói `mu` a partir de `alpha`, `b0`, `v` e `z`, e M/S dentro de cada draw usando o mesmo Z. Recalcula os 860 alvos internos, os critérios HMC e as 1.742 decisões comuns; mantém os resultados Rao-Blackwellizados separados.
- `check_delivery.py` reutiliza os quatro registros JAGS já revisados, confere a quinta linha Stan, as 23 diferenças D/Stan menos D/JAGS20k e os erros Monte Carlo combinados. Verifica os relógios, as tabelas do Markdown e extrai o PDF para inspeção. A renderização opcional usa ferramentas existentes e conserva as páginas geradas neste diretório. Nenhum verificador emite aprovação final automática.

As métricas usam `posterior` já instalado na biblioteca do projeto. A recomputação dos 23 globais e dos 860 internos foi integral. Para os demais alvos comuns, a revisão reaplicou todas as decisões às métricas persistidas e reconstruiu as médias e faixas das classes; não recalculou exaustivamente todos os R-hat/ESS locais.

## Vínculos Conhecidos

- Manifesto de preparação fornecido: `2ad3246c3b1a5b5e0c676a85434824644b440cc75c386bc45feeabc34b789bfb`.
- Manifesto do adaptador fornecido: `3562d593731cec1fe156ee52266a975cd0cbf6d6fe8666c26b15652298bb08b0`.
- O registro `../review/stan/review.json` declara PASS de preflight. Os hashes acima foram inicialmente lidos desse registro e da instrução; foram depois reconferidos no marco de reparo, sem revisão dos resultados finais.
- A compilação registrada é `43.1641881465912 s`, incluindo a interface C++ de densidade/gradientes. O total Stan deverá ser supervisor externo + diagnóstico externo + essa compilação uma vez. Em JAGS a compilação já integra a geração.
- A comparação JAGS anterior é reutilizada por seus CSVs e pelo PASS existente. O código novo não lê os RDS brutos JAGS.

## Execução e Reprodução

A autorização e os hashes recebidos estão em `release.json`. `release.example.json` permanece desativado. As tentativas e os arquivos de evidência existentes não devem ser sobrescritos; qualquer nova execução deve usar diretório próprio e janela autorizada.

Os inputs vinculam `../results_candidate_manifest.json` e seus 45 arquivos, além dos contratos, preparação, adaptador, reparo aprovado e QA JAGS anterior. O diagnóstico produtivo é `../stan_diagnostics02`; `../stan_diagnostics01_supervisor.json` permanece como custo falho preservado. Os caminhos no JSON são relativos à raiz do repositório.

Comando da tentativa completa executada:

```sh
python3 quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/review_stan_results/run_qa.py --release quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/review_stan_results/release.json --attempt attempt02 --stage all --render-pdf
```

O diretório da tentativa deve ser novo. Eventuais erros do próprio checker serão preservados e adjudicados antes de atribuir um defeito à candidata. Falta de Poppler deverá ser resolvida localizando a instalação existente ou o runtime empacotado, sem instalar dependências.

Se a janela numérica for liberada antes da comparação e do PDF, `--stage numerical` permite revisar os resultados já congelados sem exigir esses artefatos posteriores. Nessa etapa, bastam os manifests e supervisores dos resultados e diagnósticos; `report_markdown` pode permanecer nulo. A etapa de entrega será executada em outro diretório, com `--stage delivery --numerical-attempt attempt01 --render-pdf`, depois de receber seus hashes. O verificador reutilizará os CSVs da tentativa numérica, conferirá seus hashes e exigirá que os resultados Stan continuem idênticos. O percurso padrão `--stage all` realiza as duas etapas na mesma tentativa. Nenhuma etapa isolada encerra o goal ou emite PASS final.

Em timeout ou falha de pós-processamento, o modo será `preserved_failure`: o supervisor e um manifesto dos artefatos retidos serão vinculados e o cálculo posterior não será chamado. Se não houver comparação/PDF de falha, esses campos poderão ficar ausentes; o registro explicitará o limite da entrega. Se houver, sua fidelidade será examinada sem preencher resultados faltantes.

## Fechamento

A inspeção de todas as páginas renderizadas foi concluída, incluindo alinhamento e completude das tabelas, números, captions, cortes de texto, glifos, quebras de página e referências. A extração textual foi apenas complementar. `review.json/md` registra hashes, evidências e limites, com `pass` restrito à fidelidade da entrega. Precisão posterior, produção e gates históricos continuam fora dessa decisão.
