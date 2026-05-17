# SQL Interview Notes

## 1. CTE vs Derived Table: Differences and Performance

### What are they?

- **Derived Table:** A subquery in the `FROM` clause of a `SELECT` statement. It exists only for the duration of that specific `SELECT` statement.
  ```sql
  SELECT a.department_id, a.avg_salary
  FROM (SELECT department_id, AVG(salary) as avg_salary FROM Employees GROUP BY department_id) a
  WHERE a.avg_salary > 5000;
  ```
- **CTE (Common Table Expression):** A temporary named result set defined at the beginning of a query using the `WITH` clause.
  ```sql
  WITH DeptAvg AS (
      SELECT department_id, AVG(salary) as avg_salary FROM Employees GROUP BY department_id
  )
  SELECT department_id, avg_salary FROM DeptAvg WHERE avg_salary > 5000;
  ```

### Key Differences:

1.  **Readability & Reusability:** CTEs are much cleaner and more readable. You define them at the top, and you can reference the _same_ CTE multiple times within the same main query. A derived table cannot be reused; if you need to reference the logic twice, you must write the subquery twice.
2.  **Recursion:** CTEs can be recursive (a query that references itself). This is incredibly useful for hierarchical data like employee-manager organizational charts. Derived tables cannot be recursive.
3.  **Scope:** Both exist only temporarily in memory for the duration of the query.

### Which is faster?

- **In SQL Server, they are almost always the same speed.**
- The SQL Server Query Optimizer treats CTEs and derived tables exactly the same way under the hood. It expands the CTE/derived table definition into the main query and builds a single execution plan for both.
- **Important Interview Gotcha:** If you reference a CTE _multiple times_ in your main query, SQL Server does _not_ cache the CTE results in memory. It will actually re-evaluate and re-run the CTE for each reference. In complex scenarios involving huge datasets, inserting data into a `#TempTable` first is actually much faster than referencing a CTE multiple times.

---

## 2. Window Functions (`SUM() OVER`) vs `GROUP BY`

### The Core Difference: How they handle rows

- **`GROUP BY` (Standard Aggregation):** Collapses multiple rows into a single row per group. You lose the individual row details.
- **`OVER()` (Window Functions):** Calculates the aggregate value but _keeps all the original rows intact_. It appends the aggregate calculation as a new column to the existing rows.

### Example Scenario

Let's say you want to show an employee's salary and the total salary of their entire department.

**Using `GROUP BY`:**

```sql
SELECT department_id, SUM(salary) as total_dept_salary
FROM Employees
GROUP BY department_id;
```

_Result:_ You get 1 row per department. You **cannot** include the individual employee's `name` or their specific `salary` in this query without doing a messy `JOIN` back to the original table.

**Using Window Functions (`SUM() OVER`):**

```sql
SELECT
    name,
    salary,
    department_id,
    SUM(salary) OVER (PARTITION BY department_id) as total_dept_salary
FROM Employees;
```

_Result:_ You get 1 row per employee. The `total_dept_salary` is calculated for the department and attached to _every single employee row_ in that department. You don't lose the employee-level details.

### What about other aggregate functions?

This exact same rule applies to `COUNT()`, `AVG()`, `MAX()`, and `MIN()`.

- `AVG(salary) GROUP BY dept_id` = Collapses the result down to show just the average for the department.
- `AVG(salary) OVER (PARTITION BY dept_id)` = Keeps every employee row, and adds a column showing their department's average salary right next to their individual salary.

### Summary

- Use **`GROUP BY`** when you want to summarize data and _reduce_ the number of rows returned for reporting.
- Use **`OVER(...)`** when you want to calculate aggregate metrics but still need to compare them against the _individual, row-level details_ in your final result set.

---

## 3. Dynamic SQL for PIVOT

### Why do we need Dynamic SQL for PIVOT?

A standard `PIVOT` query requires you to hardcode the new column names in the `IN (...)` clause.
For example: `FOR skill_name IN ([SQL], [Python], [PowerBI])`.

But what if your raw data changes? What if tomorrow a new employee has a skill called `Tableau`? A hardcoded query will ignore it. To solve this, we must construct the SQL query as a string at runtime so it can adapt to whatever data exists in the table.

### Example Scenario

Let's use our `EmployeeSkills` table. We want to pivot the `skill_name` into columns, but we don't know in advance what all the possible skills might be.

