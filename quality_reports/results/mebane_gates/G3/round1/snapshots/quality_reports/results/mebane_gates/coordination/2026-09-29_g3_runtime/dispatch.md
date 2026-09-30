# G3: teste pequeno do benchmark literal

## Autorização e estado inicial

Continuação do goal autorizado nesta conversa em 29/09/2026. A rodada anterior
fez progresso: resolveu a pendência documental do inventário e aprovou os novos
vínculos G0/G1/G2/G7. O checker passou antes deste despacho. G3 ainda não tinha
execução. Não há bloqueio atual que impeça os testes pequenos autorizados.

O alvo é o contrato `G2/round2/benchmark_contract.json`, SHA-256
`63b61fb0594d0302a03d999bcff6c62967b6e999f37b4c9a8821f0f8e9ed18d2`.
A aprovação vigente de G2 é round3: manifesto
`2ffd63203a6af407c5f17c708ce2c42120fef0dc9600e3585f83be6e48313173`,
review `0b6a2c4268e1b7d58c2964e31db54df2c894056634939c24681d38ad54ef96f3`,
adjudicação `4999cc69a32e53e5bc0f6308acbfb77671c192a9b4126715794e1acfcc8b2ca9`.
Os indicadores pending dentro do contrato congelado são históricos; os records
de aprovação vigentes estão no ledger, sem reescrever o contrato.

## Divisão do trabalho

O executor Sol xhigh cria protocolo congelado antes dos resultados, implementação
R, testes e candidato G3 round1. É a divisão já escolhida pelo usuário e pelo
gate; a heurística de routing antiga não substitui o contrato nem a revisão.
Modelo principal separado revisa o candidato, reproduz casos críticos e procura
contraexemplos. O coordenador confere o escopo da replicação externa já incorporada,
integra evidências, adjudica e atualiza o ledger. Ninguém se autoaprova.

O protocolo deve incluir os sete requisitos de
`coordination/2026-09-29_benchmark_round/g3_dispatch_requirements.md`, sob
`quality_reports/results/mebane_gates/`. Distinguir modelo integral inalterado,
problemas condicionados e modelos auxiliares. Um auditor que registra falhas de
geração não satisfaz automaticamente o gerador válido de G3-T1.

## Limites operacionais

- Apenas casos pequenos: enumeração N=1,2,3 e ensaios com no máximo oito unidades.
- Não executar n2000, Brasília completa, nacional ou replicação externa ajustada.
- Congelar sementes, dados, iterações, tolerâncias, diagnósticos e critérios de
  falha antes da primeira execução dos testes correspondentes.
- Usar o ambiente instalado, sem instalação, atualização ou mudança de engine
  silenciosa. Se a versão necessária estiver ausente, registrar a limitação.
- Limitar cada processo de teste a 120 segundos; teto de execução computacional
  da rodada de 12 minutos. Timeout é resultado preservado, não razão para relançar
  processo ainda ativo. Não aumentar iterações após observar falha diagnóstica.
- Não excluir nem restaurar arquivos, inclusive em scripts de limpeza. Saídas
  novas usam diretórios inéditos; preservar todos os logs e tentativas.
- Não alterar fontes congeladas, contratos G2, ledger ou artefatos anteriores
  pelo executor/revisor. A coordenação altera somente estado e evidências.

## Encerramento esperado

Entregar decisão explícita sobre JAGS como referência literal e sobre a não
equivalência do Stan histórico. Uma falha do alvo deve produzir contraprova
revisável e encaminhamento a G2/inconclusive, não aprovação de produção. G4/G10
não são liberados por execução bem-sucedida isolada ou por aprovação de código.
