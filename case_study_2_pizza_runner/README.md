<div align = "center">

# 🍕 Case Study #2 — Pizza Runner

### Part of the [8-Week SQL Challenge](https://8weeksqlchallenge.com/) by Danny Ma · Solved end-to-end in **MySQL 8.0**

![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?logo=mysql&logoColor=white)
![Status](https://img.shields.io/badge/Sections%20Completed-A%20B%20C%20D%20E-brightgreen)
![Queries](https://img.shields.io/badge/Queries-35%2B-blue)

</div>

---

## 🎯 Business Problem

Danny has launched **Pizza Runner**, a pizza-delivery startup, and needs answers across five operational areas:

1. **Pizza Metrics** — order volumes, popular items, customization behaviour
2. **Runner Metrics** — pickup times, distances, speeds, delivery success rates
3. **Ingredient Optimisation** — recipe analysis, extras/exclusions patterns
4. **Pricing & Ratings** — revenue modelling and customer satisfaction
5. **Menu Expansion** — safely adding new products to the schema

The catch: the transactional data is **intentionally dirty** — literal `'null'` strings, distances stored as `'20km'`, durations as `'32 minutes'`, and comma-separated topping lists. This case study is as much a **data-cleaning exercise** as an analytics one.

---

## 🗂️ Repository Structure (3-Layer Pipeline)

```text
case_study_2_pizza_runner/
├── README.md                 # This file
├── 01_schema_and_data.sql    # Layer 1 — Ingestion: raw tables + inserts (incl. ratings)
├── 02_data_cleaning.sql      # Layer 2 — Transformation: raw → clean + validation checks
└── 03_solutions.sql          # Layer 3 — Analysis: Sections A–E, fully commented
```

Run the files **in order** — each layer depends only on the one before it, mirroring a real ELT pipeline.

### Entity Relationships

```text
runners ──< runner_orders >── customer_orders >── pizza_names
                                    │
                                    ├──> pizza_recipes ──(csv list)──> pizza_toppings
                                    └──< ratings
```

---

## 🧹 The Real Test: Data Cleaning (`02_data_cleaning.sql`)

| Raw column | Dirty examples | Cleaned result |
|---|---|---|
| `exclusions` / `extras` | `'null'`, `''` | real SQL `NULL` |
| `pickup_time` | `'null'` | `NULL` / proper `DATETIME` |
| `distance` | `'20km'`, `'23.4 km'`, `'null'` | `20.00`, `23.40`, `NULL` (`DECIMAL`) via `REGEXP_REPLACE` |
| `duration` | `'32 minutes'`, `'20 mins'`, `'40'` | `32`, `20`, `40` (`UNSIGNED`) via `REGEXP_REPLACE` |
| `cancellation` | `'null'`, `''` | real SQL `NULL` |
| *(added)* `row_id` | — | `ROW_NUMBER()` unique line ID — required because the raw table contains **identical duplicate pizza lines** (e.g. order #4) |

The cleaning file ends with **validation queries** (zero surviving `'null'` strings, every delivered order has a pickup time, row counts preserved) — proof the transformation lost nothing.

---

## 📊 Sections & Key Insights

### A. Pizza Metrics
- **14 pizzas** ordered across **10 unique orders**; **8 orders successfully delivered** (1 restaurant + 1 customer cancellation).
- **Ramen is the bestseller** (8 of 14 pizzas); Meatlovers leads delivered volume (9 vs 3 Vegetarian).
- Largest single delivered order: **3 pizzas** (order #4).
- Order #10 is the customization showcase: one plain Meatlovers + one `Exclude BBQ Sauce, Mushrooms / Extra Bacon, Cheese`.

### B. Runner Metrics
- Runner signups: 2 in week 1, 1 in week 2, 2 in week 3.
- **Prep time scales with order size**: ~12 min (1 pizza) → ~18 min (2) → ~29 min (3).
- Delivery success: Runner 1 = **100%**, Runner 2 = 75%, Runner 3 = 50%.
- Speeds cluster at **35–60 km/h**; order #8 (~93.6 km/h) flagged as a **data-quality outlier**.

### C. Ingredient Optimisation
- **Bacon is the most-added extra** (4×) — customers pay to add it.
- **Cheese is the most-excluded topping** (4×) — despite being in *both* standard recipes. Insight: the default recipe conflicts with customer preference; a "no-cheese" base option could reduce kitchen rework.
- Generated human-readable order items (`Meat Lovers - Exclude Cheese - Extra Bacon, Chicken`) and alphabetised ingredient lists with `2x` prefixes using a **recursive numbers CTE + `SUBSTRING_INDEX` string-splitting** technique.

### D. Pricing & Ratings
- Revenue: **$138** base → **$148** with a $2 fee on deliveries ≥ 20 km → **$142** including $1 extras (extras-only revenue = $4).
- Pricing rule discovered: **base $4 + $1 per topping** reproduces the real menu exactly (Meatlovers 8 toppings = $12, Vegetarian 6 = $10) — a safe model for pricing new pizzas.
- Ratings: Vegetarian outscores Meatlovers (3.5 vs 3.0); excluding cancelled orders shifts it to 3.67 vs 3.25. **Runner 3's only delivered order was rated 1/5** — a retention risk.

### E. Bonus
- Added a **Supreme** pizza (all 12 toppings) with `INSERT` statements, validated it via the splitting query, priced it at **$16** using the D3 rule, and provided rollback `DELETE`s to keep the dataset pristine.

---

## 🧰 Key SQL Techniques Practiced

| Technique | Where used |
|---|---|
| `REGEXP_REPLACE` + `CAST` | Stripping `km` / `minutes` text from numeric fields |
| `CASE` + `IN ('null','')` | Converting fake nulls to real `NULL`s |
| `ROW_NUMBER() OVER ()` | Unique line IDs for duplicate order rows |
| Recursive CTE numbers table + `SUBSTRING_INDEX` | Splitting comma-separated toppings / exclusions / extras into rows |
| `GROUP_CONCAT(... ORDER BY ... SEPARATOR)` | Building order-item descriptions & ingredient lists |
| Anti-join (`LEFT JOIN ... WHERE ... IS NULL`) | Recipe **minus** exclusions |
| `UNION ALL` + `COUNT` | Detecting double ingredients (`2x` prefix) |
| `TIMESTAMPDIFF` / `DATEDIFF` | Pickup delays, prep times, signup weeks |
| Conditional aggregation (`SUM(CASE WHEN ...)`) | Change vs no-change counts, delivery fees, success % |
| CTEs over nested subqueries | Throughout — every solution is readable top-to-bottom |

### ⭐ Hardest Query
**C5 — alphabetised ingredient list with `2x` prefixes.** It chains five CTEs: split recipes → split exclusions → split extras → anti-join (recipe − exclusions) → union with extras and count duplicates, then re-aggregates with `GROUP_CONCAT(CONCAT(CASE WHEN qty = 2 THEN '2x' END, name) ORDER BY name)`.

---

## 💻 How to Run

```bash
mysql -u root -p < 01_schema_and_data.sql
mysql -u root -p < 02_data_cleaning.sql
mysql -u root -p < 03_solutions.sql
```

Or in MySQL Workbench: open the three files and execute them **in numbered order**.

---

## 🔭 Possible Extensions

- [ ] Sessionize runner telemetry to detect systematic late pickups
- [ ] What-if simulator for delivery-fee thresholds (break-even analysis)
- [ ] Port the string-splitting logic to `JSON_TABLE` for comparison
- [ ] Window-function version of "first/last order per customer"

---

## ⚠️ Notes & Limitations

- Cancellation flags live at **order level** in `runner_orders`, so a cancelled order removes all of its pizzas from delivered metrics.
- Order #8's distance/duration imply an implausible speed — kept in the data but flagged rather than silently dropped.
- Ratings exist even for cancelled orders; both interpretations (all-rated vs delivered-only) are reported.

---

## 👤 Author

**Jatin Naresh Dolas**
Data Analyst | SQL · Python · Power BI · Streamlit

[![GitHub](https://img.shields.io/badge/GitHub-JatinD18-181717?logo=github&logoColor=white)](https://github.com/JatinD18)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Jatin%20Dolas-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/jatin-dolas)
