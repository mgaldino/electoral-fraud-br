# D em Stan: candidato para revisão independente

Executor de implementação: `01a0f4b5-4434-7b83-91b9-69ced11b40ba`.
Data de desenvolvimento: 2026-10-01. Este documento descreve o candidato,
não certifica compilação, testes, amostragem empírica ou aprovação de gate.
Os resultados efetivamente executados devem ser consultados no `result.json`
e no `preflight_manifest.json` de cada tentativa preservada.

## Escopo e fontes

Esta tradução cobre somente D. Não modifica A, os dados entregues em 30/09,
as fontes anteriores, o supervisor anterior, os ledgers ou a integração LONG.
Não depende de instalação de pacotes. O ambiente previsto contém R 4.4.2,
cmdstanr 0.9.0 e CmdStan 2.37.0; cada tentativa registra as versões reais.

Fontes vinculantes:

| Fonte | SHA-256 |
| --- | --- |
| `models/experimental/mebane_ad/d_multinomial.jags` | `6ddb9624f60b15e196cc27ed9694852c40b6553a684a9962003168da4ecfaf5b` |
| `R/experimental/mebane_ad/model_d.R` | `e5154c01c6f111cc47d5e9d9f49654f1ee081bb4001664038c840b8c0d86710a` |
| Contrato `2026-10-01_ad_long_stan/contract.json` | `fb4a296c9bf0af25812d7d8dd2ab63340fe10d4e73e806e64b5dba3f7dcf481a` |
| RDS comum de `data/run-20260930T235038Z-pid61600/` | `b2ef611dabb751f9286acbaae841a23c34948ed0a4b6306364cbe94d9d24903e` |
| `2026-09-30_ad_study/final_manifest.json`, somente leitura | `6720193e76b60e2b7d4c73910b2e4328b7cc2fb882b6e29f095160a8dce50db3` |

Os dados mantêm as 143 unidades e a ordem original de precinct. `N` é NVoters,
`A=NVoters-NValid`, `W=Votes` e `O=N-A-W`, segundo a base dos autores. Não se
reinterpreta NValid como comparecimento brasileiro, nem se acrescentam
metadados eleitorais não presentes nas fontes.

## Alvo e mudanças de variável

A ordem dos seis blocos é tau, nu, iota.m, iota.s, chi.m, chi.s.
Para unidade i e bloco b, a fonte JAGS tem h[i,b] normal com média alpha[b]
e variância v[b], e eta[i,b]=h[i,b]+b0[b]. A tradução usa
h[i,b]=alpha[b]+sqrt(v[b])*z[i,b], com z normal padrão. Permanecem separados:

- alpha[b] normal de média zero e desvio padrão 1;
- b0[b] normal de média zero e desvio padrão 0,01, precisão 10000;
- v[b] exponencial de taxa 5 sobre a **variância**, não sobre o desvio padrão.

Condicionalmente a alpha e v, o determinante da transformação z para h é
produto_b v[b]^(n/2). Assim, a densidade centrada vezes esse Jacobiano é a
densidade normal padrão de z, preservadas as demais prioris. Não se adiciona
esse Jacobiano novamente no código não centrado.

Na priori original, u1 é uniforme em (0,1) e u2,u3, condicionalmente a u1,
são uniformes independentes em (0,u1). A densidade conjunta é 1/u1².
Escrevendo u2=u1*r2 e u3=u1*r3, o Jacobiano é u1². A densidade de
(u1,r2,r3) é, portanto, um no cubo unitário. Integrar u1 deixa r2,r3
uniformes independentes em (0,1), e pi=(1,r2,r3)/(1+r2+r3).

Há apenas a ordem parcial pi1>=max(pi2,pi3). Não há ordem entre pi2 e pi3.
O determinante de (r2,r3) para (pi2,pi3) é pi1³, de modo que a densidade
induzida no simplex seria pi1^(-3) no domínio parcial. O código amostra r,
não pi: nenhuma densidade Dirichlet nem termo Jacobiano adicional em pi
deve ser inserido. A normalização é herdada do cubo uniforme e da
transformação bijetiva no interior, com fronteiras de medida zero.

Os Jacobianos computacionais que Stan adiciona ao avaliar a densidade em
coordenadas irrestritas são diferentes: soma_b log(v[b]), para exp(log v),
e soma_j [log(r[j])+log(1-r[j])], para as duas transformações logísticas.
Os testes com `jacobian=FALSE/TRUE` distinguem esses termos do Jacobiano da
mudança entre o modelo centrado e o não centrado.

## Verossimilhança e quantidades geradas

As transformações seguem literalmente D: tau e nu logísticos, m2 e s2
iguais a 0,7 vezes a logística, m3 e s3 iguais a 0,7+0,3 vezes a logística,
e m1=s1=0. Para cada classe:

