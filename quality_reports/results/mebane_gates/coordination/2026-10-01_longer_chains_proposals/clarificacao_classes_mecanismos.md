# Incremental/extrema e fabricação/transferência

Verificação do coordenador em 01/10/2026, após a observação do usuário:

> Pela teoria, o mecanismo sugerido é que a incremental é pegando quem não vota e colocando como votando em um candidato. Extrema é mudar o voto do candidato A para B. Isso que diz o paper que li.

## Resultado verificado

Nos dois textos de Mebane que fundamentam o contrato atual, essa associação
exclusiva não corresponde à especificação formal. A origem dos votos distingue
fabricação de transferência; a intensidade distingue incremental de extrema.
Ambos os mecanismos aparecem nas duas classes com fraude. Essa afirmação
vale para as versões identificadas abaixo, não para um artigo não identificado
que o usuário possa ter em mente.

| Dimensão | Definição nos textos examinados |
|---|---|
| Fabricação, M | Abstenções verdadeiras convertidas em votos contabilizados para o beneficiário. |
| Transferência, S | Votos verdadeiros da oposição convertidos em votos contabilizados para o beneficiário. |
| Incremental, Z=2 | Intensidades moderadas para os dois mecanismos, com parâmetros próprios. |
| Extrema, Z=3 | Intensidades altas para os dois mecanismos, também com parâmetros próprios. |

Em P22, seção 2.1, p. impressa 5, a definição narrativa distingue proporções
moderadas de proporções próximas da totalidade, em ambos os reservatórios.
A p. 6 introduz quatro proporções: iota-M e iota-S na classe incremental;
upsilon-M e upsilon-S na extrema. As equações (2c) e (2d) são explicitamente
indexadas por `l in {M,S}`; `k=.7` separa os intervalos das intensidades.

Em P23, p. impressa 6, equação (2b), tanto o ramo `Z=2` quanto o ramo `Z=3`
somam um termo de fabricação e um de transferência. O parágrafo logo abaixo
explica os dois reservatórios. Essa verificação não depende de interpretar
a equação (4d), cuja omissão tipográfica de `k` já foi registrada no contrato.

Na especificação contínua de P22, por exemplo, fabricar 20% das abstenções
e transferir 10% dos votos da oposição é uma configuração incremental.
Fabricar 80% e transferir 90%, respectivamente, é uma configuração extrema.
Os percentuais têm denominadores distintos. No qbl literal A, a separação
de .7 governa médias/probabilidades binomiais auxiliares, não impede que
realizações dessas auxiliares cruzem o limiar. Essa diferença A/artigo
permanece documentada; não muda os nomes dos quatro mecanismos/parâmetros.

## Consequência para a proposta

Impor `pi2 >= pi3` afirma que a classe incremental é ao menos tão prevalente
quanto a extrema. Não afirma que fabricação seja mais frequente ou maior
que transferência. Comparar esses mecanismos demanda examinar suas quatro
intensidades e os totais conjuntos M/S, com denominadores explícitos.
Uma desigualdade entre as intensidades também não implica a mesma
desigualdade entre os totais, pois os reservatórios diferem.

O comentário do usuário não é interpretado como confirmação de parâmetros,
prioris ou protocolo de nova amostragem. JAGS 100k/Stan 5k continuam
aguardando a confirmação das propostas. Nenhum modelo ou critério foi alterado.

## Fontes e verificação

1. Mebane, Walter R., Jr.; Ferrari, Diogo; McAlister, Kevin; Wu, Patrick Y. 2022. *Measuring Election Frauds*. Manuscrito, versão de 6 de março. Seção 2.1, pp. impressas 5–6, páginas 7–8 do PDF. [Fonte do autor](https://websites.umich.edu/~wmebane/measfrauds.pdf). Cópia verificada: `quality_reports/results/mebane_gates/coordination/measfrauds_2022-03-06.pdf`, SHA-256 `ad3b1cd473d48540877fb00cdffaaa09df1a21a98e4a2b4fa0a03c227ec50d76`.
2. Mebane, Walter R., Jr. 2023. *Lost Votes and Posterior Multimodality in the eforensics Model*. PolMeth 2023, versão de 2 de julho. Seção 2.1, p. impressa 6, página 8 do PDF, equações (2a)–(2b). [Fonte do autor](https://websites.umich.edu/~wmebane/pm23.pdf). Cópia verificada: `quality_reports/results/mebane_gates/coordination/pm23_2023-07-02.pdf`, SHA-256 `615ddab21034e22ca55d891e01f14b85a2e7d80e12238bfbfb142ff214531431`.

Foram conferidos os hashes, a extração textual arquivada e as três páginas
renderizadas integralmente. Não se afirma leitura integral dos artigos nesta
verificação. A consulta web retornou P22, mas tentativas de atualização dos
endpoints foram intermitentes; as versões locais com hashes acima são a base
exata do veredito. Re-renderização somente para leitura, sem editar os PDFs.
