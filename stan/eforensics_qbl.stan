// Stan approximation to the canonical UMeforensics qbl() model.
//
// This implementation preserves:
//   - ordered mixture prior on pi
//   - six hierarchical random-effect blocks
//   - k = 0.7 parameterization
//   - latent class marginalization over Z_i
//
// It does not reproduce the JAGS latent binomial count nodes exactly.
// Instead, the fraud magnitudes are treated as continuous probabilities on the
// logistic scale. This keeps the hierarchical structure while avoiding an
// intractable discrete-count marginalization in Stan.
//
// Supports both intercept-only (p_* = 0) and covariate models (p_* > 0).
// When p_* = 0, the design matrix X_* is n_obs x 0 and beta_* is length 0,
// so X_* * beta_* evaluates to a zero vector -- identical to the original
// intercept-only behavior.
//
// Nuisance direction from the JAGS implementation collapsed here:
//   pi.aux1 cancels after normalization, so Stan works directly with the
//   induced ordered-ratio prior on (pi[1], pi[2], pi[3]).
// The alpha parameters absorb the hierarchical mean. When covariates are
// present, beta_* captures the fixed effects (design matrix WITHOUT intercept
// column) and alpha remains the random-effect mean.

functions {
  real clamp_prob(real p) {
    return fmin(1 - 1e-9, fmax(1e-9, p));
  }

  real p_w_incremental(real a_over_n, real nu, real iota_m, real iota_s) {
    real denom = fmax(1e-9, 1 - iota_m);
    real p = nu * ((1 - iota_s) / denom) * (1 - iota_m - a_over_n)
           + a_over_n * ((iota_m - iota_s) / denom)
           + iota_s;
    return clamp_prob(p);
  }

  real p_w_extreme(real a_over_n, real nu, real chi_m, real chi_s) {
    real denom = fmax(1e-9, 1 - chi_m);
    real p = nu * ((1 - chi_s) / denom) * (1 - chi_m - a_over_n)
           + a_over_n * ((chi_m - chi_s) / denom)
           + chi_s;
    return clamp_prob(p);
  }
}

data {
  int<lower=1> n_obs;
  array[n_obs] int<lower=1> N;
  array[n_obs] int<lower=0> a;
  array[n_obs] int<lower=0> w;
  real<lower=0, upper=1> k;

  // Covariate dimensions (0 = intercept-only for that predictor).
  // Design matrices should NOT include an intercept column; the intercept
  // is absorbed into the corresponding alpha parameter.
  int<lower=0> p_tau;
  int<lower=0> p_nu;
  int<lower=0> p_iota_m;
  int<lower=0> p_iota_s;
  int<lower=0> p_chi_m;
  int<lower=0> p_chi_s;

  matrix[n_obs, p_tau] X_tau;
  matrix[n_obs, p_nu] X_nu;
  matrix[n_obs, p_iota_m] X_iota_m;
  matrix[n_obs, p_iota_s] X_iota_s;
  matrix[n_obs, p_chi_m] X_chi_m;
  matrix[n_obs, p_chi_s] X_chi_s;
}

parameters {
  // After marginalizing out pi_aux1, qbl() implies pi ∝ (1, u2, u3) with
  // u2, u3 ~ Uniform(0, 1). This preserves the ordered prior while removing
  // the flat auxiliary scale direction.
  real<lower=0, upper=1> pi_aux2_raw;
  real<lower=0, upper=1> pi_aux3_raw;

  // Hierarchical means for the random intercepts. When covariates are present,
  // beta_* captures fixed effects separately; alpha remains the random-effect
  // mean (not collapsed with the fixed intercept).
  real tau_alpha;
  real nu_alpha;
  real iota_m_alpha;
  real iota_s_alpha;
  real chi_m_alpha;
  real chi_s_alpha;

  // qbl() uses Exp(5) hyperparameters and then feeds their inverses into the
  // JAGS normal precision. This means these variables operate as variances.
  real<lower=0> tb;
  real<lower=0> nb;
  real<lower=0> imb;
  real<lower=0> isb;
  real<lower=0> cmb;
  real<lower=0> csb;

  // Non-centered hierarchical effects for each observation.
  vector[n_obs] z_th;
  vector[n_obs] z_nh;
  vector[n_obs] z_imh;
  vector[n_obs] z_ish;
  vector[n_obs] z_cmh;
  vector[n_obs] z_csh;

  // Fixed-effect coefficients (zero-length when p_* = 0).
  vector[p_tau] beta_tau;
  vector[p_nu] beta_nu;
  vector[p_iota_m] beta_iota_m;
  vector[p_iota_s] beta_iota_s;
  vector[p_chi_m] beta_chi_m;
  vector[p_chi_s] beta_chi_s;
}