- pA=(1-tau)*(1-m);
- pW=tau*nu+(1-tau)*m+tau*(1-nu)*s;
- pO=tau*(1-nu)*(1-s).

Cada unidade contribui log(sum_c pi[c]*Multinomial(A,W,O|N,p[c])).
Não se usa uma multinomial com probabilidades previamente promediadas.
As probabilidades são calculadas na escala log sem clamp, normalização
artificial, substituição de A observado, transformação 0,999 ou contagens
binomiais auxiliares. O coeficiente multinomial é incluído explicitamente.
Quando a contagem é zero, seu termo é omitido para evitar 0*(-Inf).

As responsabilidades são proporcionais à mesma densidade de cada classe.
Um único `Z_rng[i]` é sorteado condicionalmente por unidade e draw;
`Z[i]` é um alias desse sorteio. pA/pW/pO e os funcionais M/S ativos usam
exatamente esse Z. Isto reconstitui a distribuição posterior aumentada;
não equivale a substituir Z por sua esperança. A identidade do alvo precisa
ser sustentada pela álgebra e pelos testes compilados, não apenas pela
compilação ou por médias próximas às de JAGS.

M por classe é N*(1-tau)*m; S é N*tau*(1-nu)*s. São funcionais de votos
esperados, não contagens observadas nem reconstruções de cédulas. A geração
secundária de (L0,M_count,S_count)|W não está incluída neste runner.

## Schema para integração

O runner prospectivo mantém os nomes abaixo. Não executa o diagnóstico
LONG e não escreve em `R/experimental/mebane_ad_long/`.

| Arquivo | Conteúdo |
| --- | --- |
| `draws_array.rds` | `posterior::draws_array`, 2000 iterações pós-warmup × 4 cadeias × todas as variáveis de parâmetros, transformed parameters, generated quantities e lp__. Identidade de cadeia preservada. |
| `sampler_diagnostics.rds` | `draws_array`, 2000 × 4 × diagnósticos HMC, incluindo divergent__, treedepth__, energy__, accept_stat__, stepsize__ e n_leapfrog__. |
| `fit.rds` | Handle CmdStanMCMC lazy, salvo antes de carregar draws; depende dos CSVs persistentes nos caminhos absolutos originais. Não é um segundo armazenamento de todos os draws nem um pacote relocável. |
| `csv/` | CSVs completos por cadeia, com 2000 warmup e 2000 retained, precisão de escrita de 17 dígitos, configurações CmdStan e métricas de adaptação. |
| `chain1.log` a `chain4.log` | Saídas do CmdStan por cadeia após retorno do fit; em timeout antecipado, o console agregado e CSVs parciais são preservados. |
| `chain_timing.csv` | Tempos de warmup, sampling e total por cadeia, reportados pelo CmdStan. |
| `timing.json` | Walltime externo de `model$sample`, tempo de compilação separado, tempos por cadeia, dimensões e nomes internos NCP. |
| `manifest.json` | Hashes dos artefatos concluídos, vínculo à preparação e ao QA; não declara precisão suficiente. |
| `supervisor_started.json`, `supervisor_finished.json`, `console.log` | Comando, ID real do executor, timeout, retorno, walltime e logs persistentes; erro de infraestrutura ganha `supervisor_error.json`. |

Nomes nos draws:

- `alpha[1:6]`, `b0[1:6]`, `v[1:6]`, `mu[i,b]`, `pi[1:3]`, `Z[i]`, `pA[i]`, `pW[i]`, `pO[i]` mapeiam para os nomes anteriores pelo `name_map.csv`.
- `z[i,b]` e `r[1:2]` permanecem integralmente disponíveis para diagnóstico da parametrização não centrada (NCP).
- `responsibility[i,c]`, `p_RB[i,j]`, `M_RB[i]`, `S_RB[i]`, `M_RB_total` e `S_RB_total` são expectativas condicionais sobre classes, separadas dos ativos.
- `M_by_class[i,c]` e `S_by_class[i,c]` são funcionais por classe; `M_active[i]`, `S_active[i]`, `M_total` e `S_total` usam o mesmo `Z_rng` de pA/pW/pO.
- `log_lik[i]` é a verossimilhança marginal de três classes. Não autoriza comparações de Bayes factors ou LOO entre A e D.

Rao-Blackwell (RB) significa aqui integrar a classe condicionalmente ao
draw dos parâmetros. Os arrays mantêm RB e reconstrução aumentada separados.
A dimensão de cadeia é 1:4 em ordem; o seed base é 1001261 em todas as
cadeias, diferenciadas pelos IDs explícitos de CmdStan.

## APIs e execução prospectiva

`ad_stan_prepare(repo, out, executor_id)` faz snapshot, prepara dados e
inicializações e compila; não amostra. `ad_stan_compile_preparation` é a
rotina interna usada pelo preflight sobre um snapshot já existente.
`ad_stan_sample(preparation, qa_path, out)` só é chamado pelo supervisor,
com uma aprovação independente vinculada ao hash da preparação.

