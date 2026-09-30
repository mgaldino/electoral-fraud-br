# Nota do teste documental

As duas primeiras execuções de `check_prerequisites.py` terminaram com exit code 1
no teste `external_contract_review_precedes_fit`, antes de criar o output. A
primeira correção normalizou whitespace, mas não resolveu: o probe buscava
"hash do contrato" e "T2/T3", enquanto a regra escrita diz "conferir o hash
aprovado" e "Esse checkpoint de G10-T2 fixa caso", na seção que começa "Antes
de G10-T3". A segunda correção usa os trechos efetivamente inspecionados.
O protocolo e seus critérios não foram alterados. Isso foi erro do probe
textual, não falta da exigência de revisão prévia em G10 nem teste científico.
