<div align="center">

# 🗄️ 8-Week SQL Challenge — Case Studies 01–04

**Four industry-style business problems, solved end-to-end in MySQL 8.0 — cleaned, queried, validated and documented like production work.**

[![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?logo=mysql&logoColor=white)](https://www.mysql.com/)
[![Case Studies](https://img.shields.io/badge/Case%20Studies-4%20completed-brightgreen)](#)
[![Queries](https://img.shields.io/badge/Queries-70%2B-blue)](#)
[![Source](https://img.shields.io/badge/Challenge-8--Week%20SQL%20Challenge-orange)](https://8weeksqlchallenge.com/)

Challenge created by **Danny Ma** · Solved & documented by **Jatin Naresh Dolas**

</div>

> **⏱️ Recruiter 60-second tour:** jump to the *Case Study Deep Dives* for the business insights each study produced, scan the *Technique Coverage Matrix* for the SQL toolbox on display, then open `case_study_2_pizza_runner/02_data_cleaning.sql` — it shows how dirty, real-world-style operational data is tamed *before* a single metric is computed.

---

## 🧭 What This Repository Is

The [8-Week SQL Challenge](https://8weeksqlchallenge.com/) is a series of case studies modelled on real analytics problems — restaurant loyalty, delivery operations, SaaS subscriptions and digital banking. This repository contains my **first four case studies, completed end-to-end**. Every folder is built as a mini-project, not an answer dump:

- **`01_schema_and_data.sql`** — reproduces the full dataset from scratch (DDL + loads)
- **`02_data_cleaning.sql`** — a dedicated transformation layer wherever data arrives dirty
- **`03_solutions.sql` / `02_solutions.sql`** — fully commented answers to every question, plus interview-style follow-ups and expected-result checks
- **Per-case `README.md`** — translates query output into business insights, limitations and methodology notes

---

## ⚡ At a Glance

| # | Case Study | Domain | Scope | Headline Techniques |
|---|---|---|---|---|
| 01 | **Danny's Diner** 🍜 | Restaurant & loyalty | 10 questions + 8 follow-ups | `ROW_NUMBER` / `DENSE_RANK`, member-vs-guest logic, nested `CASE` points engine |
| 02 | **Pizza Runner** 🍕 | Delivery operations | 5 sections, 30+ queries | `REGEXP_REPLACE` cleaning, comma-list string splitting, `GROUP_CONCAT` receipts |
| 03 | **Foodie-Fi** 📺 | SaaS subscriptions | 11 questions + 2 follow-ups | `LAG()` conversion funnels, point-in-time snapshots, churn & upgrade cohorts |
| 04 | **Data Bank** 🏦 | Digital banking | 3 sections + 2 follow-ups | Running-balance ladder, temporal joins, `PERCENT_RANK` percentiles |

---

## 📁 Repository Structure

```text
8-Week-SQL-Challenge/
├── README.md                          ← you are here
│
├── case_study_1_dannys_diner/
│   ├── README.md                      # insights: bestsellers, loyalty points economics
│   ├── 01_schema_and_data.sql
│   └── 02_solutions.sql               # Q1–Q10 + F1–F8 follow-ups
│
├── case_study_2_pizza_runner/
│   ├── README.md                      # insights: extras/exclusions vs recipe design
│   ├── 01_schema_and_data.sql
│   ├── 02_data_cleaning.sql           # '20km' → 20.00, 'null' → NULL, + validation
│   └── 03_solutions.sql               # Sections A–E + follow-ups
│
├── case_study_3_foodie_fi/
│   ├── README.md                      # insights: trial-to-paid funnel, churn leakage
│   ├── 01_schema_and_data.sql
│   └── 02_solutions.sql               # Q1–Q11 + MRR follow-ups
│
└── case_study_4_data_bank/
    ├── README.md                      # insights: reserve cash & overdraft exposure
    ├── 01_schema_and_data.sql
    └── 02_solutions.sql               # Sections A–C + follow-ups
```

---

## 🔎 Case Study Deep Dives

### 01 · 🍜 Danny's Diner — loyalty analytics on three tiny tables

Small data, sharp questions: which dishes drive spend, what did members buy before vs after joining, and how many loyalty points does a overlapping-rules promo engine actually award?

- **Ramen is the bestseller** (8 of 15 order lines); customer A outspends B ($76 vs $74) despite joining later.
- One reusable **`ROW_NUMBER` / `LAG` pattern** answers "first item ever", "first item after membership" and "last item before membership" — with deterministic tie-breaks for same-day orders.
- The hardest question stacks **two overlapping point rules** (promo-week 2× on everything, otherwise 2× on sushi) into a single nested `CASE`: A ends January with **1,370 points**, B with **820**.
- Follow-ups extend the dataset into **running spend, visit-gap analysis and anti-join "never joined" lists**.

```sql
ROW_NUMBER() OVER (
    PARTITION BY customer_id
    ORDER BY order_date, product_id   -- product_id breaks same-day ties deterministically
) AS rn
```

---

### 02 · 🍕 Pizza Runner — the data-cleaning gauntlet

The raw feed stores distances as `'20km'`, durations as `'32 minutes'` and missing values as the literal string `'null'`. Half the work happens before any metric exists.

| Raw value | Cleaned | Tool |
|---|---|---|
| `'20km'`, `'23.4 km'` | `20.00`, `23.40` | `REGEXP_REPLACE` + `CAST` |
| `'32 minutes'`, `'40'` | `32`, `40` | `REGEXP_REPLACE` + `CAST` |
| `'null'`, `''` | real `NULL` | `CASE … IN ('null','')` |
| duplicate pizza lines | unique `row_id` | `ROW_NUMBER() OVER ()` |

- **14 pizzas across 10 orders, 8 delivered**; largest delivered order = 3 pizzas; prep time scales with order size (~12 → ~29 min).
- **Bacon is the most-added extra (4×)** while **cheese — present in both standard recipes — is the most-excluded topping (4×)**: a recipe-design insight, not just a number.
- Revenue modelled three ways: **$138 base → $148 with a $2 long-distance fee → $142 including $1 extras**; a *base $4 + $1/topping* rule reproduces the real menu exactly and prices new pizzas safely.
- Comma-separated topping lists are split into rows with a **recursive numbers CTE + `SUBSTRING_INDEX`**, then reassembled into human-readable receipts with `GROUP_CONCAT`.

```sql
JOIN seq ON seq.n <= 1 + (LENGTH(col) - LENGTH(REPLACE(col, ',', '')))   -- n ≤ element count
… CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(col, ',', seq.n), ',', -1)) AS UNSIGNED)
```

---

### 03 · 📺 Foodie-Fi — subscription funnels, churn and upgrades

A SaaS journey dataset: free trial → paid plans → churn. Every question is a conversion-analytics question in disguise.

- **1,000 customers; overall churn ≈ 30.7%**, with a measurable slice churning *immediately after trial* — onboarding is the leak.
- **`LAG(plan_id)`** turns raw plan rows into a conversion funnel (trial → basic/pro → churn) with per-plan percentages computed in a single pass.
- A **point-in-time snapshot** pattern (filter dates first, then `ROW_NUMBER … ORDER BY start_date DESC`) reports the active plan mix at 2020-12-31 — the same pattern real retention reports use.
- Time-to-annual-upgrade is averaged and **bucketed into 30-day windows** to show when annual-plan offers should land; an MRR follow-up prices the year-end book.

```sql
LAG(plan_id) OVER (
    PARTITION BY customer_id ORDER BY start_date
) AS prev_plan_id        -- each row can now "see" the customer's previous plan
```

---

### 04 · 🏦 Data Bank — statements, snapshots and reserve cash

A digital bank where customers move between regional nodes over time. The flagship exercise is a **running-balance report built in three granularities**.

```text
customer_transactions  (no natural key!)
        │  + txn_seq surrogate key (ROW_NUMBER)
        ▼
vw_running_balance     per-transaction, explicit ROWS frame
        ▼
vw_daily_closing       last balance of each day per customer
        ▼
monthly closing        last active day's balance per month
        ▼
reserve report         Σ final balances + overdraft exposure
```

- **Temporal (period-accurate) joins** attribute every transaction to the node/region the customer sat on *that day* (`txn_date >= start_date AND txn_date < end_date`) — eliminating fan-out from multi-allocation customers.
- **Median / P80 / P95 reallocation days per region** via a `PERCENT_RANK()` threshold trick, because MySQL has no `PERCENTILE_CONT`.
- The fact table ships **without a `txn_id`**, so a deterministic surrogate sequence is generated once and drives every window frame.
- Business payoff: **reserve cash = Σ positive final balances; overdraft exposure = Σ negative ones** — the number a treasury team would actually ask for.

```sql
SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE -txn_amount END)
  OVER (PARTITION BY customer_id ORDER BY txn_seq
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_balance
```

---

## 🧰 Technique Coverage Matrix

| Technique | 01 | 02 | 03 | 04 |
|---|:--:|:--:|:--:|:--:|
| INNER / LEFT / anti-joins (`… IS NULL`) | ✅ | ✅ | ✅ | ✅ |
| Conditional aggregation `SUM/COUNT(CASE …)` | ✅ | ✅ | ✅ | ✅ |
| CTEs (incl. recursive) | ✅ | ✅ | ✅ | ✅ |
| `ROW_NUMBER` / `RANK` / `DENSE_RANK` | ✅ | — | ✅ | ✅ |
| `LAG` sequencing (prev plan, visit gaps) | ✅ | — | ✅ | — |
| Explicit window frames (`ROWS UNBOUNDED …`) | ✅ | — | — | ✅ |
| `PERCENT_RANK` percentile trick | — | — | — | ✅ |
| `REGEXP_REPLACE` + comma-list splitting | — | ✅ | — | — |
| `GROUP_CONCAT` string assembly | — | ✅ | — | — |
| Temporal / period-accurate joins | — | — | ✅ | ✅ |
| Point-in-time snapshots | — | — | ✅ | ✅ |
| Surrogate keys (`ROW_NUMBER` as id) | — | ✅ | — | ✅ |

---

## 🏗️ How Every Solution Is Built

1. **Layered pipeline** — ingestion → (cleaning) → analysis, each layer re-runnable independently, mirroring real ELT workflows.
2. **CTEs over nested subqueries** — every query reads top-to-bottom like a story; window functions carry explicit frames so behaviour is never implicit.
3. **Validation built in** — cleaning files end with proof queries (zero surviving `'null'` strings, row counts preserved); solutions carry expected-result comments as an answer key.
4. **Interview follow-ups included** — each case study goes beyond the official questions (running spend, MRR, overdraft exposure…), because the follow-up is what interviews actually ask.
5. **Insights, not just outputs** — every per-case README states what the numbers *mean* for the business and where the data's limitations lie.

---

## 💻 How to Run

```bash
# Any case study, in numbered order, e.g. Pizza Runner:
mysql -u root -p < case_study_2_pizza_runner/01_schema_and_data.sql
mysql -u root -p < case_study_2_pizza_runner/02_data_cleaning.sql
mysql -u root -p < case_study_2_pizza_runner/03_solutions.sql
```

Or open the files in **MySQL Workbench** and execute them in order. Case studies 03–04 load the official INSERT/CSV payloads through their `01` scripts (sources linked inside the files).

---

## 🎯 Why Four Case Studies — Depth Over Breadth

These four were chosen deliberately to cover the **four pillars of analytics SQL**: aggregation & ranking (01), cleaning & string surgery on dirty operational data (02), temporal funnels & cohort logic (03), and window frames, snapshots & financial reporting (04). Together they mirror an analyst's day job more completely than a wider but shallower sweep — and every solution here is written to be re-read, re-run and defended in an interview.

---

## 🔗 Beyond This Repository

| Project | What it shows |
|---|---|
| [Netflix-SQL-Analysis](https://github.com/JatinD18/Netflix-SQL-Analysis) | End-to-end SQL analysis + Power BI dashboard on 5,800+ titles |
| [Customer-Segmentation-CLV](https://github.com/JatinD18/Customer-Segmentation-CLV) | RFM → K-Means → CLV pipeline with a Streamlit app |
| [Inventory-Optimization-Dashboard](https://github.com/JatinD18/Inventory-Optimization-Dashboard) | ML demand forecasting + safety stock / reorder-point what-if tool |
| [SuperStore_Sales_Report-PowerBI](https://github.com/JatinD18/SuperStore_Sales_Report-PowerBI) | Executive BI reporting with DAX measures & 30-day forecast |

---

## 👤 Author

**Jatin Naresh Dolas** — Data Analyst | SQL · Python · Power BI · Streamlit

[![GitHub](https://img.shields.io/badge/GitHub-JatinD18-181717?logo=github&logoColor=white)](https://github.com/JatinD18)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Jatin%20Dolas-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/jatin-dolas)

---

*Case-study briefs and datasets © Danny Ma — [8-Week SQL Challenge](https://8weeksqlchallenge.com/). Solutions, cleaning pipelines, follow-ups and documentation by Jatin Naresh Dolas.*
