# Anexo A — Escolha do denominador no vote share: nominais vs comparecimento

## Contexto

A análise de *electoral fingerprint* (Klimek et al. 2012; Kobak et al. 2016; Mebane 2023) usa a distribuição conjunta de (turnout, vote share) como superfície de detecção de irregularidades. Ambos os eixos são razões, e a escolha dos denominadores afeta tanto o suporte quanto o formato da distribuição empírica observada — e, portanto, a interpretação visual que a análise descritiva permite. Este anexo documenta a escolha feita por este parecer, contrasta com a escolha dos autores da nota original, e reporta a verificação empírica que mostrou que as duas fontes de dados usadas na nota (TSE e Nexojornal) são internamente consistentes entre si.

## Quantidades observáveis no TSE por seção eleitoral

Para cada seção × turno, o arquivo `detalhe_votacao_secao_2022_BR.csv` do TSE reporta:

| Coluna TSE | Conteúdo |
|---|---|
| `QT_APTOS` | Eleitores aptos (denominador da turnout) |
| `QT_COMPARECIMENTO` | Eleitores que compareceram = nominais + brancos + nulos (+ resíduos de legenda/anulados) |
| `QT_VOTOS_NOMINAIS` | Votos dados a candidatos (exclui brancos e nulos) |
| `QT_VOTOS_BRANCOS` | Votos em branco |
| `QT_VOTOS_NULOS` | Votos nulos |

Identidade contábil (desprezando resíduos de legenda e anulados apurados à parte):

$$\text{QT\_COMPARECIMENTO} \approx \text{QT\_VOTOS\_NOMINAIS} + \text{QT\_VOTOS\_BRANCOS} + \text{QT\_VOTOS\_NULOS}$$

## Turnout

O denominador da turnout não está em disputa na literatura:

$$\text{turnout} = \frac{\text{QT\_COMPARECIMENTO}}{\text{QT\_APTOS}}$$

Este parecer e os autores da nota calculam turnout exatamente da mesma forma.

## Vote share: três escolhas possíveis

Para o vote share do candidato $j$ em uma seção, há três denominadores tecnicamente defensáveis:

**(A) Comparecimento** — padrão da literatura internacional de *election forensics*:
$$s_j^{\text{comparecimento}} = \frac{\text{QT\_VOTOS}_j}{\text{QT\_COMPARECIMENTO}}$$

**(B) Nominais** — padrão constitucional brasileiro:
$$s_j^{\text{nominais}} = \frac{\text{QT\_VOTOS}_j}{\text{QT\_VOTOS\_NOMINAIS}}$$

**(C) Válidos + brancos** — variante raramente usada:
$$s_j^{\text{válidos+brancos}} = \frac{\text{QT\_VOTOS}_j}{\text{QT\_VOTOS\_NOMINAIS} + \text{QT\_VOTOS\_BRANCOS}}$$

## Escolha (B): o sentido constitucional brasileiro de "votos válidos"

O Art. 77 §2º da Constituição Federal do Brasil estabelece: *"Será considerado eleito Presidente o candidato que, registrado por partido político, obtiver a maioria absoluta de votos, não computados os em branco e os nulos."* A tradição jurídica e jornalística brasileira chama de "votos válidos" exatamente o que o TSE chama de `QT_VOTOS_NOMINAIS`: votos dados a candidatos, excluindo brancos e nulos. É o denominador usado para apurar quem ganhou uma eleição presidencial no Brasil.

## Escolha (A): o padrão da literatura de election forensics

Klimek et al. 2012 (PNAS), Kobak et al. 2016 (AOAS) e Mebane 2023 adotam (A). A justificativa é principalmente analítica e conceitual:

1. **Identidade contábil com turnout.** Usando (A), o produto dos dois eixos do fingerprint tem interpretação direta:
$$\text{turnout} \times s_j^{\text{comparecimento}} = \frac{\text{QT\_COMPARECIMENTO}}{\text{QT\_APTOS}} \times \frac{\text{QT\_VOTOS}_j}{\text{QT\_COMPARECIMENTO}} = \frac{\text{QT\_VOTOS}_j}{\text{QT\_APTOS}}$$
ou seja, a fração dos eleitores aptos que votaram em $j$. Com (B) essa identidade se quebra porque `QT_COMPARECIMENTO` ≠ `QT_VOTOS_NOMINAIS`.

2. **Interpretabilidade do canto (1,1).** Em fingerprint analysis, o canto superior direito da distribuição conjunta (turnout = 1, vote share = 1) corresponde à assinatura clássica de ballot stuffing: seções onde todos os eleitores compareceram e todos votaram no candidato beneficiado. Usando (A), o canto (1,1) é atingível analiticamente sem contradição. Usando (B), uma seção com turnout = 1 e `vote_share_nominais = 1` requer que ninguém tenha votado em branco nem nulo — uma restrição a mais que distorce a forma da distribuição perto do canto.

