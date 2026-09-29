# G0 round2: candidato reparado para QA independente

Executor SOL-BASELINE, goal nativo finito `01a0eaba-2cec-74f3-bca0-8c27b736567e`. Esta rodada repara apenas F1-F3 de `round1`. O gate continua `changes_requested` ate rechecagem independente e adjudicacao pelo coordenador. Nenhum artefato da rodada ou revisao anterior foi alterado.

## Resultado delimitado

- O inventario base de 108 arquivos de `round1/inventory.json` e complementado por `inventory_additions.json` com cinco omissoes materiais: manuscrito e quatro tabelas historicas. O snapshot evita que uma mudanca posterior no manuscrito ou nas tabelas altere o baseline assinado. Nenhuma tabela foi recalculada.
- O lockfile agora tem 180 registros. `lock_verification.json` confirma preservacao dos 174 anteriores, 13 pacotes na clausura dos roots `diptest`/`spikes`, zero faltantes, nenhuma dependencia direta ausente na varredura de `R/*.R` e seis versoes literais iguais aos `DESCRIPTION` instalados. Nao houve instalacao, atualizacao, `renv::restore()` nem MCMC.
- A secao Dados do README distingue integridade local do ZIP e recuperacao externa. URL/data originais de obtencao continuam desconhecidas; nao ha afirmacao de irrecuperabilidade fora deste checkout. A copia local do ZIP e o hash estao em `round1/inventory.json` e `round1/sources.md`.
- `final_state_map.json` une snapshots imutaveis de `round1` aos oito arquivos de F1-F3 e ao snapshot corrente do ledger. `gate_contract.json` e a projecao estatica G0; `run.json` e `candidate_manifest.json` registram os inputs, codigo, configuracao e outputs efetivamente usados sem depender de caminhos canonicos mutaveis.

## Limites

G0 nao atesta validade dos testes suplementares, inferencia sobre fraude/ausencia, equivalencia JAGS-Stan, reproducao fria do ambiente ou obtencao externa do ZIP historico. Os loads de fit e base, os checks de PDF, as cadeias e seus limites permanecem documentados em `round1`, que esta no manifesto por seus artefatos congelados. Revisao independente precisa conferir a completude desta nova rodada, nao herdar `manifest_complete` da rodada reprovada.
