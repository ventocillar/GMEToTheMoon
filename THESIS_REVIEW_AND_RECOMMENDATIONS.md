# Comprehensive Thesis Review and Recommendations
## GME/WallStreetBets Sentiment Analysis Study

---

## EXECUTIVE SUMMARY

Your thesis investigates the relationship between Reddit sentiment (r/WallStreetBets) and stock price movements during the January 2021 GameStop short squeeze event. The work provides interesting visualizations and descriptive sentiment analysis. However, the study would benefit significantly from:

1. **Stronger causal inference methodology** (Difference-in-Differences, event study, regression analysis)
2. **More robust data handling** (weighting by comment scores, expanded time period)
3. **Statistical validation** (hypothesis testing, correlation analysis, predictive modeling)
4. **Enhanced sentiment analysis** (financial-specific lexicons, contextual validation)

---

## I. OVERVIEW OF CURRENT THESIS

### Research Question (Inferred)
**"What is the relationship between Reddit sentiment and stock price movements during the GameStop short squeeze of January 2021?"**

### Current Methodology
1. **Data Collection:**
   - Reddit comments from January 13-31, 2021 (19 days)
   - Stock prices for GME and 6 other "meme stocks" (DDS, BBBY, FIZZ, NOK, BB, AMC)
   - Historical stock data from January 2020 to May 2021
   - Comment scores (upvotes) for a subset of comments

2. **Sentiment Analysis:**
   - Text preprocessing: tokenization, stopword removal
   - Dictionary-based sentiment using NRC lexicon (10 emotions) and BING lexicon (positive/negative)
   - Time-series aggregation of sentiment by date
   - Percentage-based sentiment metrics

3. **Visualization:**
   - Stock price trends over time
   - Sentiment composition over time
   - Word frequency analysis by sentiment category
   - Comparative analysis of meme stocks

### Strengths
- **Timely and relevant topic** with significant market and social implications
- **Multiple sentiment lexicons** (NRC, BING) for triangulation
- **Good data visualization** showing temporal patterns
- **Includes multiple stocks** for comparative context
- **Long historical baseline** (2020-2021) for stock prices

### Major Limitations
- **No causal inference framework** - correlation vs. causation not addressed
- **No statistical testing** - descriptive only, no hypothesis testing
- **Short analysis period** - only 19 days of Reddit data
- **No control group** - cannot isolate Reddit effect from other factors
- **Generic sentiment lexicons** - not tailored to financial/trading context
- **No weighting by engagement** - all comments treated equally
- **Missing validation** - sentiment accuracy not verified
- **No predictive analysis** - relationship directionality unclear
- **Code quality issues** - repetitive, hardcoded, not reproducible

---

## II. DETAILED FEEDBACK BY CATEGORY

### A. Research Question

**Current (Inferred):** "What is the relationship between Reddit sentiment and stock price movements during the GME short squeeze?"

**RECOMMENDATION: Refine and Sharpen**

**Improved Research Questions (Choose One):**

1. **Causal Question:**
   *"Did increases in positive sentiment on r/WallStreetBets causally impact GameStop stock prices during January 2021, and if so, with what lag structure?"*

2. **Predictive Question:**
   *"To what extent can Reddit sentiment metrics predict next-day stock returns for GameStop during periods of high retail trading activity?"*

3. **Comparative Question:**
   *"How did the sentiment-price relationship differ between GameStop and control stocks during the January 2021 short squeeze event?"*

4. **Mechanism Question:**
   *"Do high-engagement Reddit comments (upvoted posts) have a stronger association with stock price movements than low-engagement comments?"*

**Why This Matters:**
- Sharper questions enable clearer methodology
- Guides statistical approach and model selection
- Makes contribution to literature more explicit
- Easier to defend specific claims

---

### B. Methodology - Major Enhancements Needed

#### 1. **IMPLEMENT DIFFERENCE-IN-DIFFERENCES (DiD) DESIGN**

**What is DiD?**
Difference-in-Differences compares the change in outcomes over time between a treatment group (GME) and a control group (similar stocks not featured on r/WallStreetBets).

**How to Implement:**

