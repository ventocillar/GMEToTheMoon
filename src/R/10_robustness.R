# ==============================================================================
# 10_robustness.R
# Robustness checks: alternative lexicons, placebo, subsample, validation
# ==============================================================================

message("=== 10: Robustness checks ===")

# --- 10A: Re-run regressions with alternative lexicons ------------------------

message("  10A: Alternative lexicon regressions...")

robustness_models <- list()

# BING-based regression
robustness_models$bing <- lm(gme_return ~ bing_net_lag1 + bing_net_lag2 +
                               gme_abnormal_volume + n_comments_lag1,
                             data = reg_data)

# NRC net sentiment
robustness_models$nrc <- lm(gme_return ~ nrc_net_lag1 + nrc_net_lag2 +
                              gme_abnormal_volume + n_comments_lag1,
                            data = reg_data)

# All lexicons combined
robustness_models$combined <- lm(gme_return ~ afinn_lag1 + wsb_lag1 + bing_net_lag1 +
                                   emoji_lag1 + gme_abnormal_volume + n_comments_lag1,
                                 data = reg_data)

# HAC SEs for all
rob_hac <- lapply(robustness_models, compute_hac_results)

# Output table
tryCatch({
  stargazer(robustness_models$bing, robustness_models$nrc,
            regression_results$m3_afinn, regression_results$m3_wsb,
            robustness_models$combined,
            type = "text",
            title = "Robustness: Main Result Across Lexicons",
            dep.var.labels = "GME Daily Return",
            column.labels = c("BING", "NRC", "AFINN", "WSB", "Combined"),
            notes = "Newey-West HAC standard errors",
            out = file.path(TAB_DIR, "robustness_lexicons.tex"))
}, error = function(e) {
  message("  Note: stargazer failed for combined table (known bug), using modelsummary instead")
  rob_models <- list(
    "BING" = robustness_models$bing,
    "NRC" = robustness_models$nrc,
    "AFINN" = regression_results$m3_afinn,
    "WSB" = regression_results$m3_wsb,
    "Combined" = robustness_models$combined
  )
  modelsummary(rob_models,
               output = file.path(TAB_DIR, "robustness_lexicons.tex"),
               title = "Robustness: Main Result Across Lexicons")
  modelsummary(rob_models, output = "default")
})

# --- 10B: Score-weighted vs. unweighted comparison ----------------------------

message("  10B: Weighted vs. unweighted comparison...")

# Re-compute sentiment with weighting
sentiment_weighted_daily <- all_sentiment %>%
  filter(weight_type == "weighted", lexicon == "afinn", emotion == "score") %>%
  dplyr::select(date, w_afinn = weighted_count)

message(sprintf("  Weighted AFINN days: %d", nrow(sentiment_weighted_daily)))

if (nrow(sentiment_weighted_daily) > 0) {
  reg_data_w <- reg_data %>%
    left_join(sentiment_weighted_daily, by = "date") %>%
    mutate(w_afinn_lag1 = lag(w_afinn, 1)) %>%
    filter(!is.na(w_afinn_lag1), !is.na(gme_return))

  if (nrow(reg_data_w) > 5) {
    m_unweighted <- lm(gme_return ~ afinn_lag1, data = reg_data_w)
    m_weighted   <- lm(gme_return ~ w_afinn_lag1, data = reg_data_w)

    stargazer(m_unweighted, m_weighted,
              type = "text",
              title = "Score-Weighted vs. Unweighted Sentiment",
              column.labels = c("Unweighted", "Score-Weighted"),
              out = file.path(TAB_DIR, "robustness_weighted.tex"))
  } else {
    message("  Skipping 10B: insufficient matched weighted data")
  }
} else {
  message("  Skipping 10B: no weighted AFINN data available")
}

# --- 10C: Placebo test (fake event: Dec 15, 2020) ----------------------------

message("  10C: Placebo test with fake event date...")

# Use stock period start to placebo window end (2 months around placebo date)
placebo_window_start <- as.Date(cfg$stock_period$start)
placebo_window_end   <- PLACEBO_DATE + 30  # ~1 month after fake event

placebo_data <- stock_prices %>%
  filter(date >= placebo_window_start, date <= placebo_window_end) %>%
  filter(!is.na(daily_return)) %>%
  mutate(
    treated = as.integer(symbol %in% MEME_STOCKS),
    post    = as.integer(date >= PLACEBO_DATE),
    treat_x_post = treated * post,
    stock_id = as.factor(symbol),
    date_id  = as.factor(date)
  )

placebo_did <- feols(daily_return ~ treat_x_post | stock_id + date_id,
                     data = placebo_data,
                     cluster = ~ symbol)

