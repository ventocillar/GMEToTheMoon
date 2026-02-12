# ==============================================================================
# 11_export_dashboard.R
# Export pipeline results as JSON for the SvelteKit dashboard
# Run AFTER the full pipeline (run_all.R) so all objects are in memory
# ==============================================================================

message("=== 11: Exporting dashboard data ===")

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  install.packages("jsonlite", repos = "https://cloud.r-project.org")
}
library(jsonlite)

DASH_DIR <- here("thesis-dashboard", "static", "data")
dir.create(DASH_DIR, recursive = TRUE, showWarnings = FALSE)

export_json <- function(data, filename) {
  path <- file.path(DASH_DIR, filename)
  write_json(data, path, pretty = TRUE, auto_unbox = TRUE, na = "null")
  message("  Exported: ", filename, " (", file.size(path), " bytes)")
}

# --- 1. Timeline (daily time series) -----------------------------------------

timeline <- master_trading %>%
  select(date, gme_return, gme_close, gme_volume, gme_abnormal_volume,
         afinn_score, wsb_score, nrc_net, bing_net, emoji_score,
         n_comments, n_authors) %>%
  mutate(date = as.character(date))

export_json(timeline, "timeline.json")

# --- 2. Summary statistics ---------------------------------------------------

summary_stats <- read_csv(file.path(TAB_DIR, "summary_statistics.csv"),
                          show_col_types = FALSE)
export_json(summary_stats, "summary_stats.json")

# --- 3. Granger causality ----------------------------------------------------

granger <- read_csv(file.path(TAB_DIR, "granger_causality.csv"),
                    show_col_types = FALSE)
export_json(granger, "granger.json")

# --- 4. Regression coefficients -----------------------------------------------

extract_coefs <- function(model, model_name, hac_result = NULL) {
  if (is.null(hac_result)) {
    hac_result <- compute_hac_results(model)
  }
  tibble(
    variable = rownames(hac_result),
    estimate = hac_result[, "Estimate"],
    std_error = hac_result[, "Std. Error"],
    t_stat = hac_result[, "t value"],
    p_value = hac_result[, "Pr(>|t|)"],
    ci_lower = hac_result[, "Estimate"] - 1.96 * hac_result[, "Std. Error"],
    ci_upper = hac_result[, "Estimate"] + 1.96 * hac_result[, "Std. Error"],
    model = model_name
  )
}

reg_coefs <- bind_rows(
  extract_coefs(regression_results$m1_afinn, "AFINN Contemporaneous"),
  extract_coefs(regression_results$m2_afinn, "AFINN Lagged",
                regression_results$hac_m2_afinn),
  extract_coefs(regression_results$m3_afinn, "AFINN Full",
                regression_results$hac_m3_afinn),
  extract_coefs(regression_results$m2_wsb, "WSB Lagged",
                regression_results$hac_m2_wsb),
  extract_coefs(regression_results$m3_wsb, "WSB Full",
                regression_results$hac_m3_wsb),
  extract_coefs(regression_results$m4_text, "Text Only"),
  extract_coefs(regression_results$m4_emoji, "Emoji Only"),
  extract_coefs(regression_results$m4_combined, "Combined")
)

# Add emoji F-test info
emoji_f <- list(
  f_statistic = regression_results$emoji_f_test$F[2],
  p_value = regression_results$emoji_f_test$`Pr(>F)`[2],
  df1 = regression_results$emoji_f_test$Df[2],
  df2 = regression_results$emoji_f_test$Res.Df[2]
)

export_json(list(coefficients = reg_coefs, emoji_f_test = emoji_f),
            "regression_coefs.json")

# --- 5. DiD results (event study coefficients) --------------------------------

es_coefs <- broom::tidy(did_output$event_study, conf.int = TRUE) %>%
  filter(grepl("rel_period", term)) %>%
  mutate(
    period = as.numeric(str_extract(term, "-?\\d+")),
    pre_treatment = period < 0
  ) %>%
  select(period, estimate, std.error, conf.low, conf.high, p.value, pre_treatment)

# DiD main coefficients
did_coefs <- tibble(
  model = c("Basic", "Stock FE", "Two-way FE"),
  coefficient = c(
    coef(did_output$did_m1)["treated:post"],
    coef(did_output$did_m2)["treat_x_post"],
    coef(did_output$did_m3)["treat_x_post"]
  ),
  p_value = c(
    summary(did_output$did_m1)$coeftable[nrow(summary(did_output$did_m1)$coeftable), "Pr(>|t|)"],
    summary(did_output$did_m2)$coeftable["treat_x_post", "Pr(>|t|)"],
    summary(did_output$did_m3)$coeftable["treat_x_post", "Pr(>|t|)"]
  )
)

# Cumulative returns
car_data <- stock_prices %>%
  filter(date >= as.Date(cfg$stock_period$start),
         date <= as.Date(cfg$stock_period$end)) %>%
  mutate(group = ifelse(symbol %in% MEME_STOCKS, "Meme Stocks", "Control Stocks")) %>%
  group_by(group, date) %>%
  summarize(mean_return = mean(daily_return, na.rm = TRUE), .groups = "drop") %>%
  group_by(group) %>%
  arrange(date) %>%
  mutate(cumulative_return = cumsum(replace_na(mean_return, 0)),
         date = as.character(date)) %>%
  ungroup()

