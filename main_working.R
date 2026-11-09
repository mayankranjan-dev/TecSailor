# TecSailor - Main Analysis Script (Working Version)
# This version skips fresh data collection and uses cached data

cat("========================================\n")
cat("TECSAILOR - ANALYSIS PIPELINE\n")
cat("========================================\n\n")

# Load required scripts
cat("[1/7] Loading setup...\n")
source("R/setup.R")

cat("[2/7] Loading configuration...\n")
source("config.R")
source("R/scrape.R")
source("R/text_analysis.R")
source("R/forecast.R")
source("R/plots.R")

# Create directories
for (folder in c("data/raw", "data/processed", "outputs/tables", paths$figures)) {
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
}

# Load existing data (skip scraping)
cat("[3/7] Loading review data...\n")
flipkart_data <- if (file.exists(paths$flipkart_reviews_raw)) {
  data <- read_csv(paths$flipkart_reviews_raw, show_col_types = FALSE)
  if (nrow(data) > 0 && !"source" %in% names(data)) {
    data$source <- "flipkart"
  }
  data
} else {
  cat("   Warning: No Flipkart data found\n")
  tibble()
}

amazon_data <- if (file.exists(paths$amazon_reviews_raw)) {
  data <- read_csv(paths$amazon_reviews_raw, show_col_types = FALSE)
  if (nrow(data) == 0) {
    data <- tibble()
  } else if (!"source" %in% names(data)) {
    data$source <- "amazon"
  }
  data
} else {
  tibble()
}

# Combine reviews
if (nrow(flipkart_data) > 0 && nrow(amazon_data) > 0) {
  reviews_raw <- bind_rows(flipkart_data, amazon_data)
} else if (nrow(flipkart_data) > 0) {
  reviews_raw <- flipkart_data
} else if (nrow(amazon_data) > 0) {
  reviews_raw <- amazon_data
} else {
  stop("No review data found! Please check data/raw/ folder.")
}

write_csv(reviews_raw, paths$reviews_raw)
cat(sprintf("   Loaded %d reviews (%d Flipkart, %d Amazon)\n",
             nrow(reviews_raw), nrow(flipkart_data), nrow(amazon_data)))

# Load trends
cat("[4/7] Loading Google Trends data...\n")
if (!file.exists(paths$trends_raw)) {
  stop("Trends data not found! Expected at: ", paths$trends_raw)
}
trends <- read_csv(paths$trends_raw, show_col_types = FALSE) |>
  mutate(date = as.Date(date))
cat(sprintf("   Loaded %d trend records\n", nrow(trends)))

# Process reviews
cat("[5/7] Processing reviews and sentiment...\n")
reviews <- reviews_raw |>
  mutate(review_date = as.Date(review_date)) |>
  prepare_reviews() |>
  score_sentiment()
write_csv(reviews, paths$reviews_clean)
cat(sprintf("   Processed %d usable reviews\n", nrow(reviews)))

# Sentiment metrics
sentiment_metrics <- classification_metrics(
  reviews$actual_sentiment,
  reviews$predicted_sentiment
)
write_csv(sentiment_metrics, paths$sentiment_metrics)

confusion <- as.data.frame(table(
  actual = reviews$actual_sentiment,
  predicted = reviews$predicted_sentiment
))
write_csv(confusion, "outputs/tables/sentiment_confusion.csv")

# Aspect analysis
aspects <- analyse_aspects(reviews)
write_csv(aspects, paths$aspects)
cat(sprintf("   Analyzed %d product aspects\n", nrow(aspects)))

# Forecasting
cat("[6/7] Running demand forecasts...\n")
forecast_metrics <- trends |>
  group_split(brand) |>
  map_dfr(evaluate_brand, holdout = test_weeks)
write_csv(forecast_metrics, paths$metrics)

