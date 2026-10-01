# Replicação Mebane: Bolívia 2019

Plano autorizado em 01/10/2026. Objetivo: verificar nossa implementação contra
uma aplicação dos autores com resultados numéricos publicados, sem produzir
inferência eleitoral nova. Fonte de instrução: `user_request.txt` no diretório
de coordenação desta frente. O ledger executável é
`2026-10-01_bolivia2019_replication.json`, nesta mesma pasta de planos.

## Escopo e autorização

A preparação pode avançar em paralelo a D.C. 2010 A/D e à tradução D/Stan.
O pedido já autoriza o protocolo publicado após aprovação independente de
fontes, dados, especificação e recursos. O coordenador libera essas transições
técnicas sem pedir novamente a mesma autorização. Nenhuma estimação boliviana
pode interferir nos timings ainda abertos de D.C./Stan.

Preservar o **qbl publicado**, não substituir pelo modelo multinomial D.
Não instalar/substituir pacotes, excluir arquivos, sobrescrever resultados,
estender cadeias fora do wrapper aprovado, enviar mensagens a terceiros ou
iniciar inferência brasileira. Os resultados não aprovam automaticamente
G10, D/Stan ou produção. O gate histórico G10 e suas dependências permanecem
intactos; esta frente fornece evidência adicional, com correspondência abaixo.

## Gates e Goals

| Gate | Goal e entregável central | Dependência | Execução e checagem | Vínculo |
|---|---|---|---|---|
| B1: fontes | Arquivo de fontes e células numéricas publicadas rastreáveis | Nenhuma | Sol coleta/transcreve; outro agente confere no PDF | G10-T1 |
| B2: dados | CSV original ou reconstrução qualificada e validada em R | B1 aprovado | Sol prepara; revisor refaz transformações e avalia equivalência | G10-T1/T2 |
| B3: modelo e recursos | Contrato congelado de alvo, wrapper, critérios e recursos | B1 e B2 aprovados | Sol instrumenta; revisor metodológico separado; coordenador libera | G10-T2 |
| B4: execução | Uma tentativa do protocolo publicado, com draws e diagnósticos | B1-B3 aprovados e timings D.C./Stan encerrados | Sol executa sob supervisor; quatro cadeias paralelas se recursos aprovados | G10-T3 |
| B5: entrega | Revisão independente, comparação externa, Markdown/PDF e handoff | B4 entregue, inclusive eventual falha preservada | Revisor recompõe números brutos; coordenador adjudica | G10-T4 |

Cada gate iniciado recebe um goal finito e todos identificados no JSON. O
goal do executor termina ao entregar o candidato; o goal do revisor é outro.
Conclusão do executor não constitui aprovação. As escritas ficam separadas
por gate/round; o coordenador mantém o plano e a adjudicação. Sem orçamento
artificial de tokens. Se o recurso de goals não estiver disponível, registrar
a limitação em vez de simular um goal nativo.

## To-Dos e Critérios

**B1.** Revalidar versão do PDF, páginas impressas versus páginas do arquivo,
fontes contemporâneas e resultados por cadeia. Extrair médias, intervalos,
níveis e tipos dos intervalos com localizadores precisos, distinguindo fases
de verificação, amostra final e pós-processamento. Refazer busca delimitada
por `Bolivia2019Clean.csv`, `wrkef.R` e `obsfrauds_ciS.R`; a ausência anterior
não prova inexistência. Separar identidade comprovada, compatibilidade
plausível e desconhecido. Sementes, inicializações e versões não publicadas
continuam desconhecidas. Aprovação requer transcrição independente sem
discrepância material pendente.

**B2.** Recuperar a base original ou reconstruí-la da fonte eleitoral citada,
mantendo arquivos brutos e todas as transformações. Conferir `N=Inscritos`,
`W=MAS`, `V=soma dos votos dos partidos` e `A=N-V`, incluindo brancos/nulos,
filtros e ordem das mesas. Validar identificadores, tipos, ausências,
duplicatas, limites, contagens e totais. Totais iguais não provam igualdade
das linhas. Reconstrução exige parecer específico de adequação do alvo e
limitação explícita da equivalência ao input histórico.

