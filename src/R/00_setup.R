# ==============================================================================
# 00_setup.R
# Project setup: packages, configuration, database connection, helpers
# ==============================================================================

# --- Package Management -------------------------------------------------------

required_packages <- c(
  # Core
  "here", "config", "yaml",
  # Data
  "tidyverse", "lubridate",
  # Text mining
  "tidytext", "textdata", "stringi", "stringr",
  # Database
  "DBI", "RSQLite",
  # Financial
  "tidyquant",
  # Econometrics
  "sandwich", "lmtest", "vars", "tseries", "fixest",
  # Tables & output
  "stargazer", "modelsummary", "kableExtra",
  # Plotting
  "MetBrewer", "scales", "patchwork",
  # Reproducibility
  "broom"
)

install_if_missing <- function(pkgs) {
  missing <- pkgs[!sapply(pkgs, requireNamespace, quietly = TRUE)]
  if (length(missing) > 0) {
    message("Installing missing packages: ", paste(missing, collapse = ", "))
    install.packages(missing, repos = "https://cloud.r-project.org")
  }
}

install_if_missing(required_packages)

suppressPackageStartupMessages({
  library(here)
  library(config)
  library(yaml)
  library(tidyverse)
  library(lubridate)
  library(tidytext)
  library(textdata)
  library(stringi)
  library(stringr)
  library(DBI)
  library(RSQLite)
  library(tidyquant)
  library(sandwich)
  library(lmtest)
  library(vars)
  library(tseries)
  library(fixest)
  library(stargazer)
  library(modelsummary)
  library(kableExtra)
  library(MetBrewer)
  library(scales)
  library(patchwork)
  library(broom)
})

# Resolve namespace conflicts: vars/MASS mask dplyr::select and dplyr::filter
select <- dplyr::select
filter <- dplyr::filter

# Auto-accept textdata lexicon downloads (NRC, Loughran) in non-interactive mode
if (!interactive()) {
  td_env <- asNamespace("textdata")
  unlockBinding("printer", td_env)
  td_env$printer <- function(...) return(1L)
}

# --- Configuration ------------------------------------------------------------

cfg <- yaml::read_yaml(here("config.yml"))$default

# Unpack key parameters
STUDY_START  <- as.Date(cfg$study_period$start)
STUDY_END    <- as.Date(cfg$study_period$end)
EVENT_DATE   <- as.Date(cfg$events$robinhood_restriction)
PLACEBO_DATE <- as.Date(cfg$placebo_event_date)
MEME_STOCKS  <- cfg$meme_stocks
CTRL_STOCKS  <- cfg$control_stocks
ALL_STOCKS   <- c(MEME_STOCKS, CTRL_STOCKS)
DB_PATH      <- here(cfg$paths$database)
FIG_DIR      <- here(cfg$paths$figures)
TAB_DIR      <- here(cfg$paths$tables)

# Ensure output dirs exist
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(TAB_DIR, recursive = TRUE, showWarnings = FALSE)

# --- Database Helper ----------------------------------------------------------

get_db_connection <- function(path = DB_PATH) {
  if (!file.exists(path)) {
    stop("Database not found at: ", path,
         "\nRun the Python scraper first: python src/python/scrape_pushshift.py")
  }
  conn <- dbConnect(RSQLite::SQLite(), path)
  return(conn)
}

# --- Source Helpers -----------------------------------------------------------

source(here("src", "R", "helpers", "sentiment_functions.R"))
source(here("src", "R", "helpers", "plotting_theme.R"))

message("Setup complete. Study period: ", STUDY_START, " to ", STUDY_END)
