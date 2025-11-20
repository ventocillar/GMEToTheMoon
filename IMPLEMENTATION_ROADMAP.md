# Implementation Roadmap
## Prioritized Action Plan for Thesis Improvements

---

## Quick Start Guide

This document provides a step-by-step implementation plan for improving your thesis. Follow the phases in order, starting with the highest-impact improvements.

---

## Phase 1: Foundation (Week 1-2) 🔴 HIGH PRIORITY

### 1.1 Refine Research Question

**Current Status:** Implicit question about relationship between sentiment and prices

**Action:**
- [ ] Choose ONE specific research question from the recommendations
- [ ] Write it down clearly in your introduction
- [ ] Share with advisor for feedback

**Recommended Choice:**
> "Did positive sentiment shocks on r/WallStreetBets causally influence abnormal returns for GameStop during the January 2021 short squeeze, and through what mechanisms?"

**Time Estimate:** 2 hours

---

### 1.2 Implement Score-Weighted Sentiment

**Why:** All comments are currently treated equally. High-upvote comments likely have more influence.

**Action:**
```r
# In your current script, ADD this section after line 232:

# Calculate weighted sentiment
weighted_sentiment <- my_gamestop_scores %>%
  unnest_tokens(word, text) %>%
  anti_join(stop_words) %>%
  inner_join(get_sentiments("bing")) %>%
  mutate(
    sentiment_value = ifelse(sentiment == "positive", 1, -1),
    # Log transform reduces outlier influence
    weighted_score = sentiment_value * log(scores + 1)
  ) %>%
  group_by(date) %>%
  summarize(
    # Raw sentiment
    net_sentiment = sum(sentiment_value),
    # Weighted sentiment
    weighted_sentiment = sum(weighted_score),
    # Stats
    avg_score = mean(scores),
    n_comments = n()
  )

# Compare the two
plot_comparison <- weighted_sentiment %>%
  ggplot(aes(x = date)) +
  geom_line(aes(y = net_sentiment, color = "Unweighted"), size = 1.2) +
  geom_line(aes(y = weighted_sentiment, color = "Weighted"), size = 1.2) +
  labs(title = "Weighted vs. Unweighted Sentiment") +
  theme_minimal()

plot_comparison
```

**Expected Outcome:**
- Two sentiment time series to compare
- Foundation for regression analysis
- Better capture of influential comments

**Time Estimate:** 3-4 hours

**Files to Modify:** `thesis.AlmeidaFranco.R` (after line 232)

---

### 1.3 Basic Regression Analysis

**Why:** Currently only descriptive. Need to test statistical relationships.

**Action:**
```r
# Merge sentiment with stock returns
library(tidyquant)

# Get GME prices
gme_prices <- tq_get("GME",
                     get = "stock.prices",
                     from = "2021-01-13",
                     to = "2021-01-31")

# Calculate returns
gme_returns <- gme_prices %>%
  arrange(date) %>%
  mutate(
    return = (adjusted - lag(adjusted)) / lag(adjusted) * 100,
    return_lag1 = lag(return, 1)
  )

# Merge with sentiment
analysis_data <- gme_returns %>%
  left_join(weighted_sentiment, by = "date") %>%
  mutate(
    sentiment_lag1 = lag(weighted_sentiment, 1),
    sentiment_lag2 = lag(weighted_sentiment, 2)
  )

# Run regressions
library(lmtest)
library(sandwich)

# Model 1: Contemporaneous
model1 <- lm(return ~ weighted_sentiment, data = analysis_data)

# Model 2: Lagged (does yesterday's sentiment predict today's return?)
model2 <- lm(return ~ sentiment_lag1, data = analysis_data)

# Model 3: Multiple lags
model3 <- lm(return ~ sentiment_lag1 + sentiment_lag2, data = analysis_data)

# Get robust standard errors
summary(model2)
coeftest(model2, vcov = vcovHAC)

# Test correlation
cor.test(analysis_data$sentiment_lag1, analysis_data$return)

# Visualize
ggplot(analysis_data, aes(x = sentiment_lag1, y = return)) +
  geom_point(size = 3, alpha = 0.6) +
  geom_smooth(method = "lm", se = TRUE) +
  labs(
    title = "Lagged Sentiment vs. Returns",
    x = "Sentiment (previous day)",
    y = "Return (%)"
  ) +
  theme_minimal()
```

**Expected Outcome:**
- Regression coefficients with statistical significance
- Answer: "Does sentiment predict returns?"
- Scatterplot with regression line