**B3.** Auditar likelihood, latentes, pesos parcialmente ordenados, `k=0,7`,
seis efeitos locais, contagens auxiliares e extremos. No qbl arquivado,
`Exp(5)` incide nas **variâncias**, não nos desvios-padrão. Revalidar a chamada
publicada: `burn.in=5000`, `n.adapt=1000`, `n.iter=2000`, `n.chains=4`,
`parameters="all"`, `parComp=TRUE`, `autoConv=TRUE`, `max.auto=2`, MCMCSE
sobre `pi`, precisão `0,05`, `mcmcse.combine=TRUE`. Conferir o fluxo real do
wrapper: 2 mil iterações de verificação e mais 2 mil finais, com nova
adaptação, são contexto a verificar, não algo a deduzir de `n.iter`.

Ainda em B3: congelar diferenças de ambiente e inicializações prospectivas,
critérios de comparação por cadeia/agregados, arredondamento, Monte Carlo e
regras de inconclusividade antes dos resultados. A falta de draws ou MCSE
publicados limita um teste de equivalência. Quantificar RAM, disco, tempo,
cores e concorrência para 34.551 mesas e `parameters="all"`, incluindo
segmentos, quatro processos, serialização e diagnósticos. Fixar limites
numéricos e supervisor. Se não couber, registrar o impedimento, sem reduzir
monitores, trocar modelo ou serializar silenciosamente.

**B4.** Executar primeiro o protocolo publicado. Preservar inputs, modelos,
cadeias por segmento, logs, estados iniciais/finais, versões, módulos,
avisos e tempos. Extensões internas só se previstas no wrapper congelado;
nenhuma troca de seed, exclusão de cadeia ou aumento adicional silencioso.
Reproduzir o diagnóstico original e acrescentar trace plots, autocorrelação,
R-hat moderno, ESS bulk/tail e MCSE dos estimandos. Comparação sem precisão
adequada permanece descritiva. Timeout preserva saídas e encerra a tentativa.

**B5.** O revisor recompõe comparações dos artefatos brutos, examina dados,
código, protocolo e figuras, sem presumir que as cadeias publicadas
convergiram. O relato de discrepância em `beta.chi.m` também deve ser
revalidado. Entregar scripts R, fontes, manifesto, Markdown/PDF revisado
visualmente e handoff. Emitir três vereditos separados: fidelidade da
implementação, reprodução dos números publicados e qualidade da amostragem.

Se faltar insumo indispensável, concluir as etapas independentes possíveis
e identificar precisamente o bloqueio. Não marcar etapas não executadas
como concluídas, nem transformar isso em exigência de autorização já dada.

## Fontes Iniciais

Estado após preparação B1: o revisor conferiu os 51 registros e 194 células
numéricas sem erro de transcrição. O coordenador aceitou esse escopo, mas
não deu PASS integral ao gate: definições operacionais dos agregados e
intervalos continuam incompletas. O CSV limpo e os dois scripts externos
não foram localizados. Ver `B1/round1/adjudication.json` e o adendo às
referências no diretório de coordenação desta frente.

A revisão identificou uma inconsistência da própria fonte: a soma dos
partidos é 6.137.671, enquanto `Votos.Válidos` imprime 6.137.778, diferença
de 107. B2 deve investigar a discrepância, mantendo a fórmula publicada
`NValid=soma dos partidos`; não corrigir silenciosamente. A preparação
independente de dados pode continuar, sem adoção de input nem estimação.

- Mebane, Walter R., Jr. (2019). *Evidence Against Fraudulent Votes Being Decisive in the Bolivia 2019 Election*. Versão de 13 de novembro. [PDF do autor](https://websites.umich.edu/~wmebane/Bolivia2019.pdf). Versão e conteúdo serão revalidados em B1.
- Ferrari, Diogo; McAlister, Kevin; Mebane, Walter R., Jr.; Wu, Patrick Y. (2019). *eforensics*, versão 0.0.4, commit candidato `3017de537450f97a01872d0157462a68bea348ee`. [Repositório público](https://github.com/UMeforensics/eforensics_public/tree/3017de537450f97a01872d0157462a68bea348ee). A coincidência com A em D.C. não prova qual commit foi usado na Bolívia.
- Descoberta anterior: `quality_reports/results/mebane_gates/coordination/authors_replication_discovery/discovery.md`. PDF local em `archive/Bolivia2019.pdf` nesse diretório; preservar ambos.
