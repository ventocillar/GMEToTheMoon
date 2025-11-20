# ============================================================================
# ENHANCED GAMESTOP SENTIMENT ANALYSIS
# ============================================================================
# This script implements improved methodology for analyzing the relationship
# between Reddit sentiment and GameStop stock prices during January 2021
#
# Key improvements:
# 1. Score-weighted sentiment analysis
# 2. Regression models with lag structure
# 3. Difference-in-Differences estimation
# 4. Financial-specific sentiment lexicons
# 5. Robust statistical testing
# 6. Modular, reproducible code
# ============================================================================

# SETUP -----------------------------------------------------------------------

# Required packages
packages <- c(
  "tidyverse", "lubridate", "here",
  "readxl", "tidytext", "quanteda",
  "tidyquant", "zoo", "xts",
  "lmtest", "sandwich", "fixest",
  "ggplot2", "scales", "MetBrewer",
  "broom", "modelsummary", "kableExtra"
)

# Install missing packages
new_packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new_packages)) install.packages(new_packages)

# Load packages
invisible(lapply(packages, library, character.only = TRUE))

# Set working directory using here package for reproducibility
# This will work regardless of where the project is located
setwd(here::here())

# Create output directories if they don't exist
dir.create("output", showWarnings = FALSE)
dir.create("output/figures", showWarnings = FALSE)
dir.create("output/tables", showWarnings = FALSE)

# Configuration
CONFIG <- list(
  start_date = as.Date("2021-01-13"),
  end_date = as.Date("2021-01-31"),
  stocks = c("GME", "DDS", "BBBY", "FIZZ", "NOK", "BB", "AMC"),
  control_stocks = c("KODK", "EXPR", "NAKD"),  # Add control stocks
  data_dir = here::here("data"),
  output_dir = here::here("output")
)


# HELPER FUNCTIONS ------------------------------------------------------------

#' Read and clean Reddit comments for a single day
#'
#' @param date_str Character string for the date (e.g., "13", "14")
#' @param data_dir Directory containing the data files
#' @return Tibble with cleaned comment data
read_comments_single_day <- function(date_str, data_dir = ".", include_score = FALSE) {

  if (include_score) {
    file_pattern <- paste0("comments_", date_str, "_Jan_withscore.xlsx")
  } else {
    file_pattern <- paste0("comments_", date_str, "_Jan.xlsx")
  }

  file_path <- file.path(data_dir, file_pattern)

  if (!file.exists(file_path)) {
    warning(paste("File not found:", file_path))
    return(NULL)
  }

  df <- read_excel(file_path)

  # Select relevant columns
  if (include_score && "score" %in% names(df)) {
    df <- df %>% select(body, date, score)
  } else {
    df <- df %>% select(body, date)
  }

  # Clean and standardize
  df <- df %>%
    mutate(
      date = as.Date(date),
      body = str_replace_all(body, "[^[:alnum:][:space:]']", " "),
      body = str_trim(body)
    ) %>%
    filter(
      !body %in% c("[deleted]", "[removed]", ""),
      nchar(body) > 10  # Remove very short comments
    )

  return(df)
}


#' Read all Reddit comments for a date range
#'
#' @param dates Vector of date strings
#' @param data_dir Directory containing data files
#' @return Combined tibble of all comments
read_all_comments <- function(dates, data_dir = ".", include_score = FALSE) {

  comments_list <- map(dates, ~read_comments_single_day(.x, data_dir, include_score))

  # Remove NULL entries (missing files)
  comments_list <- comments_list[!sapply(comments_list, is.null)]

  # Combine all data frames
  all_comments <- bind_rows(comments_list)

  # Log summary
  message(sprintf("Loaded %d comments from %d days",
                  nrow(all_comments),
                  length(unique(all_comments$date))))

  return(all_comments)
}


