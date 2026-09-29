# Adjudicação da preparação de replicação

O parecer independente de Boole foi conferido contra os arquivos exatos. Os
28 inputs da revisão continuam recuperáveis; três fontes mutáveis foram
preservadas antes de futuras alterações. A descoberta é utilizável como
preparação, mas não aprova G10 nem congela seu contrato de comparação.

- **AR-01 CONFIRMED, pendente:** o exemplo empírico D.C. 2010 tem dados e código
  dos autores, mas o material encontrado não contém resultados numéricos externos
  congelados. Localizá-los ou escolher outro caso antes da replicação quantitativa.
- **AR-02 CONFIRMED, reparo seguro:** quatro chamadas em dois scripts antigos
  trocam os observáveis da interface. O pacote usa formula1=w e formula2=a.
  Corrigir em G3 e testar, sem executar os runners nem sobrescrever fits.
  As listas diretas de fresh_v2 e zoneFE não têm essa inversão.
- **AR-03 CONFIRMED, errata:** na referência Bolívia 2019, os valores de Chain 1
  estão na página impressa 30, física 31 do PDF. O comando summary está na
  página impressa 29. Os números transcritos permanecem corretos.
- **AR-04 CONFIRMED, limite documentado:** integridade dos arquivos e metadados
  não prova, sozinha, a construção dos dados eleitorais originais. A QA não
  fez nova consulta remota; esse limite permanece explícito.

A coordenação releu a interface e os scripts, conferiu a página 31 física do PDF
Bolívia com pdftotext e executou a checagem de hashes. O registro JSON preserva
o teor de cada finding, a decisão e as fontes. O veredicto global BLOCKED impede
declarar a replicação concluída, não impede o reparo independente da interface
ou os testes pequenos de implementação já autorizados.
