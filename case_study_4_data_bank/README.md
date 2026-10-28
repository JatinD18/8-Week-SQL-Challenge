<div align="center">

# 🏦 Case Study #4 — Data Bank

### Part of the [8-Week SQL Challenge](https://8weeksqlchallenge.com/) by Danny Ma · Solved end-to-end in **MySQL 8.0**

![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?logo=mysql&logoColor=white)
![Status](https://img.shields.io/badge/Sections-A%20B%20C%20%2B%20follow--ups-brightgreen)
![Focus](https://img.shields.io/badge/Focus-Running%20Balances%20%C2%B7%20Period%20Joins%20%C2%B7%20Percentiles-orange)

</div>

---

## 🎯 Business Problem

Data Bank is a digital bank where every customer is allocated to a **node** within a **region**, and allocations change over time. The analytics team needs to understand:

1. **Node exploration** — how the node network is distributed and how often customers get reallocated
2. **Transaction behaviour** — volumes and values across regions, customers and months
3. **The core challenge** — building a **running-balance report** at transaction, daily and monthly granularity, ending with the reserve cash the bank must hold

This case study is the challenge's masterclass in **temporal (period-accurate) joins, window frames, and period-closing logic** — the exact toolkit used in banking and fintech analytics.

---

## 🗂️ Repository Structure

```text
case_study_4_data_bank/
├── README.md                # This file
├── 01_schema_and_data.sql   # Layer 1 — DDL + region inserts + official INSERT/CSV load notes
└── 02_solutions.sql         # Layer 2 — txn_seq surrogate key + Sections A, B, C + follow-ups
```

### Schema (official layout)

```text
regions ──< customer_nodes >── nodes
                  │
                  └──(customer_id + active date window)──< customer_transactions
```

| Table | Columns | Role |
|---|---|---|
| `regions` | region_id, region_name | Dimension (5 regions) |
| `nodes` | node_id, node_name | Dimension (node names) |
| `customer_nodes` | customer_id, region_id, node_id, start_date, end_date | **Bridge / allocation-history table** — one row per allocation period |
| `customer_transactions` | customer_id, txn_date, txn_type, txn_amount | Fact table — **no natural key (`txn_id`)** |

### Two design decisions that shape every solution

- **`customer_nodes` is a combined allocation table** (customer ↔ region ↔ node ↔ validity dates), matching the official dataset. Current allocations carry a far-future `end_date` sentinel (`9999-12-31`).
- **The fact table has no `txn_id`**, so a deterministic surrogate sequence (`txn_seq`) is generated once via `ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY txn_date, txn_type, txn_amount)`. All window functions order by `txn_seq`. *Daily closing balances are provably unaffected by intra-day ordering — the last row of a day always carries the full cumulative sum through that day.*

---

## 📊 Sections & Key Insights

### A. Customer Nodes Exploration
- Node network mapped per region; customer allocation counts reveal which regions carry the load.
- **Reallocation cadence** measured from completed allocation episodes only (`end_date <> '9999-12-31'`) — including open episodes would poison the average.
- **Median / P80 / P95 reallocation days per region** computed with a `PERCENT_RANK()` threshold trick, because MySQL has no `PERCENTILE_CONT`.

### B. Customer Transactions
- Transaction mix split by type: **deposits add money; withdrawals and purchases subtract it**.
- Region-level metrics use a **period-accurate join**: a transaction belongs to the node/region the customer sat on *that day* (`txn_date >= start_date AND txn_date < end_date`). This also eliminates the fan-out that a naive `customer_id`-only join would create for multi-allocation customers.
- Monthly region rollups expose seasonal volume shifts.

### C. The Data Challenge — Running Balances (the flagship)
A three-granularity ladder, each layer built on the previous one as a view:

```text
customer_transactions
        │  + txn_seq surrogate key
        ▼
vw_running_balance      running balance per transaction (explicit ROWS frame)
        ▼
vw_daily_closing        last balance of each day per customer
        ▼
monthly closing         last active day's balance per month
        ▼
reserve report          Σ final balances + overdraft exposure
```

- **Business payoff:** the sum of customers' final positive balances = the **reserve cash Data Bank must keep liquid**; the sum of negative final balances = **overdraft exposure**. This is the single number a real treasury team would ask for.
- A handful of customers dip negative mid-history — flagged via a follow-up query as overdraft-behaviour candidates.

### Follow-ups
- **F1 — Overdraft customers:** distinct customers whose running balance ever went negative.
- **F2 — Node churn per region:** `COUNT(*) − COUNT(DISTINCT customer_id)` on `customer_nodes` = number of reallocation *moves* (every row beyond a customer's first is a move).

---

## 🧰 Key SQL Techniques Practiced

| Technique | Where used |
|---|---|
| `ROW_NUMBER()` as surrogate key | `txn_seq` for a fact table with no natural key |
| Explicit window frame `ROWS UNBOUNDED PRECEDING` | Running balance per transaction |
| `ROW_NUMBER() ... ORDER BY ... DESC` + `rn = 1` | Daily & monthly **closing** balances (period-end snapshots) |
| Temporal / period-accurate join | Transactions attributed to the allocation active on `txn_date` |
| `PERCENT_RANK()` threshold + `MIN(CASE WHEN ...)` | Median / P80 / P95 without `PERCENTILE_CONT` |
| Conditional sign convention | `CASE WHEN txn_type = 'deposit' THEN + ELSE −` |
| `DATEDIFF` on validity windows | Reallocation-day metrics |
| Layered views | `vw_running_balance` → `vw_daily_closing` → monthly → reserve |
| Conditional aggregation | Overdraft exposure, reallocation-event counts |

### ⭐ Hardest Query
**The closing-balance ladder (C1→C4).** It chains a surrogate key, an explicit-frame running sum, two "last-row-of-period" `ROW_NUMBER` picks, and a final per-customer snapshot — the same pattern banks use to produce statements and reserve reports. Runner-up: the **A5 percentile trick**, which reproduces ordered-set percentiles in a MySQL-compatible way.

---

## 💻 How to Run

```bash
# 1. Load schema + data (paste the official INSERT blocks or import the CSVs first)
mysql -u root -p < 01_schema_and_data.sql

# 2. Run surrogate key + all solutions
mysql -u root -p < 02_solutions.sql
```

Or in MySQL Workbench: execute `01` then `02` in order.

**Validation checks built into the workflow:**
- `txn_type` mix query confirms deposits vs outflows
- Allocation windows per customer are consecutive date ranges
- Deposits net positive; most final balances positive, a few negative (overdrafts)
- Monthly closing balance = last daily closing balance of that month

---

## 🔭 Possible Extensions

- [ ] Statement-style report: opening balance, movements, closing balance per customer per month
- [ ] Node-level liquidity view (balances attributed to the node active at month-end)
- [ ] Cohort view of customers by join month vs time-to-first-negative-balance
- [ ] Port the percentile logic to `NTILE(100)` and compare results

---

## ⚠️ Notes & Limitations

- `end_date = '9999-12-31'` marks still-active allocations; all reallocation metrics exclude it.
- Without `txn_id`, intra-day transaction order is deterministic but arbitrary (`txn_type, txn_amount` tie-break); daily/monthly closings are unaffected.
- Region attribution assumes the allocation window in `customer_nodes` is authoritative for the transaction date.
- Dataset is a teaching dataset; reserve/overdraft figures illustrate methodology, not real treasury positions.

---

## 👤 Author

**Jatin Naresh Dolas**
Data Analyst | SQL · Python · Power BI · Streamlit

[![GitHub](https://img.shields.io/badge/GitHub-JatinD18-181717?logo=github&logoColor=white)](https://github.com/JatinD18)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Jatin%20Dolas-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/jatin-dolas)
