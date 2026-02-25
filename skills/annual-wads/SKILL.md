---
name: annual-wads
description: Extract annual Weighted Average Diluted Shares for one or more public company tickers (comma-separated) by browsing Yahoo Finance in Chrome. Produces two markdown tables per ticker - (1) raw annual diluted shares for the past 10 years and (2) YoY change rate. Use when the user wants annual diluted share count data, share count history, dilution or buyback trends for a stock.
argument-hint: [ticker1,ticker2,...]
allowed-tools: mcp__chrome-devtools__list_pages, mcp__chrome-devtools__select_page, mcp__chrome-devtools__navigate_page, mcp__chrome-devtools__take_snapshot, mcp__chrome-devtools__evaluate_script, mcp__chrome-devtools__click, mcp__chrome-devtools__take_screenshot, Bash, Read, Grep, Task
---

# Annual Weighted Average Diluted Shares Table Builder

Extract and display annual Diluted Average Shares for **$0** covering the past 10 fiscal years by browsing Yahoo Finance in Chrome. Requires Yahoo Finance Premium for the full 10-year history.

## Multi-Ticker Support

The argument `$0` may contain multiple tickers separated by commas (e.g., `AAPL,MSFT,GOOG`).

1. Parse `$0` by splitting on commas and trimming whitespace to get a list of tickers.
2. **Always** use the **Task tool** to launch one subagent per ticker **in parallel** (all Task calls in a single message). Each subagent should:
   - Receive the full instructions from Step 1 onward, with `$0` replaced by its single ticker
   - Be of type `general-purpose`
   - Work independently to extract data and build the tables
3. **If there is only one ticker**, present the subagent's Table 2 (YoY change rates) directly; skip Table 1 (raw data).
4. **If there are multiple tickers**, combine all results into a **single summary table** with fiscal years as rows and paired columns per ticker (value + YoY):

| FY | TICKER1 | YoY | TICKER2 | YoY |
|----|---------|-----|---------|-----|
| 2025 | XX.XXB | -X.X% | XX.XXB | -X.X% |
| 2024 | XX.XXB | -X.X% | XX.XXB | +X.X% |
| ... | ... | ... | ... | ... |
| 2016 | XX.XXB | – | XX.XXB | – |

Replace TICKER1, TICKER2, etc. with actual ticker symbols. Use `–` for the earliest year's YoY (no prior year data). Do not present separate tables per ticker.

## Step 1: Navigate to Yahoo Finance Financials

1. List pages and select an existing Yahoo Finance page (or any available page).
2. Navigate to `https://finance.yahoo.com/quote/$0/financials/`
3. Wait for the page to load.

## Step 2: Ensure Annual View is Selected

1. Take a snapshot of the page.
2. The default view should be "Annual". Verify by checking the snapshot. If the "Quarterly" tab is currently selected, save the snapshot to a file, use Grep to find the "Annual" tab element, and click it.

## Step 3: Extract Column Headers and Diluted Average Shares Data

Use `evaluate_script` to extract the table headers and Diluted Average Shares row in one call:

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

  // Find Diluted Average Shares row
  rows.forEach(row => {
    const label = row.querySelector('div.column div.rowTitle');
    if (label && label.textContent.trim().includes('Diluted Average Shares')) {
      const columns = row.querySelectorAll('div.column');
      const values = [];
      columns.forEach(col => {
        values.push(col.textContent.trim());
      });
      result.label = 'Diluted Average Shares';
      result.values = values;
    }
  });

  result.headers = headers;
  result.headerCount = headers.length;
  return result;
}
```

This returns:
- `headers`: Array starting with `["Breakdown", "TTM", "MM/DD/YYYY", ...]` — fiscal year-end dates. With Yahoo Finance Premium, this can include 40+ years of data.
- `values`: Array starting with `["Diluted Average Shares", "<TTM value>", "<annual value>", ...]`

## Step 4: Parse and Organize Data

1. **Skip** the first header ("Breakdown") and first value ("Diluted Average Shares").
2. **Skip** the TTM column (second header / second value) if present.
3. Pair each remaining header (date string like `"9/30/2024"`) with its corresponding share count value.
4. Parse each date to extract the **fiscal year-end date** and the **year**.
5. Filter to the **past 10 fiscal years** only (take the 10 most recent annual columns).
6. Share count values of `"--"` should be treated as missing/N/A.
7. Share count values from Yahoo Finance are displayed in thousands (e.g., `"15,408,095"` means 15,408,095,000 shares). Parse by removing commas and converting to numbers. For display:
   - If values exceed 10,000,000 (i.e., more than 10 billion shares), format in **billions** (divide by 1,000,000) with two decimal places and a `B` suffix.
   - Otherwise, format in **millions** (divide by 1,000) with one decimal place and an `M` suffix.

## Step 5: Build Table 1 — Annual Diluted Average Shares

Present a markdown table with this format:

```
| Fiscal Year End | Diluted Avg Shares |
|-----------------|--------------------|
| 9/30/2025       | XX.XXB             |
| 9/30/2024       | XX.XXB             |
| ...             | ...                |
```

- Bold the year values.
- Order rows from most recent year at top to oldest at bottom.

## Step 6: Build Table 2 — YoY Share Count Change

Calculate YoY change as: `(Current Year Shares - Prior Year Shares) / Prior Year Shares * 100`

Present a markdown table:

```
| Fiscal Year End | Diluted Avg Shares | YoY Change |
|-----------------|--------------------|------------|
| 9/30/2025       | XX.XXB             | -X.X%      |
| 9/30/2024       | XX.XXB             | -X.X%      |
| ...             | ...                | ...        |
```

- Prefix positive values with `+`, negative values naturally show `-`.
- A negative YoY change means the share count decreased (net buybacks), which is typically shareholder-friendly.
- A positive YoY change means dilution (new shares issued exceeded buybacks).
- The earliest year in the table will have no prior year to compare, so show "N/A" for that growth cell.
- If either the current or prior year share count is missing/zero, show "N/A" for that growth cell.

## Step 7: Add Notes

Below the tables, include a **Notes** section mentioning:
- That all share counts are weighted average diluted shares as reported per Yahoo Finance (displayed in thousands on the source, converted for readability).
- The company's fiscal year-end date (e.g., "Fiscal year ends December 31" or "Fiscal year ends September 30").
- Whether the trend shows net buybacks (declining share count) or net dilution (rising share count) and the approximate cumulative change over the 10-year period.
- Any notable spikes or drops and likely causes if obvious (e.g., large buyback programs, equity offerings, stock-based compensation, acquisitions with stock).
- The data source: Yahoo Finance $0 Financials (Annual Income Statement, Diluted Average Shares).
