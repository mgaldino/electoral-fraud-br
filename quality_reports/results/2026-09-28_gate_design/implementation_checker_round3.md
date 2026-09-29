# Reparo delimitado C-F009

Implementador: coordenador `019d795a-acfa-72c2-a210-d55a46c606c2`.
Rechecagem: QA-LEDGER-SOL, agente distinto. O contrato científico, ledger,
prompts e Markdown aprovados não foram alterados.

O schema mecânico de `run.json` acrescenta `dependency_approvals`, complementar
a `dependency_manifests`. Para cada ID de `depends_on`, registra:

```json
{
  "dependency_approvals": {
    "G0": {
      "review_sha256": "SHA-256 do review aprovado de G0",
      "adjudication_sha256": "SHA-256 da adjudicação aprovada de G0"
    }
  }
}
```

As chaves devem coincidir exatamente com as dependências; G0 usa objeto vazio.
Cada aprovação contém exatamente os dois campos acima. Hashes devem coincidir
com os arquivos identificados nos `records` vigentes dos predecessores.
O run continua dentro do manifesto do filho, portanto a assinatura do parecer
do filho abrange os vínculos. Manifesto do pai sozinho não identifica seu
parecer, pois este é produzido posteriormente.

As novas regressões trocam apenas o revisor/review do pai ou somente sua
adjudicação, mantendo o pai estruturalmente válido e seus inputs/código/manifesto
intactos. Em ambos os casos o filho deve ser rejeitado. Também se verificam
objetos ausentes, de tipo errado ou com chaves incompletas.

Essa extensão concretiza a exigência já presente nos prompts de vincular a
aprovação exata e reabrir dependentes. Não altera estimando, critérios científicos
ou estados pendentes dos gates. Não houve MCMC ou instalação.
