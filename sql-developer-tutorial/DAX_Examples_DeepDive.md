# DAX Deep Dive — Practical Examples for SQL Developers

> **Context:** You already know SQL very well. DAX (Data Analysis Expressions) is the formula language used in **SSAS Tabular** and **Power BI**. This guide teaches DAX by comparing it to SQL you already know.

---

## 🏪 Our Scenario: Coffee Chain Sales

We have a simple Star Schema in our Data Warehouse. This is the data model we will use for ALL examples below.

```
                  ┌─────────────────┐
                  │  DimDate        │
                  │─────────────────│
                  │ DateKey (PK)    │
                  │ Date            │
                  │ Year            │
                  │ Month           │
                  │ MonthName       │
                  │ Quarter         │
                  └────────┬────────┘
                           │
┌──────────────┐   ┌───────┴────────┐   ┌──────────────────┐
│ DimBranch    │   │  FactSales     │   │  DimProduct      │
│──────────────│   │────────────────│   │──────────────────│
│ BranchKey PK │◄──│ BranchKey (FK) │   │ ProductKey (PK)  │
│ BranchName   │   │ ProductKey(FK) │──►│ ProductName      │
│ City         │   │ DateKey (FK)   │   │ Category         │
│ Region       │   │ Quantity       │   │ UnitCost         │
└──────────────┘   │ SalesAmount    │   └──────────────────┘
                   │ Discount       │
                   └────────────────┘
```

---

## 🔑 The #1 Concept: DAX Measures vs. Columns

Before any examples, you must understand this difference.

| | DAX Column | DAX Measure |
|---|---|---|
| **What it is** | A new column added to a table | A calculation result |
| **When calculated** | When data is loaded (stored) | Only when a visual uses it |
| **Equivalent in SQL** | A column in a `SELECT` | An aggregation in SQL (`SUM`, `COUNT`) |
| **Example** | `Profit = FactSales[SalesAmount] - FactSales[Cost]` | `Total Revenue = SUM(FactSales[SalesAmount])` |

> **Rule of thumb:** If your calculation is a **row-level** calculation (like Profit per row), use a **Column**. If it's an **aggregation** (like Total Revenue across many rows), use a **Measure**.

---

## Part 1: Basic Measures (The Equivalent of SQL Aggregations)

### SQL vs. DAX Side-by-Side

#### Example 1: Total Revenue

**SQL:**
```sql
SELECT SUM(SalesAmount) AS TotalRevenue
FROM FactSales
```

**DAX Measure:**
```dax
Total Revenue = SUM(FactSales[SalesAmount])
```

---

#### Example 2: Total Number of Transactions

**SQL:**
```sql
SELECT COUNT(*) AS TotalTransactions
FROM FactSales
```

**DAX:**
```dax
Total Transactions = COUNTROWS(FactSales)
```

---

#### Example 3: Average Order Value

**SQL:**
```sql
SELECT AVG(SalesAmount) AS AvgOrderValue
FROM FactSales
```

**DAX:**
```dax
Avg Order Value = AVERAGE(FactSales[SalesAmount])
```

---

## Part 2: CALCULATE — The Most Important DAX Function

`CALCULATE` is the heart of DAX. It lets you **change the filter context** of a calculation.

> **Think of it like SQL's `WHERE` clause, but you can apply it to any measure dynamically.**

### Example 4: Revenue for a Specific Category

**SQL:**
```sql
SELECT SUM(SalesAmount)
FROM FactSales f
JOIN DimProduct p ON f.ProductKey = p.ProductKey
WHERE p.Category = 'Coffee'
```

**DAX:**
```dax
Coffee Revenue = CALCULATE(
    [Total Revenue],                        -- The base measure
    DimProduct[Category] = "Coffee"         -- The filter to apply
)
```

---

### Example 5: Revenue for a Specific Year

**SQL:**
```sql
SELECT SUM(SalesAmount)
FROM FactSales f
JOIN DimDate d ON f.DateKey = d.DateKey
WHERE d.Year = 2025
```

**DAX:**
```dax
Revenue 2025 = CALCULATE(
    [Total Revenue],
    DimDate[Year] = 2025
)
```

---

### Example 6: Revenue Excluding Discounts (ALL function)

Sometimes you want to **ignore** a filter that the user applied in Power BI.

**Scenario:** A user filters the report to "Ho Chi Minh City" branches. But you want to show Total National Revenue alongside for comparison.

**DAX:**
```dax
National Revenue (All Branches) = CALCULATE(
    [Total Revenue],
    ALL(DimBranch)      -- Ignores the City/Branch filter applied in the report
)
```

---

## Part 3: Time Intelligence — DAX's Superpower

