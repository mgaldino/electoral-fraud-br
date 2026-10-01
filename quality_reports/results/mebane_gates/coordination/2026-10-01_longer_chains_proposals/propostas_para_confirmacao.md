# Próxima rodada: escolhas para confirmação

01/10/2026. **Nenhuma nova amostragem ou mudança de priori foi iniciada.**
Este documento consolida propostas; não é um contrato de execução aprovado.
O comentário posterior sobre mecanismos não foi interpretado como autorização.

## 1. Esclarecimento conceitual

Nos textos de Mebane de 2022 e 2023 examinados, incremental/extrema distinguem
intensidade. Fabricação a partir de abstenções e transferência da oposição
ocorrem nas duas classes. Coordenador e Curie conferiram essa leitura
separadamente no texto e nas páginas renderizadas. Ver
`clarificacao_classes_mecanismos.md` e `model_proposals/proposals.md`.
Se o usuário se referir a outra formulação, comparar o trecho específico;
não impor mecanismos exclusivos ao modelo atual por inferência da conversa.

## 2. Configuração das cadeias

Proposta comum: mesmas 143 unidades de D.C. 2010; A/JAGS e D/JAGS com
100.000 draws retidos por cadeia; D/Stan com 5.000. Quatro cadeias paralelas,
um ajuste pesado por vez, thin=1, sem misturar draws antigos com novos.

| Escolha a confirmar | Adaptação JAGS | Burn-in JAGS | Warmup Stan | Justificativa |
|---|---:|---:|---:|---|
| Conservadora, recomendada pelo coordenador | 1.000 | 5.000 | 2.000 | Mantém a preparação anterior, com descarte fixo já muito menor que a amostra retida; evita reduzir preparação e aumentar comprimento ao mesmo tempo. |
| Mais curta, proposta por Maxwell | 1.000 | 2.000 | 1.000 | Menor custo; suficiência desse encurtamento ainda não demonstrada. |

Os números são por cadeia. Em Stan, manter `adapt_delta=.99`,
`max_treedepth=12`, `parallel_chains=4`, um thread por cadeia. Em JAGS,
usar processos independentes com persistência em blocos, sem reinicializar
a cadeia entre blocos. Sementes, inicializações e implementação do runner
paralelo precisam ser congeladas e verificadas antes da execução autorizada.
Não considerar a ausência de divergências como prova de mistura adequada.

Recursos observados: 14 núcleos, 36 GiB físicos e 268 GiB disponíveis em
disco. Isso não mede RAM disponível, pico de RSS ou speedup. Verificar
novamente antes de rodar. A carga numérica simples de A/JAGS100k é 6,016 GB;
D/JAGS100k, 4,6432 GB; array completo D/Stan5k, 0,7824 GB, todos antes de
cópias, estados, CSVs e diagnóstico. O preflight deve evitar cópias integrais
desnecessárias. Proposta inicial de limites: 60 min para geração e 60 min
para diagnóstico de cada ajuste, até 24 GiB de RSS agregado do ajuste,
preservando pelo menos 20 GiB livres em disco. Esses limites também aguardam
confirmação e teste de implementação; nenhuma estimativa de tempo é garantia.
Se houver falha ou limite atingido, preservar os parciais e não reiniciar,
estender, eliminar cadeia ou mudar o modelo automaticamente.

## 3. Priori e precisão

**Recomendação atual: executar primeiro somente o baseline, sem alterar
prioris.** As duas sensibilidades abaixo são alternativas científicas,
não reparos técnicos já autorizados:

- Ordem completa de pesos em D: condicionar a priori a `pi1 >= pi2 >= pi3`, preservando todo o restante. Não ordena fabricação versus transferência.
- Priori mais concentrada de intensidade em D: o agente calculou um exemplo com mediana incremental de 10%, intervalo marginal a priori de 95% aproximadamente [3,8%, 23,0%] e menor heterogeneidade. Esses valores não têm justificativa externa específica para este caso. Não recomendo executá-los sem discutir essa crença substantiva; os detalhes estão em `model_proposals/proposal.md`.

Os diagnósticos existentes não sustentam dispensar o problema como apenas
imprecisão de cauda: todos os globais reprovados também têm ESS bulk <400.
Os principais gargalos são pesos `pi1/pi2`, intensidades incrementais e
totais M/S; em Stan, também o bloco de voto legítimo `nu`. `pi3` supera
9.000 de ESS bulk nos três ajustes. A hipótese de regularização insuficiente
é plausível, mas ainda não foi estabelecida como causa única.

A proposta de comunicação prospectiva separa centro e caudas: manter os
diagnósticos centrais; caso somente quantis falhem, relatar caudas imprecisas
sem transformar a estimação em PASS integral. As tolerâncias numéricas de
MCSE propostas por Curie estão no memorando e ainda não foram adotadas.
Indicadores raros/constantes exigem tratamento próprio, não aprovação de NA
nem substituição dos quantis de totais ativos pelos de suas médias condicionais.
Todos os critérios e resultados históricos permanecem intactos.

## 4. O que foi conferido e o que falta confirmar

O coordenador conferiu os 69 globais e 897 células numéricas contra a
comparação anteriormente revisada: diferença zero. Maxwell recompôs 78
alvos focados sem thinning. A revisão independente da rodada antiga já
confirmou os 23 globais de cada ajuste e todos os 860 internos Stan.
Não se afirma nova recomputação independente de cada diagnóstico local.
O modelo/prioris foi examinado por Curie, separadamente do diagnóstico Sol;
o coordenador conferiu a leitura das fontes e a aritmética relevante.

Confirmar: **configuração conservadora ou curta; somente baseline ou alguma
sensibilidade adicional; limites de recursos; e eventual regra prospectiva
de comunicação parcial**. As sensibilidades podem continuar apenas como
estudo sem bloquear a decisão sobre o baseline. Após confirmação, o runner
e o contrato exato precisam de preflight independente; aprovação desta
proposta não implica que esse preflight já esteja feito. Não liberar Brasil,
Bolívia ou produção automaticamente.

Documentos dos agentes: `diagnostics/diagnostic_proposal.md` e
`model_proposals/proposals.md`. Evidência coordenadora:
`verify_global_rankings.R`, `global_rankings_parent_check.txt` e
`clarificacao_classes_mecanismos.md`.