```sql
-- 1. Declare variables to hold the dynamic column names and the final query string
DECLARE @ColumnList NVARCHAR(MAX);
DECLARE @DynamicSQL NVARCHAR(MAX);

-- 2. Build the comma-separated list of columns using STRING_AGG (SQL Server 2017+)
-- This will create a string like: '[PowerBI],[Python],[SQL]'
SELECT @ColumnList = STRING_AGG(QUOTENAME(skill_name), ',')
FROM (SELECT DISTINCT skill_name FROM EmployeeSkills) AS DistinctSkills;

-- Note: If using SQL Server older than 2017, you would use FOR XML PATH:
-- STUFF((SELECT ',' + QUOTENAME(skill_name) FROM (SELECT DISTINCT skill_name FROM EmployeeSkills) x FOR XML PATH('')), 1, 1, '')

-- 3. Construct the full SQL query string
-- We inject the @ColumnList variable into the SELECT clause and the IN clause of the PIVOT
SET @DynamicSQL = N'
    SELECT employee_id, ' + @ColumnList + '
    FROM
        (SELECT employee_id, skill_name, proficiency FROM EmployeeSkills) AS SourceTable
    PIVOT
    (
        MAX(proficiency)
        FOR skill_name IN (' + @ColumnList + ')
    ) AS PivotTable;
';

-- 4. Execute the dynamically generated string
EXEC sp_executesql @DynamicSQL;
```

### Key Takeaways for the Interview:

1.  **Understand the limitation:** Hardcoded `PIVOT` queries are fragile in production environments where dimension values change frequently.
2.  **`STRING_AGG` / `FOR XML PATH`:** You must know how to concatenate a dynamic list of strings to build your `[Col1], [Col2]` format. This is step 1 of any dynamic pivot.
3.  **`sp_executesql`:** This is the safest way to execute dynamic SQL in SQL Server (highly preferable to just `EXEC()`) because it supports parameterization, which helps prevent SQL injection in more complex dynamic queries.

---

## 4. UNPIVOT (Columns to Rows)

### What is it?

`UNPIVOT` is the exact opposite of `PIVOT`. It takes a "wide" table (data stored across multiple columns) and transforms it into a "tall" table (data stored in rows).

### Example Scenario

Imagine you have already pivoted the `EmployeeSkills` table into a new table or CTE called `PivotedEmployeeSkills`. It looks like this:

| employee_id | SQL | Python | PowerBI |
| :---------- | :-- | :----- | :------ |
| 1           | 5   | 4      | NULL    |
| 2           | 3   | 5      | 4       |

Now, you want to transform it back to the original row-based format.

```sql
SELECT
    employee_id,
    skill_name,
    proficiency
FROM
    PivotedEmployeeSkills
UNPIVOT
(
    proficiency -- 1. The name of the new column that will hold the actual values
    FOR skill_name IN ([SQL], [Python], [PowerBI]) -- 2. The name of the new column that will hold the old header names, followed by the specific columns to unpivot
) AS UnpivotTable;
```

### Key Takeaways for the Interview:

1.  **No Aggregation Needed:** Unlike `PIVOT`, `UNPIVOT` does _not_ require an aggregate function (like `MAX` or `SUM`). You are splitting data apart, not grouping it together.
2.  **Handling NULLs:** By default, the `UNPIVOT` operator completely ignores `NULL` values. In our example, if employee 1 had `NULL` under `PowerBI`, that row simply will not exist in the final unpivoted result (which is usually the desired behavior).

---

## 5. Recursive CTEs (Hierarchical Data)

### What is it?

A Recursive CTE is a Common Table Expression that references itself. It is primarily used to traverse hierarchical data, such as an organizational chart (Employee -> Manager -> Executive) or a bill of materials (Product -> Component -> Sub-component).

### The 3 Core Components of a Recursive CTE:

Every recursive CTE must have these three exact pieces in this exact order:

1.  **The Anchor Member:** The starting point of the recursion. This query runs exactly once. (e.g., "Find the CEO who has no manager").
2.  **`UNION ALL`:** This operator glues the Anchor Member and the Recursive Member together. It _must_ be `UNION ALL`, not just `UNION`.
3.  **The Recursive Member:** A query that joins the original table back to the CTE itself. This acts like a `WHILE` loop. It takes the output of the previous step and runs again to find the next level down.