#' Calculate sentiment scores with optional weighting
#'
#' @param comments_df Tibble with 'body', 'date', and optionally 'score' columns
#' @param sentiment_dict Sentiment dictionary (e.g., get_sentiments("bing"))
#' @param weight_by_score Logical, whether to weight by comment score
#' @return Tibble with daily sentiment metrics
calculate_sentiment <- function(comments_df,
                                sentiment_dict,
                                weight_by_score = FALSE,
                                score_transform = "log") {

  # Tokenize
  tokens <- comments_df %>%
    unnest_tokens(word, body)

  # Remove stop words
  data(stop_words)

  # Add custom stop words for Reddit
  custom_stops <- tibble(
    word = c("deleted", "removed", "http", "https", "www"),
    lexicon = "custom"
  )

  stop_words_extended <- bind_rows(stop_words, custom_stops)

  tokens <- tokens %>%
    anti_join(stop_words_extended, by = "word")

  # Join with sentiment dictionary
  sentiment_tokens <- tokens %>%
    inner_join(sentiment_dict, by = "word")

  # Calculate sentiment based on dictionary type
  if ("sentiment" %in% names(sentiment_dict)) {
    # BING-style (positive/negative)
    sentiment_tokens <- sentiment_tokens %>%
      mutate(sentiment_value = ifelse(sentiment == "positive", 1, -1))
  } else if ("value" %in% names(sentiment_dict)) {
    # AFINN-style (numeric scores)
    sentiment_tokens <- sentiment_tokens %>%
      rename(sentiment_value = value)
  }

  # Apply weighting if requested and scores available
  if (weight_by_score && "score" %in% names(sentiment_tokens)) {

    if (score_transform == "log") {
      sentiment_tokens <- sentiment_tokens %>%
        mutate(weight = log(score + 1))
    } else if (score_transform == "sqrt") {
      sentiment_tokens <- sentiment_tokens %>%
        mutate(weight = sqrt(score + 1))
    } else {
      sentiment_tokens <- sentiment_tokens %>%
        mutate(weight = score)
    }

    sentiment_tokens <- sentiment_tokens %>%
      mutate(weighted_sentiment = sentiment_value * weight)
  }

  # Aggregate by date
  if (weight_by_score && "weighted_sentiment" %in% names(sentiment_tokens)) {
    daily_sentiment <- sentiment_tokens %>%
      group_by(date) %>%
      summarize(
        sentiment_unweighted = sum(sentiment_value),
        sentiment_weighted = sum(weighted_sentiment),
        n_words = n(),
        avg_score = mean(score, na.rm = TRUE),
        .groups = "drop"
      )
  } else {
    daily_sentiment <- sentiment_tokens %>%
      group_by(date) %>%
      summarize(
        sentiment_unweighted = sum(sentiment_value),
        n_words = n(),
        .groups = "drop"
      )
  }

  return(daily_sentiment)
}


#' Get stock price data with returns calculation
#'
#' @param symbols Vector of stock symbols
#' @param start_date Start date for data
#' @param end_date End date for data
#' @return Tibble with stock prices and returns
get_stock_data_with_returns <- function(symbols, start_date, end_date) {

  stock_data <- tq_get(
    symbols,
    get = "stock.prices",
    from = start_date,
    to = end_date
  )

  # Calculate returns and other metrics
  stock_data <- stock_data %>%
    group_by(symbol) %>%
    arrange(date) %>%
    mutate(
      # Simple returns
      return = (adjusted - lag(adjusted)) / lag(adjusted) * 100,
      # Log returns
      log_return = log(adjusted / lag(adjusted)) * 100,
      # Volume change
      volume_change = (volume - lag(volume)) / lag(volume) * 100,
      # Lag variables
      return_lag1 = lag(return, 1),
      return_lag2 = lag(return, 2)
    ) %>%
    ungroup()

  return(stock_data)
}


#' Create analysis dataset by merging sentiment and stock data
#'
#' @param sentiment_df Daily sentiment tibble
#' @param stock_df Stock price tibble
#' @param stock_symbol Symbol to filter for (default "GME")
#' @param add_market_data Logical, add S&P 500 data
#' @return Merged analysis tibble
create_analysis_dataset <- function(sentiment_df,
                                    stock_df,
                                    stock_symbol = "GME",
                                    add_market_data = TRUE) {

  # Filter for specific stock
  stock_filtered <- stock_df %>%
    filter(symbol == stock_symbol)

  # Merge sentiment with stock data
  analysis_data <- stock_filtered %>%
    left_join(sentiment_df, by = "date")

  # Add lagged sentiment
  analysis_data <- analysis_data %>%
    arrange(date) %>%
    mutate(
      sentiment_lag1 = lag(sentiment_weighted, 1),
      sentiment_lag2 = lag(sentiment_weighted, 2),
      sentiment_lead1 = lead(sentiment_weighted, 1)
    )

  # Add market data (S&P 500) as control
  if (add_market_data) {
    sp500 <- tq_get(
      "^GSPC",
      get = "stock.prices",
      from = min(analysis_data$date, na.rm = TRUE) - days(5),
      to = max(analysis_data$date, na.rm = TRUE)
    ) %>%
      mutate(sp500_return = (adjusted - lag(adjusted)) / lag(adjusted) * 100) %>%
      select(date, sp500_return)

    analysis_data <- analysis_data %>%
      left_join(sp500, by = "date")
  }

  return(analysis_data)
}