```r
# Create treatment indicator
stock_data$treated <- ifelse(stock_data$symbol == "GME", 1, 0)

# Define post-period (when GME sentiment surged)
stock_data$post <- ifelse(stock_data$date >= as.Date("2021-01-13"), 1, 0)

# DiD regression
library(fixest)
did_model <- feols(log(close) ~ treated * post | symbol + date,
                   data = stock_data,
                   vcov = "cluster")
summary(did_model)
```

**What You Need:**
- **Control stocks:** Stocks with similar characteristics (market cap, volatility, sector) but NOT heavily discussed on Reddit
- **Pre-treatment period:** Need Reddit data from December 2020 (at minimum) to establish baseline
- **Parallel trends assumption:** Verify GME and control stocks had similar trends before January 13

**Benefits:**
- Establishes causal effect, not just correlation
- Controls for time-invariant confounders
- Standard approach in economics/finance for policy evaluation
- Publishable in peer-reviewed journals

---

#### 2. **ADD WEIGHTED SENTIMENT BY COMMENT SCORE**

**Current Problem:**
You have comment scores but don't use them. A comment with 10,000 upvotes likely has more influence than one with 2 upvotes.

**Solution: Score-Weighted Sentiment**

```r
# Calculate weighted sentiment
weighted_sentiment <- my_gamestop_scores %>%
  unnest_tokens(word, text) %>%
  anti_join(stop_words) %>%
  inner_join(get_sentiments("bing")) %>%
  mutate(
    # Convert sentiment to numeric (-1 for negative, +1 for positive)
    sentiment_value = ifelse(sentiment == "positive", 1, -1),
    # Weight by log(score + 1) to reduce outlier influence
    weighted_score = sentiment_value * log(scores + 1)
  ) %>%
  group_by(date) %>%
  summarize(
    # Raw sentiment
    net_sentiment = sum(sentiment_value),
    # Weighted sentiment
    weighted_sentiment = sum(weighted_score),
    # Average comment score for that day
    avg_score = mean(scores),
    # Number of comments
    n_comments = n()
  )

# Compare weighted vs. unweighted
cor.test(weighted_sentiment$weighted_sentiment, stock_returns$return)
cor.test(weighted_sentiment$net_sentiment, stock_returns$return)
```

**Advanced: Confidence/Influence Score**

```r
# Create influence metric combining score and sentiment intensity
high_influence_comments <- my_gamestop_scores %>%
  filter(scores > quantile(scores, 0.75)) %>%  # Top 25% upvoted
  unnest_tokens(word, text) %>%
  anti_join(stop_words) %>%
  inner_join(get_sentiments("afinn")) %>%  # AFINN has intensity (-5 to +5)
  group_by(date) %>%
  summarize(
    # High-confidence sentiment (high engagement + strong sentiment)
    confidence_score = sum(abs(value) * log(scores + 1)),
    # Directional sentiment
    directional_sentiment = sum(value * log(scores + 1))
  )
```

**Why This Matters:**
- Viral comments drive more trading activity
- Accounts for Reddit's hierarchical engagement structure
- More realistic model of information diffusion
- Can test hypothesis: "High-engagement comments predict returns better"

---

#### 3. **REGRESSION ANALYSIS WITH LAG STRUCTURE**

**Current Gap:**
You show sentiment and prices together but don't test if sentiment predicts future prices.

**Solution: Time-Series Regression with Lags**

```r
library(dynlm)
library(lmtest)

# Prepare data
regression_data <- stock_data %>%
  filter(symbol == "GME") %>%
  left_join(weighted_sentiment, by = "date") %>%
  arrange(date) %>%
  mutate(
    # Calculate returns
    return = (close - lag(close)) / lag(close) * 100,
    # Lag sentiment by 1 day
    sentiment_lag1 = lag(weighted_sentiment, 1),
    # Lag sentiment by 2 days
    sentiment_lag2 = lag(weighted_sentiment, 2),
    # Control variables
    volume_change = (volume - lag(volume)) / lag(volume),
    sp500_return = # add S&P 500 return for market control
  )

# Regression models
model1 <- lm(return ~ weighted_sentiment, data = regression_data)
model2 <- lm(return ~ sentiment_lag1, data = regression_data)
model3 <- lm(return ~ sentiment_lag1 + sentiment_lag2 + volume_change + sp500_return,
             data = regression_data)

# Check results
summary(model2)
coeftest(model2, vcov = vcovHAC)  # Heteroskedasticity-robust SEs

# Granger causality test
library(lmtest)
grangertest(return ~ weighted_sentiment, order = 2, data = regression_data)
```

