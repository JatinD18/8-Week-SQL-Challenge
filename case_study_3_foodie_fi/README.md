<div align="center">
# 📺 Case Study #3 — Foodie-Fi

### Part of the [8-Week SQL Challenge](https://8weeksqlchallenge.com/) by Danny Ma · Solved end-to-end in **MySQL 8.0**

![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?logo=mysql&logoColor=white)
![Questions](https://img.shields.io/badge/Questions-11%20%2B%202%20follow--ups-blue)
![Focus](https://img.shields.io/badge/Focus-Subscription%20%2F%20SaaS%20Analytics-purple)

</div>

---

## 🎯 Business Problem

Foodie-Fi is a **subscription-based meal-kit startup**: every customer starts on a free trial, then either converts to a paid plan (basic monthly, pro monthly, pro annual) or churns.

The business needs the metrics that define any subscription company:

1. **Trial-to-paid conversion mix** — where do trial users flow?
2. **Churn rate** — overall, and specifically *straight after the trial*
3. **Upgrade behaviour** — how long until customers commit to the annual plan?
4. **Point-in-time plan mix** — what does the active base look like at year-end?
5. **Downgrade detection** — are premium customers slipping to cheaper plans?

This case study is the closest thing in the challenge to a **real SaaS analytics job**: event-sourced subscription data, funnel logic, and cohort-style date math.

---

## 🗂️ Repository Structure (2-Layer Pipeline)

```text
case_study_3_foodie_fi/
├── README.md                # This file
├── 01_schema_and_data.sql   # Layer 1 — Ingestion: plans dimension + subscriptions DDL
└── 02_solutions.sql         # Layer 2 — Analysis: Q1–Q11 + interview follow-ups, commented
```

> **No cleaning layer here** — unlike Pizza Runner, the data arrives clean. This case study is purely about **window functions and date logic**, so the pipeline has only two stages.
>
> **Data note:** `subscriptions` (~1,000 customers, multi-row plan journeys) is loaded from the challenge's CSV via MySQL Workbench's Table Data Import Wizard; `plans` is inserted directly in `01_schema_and_data.sql`.

### Data Model

```text
plans (dimension)  1 ──── N  subscriptions (event-sourced fact)
                                  one row per plan-change per customer
```

| plan_id | plan_name | price |
|---|---|---:|
| 0 | trial | $0.00 |
| 1 | basic monthly | $9.90 |
| 2 | pro monthly | $19.90 |
| 3 | pro annual | $199.00 |
| 4 | churn | NULL |

---

## 📊 Key Insights

### Funnel & Churn
- **1,000 customers** have ever joined; **~307 churned → 30.7% overall churn**.
- **~92 customers churned straight after the free trial** (≈9% of all customers, ≈30% of all churn) → **trial onboarding is the single biggest leak** in the funnel.
- Post-trial conversion flows mostly into **pro monthly**, making it the dominant paid destination.

### Upgrades & Commitment
- **195 customers upgraded to pro annual during 2020.**
- Average time from joining to an annual upgrade is **≈105 days (~3.5 months)**; the 30-day bucket breakdown shows exactly where the commitment decision concentrates — annual-plan offers should land inside that window, not after it.
- **Downgrades (pro monthly → basic monthly) are rare (~8 in 2020)** compared with churn: customers either stay premium or leave entirely. Retention effort should target churn, not downgrade prevention.

### Point-in-Time Base
- The **2020-12-31 snapshot** (filter dates first, then pick each customer's latest event) reveals the active plan mix — the same pattern used for real month-end retention and MRR reporting.

---

## 🧭 Question → Concept Map

| # | Question | Core concept |
|---|---|---|
| 1 | Customers ever | `COUNT(DISTINCT)` |
| 2 | Monthly trial distribution | `DATE_FORMAT` month truncation |
| 3 | Post-2020 events by plan | Date filtering + joins |
| 4 | Churn count & % | Conditional `COUNT(DISTINCT CASE WHEN …)` |
| 5 | Churn straight after trial | `LAG()` previous-plan detection |
| 6 | Plan mix after trial | `LAG()` + `SUM(COUNT(*)) OVER ()` percentages |
| 7 | Plan breakdown at 2020-12-31 | Point-in-time snapshot (`ROW_NUMBER() … DESC`) |
| 8 | Annual upgrades in 2020 | Date-range filtering |
| 9 | Avg days to annual upgrade | `DATEDIFF` + self-join on journey |
| 10 | Upgrade time in 30-day buckets | `CASE` bucketing + window percentages |
| 11 | Pro → basic downgrades | `LAG()` transition detection |
| F1 | MRR at 2020 year-end | Snapshot + annual→monthly price normalization |
| F2 | Monthly event mix per plan | Cohort-feed aggregation |

---

## 🧰 Key SQL Techniques Practiced

| Technique | Where used |
|---|---|
| `LAG(plan_id) OVER (PARTITION BY customer_id ORDER BY start_date)` | Previous-plan detection — churn-after-trial (Q5) and downgrades (Q11) |
| `ROW_NUMBER() OVER (… ORDER BY start_date DESC)` + date filter | "Current plan as of cutoff" snapshot (Q7, F1) |
| `COUNT(DISTINCT CASE WHEN … END)` | One-pass churn numerator/denominator (Q4) |
| `SUM(COUNT(*)) OVER ()` | Percentage-of-total without a cross join or subquery (Q6, Q7, Q10) |
| `DATEDIFF` + `AVG` | Time-to-upgrade measurement (Q9) |
| `CASE` bucketing on day differences | 0–30 / 31–60 / … upgrade windows (Q10) |
| CTE chaining (`journey` → filter → aggregate) | Every multi-step question |

### ⭐ Hardest Query
**Q7 — plan breakdown at 2020-12-31.** The trap is picking each customer's *active* plan at a historical cutoff: you must filter `start_date <= cutoff` **before** ranking, then keep `rn = 1` per customer with `ROW_NUMBER() … ORDER BY start_date DESC`. Get the order wrong and future events leak into the snapshot. This is the exact pattern behind real month-end retention and MRR reports.

---

## 💻 How to Run

```bash
# 1. Schema + plans data; create empty subscriptions table
mysql -u root -p < 01_schema_and_data.sql

# 2. Import subscriptions.csv (challenge dataset) into `subscriptions`
#    via MySQL Workbench → Table Data Import Wizard

# 3. Run all solutions
mysql -u root -p < 02_solutions.sql
```

Or in MySQL Workbench: run `01`, import the CSV, then run `02` — in that order.

---

## 🔭 Possible Extensions

- [ ] Month-by-month **MRR/ARR time series** (snapshot logic applied per month-end)
- [ ] **Retention cohort heatmap** by trial month (trial → month-N survival)
- [ ] Survival curve: % of customers still active N days after trial
- [ ] Compare churn risk by first paid plan (basic vs pro) using `LAG`-derived journeys

---

## ⚠️ Notes & Limitations

- `subscriptions` is **event-sourced**: each row is a plan *change*, not a billing period — durations must be derived from gaps between consecutive `start_date`s.
- The `churn` plan carries a `NULL` price and must be excluded from any revenue/MRR math.
- Every customer is assumed to begin on `trial`; validated by checking each customer's earliest event is `plan_id = 0`.
- Demo dataset — insights illustrate methodology, not real commercial results.

---

## 👤 Author

**Jatin Naresh Dolas**
Data Analyst | SQL · Python · Power BI · Streamlit

[![GitHub](https://img.shields.io/badge/GitHub-JatinD18-181717?logo=github&logoColor=white)](https://github.com/JatinD18)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Jatin%20Dolas-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/jatin-dolas)
