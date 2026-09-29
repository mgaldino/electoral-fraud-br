# Execução coordenada dos gates Mebane

Autorização: o usuário respondeu "do it" ao plano de 10 gates com execução por
goals e revisão independente. Data de início: 2026-09-28. Coordenador nativo:
`019d795a-acfa-72c2-a210-d55a46c606c2`.

## Lote inicial

G0 começa sem dependências. G1 e G2 só podem iniciar após o pass de G0.
Nenhuma aprovação científica do desenho é tratada como execução analítica.
G8/G9 continuam dependentes de publicação oficial e dos gates inferenciais.

| Gate/papel | Agente nativo | Modelo solicitado | Esforço | Situação |
|---|---|---|---|---|
| G0 executor SOL-BASELINE | 01a0eaba-2cec-74f3-bca0-8c27b736567e | gpt-6-sol | high | Round1 entregue; reparos round2 despachados |
| G0 revisor independente QA-BASELINE | 01a0eace-749b-7490-994c-2cb3b39c9a26 | gpt-6-sol | high | Round1 changes_requested; goal concluído, agente fechado |

O executor deve criar goal próprio sem token budget e escrever somente na
rodada G0/round1, README, CLAUDE e renv.lock. O coordenador é o único escritor
do ledger e da integração. Não há dois escritores concorrentes nos mesmos
arquivos. O revisor receberá contexto novo, contrato e candidato congelado.

## Roteamento

Mantido o roteiro aprovado: Sol high para G0; outro Sol high para QA. A consulta
ao adaptive-codex-router retorna recomendação antiga gpt-5.6-terra/high,
uncalibrated. Não se executou esse comando, nem se solicitou Fast. O catálogo
vivo confirma gpt-6-sol/high, solicitado pelo usuário no plano; a revisão
independente é mandatória pelo pedido, independentemente da heurística.

## Controles iniciais

- Git limpo na entrada; preservados fontes, dados e fits existentes.
- Checker inicial: 10 gates, 45 todos, estrutura válida.
- G0 marcado running; outros gates não foram liberados.
- Proibida instalação ou atualização silenciosa. Falta de dependência exige
  diagnóstico concreto, aproveitando o ambiente disponível antes de propor ação.
- Em G0 não haverá MCMC nem reconstrução integral dos dados de G1.
- Os artefatos históricos têm de ser distinguidos de verificações executadas
  nesta rodada. Restaurabilidade não será alegada como teste frio sem execução.

O fechamento será adicionado após as revisões, com caminhos/hash dos candidatos,
evidências por todo, decisões do coordenador e próximos gates efetivamente
liberados. Este registro de início não antecipa pass.

## Candidato G0 e integração

Candidato: `quality_reports/results/mebane_gates/G0/round1/`.
Manifesto congelado: SHA-256
`61649af333a6d2ef6bea20e4ed5e38671bb6d6d5f2b867fbe1d9acdc195169ab`.
Contrato canônico: SHA-256
`e5ba78d6f8d314c2bf94738df85fce0a31d8e9986ef974f6c69ee9e30ee06ca3`.
O ledger está `changes_requested`, sem aprovação ou liberação de dependentes.

O coordenador localizou e arquivou os artigos primários de 2022 e 2023 no
endereço público oficial alternativo da Universidade de Michigan. Fontes,
integridade e hashes estão em `method_sources_download.md`, nesta pasta; o
executor os incorporou ao manifesto. A falha inicial de acesso não permanece
como impedimento. A auditoria matemática pertence ao G2.

Antes do congelamento, a integração exigiu que código/configuração mutáveis
fossem representados por snapshots explícitos, inclusive o ledger. Assim, uma
transição de estado ou edição autorizada posterior não altera retroativamente
a evidência de baseline. A revisão independente confere essa correspondência.

Preparação documental independente de G1: `tse2022_control_sources.md`,
`check_tse_controls.R` e `tse2022_control_arithmetic.csv`. A aritmética de
notícias oficiais de 2022 revela uma discrepância de 657 no denominador das
notícias de T1/T2 do TSE; o registro conserva também uma fonte TRE-RN e não
força os dados a um total escolhido. Esse trabalho não equivale à execução ou
aprovação de G1.

## Revisão e adjudicação G0 round1

Parecer: `G0/round1/review/review.json`, SHA-256
`0396d243250471cdf9db8e4c0ea8f80cf0bbe9830ddd4629feb0dec2ddb175b0`.
Os 151 hashes e 32 snapshots passaram; fit e quatro bases foram carregados
independentemente. Três lacunas impedem aprovar esta rodada. O coordenador
confirmou a omissão de manuscrito/tabelas e de seis dependências no lock;
classificou como parcial a questão de proveniência, delimitando o reparo à
promessa excessiva de recuperação externa no README.

Adjudicação: `G0/round1/adjudication.json` e `.md`, validados com a skill
`adjudicate-review`. Veredicto `READY_FOR_IMPLEMENTATION`; não é pass do gate.
O executor recebeu somente os reparos confirmados e o escopo confirmado do
parcial, com nova rodada e preservação integral da anterior. Nova checagem
independente será feita sobre o novo manifesto. Nenhum pacote será instalado.