3. **Estabilidade regional.** A taxa de votos brancos e nulos varia sistematicamente por região, escolaridade e competitividade local. Usando (A), essa variação permanece absorvida no vote share (brancos/nulos puxam o vote share para baixo onde são frequentes). Usando (B), a variação regional em brancos/nulos é expulsa do denominador e distorce a comparabilidade cross-section entre regiões com perfis eleitorais diferentes.

4. **Separação conceitual de dois comportamentos distintos.** A decisão "comparecer ou abster" e a decisão "votar em candidato X vs. votar em branco/nulo" são comportamentos distintos, e a literatura de election forensics busca modelar os dois separadamente. Misturá-los no denominador (escolha B) contamina o eixo vote share com informação que deveria estar em outro lugar.

## Verificação empírica: consistência inter-níveis dos autores da nota

Os autores da nota de Figueiredo, Carvalho e Santano usam duas fontes de dados:

- No nível **município**: planilha do Nexojornal, com coluna `validos`.
- No nível **seção**: arquivos CSV do TSE, com coluna `QT_VOTOS_NOMINAIS`.

Como o termo "válidos" em português tem dois sentidos possíveis (constitucional = só nominais; contábil = nominais + brancos + nulos), havia uma suspeita inicial de que a coluna `validos` do Nexojornal pudesse corresponder ao sentido contábil (comparecimento), enquanto o script dos autores explicitamente usa `QT_VOTOS_NOMINAIS` no nível seção. Se fosse o caso, os dois níveis estariam calculando vote share com denominadores numericamente diferentes — o que introduziria viés artificial na comparação visual cross-level que a nota faz.

Para resolver empiricamente, agregamos os votos de Lula e Bolsonaro do nível seção até o nível município somando numeradores (`sum(QT_VOTOS_candidato)`) e denominadores (`sum(QT_VOTOS_NOMINAIS)`) separadamente, e comparamos o `vote_share_nominais` resultante com o `validos` reportado pelo Nexojornal nos mesmos municípios.

**Resultado** (Lula T1, Lula T2, Bolsonaro T1, Bolsonaro T2, em 11.417 municípios-turno pareados):

| Denominador TSE | max abs diff vs Nexojornal | corresponde? |
|---|---:|:---:|
| `QT_COMPARECIMENTO` | 0.1078 | Não |
| `QT_VOTOS_NOMINAIS + QT_VOTOS_BRANCOS` | 0.1071 | Não |
| **`QT_VOTOS_NOMINAIS`** | **0.0000** | **Sim** |

A diferença é exatamente zero na terceira linha — não aproximada, zero. A coluna `validos` do Nexojornal é numericamente idêntica à soma de `QT_VOTOS_NOMINAIS` agregada do TSE. Portanto:

> **Os autores da nota são internamente consistentes entre os dois níveis. Ambos os níveis adotam a escolha (B), nominais.**

A crítica original sobre "denominadores inconsistentes entre níveis" (apontada na revisão do script em `quality_reports/reviews/2026-04-10_review-r-authors-script.md`) **cai**. O que permanece válido como crítica é apenas que (B) é uma escolha não-padrão na literatura de election forensics, e que o paper deles não discute essa escolha nem sua implicação sobre a interpretação visual do fingerprint — mas essa é uma crítica de justificação metodológica, não de consistência interna.

## Escolha deste parecer: rodar ambas as especificações em paralelo

Dado que (A) e (B) são ambas defensáveis — (B) por reproduzir exatamente o que os autores fizeram e por estar alinhada com o sentido constitucional brasileiro; (A) por ser o padrão da literatura internacional de *election forensics* e por preservar a identidade contábil com turnout — este parecer segue ambas como especificações de primeira classe. Todas as análises centrais (Bloco 3 e posteriores do plano de reconstrução metodológica) são executadas em paralelo sob (A) e (B), e a robustez qualitativa dos resultados é avaliada comparando as duas colunas.

A escolha (C), `QT_VOTOS_NOMINAIS + QT_VOTOS_BRANCOS`, não é analisada como primeira classe por ser uma variação mecânica de (B) que não tem base teórica nem na literatura internacional nem na tradição jurídica brasileira.

## Referências

- Constituição da República Federativa do Brasil (1988). Art. 77, §2º.
- Klimek, P., Yegorov, Y., Hanel, R., & Thurner, S. (2012). "Statistical detection of systematic election irregularities." *Proceedings of the National Academy of Sciences*, 109(41), 16469–16473.
- Kobak, D., Shpilkin, S., & Pshenichnikov, M. S. (2016). "Integer percentages as electoral fingerprints." *The Annals of Applied Statistics*, 10(1), 54–73.
- Mebane, W. R. Jr. (2023). "Election fraud statistical analysis."
- Figueiredo, Carvalho, Santano (2026). "Is there evidence of fraud in Brazil's 2022 presidential election?" Research note. Script de replicação `script_paper_sig.R`.

---

*Este anexo é gerado durante o Bloco 1 Fase B da reconstrução metodológica e se destina a integrar a seção de apêndices do paper revisado (Bloco 8 do plano).*
