# SOL-METODO: requisitos para os gates Mebane Brasil 2022/2026

Data: 2026-09-28. Esta é uma auditoria preparatória do futuro plano, não uma revisão independente
final, estimação ou autorização para publicar resultados. Goal criado sem `token_budget`:
auditar riscos e critérios metodológicos e entregar esta nota.

Todos deste subagente realizados: [x] inspecionar o código e as fontes locais indicadas;
[x] confrontar resumos e logs com handoffs e plano; [x] propor gates e escaladas;
[x] preservar código, dados e PDFs. Fora deste goal: adjudicação pelo modelo principal e
revisão independente do plano futuro.

## Achados que o plano precisa resolver

1. **Alvo operacional.** O `eforensics` instalado é 0.0.4, do repositório
   `UMeforensics/eforensics_public`, SHA `3017de537450f97a01872d0157462a68bea348ee`
   (DESCRIPTION na biblioteca `renv` local). Inspecionei `eforensics:::qbl()` sem ajustar modelo.
   A nota [05_stan_validation_note.md](../05_stan_validation_note.md) é sobretudo uma
   auditoria do `bl()`, posteriormente atualizada para apontar `qbl()` como alvo
   (linhas 1-16, 184-208). Não constitui validação completa de paper versus `qbl()` versus
   Stan. O [prompt antigo](../../plans/stan_port_prompt.md) escreve, para `Z=1`,
   `w ~ Binomial(N-a, nu)` (linhas 61-71); o `qbl()` instalado e
   [Stan](../../../stan/eforensics_qbl.stan) usam `w ~ Binomial(N, nu*(1-a/N))`
   (Stan, linhas 191-204). Não chamar essas likelihoods de iguais sem derivação.

2. **Precisão, variância, priors e interceptos.** No JAGS local, `pi.aux1 ~ U(0,1)`,
   `pi.aux2,pi.aux3 ~ U(0,pi.aux1)` e `pi` é normalizado. A transformação Stan em dois
   ratios uniformes é plausível, mas requer demonstração da densidade induzida e teste
   prior-predictive. `dmnorm(mu.beta.*, sigma.beta.*)` recebe uma **matriz de precisão**,
   apesar do comentário JAGS dizer *variance*: precisão 10000 para o intercepto fixo
   implica variância 0,0001 e SD 0,01; precisão 1 para demais coeficientes implica SD 1.
   `*.alpha ~ dnorm(0,1)` usa precisão 1. `tb,nb,imb,isb,cmb,csb ~ dexp(5)` entram
   como precisão inversa dos efeitos aleatórios, logo são **variâncias**; `sqrt(*)` é SD
   ([Stan](../../../stan/eforensics_qbl.stan), linhas 90-125, 147-183, 210-220;
   [comparação](../05_compare_fits.md), linhas 29-33). O JAGS soma o intercepto fixo
   quase nulo ao efeito aleatório centrado em `alpha`; Stan elimina esse intercepto.
   Uma diferença pequena não é identidade de prior nem de parâmetro, sobretudo com FE.

3. **Contagens discretas, suporte e clamp.** O JAGS gera `N.iota.*`, `N.chi.*` como
   binomiais condicionais a `N` e usa as proporções **realizadas**. Quando `iota.m` ou
   `chi.m` são exatamente 1, substitui 0,999 antes de `p.w`. Stan substitui os quatro
   counts por magnitudes contínuas
   ([Stan](../../../stan/eforensics_qbl.stan), linhas 1-24, 139-145, 185-207).
   Isso muda variância e suporte: uma proporção `iota` realizada pode exceder `k=0,7`
   e uma `chi` pode ficar abaixo de `k`, apesar de suas médias estarem nos intervalos
   respectivos. O efeito pode ser importante para `N` pequeno. Stan ainda trunca
   denominadores em `1e-9` e probabilidades em `[1e-9,1-1e-9]` (linhas 26-45,
   187-204), regra diferente da do JAGS. Um clamp de probabilidade inválida pode
   transformar incompatibilidade de suporte em likelihood finita. Validar `N>0`,
   `0<=a<=N`, `0<=w<=N-a`, integralidade e duplicatas; a verificação `w<=N-a` falta em
   [05_stan_eforensics_qbl_calibrate.R](../../../R/05_stan_eforensics_qbl_calibrate.R),
   linhas 123-130.

