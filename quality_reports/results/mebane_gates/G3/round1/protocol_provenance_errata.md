# Errata de proveniência e interpretação, sem retuning

Quem inspecionou `protocol.json` v1 e encaminhou o preflight foi o
**COORDENADOR**, não o usuário. As atribuições em `preflight_v1.md` e no campo
`protocol_v2.json.reason` estão incorretas nesse ponto. Os arquivos de
protocolo congelados permanecem byte-intactos; critérios numéricos e seeds não
mudam. A errata integra a interpretação de todas as saídas desta rodada.

Na comparação condicionada N=1, A=0, W=0, `Dobs=1` é um **deslocamento
algébrico de fixture**. Não é uma margem eleitoral realizável a partir da
observação (votos no líder zero). M, S e as duas expressões de margem são
testes de álgebra por draw, não validação de contrafactual físico. Registrar
`observed_margin_compatible=false` e flags de capacidade sem clipping. Um
resultado MC que passe nesses funcionais não satisfaz, por si só, a validação
física da margem nem fecha G3.
