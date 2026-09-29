# Reconciliação do inventário após decisão do usuário

## Autorização e limites

Em 29/09/2026, o usuário determinou: "ok, mantenha a exclusao e atualize o
inventario. Mas pq foi excluido sem perguntar pra mim? Nao exclua coisas sem
perguntar pra mim, ok?"

A decisão autoriza manter a ausência já observada e atualizar o inventário e
os vínculos documentais afetados. Não autoriza novas exclusões, restaurações,
instalações ou estimações. Arquivos não serão excluídos sem autorização
explícita do usuário, inclusive em rotinas de limpeza e por subagentes.

## O que se sabe sobre a remoção

- `ssrn-4073770.pdf.download/ssrn-4073770.pdf` tinha 1.360 bytes, SHA-256
  `524dc82c59612ec91b3a6ab475dd34f0607546a37823c9a9b1fd652677a8acdf`.
  Já era um download incompleto, inválido como fonte, sem função científica
  no modelo. Apenas sua presença constava do inventário G0.
- A QA registrou presença às 13:13 UTC e ausência às 13:19 UTC em 29/09/2026.
  `Info.plist`, da mesma pasta, também estava ausente ao final da rodada.
- O commit `122e74a2c35f82bc229aafdfd61144f45007cb2c`, criado por checkpoint
  automático, registra as duas ausências. Esse registro não identifica quem
  ou qual processo executou a remoção no sistema de arquivos, nem sua causa.
  O nome do autor do commit não é evidência de autoria da exclusão.
- Não há evidência suficiente para atribuir a remoção ao usuário, a um
  agente ou ao aplicativo. A explicação anterior "ação concorrente" descrevia
  apenas a mudança observada durante a QA, não sua autoria.

## Tratamento autorizado

Preservar os inventários e pareceres anteriores como registros históricos.
Criar uma nova rodada documental que exclua o download somente da relação de
arquivos atualmente existentes, mas conserve um registro explícito de sua
ausência autorizada. Não recuperar nenhum dos dois arquivos.

Conferir por hash a evidência reaproveitada e revisar independentemente os
novos vínculos G0, G1, G2 e G7. Testes e resultados científicos anteriores
serão identificados como anteriores, não como reexecutados. Não alterar as
especificações dos gates, as fontes científicas ou o checker para acomodar
a ausência. O fechamento desta pendência não executa nem aprova G3 ou G10,
e não libera inferência nacional.