# DATA LOADING ----------------------------------------------------------------

message("=== LOADING DATA ===\n")

# Date range for Reddit data
dates <- c("13", "14", "15", "16", "17", "18", "19", "20",
           "21", "22", "23", "24", "27", "28", "29", "30", "31")

# Load Reddit comments
# Try to load with scores first
comments_with_scores <- read_comments_single_day("13-31", data_dir = ".", include_score = TRUE)

if (!is.null(comments_with_scores) && nrow(comments_with_scores) > 0) {
  message("Loaded comments with scores")
  reddit_comments <- comments_with_scores
  has_scores <- TRUE
} else {
  message("Loading comments without scores")
  reddit_comments <- read_all_comments(dates, data_dir = ".")
  has_scores <- FALSE
}

# Summary statistics
message(sprintf("\nReddit Data Summary:"))
message(sprintf("  Date range: %s to %s", min(reddit_comments$date), max(reddit_comments$date)))
message(sprintf("  Total comments: %d", nrow(reddit_comments)))
message(sprintf("  Comments per day: %.1f", nrow(reddit_comments) / n_distinct(reddit_comments$date)))

if (has_scores) {
  message(sprintf("  Score range: %.0f to %.0f", min(reddit_comments$score), max(reddit_comments$score)))
  message(sprintf("  Median score: %.0f", median(reddit_comments$score)))
}

# Load stock data
message("\n=== LOADING STOCK DATA ===\n")

# Get historical data (for context plots)
historic_stocks <- get_stock_data_with_returns(
  symbols = CONFIG$stocks,
  start_date = as.Date("2020-01-01"),
  end_date = as.Date("2021-05-01")
)

# Get event period data
event_stocks <- get_stock_data_with_returns(
  symbols = c(CONFIG$stocks, CONFIG$control_stocks),
  start_date = CONFIG$start_date - days(30),  # Include pre-period
  end_date = CONFIG$end_date + days(30)       # Include post-period
)

message(sprintf("Loaded data for %d stocks", length(unique(event_stocks$symbol))))


# SENTIMENT ANALYSIS ----------------------------------------------------------

message("\n=== SENTIMENT ANALYSIS ===\n")

# Get sentiment dictionaries
bing_dict <- get_sentiments("bing")
afinn_dict <- get_sentiments("afinn")
nrc_dict <- get_sentiments("nrc")

# Create custom WSB lexicon
wsb_positive <- c("moon", "rocket", "tendies", "gains", "bullish",
                  "diamond", "hold", "buy", "long", "calls", "squeeze")
wsb_negative <- c("bears", "puts", "crash", "sell", "short",
                  "loss", "bag", "rip", "bagholding")

custom_wsb <- tibble(
  word = c(wsb_positive, wsb_negative),
  sentiment = c(rep("positive", length(wsb_positive)),
                rep("negative", length(wsb_negative)))
)

# Enhanced BING dictionary with WSB terms
bing_enhanced <- bind_rows(bing_dict, custom_wsb)

# Calculate different sentiment measures
message("Calculating sentiment scores...")

# 1. Unweighted BING sentiment
sentiment_bing_unweighted <- calculate_sentiment(
  reddit_comments,
  bing_dict,
  weight_by_score = FALSE
) %>%
  rename(sentiment_bing = sentiment_unweighted)

# 2. Enhanced BING with WSB terms
sentiment_bing_enhanced <- calculate_sentiment(
  reddit_comments,
  bing_enhanced,
  weight_by_score = FALSE
) %>%
  rename(sentiment_bing_wsb = sentiment_unweighted)

# 3. Weighted sentiment (if scores available)
if (has_scores) {
  sentiment_weighted <- calculate_sentiment(
    reddit_comments,
    bing_enhanced,
    weight_by_score = TRUE,
    score_transform = "log"
  )
} else {
  sentiment_weighted <- sentiment_bing_enhanced
}

