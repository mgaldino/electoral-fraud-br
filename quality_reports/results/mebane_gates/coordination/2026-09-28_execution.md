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
| G0 executor SOL-BASELINE | 01a0eaba-2cec-74f3-bca0-8c27b736567e | gpt-6-sol | high | Round2 entregue; goals concluídos, agente fechado |
| G0 revisor independente QA-BASELINE | 01a0eace-749b-7490-994c-2cb3b39c9a26 | gpt-6-sol | high | Round2 pass; goals concluídos, agente fechado |
| G1 executor SOL-DADOS | 01a0eaee-0164-7530-884d-adec564a8327 | gpt-6-sol | high | Round2 entregue; goal concluído, agente fechado |
| G1 revisor independente QA-DADOS | 01a0eb01-0a01-7a10-b432-d1f2cdbd12f8 | gpt-6-sol | xhigh | Round2 pass; goal concluído, agente fechado |
| G2 executor METODO-PRINCIPAL | 01a0eaee-01df-7773-bd63-d321db26a47c | Herdado do coordenador | xhigh | Candidato entregue; goal concluído, agente fechado |
| G2 revisor independente QA-MATEMATICA | 01a0eb0d-15b5-7c51-8e6f-c5b5b93f6011 | Herdado do coordenador | xhigh | Revisão concluída; goal concluído, agente fechado |
| G7 executor SOL-PRONTIDAO-2026 | 01a0eb3a-6ea4-7f61-a66d-2805e495d1d0 | gpt-6-sol | high | Candidato entregue; goal concluído, agente fechado |
| G7 revisor QA-PRONTIDAO-2026 | 01a0eb4a-fa6d-7463-9d5a-bad4dd08b3c0 | gpt-6-sol | xhigh | Em execução, contexto independente |

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
Round1 foi reprovada; os arquivos e achados permanecem preservados. O candidato
vigente é round2, aprovado após os reparos e a revisão independente descritos
abaixo. As etapas anteriores continuam documentadas, sem apagar a reprovação.

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

## Candidato G0 round2

Manifesto: `G0/round2/candidate_manifest.json`, SHA-256
`f71333db477385fc78dad8a7a1a7ca78e48479226dcdbde80ce97d724409fec7`.
O contrato canônico G0 não mudou. Foram acrescentados snapshots do manuscrito
e das quatro tabelas, seis registros de pacotes já instalados e documentação
da aquisição externa não reconstruída. O executor não alterou round1.

O mesmo revisor independente foi retomado para conferir os reparos e o novo
manifesto; ele não participou da implementação nem recebeu o contexto privado
do executor. Seus scripts/resultados ficam em `G0/round2/review/`, separados
do candidato congelado. A promoção exige parecer e adjudicação próprios.

Foi enviada pergunta opcional ao usuário sobre link ou registro de recebimento
do ZIP dos autores. A resposta enriquecerá a proveniência, mas a pergunta não
interrompe o trabalho nem autoriza presumir uma origem não verificada.

## Aprovação G0 e despacho G1/G2

Parecer round2: `G0/round2/review/review.json`, SHA-256
`ef624cb4b2d8ad098b87e196d87add358ce1eba93165d44fcc1939ff303f5376`.
Adjudicação round2: `G0/round2/adjudication.json`, SHA-256
`ea1b4905fdfa14f6e3f36c41974ea948ba0c39d1f81f87d6eaf479782216267b`.
Revisão sem achados vigentes, `manifest_complete=true`; adjudicação da skill
`NO_CONFIRMED_DEFECTS`, validada contra o manifesto. O checker dos gates
confirmou integridade, contrato e evidências ao promover G0 para `pass`.

G1 e G2 foram despachados somente depois dessa aprovação, com os hashes exatos
do manifesto e das duas aprovações G0. Cada executor deve criar goal próprio,
sem orçamento de tokens, e entregar candidato com todos/evidências. Ambos
receberam os contratos integrais e a obrigação de comunicar decisões
substantivas ou impedimentos concretos sem inventar pass.

G1 tem escrita exclusiva nos loaders, helper de dados, configuração e testes
de dados, além de `G1/round1/`. Todas as saídas novas ficam nessa rodada;
`data/processed` e dados brutos históricos permanecem preservados. G2 escreve
somente o contrato matemático, testes de álgebra e `G2/round1/`. Nenhum deles
edita o ledger, README, CLAUDE ou G0. Nenhum foi autorizado a instalar pacotes
ou iniciar estimação fora do gate. A QA será despachada em contexto separado
após congelamento dos candidatos.

