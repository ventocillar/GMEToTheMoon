# ==============================================================================
# 08_granger_causality.R
# VAR models, Granger causality tests, impulse response functions
# Tests bidirectional causality between sentiment and returns
# ==============================================================================

message("=== 08: Granger causality analysis ===")

# --- Prepare time series data -------------------------------------------------

# Use trading days with AFINN sentiment (dates from config)
granger_data <- master_trading %>%
  filter(date >= STUDY_START, date <= STUDY_END) %>%
  filter(!is.na(gme_return), !is.na(afinn_score)) %>%
  arrange(date) %>%
  select(date, gme_return, afinn_score, wsb_score, bing_net, n_comments)

message(sprintf("  Granger sample: %d trading days", nrow(granger_data)))

# --- ADF Stationarity Tests --------------------------------------------------

message("  Running ADF stationarity tests...")

adf_return <- adf.test(granger_data$gme_return, alternative = "stationary")
adf_afinn  <- adf.test(granger_data$afinn_score, alternative = "stationary")
adf_wsb    <- adf.test(granger_data$wsb_score, alternative = "stationary")

adf_results <- tibble(
  variable = c("GME Return", "AFINN Score", "WSB Score"),
  adf_statistic = c(adf_return$statistic, adf_afinn$statistic, adf_wsb$statistic),
  p_value = c(adf_return$p.value, adf_afinn$p.value, adf_wsb$p.value),
  stationary = c(adf_return$p.value < 0.05, adf_afinn$p.value < 0.05,
                 adf_wsb$p.value < 0.05)
)

message("  ADF results:")
print(adf_results)

# --- Optimal Lag Selection ----------------------------------------------------

max_lag <- cfg$regression$granger_max_lag

# AFINN-Return VAR
var_data_afinn <- granger_data %>% select(gme_return, afinn_score) %>% as.data.frame()
lag_select_afinn <- VARselect(var_data_afinn, lag.max = min(max_lag, nrow(var_data_afinn) / 3),
                              type = "const")

# WSB-Return VAR
var_data_wsb <- granger_data %>% select(gme_return, wsb_score) %>% as.data.frame()
lag_select_wsb <- VARselect(var_data_wsb, lag.max = min(max_lag, nrow(var_data_wsb) / 3),
                            type = "const")

optimal_lag_afinn <- lag_select_afinn$selection["AIC(n)"]
optimal_lag_wsb   <- lag_select_wsb$selection["AIC(n)"]

message(sprintf("  Optimal lags - AFINN: %d, WSB: %d", optimal_lag_afinn, optimal_lag_wsb))

# --- VAR Estimation -----------------------------------------------------------

var_afinn <- VAR(var_data_afinn, p = optimal_lag_afinn, type = "const")
var_wsb   <- VAR(var_data_wsb, p = optimal_lag_wsb, type = "const")

# --- Granger Causality Tests --------------------------------------------------

message("  Running Granger causality tests...")

# Does sentiment Granger-cause returns?
granger_sent_to_ret_afinn <- causality(var_afinn, cause = "afinn_score")
granger_sent_to_ret_wsb   <- causality(var_wsb, cause = "wsb_score")

# Do returns Granger-cause sentiment?
granger_ret_to_sent_afinn <- causality(var_afinn, cause = "gme_return")
granger_ret_to_sent_wsb   <- causality(var_wsb, cause = "gme_return")

granger_results <- tibble(
  direction = c(
    "AFINN -> Returns", "Returns -> AFINN",
    "WSB -> Returns", "Returns -> WSB"
  ),
  f_statistic = c(
    granger_sent_to_ret_afinn$Granger$statistic,
    granger_ret_to_sent_afinn$Granger$statistic,
    granger_sent_to_ret_wsb$Granger$statistic,
    granger_ret_to_sent_wsb$Granger$statistic
  ),
  p_value = c(
    granger_sent_to_ret_afinn$Granger$p.value,
    granger_ret_to_sent_afinn$Granger$p.value,
    granger_sent_to_ret_wsb$Granger$p.value,
    granger_ret_to_sent_wsb$Granger$p.value
  ),
  significant = c(
    granger_sent_to_ret_afinn$Granger$p.value < 0.05,
    granger_ret_to_sent_afinn$Granger$p.value < 0.05,
    granger_sent_to_ret_wsb$Granger$p.value < 0.05,
    granger_ret_to_sent_wsb$Granger$p.value < 0.05
  )
)

message("\n  Granger causality results:")
print(granger_results)

# Export
write_csv(granger_results, file.path(TAB_DIR, "granger_causality.csv"))

# --- Impulse Response Functions -----------------------------------------------

message("  Computing impulse response functions...")

irf_afinn <- irf(var_afinn, impulse = "afinn_score", response = "gme_return",
                 n.ahead = 10, boot = TRUE, runs = cfg$regression$bootstrap_reps,
                 ci = 0.95)

irf_wsb <- irf(var_wsb, impulse = "wsb_score", response = "gme_return",
               n.ahead = 10, boot = TRUE, runs = cfg$regression$bootstrap_reps,
               ci = 0.95)

# --- IRF Plot -----------------------------------------------------------------

# AFINN -> Returns IRF
irf_afinn_df <- tibble(
  horizon = 0:10,
  response = irf_afinn$irf$afinn_score[, 1],
  lower = irf_afinn$Lower$afinn_score[, 1],
  upper = irf_afinn$Upper$afinn_score[, 1]
)

p_irf_afinn <- irf_afinn_df %>%
  ggplot(aes(x = horizon, y = response)) +
  geom_ribbon(aes(ymin = lower, ymax = upper), fill = thesis_palette[1], alpha = 0.2) +
  geom_line(color = thesis_palette[1], linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  labs(title = "Impulse Response: AFINN Sentiment Shock -> GME Return",
       subtitle = "With 95% bootstrap confidence intervals",
       x = "Horizon (trading days)", y = "Response") +
  theme_thesis()

save_thesis_plot(p_irf_afinn, "irf_afinn_to_return.png")

# WSB -> Returns IRF
irf_wsb_df <- tibble(
  horizon = 0:10,
  response = irf_wsb$irf$wsb_score[, 1],
  lower = irf_wsb$Lower$wsb_score[, 1],
  upper = irf_wsb$Upper$wsb_score[, 1]
)

p_irf_wsb <- irf_wsb_df %>%
  ggplot(aes(x = horizon, y = response)) +
  geom_ribbon(aes(ymin = lower, ymax = upper), fill = thesis_palette[4], alpha = 0.2) +
  geom_line(color = thesis_palette[4], linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  labs(title = "Impulse Response: WSB Sentiment Shock -> GME Return",
       subtitle = "With 95% bootstrap confidence intervals",
       x = "Horizon (trading days)", y = "Response") +
  theme_thesis()

save_thesis_plot(p_irf_wsb, "irf_wsb_to_return.png")

# --- Store results ------------------------------------------------------------

granger_output <- list(
  adf_results = adf_results,
  granger_results = granger_results,
  var_afinn = var_afinn,
  var_wsb = var_wsb,
  irf_afinn = irf_afinn,
  irf_wsb = irf_wsb,
  optimal_lags = c(afinn = optimal_lag_afinn, wsb = optimal_lag_wsb)
)

message("Granger causality analysis complete.\n")
