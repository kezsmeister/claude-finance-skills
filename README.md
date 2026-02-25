# claude-finance-skills

Custom [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills that extract financial data from Yahoo Finance. Type a slash command like `/annual-revenue AAPL` and Claude browses Yahoo Finance in Chrome, scrapes the tables, and returns clean markdown with 10 years of history and YoY growth rates.

All skills support **multiple tickers** — pass a comma-separated list (e.g., `/annual-eps AAPL,MSFT,GOOG`) and each ticker is processed in parallel, then combined into a single comparison table.

## Skill Catalog

| Skill | Data Extracted | Source Page | Example |
|-------|---------------|-------------|---------|
| `annual-revenue` | Annual Total Revenue (10 yr) | Income Statement | `/annual-revenue AAPL` |
| `quarterly-revenue` | Quarterly Total Revenue (10 yr) | Income Statement | `/quarterly-revenue MSFT` |
| `annual-eps` | Annual Diluted EPS (10 yr) | Income Statement | `/annual-eps GOOG` |
| `quarterly-eps` | Quarterly Diluted EPS (10 yr) | Income Statement | `/quarterly-eps AMZN` |
| `annual-dividend` | Annual Dividends Per Share (10 yr) | Dividends Tab | `/annual-dividend JNJ` |
| `quarterly-dividend` | Quarterly Dividends Per Share (10 yr) | Dividends Tab | `/quarterly-dividend KO` |
| `annual-capex` | Annual Capital Expenditure (10 yr) | Cash Flow Statement | `/annual-capex TSLA` |
| `annual-wads` | Annual Weighted Avg Diluted Shares (10 yr) | Income Statement | `/annual-wads META` |
| `cashflow-chart` | Interactive HTML cash flow chart (15 yr) | Cash Flow + Income Stmt | `/cashflow-chart AAPL` |

## Prerequisites

1. **Claude Code** — installed and working ([docs](https://docs.anthropic.com/en/docs/claude-code))
2. **Chrome DevTools MCP server** — required by all skills except `cashflow-chart`. This lets Claude control a Chrome browser to navigate Yahoo Finance and extract data. Set it up in your Claude Code MCP config:
   ```json
   {
     "mcpServers": {
       "chrome-devtools": {
         "command": "npx",
         "args": ["@anthropic-ai/chrome-devtools-mcp@latest"]
       }
     }
   }
   ```
   You also need Chrome running with the DevTools protocol enabled:
   ```bash
   # macOS
   /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222
   ```
3. **Yahoo Finance MCP server** — required by the `cashflow-chart` skill (used to fetch data via API before falling back to Chrome scraping):
   ```json
   {
     "mcpServers": {
       "yahoo-finance": {
         "command": "uvx",
         "args": ["yahoo-finance-mcp"]
       }
     }
   }
   ```
4. **Yahoo Finance Premium** (recommended) — some metrics like Weighted Average Diluted Shares only show the full 10-year history with a Premium subscription. Free accounts still work but may return fewer years.

## Installation

### Option A: Install Script

```bash
git clone https://github.com/kezsmeister/claude-finance-skills.git
cd claude-finance-skills
./install.sh
```

The script copies all skill folders into `~/.claude/skills/`. Restart Claude Code to pick them up.

### Option B: Manual Copy

Copy individual skill folders into your Claude Code skills directory:

```bash
cp -r skills/annual-revenue ~/.claude/skills/
cp -r skills/quarterly-eps ~/.claude/skills/
# ... etc.
```

## Usage

Once installed, skills appear as slash commands in Claude Code. Type `/` to see the full list.

### Single Ticker

```
/annual-revenue AAPL
```

Returns a markdown table with YoY growth:

| Fiscal Year End | Total Revenue | YoY Growth |
|-----------------|---------------|------------|
| 9/28/2024 | $391.04B | +2.0% |
| 9/30/2023 | $383.29B | -2.8% |
| 10/1/2022 | $394.33B | +7.8% |
| ... | ... | ... |

### Multiple Tickers

```
/annual-eps AAPL,MSFT,GOOG
```

Returns a combined comparison table:

| FY | AAPL | YoY | MSFT | YoY | GOOG | YoY |
|----|------|-----|------|-----|------|-----|
| 2024 | $6.97 | +10.2% | $11.80 | +21.6% | $5.80 | +36.5% |
| 2023 | $6.33 | -0.8% | $9.70 | -2.5% | $4.25 | -18.3% |
| ... | ... | ... | ... | ... | ... | ... |

### Cash Flow Chart

```
/cashflow-chart AAPL
```

Generates an interactive dark-themed HTML file with:
- Bar chart: Operating Cash Flow, CapEx, Interest Expense
- Line overlay: Free Cash Flow
- Summary KPI cards (OCF CAGR, FCF Conversion, etc.)
- Full data table
- Key observations

The chart is saved locally and opened in Chrome for preview.

## Output Format

Each skill (except `cashflow-chart`) produces:
- **Table 1** — Raw values for each fiscal year/quarter
- **Table 2** — YoY growth rates (shown by default for single-ticker queries)
- **Notes** — Data source, fiscal year-end date, notable observations

For multi-ticker queries, tables are merged into a single comparison view with paired value + YoY columns per ticker.

`cashflow-chart` produces a self-contained HTML file with Chart.js visualizations.

## How It Works

These skills use Claude Code's [custom skills](https://docs.anthropic.com/en/docs/claude-code/skills) feature. Each `SKILL.md` file contains structured instructions that tell Claude how to:

1. Navigate to the correct Yahoo Finance page in Chrome (via Chrome DevTools MCP)
2. Extract specific financial data rows using JavaScript evaluation
3. Parse, format, and present the data as markdown tables
4. Calculate YoY growth rates and add contextual notes

The skills leverage Claude's ability to control a browser through the Chrome DevTools Protocol, making the data extraction reliable even as Yahoo Finance's page structure changes — Claude can adapt its selectors on the fly.

## License

MIT