A nota lateral `2026-09-28_mebane_denominadores_brancos_nulos.md`, adicionada
ao README durante a revisão, foi preservada. Sua presença não altera o
snapshot aprovado nem constitui aprovação inferencial; G1/G2 devem conferir
as fontes e fixar sua versão se a usarem como contexto substantivo.

## Aquisição de controles oficiais para G1

O coordenador resolveu o HTTP 403 por acesso normal no navegador integrado,
sem CAPTCHA ou mudança de segurança. Foram preservados quatro ZIPs oficiais:
históricos nacionais de T1/T2, detalhe de apuração e votação nominal por
município/zona. URLs, bytes, hashes e diferenças de atualização estão em
`tse2022_control_sources.md`. Os dois últimos snapshots foram gerados em
28/09/2026 e não devem ser confundidos com o material histórico dos autores.

O agente G1 recebeu os caminhos e a indicação dos membros `_BR.csv`; é dele
a tarefa de conferir abrangência, reconciliar totais e explicar divergências.
O coordenador não duplicou essa implementação. Os ZIPs foram excluídos do Git
conforme a política já existente para brutos grandes, mas mantidos na pasta
do projeto. Nenhuma estimação foi iniciada nessa aquisição.

## Candidato G1 sob revisão

Manifesto: `G1/round1/candidate_manifest.json`, SHA-256 recalculado
`009e0fd39f8ab495e52fcb214476fcc7b6095f895381006a924df6a2ffbd7003`.
Contrato canônico: `f985ab97469aa66755b977a09781b30608afa6e245896d9d9788b4461190975d`.
O executor entregou `run.json`, todos/evidências, testes e produtos de execução
2022. Declarou goal concluído somente para entrega do candidato.

O novo revisor Sol xhigh recebeu contrato, fontes e manifesto, sem histórico
do implementador. Deve reler CSVs/ZIPs e reconstruir controles independentemente,
testar a CLI em diretório próprio e conferir fixtures adicionais, rastreabilidade
e escopo dos denominadores. Escrita limitada a `G1/round1/review/`. G1 passa a
`under_review`; nenhum dependente é liberado por esta transição. G2 continua
independente. O coordenador ainda não adjudicou os resultados de G1.

## Revisão e adjudicação G1 round1

Parecer independente: `G1/round1/review/review.json`, SHA-256
`5702f2bf4dd306bdfb7af86e81477faceecd54a4b3b4024cdfdf1d048b5d2c5f`.
Totais foram conferidos por código independente e nove saídas centrais
reproduzidas byte a byte. A QA encontrou duas falhas materiais: identidade
eleitoral não vinculada à configuração quando ambos os CSVs compartilham o
mesmo erro; ledger consumido pelo congelador e omitido do manifesto.

O coordenador confirmou os dois achados com `adjudication_checks.R` e
`adjudication_integrity.py`, preservando as evidências positivas e os limites.
`G1/round1/adjudication.json` passou no validador da skill, com veredicto
`READY_FOR_IMPLEMENTATION`; G1 permanece `changes_requested`, sem liberar G7.
Executor retomado para round2 com escopo de correção delimitado, nova execução
2022 e preservação dos fontes anteriores. Não houve mudança de estimando.

Durante a integração, o coordenador acrescentou `G1-R1-COORD-F03`: o helper
verificava controles apenas de candidatos 13/22. Uma fixture com candidato 12
elegível e um voto aceitou controle 999. O SHA do helper ainda correspondia
ao manifesto round1. `adjudication_candidate_controls.R/.csv` preservam a
contraprova; `adjudication_addendum.json/.md` registra CONFIRMED, reparo seguro
e veredicto validado `READY_FOR_IMPLEMENTATION`. O executor recebeu o adendo
como insumo adicional, sem modificar os dois achados da QA. Round2 deverá
fechar os três achados e passar por nova checagem independente.

## Candidato G2 sob revisão

Manifesto `G2/round1/candidate_manifest.json`, SHA-256 recalculado
`783cfb036f8f26bf894c36782df4fb94e20351e4df015ca6e24330021d04a5a9`.
Contrato estático `f834bc1d12d88b4bc82fb2ada95120a838451c5809332630a75cd9abf03cf4d1`.
O executor entregou fonte, PDF de 13 páginas e 51 testes determinísticos,
rotulando escolhas estatísticas como pendentes e T5 como dependente da
rederivação externa. Isso não aprova a especificação nem G3.

Novo revisor do modelo principal, esforço xhigh, recebeu contrato, PDFs
primários, código JAGS/Stan congelado e manifesto, sem conversa do implementador.
Deve rederivar priors, suporte, normalizadores, marginalização e estimandos,
distinguindo erro no contrato de diagnóstico correto de limitação nas fontes.
Escrita somente em `G2/round1/review/`; sem MCMC, instalações ou implementação
G3. G2 passa a `under_review`. A documentação técnica 2026, adquirida em paralelo
pelo coordenador, está em `tse2026_source_preflight.md`; não implica aprovação G7.

