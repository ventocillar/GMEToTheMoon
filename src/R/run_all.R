# ==============================================================================
# run_all.R
# Master script: sources all analysis scripts in order
#
# Usage: source("src/R/run_all.R") from the project root
# Or:    Rscript src/R/run_all.R
# ==============================================================================

cat("\n")
cat("================================================================\n")
cat("  GMEToTheMoon: WSB Sentiment & GameStop Returns Analysis\n")
cat("  Master Script\n")
cat("================================================================\n\n")

start_time <- Sys.time()

# Ensure we're in the project root
if (!file.exists("config.yml")) {
  if (requireNamespace("here", quietly = TRUE)) {
    setwd(here::here())
  } else {
    stop("Cannot find config.yml. Run this script from the project root.")
  }
}

# --- Phase 0: Setup -----------------------------------------------------------
cat("PHASE 0: Setup\n")
source(here::here("src", "R", "00_setup.R"))

# --- Phase 1: Load Data ------------------------------------------------------
cat("PHASE 1: Load Data\n")
source(here::here("src", "R", "01_load_data.R"))

# --- Phase 2: Preprocess Text ------------------------------------------------
cat("PHASE 2: Preprocess Text\n")
source(here::here("src", "R", "02_preprocess_text.R"))

# --- Phase 3: Sentiment Analysis ---------------------------------------------
cat("PHASE 3: Sentiment Analysis\n")
source(here::here("src", "R", "03_sentiment_analysis.R"))

# --- Phase 4: Financial Data --------------------------------------------------
cat("PHASE 4: Financial Data\n")
source(here::here("src", "R", "04_financial_data.R"))

# --- Phase 5: Merge & Aggregate ----------------------------------------------
cat("PHASE 5: Merge & Aggregate\n")
source(here::here("src", "R", "05_merge_and_aggregate.R"))

# --- Phase 6: Descriptive Statistics -----------------------------------------
cat("PHASE 6: Descriptive Statistics\n")
source(here::here("src", "R", "06_descriptive_stats.R"))

# --- Phase 7: Regression Analysis --------------------------------------------
cat("PHASE 7: Regression Analysis\n")
source(here::here("src", "R", "07_regression.R"))

# --- Phase 8: Granger Causality ----------------------------------------------
cat("PHASE 8: Granger Causality\n")
source(here::here("src", "R", "08_granger_causality.R"))

# --- Phase 9: Difference-in-Differences --------------------------------------
cat("PHASE 9: Difference-in-Differences\n")
source(here::here("src", "R", "09_did_analysis.R"))

# --- Phase 10: Robustness Checks ---------------------------------------------
cat("PHASE 10: Robustness Checks\n")
source(here::here("src", "R", "10_robustness.R"))

# --- Summary ------------------------------------------------------------------

end_time <- Sys.time()
elapsed  <- difftime(end_time, start_time, units = "mins")

cat("\n")
cat("================================================================\n")
cat("  Analysis complete!\n")
cat(sprintf("  Elapsed time: %.1f minutes\n", as.numeric(elapsed)))
cat(sprintf("  Figures saved to: %s\n", FIG_DIR))
cat(sprintf("  Tables saved to: %s\n", TAB_DIR))
cat("================================================================\n")
cat("\n")

# --- Key findings summary -----------------------------------------------------

cat("KEY FINDINGS:\n\n")

cat("1. Granger Causality:\n")
print(granger_output$granger_results)
cat("\n")

cat("2. DiD (treat x post coefficient):\n")
cat(sprintf("   Two-way FE: %.4f (p = %.4f)\n",
            coef(did_output$did_m3)["treat_x_post"],
            summary(did_output$did_m3)$coeftable["treat_x_post", "Pr(>|t|)"]))
cat(sprintf("   Pre-trend test: %s\n",
            ifelse(did_output$pre_trend_passed, "PASSED", "FAILED")))
cat("\n")

cat("3. Placebo Test:\n")
cat(sprintf("   p-value = %.4f (%s)\n",
            robustness_output$placebo_p,
            ifelse(robustness_output$placebo_p > 0.05,
                   "Not significant - supports causal interpretation",
                   "Significant - investigate")))
cat("\n")

cat("4. Emoji F-test (does emoji add value to text-only?):\n")
cat(sprintf("   p-value = %s\n",
            format.pval(regression_results$emoji_f_test$`Pr(>F)`[2], digits = 4)))

# --- Phase 11: Export dashboard data ------------------------------------------
cat("\nPHASE 11: Export Dashboard Data\n")
source(here::here("src", "R", "11_export_dashboard.R"))