**Interpretation:**
- If `sentiment_lag1` is significant and positive → sentiment predicts next-day returns
- If current `weighted_sentiment` is significant → contemporaneous relationship
- Granger test tells you if sentiment "causes" returns in statistical sense

---

#### 4. **EVENT STUDY METHODOLOGY**

**What is it?**
Examines abnormal returns around specific sentiment events (e.g., highly viral posts).

**Implementation:**

```r
# Identify major sentiment events
major_events <- weighted_sentiment %>%
  filter(weighted_sentiment > quantile(weighted_sentiment, 0.90)) %>%
  pull(date)

# Calculate abnormal returns
stock_data <- stock_data %>%
  group_by(symbol) %>%
  arrange(date) %>%
  mutate(
    # Expected return (market model)
    expected_return = alpha + beta * sp500_return,
    # Abnormal return
    abnormal_return = return - expected_return
  )

# Event window: [-1, +3] days around event
event_study_data <- map_df(major_events, function(event_date) {
  stock_data %>%
    filter(
      symbol == "GME",
      date >= event_date - days(1),
      date <= event_date + days(3)
    ) %>%
    mutate(
      event_date = event_date,
      event_time = as.numeric(date - event_date)
    )
})

# Plot cumulative abnormal returns
ggplot(event_study_data, aes(x = event_time, y = cumsum(abnormal_return))) +
  geom_line() +
  geom_vline(xintercept = 0, linetype = "dashed") +
  labs(title = "Cumulative Abnormal Returns Around High-Sentiment Events",
       x = "Days from Event",
       y = "Cumulative Abnormal Return (%)")
```

---

#### 5. **FINANCIAL-SPECIFIC SENTIMENT ANALYSIS**

**Current Problem:**
NRC and BING lexicons were built for general text, not financial/trading contexts.

**Issues:**
- "bull" / "bear" have specific financial meanings
- "moon" / "rocket" / "diamond hands" are WSB-specific jargon
- "short" could be sentiment or trading strategy

**Solutions:**

**A. Loughran-McDonald Financial Sentiment Dictionary**

```r
# Install financial sentiment lexicon
# Download from: https://sraf.nd.edu/loughranmcdonald-master-dictionary/

lm_sentiment <- read_csv("LoughranMcDonald_SentimentWordLists.csv")

# Use instead of BING
financial_sentiment <- antimy_gamestop %>%
  inner_join(lm_sentiment, by = "word") %>%
  group_by(date, sentiment) %>%
  summarize(n = n())
```

**B. Create Custom WSB Lexicon**

```r
# Add WSB-specific terms
wsb_positive <- c("moon", "rocket", "tendies", "gainz", "calls",
                  "bullish", "diamond", "hold", "buy", "long")
wsb_negative <- c("bears", "puts", "crash", "sell", "short",
                  "loss", "bag", "rip")

custom_wsb <- data.frame(
  word = c(wsb_positive, wsb_negative),
  sentiment = c(rep("positive", length(wsb_positive)),
                rep("negative", length(wsb_negative))),
  lexicon = "wsb"
)

# Combine with existing lexicons
enhanced_bing <- bind_rows(get_sentiments("bing"), custom_wsb)
```

**C. Validate Sentiment Coding**

```r
# Manually code a random sample of 200 comments
set.seed(123)
validation_sample <- my_gamestop %>%
  sample_n(200)

# You code each comment as positive/negative/neutral
# Then compare to algorithm classification
# Calculate accuracy, precision, recall

# Cohen's Kappa for inter-rater reliability
library(irr)
kappa2(cbind(manual_coding, algorithm_coding))
```

---

#### 6. **ROBUSTNESS CHECKS**

