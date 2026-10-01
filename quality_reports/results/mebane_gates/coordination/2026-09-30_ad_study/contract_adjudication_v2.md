# Contrato A/D v2: reparo conferido

A versão 2, SHA-256 `d17b7f508a7ce87eec3ca71ed7df67666b528c755e005ec9e1299e5ff9deb509`, recebeu revisão independente favorável do delta. O achado AD-CONTRACT-QA-01 permanece confirmado no histórico, mas seu reparo foi verificado: a tabela fixa 2.171 alvos obrigatórios em A e 1.742 em D, com as regras numéricas, a escala das contagens e a consequência de cada falha.

R-hat menor que 1,01 e ESS bulk/cauda de pelo menos 400 são exigidos nos alvos obrigatórios. Indicadores e contagens de classe têm também teto de cinco pontos percentuais para a amplitude das médias entre cadeias, dividindo somente as contagens pelo número de unidades nessa checagem. Esse teto é uma escolha operacional prospectiva, não um teste de fraude. Não há isenção empírica para constância apenas amostral; estatística obrigatória indefinida torna o piloto inconclusivo. A reconstrução secundária de contagens não pode resgatar a precisão da posterior primária.

Veredicto da adjudicação: **NO_CONFIRMED_DEFECTS**, apenas para o contrato experimental corrigido. A implementação e os testes executáveis ainda precisam de revisão antes de qualquer ajuste real. O usuário já autorizou este estudo; não é necessária outra autorização para executar suas etapas quando esses checkpoints estiverem satisfeitos. Produção, G3 e G10 continuam sem aprovação por este documento.
