# Validação independente do `bl` em JAGS contra Mebane (2023)

Data: 2026-04-10

## Atualização de alvo em 2026-04-11

A inspeção do pacote instalado `UMeforensics` 0.0.4 mostrou que o alvo canônico disponível localmente **não é `bl()`**, mas **`qbl()`**, que é inclusive o default de `eforensics()` (`model = "qbl"`).

Diferentemente de `bl()`, o `qbl()` já implementa:

- prior ordenado para `pi` via `pi.aux1`, `pi.aux2`, `pi.aux3`;
- `k = 0.7`;
- seis efeitos aleatórios por observação (`th`, `nh`, `imh`, `ish`, `cmh`, `csh`);
- hiperparâmetros `imb`, `isb`, `cmb`, `csb`, `nb`, `tb ~ dexp(5)` com precisões definidas por seus inversos no JAGS.

Portanto, as conclusões desta nota sobre ausência de random effects e prior de mistura inadequado valem para o **`bl()` legado** e para o fork antigo `DiogoFerrari/eforensics`, mas **não** para o alvo canônico `qbl()` do `UMeforensics`.

## Escopo

Esta nota valida, de forma independente, se o código JAGS do modelo `bl` usado no ecossistema `eforensics` implementa corretamente o modelo descrito por Mebane (2023), em vez de assumir que o pacote é canônico por definição.

Fontes auditadas:

- Mebane (2023), `pm23.pdf`: https://websites.umich.edu/~wmebane/pm23.pdf
- Repositório público mais recente `UMeforensics/eforensics_public`:
  - `R/ef_models.R`
  - `R/ef_simulate_data.R`
  - `R/ef_models_desc.R`
  - `R/ef_main.R`
- Fork antigo `DiogoFerrari/eforensics`:
  - `R/ef_models.R`
  - `R/ef_simulate_data.R`
  - `R/ef_main.R`

## Conclusão curta

Leitura atualizada após a inspeção do `UMeforensics` 0.0.4:

- o **`qbl()`** é a implementação JAGS mais próxima do paper de Mebane (2023) disponível no ecossistema `eforensics`;
- o **`bl()`** continua útil como baseline simplificado, mas não deve mais ser tratado como alvo primário do port em Stan.

O código JAGS `bl` do pacote implementa **parte importante** da estrutura substantiva do modelo de Mebane, mas **não é idêntico** ao modelo do paper de 2023.

O veredito correto nao e "o JAGS implementa Mebane exatamente", mas:

- a estrutura de mistura em 3 componentes e a logica substantiva de votos manufactured/stolen batem com o paper;
- a formula de `p.w` em JAGS e algebraicamente consistente com o paper, mas escrita condicionalmente em funcao de `a/N`;
- ha divergencias materiais entre paper, JAGS e `simulate_bl`, especialmente em `k`, priors para `pi` e random effects;
- portanto, o `bl` do pacote deve ser tratado como **implementacao operacional relacionada ao paper**, nao como transcricao literal dele.

## O que bate

### 1. Estrutura de mistura

Mebane (2023) define tres classes latentes:

- `Z = 1`: sem fraude
- `Z = 2`: fraude incremental
- `Z = 3`: fraude extrema

O JAGS `bl()` usa exatamente essa estrutura com `Z[j] ~ dcat(pi)`.

### 2. Equacao para abstencoes

No paper:

- `a_i* = 1 - tau_i - p_ti`
- com `p_ti = 0`, `iota_i^M (1 - tau_i)` ou `upsilon_i^M (1 - tau_i)` conforme `Z`

Isso implica:

- sem fraude: `a_i* = 1 - tau_i`
- incremental: `a_i* = (1 - tau_i)(1 - iota_i^M)`
- extrema: `a_i* = (1 - tau_i)(1 - upsilon_i^M)`

O JAGS `bl()` usa exatamente:

- `p.a[j] = (Z==1)*(1-mu.tau[j]) + (Z==2)*(1-mu.tau[j])*(1-iota.m[j]) + (Z==3)*(1-mu.tau[j])*(1-chi.m[j])`

Portanto, a parte de abstencao bate.

### 3. Equacao para votos no leader

No paper:

- `w_i* = nu_i tau_i + p_wi`
- incremental: `p_wi = iota_i^M (1 - tau_i) + iota_i^S tau_i (1 - nu_i)`
- extrema: `p_wi = upsilon_i^M (1 - tau_i) + upsilon_i^S tau_i (1 - nu_i)`

O simulador `simulate_bl()` escreve isso diretamente como:

