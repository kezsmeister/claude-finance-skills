---
name: quarterly-eps
description: Extract quarterly Diluted EPS for one or more public company tickers (comma-separated) by browsing Yahoo Finance in Chrome. Produces two markdown tables per ticker - (1) raw quarterly EPS for the past 10 years and (2) YoY growth rate per quarter. Use when the user wants quarterly EPS data, EPS history, or earnings per share trends for a stock.
argument-hint: [ticker1,ticker2,...]
allowed-tools: mcp__chrome-devtools__list_pages, mcp__chrome-devtools__select_page, mcp__chrome-devtools__navigate_page, mcp__chrome-devtools__take_snapshot, mcp__chrome-devtools__evaluate_script, mcp__chrome-devtools__click, mcp__chrome-devtools__take_screenshot, Bash, Read, Grep, Task
---

# Quarterly EPS Table Builder

Extract and display quarterly Diluted EPS for **$0** covering the past 10 fiscal years by browsing Yahoo Finance in Chrome.

## Multi-Ticker Support

The argument `$0` may contain multiple tickers separated by commas (e.g., `AAPL,MSFT,GOOG`).

1. Parse `$0` by splitting on commas and trimming whitespace to get a list of tickers.
2. **Always** use the **Task tool** to launch one subagent per ticker **in parallel** (all Task calls in a single message). Each subagent should:
   - Receive the full instructions from Step 1 onward, with `$0` replaced by its single ticker
   - Be of type `general-purpose`
   - Work independently to extract data and build the tables
3. **If there is only one ticker**, present the subagent's Table 2 (YoY growth rates) directly; skip Table 1 (raw data).
4. **If there are multiple tickers**, combine all results into a **single summary table** with fiscal years as rows and paired columns per ticker (Full Year value + YoY):

| FY | TICKER1 | YoY | TICKER2 | YoY |
|----|---------|-----|---------|-----|
| 2025 | $X.XX | +X.X% | $X.XX | +X.X% |
| 2024 | $X.XX | -X.X% | $X.XX | +X.X% |
| ... | ... | ... | ... | ... |
| 2016 | $X.XX | – | $X.XX | – |

Replace TICKER1, TICKER2, etc. with actual ticker symbols. Use `–` for the earliest year's YoY (no prior year data). Do not present separate tables per ticker.

## Step 1: Navigate to Yahoo Finance Financials

1. List pages and select an existing Yahoo Finance page (or any available page).
2. Navigate to `https://finance.yahoo.com/quote/$0/financials/`
3. Wait for the page to load.

## Step 2: Switch to Quarterly View

1. Take a snapshot of the page.
2. The snapshot will be very large. Save it to a file and use Grep to find the "Quarterly" tab element (search for `Quarterly`).
3. Click the **Quarterly** tab (it will be a `tab` element with text "Quarterly" and a `uid`).

## Step 3: Extract Column Headers and Diluted EPS Data

After clicking Quarterly, use `evaluate_script` to extract the table headers and Diluted EPS row in one call:

```javascript
() => {
  const rows = document.querySelectorAll('div.tableBody div.row');
  const result = {};

  // Get column headers
  const headerRow = document.querySelector('div.tableHeader div.row');
  const headers = [];
  if (headerRow) {
    headerRow.querySelectorAll('div.column').forEach(col => {
      headers.push(col.textContent.trim());
    });
  }

  // Find Diluted EPS row
  rows.forEach(row => {
    const label = row.querySelector('div.column div.rowTitle');
    if (label && label.textContent.trim().includes('Diluted EPS')) {
      const columns = row.querySelectorAll('div.column');
      const values = [];
      columns.forEach(col => {
        values.push(col.textContent.trim());
      });
      result.label = 'Diluted EPS';
      result.values = values;
    }
  });

  result.headers = headers;
  return result;
}
```

This returns:
- `headers`: Array starting with `["Breakdown", "TTM", "MM/DD/YYYY", ...]` — quarter-end dates
- `values`: Array starting with `["Diluted EPS", "<TTM value>", "<Q value>", ...]`

## Step 4: Parse and Organize Data

1. **Skip** the first header ("Breakdown") and first value ("Diluted EPS").
2. **Skip** the TTM column (second header / second value).
3. Pair each remaining header (date string like `"12/31/2024"`) with its corresponding EPS value.
4. Parse each date to extract the **year** and **quarter**:
   - Month 3 (3/31) → Q1
   - Month 6 (6/30) → Q2
   - Month 9 (9/30) → Q3
   - Month 12 (12/31) → Q4
   - Any non-standard month-end dates (e.g., 10/31) should be flagged as anomalies and **excluded** from the main table (note them separately).
5. Filter to the **past 10 full calendar years** only. If the current year is incomplete (fewer than 4 quarters reported), still include it and mark missing quarters as "N/A".
6. EPS values of `"--"` should be treated as missing/N/A.

## Step 5: Build Table 1 — Quarterly Diluted EPS

Present a markdown table with this format:

```
| Year | Q1 (Mar) | Q2 (Jun) | Q3 (Sep) | Q4 (Dec) | Full Year |
|------|----------|----------|----------|----------|-----------|
| 2025 | $X.XX    | $X.XX    | $X.XX    | $X.XX    | $X.XX     |
| ...  | ...      | ...      | ...      | ...      | ...       |
```

- **Full Year** = sum of Q1 + Q2 + Q3 + Q4 (bold the column header and values).
- Show dollar signs on all values.
- Bold the year column values.
- Order rows from most recent year at top to oldest at bottom.

## Step 6: Build Table 2 — YoY Growth per Quarter

Calculate YoY growth as: `(Current Quarter EPS - Same Quarter Prior Year EPS) / Same Quarter Prior Year EPS * 100`

Present a markdown table:

```
| Year | Q1 (Mar) | Q2 (Jun) | Q3 (Sep) | Q4 (Dec) | Full Year |
|------|----------|----------|----------|----------|-----------|
| 2025 | +X.X%    | -X.X%    | +X.X%    | +X.X%    | +X.X%     |
| ...  | ...      | ...      | ...      | ...      | ...       |
```

- **Full Year** growth = `(Current FY sum - Prior FY sum) / Prior FY sum * 100`.
- Prefix positive values with `+`, negative values naturally show `-`.
- The earliest year in the table will have no prior year to compare, so exclude it from this table (show 9 rows of growth for 10 years of data).
- If either the current or prior quarter EPS is missing/zero, show "N/A" for that growth cell.

## Step 7: Add Notes

Below the tables, include a **Notes** section mentioning:
- That all EPS values are split-adjusted per Yahoo Finance.
- Any anomalous dates found (e.g., 10/31 quarter-ends) and that they were excluded.
- Any notable spikes or drops and likely causes if obvious (e.g., tax reform, stock splits, one-time items).
- The data source: Yahoo Finance ODFL Financials (Quarterly Income Statement, Diluted EPS).

Replace "ODFL" with the actual ticker **$0** in the source note.