# 4. AFINN sentiment (numeric intensity)
sentiment_afinn <- calculate_sentiment(
  reddit_comments,
  afinn_dict,
  weight_by_score = has_scores,
  score_transform = "log"
) %>%
  rename(sentiment_afinn = ifelse(has_scores, "sentiment_weighted", "sentiment_unweighted"))

# Combine all sentiment measures
sentiment_combined <- sentiment_bing_unweighted %>%
  left_join(sentiment_bing_enhanced, by = "date") %>%
  left_join(sentiment_weighted, by = "date") %>%
  left_join(sentiment_afinn %>% select(date, sentiment_afinn), by = "date")

# Fill missing dates
complete_dates <- seq.Date(
  from = min(sentiment_combined$date),
  to = max(sentiment_combined$date),
  by = "day"
)

sentiment_complete <- tibble(date = complete_dates) %>%
  left_join(sentiment_combined, by = "date") %>%
  arrange(date)

message(sprintf("Sentiment calculated for %d days", nrow(sentiment_complete)))


# MERGE WITH STOCK DATA -------------------------------------------------------

message("\n=== CREATING ANALYSIS DATASET ===\n")

# Create main analysis dataset for GME
gme_analysis <- create_analysis_dataset(
  sentiment_df = sentiment_complete,
  stock_df = event_stocks,
  stock_symbol = "GME",
  add_market_data = TRUE
)

# Remove rows with missing returns (first day)
gme_analysis_clean <- gme_analysis %>%
  filter(!is.na(return), !is.na(sentiment_lag1))

message(sprintf("Analysis dataset: %d observations", nrow(gme_analysis_clean)))


# DESCRIPTIVE STATISTICS ------------------------------------------------------

message("\n=== DESCRIPTIVE STATISTICS ===\n")

# Summary statistics for sentiment
sentiment_summary <- sentiment_complete %>%
  summarize(
    across(
      starts_with("sentiment"),
      list(
        mean = ~mean(.x, na.rm = TRUE),
        sd = ~sd(.x, na.rm = TRUE),
        min = ~min(.x, na.rm = TRUE),
        max = ~max(.x, na.rm = TRUE)
      ),
      .names = "{.col}_{.fn}"
    )
  )

# Summary statistics for returns
return_summary <- gme_analysis_clean %>%
  summarize(
    return_mean = mean(return, na.rm = TRUE),
    return_sd = sd(return, na.rm = TRUE),
    return_min = min(return, na.rm = TRUE),
    return_max = max(return, na.rm = TRUE),
    n_obs = n()
  )

# Correlation matrix
cor_matrix <- gme_analysis_clean %>%
  select(return, starts_with("sentiment"), volume_change, sp500_return) %>%
  cor(use = "pairwise.complete.obs")

print("=== CORRELATION MATRIX ===")
print(round(cor_matrix, 3))


# REGRESSION ANALYSIS ---------------------------------------------------------

message("\n=== REGRESSION ANALYSIS ===\n")

# Model 1: Simple correlation (contemporaneous)
model1 <- lm(return ~ sentiment_weighted, data = gme_analysis_clean)

# Model 2: Lagged sentiment (1 day)
model2 <- lm(return ~ sentiment_lag1, data = gme_analysis_clean)

# Model 3: Multiple lags
model3 <- lm(return ~ sentiment_lag1 + sentiment_lag2, data = gme_analysis_clean)

# Model 4: With control variables
model4 <- lm(return ~ sentiment_lag1 + volume_change + sp500_return,
             data = gme_analysis_clean)

# Model 5: Interaction with post-peak period
gme_analysis_clean <- gme_analysis_clean %>%
  mutate(post_peak = as.numeric(date > as.Date("2021-01-28")))

model5 <- lm(return ~ sentiment_lag1 * post_peak + volume_change + sp500_return,
             data = gme_analysis_clean)

# Robust standard errors (HAC)
model2_robust <- coeftest(model2, vcov = vcovHAC)
model4_robust <- coeftest(model4, vcov = vcovHAC)

print("=== REGRESSION RESULTS (Model 2: Lagged Sentiment) ===")
print(model2_robust)

print("\n=== REGRESSION RESULTS (Model 4: With Controls) ===")
print(model4_robust)

# Create regression table
regression_table <- modelsummary(
  list(
    "Contemporaneous" = model1,
    "1-Day Lag" = model2,
    "Multiple Lags" = model3,
    "With Controls" = model4,
    "Post-Peak Interaction" = model5
  ),
  stars = TRUE,
  gof_map = c("nobs", "r.squared", "adj.r.squared"),
  output = file.path(CONFIG$output_dir, "tables", "regression_results.html")
)