**What are they?**
Tests to ensure your results aren't artifacts of specific choices.

**Essential Checks:**

```r
# 1. Alternative sentiment measures
sentiment_comparison <- data.frame(
  date = dates,
  nrc_sentiment = nrc_scores,
  bing_sentiment = bing_scores,
  lm_sentiment = loughran_mcdonald_scores,
  afinn_sentiment = afinn_scores
)

# Correlation matrix
cor(sentiment_comparison[,-1], use = "complete.obs")

# 2. Different time windows
model_full <- lm(return ~ sentiment_lag1, data = regression_data)
model_pre_peak <- lm(return ~ sentiment_lag1,
                     data = filter(regression_data, date < "2021-01-28"))
model_post_peak <- lm(return ~ sentiment_lag1,
                      data = filter(regression_data, date >= "2021-01-28"))

# 3. Winsorization (handle outliers)
regression_data <- regression_data %>%
  mutate(
    return_winsorized = DescTools::Winsorize(return, probs = c(0.01, 0.99))
  )

# 4. Alternative stock metrics
# Use adjusted close, log returns, volatility
model_alt1 <- lm(log(adjusted / lag(adjusted)) ~ sentiment_lag1, data = ...)
model_alt2 <- lm(realized_volatility ~ sentiment_lag1, data = ...)
```

---

#### 7. **EXPAND TIME PERIOD**

**Current:** January 13-31, 2021 (19 days)

**Recommended:**
- **Minimum:** December 1, 2020 - February 28, 2021 (3 months)
- **Better:** October 1, 2020 - June 30, 2021 (9 months)

**Why:**
- Establishes pre-event baseline
- Captures aftermath/unwinding
- More statistical power
- Can identify anticipatory effects
- Shows if relationship persists or was event-specific

**How to Get Data:**
```r
# Use RedditExtractoR or PRAW (Python) or Pushshift API
library(RedditExtractoR)

# Historical comments (if available)
wsb_historical <- find_thread_urls(
  subreddit = "wallstreetbets",
  keywords = "GME",
  period = "month"  # Or use date range
)

# Or use Pushshift API wrapper
library(RedditExtractoR)
# Access historical data up to 2 years back
```

---

### C. Data Quality and Handling

#### Issues Identified:

1. **Missing data handling not discussed**
   - What if a day has no comments? No trading (weekend)?
   - How do you handle [deleted] or [removed] comments?

2. **No data validation**
   - Are all comments actually about GME?
   - Could include mentions of other stocks

3. **No discussion of sampling**
   - Did you scrape all comments or a sample?
   - How were comments selected?

#### Recommendations:

```r
# 1. Filter for GME-specific comments
gme_specific <- my_gamestop %>%
  filter(
    str_detect(text, regex("\\bGME\\b|GameStop|Gamestop", ignore_case = TRUE))
  )

# 2. Handle missing days
complete_dates <- seq.Date(
  from = min(sentiment_data$date),
  to = max(sentiment_data$date),
  by = "day"
)

sentiment_data_complete <- data.frame(date = complete_dates) %>%
  left_join(sentiment_data, by = "date") %>%
  mutate(
    # Fill missing with 0 or previous day's value
    sentiment = ifelse(is.na(sentiment), 0, sentiment)
  )

# 3. Data quality checks
data_summary <- my_gamestop %>%
  group_by(date) %>%
  summarize(
    n_comments = n(),
    n_deleted = sum(text %in% c("[deleted]", "[removed]")),
    avg_length = mean(nchar(text)),
    pct_deleted = n_deleted / n_comments * 100
  )

# Flag dates with unusual patterns
data_summary %>%
  filter(pct_deleted > 50 | n_comments < 10)
```

---

### D. Code Quality

#### Major Issues:

