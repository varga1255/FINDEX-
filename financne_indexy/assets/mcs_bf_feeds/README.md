MCS-BF feed files

These JSON files let the app use real regional inputs instead of proxy values.

Expected shape:

{
  "region": "USA | WORLD | EUROPE",
  "updatedAt": "2026-04-25",
  "sources": {
    "breadth50": "description of the upstream breadth feed",
    "breadth200": "description of the upstream breadth feed",
    "sentimentZ": "description of the upstream sentiment feed",
    "volatility": "description of the upstream volatility feed"
  },
  "series": {
    "breadth50": [{ "date": "2026-04-24", "value": 42.1 }],
    "breadth200": [{ "date": "2026-04-24", "value": 55.4 }],
    "sentimentZ": [{ "date": "2026-04-24", "value": -0.73 }],
    "volatility": [{ "date": "2026-04-24", "value": 18.5 }]
  }
}

Notes:
- dates must be ISO yyyy-mm-dd
- values are daily end-of-day values
- if a region file is empty, the app falls back to proxy logic
- Europe should ideally provide a local volatility feed such as VSTOXX
