# Mid-Level Data Developer Interview Guide

_A targeted study guide focusing on ETL/SSIS, Data Modeling, and BI Tools._

> [!TIP]
> **Interview Strategy for Mid-Level**
> At the mid-level, interviewers want to see that you understand **why** we use certain patterns, not just **how** to use them. Focus on the trade-offs (e.g., Star vs. Snowflake, Type 1 vs. Type 2 SCD) and real-world scenarios where you've applied these concepts.

## 1. ETL / SSIS / Data Flows

### SSIS Task Types

In SSIS, workflows are divided into **Control Flow** (orchestration/logic) and **Data Flow** (data movement/transformation).

- **Data Flow Task:** The core engine for extracting, transforming, and loading data. Moves data from sources (OLE DB, Flat File) to destinations through transformations.
- **Execute SQL Task:** Runs T-SQL statements. _Common use case: Truncating a staging table before a data load, or logging job start/end times._
- **Script Task:** Allows custom C# or VB.NET code. _Common use case: Interacting with an API, advanced file parsing, or complex logic that out-of-the-box components can't handle._
- **For Loop / Foreach Loop Container:** Iterates over a collection. _Common use case: Looping through a folder of daily CSV files and loading them one by one._

### End-to-End ETL Data Validation Methods

How do you ensure the data you moved is correct?

- **Record Count Validation:** Check if `Source Row Count == Destination Row Count`.
- **Data Type & Truncation Checks:** Ensuring string lengths in source don't exceed destination constraints.
- **Financial/Metric Reconciliations:** Check if `SUM(SalesAmount)` in the source matches `SUM(SalesAmount)` in the data warehouse.
- **Referential Integrity Checks:** Identifying orphaned records (e.g., Fact table has a `CustomerID` that doesn't exist in the Customer Dimension).
- **Error Handling:** Instead of failing the whole package on a bad row, redirect bad rows to an "Error Table" for review.

### Slowly Changing Dimensions (SCD)

How do you handle a dimension attribute changing over time (e.g., a customer moves to a new city)?

- **Type 1 (Overwrite):** Overwrites the old data with new data.
  - _Pros:_ Easy to maintain, saves space.
  - _Cons:_ You lose historical context. Past sales are now attributed to the new city.
- **Type 2 (Add New Row):** Keeps full history. Adds a new row for the new city and "expires" the old row.
  - _Implementation:_ Uses columns like `Effective_Date`, `Expiration_Date`, and `Is_Current` flag.
  - _Pros:_ Preserves historical accuracy for reporting.
- **Type 3 (Add New Column):** Keeps limited history by adding a `Previous_City` column. Rarely used compared to Type 2.

---

## 2. Data Modeling & Warehousing

### OLAP vs OLTP

- **OLTP (Online Transaction Processing):**
  - _Purpose:_ Running the business (e.g., E-commerce app, CRM).
  - _Design:_ Highly normalized (3rd Normal Form) to minimize redundancy and maximize fast inserts/updates/deletes.
  - _Queries:_ Simple, targeting single or few records.
- **OLAP (Online Analytical Processing):**
  - _Purpose:_ Analyzing the business (e.g., Data Warehouse).
  - _Design:_ Denormalized (Star/Snowflake) to optimize for fast reads and complex aggregations.
  - _Queries:_ Complex joins, grouping large volumes of historical data.

### Schema Types

- **Star Schema:** One central Fact table surrounded by directly connected Dimension tables.
  - _Pros:_ Very fast query performance, easy for BI tools to understand, intuitive for end-users.
  - _Cons:_ Data redundancy in dimensions.
- **Snowflake Schema:** Dimensions are normalized (split into multiple related tables, e.g., a Product table linking to a Subcategory table, linking to a Category table).
  - _Pros:_ Saves storage space.
  - _Cons:_ Requires more complex queries and more `JOIN`s, which degrades reporting performance.
- **Galaxy Schema (Fact Constellation):** Multiple Fact tables that share common "conformed" dimensions (e.g., a `Sales` Fact and an `Inventory` Fact both connecting to a `Date` Dimension and a `Product` Dimension).

---

## 3. BI Tools (Power BI / Tableau)

### Usage, Dashboards, Drilldowns, Filters

- **Dashboards vs. Reports:** Reports are detailed multi-page interactive views. Dashboards are high-level, single-page executive summaries.
- **Drilldowns:** Allowing users to navigate from summary to detail within the same visual.
  - _Example:_ Clicking on "2023" to reveal Q1, Q2, Q3, Q4, then clicking "Q1" to see Jan, Feb, Mar.
- **Filters vs. Slicers:** Slicers are visual elements on the canvas for users to interact with. Filters operate in the background (Page-level, Report-level, or Visual-level).

### Data Cleansing, Profiling, and Visualization Practices

- **Data Profiling:** Analyzing raw data before using it. Looking at `NULL` distribution, distinct counts, min/max values, and data anomalies.
- **Data Cleansing:** Handling missing values (e.g., replacing NULL with "Unknown"), standardizing formats (e.g., standardizing date formats or capitalizing names), and removing duplicates.
- **Visualization Best Practices:**
  - _Chart Selection:_ Bar/Column charts for comparisons, Line charts for trends over time, Scatter plots for correlations.
  - _Avoid Clutter:_ Minimize the use of pie charts (hard to read if > 3 categories). Don't use 3D charts.
  - _Color Theory:_ Use color purposefully to highlight key data points, not just for decoration. Ensure accessibility (colorblind-friendly palettes).

> [!IMPORTANT]
> **Common Interview Question:** "Walk me through a time you had to optimize a slow dashboard."
> **Good Answer:** Discuss moving calculations from the BI tool (DAX/Tableau Calcs) upstream into the Data Warehouse (SQL) or SSIS. Talk about using a Star Schema instead of one giant flat table, or switching from DirectQuery to Import mode.
