# TecSailor

TecSailor is an R project for studying demand and promotion timing in the Indian wireless-audio market. boAt is the main case-study brand. Noise, Boult, realme and JBL are included as competitors.

The project combines Google search interest, Flipkart customer reviews, sentiment analysis, demand forecasting and a Shiny dashboard.

## Business question

When should a technology brand schedule an online sale based on expected demand, demand momentum, Indian festival periods and customer sentiment?

The result is a planning indicator. It does not claim that a discount will cause additional sales because public data does not include orders, advertising expenditure, inventory or profit margins.

## Data

Google Trends provides five years of weekly Indian search interest. The values show relative popularity and do not represent units sold. 

**Flipkart** and **Amazon India** review pages provide public ratings, review text, dates, verified-purchase status and helpful votes. The project collects reviews from both platforms to provide broader market coverage and more comprehensive customer sentiment analysis.

The project collects reviews for one wireless-audio product from each selected brand on both platforms. User names are not stored.

Sources:

- [Google Trends](https://trends.google.com/trends/)
- [Google Trends documentation](https://developers.google.com/search/docs/monitor-debug/trends-start)
- [Flipkart](https://www.flipkart.com/)
- [Amazon India](https://www.amazon.in/)

## What the tool does

- compares brand search interest
- collects reviews from multiple e-commerce platforms (Flipkart & Amazon India)
- forecasts 52 weeks of demand
- tests seasonal-naive, STL-plus-ETS and ARIMA models
- evaluates forecasts with MAE, RMSE and WAPE
- classifies review sentiment using one-to-five-star ratings
- checks lexicon sentiment against rating sentiment
- identifies frequently discussed product aspects
- recommends five separated sale windows for each brand
- displays the results in a Shiny dashboard

## Opportunity score

The score is intentionally simple:

| Component | Weight |
|---|---:|
| Forecast demand | 55% |
| Demand momentum | 20% |
| Festival timing | 15% |
| Positive-review share | 10% |

A high score suggests a useful demand-capture window. The weights can be changed in `R/forecast.R` if the business objective changes.

## Files

```text
TecSailor/
|-- R/
|   |-- forecast.R
|   |-- plots.R
|   |-- scrape.R
|   |-- setup.R
|   `-- text_analysis.R
|-- data/
|   |-- processed/
|   `-- raw/
|-- outputs/
|   |-- figures/
|   `-- tables/
|-- tests/
|-- app.R
|-- config.R
|-- main.R
|-- run_tests.R
`-- README.md
```

## Run the analysis

Open `TecSailor.Rproj` or set this folder as the working directory.

```r
source("main.R")
```

The first run installs missing packages and collects the data. Later runs use the saved data. Set `refresh_data <- TRUE` in `config.R` only when a fresh collection is required.

## Open the dashboard

```r
shiny::runApp()
```

## Run the tests

```r
source("run_tests.R")
```

## Main limitations

Google Trends measures relative search attention rather than purchases. Review activity is also not equal to sales volume. The selected product does not represent every product sold by a brand. Review sentiment can contain sarcasm, mixed opinions and multiple languages. Festival indicators mark planning windows but do not measure the historical effect of a particular retailer campaign.

Reviews are collected from both Flipkart and Amazon India to improve coverage, but different platforms may have different customer demographics and review patterns.

Actual weekly orders, prices, promotion dates, advertising spend and inventory can be added later to improve the recommendations.