### How it executes under the hood:

Let's use the Employee-Manager hierarchy as an example:

1. SQL runs the **Anchor Member** and finds Liam (the CEO). It puts Liam into the result set.
2. SQL passes Liam into the **Recursive Member**. The recursive query looks for anyone whose `manager_id` is Liam's `employee_id`. It finds Emma and Charlotte. It puts them into the result set.
3. SQL passes Emma and Charlotte back into the **Recursive Member**. It looks for anyone whose manager is Emma or Charlotte. It finds Logan. It puts Logan into the result set.
4. SQL passes Logan back into the **Recursive Member**. It looks for anyone whose manager is Logan. It finds nobody (returns an empty set).
5. **Termination:** Because the recursive member returned an empty set, the loop stops. The final combined result set is returned to the user.

### Example (from our Technical Test):

```sql
WITH RecursiveCTE AS (
    -- 1. Anchor Member: Find the top of the chain (CEO)
    SELECT
        employee_id, name, manager_id, 1 AS level
    FROM Employees
    WHERE manager_id IS NULL

    UNION ALL

    -- 2. Recursive Member: Join the CTE back to the original table
    SELECT
        e.employee_id, e.name, e.manager_id, r.level + 1
    FROM Employees e
    INNER JOIN RecursiveCTE r ON e.manager_id = r.employee_id
)
SELECT * FROM RecursiveCTE;
```

### Key Takeaways for the Interview:

- **Infinite Loops:** If your data has a circular reference (A manages B, and B manages A), the recursive CTE will loop infinitely until it hits SQL Server's default limit (`MAXRECURSION 100`) and throws an error. You can override this using `OPTION (MAXRECURSION 0)` at the end of your query for no limit, but you must ensure your data is clean!
- **Performance:** While extremely readable for hierarchies, Recursive CTEs operate iteratively (level-by-level). For massive hierarchies with millions of rows, they can be slow compared to storing data in specialized hierarchy structures (like the `hierarchyid` data type in SQL Server).

---

## 6. UNION vs UNION ALL

### The Core Difference

Both operators are used to combine the result sets of two or more `SELECT` statements vertically into a single result set.

- **`UNION`:** Combines the result sets and **removes duplicates**. It effectively performs a `SELECT DISTINCT` across the combined data.
- **`UNION ALL`:** Combines the result sets and **keeps all duplicates**. It simply glues the two sets of rows together exactly as they are.

### Performance Implication (Crucial for Interviews)

**`UNION ALL` is significantly faster than `UNION`.**

Because `UNION` has to remove duplicates, the SQL Server Query Optimizer must perform an expensive **Sort** or **Hash Aggregate** operation on the entire combined dataset to identify and eliminate matching rows. `UNION ALL` skips this step entirely and just appends the data.

**Best Practice:** Always default to using `UNION ALL` unless you have a specific, undeniable business requirement to remove duplicate rows from the combined result set.

### Why does a Recursive CTE require `UNION ALL`?

In a Recursive CTE, the `UNION ALL` operator is strictly required by SQL Server syntax (using `UNION` will throw an error).

This is because a recursive query operates iteratively—each loop depends entirely on the exact rows generated by the _previous_ loop. If the engine had to stop and deduplicate the entire accumulating dataset (which is what `UNION` does) during every single recursive pass, it would destroy the step-by-step lineage needed to traverse the hierarchy tree. Thus, SQL Server mandates `UNION ALL` to guarantee the raw, unbroken output of each recursive step is passed directly to the next.

---

## 7. Gaps and Islands

### What is it?

"Gaps and Islands" is a classic class of advanced SQL problems that involves finding continuous, unbroken sequences of data ("islands") or identifying the missing sequences between them ("gaps").

The most common interview scenario for this is finding consecutive streaks (e.g., "Find all users who logged in for 3 or more consecutive days" or "Find periods where a machine was running continuously without errors").

### The Two Common Solutions

#### Method 1: The `ROW_NUMBER()` Difference (The Classic, Fast Method)

If you have a sequence of dates, and you assign a `ROW_NUMBER()` to them, the mathematical difference between the `Date` and the `ROW_NUMBER()` will be exactly the same for any continuous streak. The moment a day is skipped (a "gap"), the difference changes, thereby starting a new "island".

