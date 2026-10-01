functions {
  vector ad_log_probabilities(vector eta, int class_id) {
    real log_t = log_inv_logit(eta[1]);
    real log_nt = log1m_inv_logit(eta[1]);
    real log_u = log_inv_logit(eta[2]);
    real log_nu = log1m_inv_logit(eta[2]);
    real log_m;
    real log_nm;
    real log_s;
    real log_ns;
    vector[3] out;
    if (class_id == 1) {
      log_m = negative_infinity();
      log_s = negative_infinity();
      log_nm = 0;
      log_ns = 0;
    } else if (class_id == 2) {
      log_m = log(0.7) + log_inv_logit(eta[3]);
      log_s = log(0.7) + log_inv_logit(eta[4]);
      log_nm = log_sum_exp(log(0.3), log(0.7) + log1m_inv_logit(eta[3]));
      log_ns = log_sum_exp(log(0.3), log(0.7) + log1m_inv_logit(eta[4]));
    } else if (class_id == 3) {
      log_m = log_sum_exp(log(0.7), log(0.3) + log_inv_logit(eta[5]));
      log_s = log_sum_exp(log(0.7), log(0.3) + log_inv_logit(eta[6]));
      log_nm = log(0.3) + log1m_inv_logit(eta[5]);
      log_ns = log(0.3) + log1m_inv_logit(eta[6]);
    } else {
      reject("class_id must be 1, 2 or 3");
    }
    out[1] = log_nt + log_nm;
    out[2] = log_sum_exp(log_sum_exp(log_t + log_u, log_nt + log_m),
                         log_t + log_nu + log_s);
    out[3] = log_t + log_nu + log_ns;
    return out;
  }

  real ad_count_log_lpmf(array[] int y, vector log_p) {
    real out = lgamma(sum(y) + 1.0);
    for (j in 1:3) {
      out -= lgamma(y[j] + 1.0);
      // Avoid 0 * negative_infinity at exact zero-probability cells.
      if (y[j] > 0) out += y[j] * log_p[j];
    }
    return out;
  }
}

data {
  int<lower=1> n;
  array[n] int<lower=1> N;
  array[n, 3] int<lower=0> observed;
}

transformed data {
  for (i in 1:n) {
    if (sum(observed[i]) != N[i]) reject("A+W+O must equal N at row ", i);
  }
}

parameters {
  vector[6] alpha;
  vector[6] b0;
  vector<lower=0>[6] v;
  matrix[n, 6] z;
  vector<lower=0, upper=1>[2] r;
}

transformed parameters {
  simplex[3] pi;
  matrix[n, 6] mu;
  pi[1] = 1 / (1 + r[1] + r[2]);
  pi[2] = r[1] * pi[1];
  pi[3] = r[2] * pi[1];
  for (i in 1:n) {
    vector[6] eta = alpha + b0 + sqrt(v) .* to_vector(z[i]);
    mu[i, 1] = inv_logit(eta[1]);
    mu[i, 2] = inv_logit(eta[2]);
    mu[i, 3] = 0.7 * inv_logit(eta[3]);
    mu[i, 4] = 0.7 * inv_logit(eta[4]);
    mu[i, 5] = 0.7 + 0.3 * inv_logit(eta[5]);
    mu[i, 6] = 0.7 + 0.3 * inv_logit(eta[6]);
  }
}

model {
  alpha ~ std_normal();
  b0 ~ normal(0, 0.01);
  v ~ exponential(5);
  to_vector(z) ~ std_normal();
  // r has uniform density one on (0,1)^2 after integrating aux1.
  for (i in 1:n) {
    vector[6] eta = alpha + b0 + sqrt(v) .* to_vector(z[i]);
    vector[3] terms;
    for (c in 1:3) {
      terms[c] = log(pi[c]) + ad_count_log_lpmf(observed[i] | ad_log_probabilities(eta, c));
    }
    target += log_sum_exp(terms);
  }
}

generated quantities {
  matrix[n, 3] responsibility;
  array[n] int<lower=1, upper=3> Z_rng;
  array[n] int<lower=1, upper=3> Z;
  vector[n] pA;
  vector[n] pW;
  vector[n] pO;
  matrix[n, 3] p_RB;
  matrix[n, 3] M_by_class;
  matrix[n, 3] S_by_class;
  vector[n] M_active;
  vector[n] S_active;
  vector[n] M_RB;
  vector[n] S_RB;
  vector[n] log_lik;
  real M_total;
  real S_total;
  real M_RB_total;
  real S_RB_total;
  for (i in 1:n) {
    vector[6] eta = alpha + b0 + sqrt(v) .* to_vector(z[i]);
    vector[3] terms;
    matrix[3, 3] p_class;
    vector[3] m = [0, mu[i, 3], mu[i, 5]]';
    vector[3] s = [0, mu[i, 4], mu[i, 6]]';
    for (c in 1:3) {
      vector[3] lp = ad_log_probabilities(eta, c);
      terms[c] = log(pi[c]) + ad_count_log_lpmf(observed[i] | lp);
      p_class[c] = exp(lp)';
      M_by_class[i, c] = N[i] * inv_logit(-eta[1]) * m[c];
      S_by_class[i, c] = N[i] * inv_logit(eta[1]) * inv_logit(-eta[2]) * s[c];
    }
    responsibility[i] = softmax(terms)';
    Z_rng[i] = categorical_rng(to_vector(responsibility[i]));
    Z[i] = Z_rng[i];
    pA[i] = p_class[Z_rng[i], 1];
    pW[i] = p_class[Z_rng[i], 2];
    pO[i] = p_class[Z_rng[i], 3];
    p_RB[i] = responsibility[i] * p_class;
    M_active[i] = M_by_class[i, Z_rng[i]];
    S_active[i] = S_by_class[i, Z_rng[i]];
    M_RB[i] = dot_product(responsibility[i], M_by_class[i]);
    S_RB[i] = dot_product(responsibility[i], S_by_class[i]);
    log_lik[i] = log_sum_exp(terms);
  }
  M_total = sum(M_active);
  S_total = sum(S_active);
  M_RB_total = sum(M_RB);
  S_RB_total = sum(S_RB);
}
