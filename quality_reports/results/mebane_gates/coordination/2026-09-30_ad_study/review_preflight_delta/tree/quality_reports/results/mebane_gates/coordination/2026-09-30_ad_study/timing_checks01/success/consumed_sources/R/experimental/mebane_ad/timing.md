# Timing definitions fixed before empirical fitting

The unchanged AD-DC2010-v2 design permits one generation attempt per model,
with an external 1200-second timeout. Diagnostics are separate subprocesses,
each with its own 1200-second safety timeout; they never extend or repeat MCMC.

- `phases.setup.elapsed`: input reads, validation, JAGS package loading,
  snapshots, preparation and persistence of actual inputs/inits/metadata.
- `compile`, `adapt`, `burn`, `sample`: disjoint engine calls; each also records
  a failed partial phase on ordinary R errors. A killed process may lack its
  last completed phase; the external supervisor remains authoritative.
- `persist_raw`: writing raw draws and final JAGS state, not sampling time.
- `run_result.elapsed_seconds`: internal generation from function entry until
  raw persistence or error handling. It excludes R startup, initial source
  loading and the final result/manifest writes. This is not a total-process time.
- Diagnostic columns `ess_*_per_internal_generation_second` use that explicitly
  partial generation denominator. Sample-only ESS/s remains separately named.
- Supervisor `elapsed_seconds`: monotonic wall time for the whole generation
  subprocess, including startup and its final writes (and termination handling).
- The postprocessing supervisor analogously measures the diagnostics subprocess.
  End-to-end compute per model is their sum, without overlapping phases or double
  counting. It excludes time queued behind the other model, reporting and the
  parent supervisor's own bookkeeping. Final comparison adds ESS per external
  generation second and per end-to-end compute second with these definitions.

The clocks describe actual costs. Diagnostic failure prevents interpreting ESS/s
as a validated efficiency ranking. No model, seed, iteration or threshold changes.