4. **Convergência não estabelecida.** No JAGS fresco intercept-only, o Rhat legado/coda
   é 1,24 para `pi[1:2]`, 4,17 para `iota.m.alpha` e 12,84 para `imb`
   ([resumo](../05_eforensics_qbl_brasilia_fresh_v2_summary.txt), linhas 29-51).
   Com FE por zona, Rhat chega a 4,60/4,62 para `pi[1:2]` e 13,51-20,19 para
   `iota.*.alpha` ([resumo](../05_jags_qbl_zone_fe_summary.txt), linhas 34-60).
   O [Stan n=2000](../05_stan_qbl_brasilia_log_n2000.md) é **smoke test** de 2 cadeias,
   500 warmup e 250 amostras; `Ft`, `Fw` e `stolen_votes` têm Rhat 1,21-1,23 e
   ESS_bulk 8,24-9,24 (linhas 16-18, 25-33, 55-64). Zero divergências nesse teste não
   o valida. A [comparação salva](../05_compare_fits.md) contém apenas JAGS IO e FE,
   sem Stan e sem `Ft/Fw` JAGS (linhas 5-27).

5. **Handoffs são hipóteses.** O [handoff qbl](../05_stan_qbl_session_handoff.md)
   chama o fit antigo de modo errado **causado** por burn-in curto e o novo de
   benchmark correto (linhas 10-28, 118-125); atribui Rhat alto necessariamente à
   não identificação porque `pi` parece pequeno (58-67); aceita `pi` até Rhat 1,30 e
   dispensa diagnóstico de magnitudes (144-156); interpreta `iota.s.alpha` negativo
   como suporte da nula apesar de Rhat 13,5 (177-205); e afirma que relaxar counts
   não altera quantidades (110-116). Nada disso foi demonstrado pelos logs citados.
   O logit agregado de comparecimento no
   [diagnóstico fresco](../../../R/05_eforensics_qbl_fresh_diagnostic.R), linhas 161-173,
   é sanity check, não prova de modo correto nem de causa da falha anterior. O contraste
   Stan n=2000 versus JAGS n=6748 também não é paridade.

6. **Escopo e interpretação.** O [plano antigo](../../plans/2026-04-10_reconstrucao-metodologica.md)
   é explicitamente só para 2022 (linhas 1-17, 250-258), ainda chama o fork Ferrari
   de canônico (275-280) e antecipa as curvas esperadas de poder como critério de
   conclusão (133-167, 260-267). O pedido atual amplia o **planejamento** para 2026,
   não cria dados nem resultados de 2026. A afirmação do plano de que magnitudes
   negativas seriam evidência afirmativa de ausência de fraude (111-116) excede a
   interpretação condicionada em `PA2024.pdf`, pp. 4-6. Não converter sinal ou
   não rejeição em ausência de fraude. O PDF recém-adicionado `ssrn-4073770.pdf` foi
   apenas identificado como Kalinin (2022), comparação de métodos; não o usei como
   validação do `qbl()` ou de dados brasileiros.

## Gates e critérios de aceite propostos

**G0. Escopo, proveniência e estimandos: bloqueante antes de fit.** Separar entregas
retrospectivas de 2022 e prospectivas de 2026. Congelar turno, candidato beneficiado,
universo de seções, `N`, `a`, `w`, exclusões, fonte oficial, data de acesso, versões/hashes,
seeds e estimandos. Para 2026, abrir execução somente com dados oficiais definidos e
auditados, sem pressupor resultado ou cobertura equivalente. Aceite: manifesto e
dicionário reproduzíveis; contagens e somas conciliadas por UF/turno/candidato; regra
explícita para zero votos e `V>N`; chave única e regras lógicas verificadas. Escalar
qualquer mudança de universo, candidato, especificação ou alvo inferencial entre anos.

