# Simple test run without Google Trends scraping
cat("Starting test run...\n")

source("R/setup.R")
cat("Setup loaded\n")

source("config.R")
cat("Config loaded\n")

source("R/scrape.R")
cat("Scrape functions loaded\n")

source("R/text_analysis.R")
cat("Text analysis loaded\n")

source("R/forecast.R")
cat("Forecast functions loaded\n")

source("R/plots.R")
cat("Plot functions loaded\n")

# Create directories
for (folder in c("data/raw", "data/processed", "outputs/tables", paths$figures)) {
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
}
cat("Directories created\n")

# Load existing data
cat("Loading Flipkart data...\n")
flipkart_data <- if (file.exists(paths$flipkart_reviews_raw)) {
  data <- read_csv(paths$flipkart_reviews_raw, show_col_types = FALSE)
  if (nrow(data) > 0 && !"source" %in% names(data)) {
    data$source <- "flipkart"
  }
  data
} else {
  tibble()
}
cat(sprintf("Loaded %d Flipkart reviews\n", nrow(flipkart_data)))

# Skip Amazon for now
reviews_raw <- flipkart_data
write_csv(reviews_raw, paths$reviews_raw)
cat("Reviews combined\n")

cat("Loading trends data...\n")
trends <- read_csv(paths$trends_raw, show_col_types = FALSE) |>
  mutate(date = as.Date(date))
cat(sprintf("Loaded %d trend records\n", nrow(trends)))

cat("Processing reviews...\n")
reviews <- reviews_raw |>
  mutate(review_date = as.Date(review_date)) |>
  prepare_reviews() |>
  score_sentiment()
write_csv(reviews, paths$reviews_clean)
cat(sprintf("Processed %d reviews\n", nrow(reviews)))

cat("\nTest run completed successfully!\n")
cat(sprintf("- Flipkart reviews: %d\n", nrow(flipkart_data)))
cat(sprintf("- Usable reviews: %d\n", nrow(reviews)))
cat(sprintf("- Trend records: %d\n", nrow(trends)))