`ad_stan_reference_lp`, `ad_stan_reference_u_lp`,
`ad_stan_reference_likelihood`, `ad_stan_reference_log_probs`,
`ad_stan_reference_mass`, `ad_stan_centered_lp`, `ad_stan_pack` e
`ad_stan_unpack` são os cálculos independentes em R. A comparação com
`fit$log_prob` usa a densidade não normalizada: as constantes das prioris
omitidas por `propto=TRUE` não são incluídas; o coeficiente multinomial é.

Após liberação da janela computacional, a validação usa:

```sh
python3 -B R/experimental/mebane_ad_stan/prepare_stan.py \
  preflight REPO NOVO_DIRETORIO
```

O diretório deve estar no escopo `stan_impl/` e não pode existir. O launcher
Python configura TMPDIR/TMP/TEMP dentro desse diretório antes de iniciar R;
sem isso a compilação é recusada. O pacote preparado fica em
`NOVO_DIRETORIO/preparation/`. `launcher.log` e `launcher_manifest.json`
preservam a execução externa. O timeout do preflight é de 1800 s e não é
o timeout de 3600 s do experimento prospectivo. O modo `prepare`, em vez de
`preflight`, somente prepara/compila sem rodar a suíte.
Produtos C++ e bibliotecas compartilhadas encontrados no temporário da
sessão R são copiados para `preparation/compiler_products/` antes da saída;
o executável CmdStan permanece em `preparation/build/`.

O launcher R congela todas as fontes antes de compilar e executa somente dados sintéticos
de três unidades em modo `fixed_param`. Os parâmetros não são atualizados.
As 256 iterações sintéticas só exercitam as quantidades geradas condicionais.
As chamadas efetivas são registradas em `tests/calls.json` e `test.log`.

O QA independente deve usar um ID real distinto do implementador, verificar
o pacote e registrar JSON com `status: "PASS"`, `reviewer_id` e
`preparation_manifest_sha256` igual ao SHA-256 de `manifest.json`. Um PASS
não produzido pelo revisor, ausente ou associado a outro hash é recusado.
Os fixtures de rejeição de QA dos testes não são aprovações reais.

Somente após QA independente e autorização vigente da execução empírica:

```sh
python3 -B PREPARACAO/sources/R/experimental/mebane_ad_stan/supervise_stan.py \
  PREPARACAO PARECER_JSON NOVO_DIRETORIO_EMPIRICO
```

`CODEX_THREAD_ID` deve vir do executor real. A configuração não é uma opção
livre: quatro cadeias seriais, warmup 2000, retained 2000, thin 1,
adapt_delta 0,99, max_treedepth 12, seed 1001261 e IDs 1:4. Compilação ocorre
antes do tempo empírico. O timeout externo de 3600 s cobre geração e
persistência dos resultados, não diagnóstico externo. O walltime de geração
é registrado separadamente da exportação e da compilação. Os tempos por
cadeia do CmdStan não incluem todo o overhead do supervisor.

O supervisor envia SIGTERM ao grupo, aguarda o líder por até dez segundos e
sempre tenta SIGKILL no grupo, inclusive se o líder tiver encerrado enquanto
descendentes persistem. Não há retry, extensão automática, exclusão de
cadeias ou remoção dos resultados de uma tentativa interrompida.

## Evidência e limites

O preflight exercita os métodos compilados reais de cmdstanr, não uma função
R usada como substituta. Verifica log_prob com e sem Jacobiano, gradientes
por diferenças finitas independentes, fronteiras incluindo contagens zero,
normalização de massas para N=0..4, mistura, mapeamento de nomes e seleção
conjunta das quantidades geradas. N=0 é um teste da função de massa; dados
do modelo completo exigem N>=1. As tolerâncias estão fixadas no script antes
da execução e qualquer reparo exige novo snapshot e nova tentativa.

`fit$grad_log_prob` é comparado com diferenças finitas centrais de passo
1e-5*max(1,abs(u[j])); a tolerância relativa escalada é 3e-5. Logdensidades
integrais usam 2e-10; as funções de probabilidade e massas usam tolerâncias
mais estritas registradas junto a cada teste. Fronteiras matemáticas exatas
com log p=-Inf são testadas na função de massa, sem exigir que parâmetros
contínuos restritos de Stan atinjam endpoints de medida zero.

Uma tentativa com testes PASS continua sendo um candidato revisável.
Nenhum teste sintético demonstra convergência, identificação eleitoral,
equivalência empírica, precisão dos resultados reais, aprovação G10 ou uso
em produção. A rotina completa de 4×2000 retained, serialização real e
diagnósticos HMC/NCP só podem ser validados empiricamente após o QA.
