// Legacy baseline only.
// As of 2026-04-11, the canonical JAGS target in UMeforensics is qbl(), not bl().
// This Stan file is retained for historical comparison against the simplified bl().

functions {
  real safe_binomial_logp(int y, int n, real p) {
    if (is_nan(p) || is_inf(p) || p <= 0 || p >= 1) {
      return negative_infinity();
    }
    return binomial_lpmf(y | n, p);
  }

  real p_w_incremental(real a_over_n, real nu, real iota_m, real iota_s) {
    real denom = 1 - iota_m;
    return nu * ((1 - iota_s) / denom) * (1 - iota_m - a_over_n)
         + a_over_n * ((iota_m - iota_s) / denom)
         + iota_s;
  }

  real p_w_extreme(real a_over_n, real nu, real chi_m, real chi_s) {
    real denom = 1 - chi_m;
    return nu * ((1 - chi_s) / denom) * (1 - chi_m - a_over_n)
         + a_over_n * ((chi_m - chi_s) / denom)
         + chi_s;
  }
}

data {
  // Election-unit counts for the Brasilia section-level calibration dataset.
  int<lower=1> n_obs;
  array[n_obs] int<lower=1> N;
  array[n_obs] int<lower=0> a;
  array[n_obs] int<lower=0> w;
  real<lower=0, upper=1> k;
}

parameters {
  // Legacy JAGS target: flat Dirichlet on the mixture weights.
  simplex[3] pi;

  // Intercept-only linear predictors on the legacy JAGS scale.
  real beta_tau;
  real beta_nu;
  real beta_iota_m;
  real beta_iota_s;
  real beta_chi_m;
  real beta_chi_s;
}

transformed parameters {
  // Legacy "bl" operational approximation: global rates, no hierarchical kappa_i.
  real<lower=0, upper=1> tau = inv_logit(beta_tau);
  real<lower=0, upper=1> nu = inv_logit(beta_nu);
  real<lower=0, upper=k> iota_m = k * inv_logit(beta_iota_m);
  real<lower=0, upper=k> iota_s = k * inv_logit(beta_iota_s);
  real<lower=k, upper=1> chi_m = k + (1 - k) * inv_logit(beta_chi_m);
  real<lower=k, upper=1> chi_s = k + (1 - k) * inv_logit(beta_chi_s);
}

model {
  // Legacy DiogoFerrari/eforensics prior: beta ~ Normal(0, 10), pi ~ Dirichlet(1,1,1).
  vector[3] alpha_pi = rep_vector(1, 3);
  pi ~ dirichlet(alpha_pi);

  beta_tau ~ normal(0, 10);
  beta_nu ~ normal(0, 10);
  beta_iota_m ~ normal(0, 10);
  beta_iota_s ~ normal(0, 10);
  beta_chi_m ~ normal(0, 10);
  beta_chi_s ~ normal(0, 10);

  // Stan approximation to the legacy JAGS "bl" likelihood:
  // we marginalize Z_i and use global fraud magnitudes directly rather than
  // observation-specific latent binomial draws for N.iota.* and N.chi.*.
  for (i in 1:n_obs) {
    real a_over_n = a[i] / (1.0 * N[i]);
    real p_a_1 = 1 - tau;
    real p_a_2 = (1 - tau) * (1 - iota_m);
    real p_a_3 = (1 - tau) * (1 - chi_m);
    real p_w_1 = nu * (1 - a_over_n);
    real p_w_2 = p_w_incremental(a_over_n, nu, iota_m, iota_s);
    real p_w_3 = p_w_extreme(a_over_n, nu, chi_m, chi_s);
    vector[3] lp;

    lp[1] = log(pi[1])
          + safe_binomial_logp(a[i], N[i], p_a_1)
          + safe_binomial_logp(w[i], N[i], p_w_1);
    lp[2] = log(pi[2])
          + safe_binomial_logp(a[i], N[i], p_a_2)
          + safe_binomial_logp(w[i], N[i], p_w_2);
    lp[3] = log(pi[3])
          + safe_binomial_logp(a[i], N[i], p_a_3)
          + safe_binomial_logp(w[i], N[i], p_w_3);

    target += log_sum_exp(lp);
  }
}

generated quantities {
  // User-facing summaries to align with Mebane-style reporting.
  real pi_1 = pi[1];
  real pi_2 = pi[2];
  real pi_3 = pi[3];
  real Ft = 0;
  real Fw = 0;
  real stolen_votes = 0;
  real fraudulent_units_incremental = 0;
  real fraudulent_units_extreme = 0;

  for (i in 1:n_obs) {
    real a_over_n = a[i] / (1.0 * N[i]);
    real p_a_1 = 1 - tau;
    real p_a_2 = (1 - tau) * (1 - iota_m);
    real p_a_3 = (1 - tau) * (1 - chi_m);
    real p_w_1 = nu * (1 - a_over_n);
    real p_w_2 = p_w_incremental(a_over_n, nu, iota_m, iota_s);
    real p_w_3 = p_w_extreme(a_over_n, nu, chi_m, chi_s);
    vector[3] lp;
    real log_norm;
    real r2;
    real r3;
    real manufactured_inc = N[i] * iota_m * (1 - tau);
    real manufactured_ext = N[i] * chi_m * (1 - tau);
    real total_inc = N[i] * (iota_m * (1 - tau) + iota_s * tau * (1 - nu));
    real total_ext = N[i] * (chi_m * (1 - tau) + chi_s * tau * (1 - nu));

    lp[1] = log(pi[1])
          + safe_binomial_logp(a[i], N[i], p_a_1)
          + safe_binomial_logp(w[i], N[i], p_w_1);
    lp[2] = log(pi[2])
          + safe_binomial_logp(a[i], N[i], p_a_2)
          + safe_binomial_logp(w[i], N[i], p_w_2);
    lp[3] = log(pi[3])
          + safe_binomial_logp(a[i], N[i], p_a_3)
          + safe_binomial_logp(w[i], N[i], p_w_3);

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