# GRANGER CAUSALITY TEST ------------------------------------------------------

message("\n=== GRANGER CAUSALITY TEST ===\n")

# Test if sentiment Granger-causes returns
granger_test <- grangertest(
  return ~ sentiment_lag1,
  order = 2,
  data = gme_analysis_clean
)

print("=== GRANGER CAUSALITY TEST ===")
print(granger_test)


# DIFFERENCE-IN-DIFFERENCES ESTIMATION ----------------------------------------

message("\n=== DIFFERENCE-IN-DIFFERENCES ANALYSIS ===\n")

# Create DiD dataset
# Treatment: GME (heavily discussed on Reddit)
# Control: Other stocks NOT heavily discussed (use control_stocks)

# Define treatment and post period
did_data <- event_stocks %>%
  mutate(
    treated = as.numeric(symbol == "GME"),
    post = as.numeric(date >= as.Date("2021-01-13")),
    treat_post = treated * post
  ) %>%
  filter(
    symbol %in% c("GME", CONFIG$control_stocks),
    date >= as.Date("2020-12-01"),
    date <= as.Date("2021-02-28")
  )

# DiD regression with fixed effects
did_model <- feols(
  log(adjusted) ~ treat_post | symbol + date,
  data = did_data,
  vcov = "cluster"
)

print("=== DIFFERENCE-IN-DIFFERENCES RESULTS ===")
summary(did_model)

# Alternative: Two-way fixed effects with leads/lags
did_data <- did_data %>%
  group_by(symbol) %>%
  arrange(date) %>%
  mutate(
    days_from_event = as.numeric(date - as.Date("2021-01-13"))
  ) %>%
  ungroup() %>%
  filter(abs(days_from_event) <= 20)  # Event window: +/- 20 days

# Create event study plot data
event_study_model <- feols(
  log(adjusted) ~ i(days_from_event, treated, ref = -1) | symbol + date,
  data = did_data
)


# VISUALIZATIONS --------------------------------------------------------------

message("\n=== CREATING VISUALIZATIONS ===\n")

# Theme setup
theme_set(theme_minimal())

# 1. Sentiment over time
plot_sentiment <- ggplot(sentiment_complete, aes(x = date)) +
  geom_line(aes(y = sentiment_weighted, color = "Weighted"), size = 1.2) +
  geom_line(aes(y = sentiment_bing, color = "Unweighted"), size = 1.2, alpha = 0.6) +
  geom_vline(xintercept = as.Date("2021-01-28"), linetype = "dashed", color = "red") +
  scale_color_manual(values = met.brewer("Veronese", 2)) +
  scale_x_date(date_breaks = "2 days", date_labels = "%b %d") +
  labs(
    title = "Reddit Sentiment Over Time (r/WallStreetBets)",
    subtitle = "Weighted by comment engagement scores",
    x = "Date",
    y = "Net Sentiment Score",
    color = "Sentiment Type"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(
  file.path(CONFIG$output_dir, "figures", "sentiment_over_time.png"),
  plot_sentiment,
  width = 10,
  height = 6,
  dpi = 300
)

# 2. Sentiment vs Returns (scatter with regression line)
plot_scatter <- ggplot(gme_analysis_clean, aes(x = sentiment_lag1, y = return)) +
  geom_point(alpha = 0.6, size = 3) +
  geom_smooth(method = "lm", se = TRUE, color = met.brewer("Veronese", 1)[1]) +
  labs(
    title = "Relationship Between Lagged Sentiment and Returns",
    subtitle = "GameStop (GME) - January 2021",
    x = "Sentiment (t-1)",
    y = "Return (%)"
  )

ggsave(
  file.path(CONFIG$output_dir, "figures", "sentiment_returns_scatter.png"),
  plot_scatter,
  width = 8,
  height = 6,
  dpi = 300
)

# 3. Time series: Sentiment and Returns together
gme_analysis_plot <- gme_analysis_clean %>%
  mutate(
    sentiment_scaled = scale(sentiment_weighted)[,1],
    return_scaled = scale(return)[,1]
  )

plot_timeseries <- ggplot(gme_analysis_plot, aes(x = date)) +
  geom_line(aes(y = sentiment_scaled, color = "Sentiment"), size = 1.2) +
  geom_line(aes(y = return_scaled, color = "Returns"), size = 1.2) +
  geom_vline(xintercept = as.Date("2021-01-28"), linetype = "dashed", alpha = 0.5) +
  scale_color_manual(values = met.brewer("Veronese", 2)) +
  scale_x_date(date_breaks = "2 days", date_labels = "%b %d") +
  labs(
    title = "Sentiment vs. Returns Over Time (Standardized)",
    subtitle = "GameStop (GME) - January 2021",
    x = "Date",
    y = "Standardized Value",
    color = ""
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(
  file.path(CONFIG$output_dir, "figures", "sentiment_returns_timeseries.png"),
  plot_timeseries,
  width = 10,
  height = 6,
  dpi = 300
)

# 4. Regression coefficients plot
coef_data <- broom::tidy(model4, conf.int = TRUE) %>%
  filter(term != "(Intercept)") %>%
  mutate(term = factor(term, levels = c("sentiment_lag1", "volume_change", "sp500_return")))

plot_coef <- ggplot(coef_data, aes(x = term, y = estimate)) +
  geom_point(size = 4) +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high), width = 0.2) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
  coord_flip() +
  labs(
    title = "Regression Coefficients with 95% Confidence Intervals",
    subtitle = "Dependent Variable: Daily Return (%)",
    x = "",
    y = "Coefficient Estimate"
  )