```sql
WITH GroupedData AS (
    SELECT
        user_id,
        login_date,
        -- Subtract the row number (as days) from the login_date to create a unique Island ID
        DATEADD(day, -ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY login_date), login_date) as Island_ID
    FROM UserLogins
)
SELECT
    user_id,
    MIN(login_date) as Streak_Start,
    MAX(login_date) as Streak_End,
    COUNT(*) as Streak_Length
FROM GroupedData
GROUP BY user_id, Island_ID;
```

#### Method 2: The `LAG()` & Cumulative Sum (The Robust Production Method)

The `ROW_NUMBER` method breaks instantly if there are duplicate dates (e.g., a user logged in twice on the same day). The `LAG` method is much safer.

You use `LAG()` to look at the previous row's date. If the difference is exactly 1 day, it's part of the same streak (we flag it as `0`). If the difference is > 1 day, it's a gap, meaning a new streak has begun (we flag it as `1`). You then use a running `SUM()` on those `0` and `1` flags to generate a unique `Island_ID`.

```sql
WITH LaggedData AS (
    SELECT
        user_id,
        login_date,
        LAG(login_date) OVER(PARTITION BY user_id ORDER BY login_date) as prev_date
    FROM (SELECT DISTINCT user_id, login_date FROM UserLogins) x -- Always handle duplicates first!
),
FlaggedData AS (
    SELECT
        user_id,
        login_date,
        -- If the gap is > 1 day (or NULL because it's the first row), flag it as a new island
        CASE WHEN DATEDIFF(day, prev_date, login_date) = 1 THEN 0 ELSE 1 END as is_new_island
    FROM LaggedData
),
IslandData AS (
    SELECT
        user_id,
        login_date,
        -- The cumulative sum of the flags creates a unique ID for each continuous streak
        SUM(is_new_island) OVER(PARTITION BY user_id ORDER BY login_date) as Island_ID
    FROM FlaggedData
)
SELECT
    user_id,
    COUNT(*) as Streak_Length
FROM IslandData
GROUP BY user_id, Island_ID;
```

### Key Takeaways for the Interview:

- If an interviewer asks a "consecutive days", "longest streak", or "continuous period" question, you should immediately say out loud: _"Ah, this is a Gaps and Islands problem."_
- The **`ROW_NUMBER()`** method is incredibly elegant and fast to write on a whiteboard, but you must mention to the interviewer that it assumes there are no duplicate dates.
- The **`LAG()`** method takes more code, but it proves you understand how to write robust, production-safe SQL that won't break when dirty data arrives.

---

## 8. CROSS APPLY vs OUTER APPLY

### What is it?

`APPLY` allows you to join a table to a table-valued function or a correlated subquery. Unlike standard joins, the subquery on the right side of the `APPLY` executes _row-by-row_ for every row in the left table.

- **`CROSS APPLY`**: Similar to an `INNER JOIN`. If the right-side function/subquery returns no rows for a given row on the left, that left row is excluded from the final result.
- **`OUTER APPLY`**: Similar to a `LEFT JOIN`. If the right-side returns nothing, the left row is still included with `NULL`s for the right-side columns.

### Classic Interview Scenario: "Get the most recent X for each Y"

For example, get the single most recent order for every customer.

Doing this with standard joins requires messy CTEs, `ROW_NUMBER()`, and an inner join back to the original table. `APPLY` makes it incredibly clean:

```sql
SELECT
    c.customer_id,
    c.customer_name,
    RecentOrders.order_date,
    RecentOrders.amount
FROM Customers c
CROSS APPLY (
    -- This subquery runs once FOR EACH customer
    SELECT TOP 1 order_date, amount
    FROM Orders o
    WHERE o.customer_id = c.customer_id
    ORDER BY order_date DESC
) AS RecentOrders;
```

### Key Takeaways for the Interview:

- If asked to join against a custom table-valued function, you **must** use `APPLY`.
- It is the most elegant solution for the "Top N records per category" problem (e.g., top 3 highest paid employees per department).

---

## 9. SARGable Predicates (Performance Tuning)

### What is SARGable?

SARGable stands for **S**earch **ARG**ument **ABLE**. In interviews, mentioning SARGability proves you understand how the database engine actually fetches data from disk (Performance Tuning).

