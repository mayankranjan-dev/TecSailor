# Project Context

## Project Title

**TecSailor: Demand Forecasting and Sale-Timing Analysis for the Indian Wireless-Audio Market**

## Purpose

The project builds a small market-intelligence tool in R. It helps a consumer-technology brand compare market interest, understand customer feedback, forecast demand and identify possible sale periods.

## Case Study

**boAt** is the main brand because it is closely associated with India's affordable wireless-audio market. **Noise, Boult, realme and JBL** provide comparison points.

## Research Question

Can search behaviour, e-commerce reviews, customer sentiment and Indian festival timing identify useful promotional windows for a technology brand?

---

## Data Sources

### 1. Google Trends Data
- **Source:** [Google Trends](https://trends.google.com/trends/)
- **Coverage:** 5 years of weekly search interest data for India
- **Metric:** Relative popularity (normalized 0-100 scale, not absolute search volumes)
- **Search Terms:**
  - boAt: "boat earbuds"
  - Noise: "noise earbuds"
  - Boult: "boult earbuds"
  - realme: "realme earbuds"
  - JBL: "jbl earbuds"
- **File:** `data/raw/google_trends.csv`

### 2. Flipkart Product Reviews
- **Source:** [Flipkart](https://www.flipkart.com/) - public product review pages
- **Collection Method:** Web scraping via `R/scrape.R` - `scrape_reviews()` function
- **Products Scraped:**
  - boAt Airdopes 131
  - Noise Buds VS102 Neo
  - Boult AirBass TrueBuds
  - realme Buds Wireless 5
  - JBL Wave Beam
- **Pages per Brand:** 20 (configurable in `config.R`)
- **Fields Captured:** rating (1-5 stars), title, review text, date, verified purchase status, helpful votes, city, state
- **Privacy:** User names are NOT stored
- **File:** `data/raw/flipkart_reviews.csv`
- **Log File:** `data/raw/flipkart_scrape_log.csv`

### 3. Amazon India Product Reviews
- **Source:** [Amazon India](https://www.amazon.in/) - public product review pages
- **Collection Method:** Web scraping via `R/scrape.R` - `scrape_amazon_reviews()` function
- **Products Scraped:**
  - boAt Airdopes 141 (ASIN: B0CQDFLWBQ)
  - Noise Buds Connect (ASIN: B0CVCLS3RG)
  - Boult AirBass Propods (ASIN: B0CSHVN6K3)
  - realme Buds Air 3 (ASIN: B0BYQ53CHJ)
  - JBL Tune 130NC (ASIN: B0CGQ2F98M)
- **Pages per Brand:** 20 (configurable in `config.R`)
- **Fields Captured:** rating (1-5 stars), title, review text, date, verified purchase status, helpful votes
- **Privacy:** User names are NOT stored
- **File:** `data/raw/amazon_reviews.csv`
- **Log File:** `data/raw/amazon_scrape_log.csv`

### 4. Combined Reviews Dataset
- **File:** `data/raw/combined_reviews.csv`
- **Content:** Merged data from both Flipkart and Amazon with source tracking
- **Source Field:** Each review tagged with "flipkart" or "amazon" for analysis comparison

---

## Project Structure

### Core R Scripts

#### `R/setup.R`
- Package installation and loading
- Sets up the R environment with required libraries

#### `R/scrape.R`
- **Functions:**
  - `scrape_reviews()`: Collects Flipkart reviews for all configured brands
  - `scrape_review_page()`: Parses a single Flipkart review page using Flipkart's INITIAL_STATE JSON
  - `scrape_amazon_reviews()`: Collects Amazon India reviews for all configured brands
  - `scrape_amazon_page()`: Parses a single Amazon review page using HTML selectors
  - `scrape_trends()`: Fetches Google Trends data for India
  - `parse_review_date()`: Converts Flipkart relative dates ("2 days ago") to actual dates
  - `parse_amazon_date()`: Converts Amazon date format ("Reviewed in India on 15 October 2023")
- **Configuration:** 
  - Respects `request_pause` (0.6 seconds default) between requests
  - Separate flags for `scrape_flipkart` and `scrape_amazon` in config
  - Uses appropriate user agent headers for both platforms
- **Caching:** Only runs if `refresh_data = TRUE` or raw files don't exist
- **Error Handling:** Gracefully handles failed page requests, logs all attempts

#### `R/text_analysis.R`
- **Functions:**
  - `clean_text()`: Normalizes text (lowercase, expands contractions, removes URLs/punctuation)
  - `prepare_reviews()`: Filters, deduplicates, and creates sentiment labels from ratings
  - `score_sentiment()`: Applies Bing lexicon with negation handling
  - `classification_metrics()`: Calculates precision, recall, F1, accuracy, balanced accuracy
  - `analyse_aspects()`: Maps words to product aspects using predefined dictionary
- **Sentiment Lexicon:** Bing lexicon (positive/negative word classifications)
- **Negation Handling:** Flips sentiment for words preceded by "not", "no", "never", "without", "hardly", "neither", "nor"
- **Aspect Dictionary:** Maps words to 8 product aspects: Sound, Battery, Calling, Connectivity, Comfort, Value, Build quality, Delivery, Support

#### `R/forecast.R`
- **Functions:**
  - `evaluate_brand()`: Tests 3 models on holdout data (26 weeks)
  - `build_forecast()`: Refits best model to full data and forecasts 52 weeks ahead
  - `score_sale_weeks()`: Calculates opportunity scores for each forecast week
  - `select_sale_windows()`: Picks top N non-overlapping sale windows (minimum 21 days apart)
- **Models Tested:**
  1. Seasonal naive (baseline)
  2. STL + ETS (seasonal decomposition + exponential smoothing)
  3. ARIMA (auto.arima with seasonal components)
- **Festival Calendar:** Republic Day (Jan 26), Independence Day (Aug 15), Diwali (Oct/Nov variable dates) for years 2022-2027

#### `R/plots.R`
- **Functions:**
  - `plot_market_trends()`: Line chart comparing brand search interest over time
  - `plot_forecasts()`: Historical data + 52-week forecast with confidence intervals
  - `plot_sale_scores()`: Opportunity scores timeline with festival markers
  - `plot_sentiment()`: Sentiment distribution by brand
  - `plot_aspects()`: Product aspect mentions by brand and sentiment
  - `plot_model_metrics()`: Forecast accuracy comparison (RMSE, MAE, WAPE)
  - `save_chart()`: Wrapper to save plots as PNG files

### Configuration

#### `config.R`
- **Brand Configuration:** 5 brands with trend terms, Flipkart products, Amazon products, review URLs, and ASINs
- **Scraping Settings:**
  - `review_pages = 20` (per platform)
  - `request_pause = 0.6` seconds
  - `refresh_data = FALSE` (uses cached data by default)
  - `scrape_amazon = TRUE` (enable/disable Amazon scraping)
  - `scrape_flipkart = TRUE` (enable/disable Flipkart scraping)
- **Forecast Settings:**
  - `forecast_weeks = 52`
  - `test_weeks = 26` (holdout period)
  - `project_seed = 2025` (reproducibility)
- **File Paths:** Centralized path management for all inputs/outputs including separate paths for Flipkart and Amazon raw data

### Entry Points

#### `main.R`
- **Purpose:** Master orchestration script
- **Workflow:**
  1. Sources all R scripts and configuration
  2. Creates directory structure
  3. Collects or loads Flipkart reviews (if enabled)
  4. Collects or loads Amazon reviews (if enabled)
  5. Combines reviews from both sources with source tracking
  6. Processes reviews and scores sentiment
  7. Evaluates sentiment classification metrics
  8. Runs forecast backtests and selects best models
  9. Generates 52-week forecasts
  10. Calculates opportunity scores and sale recommendations
  11. Generates quality metrics by data source
  12. Generates all visualizations
  13. Writes analysis summary report with source breakdown

#### `app.R`
- **Purpose:** Shiny interactive dashboard
- **Launch:** `shiny::runApp()`
- **Features:** Visual display of trends, forecasts, sentiment, and recommendations

#### `run_tests.R`
- **Purpose:** Runs test suite
- **Test File:** `tests/test_project.R`

---

## Methodology

### 1. Sentiment Analysis

#### Rating-Based Sentiment Labels
- **Negative:** 1-2 stars
- **Neutral:** 3 stars
- **Positive:** 4-5 stars

These rating-derived labels serve as ground truth for evaluation.

#### Lexicon-Based Prediction
- Uses **Bing sentiment lexicon** (categorizes words as positive/negative)
- **Sentiment Score Calculation:**
  - +1 for each positive word
  - -1 for each negative word
  - Flips sign if word is preceded by negation words (within 2-word window)
- **Predicted Sentiment:**
  - Score < 0 → Negative
  - Score > 0 → Positive
  - Score = 0 → Neutral

### 2. Forecast Methodology

#### Train-Test Split
- **Training:** All data except final 26 weeks
- **Test:** Final 26 weeks (holdout)

#### Models Compared
1. **Seasonal Naive:** Simple baseline using last year's pattern
2. **STL + ETS:** Seasonal-Trend decomposition using LOESS + Exponential Smoothing State space model
3. **ARIMA:** Auto-fitted ARIMA with seasonal components

#### Model Selection
- Each brand's 3 models are backtested on the 26-week holdout
- Model with **lowest RMSE** is selected
- Selected model is refit to full dataset
- 52-week forecast is generated with 80% and 95% confidence intervals

### 3. Sale Opportunity Scoring

#### Score Components (0-100 scale)
| Component | Weight | Description |
|-----------|--------|-------------|
| **Forecast Demand** | 55% | Normalized forecast value for the week |
| **Demand Momentum** | 20% | Week-over-week change in forecast |
| **Festival Proximity** | 15% | 1 if major festival within 3 weeks, 0 otherwise |
| **Sentiment Health** | 10% | Brand's share of positive reviews |

#### Recommendation Logic
- **Strong sale window:** Score ≥ 75
- **Good sale window:** Score ≥ 60
- **Monitor demand:** Score ≥ 45
- **Low priority:** Score < 45

#### Spacing Rule
- Recommended windows must be **at least 21 days apart**
- Prevents clustering all recommendations around single demand peak
- Top 5 non-overlapping windows selected per brand

---

## Metrics Evaluated

### 1. Data Quality Metrics

**File:** `outputs/tables/data_quality.csv`

Now broken down by data source (Flipkart, Amazon, Combined):

| Metric | Description |
|--------|-------------|
| Source | Data source identifier (flipkart/amazon/combined) |
| Requested pages | Total review pages requested from that source |
| Successful pages | Pages successfully scraped |
| Success rate | Percentage of successful scrapes |
| Raw reviews | Total reviews collected before cleaning |
| Usable reviews | Reviews after cleaning and deduplication |
| Usable share | Percentage of raw reviews that are usable |
| Verified share | Percentage of verified purchase reviews |
| Lexicon coverage | Percentage of reviews containing sentiment lexicon words |

This allows comparison of data quality between Flipkart and Amazon platforms.

### 2. Sentiment Classification Metrics

**File:** `outputs/tables/sentiment_metrics.csv`

**Overall Performance:**
- **Accuracy:** 88.2% - percentage of correct predictions
- **Balanced Accuracy:** 66.1% - average recall across classes (handles class imbalance)
- **Macro Precision:** 68.5% - average precision across classes
- **Macro Recall:** 66.1% - average recall across classes
- **Macro F1:** 67.2% - harmonic mean of precision and recall

**Per-Class Performance:**

| Class | Precision | Recall | F1 |
|-------|-----------|--------|-----|
| **Negative** | 94.4% | 85.0% | 89.5% |
| **Neutral** | 20.0% | 16.7% | 18.2% |
| **Positive** | 91.2% | 96.7% | 93.9% |

**Interpretation:**
- Lexicon performs excellently on negative and positive reviews
- Neutral reviews are hard to classify (low scores typical for this class)
- High overall accuracy (88.2%) indicates lexicon-based approach is viable

**Additional File:** `outputs/tables/sentiment_confusion.csv` contains full confusion matrix

### 3. Forecast Accuracy Metrics

**File:** `outputs/tables/forecast_metrics.csv`

Three metrics used to compare models:
- **MAE (Mean Absolute Error):** Average absolute difference between forecast and actual
- **RMSE (Root Mean Square Error):** Square root of average squared errors (penalizes large errors more)
- **WAPE (Weighted Absolute Percentage Error):** Sum of absolute errors divided by sum of actuals

**Best Model by Brand (lowest RMSE):**

| Brand | Best Model | MAE | RMSE | WAPE |
|-------|------------|-----|------|------|
| **Boult** | ARIMA | 1.31 | 1.70 | 0.109 |
| **JBL** | STL + ETS | 2.46 | 3.85 | 0.173 |
| **Noise** | STL + ETS | 10.79 | 13.55 | 0.210 |
| **boAt** | Seasonal naive | 5.15 | 7.38 | 0.092 |
| **realme** | STL + ETS | 4.62 | 5.94 | 0.165 |

**Key Findings:**
- No single model dominates across all brands
- ARIMA best for Boult (stable pattern)
- STL + ETS best for JBL, Noise, realme (seasonal decomposition works well)
- Seasonal naive surprisingly best for boAt (simple pattern or limited training data)

**Visualization:** `outputs/figures/06_forecast_evaluation.png`

### 4. Product Aspect Analysis

**File:** `outputs/tables/review_aspects.csv`

**Aspects Tracked:**
- Sound (sound, audio, bass, music)
- Battery (battery, charge, charging)
- Calling (call, calling, mic, voice)
- Connectivity (connect, connection, bluetooth)
- Comfort (fit, comfort, ear, pain)
- Value (price, money, worth, expensive)
- Build quality (quality, build, design)
- Delivery (delivery, delivered, package)
- Support (warranty, service, replace, return)

Mentions counted by brand, aspect, and sentiment (negative/neutral/positive).

**Visualization:** `outputs/figures/05_review_aspects.png`

---

## Output Files

### Processed Data

| File | Description |
|------|-------------|
| `data/processed/reviews_scored.csv` | Cleaned reviews with sentiment scores and predictions |
| `data/processed/demand_forecast.csv` | 52-week forecasts for all brands with confidence intervals |
| `data/processed/sale_recommendations.csv` | Top 5 recommended sale windows per brand |
| `data/processed/all_sale_scores.csv` | Full opportunity scores for all forecast weeks |

### Tables

| File | Description |
|------|-------------|
| `outputs/tables/data_quality.csv` | Scraping success and data coverage metrics |
| `outputs/tables/forecast_metrics.csv` | MAE, RMSE, WAPE for all 15 model-brand combinations |
| `outputs/tables/sentiment_metrics.csv` | Precision, recall, F1, accuracy by sentiment class |
| `outputs/tables/sentiment_confusion.csv` | Confusion matrix for sentiment predictions |
| `outputs/tables/review_aspects.csv` | Product aspect mentions by brand and sentiment |

### Figures

| File | Description |
|------|-------------|
| `outputs/figures/01_market_trends.png` | Historical search interest comparison (5 years) |
| `outputs/figures/02_demand_forecast.png` | 52-week forecasts with historical context |
| `outputs/figures/03_sale_opportunity.png` | Opportunity scores timeline with festival markers |
| `outputs/figures/04_customer_sentiment.png` | Sentiment distribution by brand |
| `outputs/figures/05_review_aspects.png` | Product aspect mentions breakdown |
| `outputs/figures/06_forecast_evaluation.png` | Model accuracy comparison |

### Reports

| File | Description |
|------|-------------|
| `outputs/analysis_summary.txt` | Human-readable summary of key findings |

---

## Key Findings (From Latest Run)

### Top boAt Sale Windows
1. **2027-10-03** - Score: 83.3 (Strong sale window, Regular week)
2. **2027-08-08** - Score: 76.9 (Strong sale window, Independence Day)
3. **2027-05-30** - Score: 65.1 (Good sale window, Regular week)

### Forecast Performance Summary
- Best overall accuracy: **Boult with ARIMA** (RMSE: 1.70, WAPE: 10.9%)
- Worst performance: **Noise** (all models, likely due to high volatility)
- **boAt** surprisingly favors simple seasonal naive baseline

### Sentiment Analysis Summary
- **88.2%** overall accuracy
- Lexicon excels at detecting positive (96.7% recall) and negative (85.0% recall) reviews
- Neutral class challenging (only 16.7% recall) - typical limitation of lexicon approaches

---

## Interpretation & Limitations

### What This Tool Provides
- Planning indicators for promotion timing
- Relative demand comparisons between brands
- Customer sentiment trends
- Data-driven scheduling suggestions

### What This Tool Does NOT Provide
- Causal proof that a sale will increase revenue
- Absolute sales volume predictions
- Actual unit sales or revenue forecasts
- ROI calculations

### Key Limitations
1. **Google Trends measures search interest, not purchases**
2. **Reviews ≠ sales volume** (only customers who leave reviews)
3. **Single product per brand per platform** doesn't represent full portfolio
4. **No actual transaction data** (units sold, prices, margins, inventory)
5. **No historical promotion data** (past campaign dates, discounts, advertising spend)
6. **Sentiment limitations:** sarcasm, mixed opinions, multilingual reviews
7. **Festival markers** indicate timing but not campaign effectiveness
8. **Platform differences:** Flipkart and Amazon may have different customer demographics and review patterns

### Future Enhancements
To improve recommendations, the model would need:
- Weekly sales volume data
- Historical promotion dates and discount percentages
- Advertising expenditure data
- Inventory levels
- Competitor pricing data
- Margin and profitability metrics

---

## Reproducibility

### Random Seed
- Fixed seed: `2025` (set in `config.R`)
- Ensures consistent results across runs

### Data Caching
- Raw data saved after first collection
- Set `refresh_data = FALSE` to use cached data
- Avoids repeated web requests during development/testing

### Testing
- **Test suite:** `tests/test_project.R`
- **Run:** `source("run_tests.R")`
- **Coverage:** Text processing, sentiment labels, metric calculations, opportunity score ranges, data integrity, forecast outputs, dashboard object creation

---

## Git Configuration

### Version Control Setup
- **Files:** `.gitignore`, `.gitattributes`, `TecSailor.Rproj`
- **Tracked:** Source code, data files, result tables, figures
- **Ignored:** `.Rproj.user/`, `.Rhistory`, `.RData`, `.Ruserdata`, temporary logs
- **Remote:** Not configured (local repository only, no automatic pushes)

---

## How to Run

### Full Analysis Pipeline
```r
source("main.R")
```

First run installs packages and collects data. Subsequent runs use cached data.

### Interactive Dashboard
```r
shiny::runApp()
```

### Test Suite
```r
source("run_tests.R")
```

### Force Data Refresh
Edit `config.R`:
```r
refresh_data <- TRUE
scrape_flipkart <- TRUE  # Set to FALSE to skip Flipkart
scrape_amazon <- TRUE    # Set to FALSE to skip Amazon
```
Then run `source("main.R")`

---

## Dependencies

All packages installed automatically via `R/setup.R` on first run. Key libraries:
- **Data manipulation:** `tidyverse`, `dplyr`, `tidyr`, `readr`
- **Text analysis:** `tidytext`, `textdata` (Bing lexicon)
- **Time series:** `forecast`, `tseries`
- **Web scraping:** `rvest`, `httr`
- **Trends data:** `gtrendsR`
- **Visualization:** `ggplot2`
- **Dashboard:** `shiny`, `DT`

---

**Last Updated:** Generated from project run on 2026-10-31 23:33