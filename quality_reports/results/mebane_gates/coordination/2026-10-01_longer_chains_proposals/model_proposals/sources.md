# Fontes e limites

Consultas: 01/10/2026. A análise principal está em `proposals.md`; os hashes locais estão em `source_manifest.json`.

## Fontes primárias locais

- Mebane, Ferrari, McAlister e Wu, *Measuring Election Frauds*, versão 6/03/2022: páginas impressas 5-6, PDF 7-8; narrativa, equações (2c), (2d), (3). Extração própria `measfrauds_local_layout.txt`; ambas as páginas renderizadas e vistas.
- Mebane, *Lost Votes and Posterior Multimodality in the eforensics Model*, versão 2/07/2023: páginas impressas 5-7, PDF 7-9; equações (1), (2a), (2b), (4c), (4d). Extração própria `pm23_local_layout.txt`; três páginas renderizadas e vistas.
- `qbl_installed_3017de5.jags`, D JAGS e D Stan: fontes exatas do manifesto, não reescritas. Evidência de mecanismos, prioris, likelihood e funcionais.
- `comparison_final01`: resumos congelados usados somente para 21 alvos nominais; sem recalcular MCMC, ranking ou traços.
- `../decision.md` e pedido do coordenador: governança, confirmação pendente e recursos. Documento de decisão vivo, não congelado por este agente.

## Referências técnicas públicas

- [Stan: posteriors problemáticas](https://mc-stan.org/docs/stan-users-guide/problematic-posteriors.html): simetria de componentes e efeitos de restrições de ordenação.
- [Stan: diagnósticos](https://mc-stan.org/learn-stan/diagnostics-warnings.html): quatro cadeias, R-hat, ESS e relação com precisão; nenhum limiar demonstra identificação científica.
- [Stan Reference Manual: MCMC](https://mc-stan.org/docs/reference-manual/mcmc.html): adaptação do passo e da métrica durante warmup.
- [posterior: ess_tail](https://mc-stan.org/posterior/reference/ess_tail.html), [ess_quantile](https://mc-stan.org/posterior/reference/ess_quantile.html) e [mcse_quantile](https://mc-stan.org/posterior/reference/mcse_quantile.html): quantis-alvo, matriz iterações por cadeias, estatísticas indefinidas.
- [posterior: ess_mean](https://mc-stan.org/posterior/reference/ess_mean.html) e [mcse_mean](https://mc-stan.org/posterior/reference/mcse_mean.html): precisão de médias, distinta do ESS bulk rank-normalizado.
- [Vehtari et al. (2021), DOI 10.1214/20-BA1221](https://arxiv.org/abs/1903.08008): R-hat rank-normalizado/dobrado e ESS localizado.
- [Stan: prior predictive checks](https://mc-stan.org/docs/stan-users-guide/posterior-predictive-checks.html#prior-predictive-checks): distribuição preditiva anterior aos dados; os momentos determinísticos desta entrega não são uma checagem preditiva completa.

As páginas atuais de posterior exibiam versão 1.7.1; o manual Stan, 2.40. Uma inspeção local separada via R --vanilla resolveu posterior 1.6.1. Isso não identifica a versão que gerou os resultados antigos: não foi usado para recalculá-los. O próximo contrato deve congelar versão e tratamento de constantes/NA. Os cálculos de priori usam somente R base 4.4.2.

As referências metodológicas não endossam os valores ilustrativos de priori (.10, SD .5, taxa 20) nem as tolerâncias absolutas propostas de MCSE. Esses valores precisam de confirmação substantiva e operacional. Não foi feita busca ampla de outros artigos após a nova prioridade, nem certificada igualdade dos PDFs locais com URLs atuais.