ggsave(
  file.path(CONFIG$output_dir, "figures", "regression_coefficients.png"),
  plot_coef,
  width = 8,
  height = 6,
  dpi = 300
)

# 5. Event study plot (if DiD was successful)
if (exists("event_study_model")) {
  plot_event <- iplot(event_study_model,
                      main = "Event Study: Effect of Reddit Sentiment Surge on GME",
                      xlab = "Days from Event (Jan 13, 2021)",
                      ylab = "Log Price Effect")

  ggsave(
    file.path(CONFIG$output_dir, "figures", "event_study.png"),
    plot_event,
    width = 10,
    height = 6,
    dpi = 300
  )
}


# EXPORT RESULTS --------------------------------------------------------------

message("\n=== EXPORTING RESULTS ===\n")

# Save analysis dataset
write_csv(
  gme_analysis_clean,
  file.path(CONFIG$output_dir, "gme_analysis_dataset.csv")
)

# Save sentiment data
write_csv(
  sentiment_complete,
  file.path(CONFIG$output_dir, "sentiment_data.csv")
)

# Save summary statistics
write_csv(
  sentiment_summary,
  file.path(CONFIG$output_dir, "tables", "sentiment_summary.csv")
)

write_csv(
  as.data.frame(cor_matrix),
  file.path(CONFIG$output_dir, "tables", "correlation_matrix.csv")
)

# Save model results as text
sink(file.path(CONFIG$output_dir, "tables", "model_results.txt"))
cat("=== REGRESSION RESULTS ===\n\n")
cat("Model 2: Lagged Sentiment (Robust SEs)\n")
print(model2_robust)
cat("\n\nModel 4: With Controls (Robust SEs)\n")
print(model4_robust)
cat("\n\n=== GRANGER CAUSALITY TEST ===\n")
print(granger_test)
if (exists("did_model")) {
  cat("\n\n=== DIFFERENCE-IN-DIFFERENCES ===\n")
  print(summary(did_model))
}
sink()

message("\n=== ANALYSIS COMPLETE ===\n")
message(sprintf("Results saved to: %s", CONFIG$output_dir))
message("\nKey findings:")
message(sprintf("  - Correlation (sentiment_lag1 vs. return): %.3f",
                cor(gme_analysis_clean$sentiment_lag1,
                    gme_analysis_clean$return,
                    use = "complete.obs")))
message(sprintf("  - Regression coefficient (sentiment_lag1): %.4f",
                coef(model2)[2]))
message(sprintf("  - P-value: %.4f", summary(model2)$coefficients[2, 4]))

# Final note
cat("\n")
cat("=" , rep("=", 76), "=\n", sep = "")
cat("NEXT STEPS:\n")
cat("1. Review regression results in output/tables/\n")
cat("2. Examine visualizations in output/figures/\n")
cat("3. Check model assumptions (residual plots, normality)\n")
cat("4. Consider robustness checks (different time windows, outlier handling)\n")
cat("5. Validate sentiment coding with manual sample\n")
cat("6. Expand time period if more data available\n")
cat("=" , rep("=", 76), "=\n", sep = "")