A query is SARGable if the SQL engine can utilize an Index to find the data quickly (an **Index Seek**). If a query is non-SARGable, the engine must look at every single row in the table (an **Index Scan** / Table Scan), destroying performance on large tables.

### The Golden Rule

**Never apply a function to the column you are searching on.** If you wrap a column in a function, the optimizer goes blind and abandons the index.

### Bad (Non-SARGable) vs Good (SARGable)

**1. Searching Dates:**

- ❌ **BAD:** `WHERE YEAR(order_date) = 2023` (Engine has to run the `YEAR` function on a million rows just to check).
- ✅ **GOOD:** `WHERE order_date >= '2023-01-01' AND order_date < '2024-01-01'` (Engine uses the B-Tree index to instantly jump to the correct date range).

**2. Searching Strings:**

- ❌ **BAD:** `WHERE LEFT(customer_name, 1) = 'A'` or `WHERE customer_name LIKE '%Smith'` (Leading wildcards kill indexes).
- ✅ **GOOD:** `WHERE customer_name LIKE 'A%'` (Trailing wildcards are perfectly fine and SARGable).

**3. Math Operations:**

- ❌ **BAD:** `WHERE salary * 1.1 > 100000`
- ✅ **GOOD:** `WHERE salary > 100000 / 1.1` (Always move the math to the constant side of the equals sign).

---

## 10. T-SQL Batching & Special Commands

### The "Must be the only statement in a batch" Rule

In T-SQL, certain commands are special—they **must be the only statement in a batch**.

If you try to execute them in the same script alongside other commands without separating them, the SQL compiler will throw an error like: `Incorrect syntax near the keyword 'CREATE'`.

The most common commands that have this strict restriction are:

- `CREATE SCHEMA`
- `CREATE VIEW`
- `CREATE PROCEDURE`
- `CREATE FUNCTION`
- `CREATE TRIGGER`

### The Solution: `GO`

To fix this, you must use the `GO` command. `GO` is not an actual SQL statement; it is a batch separator recognized by SQL Server tools (like SSMS or Azure Query Editor). It tells the engine to compile and execute the previous block of code before moving on to the next line.

**❌ BAD (Will fail):**

```sql
CREATE SCHEMA Sales;
CREATE TABLE Sales.Orders (ID INT);
```

**✅ GOOD (Will succeed):**

```sql
CREATE SCHEMA Sales;
GO
CREATE TABLE Sales.Orders (ID INT);
```

---

## 8. Post-Pipeline Data Verification: How Do I Confirm the Data Is Correct?

### The Interview Answer (Say This First)

> *"I apply a 3-layer verification strategy. First, row count reconciliation between source and target. Second, checksum validation on key numeric columns to catch silent data corruption. Third, data quality rules: NULL checks, referential integrity, and duplicate detection. Any failures get logged to an `ErrorLog` table — data never reaches the BI layer silently broken."*

---

### Technique 1: Row Count Reconciliation

**What it checks:** Did every row from the source make it to the destination?

```sql
-- Step 1: Count rows in the source (staging/source table)
SELECT 'Source' AS location, COUNT(*) AS row_count
FROM StagingCustomers

UNION ALL

-- Step 2: Count rows in the destination (DW table)
SELECT 'Target' AS location, COUNT(*) AS row_count
FROM DimCustomer
WHERE load_date = CAST(GETDATE() AS DATE);  -- Only today's loaded rows

-- Expected: both counts should match
```

> ⚠️ **Interview Gold:** Row count matching is necessary but **not sufficient** alone. A broken pipeline could delete 100 rows and insert 100 wrong rows — the count stays the same but the data is wrong. You must combine it with checksum validation.

---

### Technique 2: Checksum / Hash Validation

**What it checks:** Are the actual values the same, not just the row count?

```sql
-- Compare the SUM of a key financial column between source and target
SELECT
    'Source' AS location,
    COUNT(*)                          AS row_count,
    SUM(CAST(SaleAmount AS DECIMAL(18,2))) AS total_amount,
    CHECKSUM_AGG(CHECKSUM(SaleAmount, CustomerID)) AS data_hash
FROM StagingOrders

UNION ALL

SELECT
    'Target' AS location,
    COUNT(*),
    SUM(CAST(SaleAmount AS DECIMAL(18,2))),
    CHECKSUM_AGG(CHECKSUM(SaleAmount, CustomerID))
FROM FactSales
WHERE LoadDate = CAST(GETDATE() AS DATE);
```