export_json(list(event_study = es_coefs, did_coefs = did_coefs,
                 cumulative_returns = car_data), "did_results.json")

# --- 6. IRF (Impulse Response Functions) --------------------------------------

irf_afinn_df <- tibble(
  horizon = 0:10,
  response = granger_output$irf_afinn$irf$afinn_score[, 1],
  lower = granger_output$irf_afinn$Lower$afinn_score[, 1],
  upper = granger_output$irf_afinn$Upper$afinn_score[, 1],
  impulse = "AFINN Sentiment",
  response_var = "GME Return"
)

irf_wsb_df <- tibble(
  horizon = 0:10,
  response = granger_output$irf_wsb$irf$wsb_score[, 1],
  lower = granger_output$irf_wsb$Lower$wsb_score[, 1],
  upper = granger_output$irf_wsb$Upper$wsb_score[, 1],
  impulse = "WSB Sentiment",
  response_var = "GME Return"
)

# Also compute return -> sentiment IRFs
irf_ret_afinn <- irf(granger_output$var_afinn, impulse = "gme_return",
                     response = "afinn_score", n.ahead = 10, boot = TRUE,
                     runs = 500, ci = 0.95)
irf_ret_wsb <- irf(granger_output$var_wsb, impulse = "gme_return",
                   response = "wsb_score", n.ahead = 10, boot = TRUE,
                   runs = 500, ci = 0.95)

irf_ret_afinn_df <- tibble(
  horizon = 0:10,
  response = irf_ret_afinn$irf$gme_return[, 1],
  lower = irf_ret_afinn$Lower$gme_return[, 1],
  upper = irf_ret_afinn$Upper$gme_return[, 1],
  impulse = "GME Return",
  response_var = "AFINN Sentiment"
)

irf_ret_wsb_df <- tibble(
  horizon = 0:10,
  response = irf_ret_wsb$irf$gme_return[, 1],
  lower = irf_ret_wsb$Lower$gme_return[, 1],
  upper = irf_ret_wsb$Upper$gme_return[, 1],
  impulse = "GME Return",
  response_var = "WSB Sentiment"
)

export_json(bind_rows(irf_afinn_df, irf_wsb_df, irf_ret_afinn_df, irf_ret_wsb_df),
            "irf.json")

# --- 7. Emotions (NRC daily time series) --------------------------------------

emotions <- all_sentiment %>%
  filter(lexicon == "nrc", weight_type == "unweighted",
         !emotion %in% c("positive", "negative")) %>%
  select(date, emotion, normalized) %>%
  mutate(date = as.character(date))

export_json(emotions, "emotions.json")

# --- 8. Emoji top (frequency + sentiment) -------------------------------------

emoji_lexicon <- read_csv(here("data", "lexicons", "wsb_emoji_lexicon.csv"),
                          show_col_types = FALSE)

emoji_top <- emoji_freq %>%
  head(20) %>%
  left_join(emoji_lexicon, by = "emoji") %>%
  select(emoji, count = n, sentiment_value = value, description)

export_json(emoji_top, "emoji_top.json")

# --- 9. Word contributions (AFINN top positive/negative) ----------------------

# Use the BING word contribution data already computed in 06
word_contrib <- bing_word_contrib %>%
  group_by(sentiment) %>%
  slice_max(n, n = 30) %>%
  ungroup() %>%
  rename(count = n)

export_json(word_contrib, "word_contributions.json")

# --- 10. Bootstrap CIs -------------------------------------------------------

bootstrap_ci <- read_csv(file.path(TAB_DIR, "bootstrap_ci.csv"),
                         show_col_types = FALSE)
export_json(bootstrap_ci, "bootstrap_ci.json")

# --- 11. Robustness (cross-lexicon comparison) --------------------------------

extract_rob_coefs <- function(model, model_name) {
  hac <- compute_hac_results(model)
  tibble(
    variable = rownames(hac),
    estimate = hac[, "Estimate"],
    std_error = hac[, "Std. Error"],
    p_value = hac[, "Pr(>|t|)"],
    model = model_name
  )
}

robustness <- bind_rows(
  extract_rob_coefs(robustness_output$lexicon_models$bing, "BING"),
  extract_rob_coefs(robustness_output$lexicon_models$nrc, "NRC"),
  extract_rob_coefs(regression_results$m3_afinn, "AFINN"),
  extract_rob_coefs(regression_results$m3_wsb, "WSB"),
  extract_rob_coefs(robustness_output$lexicon_models$combined, "Combined")
)

placebo <- list(
  coefficient = coef(robustness_output$placebo_did)["treat_x_post"],
  p_value = robustness_output$placebo_p
)

export_json(list(coefficients = robustness, placebo = placebo), "robustness.json")

# --- Summary ------------------------------------------------------------------

json_files <- list.files(DASH_DIR, pattern = "\\.json$")
message(sprintf("\nDashboard export complete: %d JSON files -> %s",
                length(json_files), DASH_DIR))
message("Files: ", paste(json_files, collapse = ", "))