**Time Estimate:** 4-5 hours

**Key Question to Answer:** Is the coefficient on `sentiment_lag1` statistically significant?

---

### 1.4 Refactor Repetitive Code

**Why:** Lines 61-110 repeat the same operation 17 times. Hard to maintain and error-prone.

**Action:**
```r
# REPLACE lines 40-119 with:

# Define function
read_comments <- function(date_str, data_dir = ".") {
  file_path <- paste0(data_dir, "/comments_", date_str, "_Jan.xlsx")

  if (!file.exists(file_path)) {
    warning(paste("File not found:", file_path))
    return(NULL)
  }

  read_excel(file_path) %>%
    select(body, date) %>%
    mutate(date = as.Date(date))
}

# Use the function
dates <- c("13", "14", "15", "16", "17", "18", "19", "20",
           "21", "22", "23", "24", "27", "28", "29", "30", "31")

# Read all files at once
my_gamestop <- dates %>%
  map(read_comments) %>%
  compact() %>%  # Remove NULLs
  bind_rows()

# Verify
nrow(my_gamestop)  # Should match your original
```

**Expected Outcome:**
- Same result, cleaner code
- Easier to add new dates
- Reduced from ~70 lines to ~20 lines

**Time Estimate:** 1-2 hours

---

## Phase 2: Statistical Rigor (Week 3-4) 🟡 MEDIUM PRIORITY

### 2.1 Add Control Variables

**Action:**
```r
# Add market return (S&P 500) and volume
sp500 <- tq_get("^GSPC",
                from = "2021-01-13",
                to = "2021-01-31") %>%
  mutate(sp500_return = (adjusted - lag(adjusted)) / lag(adjusted) * 100) %>%
  select(date, sp500_return)

# Add volume change
analysis_data <- analysis_data %>%
  mutate(volume_change = (volume - lag(volume)) / lag(volume) * 100)

# Merge
analysis_data <- analysis_data %>%
  left_join(sp500, by = "date")

# Regression with controls
model4 <- lm(return ~ sentiment_lag1 + volume_change + sp500_return,
             data = analysis_data)

summary(model4)
coeftest(model4, vcov = vcovHAC)
```

**Expected Outcome:**
- Control for market-wide movements
- Control for trading volume effects
- Isolate Reddit sentiment effect

**Time Estimate:** 2-3 hours

---

### 2.2 Granger Causality Test

**Why:** Tests if sentiment "causes" returns in statistical sense

**Action:**
```r
library(lmtest)

# Test if sentiment Granger-causes returns
# (Does past sentiment help predict current returns?)
granger_test <- grangertest(
  return ~ sentiment_lag1,
  order = 2,
  data = analysis_data
)

print(granger_test)

# Interpretation:
# If p-value < 0.05: sentiment helps predict returns
# If p-value > 0.05: no evidence of Granger causality
```

**Expected Outcome:**
- Statistical test of predictive relationship
- Support (or not) for causal claim

**Time Estimate:** 1 hour

---

### 2.3 Robustness Checks

**Why:** Ensure results aren't artifacts of specific choices

**Action:**
```r
# 1. Different time windows
pre_peak <- analysis_data %>% filter(date < as.Date("2021-01-28"))
post_peak <- analysis_data %>% filter(date >= as.Date("2021-01-28"))

model_pre <- lm(return ~ sentiment_lag1, data = pre_peak)
model_post <- lm(return ~ sentiment_lag1, data = post_peak)

# Compare coefficients
coef(model_pre)[2]
coef(model_post)[2]

# 2. Alternative sentiment measure (AFINN instead of BING)
afinn_sentiment <- antimy_gamestop %>%
  inner_join(get_sentiments("afinn")) %>%
  group_by(date) %>%
  summarize(sentiment_afinn = sum(value))

# Re-run regressions with AFINN
# ...

# 3. Winsorize outliers
library(DescTools)
analysis_data <- analysis_data %>%
  mutate(return_wins = Winsorize(return, probs = c(0.01, 0.99)))

model_robust <- lm(return_wins ~ sentiment_lag1, data = analysis_data)
```

**Expected Outcome:**
- Evidence that results are stable across specifications
- Identify if results are driven by outliers or specific periods

**Time Estimate:** 3-4 hours

---

## Phase 3: Causal Inference (Week 5-6) 🟢 ADVANCED

### 3.1 Expand Data Collection

**Why:** 19 days is too short. Need baseline period.