## Reparo G1 round2 sob revisão

Candidato recebido com manifesto
`517c17c724cca82a820519c476981d47c8892c7383dd2c3dded9373eba6d31e8`
e contrato G1 inalterado. O executor entregou reparos F01/F02/F03, 64 regressões,
reexecução completa de 2022, controles oficiais e demonstração de invariância
das colunas antigas. Parquet entre versões mudou pela adição de tipo de eleição;
o replay dentro da nova versão foi byte-idêntico. Essas são evidências do
executor, ainda sob revisão independente, não aprovação antecipada.

A QA anterior foi retomada com novo goal para verificar a round2, com escrita
exclusiva em `G1/round2/review/`. Deve reproduzir os três reparos com contraprovas
próprias e conferir fontes, preservação da round1, dependências G0 e completude
do manifesto de 194 arquivos. G1 fica `under_review`; G7 ainda não foi despachado.

## G2: revisão concluída e decisão metodológica pendente

Revisão `G2/round1/review/review.json`, SHA-256
`a027cd5ad0875ffbb92e3b983c2907700fe6e8b4dbfc776df141ef9f5f80ba7c`:
75 testes independentes e 162 enumerações, sem defeito material encontrado nas
derivações. As pendências D1 (alvo), D2 (priors/desenho) e D3 (estimandos/margem)
foram confirmadas pela coordenação contra as fontes e nove verificações próprias.
Os 73 arquivos do candidato e 49 da revisão foram conferidos por hash e tamanho.

`G2/round1/adjudication.json/.md` registra `BLOCKED` para essa adjudicação e
`changes_requested` no ledger. O validador da skill passou. T1/T2/T3/T5 têm
evidência suficiente de auditoria; T4 permanece em progresso até fixar o
estimando. Nenhum desses todos concluídos aprova o modelo para inferência.

A coordenação perguntou ao usuário se prefere primeiro reproduzir fielmente
o JAGS como benchmark ou desenvolver um modelo gerador alternativo. Recomendou
a primeira rota, sem aprovar seus limites probabilísticos ou inferenciais.
Ausência de resposta não é autorização para selecionar outro alvo. O ramo
G1/G7 continua independente. Nenhum JAGS/Stan foi executado nesta adjudicação.

## Aprovação G1 e liberação G7

G1 round2 aprovado após parecer independente `pass`, com fechamento dos três
achados e nenhum novo finding. Revisão SHA-256
`727f6b234e3a580c329cc5e898018bb68c02063717c292b6d91e4fbe12d86941`;
adjudicação SHA-256
`fe21ce5ebaf107027b6cf64f72eb06f9f2549df8f65ccbbd3eeee2067807735e`.
O coordenador reaplicou cinco probes, conferiu o código e verificou 194 arquivos
do candidato mais 197 inputs e 89 artefatos da QA. A QA executou 43 probes
próprios, 64 regressões e reconciliações independentes completas. Os nove
produtos centrais foram byte-idênticos; os dados históricos foram preservados.
O validador de adjudicação e o checker passaram; G1-T1 a T5 foram marcados
done com evidências contidas no manifesto. Nenhuma inferência foi aprovada.

G7 foi então despachado a novo executor Sol high, em contexto separado, com
contrato integral e os hashes exatos de aprovação de G1. Seu escopo é intake,
configurações, testes e artefatos próprios de 2026; não pode alterar G1 ou escolher
o modelo. Deve usar os PDFs oficiais já adquiridos, separar simulado/real e
data-ready/inference-ready, testar revisões imutáveis, cobertura incompleta e
ausência versus não ocorrência de T2. Não houve aquisição de votos reais de
2026 nem criação de monitoramento futuro. A QA será despachada após o candidato.

## Candidato G7 sob revisão

Manifesto `G7/round1/candidate_manifest.json`, SHA-256
`62f7a5c4907c9d39b75fe5cd88224bddb4796e015f69f004469e51df7ae493c8`,
com 275 arquivos declarados. Executor concluiu goal de entrega em 16min47s,
sem autoaprovar o gate. Especificou um adaptador de staging para CSV normalizado
por seção/candidato, parser EA11/EA16, recibos/versionamento e roteiro por turno.
Não existe ainda conversor aprovado de arquivos oficiais brutos de 2026 para
esse CSV; sua necessidade deve permanecer explícita até os arquivos reais.

