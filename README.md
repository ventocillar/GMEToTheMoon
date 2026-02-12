# GMEToTheMoon

**Retail Investor Sentiment and Meme Stock Returns: Evidence from r/WallStreetBets During the GameStop Short Squeeze**

---

## Table of Contents

1. [Objective](#1-objective)
2. [Background and Motivation](#2-background-and-motivation)
3. [Research Question and Hypotheses](#3-research-question-and-hypotheses)
4. [Study Design](#4-study-design)
5. [Data](#5-data)
6. [Methodology](#6-methodology)
7. [Pipeline Overview](#7-pipeline-overview)
8. [Interactive Dashboard](#8-interactive-dashboard)
9. [Project Structure](#9-project-structure)
10. [How to Reproduce](#10-how-to-reproduce)
11. [Output Description](#11-output-description)
12. [Variable Codebook](#12-variable-codebook)
13. [Dependencies](#13-dependencies)
14. [Limitations and Future Work](#14-limitations-and-future-work)
15. [Authors](#15-authors)

---

## 1. Objective

This project provides the complete empirical pipeline for a master thesis investigating **whether retail investor sentiment expressed on r/WallStreetBets causally influenced the abnormal stock returns observed during the GameStop (GME) short squeeze of January 2021**.

The analysis goes beyond simple correlation. It applies causal inference techniques -- Granger causality testing and difference-in-differences (DiD) estimation -- to establish the direction and significance of the sentiment-return relationship, while controlling for confounders and validating results through multiple robustness checks.

---

## 2. Background and Motivation

In late January 2021, shares of GameStop Corp. (GME) rose from approximately $20 to a peak of $483 in under two weeks, driven largely by coordinated buying among retail investors on the Reddit forum r/WallStreetBets. The episode triggered Robinhood's unprecedented decision to restrict buying of several "meme stocks" on January 28, 2021, and led to a U.S. Congressional hearing on February 18, 2021.

The event raised fundamental questions about:

- Whether social media sentiment can move asset prices.
- Whether retail investor coordination constitutes a new form of market force.
- How standard financial NLP tools perform on non-standard language (slang, emojis, ironic usage).

Standard sentiment lexicons (AFINN, BING, NRC) were designed for general English text and fail to capture WSB-specific language where words like *retard*, *autist*, and *YOLO* carry positive connotations, and emojis like the rocket emoji serve as strong bullish signals. This project addresses this gap by constructing custom lexicons and an emoji sentiment dictionary tailored to the WSB community.

### Key Events Timeline

| Date | Event |
|------|-------|
| Nov 16, 2020 | Ryan Cohen's letter to GameStop board |
| Jan 11, 2021 | Ryan Cohen joins GameStop board; WSB attention accelerates |
| Jan 22, 2021 | First major price surge; GME closes at $65 |
| Jan 27, 2021 | Peak closing price ($347); extreme volume |
| **Jan 28, 2021** | **Robinhood restricts buying of GME, AMC, BB, NOK, BBBY** |
| Feb 18, 2021 | U.S. House Financial Services Committee hearing |

---

## 3. Research Question and Hypotheses

### Primary Research Question

> Did positive sentiment shocks on r/WallStreetBets causally influence abnormal returns for GameStop during the January 2021 short squeeze?

### Hypotheses

| ID | Hypothesis | Test |
|----|-----------|------|
| H1 | Lagged WSB sentiment predicts next-day GME returns | OLS with HAC standard errors |
| H2 | Sentiment Granger-causes returns (but not vice versa) | VAR / Granger causality |
| H3 | Meme stocks experienced abnormal returns relative to control stocks after the Robinhood restriction | Difference-in-Differences |
| H4 | Emoji sentiment adds explanatory power beyond text-only sentiment | F-test (nested model comparison) |
| H5 | Results are robust to alternative lexicons, weighting schemes, and subsamples | Robustness battery |

---

## 4. Study Design

### Period

**December 1, 2020 -- March 31, 2021** (~120 days, ~85 trading days). This window captures the full arc of the event: the pre-attention baseline, the buildup, the squeeze, and the aftermath.

### Treatment and Control Groups (for DiD)

| Group | Stocks | Rationale |
|-------|--------|-----------|
| **Treatment** (meme stocks) | GME, AMC, BB, NOK, BBBY | Stocks heavily discussed on WSB and restricted by Robinhood on Jan 28 |
| **Control** (retail sector) | WMT, TGT, KR, DG | Same broad sector (retail/consumer), comparable market cap range, no significant WSB attention during the study period |

### Event Date

**January 28, 2021** -- The day Robinhood restricted buying. Used as the treatment date for the DiD design and as the primary structural break in the time series analysis.

---

## 5. Data

### 5A. Reddit Comments

**Source**: Arctic Shift API (community-maintained Pushshift mirror) at `https://arctic-shift.photon-reddit.com/api/`.

All comments from r/wallstreetbets between December 1, 2020 and March 31, 2021 are collected. The original Excel files used in the first version of this thesis have been lost; this scraper reconstructs the dataset from archival sources with broader coverage (the original only had Jan 13--31).

**Fields collected per comment**:

| Field | Description |
|-------|-------------|
| `comment_id` | Unique Reddit comment identifier |
| `body` | Full comment text (including emojis) |
| `author` | Reddit username |
| `score` | Net upvotes (upvotes minus downvotes) |
| `created_utc` | Unix timestamp of creation |
| `date` | Derived calendar date (YYYY-MM-DD) |
| `parent_id` | Parent comment or submission ID |
| `permalink` | URL path to the comment |

**Expected volume**: ~500,000--1,000,000+ comments across the 4-month period. Comments with `[deleted]` or `[removed]` bodies are excluded at collection time.

**Storage**: SQLite database at `data/wsb_data.sqlite`.

### 5B. Stock Prices

**Source**: Yahoo Finance via the `tidyquant` R package (`tq_get()`).

Daily OHLCV data for all 9 stocks (5 meme + 4 control) from October 1, 2020 through April 30, 2021. The wider window provides pre-treatment data for the DiD parallel trends test.

**Derived variables**:

| Variable | Formula |
|----------|---------|
| `daily_return` | `(adjusted_t / adjusted_{t-1}) - 1` |
| `log_return` | `log(adjusted_t / adjusted_{t-1})` |
| `abnormal_volume` | `volume_t / mean(volume_{pre-Jan 2021})` |

### 5C. Sentiment Lexicons

Six lexicons are used, applied to every comment in the dataset:

| Lexicon | Type | Source | Coverage |
|---------|------|--------|----------|
| **NRC** | Categorical (10 emotions) | `tidytext::get_sentiments("nrc")` | General English; 8 emotions + positive/negative |
| **BING** | Binary (positive/negative) | `tidytext::get_sentiments("bing")` | General English |
| **AFINN** | Numeric (-5 to +5) | `tidytext::get_sentiments("afinn")` | General English |
| **Loughran-McDonald** | Categorical (6 classes) | `tidytext::get_sentiments("loughran")` | Financial text |
| **WSB Custom** | Numeric (-3 to +3) | `data/lexicons/wsb_lexicon.csv` | 58 WSB-specific slang terms |
| **Emoji** | Numeric (-2 to +3) | `data/lexicons/wsb_emoji_lexicon.csv` | 30 common WSB emojis |

#### WSB Custom Lexicon Design

The custom lexicon was built through qualitative coding of high-frequency WSB terms. Sentiment values reflect WSB community norms, not standard English usage:

| Category | Score | Examples |
|----------|-------|----------|
| Very bullish | +3 | moon, mooning, squeeze, shortsqueeze, gainporn |
| Bullish | +2 | tendies, diamond, hodl, yolo, bullish, dfv |
| Mildly bullish | +1 | ape, stonk, hold, bull, dd, brrr, buythedip |
| Context-inverted | +1 | retard, autist, degenerates (terms of endearment on WSB) |
| Neutral | 0 | lossporn, wifesboyfriend, casino, wendy |
| Bearish | -2 | paperhands, bagholder, fud, citadel, melvin |
| Very bearish | -3 | guh |

#### Emoji Lexicon Design

Emojis are extracted from comment text **before** tokenization (critical because `unnest_tokens()` strips non-ASCII characters). Each emoji is assigned a sentiment value:

| Score | Emojis |
|-------|--------|
| +3 | Rocket |
| +2 | Diamond, money bag, chart increasing, moon, ox, flexed biceps, money-mouth face |
| +1 | Gorilla, banana, open hands, poultry leg |
| 0 | Slot machine, face with tears of joy, rolling on floor laughing |
| -1 | Clown face, pile of poo, loudly crying, rainbow (WSB negative connotation), wastebasket |
| -2 | Bear, chart decreasing, skull, skull and crossbones, roll of paper (paper hands) |

---

## 6. Methodology

### 6A. Text Preprocessing

1. **Emoji extraction** -- Unicode emoji characters are extracted from raw comment text using `stringi::stri_extract_all_regex()` before any tokenization. Each emoji occurrence is stored as a separate observation with the parent comment's date and score.

2. **Text cleaning** -- URLs, markdown links, HTML entities (`&amp;`, `&gt;`), and dollar signs are removed.

3. **Tokenization** -- `tidytext::unnest_tokens()` splits text into unigrams.

4. **Stop word removal** -- Standard English stop words (`tidytext::stop_words`) plus 50+ custom Reddit stop words (e.g., *deleted*, *removed*, *http*, *amp*, *lol*, *lmao*, contractions).

5. **Filtering** -- Pure numeric tokens and single-character tokens are removed.

### 6B. Sentiment Computation

A single parameterized function `compute_sentiment_by_lexicon()` handles all lexicons. For each lexicon, daily sentiment is computed in two variants:

- **Unweighted**: Each word/emoji contributes equally regardless of comment popularity.
- **Score-weighted**: Contributions are weighted by `log(comment_score + 2)`, giving more influence to highly upvoted comments.

**Normalization**: Raw counts are divided by daily comment volume to produce comparable cross-day measures.

**Composite scores**:
- `nrc_net` = NRC positive count - NRC negative count
- `bing_net` = BING positive count - BING negative count
- `nrc_ratio` = NRC positive / (NRC positive + NRC negative)

### 6C. OLS Regression with HAC Standard Errors

Four model specifications test whether sentiment predicts returns:

| Model | Specification | Purpose |
|-------|--------------|---------|
| M1 | `return_t ~ sentiment_t` | Contemporaneous association |
| M2 | `return_t ~ sentiment_{t-1}` | Predictive (lagged) |
| M3 | `return_t ~ sentiment_{t-1} + sentiment_{t-2} + volume + n_comments` | Full model with controls |
| M4 | `return_t ~ text_sentiment + emoji_sentiment` vs. text-only | Emoji contribution (F-test) |

All models use **Newey-West heteroskedasticity and autocorrelation consistent (HAC) standard errors** (`sandwich::NeweyWest()`, 5 lags) to account for serial correlation in daily financial data.

### 6D. Granger Causality

1. **Stationarity**: Augmented Dickey-Fuller (ADF) tests confirm that returns and sentiment series are stationary (required for valid VAR estimation).

2. **Lag selection**: Optimal lag order is chosen by minimizing the Akaike Information Criterion (AIC) via `vars::VARselect()`.

3. **VAR estimation**: A bivariate Vector Autoregression is estimated for each sentiment measure paired with GME returns.

4. **Granger causality**: `vars::causality()` tests both directions:
   - Does sentiment Granger-cause returns? (H2a)
   - Do returns Granger-cause sentiment? (H2b -- feedback effect)

5. **Impulse response functions (IRF)**: Bootstrap confidence intervals (1,000 replications) quantify the dynamic response of returns to a one-standard-deviation sentiment shock over a 10-day horizon.

### 6E. Difference-in-Differences

The DiD design exploits the Robinhood restriction as a quasi-natural experiment:

**Estimating equation**:

```
return_{i,t} = alpha_i + gamma_t + beta * (treated_i x post_t) + epsilon_{i,t}
```

where `alpha_i` are stock fixed effects, `gamma_t` are date fixed effects, and `beta` is the DiD estimator (average treatment effect on the treated).

Three specifications are estimated using `fixest::feols()`:

| Spec | Fixed Effects | Standard Errors |
|------|--------------|-----------------|
| Basic | None | Clustered at stock level |
| Stock FE | Stock | Clustered at stock level |
| Two-way FE | Stock + Date | Clustered at stock level |

**Parallel trends validation**: An event study specification interacts treatment with relative-time dummies (days before/after Jan 28). Pre-treatment coefficients should be statistically insignificant if the parallel trends assumption holds.

### 6F. Robustness Checks

| Check | Purpose |
|-------|---------|
| Alternative lexicons | Re-run main regression with BING, NRC, Loughran-McDonald, and combined lexicons |
| Score-weighted vs. unweighted | Compare whether comment popularity weighting changes conclusions |
| Placebo DiD (Dec 15, 2020) | Run DiD with a fake event date; should find no treatment effect |
| High-engagement subsample | Re-run with only comments scoring > 10 upvotes |
| Bootstrap CIs | 1,000-rep bootstrap for main regression coefficients |
| Manual validation | Export 200 random comments for human sentiment annotation; compute inter-rater agreement (Cohen's kappa) |

---

## 7. Pipeline Overview

The analysis runs as a sequential pipeline of numbered R scripts. Each script reads the outputs of previous scripts and produces data objects and/or output files.

```
[Python Scraper]          Reddit comments --> SQLite
        |
        v
[00_setup.R]              Packages, config, DB connection, helpers
        |
        v
[01_load_data.R]          SQLite --> comments_raw, daily_activity
        |
        v
[02_preprocess_text.R]    Emoji extraction + tokenization --> tokens_clean, emoji_extracted
        |
        v
[03_sentiment_analysis.R] All lexicons --> all_sentiment (6 lexicons x 2 weight types)
        |
        v
[04_financial_data.R]     Yahoo Finance --> stock_prices, gme_prices (stored in SQLite)
        |
        v
[05_merge_and_aggregate.R] Merge sentiment + returns --> master_df, master_trading
        |
        v
[06_descriptive_stats.R]  Summary tables + 8 publication plots --> output/
        |
        v
[07_regression.R]         OLS + HAC SEs + F-test --> regression tables
        |
        v
[08_granger_causality.R]  ADF + VAR + Granger + IRF --> causality results
        |
        v
[09_did_analysis.R]       DiD + event study + parallel trends --> DiD tables + plots
        |
        v
[10_robustness.R]         6 robustness checks --> robustness tables + validation sample
```

The master script `run_all.R` sources every step, prints a summary of key findings, and exports dashboard data:

```
        |
        v
[11_export_dashboard.R]  Export all results as JSON --> thesis-dashboard/static/data/
```

---

## 8. Interactive Dashboard

A scrollytelling web application built with **SvelteKit 5 + D3.js** presents the analysis results interactively. The dashboard features 10 sections with animated charts, tooltips, and responsive design.

**Tech stack**: SvelteKit 5 (runes syntax), Tailwind CSS v4, D3.js v7, TypeScript, adapter-static.

**Visual design**: Dark theme (`#0a0a0f` background) with the MetBrewer Veronese 10-color palette. Scrollytelling layout with floating navigation dots, gradient progress bar, and IntersectionObserver-driven section tracking.

### Dashboard Sections

| # | Section | Component(s) | Visualization |
|---|---------|-------------|---------------|
| 1 | **Hero** | `HeroSection.svelte` | Animated GME price counter ($16 -> $483 -> $40) |
| 2 | **Timeline** | `TimelineChart.svelte` | Dual-axis: price (teal line) + AFINN sentiment (gold area) with event markers |
| 3 | **The Null Result** | `NullResultCard.svelte`, `GrangerArrow.svelte` | Key finding + animated causality direction diagram |
| 4 | **Regression** | `CoefficientPlot.svelte` | Forest plot with CI whiskers, toggleable model pills |
| 5 | **DiD** | `EventStudyChart.svelte`, `CumulativeReturns.svelte` | Event study coefficients + meme vs control cumulative returns |
| 6 | **IRF** | `IrfChart.svelte` (x4) | Impulse response functions with bootstrap CI bands |
| 7 | **Emotions** | `EmotionRadar.svelte`, `EmotionStream.svelte` | Spider chart + stacked area of 8 NRC emotions |
| 8 | **WSB Culture** | `EmojiBar.svelte`, `WordCloud.svelte` | Top emoji bar chart + dual-panel word contributions |
| 9 | **Robustness** | `BootstrapCI.svelte`, `LexiconGrid.svelte` | CI visualization + cross-lexicon heatmap |
| 10 | **Methodology** | `MethodologyCards.svelte` | Collapsible cards + pipeline diagram |

### Running the Dashboard

```bash
cd thesis-dashboard
npm install
npm run dev          # Development server at http://localhost:5173
npm run build        # Static export to build/
```

### Data Flow: R -> Dashboard

The R export script (`11_export_dashboard.R`) converts all in-memory pipeline objects to 11 JSON files:

| JSON File | Source | Content |
|-----------|--------|---------|
| `timeline.json` | `master_trading` | 82 trading days: price, volume, all sentiment scores, comment activity |
| `summary_stats.json` | `summary_statistics.csv` | Descriptive statistics (N, mean, SD, min, Q1, median, Q3, max) |
| `granger.json` | `granger_results` | 4 Granger causality tests (both directions, 2 lexicons) |
| `regression_coefs.json` | Regression model objects | 25 coefficients across 8 models + emoji F-test |
| `did_results.json` | DiD model objects | Event study coefficients, DiD estimates, cumulative returns |
| `irf.json` | IRF objects from VAR | 44 impulse response points (4 panels x 11 horizons) |
| `emotions.json` | NRC daily sentiment | 960 rows: 8 emotions x 120 days |
| `emoji_top.json` | `emoji_freq` | Top 20 emojis with counts and sentiment values |
| `word_contributions.json` | BING word contribution | Top positive and negative word contributors |
| `bootstrap_ci.json` | `bootstrap_ci.csv` | 1,000-rep bootstrap 95% CIs for main coefficients |
| `robustness.json` | Robustness model objects | Cross-lexicon coefficients + placebo test result |

For detailed documentation on the dashboard architecture and build process, see [`thesis-dashboard/GUIDE.md`](thesis-dashboard/GUIDE.md).

---

## 9. Project Structure

```
GMEToTheMoon/
├── config.yml                          # All study parameters (dates, tickers, paths)
├── .gitignore                          # Excludes data, outputs, IDE files
├── requirements.txt                    # Python dependencies (requests)
├── README.md                           # This file
│
├── data/
│   ├── wsb_data.sqlite                 # Central SQLite database (generated by scraper)
│   └── lexicons/
│       ├── wsb_lexicon.csv             # 58 WSB slang terms with sentiment values
│       └── wsb_emoji_lexicon.csv       # 30 emojis with sentiment values
│
├── src/
│   ├── python/
│   │   ├── scrape_pushshift.py         # Arctic Shift API scraper (pagination, retry, resume)
│   │   └── db_schema.sql              # SQLite table definitions and indexes
│   │
│   └── R/
│       ├── 00_setup.R                  # Package management, config loading, DB helper
│       ├── 01_load_data.R              # Load comments from SQLite, compute daily activity
│       ├── 02_preprocess_text.R        # Emoji extraction, tokenization, stop word removal
│       ├── 03_sentiment_analysis.R     # Run all 6 lexicons (weighted + unweighted)
│       ├── 04_financial_data.R         # Fetch stock prices, compute returns
│       ├── 05_merge_and_aggregate.R    # Merge sentiment + returns, create lag variables
│       ├── 06_descriptive_stats.R      # Summary statistics, 8 time series plots
│       ├── 07_regression.R             # OLS with Newey-West HAC SEs, emoji F-test
│       ├── 08_granger_causality.R      # ADF, VAR, Granger tests, impulse responses
│       ├── 09_did_analysis.R           # Difference-in-Differences, event study plot
│       ├── 10_robustness.R             # Placebo, subsample, bootstrap, validation export
│       ├── 11_export_dashboard.R       # Export all results as JSON for dashboard
│       │
│       ├── helpers/
│       │   ├── sentiment_functions.R   # Parameterized sentiment computation (all lexicons)
│       │   └── plotting_theme.R        # theme_thesis(), save_thesis_plot(), color palette
│       │
│       ├── run_all.R                   # Master script: sources all steps in order
│       │
│       └── legacy/
│           └── thesis.AlmeidaFranco.R  # Original 600-line script (preserved for reference)
│
├── thesis-dashboard/                   # Interactive SvelteKit + D3 dashboard
│   ├── package.json                    # Dependencies: Svelte 5, D3, Tailwind v4
│   ├── svelte.config.js               # adapter-static for SSG
│   ├── vite.config.ts                  # Tailwind + SvelteKit plugins
│   ├── tsconfig.json                   # noImplicitAny: false for D3
│   ├── GUIDE.md                        # Methodology thought process + build guide
│   ├── src/
│   │   ├── app.html, app.css           # Shell + dark theme globals
│   │   ├── lib/
│   │   │   ├── components/             # 15+ Svelte 5 chart components
│   │   │   │   ├── hero/               # Animated price counter
│   │   │   │   ├── timeline/           # Dual-axis price + sentiment chart
│   │   │   │   ├── granger/            # Causality direction diagram
│   │   │   │   ├── regression/         # Forest plot with CI whiskers
│   │   │   │   ├── did/                # Event study + cumulative returns
│   │   │   │   ├── irf/                # Impulse response functions
│   │   │   │   ├── emotions/           # Radar + stream charts
│   │   │   │   ├── culture/            # Emoji bar + word contributions
│   │   │   │   ├── robustness/         # Bootstrap CI + lexicon grid
│   │   │   │   ├── methodology/        # Collapsible cards + pipeline diagram
│   │   │   │   └── layout/             # Nav, Section, ScrollProgress
│   │   │   ├── stores/data.svelte.ts   # Writable stores for 11 JSON datasets
│   │   │   ├── types/index.ts          # TypeScript interfaces
│   │   │   └── utils/                  # Colors (Veronese palette) + formatters
│   │   └── routes/
│   │       ├── +layout.svelte          # Data loading + progress bar
│   │       ├── +layout.ts              # SSG prerender config
│   │       └── +page.svelte            # 10-section scrollytelling page
│   └── static/data/                    # 11 JSON files exported by R pipeline
│
├── output/
│   ├── figures/                        # All plots (PNG, 300 DPI, 30x20 cm)
│   └── tables/                         # Regression tables (LaTeX), CSVs, validation sample
│
└── tests/
    └── test_sentiment_functions.R      # 12 unit tests for sentiment functions
```

---

## 10. How to Reproduce

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| **R** | >= 4.1 | Statistical analysis |
| **Python** | >= 3.8 | Reddit data collection |
| **Internet** | Required | Downloading Reddit data and stock prices |

R packages are installed automatically by `00_setup.R` if missing. Python requires only the `requests` library.

### Step 1: Clone the Repository

```bash
git clone https://github.com/ventocillar/GMEToTheMoon.git
cd GMEToTheMoon
```

### Step 2: Collect Reddit Data

The scraper downloads all r/wallstreetbets comments from December 2020 through March 2021 from the Arctic Shift API and stores them in a local SQLite database.

```bash
pip install -r requirements.txt
python src/python/scrape_pushshift.py
```

**Options**:

```bash
python src/python/scrape_pushshift.py --start 2020-12-01 --end 2021-03-31 --db data/wsb_data.sqlite
```

**Notes**:
- Takes approximately 1--2 hours depending on API speed and network.
- The scraper supports **resumption**: if interrupted, re-running the same command picks up where it left off.
- Progress is logged every 10 batches with current date position and cumulative counts.
- Deleted and removed comments are filtered out at collection time.

**Verify data collection**:

```bash
sqlite3 data/wsb_data.sqlite "SELECT COUNT(*), MIN(date), MAX(date) FROM comments;"
```

Expected output: 500,000+ comments spanning 2020-12-01 to 2021-03-31.

### Step 3: Run the Full Analysis

Open R in the project root directory and run:

```r
source("src/R/run_all.R")
```

This executes all 11 scripts in sequence. Typical runtime is 5--15 minutes depending on dataset size and machine. The script prints progress messages and a summary of key findings at the end.

**To run individual steps** (e.g., after modifying a later script):

```r
source("src/R/00_setup.R")          # Always run setup first
source("src/R/01_load_data.R")      # Then the specific step
# ...
```

### Step 4: Run Unit Tests

```r
testthat::test_file("tests/test_sentiment_functions.R")
```

Runs 12 tests covering:
- Correct output structure for each lexicon
- Score weighting produces different results than unweighted
- Multi-day data returns separate rows per date
- WSB custom lexicon math (e.g., moon + guh = net 0)
- Emoji bullish/bearish counting
- Normalization by daily comment volume
- Error on unknown lexicon name

### Step 5: Launch the Interactive Dashboard

After the R pipeline completes, it automatically exports 11 JSON files to `thesis-dashboard/static/data/`. To run the dashboard:

```bash
cd thesis-dashboard
npm install
npm run dev          # Development server at http://localhost:5173
```

To build a static export for deployment:

```bash
npm run build        # Static site exported to build/
```

For detailed documentation on the dashboard architecture, see [`thesis-dashboard/GUIDE.md`](thesis-dashboard/GUIDE.md).

### Step 6: Manual Validation (Researcher Task)

After running the pipeline, `output/tables/validation_sample.csv` contains 200 randomly sampled comments with empty columns for manual sentiment annotation. The researcher should:

1. Read each comment and assign `manual_sentiment` (positive / negative / neutral).
2. Rate `manual_confidence` (1--5 scale).
3. Compute Cohen's kappa between manual labels and the lexicon-assigned labels to assess sentiment measurement quality.

---

## 11. Output Description

### Figures (`output/figures/`)

| File | Description |
|------|-------------|
| `gme_price_timeseries.png` | GME adjusted closing price with event date markers |
| `daily_comment_volume.png` | Daily number of WSB comments |
| `nrc_emotions_timeseries.png` | 8 NRC emotions (anger through trust) normalized over time |
| `positive_negative_timeseries.png` | NRC and BING positive/negative sentiment comparison |
| `sentiment_return_overlay.png` | Standardized AFINN sentiment overlaid on GME returns (Jan--Feb) |
| `bing_word_contribution.png` | Top 20 words contributing to positive and negative BING sentiment |
| `emoji_frequency.png` | 20 most frequent emojis in WSB comments |
| `meme_stocks_prices.png` | Faceted price charts for all 5 meme stocks |
| `irf_afinn_to_return.png` | Impulse response: AFINN shock -> GME return (10-day horizon) |
| `irf_wsb_to_return.png` | Impulse response: WSB sentiment shock -> GME return |
| `did_event_study.png` | Event study coefficients (treatment effect by relative day) |
| `cumulative_abnormal_returns.png` | Cumulative returns: meme stocks vs. control stocks |

### Tables (`output/tables/`)

| File | Description |
|------|-------------|
| `summary_statistics.csv` | Descriptive statistics for all key variables |
| `regression_afinn.tex` | AFINN regression table (3 specifications, HAC SEs) |
| `regression_wsb.tex` | WSB custom regression table (3 specifications, HAC SEs) |
| `regression_text_vs_emoji.tex` | Text-only vs. emoji vs. combined comparison |
| `granger_causality.csv` | Granger test results (both directions, 2 lexicons) |
| `did_results.tex` | DiD coefficient table (3 FE specifications) |
| `robustness_lexicons.tex` | Main result replicated across all lexicons |
| `robustness_weighted.tex` | Score-weighted vs. unweighted comparison |
| `robustness_high_engagement.tex` | All comments vs. high-score subsample |
| `bootstrap_ci.csv` | Bootstrap 95% confidence intervals for main coefficients |
| `validation_sample.csv` | 200 random comments for manual annotation |

---

## 12. Variable Codebook

### Sentiment Variables (daily)

| Variable | Lexicon | Type | Description |
|----------|---------|------|-------------|
| `afinn_score` | AFINN | Numeric | Sum of AFINN word values (-5 to +5 per word) |
| `wsb_score` | WSB Custom | Numeric | Sum of WSB lexicon values (-3 to +3 per word) |
| `emoji_score` | Emoji | Numeric | Sum of emoji sentiment values |
| `bing_net` | BING | Numeric | Count(positive words) - Count(negative words) |
| `nrc_net` | NRC | Numeric | Count(positive words) - Count(negative words) |
| `nrc_ratio` | NRC | Ratio [0,1] | Positive / (positive + negative) |
| `bing_ratio` | BING | Ratio [0,1] | Positive / (positive + negative) |
| `raw_count_nrc_*` | NRC | Count | Raw word count per emotion (anger, joy, etc.) |
| `normalized_nrc_*` | NRC | Ratio | Raw count / daily comment volume |

### Financial Variables (daily, trading days only)

| Variable | Description |
|----------|-------------|
| `gme_return` | GME daily return: `(adjusted_t / adjusted_{t-1}) - 1` |
| `gme_log_return` | GME log return: `log(adjusted_t / adjusted_{t-1})` |
| `gme_close` | GME adjusted closing price (USD) |
| `gme_volume` | GME daily trading volume (shares) |
| `gme_abnormal_volume` | Volume relative to pre-event average |

### Activity Variables (daily)

| Variable | Description |
|----------|-------------|
| `n_comments` | Number of WSB comments that day |
| `n_authors` | Number of unique comment authors |
| `avg_score` | Mean comment score (upvotes) |
| `median_score` | Median comment score |
| `total_score` | Sum of all comment scores |

### Lag Variables

All sentiment and activity variables are also available with `_lag1` and `_lag2` suffixes representing 1-day and 2-day lags respectively (e.g., `afinn_lag1`, `wsb_lag2`, `n_comments_lag1`).

### DiD Variables

| Variable | Description |
|----------|-------------|
| `treated` | 1 if meme stock, 0 if control stock |
| `post` | 1 if date >= Jan 28, 2021 |
| `treat_x_post` | Interaction term (DiD estimator) |
| `post_event` | 1 if date >= Jan 28 |
| `post_surge` | 1 if date >= Jan 22 |

---

## 13. Dependencies

### R Packages

| Package | Version | Purpose |
|---------|---------|---------|
| `here` | >= 1.0 | Reproducible file paths (replaces `setwd()`) |
| `yaml` | >= 2.3 | Parse `config.yml` |
| `tidyverse` | >= 1.3 | Data wrangling, plotting (includes ggplot2, dplyr, tidyr, readr, purrr, stringr) |
| `lubridate` | >= 1.8 | Date handling |
| `tidytext` | >= 0.3 | Text tokenization and built-in lexicons (NRC, BING, AFINN, Loughran) |
| `stringi` | >= 1.7 | Unicode emoji extraction via regex |
| `DBI` | >= 1.1 | Database interface |
| `RSQLite` | >= 2.2 | SQLite driver |
| `tidyquant` | >= 1.0 | Stock price data from Yahoo Finance |
| `sandwich` | >= 3.0 | Newey-West HAC variance-covariance estimator |
| `lmtest` | >= 0.9 | `coeftest()` for HAC standard errors |
| `vars` | >= 1.5 | VAR estimation, Granger causality, impulse response functions |
| `tseries` | >= 0.10 | Augmented Dickey-Fuller stationarity test |
| `fixest` | >= 0.11 | Fast fixed-effects estimation for DiD |
| `stargazer` | >= 5.2 | LaTeX regression tables |
| `modelsummary` | >= 1.0 | Alternative regression tables |
| `kableExtra` | >= 1.3 | Table formatting |
| `MetBrewer` | >= 0.2 | Color palettes (Veronese palette) |
| `scales` | >= 1.2 | Axis formatting (comma, percent) |
| `patchwork` | >= 1.1 | Plot composition |
| `broom` | >= 1.0 | Tidy model output |
| `jsonlite` | >= 1.8 | Export pipeline results as JSON for dashboard |
| `testthat` | >= 3.0 | Unit testing (for `tests/`) |

All packages are installed automatically by `00_setup.R` if not already present.

### Python Packages

| Package | Version | Purpose |
|---------|---------|---------|
| `requests` | >= 2.28 | HTTP requests to Arctic Shift API |

Standard library modules used: `sqlite3`, `json`, `time`, `datetime`, `argparse`, `logging`, `os`, `sys`.

---

## 14. Limitations and Future Work

### Limitations

- **Lexicon-based sentiment** cannot capture sarcasm, irony, or context-dependent meaning beyond the hand-coded exceptions in the WSB lexicon.
- **Comment-level analysis** treats all comments equally within a day; thread structure and reply chains are not modeled.
- **Subreddit scope**: Only r/wallstreetbets is analyzed. Cross-platform sentiment (Twitter, Discord, StockTwits) is not included.
- **Short time series**: ~85 trading days limits the power of time series tests; Granger causality results should be interpreted cautiously.
- **No intraday data**: Daily aggregation cannot capture within-day sentiment dynamics or after-hours trading effects.

### Future Work

- Apply transformer-based sentiment models (e.g., FinBERT, RoBERTa fine-tuned on Reddit) to improve classification accuracy.
- Extend to intraday analysis using comment timestamps and tick-level price data.
- Include additional social media platforms for cross-platform sentiment triangulation.
- Apply the framework to subsequent meme stock episodes (AMC June 2021, BBBY August 2022).

---

## 15. Authors

**Renato Ventocilla Franco** and **Francisco Almeida**

*Master Thesis -- Hertie School*

Supervisor: **Marc Kayser**
