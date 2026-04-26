MCS-BF data sources

Recommended source stack for replacing proxy inputs with production-grade regional data.

USA

- Breadth50 / Breadth200
  - Source: historical S&P 500 constituent data + daily price history
  - Recommended provider: Financial Modeling Prep
  - Why: provides index datasets, historical constituents, and historical prices via API
  - Implementation note: compute daily percent of constituents above SMA50 and SMA200 inside our pipeline

- SentimentZ
  - Source: Cboe S&P 500 put/call ratio history
  - Recommended provider: Cboe historical put/call ratio archives
  - Why: official market sentiment-style options flow data; closer to real risk appetite than price-return proxy
  - Implementation note: normalize to rolling z-score in our pipeline

- Volatility
  - Source: Cboe VIX historical values
  - Recommended provider: Cboe official VIX historical data

WORLD

- Breadth50 / Breadth200
  - Source: MSCI World constituent history + daily price history
  - Recommended provider: MSCI licensed constituent data, or a vendor with licensed MSCI constituent history
  - Why: true breadth for MSCI World requires real constituent membership over time
  - Implementation note: if licensed MSCI history is unavailable, do not label fallback as "real breadth"

- SentimentZ
  - Source: AAII bull-bear spread or a global multi-asset risk sentiment series
  - Recommended provider: AAII Sentiment Survey for initial implementation
  - Why: widely used, stable, easy to normalize into z-score
  - Implementation note: weekly series can be forward-filled to daily

- Volatility
  - Source: VIX historical values
  - Recommended provider: Cboe official VIX historical data
  - Why: acceptable global risk proxy for MSCI World if no better global implied-vol index is licensed

EUROPE

- Breadth50 / Breadth200
  - Source: STOXX Europe 600 constituent history + daily price history
  - Recommended provider: STOXX historical component changes plus licensed historical data access, or a vendor with STOXX constituent history
  - Why: true European breadth needs real STOXX 600 membership over time

- SentimentZ
  - Source: Cboe Europe / STOXX-linked options sentiment if available; otherwise same global sentiment series used for World
  - Recommended provider: first implementation may reuse AAII or a global options sentiment proxy until a better Europe-specific series is selected

- Volatility
  - Source: VSTOXX historical values
  - Recommended provider: STOXX / licensed VSTOXX data
  - Why: this is the right regional volatility input for Euro-area equity risk

Priority order

1. USA volatility and sentiment
2. Europe volatility
3. USA breadth
4. Europe breadth
5. World breadth
6. World and Europe sentiment refinement

Current status in app

- The app now supports real regional feed files:
  - assets/mcs_bf_feeds/usa.json
  - assets/mcs_bf_feeds/world.json
  - assets/mcs_bf_feeds/europe.json
- If a real feed is missing, the app falls back to proxy logic and shows the source label in the UI.