**Action:**
- [ ] Collect Reddit data for December 2020 (pre-event baseline)
- [ ] Collect Reddit data through February 2021 (post-event)
- [ ] Aim for 3-month window minimum

**Tools:**
- Pushshift API: https://github.com/pushshift/api
- RedditExtractoR package (if still maintained)
- PRAW (Python Reddit API Wrapper)

**Expected Outcome:**
- ~90 days of data instead of 19
- Better statistical power
- Can test pre-trends

**Time Estimate:** 1-2 days (depends on API familiarity)

---

### 3.2 Identify Control Stocks

**Why:** Need comparison group for DiD analysis

**Action:**
- [ ] Find 3-5 stocks with similar characteristics to GME:
  - Similar market cap (before Jan 2021)
  - Similar industry (retail/gaming)
  - Similar volatility
  - **NOT heavily discussed on r/WallStreetBets**

**Candidates:**
- Other retail stocks: EXPR, ANF, GPS, JWN
- Similar market cap stocks not on Reddit
- Check Reddit mention frequency to confirm they're NOT treated

**Verification:**
```r
# Count mentions of each stock on Reddit
# Ensure control stocks have <10% of GME mention volume
```

**Expected Outcome:**
- Valid control group for causal analysis

**Time Estimate:** 3-4 hours (research + verification)

---

### 3.3 Implement Difference-in-Differences

**Why:** Gold standard for causal inference in this setting

**Action:**
```r
library(fixest)

# Create panel dataset
did_data <- stock_prices %>%
  filter(symbol %in% c("GME", "KODK", "EXPR", "NAKD")) %>%  # Example controls
  mutate(
    treated = as.numeric(symbol == "GME"),
    post = as.numeric(date >= as.Date("2021-01-13")),
    treat_post = treated * post
  )

# DiD regression with two-way fixed effects
did_model <- feols(
  log(adjusted) ~ treat_post | symbol + date,
  data = did_data,
  vcov = "cluster"
)

summary(did_model)

# Coefficient on treat_post is the causal effect
```

**Expected Outcome:**
- Causal estimate of Reddit sentiment effect
- Publishable methodology
- Strong thesis contribution

**Time Estimate:** 4-6 hours (after controls identified)

---

### 3.4 Event Study

**Why:** Visual representation of treatment effect over time

**Action:**
```r
# Create leads and lags around treatment date
did_data <- did_data %>%
  mutate(
    days_from_event = as.numeric(date - as.Date("2021-01-13"))
  ) %>%
  filter(abs(days_from_event) <= 30)  # +/- 30 day window

# Event study specification
event_model <- feols(
  log(adjusted) ~ i(days_from_event, treated, ref = -1) | symbol + date,
  data = did_data
)

# Plot
iplot(event_model,
      main = "Event Study: Effect of Reddit Sentiment on GME",
      xlab = "Days from Event",
      ylab = "Log Price Effect")
```

**Expected Outcome:**
- Plot showing pre-trends (should be flat)
- Jump at treatment (if effect exists)
- Visual proof of causal effect

**Time Estimate:** 2-3 hours

---

## Phase 4: Domain-Specific Improvements (Week 7-8) 🔵 NICE TO HAVE

### 4.1 Financial Sentiment Lexicon

**Why:** BING/NRC built for general text, not finance

**Action:**
1. Download Loughran-McDonald dictionary:
   - https://sraf.nd.edu/loughranmcdonald-master-dictionary/

2. Create custom WSB lexicon:
```r
wsb_positive <- c("moon", "rocket", "tendies", "gains", "bullish",
                  "diamond", "hold", "hodl", "calls", "squeeze", "yolo")

wsb_negative <- c("bears", "puts", "crash", "sell", "short",
                  "loss", "bag", "rip", "ded")

custom_wsb <- tibble(
  word = c(wsb_positive, wsb_negative),
  sentiment = c(rep("positive", length(wsb_positive)),
                rep("negative", length(wsb_negative)))
)

# Combine with BING
enhanced_bing <- bind_rows(get_sentiments("bing"), custom_wsb)
```

3. Re-run all analyses with enhanced dictionary

**Expected Outcome:**
- More accurate sentiment for financial context
- Capture WSB-specific jargon

**Time Estimate:** 3-4 hours

---

### 4.2 Validate Sentiment Accuracy

**Why:** Are the dictionaries actually correct for this context?

**Action:**
1. Randomly sample 200 comments:
```r
set.seed(123)
validation_sample <- my_gamestop %>%
  sample_n(200)

write_csv(validation_sample, "validation_sample.csv")
```