**G1. Contrato paper/JAGS/Stan: bloqueante antes de chamar Stan de port.** Alinhar,
equação por equação, o paper Mebane 2023, `qbl()` congelado e Stan: processo generativo
versus likelihood condicionada em `a`, prior de `pi`, `k`, seis efeitos aleatórios,
interceptos/FE, precisão/variância/SD, counts, suporte, clamps e `Ft`, `Fw`, `Fw-Ft`.
Classificar cada linha como `igual por demonstração`, `aproximação testável`,
`divergente` ou `indeterminada`; anexar derivação e teste, não só comentário de código.
O [Stan](../../../stan/eforensics_qbl.stan), linhas 228-265, soma responsabilidades
posteriores e magnitudes médias contínuas para `Ft/Fw`: verificar se o estimando e sua
incerteza coincidem com a computação JAGS por draw usando `Z` e counts. Aceite: contrato
revisado independentemente; nenhuma declaração de equivalência antes de G2. Se a
aproximação permanecer, rotulá-la como modelo distinto e medir o efeito em quantidades
substantivas, não só em `pi`.

**G2. Paridade small-N e simulação: bloqueante antes de escalar.** Criar harness
reexecutável em R que enumere `Z` e os quatro counts para `N` pequeno e compare
log-likelihood sob parâmetros e dados idênticos. Separar (a) álgebra da versão
relaxada, (b) diferença dos counts e (c) efeito de clamps. Incluir `N` pequeno e
típico; `a=0/N`, `w=0/N-a`; `mu` perto de 0/k/1; FE nulos e ativos. Testar priors
por simulação prior-predictive e o intercepto efetivo `alpha + beta[1]`. Depois
simular do **qbl congelado**, não apenas de `simulate_bl`, com nula e alternativas
incremental/extrema, classes raras/frequentes, tamanhos/geografias variados; comparar
cobertura, calibração, viés, incerteza Monte Carlo, classes e `Ft/Fw` por draw. Aceite:
tolerâncias numéricas e substantivas fixadas antes dos resultados; discrepâncias por
`N`/cenário com intervalos e custo. Proximidade de médias ou sobreposição de intervalos
não demonstra paridade. Se falhar, manter JAGS como alvo operacional ou reformular Stan.

**G3. Diagnóstico de posterior e sampler: bloqueante por estimando publicado.** Para
cada especificação final, pelo menos 4 cadeias independentes, iniciais dispersas
inclusive modos plausíveis, warmup/adaptação documentados, trace/rank plots e diagnóstico
de **todas** as quantidades interpretadas: `pi`, turnout/vote choice, magnitudes e FE,
hiperparâmetros, `Ft`, `Fw`, `Fw-Ft`, unidades flagged e margem contrafactual. Propor
Rhat rank-normalized split <=1,01 e ESS_bulk/tail >=400 como piso inicial por quantidade;
MCSE da média <=5% da SD posterior e MCSE dos quantis/caudas pequeno frente à tolerância
decisória predefinida. Para IC 99,5%, medir estabilidade das caudas. Stan: divergências
persistentes zero, BFMI/treedepth documentados; JAGS: autocorrelação, ESS/MCSE por draw,
comparação entre cadeias/modos. Falha ou `NA` não passa. Dip test e `M(pi)` complementam,
mas não substituem Rhat/ESS/MCSE. Se apenas um subconjunto passa, liberar **só esse
subconjunto**, com limites e sensibilidade; não interpretar sinal de alpha ou "nula" geral.
`pi` perto de zero não desculpa ausência de convergência.

**G4. Identificação e sensibilidade: antes de inferência substantiva.** Demonstrar
recuperação com verdade simulada e comparar prior versus posterior de `pi`, magnitudes e
quantidades finais; mapear ridges, modos, classes raras e efeito do prior ordenado.
Separar não identificação estrutural de cadeias presas, especificação errada, FE
insuficientes e baixo número efetivo. Fazer posterior predictive checks por tamanho de
seção/UF. Pré-especificar sensibilidade a priors, `k`, FE, escala geográfica, `N` pequeno,
lost votes, candidato, denominador, zeros/exterior e mudança 2022-2026. Aceite:
resultados robustos ou limites explicitamente rotulados. Sem convergência de coeficientes
de fraude, não interpretar seus sinais ou IC nem a narrativa estratégico/malevolente.
FE municipais, partição ou subamostra não são soluções automáticas: piloto de custo e
identificação e justificativa de mudança de estimando são obrigatórios.