transformed parameters {
  vector[3] pi_raw;
  simplex[3] pi;

  vector[n_obs] eta_tau = tau_alpha + X_tau * beta_tau + sqrt(tb) * z_th;
  vector[n_obs] eta_nu = nu_alpha + X_nu * beta_nu + sqrt(nb) * z_nh;
  vector[n_obs] eta_iota_m = iota_m_alpha + X_iota_m * beta_iota_m + sqrt(imb) * z_imh;
  vector[n_obs] eta_iota_s = iota_s_alpha + X_iota_s * beta_iota_s + sqrt(isb) * z_ish;
  vector[n_obs] eta_chi_m = chi_m_alpha + X_chi_m * beta_chi_m + sqrt(cmb) * z_cmh;
  vector[n_obs] eta_chi_s = chi_s_alpha + X_chi_s * beta_chi_s + sqrt(csb) * z_csh;

  vector[n_obs] tau_prob;
  vector[n_obs] nu_prob;
  vector[n_obs] iota_m;
  vector[n_obs] iota_s;
  vector[n_obs] chi_m;
  vector[n_obs] chi_s;

  pi_raw[1] = 1;
  pi_raw[2] = pi_aux2_raw;
  pi_raw[3] = pi_aux3_raw;
  pi = pi_raw / sum(pi_raw);

  tau_prob = inv_logit(eta_tau);
  nu_prob = inv_logit(eta_nu);
  iota_m = k * inv_logit(eta_iota_m);
  iota_s = k * inv_logit(eta_iota_s);
  chi_m = k + (1 - k) * inv_logit(eta_chi_m);
  chi_s = k + (1 - k) * inv_logit(eta_chi_s);
}

model {
  // Canonical qbl() ordered prior, with the redundant global scale removed.
  pi_aux2_raw ~ uniform(0, 1);
  pi_aux3_raw ~ uniform(0, 1);

  // Hierarchical means for the random intercepts.
  // With covariates, alpha is the random-effect mean (matching JAGS alpha ~ N(0,1))
  // and beta captures the fixed effects separately.
  tau_alpha ~ normal(0, 1);
  nu_alpha ~ normal(0, 1);
  iota_m_alpha ~ normal(0, 1);
  iota_s_alpha ~ normal(0, 1);
  chi_m_alpha ~ normal(0, 1);
  chi_s_alpha ~ normal(0, 1);

  // Fixed-effect priors: N(0,1) matching JAGS variance=1 for non-intercept cols.
  // When p_* = 0 these are zero-length vectors and these statements are no-ops.
  beta_tau ~ normal(0, 1);
  beta_nu ~ normal(0, 1);
  beta_iota_m ~ normal(0, 1);
  beta_iota_s ~ normal(0, 1);
  beta_chi_m ~ normal(0, 1);
  beta_chi_s ~ normal(0, 1);

  tb ~ exponential(5);
  nb ~ exponential(5);
  imb ~ exponential(5);
  isb ~ exponential(5);
  cmb ~ exponential(5);
  csb ~ exponential(5);

  z_th ~ std_normal();
  z_nh ~ std_normal();
  z_imh ~ std_normal();
  z_ish ~ std_normal();
  z_cmh ~ std_normal();
  z_csh ~ std_normal();

  // Mixture likelihood with Z_i marginalized out.
  for (i in 1:n_obs) {
    real a_over_n = a[i] / (1.0 * N[i]);
    real p_a_1 = clamp_prob(1 - tau_prob[i]);
    real p_a_2 = clamp_prob((1 - tau_prob[i]) * (1 - iota_m[i]));
    real p_a_3 = clamp_prob((1 - tau_prob[i]) * (1 - chi_m[i]));
    real p_w_1 = clamp_prob(nu_prob[i] * (1 - a_over_n));
    real p_w_2 = p_w_incremental(a_over_n, nu_prob[i], iota_m[i], iota_s[i]);
    real p_w_3 = p_w_extreme(a_over_n, nu_prob[i], chi_m[i], chi_s[i]);
    vector[3] lp;

    lp[1] = log(pi[1])
          + binomial_lpmf(a[i] | N[i], p_a_1)
          + binomial_lpmf(w[i] | N[i], p_w_1);
    lp[2] = log(pi[2])
          + binomial_lpmf(a[i] | N[i], p_a_2)
          + binomial_lpmf(w[i] | N[i], p_w_2);
    lp[3] = log(pi[3])
          + binomial_lpmf(a[i] | N[i], p_a_3)
          + binomial_lpmf(w[i] | N[i], p_w_3);

    target += log_sum_exp(lp);
  }
}

