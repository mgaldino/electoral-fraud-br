# Papers — Coordenação de Projetos de Pesquisa

## Propósito

Esta pasta contém todos os projetos de pesquisa (papers, tese, consultoria). Sessões abertas aqui servem para **coordenação cross-project**: triagem, priorização, tarefas rápidas em múltiplos projetos.

Para trabalho profundo em um projeto específico, abrir sessão dentro da pasta do projeto.

## Dashboard

O dashboard centralizado está em `/Users/manoelgaldino/Documents/DCP/DASHBOARD.md`. Use `/dashboard` para visualizar.

## Workflow de coordenação

1. `/dashboard` — ver estado de todos os projetos
2. `/dashboard refresh` — sincronizar dashboard com MEMORY.md de cada projeto
3. Priorizar: quais projetos têm bloqueios do autor? Quais têm urgência ALTA?
4. Para tarefas rápidas (git status, checar arquivos, verificar pendências), usar sub-agentes
5. Para trabalho profundo, abrir sessão dedicada na pasta do projeto

## Projetos ativos (subpastas)

Cada projeto tem seu próprio CLAUDE.md e MEMORY.md. Não duplicar instruções aqui.

## API Keys

- **PANGRAM_API_KEY**: configurada em `~/.zshrc`. Usada pelo skill `readability-audit` para detecção de IA via Pangram SDK. Para carregar numa sessão que ainda não leu o zshrc: `source ~/.zshrc`
- **REGRA PANGRAM — Autorização dupla**: NUNCA usar Pangram API sem autorização explícita do usuário. (1) Perguntar se quer rodar + custo estimado. (2) Se sim, pedir confirmação explícita. Se negar na primeira, NÃO perguntar de novo. NUNCA usar Pangram em papers de benchmark (PDFs de journals pré-2022) — apenas em papers novos do usuário.

## Regras

- **REGRA CRÍTICA — Pareceres completos**: Ao rodar QUALQUER skill de review (coarse-review, edmans-review, review-formal-model, review-paper, devils-advocate, proofread, game-theory-audit, etc.), o output COMPLETO do parecer DEVE ser salvo em `quality_reports/YYYY-MM-DD_nome-do-review.md` ANTES de resumir para o usuário. NUNCA truncar. NUNCA salvar apenas resumo. Pareceres que ficam só na memória da sessão são PERDIDOS.
- NÃO fazer edições profundas em código/texto de projetos a partir desta sessão — o contexto é insuficiente
- Usar esta sessão para: coordenação, triagem, priorização, tarefas administrativas (git, renomear, mover)
- Sub-agentes podem ler arquivos de projetos, mas edições substantivas devem ser feitas em sessões dedicadas
- **Paper é documento atemporal**: Ao sugerir texto para qualquer paper, escrever como se o leitor visse pela primeira vez. NUNCA referenciar versões anteriores, mudanças feitas durante revisão, ou estado prévio do manuscrito ("now", "previously", "we have removed", "in the revised version"). Descrever o resultado como se sempre tivesse sido assim.
