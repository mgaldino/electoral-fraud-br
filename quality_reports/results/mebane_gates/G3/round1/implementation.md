# G3 round1: candidato do executor

## Escopo e decisão

Fonte integral JAGS inalterada: `G0/round1/qbl_installed_3017de5.jags`, SHA-256
`f8360126424b7a463f76a1c99efc89a8a5cb81339213bd4931559f14595fbab6`.
R 4.4.2, JAGS 4.3.2, pacotes existentes em renv. O benchmark é o contrato
G2 round2, cuja aprovação vigente é G2 round3. Este candidato não promove G3.

O JAGS pode permanecer referência **literal de software**, não gerador físico
certificado nem engine de produção aprovada. O Stan histórico é aproximado e
não equivalente; nenhum Stan novo foi acrescentado. A comparação numérica
executada condiciona efeitos contínuos, coeficientes e auxiliares de `pi`:
não é portagem nem validação do modelo integral não condicionado.

## Evidência por requisito do despacho

1. Fonte integral compilada nos probes. Dados e inits foram separados:
   contagens inválidas ativas em dados ou inits produziram `Error in node w / Invalid parent values`
   na compilação. Componentes inativos com as mesmas contagens compilaram.
   O probe de contagem estocástica atualizou 20 passos sem erro; propostas
   internas/rejeições não são observáveis por esse ensaio. Observações `a,w`
   ambas ausentes ou parcialmente condicionadas compilaram e amostraram.
2. Enumeração completa das quatro contagens e Z e forma fatorada concordaram
   em 29 células N=1,2,3 (erro máximo 2.5e-16). O kernel de diagnóstico
   zera probabilidades inválidas, mas não é likelihood normalizada: massa
   total 0.9999584, 0.9999407, 0.9999317; massa física respectivamente
   0.9999584, 0.9543224, 0.9341464. A normalização explícita muda o alvo.
   JAGS não foi atestado como realizando essa normalização.
3. Contraprova mínima: N=A=R_iota_m=1, R_iota_s=0, Z=2,
   tau=nu=0.5 gera `p.w=499.5`. É suporte de pais com massa positiva, não
   arredondamento. Há também A+W>N no kernel para N>=2. Os CSVs distinguem
   suporte probabilístico e físico.
4. O auditor de geração gravou as 32 tentativas sem redraw/clamp; todas foram
   válidas para a seed fixada. Isso **não** cobre o estado de contraprova nem
   estabelece gerador completo; G3-T1 não é done/pass. Tentativas que
   falhassem seriam mantidas com `status` e W ausente, não reamostradas.
5. Dez checagens de fonte cobriram prior parcial de `pi`, seis `dexp(5)`
   sobre variâncias, `1/v` como precisão, seis efeitos por observação, dois
   interceptos, quatro `Bin(N,mu)`, m=N->0.999 e `p.w` ponderado. Os probes
   usaram seis desenhos n x 1 de uns e `beta1=0` separado dos efeitos fixados;
   não selecionam geografia de produção. A sentinela assimétrica do wrapper
   real conferiu quatro chamadas e respectivos dados JAGS, inclusive controle
   negativo trocado, sem entrar na MCMC. Os funcionais M/S e limites foram
   calculados por draw e somados dentro de draw. A fixture Dobs=10 e o offset
   Dobs=1 da comparação são algébricos, não margens compatíveis com os votos
   observados. Flags marcam incompatibilidade e capacidade necessária; fonte
   dos votos subtraídos e factibilidade física completa não foram validadas.
6. Quatro cadeias de 2000 draws após 200 adaptação/500 burn foram comparadas
   à enumeração posterior exata do problema condicionado N=1,A=W=0. Todas as
   médias monitoradas passaram `max(1e-3,6*MCSE)` calculado por batch means.
   A comparação global ficou **inconclusiva**: `ess_tail` retornou NA para
   vários alvos discretos, e S foi degenerado no suporte posterior; não se
   atribuiu Rhat/ESS válido a esse alvo. Os critérios v2 não foram mudados.
7. O teste AR-02 reexecutado passou, com quatro rotas de wrapper e dados
   diretos/sentinela assimétrica; o reparo histórico não foi refeito aqui.

## Limites e próximo ponto de decisão

O primeiro teste determinístico falhou por nome herdado em R; o primeiro
JAGS foi interrompido por chamada incorreta ao método `update`; o segundo
amostrou mas falhou na extração de nomes escalares. Logs e produtos parciais
foram preservados em tentativas distintas. Nada indica convergência ou
validade nacional. É necessário decidir em G2 como tratar estados F1/F2 e o
alvo físico/probabilístico antes de certificar um gerador. Para a comparação
MC de discretos, um futuro protocolo revisado precisará predefinir tratamento
de quantis degenerados/`ess_tail=NA`, com revisão independente; esta rodada
não retuna nem substitui o diagnóstico falho.
