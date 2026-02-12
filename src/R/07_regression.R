# ==============================================================================
# 07_regression.R
# OLS regressions with Newey-West HAC standard errors
# Tests whether WSB sentiment predicts GME returns
# ==============================================================================

message("=== 07: Regression analysis ===")

# Use only trading days with complete data (dates from config)
reg_data <- master_trading %>%
  filter(date >= STUDY_START, date <= STUDY_END) %>%
  filter(!is.na(gme_return), !is.na(afinn_score))

message(sprintf("  Regression sample: %d trading days", nrow(reg_data)))

# --- Model 1: Contemporaneous ------------------------------------------------
# return_t ~ sentiment_t

m1_afinn <- lm(gme_return ~ afinn_score, data = reg_data)
m1_wsb   <- lm(gme_return ~ wsb_score, data = reg_data)
m1_bing  <- lm(gme_return ~ bing_net, data = reg_data)

# --- Model 2: Lagged sentiment (predictive) ----------------------------------
# return_t ~ sentiment_{t-1}

m2_afinn <- lm(gme_return ~ afinn_lag1, data = reg_data)
m2_wsb   <- lm(gme_return ~ wsb_lag1, data = reg_data)
m2_bing  <- lm(gme_return ~ bing_net_lag1, data = reg_data)

# --- Model 3: Full model with controls ---------------------------------------
# return_t ~ sentiment_{t-1} + sentiment_{t-2} + volume + n_comments

m3_afinn <- lm(gme_return ~ afinn_lag1 + afinn_lag2 +
                 gme_abnormal_volume + n_comments_lag1,
               data = reg_data)

m3_wsb <- lm(gme_return ~ wsb_lag1 + wsb_lag2 +
               gme_abnormal_volume + n_comments_lag1,
             data = reg_data)

# --- Model 4: Text vs Emoji vs Combined (F-test) -----------------------------

m4_text_only <- lm(gme_return ~ afinn_lag1 + wsb_lag1, data = reg_data)
m4_emoji_only <- lm(gme_return ~ emoji_lag1, data = reg_data)
m4_combined <- lm(gme_return ~ afinn_lag1 + wsb_lag1 + emoji_lag1, data = reg_data)

# F-test: does emoji add explanatory power?
emoji_f_test <- anova(m4_text_only, m4_combined)

# --- Newey-West HAC Standard Errors -------------------------------------------

nw_lags <- cfg$regression$newey_west_lags

compute_hac_results <- function(model, nw_lag = nw_lags) {
  hac_vcov <- sandwich::NeweyWest(model, lag = nw_lag, prewhite = FALSE)
  coeftest(model, vcov = hac_vcov)
}

# Compute HAC results for all models
hac_m1_afinn <- compute_hac_results(m1_afinn)
hac_m2_afinn <- compute_hac_results(m2_afinn)
hac_m3_afinn <- compute_hac_results(m3_afinn)
hac_m2_wsb   <- compute_hac_results(m2_wsb)
hac_m3_wsb   <- compute_hac_results(m3_wsb)

# --- Output Tables ------------------------------------------------------------

# Main regression table (AFINN)
stargazer(m1_afinn, m2_afinn, m3_afinn,
          type = "text",
          title = "OLS Regression: AFINN Sentiment and GME Returns",
          dep.var.labels = "GME Daily Return",
          column.labels = c("Contemp.", "Lagged", "Full"),
          se = list(
            hac_m1_afinn[, "Std. Error"],
            hac_m2_afinn[, "Std. Error"],
            hac_m3_afinn[, "Std. Error"]
          ),
          notes = "Newey-West HAC standard errors in parentheses",
          out = file.path(TAB_DIR, "regression_afinn.tex"))

# WSB sentiment table
stargazer(m1_wsb, m2_wsb, m3_wsb,
          type = "text",
          title = "OLS Regression: WSB Custom Sentiment and GME Returns",
          dep.var.labels = "GME Daily Return",
          column.labels = c("Contemp.", "Lagged", "Full"),
          se = list(
            compute_hac_results(m1_wsb)[, "Std. Error"],
            hac_m2_wsb[, "Std. Error"],
            hac_m3_wsb[, "Std. Error"]
          ),
          notes = "Newey-West HAC standard errors in parentheses",
          out = file.path(TAB_DIR, "regression_wsb.tex"))

# Text vs Emoji comparison
stargazer(m4_text_only, m4_emoji_only, m4_combined,
          type = "text",
          title = "Text-Only vs. Emoji vs. Combined Sentiment",
          dep.var.labels = "GME Daily Return",
          column.labels = c("Text Only", "Emoji Only", "Combined"),
          notes = "Newey-West HAC standard errors",
          out = file.path(TAB_DIR, "regression_text_vs_emoji.tex"))

# --- Store results for later use ----------------------------------------------

regression_results <- list(
  m1_afinn = m1_afinn, m2_afinn = m2_afinn, m3_afinn = m3_afinn,
  m1_wsb = m1_wsb, m2_wsb = m2_wsb, m3_wsb = m3_wsb,
  m4_text = m4_text_only, m4_emoji = m4_emoji_only, m4_combined = m4_combined,
  emoji_f_test = emoji_f_test,
  hac_m2_afinn = hac_m2_afinn, hac_m3_afinn = hac_m3_afinn,
  hac_m2_wsb = hac_m2_wsb, hac_m3_wsb = hac_m3_wsb
)

message("  Emoji F-test p-value: ", format.pval(emoji_f_test$`Pr(>F)`[2], digits = 4))
message("Regression analysis complete.\n")