This is where DAX truly shines compared to SQL. Time Intelligence functions handle complex date calculations automatically.

> **Important:** For Time Intelligence to work, you must have a **DimDate** table in your model and mark it as the "Date Table" in SSAS.

### Example 7: Year-To-Date Revenue

**SQL (very painful):**
```sql
SELECT SUM(SalesAmount)
FROM FactSales f
JOIN DimDate d ON f.DateKey = d.DateKey
WHERE d.Year = YEAR(GETDATE())
  AND d.Date <= GETDATE()
```

**DAX (one clean line):**
```dax
Revenue YTD = TOTALYTD([Total Revenue], DimDate[Date])
```

---

### Example 8: Last Year's Revenue (Same Period)

**SQL (complex):**
```sql
SELECT SUM(SalesAmount)
FROM FactSales f
JOIN DimDate d ON f.DateKey = d.DateKey
WHERE d.Year = YEAR(GETDATE()) - 1
  AND d.Date <= DATEADD(YEAR, -1, GETDATE())
```

**DAX (simple):**
```dax
Revenue LY = CALCULATE(
    [Total Revenue],
    SAMEPERIODLASTYEAR(DimDate[Date])
)
```

---

### Example 9: Month-over-Month Growth %

This combines everything above. This is a "Senior Developer" level calculation.

```dax
-- Step 1: Revenue last month
Revenue Last Month = CALCULATE(
    [Total Revenue],
    DATEADD(DimDate[Date], -1, MONTH)
)

-- Step 2: Growth percentage
MoM Growth % = 
    DIVIDE(
        [Total Revenue] - [Revenue Last Month],   -- Numerator
        [Revenue Last Month],                     -- Denominator
        0                                         -- Return 0 if denominator is 0 (avoid division by zero)
    )
```

**DIVIDE() vs. `/`:** Always use `DIVIDE()` in DAX instead of `/`. It safely handles division by zero, which would crash a normal formula.

---

## Part 4: FILTER and RELATED (Advanced)

### Example 10: Count Branches That Exceeded Target

**Scenario:** Count how many branches had sales over 100 million VND this month.

```dax
High Performing Branches = 
    COUNTROWS(
        FILTER(
            DimBranch,                          -- Loop through each branch
            [Total Revenue] > 100000000         -- Check if its revenue > 100M
        )
    )
```

> **SQL equivalent thinking:** This is like `SELECT COUNT(*) FROM DimBranch WHERE Revenue > 100M` — but DAX handles the joins automatically via the model relationships.

---

### Example 11: RELATED — Cross-Table Column Access

When writing a **Calculated Column** in `FactSales`, you cannot directly access `DimProduct[Category]` because it's in another table. You use `RELATED()`.

```dax
-- Calculated Column in FactSales table:
Product Category = RELATED(DimProduct[Category])

-- Now you can use it:
Profit Margin = 
    DIVIDE(
        FactSales[SalesAmount] - RELATED(DimProduct[UnitCost]) * FactSales[Quantity],
        FactSales[SalesAmount],
        0
    )
```

> **SQL equivalent:** `RELATED()` in DAX is the same as a `JOIN` to get a value from another table.

---

## 📝 DAX Cheat Sheet for the Interview

| DAX Function | SQL Equivalent | Use When |
|---|---|---|
| `SUM()` | `SUM()` | Add up a column |
| `COUNTROWS()` | `COUNT(*)` | Count rows in a table |
| `CALCULATE()` | `WHERE` clause | Filter a measure dynamically |
| `ALL()` | Remove `WHERE` clause | Ignore report filters |
| `TOTALYTD()` | Complex date `WHERE` | Year-to-date aggregation |
| `SAMEPERIODLASTYEAR()` | `DATEADD(year, -1, ...)` | Compare to last year |
| `DIVIDE()` | `/ ` with `NULLIF` | Safe division (no divide by zero) |
| `RELATED()` | `JOIN` to get a column | Access column from related table |
| `FILTER()` | `WHERE` in a subquery | Filter a table inside a formula |

---

## 💬 How to Talk About DAX in the Interview

**Interviewer:** "Do you have experience with DAX?"

**You:**
> "Yes. In my experience with SSAS Tabular models, I use DAX to define business metrics as Measures that live in the model itself — not in every individual report. For example, I would create a `MoM Growth %` measure using `CALCULATE` and `DATEADD` once, and then every Power BI report that connects to the model can use it automatically. The key advantage is that `CALCULATE` lets me override the filter context, which is what makes complex calculations like Year-to-Date, Rolling Averages, and Prior Period Comparisons so elegant in DAX compared to writing complex SQL window functions."
