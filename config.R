brands <- tibble(
  brand = c("boAt", "Noise", "Boult", "realme", "JBL"),
  trend_term = c("boat earbuds", "noise earbuds", "boult earbuds", "realme earbuds", "jbl earbuds"),
  flipkart_product = c("Airdopes 131", "Buds VS102 Neo", "AirBass TrueBuds", "Buds Wireless 5", "Wave Beam"),
  amazon_product = c("Airdopes 141", "Buds Connect", "AirBass Propods", "Buds Air 3", "Tune 130NC"),
  flipkart_url = c(
    "https://www.flipkart.com/boat-airdopes-131-bluetooth-headset/product-reviews/itm63eaf8c589b2b?pid=ACCFSDGXX3S6DVBG",
    "https://www.flipkart.com/noise-buds-vs102-neo-40-hrs-playtime-environmental-cancellation-quad-mic-bluetooth/product-reviews/itm77f87105a246e",
    "https://www.flipkart.com/boult-audio-airbass-truebuds-bluetooth-headset/product-reviews/itm673653cf1da5b?pid=ACCFT7GYFKYADVCV",
    "https://www.flipkart.com/realme-buds-wireless-5-50db-anc-360-degree-spatial-audio-ip55-38hrs-playback-bluetooth/product-reviews/itm98edfd0118e5a",
    "https://www.flipkart.com/jbl-wave-beam-tws-32hr-playtime-ip54-smart-ambient-talkthru-mode-app-bluetooth/product-reviews/itm90c7bd93872cc"
  ),
  amazon_asin = c(
    "B0CQDFLWBQ",  # boAt Airdopes 141
    "B0CVCLS3RG",  # Noise Buds Connect
    "B0CSHVN6K3",  # Boult AirBass Propods
    "B0BYQ53CHJ",  # realme Buds Air 3
    "B0CGQ2F98M"   # JBL Tune 130NC
  )
)

review_pages <- 20
request_pause <- 0.6
refresh_data <- FALSE
scrape_amazon <- FALSE
scrape_flipkart <- FALSE
forecast_weeks <- 52
test_weeks <- 26
project_seed <- 2025

paths <- list(
  flipkart_reviews_raw = "data/raw/flipkart_reviews.csv",
  amazon_reviews_raw = "data/raw/amazon_reviews.csv",
  reviews_raw = "data/raw/combined_reviews.csv",
  trends_raw = "data/raw/google_trends.csv",
  reviews_clean = "data/processed/reviews_scored.csv",
  forecasts = "data/processed/demand_forecast.csv",
  recommendations = "data/processed/sale_recommendations.csv",
  metrics = "outputs/tables/forecast_metrics.csv",
  sentiment_metrics = "outputs/tables/sentiment_metrics.csv",
  aspects = "outputs/tables/review_aspects.csv",
  figures = "outputs/figures",
  report = "outputs/analysis_summary.txt"
)