- incremental: `tau*nu + iota.m*(1-tau) + iota.s*tau*(1-nu)`
- extrema: `tau*nu + chi.m*(1-tau) + chi.s*tau*(1-nu)`

O JAGS `bl()` usa uma forma diferente:

- `p.w[j] = ...` em funcao de `a[j]/N[j]`, `iota.m[j]`, `iota.s[j]`, `chi.m[j]`, `chi.s[j]`

Essa forma **nao contradiz** o paper. Ela e a mesma equacao reescrita usando o fato de que, sob fraude incremental,

- `a/N = (1 - tau)(1 - iota.m)`

e, sob fraude extrema,

- `a/N = (1 - tau)(1 - chi.m)`.

Substituindo essas identidades na expressao do paper, obtém-se exatamente a forma usada no JAGS. Logo:

- a formula de `p.w` em JAGS esta correta em relacao a Mebane;
- a diferenca e de parametrizacao condicional, nao de substancia.

## O que nao bate

### 1. Constante `k`

No paper de Mebane (2023), as equacoes (4c) e (4d) usam:

- `k = 0.7`

O `bl()` em JAGS, tanto no fork `DiogoFerrari/eforensics` quanto no repositorio `UMeforensics/eforensics_public`, usa:

- `k = .7`

Mas `simulate_bl()` usa:

- `k1 = 0.5`
- `k2 = 0.8`

Isso e uma divergencia material. Para o modelo `bl` de estimacao, a referencia correta e:

- `k = 0.7`

Nao e defensavel tratar `0.5/0.8` como canonico para o `bl` estimado via JAGS.

### 2. Prior para as probabilidades de mistura

No paper de Mebane (2023), o prior para `pi` **nao** e Dirichlet flat. O paper usa:

- `tilde(pi1) ~ U(0,1)`
- `tilde(pi2) ~ U(0, tilde(pi1))`
- `tilde(pi3) ~ U(0, tilde(pi1))`
- `pi_j = tilde(pi_j) / sum(tilde(pi))`

Objetivo: forcar `pi1` a ser fracamente a maior para desincentivar label switching.

Ha divergencia entre implementacoes:

- `DiogoFerrari/eforensics::bl()` usa `pi ~ ddirch(1,1,1)`;
- `UMeforensics/eforensics_public::bl()` usa o prior ordenado com auxiliares uniformes, alinhado ao paper.

Portanto:

- o fork antigo do Diogo **nao** bate com o prior de Mebane (2023);
- o repositorio publico `UMeforensics/eforensics_public` bate melhor com o paper nesse ponto.

### 3. Random effects do paper nao aparecem no `bl` do pacote

Mebane (2023) define o modelo com random effects observacao-especificos:

- `kappa_i^tau`, `kappa_i^nu`, `kappa_i^{iota M}`, `kappa_i^{iota S}`, `kappa_i^{upsilon M}`, `kappa_i^{upsilon S}`

com priors hierarquicos, incluindo `sigma ~ Exp(5)`.

O `bl()` do pacote nao inclui esses random effects. Em vez disso:

- `tau` e `nu` sao medias logisticas deterministicas por observacao;
- `iota` e `chi` sao gerados via contagens binomiais latentes `N.iota.*`, `N.chi.*`.

Ou seja:

- o `bl` do pacote e uma simplificacao operacional do paper;
- ele nao e o mesmo modelo hierarquico completo descrito em Mebane (2023).

### 4. O simulador nao e uma descricao segura do estimador

O `simulate_bl()` ajuda a entender a intuicao do modelo, mas **nao pode ser usado como referencia unica** para o estimador porque:

- usa `k1 = 0.5`, `k2 = 0.8`;
- escreve o modelo em forma mais direta, sem a reparametrizacao condicional do JAGS;
- nao resolve a questao dos priors do estimador.

Portanto, usar `simulate_bl()` como fonte canônica para portar o estimador gera erro de especificacao.

## Implicacao para a portagem para Stan

Atualização importante: após a inspeção do pacote oficial instalado, há agora **quatro** alvos relevantes:

1. **Paper Mebane (2023)**: formulação teórica completa.
2. **JAGS `qbl()` do `UMeforensics`**: implementação prática canônica mais próxima do paper, com prior ordenado e efeitos aleatórios.
3. **JAGS `bl()` / `bl_working`**: simplificações não hierárquicas úteis apenas como baseline legado.
4. **`simulate_bl()`**: versão generativa útil para intuição, mas não confiável como descrição canônica do estimador.