2. Manually code each as positive/negative/neutral
3. Compare to algorithm:
```r
# Calculate algorithm sentiment for each comment
algo_sentiment <- validation_sample %>%
  unnest_tokens(word, text) %>%
  inner_join(get_sentiments("bing")) %>%
  group_by(row_id) %>%
  summarize(
    algo_score = sum(ifelse(sentiment == "positive", 1, -1)),
    algo_sentiment = case_when(
      algo_score > 0 ~ "positive",
      algo_score < 0 ~ "negative",
      TRUE ~ "neutral"
    )
  )

# Merge with manual coding
validation <- validation_sample %>%
  left_join(algo_sentiment)

# Calculate accuracy
mean(validation$manual_sentiment == validation$algo_sentiment)

# Confusion matrix
table(validation$manual_sentiment, validation$algo_sentiment)

# Cohen's Kappa
library(irr)
kappa2(validation[, c("manual_sentiment", "algo_sentiment")])
```

**Expected Outcome:**
- Accuracy metric (aim for >70%)
- Identify systematic errors
- Strengthen methodology section

**Time Estimate:** 4-6 hours (mostly manual coding)

---

## Phase 5: Polish & Presentation (Week 9-10) 🎨

### 5.1 Create Publication-Quality Tables

**Action:**
```r
library(modelsummary)
library(kableExtra)

# Regression table
modelsummary(
  list(
    "Baseline" = model1,
    "Lagged" = model2,
    "Controls" = model4
  ),
  stars = TRUE,
  coef_rename = c(
    "sentiment_lag1" = "Sentiment (t-1)",
    "volume_change" = "Volume Change (%)",
    "sp500_return" = "Market Return (%)"
  ),
  gof_map = c("nobs", "r.squared", "adj.r.squared"),
  output = "regression_table.html"
)

# Summary statistics table
summary_stats <- analysis_data %>%
  select(return, weighted_sentiment, volume, sp500_return) %>%
  datasummary_skim()
```

**Expected Outcome:**
- Professional tables for thesis
- Easy to read and interpret

**Time Estimate:** 2-3 hours

---

### 5.2 Enhanced Visualizations

**Action:**
Create these key plots:

1. **Sentiment vs. Returns Over Time**
2. **Scatterplot with Regression Line**
3. **Event Study Plot** (if DiD implemented)
4. **Comparison of Sentiment Measures**
5. **Robustness Check Results**

See `enhanced_analysis.R` lines 500-600 for examples.

**Expected Outcome:**
- Publication-ready figures
- Clear visual story

**Time Estimate:** 3-4 hours

---

### 5.3 Write Results Section

**Structure:**

```markdown
## Results

### Descriptive Statistics
- [Table 1: Summary statistics]
- [Figure 1: Sentiment over time]
- [Figure 2: Returns over time]

### Main Results
- [Table 2: Regression results]
- [Figure 3: Scatterplot]
- Key finding: "A one-unit increase in lagged sentiment is associated
  with a X.XX percentage point increase in returns (p < 0.05)"

### Causal Analysis
- [Table 3: DiD results]
- [Figure 4: Event study]
- Key finding: "The Reddit sentiment surge caused an X% abnormal
  return for GME relative to control stocks"

### Robustness Checks
- [Table 4: Alternative specifications]
- Results are robust to...
```

**Time Estimate:** 1 week (writing + revisions)

---

## Quick Reference: File Structure

```
GMEToTheMoon/
├── data/
│   ├── comments_13_Jan.xlsx
│   ├── comments_14_Jan.xlsx
│   └── ... (other data files)
├── output/
│   ├── figures/
│   │   ├── sentiment_over_time.png
│   │   ├── sentiment_returns_scatter.png
│   │   └── event_study.png
│   └── tables/
│       ├── regression_results.html
│       └── summary_statistics.csv
├── thesis.AlmeidaFranco.R  (original)
├── enhanced_analysis.R  (new, improved)
├── THESIS_REVIEW_AND_RECOMMENDATIONS.md  (feedback)
└── IMPLEMENTATION_ROADMAP.md  (this file)
```

---

## Priority Matrix