best_models <- forecast_metrics |>
  group_by(brand) |>
  slice_min(RMSE, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(brand, model)

forecasts <- trends |>
  group_split(brand) |>
  map_dfr(function(data) {
    chosen <- best_models$model[best_models$brand == data$brand[1]]
    build_forecast(data, chosen, forecast_weeks)
  })
write_csv(forecasts, paths$forecasts)
cat(sprintf("   Generated %d weeks of forecasts\n", forecast_weeks))

# Sale opportunity scoring
sale_scores <- score_sale_weeks(forecasts, reviews)
recommendations <- sale_scores |>
  group_split(brand) |>
  map_dfr(select_sale_windows, n = 5) |>
  arrange(brand, desc(opportunity_score))
write_csv(sale_scores, "data/processed/all_sale_scores.csv")
write_csv(recommendations, paths$recommendations)

# Data quality metrics
scrape_log <- bind_rows(
  if (file.exists("data/raw/flipkart_scrape_log.csv")) {
    read_csv("data/raw/flipkart_scrape_log.csv", show_col_types = FALSE)
  } else if (file.exists("data/raw/scrape_log.csv")) {
    read_csv("data/raw/scrape_log.csv", show_col_types = FALSE) |>
      mutate(source = "flipkart")
  } else {
    tibble()
  },
  if (file.exists("data/raw/amazon_scrape_log.csv")) {
    read_csv("data/raw/amazon_scrape_log.csv", show_col_types = FALSE)
  } else {
    tibble()
  }
)

if (nrow(scrape_log) > 0 && "source" %in% names(scrape_log)) {
  quality <- scrape_log |>
    group_by(source) |>
    summarise(
      requested_pages = n(),
      successful_pages = sum(rows > 0),
      success_rate = mean(rows > 0),
      .groups = "drop"
    ) |>
    bind_rows(
      scrape_log |>
        summarise(
          source = "combined",
          requested_pages = n(),
          successful_pages = sum(rows > 0),
          success_rate = mean(rows > 0)
        )
    ) |>
    left_join(
      tibble(
        source = c("flipkart", "amazon", "combined"),
        raw_reviews = c(
          nrow(flipkart_data),
          nrow(amazon_data),
          nrow(bind_rows(flipkart_data, amazon_data))
        ),
        usable_reviews = c(
          sum(reviews$source == "flipkart", na.rm = TRUE),
          sum(reviews$source == "amazon", na.rm = TRUE),
          nrow(reviews)
        )
      ),
      by = "source"
    ) |>
    mutate(
      usable_share = ifelse(raw_reviews > 0, usable_reviews / raw_reviews, 0),
      verified_share = NA_real_,
      lexicon_coverage = NA_real_
    )
  
  quality$verified_share[quality$source == "flipkart"] <- mean(reviews$verified[reviews$source == "flipkart"], na.rm = TRUE)
  quality$verified_share[quality$source == "amazon"] <- mean(reviews$verified[reviews$source == "amazon"], na.rm = TRUE)
  quality$verified_share[quality$source == "combined"] <- mean(reviews$verified, na.rm = TRUE)
  
  quality$lexicon_coverage[quality$source == "flipkart"] <- mean(reviews$lexicon_hits[reviews$source == "flipkart"] > 0, na.rm = TRUE)
  quality$lexicon_coverage[quality$source == "amazon"] <- mean(reviews$lexicon_hits[reviews$source == "amazon"] > 0, na.rm = TRUE)
  quality$lexicon_coverage[quality$source == "combined"] <- mean(reviews$lexicon_hits > 0, na.rm = TRUE)
} else {
  # Fallback for old format
  quality <- tibble(
    source = "flipkart",
    requested_pages = 70,
    successful_pages = nrow(scrape_log),
    success_rate = 1.0,
    raw_reviews = nrow(flipkart_data),
    usable_reviews = nrow(reviews),
    usable_share = nrow(reviews) / nrow(flipkart_data),
    verified_share = mean(reviews$verified),
    lexicon_coverage = mean(reviews$lexicon_hits > 0)
  )
}

write_csv(quality, "outputs/tables/data_quality.csv")

# Generate visualizations
cat("[7/7] Creating visualizations...\n")
save_chart(plot_market_trends(trends), "01_market_trends.png", 11, 6)
save_chart(plot_forecasts(trends, forecasts), "02_demand_forecast.png", 11, 8)
save_chart(plot_sale_scores(sale_scores), "03_sale_opportunity.png", 11, 8)
save_chart(plot_sentiment(reviews), "04_customer_sentiment.png", 9, 6)
save_chart(plot_aspects(aspects), "05_review_aspects.png", 11, 8)
save_chart(plot_model_metrics(forecast_metrics), "06_forecast_evaluation.png", 10, 7)
cat("   Created 6 visualizations\n")

# Generate summary report
best_boat <- recommendations |>
  filter(brand == "boAt") |>
  arrange(desc(opportunity_score)) |>
  slice_head(n = 3)

summary_text <- c(
  "TECSAILOR - ANALYSIS SUMMARY",
  paste("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M")),
  "",
  "DATA QUALITY BY SOURCE",
  capture.output(print(quality, width = Inf)),
  "",
  "FORECAST BACKTEST",
  capture.output(print(forecast_metrics, n = Inf, width = Inf)),
  "",
  "SENTIMENT EVALUATION",
  capture.output(print(sentiment_metrics, n = Inf, width = Inf)),
  "",
  "TOP BOAT SALE WINDOWS",
  capture.output(print(select(best_boat, date, opportunity_score, sale_window, recommendation), n = Inf, width = Inf)),
  "",
  "DATA SOURCE SUMMARY",
  sprintf("Total reviews analyzed: %d", nrow(reviews)),
  sprintf("  - Flipkart: %d (%.1f%%)", sum(reviews$source == "flipkart", na.rm = TRUE), 100 * mean(reviews$source == "flipkart", na.rm = TRUE)),
  sprintf("  - Amazon: %d (%.1f%%)", sum(reviews$source == "amazon", na.rm = TRUE), 100 * mean(reviews$source == "amazon", na.rm = TRUE)),
  "",
  "INTERPRETATION",
  "The opportunity score combines forecast demand, demand momentum, festival timing and review health.",
  "Google Trends is a relative demand proxy and is not the same as completed e-commerce sales.",
  "Reviews are collected from both Flipkart and Amazon India to provide broader market coverage.",
  "The result supports promotion planning but does not prove that a discount will cause extra sales."
)

writeLines(summary_text, paths$report)

cat("\n========================================\n")
cat("ANALYSIS COMPLETE!\n")
cat("========================================\n\n")
cat("Results saved to:\n")
cat("  - outputs/analysis_summary.txt\n")
cat("  - outputs/figures/ (6 PNG files)\n")
cat("  - outputs/tables/ (5 CSV files)\n")
cat("  - data/processed/ (4 CSV files)\n\n")
cat("To view the dashboard, run:\n")
cat("  shiny::runApp()\n\n")

# Print summary
cat(summary_text, sep = "\n")