generated quantities {
  real pi_1 = pi[1];
  real pi_2 = pi[2];
  real pi_3 = pi[3];

  real sigma_tau = sqrt(tb);
  real sigma_nu = sqrt(nb);
  real sigma_iota_m = sqrt(imb);
  real sigma_iota_s = sqrt(isb);
  real sigma_chi_m = sqrt(cmb);
  real sigma_chi_s = sqrt(csb);

  real Ft = 0;
  real Fw = 0;
  real stolen_votes = 0;
  real fraudulent_units_incremental = 0;
  real fraudulent_units_extreme = 0;

  for (i in 1:n_obs) {
    real a_over_n = a[i] / (1.0 * N[i]);
    real p_a_1 = clamp_prob(1 - tau_prob[i]);
    real p_a_2 = clamp_prob((1 - tau_prob[i]) * (1 - iota_m[i]));
    real p_a_3 = clamp_prob((1 - tau_prob[i]) * (1 - chi_m[i]));
    real p_w_1 = clamp_prob(nu_prob[i] * (1 - a_over_n));
    real p_w_2 = p_w_incremental(a_over_n, nu_prob[i], iota_m[i], iota_s[i]);
    real p_w_3 = p_w_extreme(a_over_n, nu_prob[i], chi_m[i], chi_s[i]);
    vector[3] lp;
    real log_norm;
    real r2;
    real r3;
    real manufactured_inc = N[i] * iota_m[i] * (1 - tau_prob[i]);
    real manufactured_ext = N[i] * chi_m[i] * (1 - tau_prob[i]);
    real total_inc = N[i] * (iota_m[i] * (1 - tau_prob[i]) + iota_s[i] * tau_prob[i] * (1 - nu_prob[i]));
    real total_ext = N[i] * (chi_m[i] * (1 - tau_prob[i]) + chi_s[i] * tau_prob[i] * (1 - nu_prob[i]));

    lp[1] = log(pi[1])
          + binomial_lpmf(a[i] | N[i], p_a_1)
          + binomial_lpmf(w[i] | N[i], p_w_1);
    lp[2] = log(pi[2])
          + binomial_lpmf(a[i] | N[i], p_a_2)
          + binomial_lpmf(w[i] | N[i], p_w_2);
    lp[3] = log(pi[3])
          + binomial_lpmf(a[i] | N[i], p_a_3)
          + binomial_lpmf(w[i] | N[i], p_w_3);

    log_norm = log_sum_exp(lp);
    r2 = exp(lp[2] - log_norm);
    r3 = exp(lp[3] - log_norm);

    fraudulent_units_incremental += r2;
    fraudulent_units_extreme += r3;
    Ft += r2 * manufactured_inc + r3 * manufactured_ext;
    Fw += r2 * total_inc + r3 * total_ext;
  }

  stolen_votes = Fw - Ft;
}
