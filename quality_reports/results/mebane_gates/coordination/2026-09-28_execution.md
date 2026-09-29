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
| G0 executor SOL-BASELINE | 01a0eaba-2cec-74f3-bca0-8c27b736567e | gpt-6-sol | high | Em execução |
| G0 revisor independente | A despachar após congelamento | gpt-6-sol | high | Aguardando candidato |

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
