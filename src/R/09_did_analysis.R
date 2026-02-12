# ==============================================================================
# 09_did_analysis.R
# Difference-in-Differences analysis
# Treatment: meme stocks (WSB attention). Control: retail stocks (no WSB)
# Event: Robinhood trading restriction (Jan 28, 2021)
# ==============================================================================

message("=== 09: Difference-in-Differences analysis ===")

# --- Prepare DiD dataset -----------------------------------------------------

# Use wider stock period for DiD (allows pre-trend testing)
did_start <- as.Date(cfg$stock_period$start)
did_end   <- as.Date(cfg$stock_period$end)

did_data <- stock_prices %>%
  filter(date >= did_start, date <= did_end) %>%
  filter(!is.na(daily_return)) %>%
  mutate(
    treated = as.integer(symbol %in% MEME_STOCKS),
    post    = as.integer(date >= EVENT_DATE),
    treat_x_post = treated * post,
    # For event study
    days_to_event = as.numeric(date - EVENT_DATE),
    # Stock and date identifiers for fixed effects
    stock_id = as.factor(symbol),
    date_id  = as.factor(date)
  )

n_treated <- sum(did_data$treated == 1)
n_control <- sum(did_data$treated == 0)
message(sprintf("  DiD sample: %d obs (%d treated, %d control)",
                nrow(did_data), n_treated, n_control))

# --- Main DiD Regression (fixest) ---------------------------------------------

# Model 1: Basic DiD
did_m1 <- feols(daily_return ~ treated * post,
                data = did_data,
                cluster = ~ symbol)

# Model 2: With stock fixed effects
did_m2 <- feols(daily_return ~ treat_x_post | stock_id,
                data = did_data,
                cluster = ~ symbol)

# Model 3: With stock + date fixed effects (two-way FE)
did_m3 <- feols(daily_return ~ treat_x_post | stock_id + date_id,
                data = did_data,
                cluster = ~ symbol)

message("\n  DiD Results (main specification):")
# Use summary coeftable to avoid fixest::pvalue formatting issues
m1_pv <- summary(did_m1)$coeftable[,"Pr(>|t|)"]
m2_pv <- summary(did_m2)$coeftable[,"Pr(>|t|)"]
m3_pv <- summary(did_m3)$coeftable[,"Pr(>|t|)"]
message(sprintf("  Basic DiD (treat x post): %.4f (p = %.4f)",
                coef(did_m1)["treated:post"], m1_pv["treated:post"]))
message(sprintf("  Stock FE: %.4f (p = %.4f)",
                coef(did_m2)["treat_x_post"], m2_pv["treat_x_post"]))
message(sprintf("  Two-way FE: %.4f (p = %.4f)",
                coef(did_m3)["treat_x_post"], m3_pv["treat_x_post"]))

# --- Output table -------------------------------------------------------------

etable(did_m1, did_m2, did_m3,
       title = "Difference-in-Differences: Meme vs. Control Stocks",
       headers = c("Basic", "Stock FE", "Two-way FE"),
       notes = "Clustered SEs at stock level. Event: Robinhood restriction (Jan 28, 2021).",
       file = file.path(TAB_DIR, "did_results.tex"))

# --- Pre-Trend Test (Parallel Trends) ----------------------------------------

message("  Testing parallel trends assumption...")

# Event study specification: interact treatment with relative time dummies
did_data <- did_data %>%
  mutate(
    # Bin relative time periods
    rel_period = case_when(
      days_to_event <= -15 ~ -15,
      days_to_event >= 15  ~ 15,
      TRUE ~ days_to_event
    ),
    rel_period = as.factor(rel_period)
  )

# Event study regression (omit period -1 as reference)
event_study <- feols(daily_return ~ i(rel_period, treated, ref = -1) | stock_id + date_id,
                     data = did_data,
                     cluster = ~ symbol)

# Extract pre-treatment coefficients for parallel trends test
es_coefs <- broom::tidy(event_study, conf.int = TRUE)
pre_coefs <- es_coefs %>%
  filter(grepl("rel_period", term)) %>%
  mutate(
    period = as.numeric(str_extract(term, "-?\\d+")),
    pre_treatment = period < 0
  )

# Joint test of pre-treatment coefficients
pre_periods <- pre_coefs %>% filter(pre_treatment)
pre_trend_significant <- any(pre_periods$p.value < 0.05)

message(sprintf("  Pre-trend test: %s (any significant pre-treatment coefficients: %s)",
                ifelse(pre_trend_significant, "FAILED - check parallel trends",
                       "PASSED - parallel trends supported"),
                pre_trend_significant))

# --- Event Study Plot ---------------------------------------------------------

p_event_study <- pre_coefs %>%
  ggplot(aes(x = period, y = estimate)) +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high),
              fill = thesis_palette[1], alpha = 0.2) +
  geom_point(color = thesis_palette[1], size = 2) +
  geom_line(color = thesis_palette[1], linewidth = 0.8) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  geom_vline(xintercept = -0.5, linetype = "dashed",
             color = thesis_colors$event, alpha = 0.7) +
  annotate("text", x = -0.5, y = max(pre_coefs$conf.high, na.rm = TRUE),
           label = "Event", hjust = -0.1, color = thesis_colors$event, size = 3.5) +
  labs(title = "Event Study: Cumulative Abnormal Returns",
       subtitle = "Meme stocks vs. retail control stocks around Robinhood restriction",
       x = "Days Relative to Event (Jan 28, 2021)",
       y = "Coefficient (treatment effect)") +
  theme_thesis()

save_thesis_plot(p_event_study, "did_event_study.png")

# --- Cumulative Abnormal Returns Plot -----------------------------------------

car_data <- stock_prices %>%
  filter(date >= did_start, date <= did_end) %>%
  mutate(group = ifelse(symbol %in% MEME_STOCKS, "Meme Stocks", "Control Stocks")) %>%
  group_by(group, date) %>%
  summarize(mean_return = mean(daily_return, na.rm = TRUE), .groups = "drop") %>%
  group_by(group) %>%
  arrange(date) %>%
  mutate(cumulative_return = cumsum(replace_na(mean_return, 0))) %>%
  ungroup()

p_car <- car_data %>%
  ggplot(aes(x = date, y = cumulative_return, color = group)) +
  geom_line(linewidth = 1, alpha = 0.8) +
  geom_vline(xintercept = EVENT_DATE,
             linetype = "dashed", color = thesis_colors$event, alpha = 0.7) +
  scale_color_manual(values = c("Meme Stocks" = thesis_palette[1],
                                 "Control Stocks" = thesis_palette[6])) +
  scale_x_date(date_breaks = "1 week", date_labels = "%b %d") +
  scale_y_continuous(labels = percent) +
  labs(title = "Cumulative Returns: Meme Stocks vs. Control Stocks",
       subtitle = "Jan - Feb 2021",
       x = NULL, y = "Cumulative Return", color = NULL) +
  theme_thesis()

save_thesis_plot(p_car, "cumulative_abnormal_returns.png")

# --- Store results ------------------------------------------------------------

did_output <- list(
  did_m1 = did_m1,
  did_m2 = did_m2,
  did_m3 = did_m3,
  event_study = event_study,
  pre_trend_passed = !pre_trend_significant
)

message("DiD analysis complete.\n")
