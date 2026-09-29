# AR-02 interface repair: candidate for independent QA

This is a new, bounded pre-G3 candidate. The archived UMeforensics source at
commit `3017de537450f97a01872d0157462a68bea348ee` maps `formula1` to
winner votes (`w`, `Xw`) and `formula2` to abstentions (`a`, `Xa`) at
`ef_main_3017de5.R:667-675`. The fixed G2 benchmark contract has SHA-256
`63b61fb0594d0302a03d999bcff6c62967b6e999f37b4c9a8821f0f8e9ed18d2`.

Before editing, both runner files matched by SHA-256 both the
`replication_review_inputs/R/` copies and `G0/round1/final_state/R/` copies.
The two source changes are only the four formula pairs: in R/05, the synthetic
call is now `formula1 = w ~ x1.w`, `formula2 = a ~ x1.a`, and its two
intercept-only calls are `w ~ 1`, `a ~ 1`; the R/07 call is also `w ~ 1`,
`a ~ 1`. No constants, MCMC settings, latent formulas, fit files, or direct-list
JAGS scripts were changed. `git diff --numstat` reported 6/6 lines in R/05
and 2/2 lines in R/07; `git diff --check` exited 0.

## New interface check

From the repository root:

```sh
Rscript tests/mebane/likelihood/test_ar02_interface.R
git diff --check -- R/05_eforensics_umeforensics_qbl.R R/07_brasil_full_qbl.R
shasum -a 256 R/05_eforensics_umeforensics_qbl.R R/07_brasil_full_qbl.R tests/mebane/likelihood/test_ar02_interface.R
```

The first command exited 0 in a new disposable R process on 2026-09-29.
Its recorded output is summarized in `run.json`, with `run_kind` explicitly
marked `NEW_DISPOSABLE_R_PROCESS`. The test parses the four call expressions
from the actual scripts, checks their formulas by AST, then evaluates those
expressions through the installed package wrapper on asymmetric sentinel
counts `N=(10,12)`, `a=(2,5)`, `w=(7,3)` and distinct covariates. Captured
responses and all six design matrices match a manually built direct list.
Four deliberately swapped formula pairs serve as negative controls.

The package's original `order.formulas` has a formula-object versus string
handling defect. The test applies each runner's existing workaround only in
memory, and also bypasses `ef_check_jags` in memory. Before each wrapper call,
`runjags::run.jags` is replaced by a capture-and-abort stub and
`rjags::jags.model` by a blocking guard; all original namespace functions are
restored and checked after the test. Eight stub captures occurred (four
repaired and four negative controls), with zero compiler entries. The wrapper
was exercised only through data construction; it was **not** completed past
the sampling boundary. Its printed `MCMC in progress` message precedes that
boundary and does not mean MCMC ran.

The standalone test first encountered missing packages because the sandbox
skips `renv` activation. It now locates the already installed project library
without installation or editing `renv`. Interim fixture/attribute assertions
were corrected; the final direct command above passed. Startup locale warnings
remain nonfatal. Versions: R 4.4.2, eforensics 0.0.4, runjags 2.2.2.5,
rjags 4.17.

## Method boundary

This test validates the formula-to-data interface only. It does not validate
likelihood numerics, posterior sampling, convergence, or a full historical or
national runner. Prior fits are untouched and must not be called re-estimates.
R/05_eforensics_qbl_fresh_diagnostic.R and R/05_jags_qbl_zone_fe.R use direct
lists and are not implicated by this wrapper reversal. No source or fit under
R/lib, Stan, G2, ledger, or the national loader was changed. The concurrent
removal of the incomplete `.download` file was neither recovered nor deleted
by this work; global replication and G2 QA remain separate. This candidate
is ready for independent QA, not a G3 PASS, and reuse in G3 needs explicit
coordinator release.
