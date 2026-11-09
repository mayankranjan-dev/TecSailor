# Changelog - Amazon Integration

## Overview
Extended the TecSailor project to scrape product reviews from **Amazon India** in addition to existing Flipkart data collection. This provides broader market coverage and more comprehensive customer sentiment analysis.

## Changes Made

### 1. Configuration Updates (`config.R`)
- **Added Amazon product information** to brands table:
  - `amazon_product`: Product names for each brand on Amazon
  - `amazon_asin`: Amazon Standard Identification Numbers for each product
  - Renamed `product` to `flipkart_product` for clarity
  - Renamed `review_url` to `flipkart_url` for clarity

- **New configuration flags:**
  - `scrape_amazon = TRUE`: Enable/disable Amazon scraping
  - `scrape_flipkart = TRUE`: Enable/disable Flipkart scraping

- **Updated file paths:**
  - `flipkart_reviews_raw`: Separate storage for Flipkart reviews
  - `amazon_reviews_raw`: Separate storage for Amazon reviews
  - `reviews_raw`: Combined reviews from both sources

### 2. Scraping Functions (`R/scrape.R`)
- **New Amazon scraping functions:**
  - `scrape_amazon_reviews()`: Main function to collect Amazon reviews
  - `scrape_amazon_page()`: Parses individual Amazon review pages using HTML selectors
  - `parse_amazon_date()`: Converts Amazon date format ("Reviewed in India on DD Month YYYY")

- **Updated existing functions:**
  - Modified `scrape_reviews()` to use new column names (`flipkart_url`, `flipkart_product`)
  - Added `source` field to track data origin ("flipkart" or "amazon")
  - Enhanced logging with source tracking

### 3. Data Collection Pipeline (`main.R`)
- **Separate scraping workflows:**
  - Flipkart reviews collected to `data/raw/flipkart_reviews.csv`
  - Amazon reviews collected to `data/raw/amazon_reviews.csv`
  - Both sources combined into `data/raw/combined_reviews.csv`

- **Enhanced data quality metrics:**
  - Now calculated separately for each source (Flipkart, Amazon, Combined)
  - Allows comparison of scraping success rates between platforms
  - Tracks verified purchase rates by platform
  - Monitors lexicon coverage by platform

- **Updated summary report:**
  - Shows data quality breakdown by source
  - Includes review count and percentage from each platform
  - Notes multi-source collection in interpretation

### 4. Documentation Updates

#### README.md
- Added Amazon India as a data source
- Updated "What the tool does" section to mention multi-platform collection
- Added note about platform differences in limitations section

#### PROJECT_CONTEXT.md
- **New section:** Complete Amazon India data source documentation
- **Updated scraping section:** Detailed explanation of both platforms
- **Enhanced data quality metrics:** Description of source-based breakdown
- **Configuration section:** Documented new flags and settings
- **Limitations:** Added note about platform demographic differences

### 5. Amazon Products Selected

| Brand | Product | ASIN |
|-------|---------|------|
| boAt | Airdopes 141 | B0CQDFLWBQ |
| Noise | Buds Connect | B0CVCLS3RG |
| Boult | AirBass Propods | B0CSHVN6K3 |
| realme | Buds Air 3 | B0BYQ53CHJ |
| JBL | Tune 130NC | B0CGQ2F98M |

*Note: Different products than Flipkart to expand coverage across product lines*

## Technical Details

### Amazon Scraping Approach
- **Method:** HTML parsing using rvest
- **Selectors:** Uses Amazon's data-hook attributes for reliable extraction
- **Rate limiting:** Respects `request_pause` setting (default 0.6 seconds)
- **Error handling:** Graceful failure with logging
- **User agent:** Desktop browser identification

### Data Fields Extracted
Both platforms now provide:
- Review ID (unique identifier)
- Rating (1-5 stars)
- Title
- Review text
- Review date (parsed to Date object)
- Verified purchase status
- Helpful votes count
- Source platform ("flipkart" or "amazon")

### Compatibility
- All existing analysis functions work unchanged
- Text analysis, sentiment scoring, and forecasting operate on combined dataset
- Source field allows optional platform-specific analysis

## How to Use

### Run with both sources (default):
```r
source("main.R")
```

### Run with only Amazon:
```r
# In config.R, set:
scrape_flipkart <- FALSE
scrape_amazon <- TRUE
refresh_data <- TRUE

source("main.R")
```

### Run with only Flipkart (original behavior):
```r
# In config.R, set:
scrape_flipkart <- TRUE
scrape_amazon <- FALSE
refresh_data <- TRUE

source("main.R")
```

### Refresh all data:
```r
# In config.R, set:
refresh_data <- TRUE
scrape_flipkart <- TRUE
scrape_amazon <- TRUE

source("main.R")
```

## Benefits

1. **Larger dataset:** More reviews = better sentiment analysis reliability
2. **Platform comparison:** Can analyze if customer sentiment differs between platforms
3. **Broader coverage:** Different products = more comprehensive brand representation
4. **Redundancy:** If one platform has scraping issues, other still provides data
5. **Market insight:** Understanding multi-platform customer base

## Future Enhancements

Potential additions:
- Add more e-commerce platforms (Myntra, Croma, Reliance Digital)
- Platform-specific visualizations in Shiny dashboard
- Comparative sentiment analysis by platform
- Price tracking from product pages
- Product availability monitoring
