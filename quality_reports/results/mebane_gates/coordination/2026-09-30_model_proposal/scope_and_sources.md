# Escopo e fontes do lote de 30/09/2026

O usuário autorizou o fechamento documental de G3 e uma proposta comparativa,
sem adotar nova especificação nem iniciar estimação. O lote não inclui G10,
pilotos, inferência nacional, instalação, commit/push, comunicação externa
ou exclusão de qualquer arquivo. Os termos do benchmark literal permanecem
intactos. Nenhum critério de MCMC foi modificado retroativamente.

## Papéis e separação

- Coordenação `019d795a-acfa-72c2-a210-d55a46c606c2`: adjudicação de evidência,
  proposta matemática, exemplos determinísticos, atualização documental e PDF.
- Executor Sol `01a0ee04-c901-7831-8ac6-0160da2e3883`: reconstrução de sete
  versões históricas de código, exclusivamente em `provenance_repair/`.
- Revisor independente `01a0ee05-aeaf-7492-a8ea-fa731dd6214a`: novo goal de QA,
  exclusivamente em `review/`; não implementa o reparo nem escreve a proposta.

A revisão é técnica de um documento de 2.492 palavras e de um reparo documental,
por um revisor independente. Não é uma revisão com múltiplos leitores,
reestruturação de manuscrito ou reescrita adversarial. O leitor recebe o documento
inteiro, hashes e suas não-afirmações; não há um PASS interpretativo separado.

## Identidades locais conferidas

- Proposta v1: SHA-256 `7fe462ed99561dee68d49fe1c5595845664249060459d018b4d01829fd61153c`.
- Contrato matemático G2 em `appendices/mebane_model_contract.md`:
  `22b7eac49bb7c900f4c34306fb1074025dbdbee0da2ed8d80f00e5cbc71d2b11`.
- Fonte literal JAGS: `f8360126424b7a463f76a1c99efc89a8a5cb81339213bd4931559f14595fbab6`.
- P22 local: `ad3b1cd473d48540877fb00cdffaaa09df1a21a98e4a2b4fa0a03c227ec50d76`.
- P23 local: `615ddab21034e22ca55d891e01f14b85a2e7d80e12238bfbfb142ff214531431`.
- A integridade dos 350 itens declarados pelo candidato revision3 foi conferida
  por `audit_inputs.py`; o resultado e cópias pré-edição dos documentos centrais
  estão em `input_audit.json` e `before/`. O script recusa sobrescrita.

Os títulos/autores/datas dos artigos foram lidos nas extrações arquivadas G2.
A especificação usada nesta proposta foi conferida no contrato e na fonte JAGS;
não houve nova leitura integral dos PDFs nem tentativa de atualizar suas versões.

## Consultas públicas em 30/09/2026

- <https://websites.umich.edu/~wmebane/pm23.pdf>: timeout; não usado como uma
  obtenção nova. A cópia local congelada continua sendo a referência.
- <https://mc-stan.org/posterior/reference/ess_tail.html>: documentação 1.7.1,
  definição de ESS de cauda, formato iterações por cadeias e comportamento NA.
- <https://mc-stan.org/docs/functions-reference/multivariate_discrete_distributions.html>:
  manual 2.40, definição da multinomial e `multinomial_lpmf`.
- <https://mc-stan.org/docs/stan-users-guide/finite-mixtures.html>: manual 2.40,
  marginalização da classe e `log_sum_exp`.
- <https://doi.org/10.1214/20-BA1221>: erro de obtenção. A referência bibliográfica
  foi conferida na página primária de posterior, sem nova leitura integral.
- A página “Simplex Distributions” do manual Stan foi aberta como contexto, mas
  não é evidência adicional sobre a identificação do modelo eleitoral.

Links não significam aquisição de novos dados nem atualização de pacotes.

## Tentativas e resultados determinísticos

O script `check_proposals.R` não contém amostragem ou estimação. As tentativas
`checks01` e `checks02` falharam por problemas delimitados de implementação:
cancelamento na razão condicional em fronteira e propagação de nomes em R.
As versões efetivas do script e notas das falhas estão preservadas. O teste
`boundary_probe.R` reproduz o primeiro problema sem tolerância ou clamp.

`checks03` passou em 83 configurações de parâmetros, cada uma para N=1,2,3,4:
332 distribuições. O maior erro absoluto na equivalência mecanismo/multinomial
foi 2,7755575615628914e-16; na fatorização sequencial, 5,5511151231257827e-16;
nas médias condicionais de M/S, 8,8817841970012523e-16. Tolerância 1e-11 em
todas as tentativas. Há também checagens das duas ordens de normalização.

Esses resultados não liberam G3/G4/G10 nem provam identificação, desempenho,
convergência ou adequação ao Brasil. Os diagnósticos antigos permanecem sujeitos
ao protocolo antigo e ao parecer independente que os classificou inconclusivos.
