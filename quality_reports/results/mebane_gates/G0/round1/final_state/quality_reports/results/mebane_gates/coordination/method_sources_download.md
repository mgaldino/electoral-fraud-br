# Fontes metodológicas arquivadas

Consulta e download: 2026-09-28, America/Sao_Paulo (2026-09-29 UTC).
Responsável: coordenador, `019d795a-acfa-72c2-a210-d55a46c606c2`.

As tentativas anteriores em `websites.umich.edu` receberam 403/challenge ou
timeout. Uma busca pública localizou os mesmos documentos no endereço oficial
`public.websites.umich.edu`. Downloads HTTPS públicos por `curl -fL`, com
permissão de rede escalada, terminaram com exit code 0. Não foram usados
credenciais, serviços de terceiros ou arquivos incompletos como fontes.

| Documento e versão declarada na primeira página | Fonte primária | Arquivo local | Bytes | Páginas | SHA-256 |
|---|---|---|---:|---:|---|
| Mebane, Walter R., Jr.; Ferrari, Diogo; McAlister, Kevin; Wu, Patrick Y. (2022). *Measuring Election Frauds*. Manuscrito, 6 de março de 2022. | https://public.websites.umich.edu/~wmebane/measfrauds.pdf | `measfrauds_2022-03-06.pdf` | 524478 | 75 | `ad3b1cd473d48540877fb00cdffaaa09df1a21a98e4a2b4fa0a03c227ec50d76` |
| Mebane, Walter R., Jr. (2023). *Lost Votes and Posterior Multimodality in the eforensics Model*. Preparado para PolMeth 2023, Stanford University, Palo Alto, CA, 9 a 11 de julho. Versão original de 29 de junho; versão consultada de 2 de julho de 2023. | https://public.websites.umich.edu/~wmebane/pm23.pdf | `pm23_2023-07-02.pdf` | 5123025 | 105 | `615ddab21034e22ca55d891e01f14b85a2e7d80e12238bfbfb142ff214531431` |

Arquivos nesta mesma pasta. `pdfinfo` terminou com exit code 0 nos dois PDFs,
sem criptografia; `pdftotext -f 1 -l 1 ARQUIVO -` permitiu conferir autoria,
título e versão. `shasum -a 256` produziu os hashes acima. Não foi realizada
nesta etapa uma leitura substantiva integral ou validação das equações; isso
pertence ao G2. Os arquivos originais do usuário foram preservados.

Comandos executados, sem sobrescrever fontes anteriores:

```sh
curl -fL --max-time 45 https://public.websites.umich.edu/~wmebane/pm23.pdf -o quality_reports/results/mebane_gates/coordination/pm23_2023-07-02.pdf
curl -fL --max-time 60 https://public.websites.umich.edu/~wmebane/measfrauds.pdf -o quality_reports/results/mebane_gates/coordination/measfrauds_2022-03-06.pdf
pdfinfo quality_reports/results/mebane_gates/coordination/pm23_2023-07-02.pdf
pdfinfo quality_reports/results/mebane_gates/coordination/measfrauds_2022-03-06.pdf
pdftotext -f 1 -l 1 quality_reports/results/mebane_gates/coordination/pm23_2023-07-02.pdf -
pdftotext -f 1 -l 1 quality_reports/results/mebane_gates/coordination/measfrauds_2022-03-06.pdf -
shasum -a 256 quality_reports/results/mebane_gates/coordination/pm23_2023-07-02.pdf quality_reports/results/mebane_gates/coordination/measfrauds_2022-03-06.pdf
```