| Task | Impact | Effort | Priority |
|------|--------|--------|----------|
| Score-weighted sentiment | HIGH | LOW | **DO FIRST** |
| Basic regression | HIGH | MEDIUM | **DO FIRST** |
| Refactor code | MEDIUM | LOW | **DO FIRST** |
| Refine research question | HIGH | LOW | **DO FIRST** |
| Granger causality | HIGH | LOW | DO SECOND |
| Control variables | HIGH | LOW | DO SECOND |
| Robustness checks | MEDIUM | MEDIUM | DO SECOND |
| Expand data collection | HIGH | HIGH | DO THIRD |
| Difference-in-Differences | VERY HIGH | HIGH | DO THIRD |
| Event study | HIGH | MEDIUM | DO THIRD |
| Financial lexicon | MEDIUM | MEDIUM | DO FOURTH |
| Validate sentiment | MEDIUM | HIGH | DO FOURTH |

---

## Checkpoints for Advisor Meetings

### Meeting 1 (After Phase 1):
- Show weighted vs. unweighted sentiment plots
- Present regression results (model 2)
- Discuss: "Is the effect size meaningful?"

### Meeting 2 (After Phase 2):
- Show robustness checks
- Present Granger causality test
- Discuss: "What control variables should we add?"

### Meeting 3 (After Phase 3):
- Present DiD results
- Show event study plot
- Discuss: "Does this establish causality?"

### Meeting 4 (After Phase 5):
- Show draft results section
- Review all tables and figures
- Discuss: "What's the main contribution?"

---

## Common Pitfalls to Avoid

1. **Don't skip Phase 1** - Foundation is critical
2. **Don't over-interpret** - Be careful with causal language without DiD
3. **Don't ignore assumptions** - Check regression assumptions
4. **Don't forget limitations** - Be honest about what you can/can't claim
5. **Don't wait to write** - Start writing results as you go

---

## Resources

### R Packages to Install
```r
install.packages(c(
  "tidyverse", "lubridate", "here",
  "tidytext", "quanteda",
  "tidyquant", "zoo",
  "lmtest", "sandwich", "fixest",
  "modelsummary", "kableExtra",
  "DescTools"
))
```

### Key References
- Angrist & Pischke (2009) - "Mostly Harmless Econometrics"
- Stock & Watson (2015) - "Introduction to Econometrics"
- Loughran & McDonald (2011) - Financial sentiment paper
- Pedersen (2022) - GameStop case study

### Online Resources
- DiD tutorial: https://diff.healthpolicydatascience.org/
- fixest package: https://lrberge.github.io/fixest/
- modelsummary: https://modelsummary.com/

---

## FAQ

**Q: Do I really need to implement DiD?**
A: For a thesis, yes. It's the difference between "there's a correlation" and "Reddit caused price movements." The latter is much stronger.

**Q: What if I can't get more data?**
A: Use what you have but:
1. Be clear about limitations in your discussion
2. Focus on the period you have (can still use DiD with short pre-period)
3. Suggest longer time series for future research

**Q: Can I use the enhanced_analysis.R file directly?**
A: Yes! It's designed to replace your current script. You'll need to:
1. Adjust file paths
2. Make sure data files exist
3. Run it section by section

**Q: How long will this all take?**
A: Realistically:
- Phase 1: 2 weeks (part-time)
- Phase 2: 2 weeks
- Phase 3: 2-3 weeks (includes data collection)
- Phase 4: 1-2 weeks
- Phase 5: 2 weeks (mostly writing)

**Total: 9-11 weeks** if working part-time

**Q: Can I skip some phases?**
A: Minimum for a solid thesis:
- Phase 1: ALL (required)
- Phase 2: At least 2.1 and 2.2
- Phase 3: At least 3.2 and 3.3 (DiD)
- Phase 4: Optional but recommended
- Phase 5: ALL (required)

---

## Final Checklist

Before submitting your thesis, ensure:

- [ ] Research question is clear and specific
- [ ] Sentiment is weighted by engagement scores
- [ ] Regression analysis with lagged sentiment
- [ ] Control variables included
- [ ] Statistical significance reported
- [ ] Difference-in-Differences implemented
- [ ] Robustness checks performed
- [ ] All plots are high-resolution (300 dpi)
- [ ] Tables are formatted professionally
- [ ] Code is clean and documented
- [ ] Limitations section is thorough
- [ ] Results are interpreted, not just reported
- [ ] Advisor has reviewed everything

---

**Good luck with your thesis! You have a great foundation and with these improvements, it will be excellent.**

For questions or clarifications, refer to:
- `THESIS_REVIEW_AND_RECOMMENDATIONS.md` for detailed methodology
- `enhanced_analysis.R` for implementation examples