Uma "portagem exata" do `bl()` em JAGS nao e a mesma coisa que portar literalmente as equacoes simplificadas do prompt.

Ha tres alvos diferentes:

1. **Paper Mebane (2023)**: modelo hierarquico com random effects e prior ordenado para `pi`.
2. **JAGS `bl()` do pacote**: simplificacao binomial-logistica sem random effects, com forma condicional de `p.w`.
3. **`simulate_bl()`**: versao generativa util para intuicao, mas inconsistente com o `bl()` estimado em pontos importantes.

Para comparacao de velocidade com o JAGS usado no pipeline atual, o alvo correto agora passa a ser o item 2 acima, isto é, o **`qbl()` do `UMeforensics`**.

Mas isso exige uma observacao metodologica importante:

- o `bl()` em JAGS introduz variaveis discretas latentes observacao-especificas (`Z`, `N.iota.*`, `N.chi.*`);
- Stan nao aceita tais parametros discretos;
- logo, um port "exato" exige marginalizacao ou reformulacao adicional;
- um modelo Stan com apenas 11 parametros e intercept-only e uma **simplificacao deliberada**, nao uma traducao exata do `bl()` atual.

## Decisao recomendada

Para seguir de forma rigorosa:

- nao assumir que o fork `DiogoFerrari/eforensics` e canonico;
- usar `pm23.pdf` e `UMeforensics/eforensics_public` como referencias principais;
- tratar `DiogoFerrari/eforensics` como implementacao antiga a ser auditada;
- corrigir o prompt de portagem para refletir:
  - `k = 0.7` no `bl` estimado;
  - prior ordenado para `pi` no paper e no repo publico;
  - discrepancia do `simulate_bl`;
  - fato de que o modelo Stan intercept-only minimo nao e portagem exata do JAGS.

## Veredito final

O codigo JAGS fornecido **nao deve ser aceito sem qualificacoes como "Mebane 2023 exato"**.

O julgamento mais preciso e:

- **correto na logica central de mistura e na forma substantiva das equacoes de fraude**;
- **correto na expressao de `p.w` quando lida como reparametrizacao condicional**;
- **incorreto ou incompleto como representacao literal do paper de 2023** devido a:
  - prior de `pi` diferente no fork antigo;
  - ausencia de random effects do paper;
  - inconsistencia de `simulate_bl` com `bl()` em `k`.

Leitura consolidada em 2026-04-11:

- **`qbl()` do `UMeforensics`** e a melhor aproximacao operacional disponivel do paper;
- **`bl()`** deve ser mantido apenas como comparativo legado;
- a portagem em Stan deve ser recentrada em `qbl()`.

## Addendum 2026-04-12: diagnostico do fit JAGS salvo

O fit `05_eforensics_qbl_brasilia_fit.rds` (JAGS, 4 chains, burn=2000,
sample=5000) **esta preso num modo local errado**:

- `beta.tau` (= `tau.alpha`) ~ 0.711 em todas as 4 chains.
- O valor correto e ~1.616, validado contra o logit empirico do turnout
  (0.833 → 1.605) e contra um JAGS fresco com burn=5000 que converge
  em todas as 4 chains.
- O Stan existente ja estava no modo correto (tau_alpha ~ 1.59).

**Causa**: burn-in de 2000 iteracoes insuficiente para o modelo `qbl` com
n=6748 observacoes e 74249 nos estocasticos nao observados. Com burn=5000
e adapt=1500, todas as chains convergem.

O benchmark correto para comparacao Stan vs JAGS e agora
`05_eforensics_qbl_brasilia_fresh_v2_fit.rds`.

### Identificabilidade dos parametros de fraude

A analise detalhada do JAGS fresco e do PA2024.pdf (Mebane, Jun 2025) mostra
que `iota_*_alpha`, `chi_*_alpha` e seus hiperparametros (`imb`, `isb`, `cmb`,
`csb`) tem rhat 2-13 mesmo no modo correto. Isso e consequencia direta da
nao-identificacao: com `pi[2] ~ 0.009` e `pi[3] ~ 0.0003`, quase nenhuma
observacao informa esses parametros.

Mebane lida com isso em PA2024 usando (a) county fixed effects para reduzir
multimodalidade, (b) dip test e M(pi_k) como diagnostico em vez de rhat, e
(c) reportando Ft/Fw como quantidade substantiva (robusta a nao-identificacao
dos alphas).

Ver `05_stan_qbl_session_handoff.md` v2 para detalhes completos.
