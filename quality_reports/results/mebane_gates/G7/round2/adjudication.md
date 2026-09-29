# Adjudicação G7 round2

**G7 aprovado para prontidão operacional ensaiada.** Nenhum novo defeito encontrado; os três findings anteriores foram reparados e verificados, sem reclassificá-los como refutados.

## G7-R1-COORD-F03

Leitura preserva bytes UTF-8 após validação explícita, sem mudar locale. Controle ASCII, nome acentuado NFC, sequência decomposta e nome com vírgula/apóstrofo passaram ponta a ponta em C e pt_BR.UTF-8. CSV, seleção em configuração, recibo e snapshots preservam identidade exata; byte inválido, sequência truncada/overlong e NUL falham por mensagem específica.

## G7-R1-QA-F01

Datas configuradas por turno são válidas, ordenadas e comparadas exatamente ao EA11. Datas erradas no mesmo ano são recusadas em T1/T2. Configurações incompletas, impossíveis, numéricas, vetoriais ou com turno extra falham pela guarda de datas. A configuração 2026 corresponde à nota arquivada e à URL oficial do calendário; a data T2 permanece condicional e seu código vem do EA11 recebido. Casos 2026 T1/T2 com datas, códigos, cargo, controles e 28 UFs coerentes chegam ao erro específico Candidate selection unresolved for turn.

## G7-R1-QA-F02

O recibo declara universo territorial, UFs esperadas/referenciadas/observadas e contagens por UF. Referência sem UF esperada ou com UF extra falha especificamente; ausência de votos em uma UF aparece como incomplete_coverage e na contagem local. Uma seção e uma referência mínima cobrindo as 28 siglas podem ser completas somente em relação ao EA16 fornecido. national_coverage_attested, data_ready e inference_ready permanecem false, inclusive com fase/URL/rótulo oficial sintéticos.

## Evidência e limites

A coordenação leu o código e o parecer, verificou 1.859 arquivos do candidato e 1.173 da QA e executou oito testes próprios em C e pt_BR.UTF-8. A QA executou 69 casos próprios em cada locale, oito casos do DAG e as suítes afetadas; 25 recibos foram byte-idênticos. Os 1.066 arquivos de round1 estão preservados e as fontes antigas são recuperáveis pelo mapa de 1.094 cópias.

A aprovação abrange CSV normalizado por seção/candidato, referências, controles, snapshots e roteiro. Não atesta voto real, cobertura nacional ou convergência. Falta conversor auditado dos arquivos oficiais brutos. Todos os recibos continuam data_ready=false, inference_ready=false e national_coverage_attested=false. Ingestão serial ou lock externo; escala/memória ainda não testadas nacionalmente.

G0/G1 permanecem aprovados; G2 continua changes_requested por escolhas metodológicas. Nenhum MCMC, instalação ou aquisição de votos de 2026 ocorreu neste reparo. G8/G9 não foram liberados.