**G5. Margem contrafactual: bloqueante para claim sobre resultado eleitoral.** Não
comparar `Fw` diretamente à margem observada como teste de reversão. O
[plano antigo](../../plans/2026-04-10_reconstrucao-metodologica.md), linhas 105-120,
e `PA2024.pdf`, pp. 3-5, fazem comparação descritiva, mas não definem o impacto na
margem. Especificar **por draw** os totais contrafactuais de cada candidato e a origem
dos votos subtraídos. Retirar voto manufaturado do beneficiado muda sua contagem em um;
reverter transferência **do adversário da margem** retira um do beneficiado e devolve
um ao adversário, mudando a margem em dois. Transferência de outro candidato, branco ou
nulo tem efeito diferente. `qbl` agrega todos os não-leaders em `w`: a origem de votos
"stolen" não é identificada sem suposições ou dados adicionais. Propor limites e cenários
de alocação, rotulados como identificação parcial. Somar contribuições conjuntas **por
draw** e obter a distribuição da margem contrafactual e do evento de reversão; não
subtrair médias nem somar/subtrair limites de intervalos marginais. Aceite: álgebra
auditada independentemente, conservação de votos onde aplicável, unidades e incerteza
conjunta, sensibilidade ao doador/turno. Nenhum resultado empírico é derivado aqui.

**G6. Poder, detectabilidade e 2026: antes da conclusão.** O Bloco 4 antigo chama
2022 observado de baseline "limpo"
([plano](../../plans/2026-04-10_reconstrucao-metodologica.md), linhas 133-161),
hipótese não verificada. Separar poder sob DGP nulo conhecido, detecção de perturbações
de dados observados e robustez à especificação; medir tamanho/falsos positivos,
inclusive anomalias inocentes. Pré-especificar mecanismos contabilmente válidos,
amostra, geografia, magnitude em votos/margem, réplicas, sucesso e taxa de ajustes que
falham. Não descartar réplicas com MCMC ruim. Calcular IC Monte Carlo e pilotar custo e
precisão antes de escolher A/B/C; a curva não precisa confirmar a expectativa do plano.
Em 2026, adaptar gerador e universo a dados oficiais novos e repetir G0-G5; poder ou
identificação de 2022 não são automaticamente transportáveis. Na matriz de
detectabilidade, cada célula precisa de cenário validado; "invisível" só vale dentro
do mecanismo e domínio demonstrados.

## Delegação, capacidade do Sol e escaladas

Converter os gates em todos rastreáveis: dono, input congelado, artefato e critério de
aceite. GPT-6 Sol pode preparar manifestos, harness, simulações, QA, diagnósticos,
pilotos de custo, tabelas e notas, sujeito aos gates e à revisão independente. Não
restringir sua capacidade por suposição ligada ao nome do modelo; avaliar entregas por
testes reexecutados, contratos coerentes, discrepâncias resolvidas e QA de outputs.
Medir tempo e recursos em piloto antes de selecionar sampler ou escala. Um subagente
implementa; outro audita derivação, dados, scripts e resultados contra fontes congeladas,
sem editar simultaneamente os mesmos arquivos. O modelo principal adjudica mudanças de
estimando, Stan aproximado versus JAGS, exceções a thresholds, falhas G2/G3,
interpretação de sinais/identificação, margem e transporte 2022-2026. Esta nota não é
o parecer do revisor independente do plano.

## Fontes e limites da verificação

- Código lido: `stan/eforensics_qbl.stan`, `R/05_eforensics_qbl_fresh_diagnostic.R`,
  `R/05_jags_qbl_zone_fe.R`, `R/05_stan_eforensics_qbl_calibrate.R`, modelo
  `eforensics:::qbl()` extraído em modo de leitura e DESCRIPTION do pacote instalado.
- Evidência histórica lida: `quality_reports/results/05_stan_validation_note.md`,
  `05_stan_qbl_session_handoff.md`, ambos os resumos JAGS, log Stan n2000,
  `05_compare_fits.md`, `bloco3_session_handoff.md`, plano de reconstrução de 2026-04-10,
  prompt antigo do port e passagens metodológicas de `PA2024.pdf` via `pdftotext`.
- Não executei MCMC, não instalei pacotes, não reproduzi fits, não validei resultados
  empíricos, não li integralmente o paper Mebane 2023 e não derivei resultado para
  Brasil 2022/2026. Números acima vêm de logs históricos. PDFs recém-adicionados não
  foram alterados. A nota requer revisão independente antes de incorporar requisitos
  ao plano aprovado.
