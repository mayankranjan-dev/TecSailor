# TecSailor - Main Analysis Script
# This script processes review data, runs demand forecasts, and generates visualizations

cat("========================================\n")
cat("TECSAILOR - ANALYSIS PIPELINE\n")
cat("========================================\n\n")

# Load required scripts
cat("[Step 1/8] Loading setup and configuration...\n")
source("R/setup.R")
source("config.R")
source("R/scrape.R")
source("R/text_analysis.R")
source("R/forecast.R")
source("R/plots.R")

# Create directories
for (folder in c("data/raw", "data/processed", "outputs/tables", paths$figures)) {
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
}

# Data collection (only if refresh_data = TRUE)
cat("[Step 2/8] Checking data collection settings...\n")
if (refresh_data || !file.exists(paths$flipkart_reviews_raw)) {
  if (scrape_flipkart) {
    cat("   Collecting Flipkart reviews (this may take 10-15 minutes)...\n")
    scraped <- scrape_reviews(brands, review_pages, request_pause)
    write_csv(scraped$data, paths$flipkart_reviews_raw)
    write_csv(scraped$log, "data/raw/flipkart_scrape_log.csv")
    cat(sprintf("   ✓ Collected %d Flipkart reviews\n", nrow(scraped$data)))
  }
} else {
  cat("   Using cached Flipkart data\n")
}

if (refresh_data || !file.exists(paths$amazon_reviews_raw)) {
  if (scrape_amazon) {
    cat("   Collecting Amazon reviews (this may take 10-15 minutes)...\n")
    amazon_scraped <- scrape_amazon_reviews(brands, review_pages, request_pause)
    write_csv(amazon_scraped$data, paths$amazon_reviews_raw)
    write_csv(amazon_scraped$log, "data/raw/amazon_scrape_log.csv")
    cat(sprintf("   ✓ Collected %d Amazon reviews\n", nrow(amazon_scraped$data)))
  }
} else {
  cat("   Skipping Amazon data collection\n")
}

if (refresh_data || !file.exists(paths$trends_raw)) {
  cat("   Collecting Google Trends data (this may take 2-3 minutes)...\n")
  trend_data <- scrape_trends(brands)
  write_csv(trend_data, paths$trends_raw)
  cat("   ✓ Collected trend data\n")
} else {
  cat("   Using cached Google Trends data\n")
}

# Load and combine review data
cat("[Step 3/8] Loading review data...\n")
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
  stop("ERROR: No review data found! Please check data/raw/ folder or set refresh_data=TRUE in config.R")
}

write_csv(reviews_raw, paths$reviews_raw)
cat(sprintf("   Loaded %d reviews (%d Flipkart, %d Amazon)\n",
             nrow(reviews_raw), nrow(flipkart_data), nrow(amazon_data)))

# Load trends
trends <- read_csv(paths$trends_raw, show_col_types = FALSE) |>
  mutate(date = as.Date(date))
cat(sprintf("   Loaded %d trend records\n", nrow(trends)))

# Process reviews
cat("[Step 4/8] Processing reviews and sentiment analysis...\n")
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
cat(sprintf("   Overall sentiment accuracy: %.1f%%\n", 100 * sentiment_metrics$accuracy[1]))

# Aspect analysis
aspects <- analyse_aspects(reviews)
write_csv(aspects, paths$aspects)
cat(sprintf("   Analyzed %d product aspect mentions\n", nrow(aspects)))

# Forecasting
cat("[Step 5/8] Running demand forecasts (this may take 3-5 minutes)...\n")
forecast_metrics <- trends |>
  group_split(brand) |>
  map_dfr(evaluate_brand, holdout = test_weeks)
write_csv(forecast_metrics, paths$metrics)
cat("   ✓ Forecast backtest complete\n")