**If results match:** ✅ Data integrity confirmed.
**If `total_amount` differs:** ❌ Silent data corruption — values were altered during transformation.
**If `data_hash` differs but `total_amount` matches:** ❌ Individual rows differ (e.g., positive and negative values cancelled each other out).

---

### Technique 3: NULL Checks on Mandatory Columns

**What it checks:** Did any required fields come through as NULL (broken lookups, missing joins)?

```sql
SELECT
    COUNT(*)                              AS total_rows,
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END)  AS null_customer_ids,
    SUM(CASE WHEN SaleAmount IS NULL THEN 1 ELSE 0 END)  AS null_amounts,
    SUM(CASE WHEN LoadDate IS NULL THEN 1 ELSE 0 END)    AS null_dates
FROM FactSales
WHERE LoadDate = CAST(GETDATE() AS DATE);

-- Any column > 0 is an immediate failure condition
```

---

### Technique 4: Referential Integrity Check

**What it checks:** Do all foreign keys in the Fact table actually exist in the Dimension tables? (Orphaned fact rows = broken relationships in Power BI.)

```sql
-- Find fact rows whose CustomerID does not exist in DimCustomer
SELECT f.SaleID, f.CustomerID
FROM FactSales f
LEFT JOIN DimCustomer d ON f.CustomerID = d.CustomerID
WHERE d.CustomerID IS NULL      -- The LEFT JOIN produced a NULL = no match found
  AND f.LoadDate = CAST(GETDATE() AS DATE);

-- Expected result: 0 rows returned
-- Any rows returned = referential integrity failure
```

---

### Technique 5: Duplicate Detection

**What it checks:** Did the pipeline accidentally load the same records twice?

```sql
-- Find any business key combinations that appear more than once
SELECT
    CustomerID,
    OrderDate,
    COUNT(*) AS duplicate_count
FROM FactSales
WHERE LoadDate = CAST(GETDATE() AS DATE)
GROUP BY
    CustomerID,
    OrderDate
HAVING COUNT(*) > 1;

-- Expected result: 0 rows
-- Any rows = duplicate inserts occurred (often from a pipeline re-run without truncating staging)
```

---

### Full Verification Summary Table

| Technique | What It Catches | SQL Tool Used |
| :--- | :--- | :--- |
| **Row Count** | Missing or extra rows | `COUNT(*)` + `UNION ALL` |
| **Checksum / Hash** | Silent value corruption | `SUM()`, `CHECKSUM_AGG()` |
| **NULL Check** | Broken lookups, missing joins | `SUM(CASE WHEN ... IS NULL)` |
| **Referential Integrity** | Orphaned fact rows | `LEFT JOIN ... WHERE IS NULL` |
| **Duplicate Detection** | Double-loaded records | `GROUP BY ... HAVING COUNT > 1` |

### Production Best Practice: Automate Into an Audit SP

In a production environment, encapsulate all 5 checks into a single stored procedure called by the pipeline's final step:

```sql
CREATE PROCEDURE dbo.ValidateDailyLoad
    @LoadDate DATE
AS
BEGIN
    DECLARE @Errors INT = 0;

    -- Check 1: Row count
    IF (SELECT COUNT(*) FROM StagingOrders WHERE CAST(CreatedDate AS DATE) = @LoadDate)
       <> (SELECT COUNT(*) FROM FactSales WHERE LoadDate = @LoadDate)
    BEGIN
        INSERT INTO LoadErrorLog VALUES (@LoadDate, 'Row count mismatch', GETDATE());
        SET @Errors += 1;
    END

    -- Check 2: NULL CustomerID
    IF EXISTS (SELECT 1 FROM FactSales WHERE CustomerID IS NULL AND LoadDate = @LoadDate)
    BEGIN
        INSERT INTO LoadErrorLog VALUES (@LoadDate, 'NULL CustomerID detected', GETDATE());
        SET @Errors += 1;
    END

    -- Return validation status
    IF @Errors = 0
        PRINT 'Validation PASSED for ' + CAST(@LoadDate AS VARCHAR);
    ELSE
        RAISERROR('Validation FAILED: %d error(s) logged. Check LoadErrorLog.', 16, 1, @Errors);
END;
```

