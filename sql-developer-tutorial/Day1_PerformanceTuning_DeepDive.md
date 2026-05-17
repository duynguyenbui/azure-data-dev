# Day 1: Performance Tuning & Advanced Querying Deep Dive

As a Senior SQL Developer in a BI/ETL environment, your ability to make queries run fast is just as important as making them return the right data. Innovature BPO expects you to handle complex data pipelines efficiently. 

This guide breaks down the three core pillars of SQL Server performance tuning you need for the interview.

---

## 1. Indexing Strategy: Clustered vs. Non-Clustered

An index is a data structure that improves the speed of data retrieval operations.

### The Basics
*   **Clustered Index:** Defines the physical sorting order of the data in the table. Because data can only be sorted one way physically, there can be **only one** clustered index per table (usually the Primary Key).
*   **Non-Clustered Index:** A separate data structure from the table (like an index at the back of a textbook). It contains the indexed columns and a "pointer" back to the actual row in the clustered index. You can have many of these on a table.

### 🧠 Senior BI Insights (Interview Gold)
*   **The Power of Covering Indexes (`INCLUDE`):** A common bottleneck is the **Key Lookup**. This happens when a query uses a non-clustered index to find rows, but that index doesn't contain *all* the columns you asked for in your `SELECT`. SQL Server then has to do an expensive jump back to the clustered index to get the missing columns.
    *   **The Fix:** Use the `INCLUDE` clause when creating a non-clustered index to add those extra columns to the leaf level of the index. If the index "covers" the entire query, SQL Server never has to touch the actual table.
*   **ETL Bulk Loading Strategy:** Indexes make `SELECT` faster, but they make `INSERT/UPDATE/DELETE` *slower* because the index has to be updated every time the data changes. **When doing massive ETL data loads, a senior practice is to disable or drop non-clustered indexes before the load, and rebuild them afterward.**

---

## 2. Execution Plans: Reading the Map

An execution plan is the step-by-step map SQL Server generates to execute your query. 

### Key Operators to Look For
1.  **Index Seek (Good):** SQL Server navigated the b-tree index structure to jump directly to the specific rows you requested. (Highly desired for specific lookups).
2.  **Table Scan / Clustered Index Scan (Warning):** SQL Server had to read every single row in the table/index to find the data. 
    *   *Note:* A scan isn't *always* bad. If you are doing a full ETL extraction of a 10-million-row table to load into a data warehouse, a scan is the most efficient method. It is only bad if you only wanted 5 specific rows!
3.  **Key Lookup (Bottleneck):** As mentioned above, this means your non-clustered index wasn't "covering" the query.
4.  **Hash Match vs. Nested Loops (Joins):** 
    *   **Nested Loops:** Good for joining small tables to large tables.
    *   **Hash Match:** Good for joining two massive, unsorted datasets (very common in Data Warehousing / ETL).

---

## 3. CTEs, Window Functions, and Temp Data Structures

These are the core tools for complex data transformation in SQL.

### Temp Tables (`#Temp`) vs. Table Variables (`@Table`)
This is a classic interview question. What is the difference?
*   **Temp Tables (`#TableName`):** Stored in `tempdb`. They **have column statistics**, and you can create indexes on them. SQL Server can generate optimal execution plans for them. **Use these for large datasets.**
*   **Table Variables (`@TableName`):** Also stored in `tempdb` (not just in memory!). They **do NOT have statistics**. SQL Server's query optimizer usually assumes a table variable only contains **1 row**. 
    *   **The Trap:** If you insert 100,000 rows into a table variable and join it to another table, SQL Server will generate a terrible execution plan because it thinks it's only dealing with 1 row. **Use these only for extremely small datasets (e.g., < 100 rows).**

### CTEs (Common Table Expressions)
CTEs (`WITH CTE_Name AS (...)`) are great for making code readable and for recursive queries.
*   **The Senior Trap:** In SQL Server, CTEs are **not materialized** (they are not saved in memory or disk). If you define a CTE and then join to it 3 times in your main query, SQL Server runs the CTE's underlying query 3 separate times! If the CTE is complex, use a `#Temp` table instead.

### Window Functions (`ROW_NUMBER()`, `RANK()`)
These perform calculations across a set of table rows that are related to the current row, without grouping them into a single output row.
*   **Why BI loves `ROW_NUMBER()`:** It is the ultimate tool for **deduplication** and handling **Slowly Changing Dimensions (SCDs)** in staging tables.
*   **Example:** Finding the most recent status record for every customer:
```sql
WITH RankedStatus AS (
    SELECT 
        CustomerID,
        StatusValue,
        UpdateDate,
        ROW_NUMBER() OVER(PARTITION BY CustomerID ORDER BY UpdateDate DESC) as rn
    FROM Staging.CustomerStatus
)
SELECT CustomerID, StatusValue
FROM RankedStatus
WHERE rn = 1; -- rn=1 is always the most recent record!
```

---

## 📝 Summary Cheat Sheet for the Interview
*   **Clustered vs Non-Clustered:** Clustered is physical order (only 1). Non-clustered is a separate pointer list (can have many).
*   **ETL Index Rule:** Disable non-clustered indexes before bulk inserts to speed up the load, rebuild them after.
*   **Key Lookup / Covering Index:** Avoid Key Lookups by adding columns to a non-clustered index using the `INCLUDE` keyword.
*   **Temp Tables vs Table Vars:** `#Temp` tables have statistics (good for big data). `@Table` variables have no statistics (bad for big data, good for small lists).
*   **CTE limitation:** CTEs aren't materialized. If you use it multiple times, SQL Server runs it multiple times.
*   **Window Functions:** Use `ROW_NUMBER() OVER (PARTITION BY... ORDER BY...)` to deduplicate data or find the "latest" record efficiently.