best_models <- forecast_metrics |>
  group_by(brand) |>
  slice_min(RMSE, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(brand, model)

cat("   Building 52-week forecasts...\n")
forecasts <- trends |>
  group_split(brand) |>
  map_dfr(function(data) {
    chosen <- best_models$model[best_models$brand == data$brand[1]]
    build_forecast(data, chosen, forecast_weeks)
  })
write_csv(forecasts, paths$forecasts)
cat(sprintf("   ✓ Generated %d weeks of forecasts per brand\n", forecast_weeks))

# Sale opportunity scoring
cat("[Step 6/8] Calculating sale opportunity scores...\n")
sale_scores <- score_sale_weeks(forecasts, reviews)
recommendations <- sale_scores |>
  group_split(brand) |>
  map_dfr(select_sale_windows, n = 5) |>
  arrange(brand, desc(opportunity_score))
write_csv(sale_scores, "data/processed/all_sale_scores.csv")
write_csv(recommendations, paths$recommendations)
cat(sprintf("   ✓ Identified %d sale windows\n", nrow(recommendations)))

# Data quality metrics
cat("[Step 7/8] Calculating data quality metrics...\n")
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
          nrow(reviews_raw)
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
  quality <- tibble(
    source = "combined",
    requested_pages = if(nrow(scrape_log) > 0) nrow(scrape_log) else NA_real_,
    successful_pages = if(nrow(scrape_log) > 0) sum(scrape_log$rows > 0, na.rm = TRUE) else NA_real_,
    success_rate = if(nrow(scrape_log) > 0) mean(scrape_log$rows > 0, na.rm = TRUE) else NA_real_,
    raw_reviews = nrow(reviews_raw),
    usable_reviews = nrow(reviews),
    usable_share = nrow(reviews) / nrow(reviews_raw),
    verified_share = mean(reviews$verified, na.rm = TRUE),
    lexicon_coverage = mean(reviews$lexicon_hits > 0, na.rm = TRUE)
  )
}

write_csv(quality, "outputs/tables/data_quality.csv")

# Generate visualizations
cat("[Step 8/8] Creating visualizations...\n")
save_chart(plot_market_trends(trends), "01_market_trends.png", 11, 6)
cat("   ✓ Market trends\n")
save_chart(plot_forecasts(trends, forecasts), "02_demand_forecast.png", 11, 8)
cat("   ✓ Demand forecast\n")
save_chart(plot_sale_scores(sale_scores), "03_sale_opportunity.png", 11, 8)
cat("   ✓ Sale opportunity\n")
save_chart(plot_sentiment(reviews), "04_customer_sentiment.png", 9, 6)
cat("   ✓ Customer sentiment\n")
save_chart(plot_aspects(aspects), "05_review_aspects.png", 11, 8)
cat("   ✓ Review aspects\n")
save_chart(plot_model_metrics(forecast_metrics), "06_forecast_evaluation.png", 10, 7)
cat("   ✓ Forecast evaluation\n")

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
  "Reviews are collected from Flipkart and Amazon India (when available) for broader market coverage.",
  "The result supports promotion planning but does not prove that a discount will cause extra sales."
)

writeLines(summary_text, paths$report)

cat("\n========================================\n")
cat("✓ ANALYSIS COMPLETE!\n")
cat("========================================\n\n")
cat("Results saved to:\n")
cat("  - outputs/analysis_summary.txt (text report)\n")
cat("  - outputs/figures/ (6 PNG visualizations)\n")
cat("  - outputs/tables/ (5 CSV metric files)\n")
cat("  - data/processed/ (4 processed datasets)\n\n")
cat("Next steps:\n")
cat("  1. Check outputs/analysis_summary.txt for full report\n")
cat("  2. View visualizations in outputs/figures/\n")
cat("  3. Launch dashboard with: shiny::runApp()\n\n")

# Print summary to console
cat("=" %rep% 50, "\n", sep = "")
cat(summary_text, sep = "\n")
cat("=" %rep% 50, "\n", sep = "")

cat("\n✓ All done! Dashboard ready to launch.\n\n")
