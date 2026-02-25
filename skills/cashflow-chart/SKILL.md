---
name: cashflow-chart
description: Build an interactive dark-themed HTML cash flow chart for one or more public company tickers (comma-separated). Creates a Chart.js visualization with Operating Cash Flow (green bars), Capital Expenditure (red bars), Interest Expense (orange bars), and Free Cash Flow (blue line), plus summary callout boxes, a data table, and key observations. Use when the user wants a cash flow chart, FCF analysis, or operating cash flow visualization for a stock.
argument-hint: [ticker1,ticker2,...]
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, mcp__yahoo-finance__get_financial_statement, mcp__yahoo-finance__get_stock_info, mcp__chrome-devtools__navigate_page, mcp__chrome-devtools__take_snapshot, mcp__chrome-devtools__take_screenshot, mcp__chrome-devtools__evaluate_script, Task
---

# Cash Flow Chart Builder

Build an interactive HTML chart for ticker **$0** covering the past 15 fiscal years.

## Multi-Ticker Support

The argument `$0` may contain multiple tickers separated by commas (e.g., `AAPL,MSFT,GOOG`).

1. Parse `$0` by splitting on commas and trimming whitespace to get a list of tickers.
2. **Always** use the **Task tool** to launch one subagent per ticker **in parallel** (all Task calls in a single message). Each subagent should:
   - Receive the full instructions from Step 1 onward, with `$0` replaced by its single ticker
   - Be of type `general-purpose`
   - Work independently to gather data, build the HTML file, and verify rendering
3. After all subagents complete, present each ticker's file path and key metrics in sequence, separated by a horizontal rule (`---`) and a heading with the ticker name.

## Step 1: Gather Data

Collect data for the **past 15 fiscal years** from two sources:

### Cash Flow Statement
Use the Yahoo Finance MCP tool `get_financial_statement` with `financial_type: "cashflow"` for **$0** to get:
- **Operating Cash Flow**
- **Capital Expenditure** (use absolute values; the API reports negative numbers)
- **Free Cash Flow**

### Income Statement
Use the Yahoo Finance MCP tool `get_financial_statement` with `financial_type: "income_stmt"` for **$0** to get:
- **Interest Expense**

### Supplementing with Chrome (if needed)
The Yahoo Finance API typically only returns 4 years. To get the full 15-year history:

1. Navigate Chrome to `https://finance.yahoo.com/quote/$0/cash-flow/` and take a snapshot
2. Extract **Operating Cash Flow**, **Capital Expenditure**, and **Free Cash Flow** rows from the page snapshot (the page shows the full history with annual data)
3. Navigate Chrome to `https://finance.yahoo.com/quote/$0/financials/` and extract the **Interest Expense** row
4. If the snapshot is too large, use `evaluate_script` to extract specific rows:

```javascript
() => {
  const rows = document.querySelectorAll('[class*="row"]');
  let result = [];
  for (const row of rows) {
    const text = row.innerText;
    if (text.startsWith('TARGET_ROW_NAME')) {
      result.push(text);
    }
  }
  return result;
}
```

Convert all values to **$M** (millions) for the chart. If a company has fewer than 15 years of data, use whatever is available.

## Step 2: Build the HTML File

Create a single self-contained HTML file using:
- **Chart.js** from CDN: `https://cdn.jsdelivr.net/npm/chart.js@4.4.7/dist/chart.umd.min.js`
- **chartjs-plugin-datalabels** from CDN: `https://cdn.jsdelivr.net/npm/chartjs-plugin-datalabels@2.2.0/dist/chartjs-plugin-datalabels.min.js`

### Chart Specification

| Series | Type | Color | Axis |
|--------|------|-------|------|
| Operating Cash Flow | Bar | Green `rgba(74, 222, 128)` | Left (Y) |
| Capital Expenditure | Bar | Red `rgba(248, 113, 113)` | Left (Y) |
| Interest Expense | Bar | Orange `rgba(251, 191, 36)` | Left (Y) |
| Free Cash Flow | Line (overlaid, filled) | Blue `rgba(96, 165, 250)` | Left (Y) |

### Theme & Layout
- **Dark theme**: body background `#1a1a2e`, chart area background `#16213e`
- **Chart height**: 500px, `maintainAspectRatio: false`, responsive
- **Legend**: Below the chart, point-style, color `#cdd6f4`
- **Tooltip**: interaction mode `index`, intersect `false`, dark styled
- **Y-axis**: formatted as `$XM` (e.g., `$1,000M`), grid color subtle
- **X-axis**: labels as `FY20XX`
- **Data labels**: Show on OCF bars (green, select key years) and FCF line (blue, select key years) to avoid overlap. Use `chartjs-plugin-datalabels`. Format large values as `$X.XB`.
- **Bar styling**: `borderRadius: 3`, slight transparency

### Below the Chart

#### Callout Boxes (grid of 5)
Show these KPIs in styled card boxes:
1. **First-year OCF** (green) - with "Starting baseline" subtitle
2. **Latest OCF** (green) - with "Xx growth" subtitle
3. **OCF CAGR** (orange) - calculated as compound annual growth rate over the period
4. **Latest FCF** (blue) - with "Record/Latest free cash flow" subtitle
5. **FCF Conversion %** (blue) - FCF / OCF for the latest year

#### Data Table
Full HTML table with columns:
- FY | Op. Cash Flow | YoY% | CapEx | Interest Exp. | Free Cash Flow | FCF Conversion
- Color-code: OCF green, CapEx red, Interest orange, FCF blue
- YoY% green if positive, red if negative
- Dark table styling consistent with theme

#### Key Observations
A "Key Observations" section with 4-6 bullet points highlighting:
- Overall growth trajectory and CAGR
- Any anomalous years (dips, spikes) and likely causes (divestitures, acquisitions, restructuring)
- Major M&A events and their impact on interest expense and OCF
- Capital intensity / FCF conversion trends
- Latest year performance and what it signals
- Interest expense trends (leverage changes)

Research the company briefly to provide context-aware observations (e.g., major acquisitions, divestitures, business model changes).

## Step 3: Save & Display

1. Save the HTML file to the scratchpad directory as `{ticker_lowercase}_cashflow.html`
2. Open the file in Chrome using `navigate_page`
3. Take a full-page screenshot to verify rendering
4. If labels overlap or chart looks off, adjust data label display (show on fewer years) and reload
5. Report the file path and key metrics to the user