1. **Repetitive code** (lines 61-110)
2. **Hardcoded file paths** (line 2, 40-58)
3. **No functions** for repeated operations
4. **Missing error handling**
5. **No reproducibility** (file paths won't work for reviewers)
6. **Incomplete sections** (line 284, 303)

#### Refactored Example:

```r
# BEFORE (repetitive)
my_gamestop_13jan <- read_excel("comments_13_Jan.xlsx") %>% select(body, date)
my_gamestop_14jan <- read_excel("comments_14_Jan.xlsx") %>% select(body, date)
# ... repeated 17 times

# AFTER (functional)
read_and_clean_comments <- function(date_str) {
  file_path <- here::here("data", paste0("comments_", date_str, "_Jan.xlsx"))

  if (!file.exists(file_path)) {
    warning(paste("File not found:", file_path))
    return(NULL)
  }

  read_excel(file_path) %>%
    select(body, date) %>%
    mutate(date = as.Date(date))
}

# Read all files at once
dates <- c("13", "14", "15", "16", "17", "18", "19", "20",
           "21", "22", "23", "24", "27", "28", "29", "30", "31")

my_gamestop <- dates %>%
  map(read_and_clean_comments) %>%
  bind_rows()
```

#### Full Refactoring Recommendations:

```r
# 1. Project structure
# GMEToTheMoon/
# ├── data/
# │   ├── raw/
# │   └── processed/
# ├── scripts/
# │   ├── 01_data_collection.R
# │   ├── 02_data_cleaning.R
# │   ├── 03_sentiment_analysis.R
# │   ├── 04_regression_analysis.R
# │   └── 05_visualization.R
# ├── output/
# │   ├── figures/
# │   └── tables/
# ├── functions/
# │   └── helper_functions.R
# └── README.md

# 2. Use configuration file
config <- list(
  data_dir = here::here("data", "raw"),
  output_dir = here::here("output"),
  start_date = as.Date("2021-01-13"),
  end_date = as.Date("2021-01-31"),
  stocks = c("GME", "DDS", "BBBY", "FIZZ", "NOK", "BB", "AMC")
)

# 3. Create reusable functions
source(here::here("functions", "helper_functions.R"))

# 4. Add logging
library(logger)
log_info("Starting sentiment analysis for {length(dates)} days")

# 5. Make it a research compendium
library(usethis)
use_readme_md()
use_mit_license()
```

---

### E. Statistical Rigor

#### Missing Elements:

1. **No hypothesis tests**
2. **No confidence intervals**
3. **No discussion of statistical significance**
4. **No power analysis**
5. **No correction for multiple comparisons**

#### Add These:

```r
# 1. Correlation test with confidence interval
cor_test <- cor.test(sentiment_data$weighted_sentiment,
                     stock_data$return,
                     method = "pearson")
print(cor_test)  # Shows CI and p-value

# 2. Test if sentiment differs pre/post peak
t.test(sentiment ~ period, data = sentiment_data)

# 3. Multiple testing correction
# If testing 10 emotions, use Bonferroni correction
p_values <- c(...)  # p-values from 10 tests
p_adjust(p_values, method = "bonferroni")

# 4. Confidence bands on plots
ggplot(per, aes(x = date, y = percent, color = emotion)) +
  geom_line(size = 1.5) +
  geom_ribbon(aes(ymin = percent_lower, ymax = percent_upper), alpha = 0.2)

# 5. Report effect sizes
library(effectsize)
cohens_d(sentiment ~ period, data = sentiment_data)
```

---

## III. ENHANCED METHODOLOGY PROPOSAL

### Recommended New Analysis Pipeline

```
1. DATA COLLECTION (Expanded)
   ├── Reddit comments: Dec 2020 - Jun 2021
   ├── Stock prices: GME + 10 control stocks
   ├── Market data: S&P 500, VIX (volatility index)
   └── News mentions: Google Trends, news article counts

2. DATA PREPROCESSING
   ├── Filter GME-specific comments
   ├── Remove [deleted]/[removed]
   ├── Validate dates and merge with stock data
   └── Create complete time series (fill missing days)

3. SENTIMENT ANALYSIS (Multi-Method)
   ├── Loughran-McDonald (financial)
   ├── Custom WSB lexicon
   ├── VADER (social media-optimized)
   └── Validate on manual coding sample (n=200)

4. FEATURE ENGINEERING
   ├── Weighted sentiment (by score)
   ├── High-confidence sentiment (top 25% upvoted)
   ├── Sentiment volatility (daily standard deviation)
   ├── Volume metrics (number of comments)
   └── Lagged variables (t-1, t-2 days)

5. DESCRIPTIVE ANALYSIS
   ├── Time series plots
   ├── Summary statistics
   ├── Correlation matrices
   └── Visual inspection of relationships

6. CAUSAL INFERENCE
   ├── Difference-in-Differences (GME vs. controls)
   ├── Synthetic control method
   └── Event study around key dates

7. PREDICTIVE MODELING
   ├── Time-series regression (OLS with HAC SEs)
   ├── Vector Autoregression (VAR)
   ├── Granger causality tests
   └── Out-of-sample prediction

8. ROBUSTNESS CHECKS
   ├── Alternative sentiment measures
   ├── Different time windows
   ├── Winsorization of outliers
   └── Alternative model specifications

9. INTERPRETATION
   ├── Economic significance vs. statistical significance
   ├── Limitations discussion
   ├── Alternative explanations
   └── Policy/practical implications
```

---

## IV. SPECIFIC IMPROVEMENTS TO IMPLEMENT

### Priority 1 (Essential)

1. **Add regression analysis with lags**
   ```r
   model <- lm(return ~ sentiment_lag1 + volume_change + sp500_return,
               data = regression_data)
   ```

2. **Weight sentiment by comment scores**
   ```r
   weighted_sentiment = sentiment_value * log(score + 1)
   ```

3. **Expand time period to at least 3 months**
   - Need pre-event baseline

4. **Add statistical tests**
   ```r
   cor.test(), t.test(), summary(lm(...))
   ```

5. **Refactor code to remove repetition**
   - Use functions and loops

### Priority 2 (Important)

6. **Implement Difference-in-Differences**
   - Requires control stocks

7. **Use financial sentiment lexicon**
   - Loughran-McDonald

8. **Create custom WSB dictionary**
   - "moon", "rocket", "diamond hands", etc.

9. **Add robustness checks**
   - Alternative measures, time windows

10. **Validate sentiment accuracy**
    - Manual coding of sample

### Priority 3 (Nice to Have)

11. **Event study methodology**
12. **VAR or VECM models**
13. **Machine learning approaches** (Random Forest, LSTM)
14. **Network analysis** (user interactions)
15. **Intraday analysis** (if you can get intraday data)

---

## V. LITERATURE TO CITE

### Key Papers to Review:

1. **Social Media and Stock Markets:**
   - Bollen et al. (2011) - "Twitter mood predicts the stock market"
   - Ranco et al. (2015) - "The effects of Twitter sentiment on stock price returns"

2. **Reddit and Finance:**
   - Hu et al. (2021) - "Retail investors, social trading, and GameStop"
   - Pedersen (2022) - "GameStop short squeeze"

3. **Sentiment Analysis Methods:**
   - Loughran & McDonald (2011) - "When is a liability not a liability?"
   - Tetlock (2007) - "Giving content to investor sentiment"

4. **Causal Inference:**
   - Angrist & Pischke (2009) - "Mostly Harmless Econometrics"
   - Card & Krueger (1994) - Classic DiD paper

---

## VI. THESIS STRUCTURE RECOMMENDATIONS

### Suggested Outline:

```
1. INTRODUCTION
   - Motivation: GME short squeeze as pivotal event
   - Research question(s)
   - Contribution to literature
   - Preview of findings

2. LITERATURE REVIEW
   - Social media and financial markets
   - Sentiment analysis in finance
   - Retail trading and market dynamics
   - Reddit/WallStreetBets phenomenon

3. DATA
   - Data sources and collection methods
   - Sample period and justification
   - Descriptive statistics
   - Data cleaning and validation

4. METHODOLOGY
   - Sentiment analysis approach
   - Econometric models (regression, DiD)
   - Identification strategy
   - Robustness checks

5. RESULTS
   - Descriptive findings (your current visualizations)
   - Regression results
   - Causal estimates (DiD)
   - Robustness checks

6. DISCUSSION
   - Interpretation of findings
   - Economic significance
   - Mechanisms (why does sentiment matter?)
   - Limitations

7. CONCLUSION
   - Summary of findings
   - Implications for markets, regulation, investors
   - Future research directions

APPENDIX
   - Additional tables and figures
   - Robustness checks
   - Code (link to GitHub)
```

---

## VII. ANSWERS TO YOUR SPECIFIC QUESTIONS

### Q1: "Should I keep the research question or improve it?"

**ANSWER: Improve it**

**Current (implicit):** "What is the relationship between Reddit sentiment and GameStop prices?"

**Problems:**
- Too broad
- Doesn't specify causal vs. correlational
- Doesn't indicate what you'll add to existing knowledge

**Recommended:**

**Option A (Causal):**
*"Did positive sentiment shocks on r/WallStreetBets cause abnormal returns for GameStop stock during the January 2021 short squeeze event?"*

**Option B (Predictive):**
*"To what extent do high-engagement Reddit comments predict next-day returns for GameStop, and does this predictive power exceed that of traditional market indicators?"*

**Option C (Comparative):**
*"Was the sentiment-return relationship stronger for GameStop than for other heavily-shorted stocks during January 2021, and if so, what explains this difference?"*

**Why these are better:**
- Specific and testable
- Clear methodology implications
- Unique contribution
- Defendable

---

### Q2: "How to improve methodology - add DiD or confidence scores?"

**ANSWER: Do BOTH (and more)**

**Implement in this order:**

**Phase 1 (Foundation):**
1. Weight sentiment by comment scores ← **Do this first!**
2. Add basic regression with lags
3. Expand time period to 3+ months

**Phase 2 (Causal Inference):**
4. Implement Difference-in-Differences
5. Event study around key dates
6. Granger causality tests

**Phase 3 (Robustness):**
7. Alternative sentiment measures
8. Robustness checks
9. Validation studies

**Why score weighting is critical:**
```r
# Example showing why it matters:

# Scenario 1: One comment, 10,000 upvotes, says "GME to the moon!"
# Scenario 2: 100 comments, 10 upvotes each, saying "GME will crash"

# Without weighting:
#   Scenario 2 dominates (100 negative vs. 1 positive)
# With weighting:
#   Scenario 1 might dominate (viral signal)

# Empirically, test which predicts better:
model1 <- lm(return ~ unweighted_sentiment)  # R² = ?
model2 <- lm(return ~ weighted_sentiment)    # R² = ?
model3 <- lm(return ~ high_engagement_sentiment)  # R² = ?

# Report all three, compare
```

---

### Q3: "Other methodological ideas?"

**YES! Here are advanced options:**

#### A. **Intraday Analysis** (if you can get data)
```r
# Instead of daily close prices, use hourly/minute data
# Match with comment timestamps
# Immediate impact analysis
```

#### B. **Topic Modeling**
```r
library(topicmodels)
# Identify themes: short squeeze, YOLO, due diligence
# See which topics predict returns
```

#### C. **Network Analysis**
```r
library(igraph)
# User reply networks
# Identify influential users
# Information cascades
```

#### D. **Machine Learning**
```r
library(ranger)  # Random Forest
library(xgboost)

# Features: sentiment, volume, engagement, time, market vars
# Predict: next-day return direction (up/down)
# Compare to linear models
```

#### E. **Volatility Modeling**
```r
library(rugarch)
# Does sentiment predict volatility (risk)?
# GARCH models with sentiment as exogenous variable
```

#### F. **Comparison to News Sentiment**
```r
# Google Trends: "GameStop"
# News article sentiment (FinBERT)
# Does Reddit add info beyond mainstream news?
```

---

## VIII. ACTIONABLE NEXT STEPS

### Week 1-2: Foundation
- [ ] Refine research question (choose one from recommendations)
- [ ] Expand data collection (Dec 2020 - Jun 2021 minimum)
- [ ] Implement score-weighted sentiment
- [ ] Refactor code (remove repetition, add functions)

### Week 3-4: Analysis
- [ ] Build regression models with lags
- [ ] Add control variables (market return, volume)
- [ ] Conduct correlation and significance tests
- [ ] Create summary statistics tables

### Week 5-6: Causal Inference
- [ ] Identify control stocks
- [ ] Implement Difference-in-Differences
- [ ] Event study around peak dates
- [ ] Granger causality tests

### Week 7-8: Robustness & Writing
- [ ] Test alternative sentiment measures
- [ ] Robustness checks (different windows, outlier handling)
- [ ] Validate sentiment (manual coding sample)
- [ ] Draft results section with tables and figures

### Week 9-10: Polish
- [ ] Write introduction and literature review
- [ ] Discussion of limitations
- [ ] Policy/practical implications
- [ ] Final editing and formatting

---

## IX. CODE IMPLEMENTATION STARTER

I'll create a separate file with complete, refactored code implementing these suggestions. The improved analysis will include:

1. Modular functions
2. Weighted sentiment
3. Regression analysis
4. Statistical tests
5. Proper documentation

See `enhanced_analysis.R` for full implementation.

---

## X. FINAL ASSESSMENT

### Overall Evaluation

**Current Grade: B/B+** (Descriptive work, good visualizations, but lacks rigor)

**Potential Grade: A/A-** (With recommended improvements)

### What You're Doing Well:
1. Relevant and timely topic
2. Good data visualization
3. Multiple sentiment approaches
4. Clear code structure (mostly)

### Critical Gaps:
1. No causal inference
2. No statistical testing
3. Short time period
4. No engagement weighting
5. Generic sentiment lexicons

### Biggest Impact Improvements:
1. **Add regression analysis** ← Transforms from descriptive to analytical
2. **Weight by comment scores** ← Captures influence
3. **Implement DiD** ← Establishes causality
4. **Expand time period** ← Statistical power
5. **Use financial lexicon** ← Domain-appropriate

---

## XI. THESIS QUESTION - FINAL RECOMMENDATION

### Keep, Modify, or Change?

**VERDICT: Significantly Modify**

**From:**
"Relationship between Reddit sentiment and stock prices"

**To (Recommended):**

### **Primary Research Question:**
*"Did coordinated positive sentiment on r/WallStreetBets causally influence abnormal returns for GameStop during the January 2021 short squeeze, and through what mechanisms?"*

### **Sub-Questions:**
1. What was the lag structure of sentiment's effect on returns?
2. Did high-engagement comments have stronger predictive power?
3. How did the sentiment-return relationship differ from control stocks?
4. Did the effect persist after the peak, or was it event-specific?

### **Why This Question is Better:**

| Aspect | Old (Implicit) | New (Proposed) |
|--------|---------------|----------------|
| **Causality** | Unclear (correlation?) | Explicit causal claim |
| **Mechanism** | Not addressed | "Through what mechanisms?" |
| **Novelty** | Descriptive | Tests causal theory |
| **Methodology** | Ambiguous | Requires DiD/regression |
| **Contribution** | Unclear | Identifies social media's causal role |
| **Testability** | Vague | Specific, falsifiable |

---

## XII. CONCLUSION

Your thesis tackles a fascinating and important question. The GameStop event represents a paradigm shift in market dynamics, and understanding the role of social media is crucial.

**You have a solid foundation:**
- Good data
- Interesting visualizations
- Multiple sentiment approaches

**To elevate to publication quality:**
- Add causal inference (DiD)
- Implement weighted sentiment
- Conduct rigorous statistical tests
- Expand time period
- Use domain-appropriate methods

**The improvements I've suggested will:**
1. Transform from descriptive to analytical
2. Enable causal claims (not just correlation)
3. Meet standards for peer-reviewed publication
4. Provide actionable insights for investors/regulators

**Next Steps:**
1. Review the detailed methodology recommendations
2. Implement the code refactoring I'll provide
3. Focus first on weighted sentiment + regression
4. Then add DiD for causal inference
5. Finally, robustness checks and validation

I'm confident that with these enhancements, your thesis will make a meaningful contribution to understanding the intersection of social media and financial markets.

**Feel free to ask:**
- Specific implementation questions
- Clarification on any methodology
- Help with code
- Feedback on drafts

Good luck with your thesis! The topic is excellent, and with these improvements, the execution will match the ambition.

---

**Document Prepared:** November 2025
**For:** GME/WallStreetBets Sentiment Analysis Thesis
**Next:** See `enhanced_analysis.R` for code implementation