Antes do congelamento, a integração apontou três riscos e solicitou testes:
recibo adulterado apesar de hashes de entrada intactos; estados G8/G9 pass
sem predecessores; formato textual dos códigos/turno no JSON publicado nos
PDFs EA11/EA16. O executor ampliou validações e ensaios antes de entregar.
Esses ajustes não substituem a QA. Os recibos continuam data_ready=false e
inference_ready=false, inclusive em fixture com rótulo oficial.

Nova QA Sol xhigh recebeu contrato e candidato congelados, sem conversa do
executor, e deverá produzir ensaio independente, contraprovas e auditoria de
fontes/completude. Seu escopo de escrita é somente `G7/round1/review/`. Nenhuma
fonte/resultado de G0/G1/G2 ou do candidato pode ser alterado. O ledger registra
under_review; isso não libera G8/G9 nem antecipa G7 pass.

## G7 round1: reparos adjudicados

A QA independente entregou `changes_requested`, com três achados: nome UTF-8
válido rejeitado no locale C; data de turno incorreta mas no mesmo ano aceita;
omissão da abrangência territorial do denominador de cobertura. O primeiro
foi encontrado pela coordenação depois do congelamento e reproduzido pela QA
com arquivos próprios; os demais foram encontrados pela QA e reproduzidos
pela coordenação. A cobertura reduzida nunca tornou data_ready/inference_ready
verdadeiros: o terceiro achado é de escopo do recibo, não liberação indevida.

Revisão SHA-256 `a0232205b424c747f354fa5c950c7286370bd168070c51858945e0ff33886297`;
manifesto QA `b8192cd30f8decf6f7be761f0dfd5f809dc6bc43cf1f67464769dffd725dd10f`;
adjudicação `882d1b4081df7d4443983e5b5709942076030b34f0edf1f18b68d45a6edc122a`.
275 arquivos do candidato e 809 da QA foram conferidos. O validador da skill
aprovou a adjudicação `READY_FOR_IMPLEMENTATION` para correções seguras; G7
não passou. Round2 é despachada ao mesmo executor Sol, com preservação de bytes
anteriores e novo goal. O ledger retorna a running durante os reparos, mantendo
os registros da última revisão até nova submissão. G2 permanece independente.

## G7 round2 sob rechecagem

Executor Sol concluiu o goal de reparo em 15min02s. Candidato
`2593c78b5687c883aff6441f09b5d2e67cd319c1ceae723d043dee44a36e62a6`,
com 1.859 arquivos; contrato G7 inalterado. Vinte casos de reparo passaram em
C, no ambiente herdado (efetivamente C) e pt_BR.UTF-8; também passaram regressões
anteriores, fixtures G1 e 26 testes do checker. O executor preservou 1.094
caminhos antes de editar e verificou 1.066 arquivos da round1/QA inalterados.
A revisão independente foi retomada com escrita exclusiva em round2/review/;
deverá fechar os três achados, reexecutar testes próprios e conferir integridade.
O ledger está under_review, sem promoção de G7 ou liberação de dados/inferência.

## Aprovação G7 e fechamento do lote disponível

QA round2 `pass`, sem novo finding, fechou os três reparos: 69 probes próprios
em cada locale (C e pt_BR.UTF-8), oito casos do DAG e regressões afetadas;
25 recibos idênticos entre locales. Revisão SHA-256
`9fb58b9afb0d4aac73a56989a232ac005d4f3ff4f415504d4cb11b58a815f6b7`;
manifesto QA `ac267cf285ce751c53b37bea838659058451b2cb4a8bb0df97790e7c711479c1`.
A coordenação leu o parecer/código, executou oito testes próprios em cada locale
e verificou os 1.859 arquivos do candidato e 1.173 da QA. Adjudicação `pass`,
validada pela skill, SHA-256
`28a12c50055251ef59c899dcda390c84bfbcfe6628c747e1060ac78f92b99cc8`.

G7-T1 a T4 foram marcados done com evidência congelada e o gate promovido a pass.
A aprovação é de prontidão ensaiada, sem conversor bruto oficial, votos reais ou
inferência 2026. UFs presentes não atestam cobertura nacional; ingestão serial
ou lock externo e preflight de recursos continuam necessários no uso real.

Estado ao fechar este lote: G0/G1/G7 pass; G2 changes_requested por três escolhas
metodológicas; G3-G6 queued; G8/G9 waiting_external. Os subagentes encerraram
seus goals finitos e foram fechados. A rota metodológica foi perguntada ao usuário
e não houve resposta neste lote; não foi escolhida silenciosamente. Nenhum MCMC,
instalação ou monitoramento futuro foi iniciado. O resumo PDF de 29/09/2026
consolida resultados, limites, comentário sobre JAGS e referências completas.