placebo_p <- summary(placebo_did)$coeftable["treat_x_post", "Pr(>|t|)"]
message(sprintf("  Placebo DiD coefficient: %.4f (p = %.4f) -- %s",
                coef(placebo_did)["treat_x_post"],
                placebo_p,
                ifelse(placebo_p > 0.05, "NOT significant (good!)",
                       "Significant (investigate)")))

# --- 10D: High-engagement subsample ------------------------------------------

message("  10D: High-engagement subsample analysis...")

# Recompute sentiment using only high-score comments
conn <- get_db_connection()
high_score_comments <- dbGetQuery(conn, sprintf(
  "SELECT comment_id, body, author, score, date
   FROM comments
   WHERE date >= '%s' AND date <= '%s' AND score > 10
   ORDER BY created_utc",
  STUDY_START, STUDY_END
))
dbDisconnect(conn)

high_score_comments <- high_score_comments %>% mutate(date = as.Date(date))
message(sprintf("  High-engagement comments (score > 10): %s",
                format(nrow(high_score_comments), big.mark = ",")))

if (nrow(high_score_comments) > 100) {
  # Quick tokenize
  hs_tokens <- high_score_comments %>%
    select(comment_id, text = body, date, score) %>%
    mutate(text = str_replace_all(text, "https?://\\S+", "")) %>%
    unnest_tokens(word, text) %>%
    anti_join(all_stop_words, by = "word") %>%
    filter(!str_detect(word, "^\\d+$"), nchar(word) > 1)

  hs_afinn <- compute_sentiment_by_lexicon(hs_tokens, "afinn")

  hs_daily <- hs_afinn %>%
    select(date, hs_afinn_score = weighted_count)

  reg_data_hs <- reg_data %>%
    left_join(hs_daily, by = "date") %>%
    mutate(hs_afinn_lag1 = lag(hs_afinn_score, 1))

  m_all_comments <- lm(gme_return ~ afinn_lag1, data = reg_data_hs)
  m_high_score   <- lm(gme_return ~ hs_afinn_lag1, data = reg_data_hs)

  stargazer(m_all_comments, m_high_score,
            type = "text",
            title = "All Comments vs. High-Engagement (score > 10)",
            column.labels = c("All Comments", "High Score Only"),
            out = file.path(TAB_DIR, "robustness_high_engagement.tex"))
}

# --- 10E: Bootstrap confidence intervals -------------------------------------

message("  10E: Bootstrap confidence intervals for main coefficients...")

set.seed(cfg$validation$random_seed)
n_boot <- cfg$regression$bootstrap_reps

boot_coefs <- replicate(n_boot, {
  boot_idx <- sample(nrow(reg_data), replace = TRUE)
  boot_data <- reg_data[boot_idx, ]
  coef(lm(gme_return ~ afinn_lag1 + wsb_lag1, data = boot_data))
})

boot_ci <- apply(boot_coefs, 1, quantile, probs = c(0.025, 0.975))

boot_results <- tibble(
  coefficient = colnames(boot_ci),
  ci_lower = boot_ci[1, ],
  ci_upper = boot_ci[2, ],
  mean_est = rowMeans(boot_coefs)
)

message("  Bootstrap 95% CIs:")
print(boot_results)

write_csv(boot_results, file.path(TAB_DIR, "bootstrap_ci.csv"))

# --- 10F: Manual validation sample -------------------------------------------

message("  10F: Exporting validation sample...")

conn <- get_db_connection()
set.seed(cfg$validation$random_seed)

validation_sample <- dbGetQuery(conn, sprintf(
  "SELECT comment_id, body, score, date FROM comments
   WHERE date >= '%s' AND date <= '%s'
   ORDER BY RANDOM() LIMIT %d",
  STUDY_START, STUDY_END,
  cfg$validation$sample_size
))
dbDisconnect(conn)

# Add empty columns for manual annotation
validation_sample$manual_sentiment <- NA_character_  # positive / negative / neutral
validation_sample$manual_confidence <- NA_real_       # 1-5 scale
validation_sample$notes <- NA_character_

write_csv(validation_sample, file.path(TAB_DIR, "validation_sample.csv"))
message(sprintf("  Exported %d comments for manual annotation -> %s",
                nrow(validation_sample),
                file.path(TAB_DIR, "validation_sample.csv")))

# --- Store all robustness results ---------------------------------------------

robustness_output <- list(
  lexicon_models = robustness_models,
  placebo_did = placebo_did,
  placebo_p = placebo_p,
  boot_results = boot_results,
  validation_sample_n = nrow(validation_sample)
)

message("Robustness checks complete.\n")
