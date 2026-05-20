# Intensive Study Plan & Answers: BI Developer Interview at Pinnacle Group

**Goal:** Secure the BI/Data Developer position at Pinnacle Group.
**Constraint:** STRICTLY NO AI TOOLS during the interview. All knowledge must be recalled naturally.
**Interview Date:** Wednesday, May 20th, 2026, 11:00 PM (VN Time).

This plan bridges the foundational concepts (to recall your knowledge) with the **Senior/Advanced** concepts (to showcase your deep expertise). The detailed answers and talking points for each topic are provided directly below the study items.

---

## 📑 Table of Contents

- [Section 1: The Technical Test & SQL Core (Execution & Mechanics)](#section-1-the-technical-test--sql-core-execution--mechanics)
- [Section 2: Advanced SQL Deep Dive (Performance & Architecture)](#section-2-advanced-sql-deep-dive-performance--architecture)
- [Section 3: Data Warehousing & Data Modeling](#section-3-data-warehousing--data-modeling)
- [Section 4: SSIS (Integration Services) & ETL Workflows](#section-4-ssis-integration-services--etl-workflows)
- [Section 5: BI Tools & Data Cleansing](#section-5-bi-tools--data-cleansing)
- [Section 6: Behavioral & Client Research (Demonstrating Seniority)](#section-6-behavioral--client-research-demonstrating-seniority)

## Section 1: The Technical Test & SQL Core (Execution & Mechanics)

**Focus:** Solving the technical test and solidifying core SQL execution mechanics.

- **Solve Problem 1 & 2 (Without AI):**
  - _Core:_ Write the `GROUP BY`/`HAVING`, `DELETE` with `CTE` + `ROW_NUMBER()`, and Self-Joins.
  - _Advanced:_ Be prepared to explain the **Execution Plan** for these queries. For example, will your Self-Join result in a Nested Loop or Hash Match? Why is `ROW_NUMBER()` better for performance than a correlated subquery for deleting duplicates?

  **Answer Details:**
  - **Execution Plans: Hash Match vs. Nested Loop**
    - **Nested Loop:** Ideal for small datasets, or when one table is small and the other is large but indexed on the join column. It loops through each row of the outer table and searches the inner table. It's fast for small data but degrades exponentially with large unindexed tables.
    - **Hash Match:** Ideal for large, unsorted, non-indexed datasets. SQL Server builds a hash table in memory from the smaller table, then hashes the join column of the larger table and probes the in-memory hash table for matches. It requires memory (RAM) to build the hash table but is much more efficient than looping through millions of rows.
    - **Merge Join:** Used when both datasets are already sorted on the join column (e.g., both have clustered indexes on the join key). It's the fastest join but requires pre-sorted data.
  - **Deleting Duplicates: `ROW_NUMBER()` vs Correlated Subquery**
    - **`ROW_NUMBER()`:** This requires only a _single pass_ over the data. The engine partitions the data, assigns numbers in memory, and deletes where the number > 1. It is highly optimized and scalable.
    - **Correlated Subquery:** A `DELETE FROM table WHERE id NOT IN (SELECT MAX(id)...)` forces the engine to evaluate the subquery _for every single row_ in the outer table. This leads to an exponential number of reads and terrible performance on large tables.

- **SQL Fundamentals & Beyond:**
  - _Core:_ Memorize the **SQL Order of Execution** (`FROM` -> `WHERE` -> `GROUP BY` -> `HAVING` -> `SELECT` -> `ORDER BY`).
  - _Advanced:_ Explain how the SQL Server Query Optimizer parses, binds, and optimizes (compiles) the execution plan. Understand **SARGable** (Search Argument Able) predicates to avoid accidental index scans.

  **Answer Details:**
  - **SQL Order of Execution:** `FROM / JOIN` -> `WHERE` -> `GROUP BY` -> `HAVING` -> `SELECT` -> `ORDER BY` -> `LIMIT / OFFSET`.
  - **Query Optimizer (Parsing, Binding, Optimizing):**
    - **Parsing:** Checks the SQL string for syntax errors.
    - **Binding (Algebrizer):** Resolves names to objects (checks if tables/columns exist and permissions).
    - **Optimization:** Evaluates multiple execution plans using database statistics and compiles the most cost-effective plan.
  - **SARGable Predicates:** SARGable stands for **Search Argument-Able**. It means your `WHERE` clause is written so the engine can use an Index (Index Seek).
    - _Rule:_ Never wrap a column in a function.
    - _Bad:_ `WHERE YEAR(date) = 2026` (Causes an Index Scan - checks every row).
    - _Good:_ `WHERE date >= '2026-01-01' AND date < '2027-01-01'` (Causes an Index Seek - instantly jumps to the data).

---

## Section 2: Advanced SQL Deep Dive (Performance & Architecture)

**Focus:** Nailing the "Very Important" SQL technical questions with an emphasis on Performance Tuning.

- **Dynamic Grouping (GROUP BY with CASE WHEN):**
  - _Core:_ Understanding how to use `CASE WHEN` inside a `GROUP BY` clause to dynamically bucket or merge rows together based on business logic.
  - _Advanced:_ Explain how conditional grouping avoids the need for complex `UNION` statements or multiple staging tables by standardizing grouping keys on the fly.

  **Answer Details:**
  - **What is it?** Normally, `GROUP BY ColumnA` creates a unique group for every distinct value in `ColumnA`. However, by wrapping a `CASE WHEN` statement inside the `GROUP BY`, you can force different rows to share the exact same grouping key (like forcing a value to `0` or `'Misc'`), which collapses them into a single aggregated row.
  - **Interview Example:** Imagine an HR system where you want to sum up salaries by Department. However, for the "Executive" department, you want to group them together with the "Admin" department to hide their specific salaries, while leaving IT and HR separate.
    ```sql
    SELECT
        -- We must use the exact same CASE statement in the SELECT as the GROUP BY
        CASE
            WHEN DepartmentName IN ('Executive', 'Admin') THEN 'Admin & Exec'
            ELSE DepartmentName
        END AS ReportingDepartment,
        SUM(Salary) AS TotalSalary
    FROM Employees
    GROUP BY
        CASE
            WHEN DepartmentName IN ('Executive', 'Admin') THEN 'Admin & Exec'
            ELSE DepartmentName
        END;
    ```
  - **Why your snippet works:** In your specific snippet (e.g., `CASE WHEN PaySummaryType='A' THEN 0 ELSE PaySummaryBalance END`), the logic is forcing certain Pay Summaries to have a balance of `0` for grouping purposes. By forcing them to `0`, the SQL engine ignores their actual distinct balances and merges all those 'A' type records into a single aggregated row for the report.

- **Advanced SQL Joins (INNER, OUTER, CROSS, APPLY):**
  - _Core:_ Differences between `INNER JOIN`, `LEFT/RIGHT/FULL OUTER JOIN`, and `CROSS JOIN`.
  - _Advanced:_ Explain exactly when and why to use `CROSS APPLY` and `OUTER APPLY` instead of standard joins (e.g., table-valued functions or correlated subqueries returning top N rows).

  **Answer Details:**
  - **INNER JOIN:** Returns only the rows where there is a match in _both_ tables. The most common and performant join.
  - **OUTER JOIN (LEFT, RIGHT, FULL):**
    - `LEFT JOIN`: Returns _all_ rows from the left table, and matching rows from the right table. Unmatched rows on the right are filled with `NULL`.
    - `RIGHT JOIN`: Opposite of LEFT JOIN. (Best practice: Stick to `LEFT JOIN` and swap table order for readability).
    - `FULL OUTER JOIN`: Returns all rows from _both_ tables. Unmatched rows are `NULL` on either side.
  - **CROSS JOIN:** Returns the Cartesian product of both tables. If Table A has 10 rows and Table B has 10 rows, the result is 100 rows. Often used for generating calendar/date dimension tables or dummy data matrices. It has no `ON` clause.
  - **APPLY (CROSS APPLY vs OUTER APPLY):**
    - The `APPLY` operator allows you to join a table to a _table-valued function_ or a _correlated subquery_ where the right side evaluates row-by-row based on values from the left table. Standard joins cannot do this cleanly.
    - **`CROSS APPLY`:** Similar to an `INNER JOIN`. If the right-side function/subquery returns nothing, the left row is dropped.
    - **`OUTER APPLY`:** Similar to a `LEFT JOIN`. If the right-side returns nothing, the left row is kept with `NULL`s.
    - _Interview Goldmine - "Top N Per Category":_ `APPLY` is the absolute cleanest way to solve "Get the single most recent order for every customer."
      ```sql
      SELECT c.CustomerName, LatestOrder.OrderDate
      FROM Customers c
      CROSS APPLY (
          SELECT TOP 1 OrderDate
          FROM Orders o
          WHERE o.CustomerID = c.CustomerID
          ORDER BY OrderDate DESC
      ) AS LatestOrder;
      ```
    - **Why not just use an `INNER JOIN` or `LEFT JOIN`?**
      Standard joins cannot dynamically pass a value from the left table into a subquery on the right side. If you tried to use a standard `JOIN` to a subquery in the `FROM` clause, that subquery would not be allowed to reference `c.CustomerID` from the outer query.
      To solve this with standard joins, you would be forced to use messy workarounds like `ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY OrderDate DESC)` inside a CTE, which requires scanning and sorting the _entire_ Orders table before doing the join. `CROSS APPLY` allows the engine to surgically execute the `TOP 1` query specifically for the individual customers being evaluated, resulting in vastly superior performance and much cleaner code.

- **BULK INSERT (High-Performance Data Loading):**
  - _Core:_ What is the `BULK INSERT` command and when to use it over standard `INSERT` statements.
  - _Advanced:_ Compare `BULK INSERT` with `bcp` and SSIS. Discuss performance tuning like `BATCHSIZE`, `TABLOCK`, and Minimal Logging.

  **Answer Details:**
  - **What is BULK INSERT?** It is a native T-SQL command used to import large data files (like CSVs) directly into a SQL Server table. It is exponentially faster than standard row-by-row `INSERT` statements because it reads the file directly from the file system and can utilize minimal logging.
    ```sql
    BULK INSERT dbo.Staging_Sales
    FROM 'C:\Data\SalesData.csv'
    WITH (
        FIELDTERMINATOR = ',',
        ROWTERMINATOR = '\n',
        FIRSTROW = 2,
        TABLOCK,
        BATCHSIZE = 100000
    );
    ```
  - **BULK INSERT vs. BCP vs. SSIS:**
    - **BULK INSERT:** A T-SQL command. Best when you want to orchestrate the import directly from a Stored Procedure. The major limitation is that the SQL Server Engine account must have direct OS-level read permissions to the file path.
    - **BCP (Bulk Copy Program):** A command-line utility outside of SQL Server. Extremely fast. Best when writing OS-level batch/PowerShell scripts, or when you need to _export_ data (`BULK INSERT` cannot export, it only imports).
    - **SSIS (Integration Services):** A full ETL platform. Use SSIS when the data requires complex transformations, data type casting, or cleansing _before_ it hits the database. `BULK INSERT` and `BCP` are strictly for loading raw data "as-is" into staging tables.
  - **Advanced Interview Topic - Minimal Logging:**
    - To get the absolute fastest load times, SQL Server can bypass writing every single row to the Transaction Log (Minimal Logging).
    - _How to achieve it:_ The database Recovery Model must be set to `SIMPLE` or `BULK_LOGGED`, and you must use the `TABLOCK` hint in the command.
    - _Batch Size:_ By default, `BULK INSERT` loads the entire file in one massive transaction. If it fails near the end, the whole file rolls back (which is very expensive). Using `BATCHSIZE` (e.g., 100,000) breaks the load into smaller, committed chunks.

- **Stored Procedures vs. UDFs:**
  - _Core:_ SPs can perform DML and transactions; UDFs return values and cannot modify state.
  - _Advanced:_ Discuss **Parameter Sniffing** in Stored Procedures and how to fix it (e.g., `OPTION (RECOMPILE)`). Discuss why Scalar UDFs can kill performance (row-by-row execution) and why Inline Table-Valued Functions (iTVFs) are strongly preferred.

  **Answer Details:**

  **1. Stored Procedures (SPs):**
  - **Purpose:** Precompiled SQL code blocks designed to execute business logic, orchestrate ETL processes, or manipulate data.
  - **Capabilities:** Can perform DML (`INSERT`, `UPDATE`, `DELETE`), handle explicit transactions (`BEGIN TRAN`, `COMMIT`, `ROLLBACK`), use error handling (`TRY...CATCH`), and return multiple result sets.
  - **Limitations:** Cannot be used inside a `SELECT`, `WHERE`, or `JOIN` clause. You must execute them using `EXEC`.
  - **Advanced Interview Topic: Parameter Sniffing:**
    - _The Problem:_ When an SP runs for the first time, SQL Server compiles an execution plan optimized for the exact parameters passed _that first time_. If those initial parameters represent a rare edge case, subsequent runs with "normal" parameters will be forced to use that terrible, cached execution plan.
    - _The Fix:_ Add `OPTION (RECOMPILE)` at the end of the query to force the optimizer to build a fresh plan every execution.
      ```sql
      CREATE PROCEDURE GetOrdersByStatus (@Status VARCHAR(20))
      AS
      BEGIN
          SELECT * FROM Orders WHERE Status = @Status
          OPTION (RECOMPILE); -- Forces a new plan every time
      END
      ```

  **2. Scalar User-Defined Functions (Scalar UDFs):**
  - **Purpose:** Takes 0 or more parameters and returns a _single_ scalar value (e.g., an INT or VARCHAR).
  - **Capabilities:** Can be used directly inline in `SELECT` statements or `WHERE` clauses.

    ```sql
    CREATE FUNCTION dbo.GetTaxAmount (@Salary DECIMAL(10,2))
    RETURNS DECIMAL(10,2)
    AS
    BEGIN
        RETURN @Salary * 0.2;
    END

    -- Usage:
    SELECT EmployeeName, dbo.GetTaxAmount(Salary) FROM Employees;
    ```

  - **Limitations:** Cannot modify database state (No DML).
  - **Advanced Interview Topic: The Performance Killer:**
    - Scalar UDFs are notorious performance bottlenecks because they execute _row-by-row_ (RBAR - Row By Agonizing Row). If you have a million rows in your `SELECT`, the function executes a million separate times, completely bypassing set-based optimization.

  **3. Table-Valued Functions (TVFs):**
  - **Purpose:** Takes 0 or more parameters and returns a _Table_ data type.
  - **Capabilities:** You can query against them directly in the `FROM` or `JOIN` clause (especially powerful when paired with `CROSS APPLY`).
  - **Advanced Interview Topic: Inline TVF (iTVF) vs. Multi-Statement TVF (MSTVF):**
    - _iTVF:_ Contains a single `RETURN (SELECT...)` statement. It acts like a parameterized View. The Query Optimizer expands the underlying query and treats it strictly as set-based logic, making it _blazing fast_. This is the gold standard alternative to a Scalar UDF.

      ```sql
      CREATE FUNCTION dbo.GetRecentOrders (@CustomerID INT)
      RETURNS TABLE
      AS
      RETURN (
          SELECT TOP 5 OrderID, TotalAmount
          FROM Orders
          WHERE CustomerID = @CustomerID
          ORDER BY OrderDate DESC
      );

      -- Usage with CROSS APPLY:
      SELECT c.CustomerName, o.TotalAmount
      FROM Customers c
      CROSS APPLY dbo.GetRecentOrders(c.CustomerID) o;
      ```

    - _MSTVF:_ Contains a `BEGIN...END` block where you define a table variable, insert data into it, and return it. These are incredibly slow because the optimizer cannot see inside them, blindly assuming they always return exactly 1 row (ruining the execution plan for large datasets).

- **Temp Tables vs. CTEs:**
  - _Core:_ CTEs exist in memory for a single query; Temp Tables are physical tables in `tempdb`.
  - _Advanced:_ Discuss when CTEs cause performance issues (they don't materialize data, so complex joins can recalculate the CTE repeatedly). Temp Tables can have statistics and indexes generated on them, making them vastly superior for holding massive intermediate datasets.

  **Answer Details:**
  - **CTEs:** Exist only in memory for a single statement. If you reference a CTE 3 times in a query, SQL Server usually executes the underlying logic 3 separate times.
  - **Temp Tables — Local (`#Table`) vs Global (`##Table`):** _(This is a direct interview_prep.md exam point)_
    - **Local Temp Table (`#`):** Prefixed with a **single hash**. Visible **only** to the session (connection) that created it. It is automatically dropped when that session or the stored procedure that created it ends. This is the default and preferred choice in most ETL and SP scenarios.
    - **Global Temp Table (`##`):** Prefixed with a **double hash**. Visible to **all active sessions** across the entire SQL Server instance. It is dropped only when the creating session terminates **AND** no other sessions are actively referencing it. Use sparingly — primarily for sharing intermediate results across multiple sessions in a coordinated batch job.
    - _Why local is preferred for ETL:_ Since SSIS or ADF pipelines can run in parallel, a Global Temp Table could be accidentally shared between concurrent pipeline executions, causing data corruption.
    - _Why they are better for large data:_ You can create Indexes on them, and SQL Server generates statistics for them. Joining a massive intermediate dataset multiple times is dramatically faster using an indexed Temp Table than a CTE.

- **Indexes (Clustered vs. Non-Clustered):**
  - _Core:_ Clustered defines physical disk order; Non-Clustered are separate pointer structures.
  - _Advanced:_ Discuss **Index Fragmentation**, **Fill Factor**, and **Covering Indexes** (`INCLUDE` columns) to completely avoid expensive Key Lookups in the execution plan.

  **Answer Details:**
  - **Clustered Index:** Dictates the physical sort order of the table. You can only have 1.
  - **Non-Clustered Index:** A separate B-Tree structure pointing back to the physical data.
    - _What is a B-Tree?_ A Balanced Tree (B-Tree) is a hierarchical data structure optimized for fast disk reads. It consists of a **Root Node** (the top entry point), **Intermediate Nodes** (the signposts guiding the search), and **Leaf Nodes** (the bottom layer).
    - _How it works:_ Because the tree remains "balanced" (meaning all paths from root to leaf are the same length), SQL Server can find any record out of millions in just 3 or 4 rapid jumps — giving it incredible performance instead of a slow table scan. In a non-clustered index, the leaf nodes hold the indexed value and a pointer (row locator) back to the actual physical data row.
  - **Covering Index:** An index that contains all the columns requested in the `SELECT` and `WHERE` clauses. If an index has the lookup column but lacks a selected column, SQL Server performs a costly "Key Lookup" back to the clustered index. You fix this using the `INCLUDE (col1, col2)` clause on your non-clustered index.

    **Example — The Key Lookup Problem:**

    ```sql
    -- You have this query running thousands of times per hour:
    SELECT EmployeeName, Salary
    FROM Employees
    WHERE Department = 'Engineering';

    -- You created this index to help the WHERE clause:
    CREATE NONCLUSTERED INDEX IX_Employees_Dept
    ON Employees(Department);
    -- ❌ PROBLEM: The index only has Department. SQL Server must do a
    -- separate "Key Lookup" for EVERY matching row to fetch EmployeeName and Salary.
    -- With 10,000 Engineering employees, that is 10,000 extra random reads!
    ```

    **The Fix — Covering Index with INCLUDE:**

    ```sql
    -- Drop the old index and create a Covering Index instead:
    CREATE NONCLUSTERED INDEX IX_Employees_Dept_Covering
    ON Employees(Department)        -- Search/Filter column goes here
    INCLUDE (EmployeeName, Salary); -- Extra columns needed by SELECT go in INCLUDE

    -- ✅ RESULT: SQL Server can now answer the entire query from the index leaf node alone.
    -- Zero Key Lookups. The query goes from slow to lightning fast.
    ```

    > **Rule of thumb:** If you see a "Key Lookup" operator in an execution plan, your query is a candidate for a Covering Index with `INCLUDE`.

  - **Fragmentation & Fill Factor:** Over time, `INSERT/UPDATE`s cause data pages to split and become fragmented. `Fill Factor` tells SQL Server to leave a percentage of empty space on each data page (e.g., 80% full, 20% empty) to accommodate future inserts without causing page splits.

    **Example — Checking and Fixing Fragmentation:**

    ```sql
    -- Step 1: Check fragmentation level on a table
    SELECT
        index_id,
        index_type_desc,
        avg_fragmentation_in_percent,
        page_count
    FROM sys.dm_db_index_physical_stats(
        DB_ID(),          -- Current database
        OBJECT_ID('Employees'), -- Target table
        NULL, NULL, 'DETAILED'
    );
    -- avg_fragmentation_in_percent tells you how fragmented it is:
    --   < 10%  → No action needed
    --   10–30% → REORGANIZE (online, lightweight)
    --   > 30%  → REBUILD (takes more time but fully defragments)

    -- Step 2a: Light fix — REORGANIZE (does not lock the table)
    ALTER INDEX IX_Employees_Dept ON Employees REORGANIZE;

    -- Step 2b: Full fix — REBUILD (locks table briefly but full defragmentation)
    ALTER INDEX IX_Employees_Dept ON Employees REBUILD
    WITH (FILLFACTOR = 80); -- Rebuild and set Fill Factor to 80% full / 20% free space
    ```

    > **Fill Factor interview tip:** A Fill Factor of `80` means each data page is only filled to 80% — leaving 20% free for future inserts. This prevents page splits (which are the root cause of fragmentation) for tables with heavy write activity. For read-only/reporting tables, use `100` (fully packed) for maximum read performance.

  **Index Creation Syntax (How to "Mark" an Index):**

  ```sql
  -- 1. Create a Clustered Index (Usually created automatically by the Primary Key)
  CREATE CLUSTERED INDEX CIX_Employees_EmpID
  ON Employees(EmployeeID);

  -- 2. Create a Non-Clustered Index (Basic B-Tree for fast lookups)
  CREATE NONCLUSTERED INDEX IX_Employees_Department
  ON Employees(Department);

  -- 3. Create a Covering Index (Non-Clustered with INCLUDE to avoid Key Lookups)
  CREATE NONCLUSTERED INDEX IX_Employees_Department_Covering
  ON Employees(Department)
  INCLUDE (Salary, HireDate);
  ```

  **How to Choose the "Correct" Index (Interview Strategy):**
  - **Primary Key / Range Queries:** Use a **Clustered Index**. You only get one, so put it on a column that is sequentially increasing (like `IDENTITY`) or frequently used for `ORDER BY` and range queries (`BETWEEN`, `<`, `>`) — e.g., `OrderDate`.
  - **Frequent Lookup/JOIN Columns:** Use a **Non-Clustered Index**. Best for columns frequently used in `WHERE` or `JOIN` clauses that have high selectivity (many unique values, like `Email` or `Department`).
  - **To Prevent Key Lookups:** Use a **Covering Index (`INCLUDE`)**. If a slow query frequently filters by `Department` but also needs to display `Salary`, adding `INCLUDE (Salary)` to the index on `Department` makes the query lightning fast by completely satisfying the query from the B-Tree leaf node without jumping back to the physical table.

- **Window Functions:**
  - _Core:_ `RANK()`, `DENSE_RANK()`, `ROW_NUMBER()`, `PARTITION BY`.
  - _Advanced:_ Discuss performance implications and framing clauses (e.g., `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`) for calculating running totals efficiently.

  **Answer Details:**
  - `ROW_NUMBER()`: Sequential (1, 2, 3, 4).
  - `RANK()`: Skips ties (1, 2, 2, 4).
  - `DENSE_RANK()`: Does not skip (1, 2, 2, 3).
  - **Framing:** The `OVER` clause defaults to `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`. Specifying `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` is physically much faster for running totals because `ROWS` looks at physical rows, while `RANGE` logically groups ties, adding heavy sorting overhead.

  **Example — ROW_NUMBER vs RANK vs DENSE_RANK:**

  ```sql
  -- Setup: two employees with the SAME salary of 5000 (a tie)
  -- Name       | Salary
  -- Alice      | 7000
  -- Bob        | 5000
  -- Carol      | 5000   ← tie with Bob
  -- Dave       | 3000

  SELECT
      Name,
      Salary,
      ROW_NUMBER() OVER (ORDER BY Salary DESC) AS row_num,
      -- Result: 1, 2, 3, 4  — always unique, breaks ties arbitrarily

      RANK()       OVER (ORDER BY Salary DESC) AS rank_num,
      -- Result: 1, 2, 2, 4  — Bob and Carol both get rank 2, then skips to 4

      DENSE_RANK() OVER (ORDER BY Salary DESC) AS dense_rank_num
      -- Result: 1, 2, 2, 3  — Bob and Carol both get rank 2, next is 3 (no skip)
  FROM Employees;
  ```

  **Example — Practical use: Delete duplicates keeping only the first row:**

  ```sql
  WITH CTE_Duplicates AS (
      SELECT *,
          ROW_NUMBER() OVER (
              PARTITION BY Email         -- Group rows with the same email
              ORDER BY CreatedDate DESC  -- Keep the most recent one (ROW_NUMBER = 1)
          ) AS rn
      FROM Employees
  )
  DELETE FROM CTE_Duplicates WHERE rn > 1; -- Delete all duplicates
  ```

  **Example — Running Total (Framing clause):**

  ```sql
  SELECT
      Name,
      Department,
      Salary,
      -- Running total of salary within each department, row by row:
      SUM(Salary) OVER (
          PARTITION BY Department
          ORDER BY Salary DESC
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW  -- ← ROWS is faster than RANGE
      ) AS RunningTotal
  FROM Employees;
  -- Output for Engineering dept:
  -- Alice  | 7000 | RunningTotal: 7000
  -- Bob    | 5000 | RunningTotal: 12000
  -- Carol  | 5000 | RunningTotal: 17000
  ```

- **PIVOT & UNPIVOT:**
  - _Core:_ Transforming row-level data into columns (`PIVOT`) or columns into rows (`UNPIVOT`).
  - _Advanced:_ Explain the three strict requirements of PIVOT (Source Subquery, Aggregate Function, `FOR...IN` clause). Be prepared to discuss why **Dynamic SQL** is required when the column headers are unknown beforehand.

  **Answer Details:**
  - **Requirements:** A PIVOT requires a clean source subquery, an aggregate function, and a `FOR ... IN (...)` clause containing hardcoded column headers.
  - **Dynamic SQL:** Because PIVOT headers must be hardcoded, dynamic data (like constantly changing Product Names) will break the query. You solve this by building a comma-separated string of the new columns using `STRING_AGG`, concatenating it into a dynamic SQL string, and executing it via `sp_executesql`.

  **Example — PIVOT (Rows → Columns):**

  ```sql
  -- Source data (rows):
  -- Year | Quarter | Revenue
  -- 2024 | Q1      | 100
  -- 2024 | Q2      | 150
  -- 2024 | Q3      | 200
  -- 2024 | Q4      | 120

  SELECT *
  FROM (
      SELECT [Year], Quarter, Revenue  -- Step 1: Clean source subquery
      FROM SalesData
  ) AS SourceData
  PIVOT (
      SUM(Revenue)                     -- Step 2: Aggregate function
      FOR Quarter IN ([Q1],[Q2],[Q3],[Q4])  -- Step 3: Hardcoded column headers
  ) AS PivotResult;

  -- Result (columns):
  -- Year | Q1  | Q2  | Q3  | Q4
  -- 2024 | 100 | 150 | 200 | 120
  ```

  **Example — UNPIVOT (Columns → Rows):**

  ```sql
  -- Source data (wide/columnar format):
  -- Year | Q1  | Q2  | Q3  | Q4
  -- 2024 | 100 | 150 | 200 | 120

  SELECT [Year], Quarter, Revenue
  FROM PivotResult
  UNPIVOT (
      Revenue         -- New column name for the values
      FOR Quarter IN ([Q1],[Q2],[Q3],[Q4])  -- Columns to collapse into rows
  ) AS UnpivotResult;

  -- Result: back to row format
  -- Year | Quarter | Revenue
  -- 2024 | Q1      | 100
  -- 2024 | Q2      | 150
  ```

- **MERGE Statement (UPSERT Pattern):**
  - _Core:_ The syntax combining `INSERT`, `UPDATE`, and `DELETE` in a single statement to synchronize a target table with a source table.
  - _Advanced:_ Discuss the performance implications of `MERGE` vs separate statements, the mandatory semicolon, and how to prevent concurrency deadlocks using the `HOLDLOCK` hint.

  **Answer Details:**
  - **The Concept:** Often referred to as an "UPSERT" (Update if exists, Insert if it does not). It compares a Source table/query to a Target table based on a specific join condition.
  - **The Syntax Structure:** You define actions based on three potential match states:
    - `WHEN MATCHED THEN UPDATE...` (Exists in both)
    - `WHEN NOT MATCHED BY TARGET THEN INSERT...` (Exists in source, missing in target)
    - `WHEN NOT MATCHED BY SOURCE THEN DELETE...` (Exists in target, missing in source - optional)
  - **Mandatory Syntax Rule:** The `MERGE` statement **must** be terminated with a semicolon (`;`), otherwise SQL Server will throw a syntax error.
  - **Advanced Interview Topic: Concurrency & Deadlocks:**
    - While `MERGE` is highly readable for ETL processes, it is notorious for causing deadlocks in highly concurrent environments (e.g., multiple processes trying to upsert at the same time).
    - _The Fix:_ Always use the `WITH (HOLDLOCK)` hint on the target table (e.g., `MERGE INTO TargetTable WITH (HOLDLOCK) AS T`). This serializes access and prevents race conditions where a separate transaction might insert a row in the split-second between the `MERGE` statement's initial read and subsequent write phase.

  **Example — Full Production MERGE (DimCustomer SCD Type 1 UPSERT):**

  ```sql
  -- Scenario:
  -- StagingCustomers has fresh data from the source system.
  -- DimCustomer is the target warehouse dimension table.
  -- Goal: Update changed customers, insert new ones, delete removed ones.

  MERGE INTO DimCustomer WITH (HOLDLOCK) AS Target  -- ← HOLDLOCK prevents deadlocks
  USING (
      SELECT CustomerID, CustomerName, City, Email
      FROM StagingCustomers
  ) AS Source
  ON Target.CustomerID = Source.CustomerID           -- ← Join condition

  -- Case 1: CustomerID exists in BOTH → Update changed columns
  WHEN MATCHED AND (
      Target.CustomerName <> Source.CustomerName OR
      Target.City         <> Source.City
  ) THEN
      UPDATE SET
          Target.CustomerName = Source.CustomerName,
          Target.City         = Source.City,
          Target.UpdatedDate  = GETDATE()

  -- Case 2: CustomerID is in Source but NOT in Target → New customer, insert
  WHEN NOT MATCHED BY TARGET THEN
      INSERT (CustomerID, CustomerName, City, Email, CreatedDate)
      VALUES (Source.CustomerID, Source.CustomerName, Source.City,
              Source.Email, GETDATE())

  -- Case 3: CustomerID is in Target but NOT in Source → Customer deleted, remove
  WHEN NOT MATCHED BY SOURCE THEN
      DELETE;
  -- ↑ Semicolon is MANDATORY — MERGE will error without it
  ```

  **What each case looks like with data:**

  ```
  StagingCustomers (Source)     DimCustomer (Target)      Action
  C001 | Alice | Boston    ←→  C001 | Alice | New York  → MATCHED + City changed → UPDATE
  C002 | Bob   | Chicago   ←→  (not found)               → NOT MATCHED BY TARGET  → INSERT
  (not found)               ←→  C003 | Carol | Dallas    → NOT MATCHED BY SOURCE  → DELETE
  ```

- **Transactions in SQL Server:**
  - _Core:_ What a transaction is, ACID properties, and the 4 transaction types.
  - _Advanced:_ Transaction isolation levels and handling errors safely with `TRY...CATCH`.

  **What Is a Transaction?**
  A transaction is a logical unit of work that groups one or more SQL statements together. Either **all statements succeed and are committed**, or **all statements fail and are rolled back** — the database never ends up in a half-finished state.

  **ACID Properties — The Foundation:**

  | Property            | Meaning                                                                               | Example                                                                     |
  | :------------------ | :------------------------------------------------------------------------------------ | :-------------------------------------------------------------------------- |
  | **A — Atomicity**   | All-or-nothing. Every statement succeeds, or none do.                                 | Debit one account AND credit another — if credit fails, debit must reverse. |
  | **C — Consistency** | After the transaction, the database is in a valid state. No constraints violated.     | A bank transfer cannot change the total money in the system.                |
  | **I — Isolation**   | Concurrent transactions cannot see each other's uncommitted changes.                  | Two users booking the last seat — only one should succeed.                  |
  | **D — Durability**  | Once committed, data is permanently written even if server crashes immediately after. | Your order confirmation is permanent once payment succeeds.                 |

  ***

  **The 4 Types of SQL Server Transactions:**

  **Type 1 — Autocommit Transaction (Default)**
  Every single SQL statement is its own automatic transaction. No `BEGIN TRAN` needed.

  ```sql
  -- Each statement is an independent, self-committing transaction
  INSERT INTO Orders VALUES (1, 'New York', 500.00);  -- Auto-committed
  UPDATE Products SET Stock = Stock - 1 WHERE ID = 10; -- Auto-committed separately
  ```

  > ⚠️ **Risk:** If `INSERT` succeeds but `UPDATE` fails, you have an order but no stock reduction. Data is now inconsistent. This is why you need Explicit Transactions when statements depend on each other.

  **Type 2 — Explicit Transaction (Most Important for Interviews)**
  You manually control start and end using `BEGIN TRANSACTION`, `COMMIT`, and `ROLLBACK`.

  ```sql
  BEGIN TRANSACTION;
  BEGIN TRY
      UPDATE BankAccounts SET Balance = Balance - 500 WHERE AccountID = 1; -- Debit
      UPDATE BankAccounts SET Balance = Balance + 500 WHERE AccountID = 2; -- Credit
      COMMIT TRANSACTION; -- Both succeeded — save permanently
  END TRY
  BEGIN CATCH
      ROLLBACK TRANSACTION; -- Something failed — undo everything
      THROW;                -- Re-raise the error to the caller
  END CATCH;
  ```

  **Type 3 — Implicit Transaction**
  SQL Server automatically starts a new transaction after each `COMMIT` or `ROLLBACK` — you never write `BEGIN TRAN`. Enabled via `SET IMPLICIT_TRANSACTIONS ON`.

  > Rarely used in SQL Server. Easy to forget to `COMMIT`, leaving open transactions that block other sessions.

  **Type 4 — Distributed Transaction**
  A transaction that spans **multiple databases or multiple servers**. Managed by the **Microsoft Distributed Transaction Coordinator (MSDTC)**.

  ```sql
  BEGIN DISTRIBUTED TRANSACTION;
      INSERT INTO LocalDB.dbo.Orders VALUES (1, 'Item A');
      INSERT INTO [RemoteServer].RemoteDB.dbo.OrderLog VALUES (1, GETDATE());
  COMMIT;
  ```

  > In modern cloud architectures, distributed transactions are replaced by the **Saga Pattern** because MSDTC is unreliable across cloud services.

  ***

  **Transaction Isolation Levels (Bonus — shows seniority):**

  Controls how much one transaction can _see_ the uncommitted work of concurrent transactions. To understand isolation levels, you must first understand the **Read Anomalies** they prevent:
  - **Dirty Read:** Reading uncommitted data. (e.g., You read a bank balance as $1000 while another transaction is updating it. That transaction fails and rolls back to $500, but you've already generated a report using the fake $1000).
  - **Non-Repeatable Read:** Reading the same row twice in one transaction, but getting different data because someone else `UPDATE`d it in between your reads.
  - **Phantom Read:** Running a `SELECT` with a `WHERE` clause twice, but getting a different number of rows because someone else `INSERT`ed or `DELETE`d rows that match your `WHERE` condition in between your reads.

  | Level                          | Dirty Read | Non-Repeatable Read | Phantom Read | Use Case                                                            |
  | :----------------------------- | :--------: | :-----------------: | :----------: | :------------------------------------------------------------------ |
  | **READ UNCOMMITTED**           |     ✅     |         ✅          |      ✅      | Max speed, least safety. OK for rough reports only.                 |
  | **READ COMMITTED** _(default)_ |     ❌     |         ✅          |      ✅      | Standard default. Only reads committed data.                        |
  | **REPEATABLE READ**            |     ❌     |         ❌          |      ✅      | Prevents row changes between reads in same transaction.             |
  | **SERIALIZABLE**               |     ❌     |         ❌          |      ❌      | Maximum protection, heaviest locking.                               |
  | **SNAPSHOT**                   |     ❌     |         ❌          |      ❌      | Row versioning — reads a point-in-time copy. No locks. Best for BI. |

  > **Interview Answer:** _"For BI reporting queries that run long and should never block production writes, I use `SNAPSHOT` isolation. It reads a consistent point-in-time snapshot using row versioning in `tempdb`, so reporting never conflicts with live DML transactions."_

---

## Section 3: Data Warehousing & Data Modeling

#### 📘 Foundational Definitions (Start Here Before Memorizing the Advanced Details)

Before diving into specifics, you must understand what these core terms _actually mean_. An interviewer may ask "define this from scratch."

| Term                               | Plain-English Definition                                                                                                                                                                                                                  |
| :--------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Data Warehouse (DW)**            | A specialized database built _purely for analysis_ — NOT for day-to-day transactions. Think of it as a historical archive that has already cleaned, organized, and transformed data so analysts can query it quickly.                     |
| **Data Modeling**                  | The act of designing how tables relate to each other in your database. In a warehouse, this means deciding which tables hold raw numbers (Fact Tables) and which tables hold descriptive context (Dimension Tables).                      |
| **Fact Table**                     | The central table in a data warehouse. It holds **measurable, numeric business events** — things you can count, sum, or average. Examples: `SalesAmount`, `Quantity`, `Revenue`. Fact tables are typically very large (millions of rows). |
| **Dimension Table**                | A supporting table that provides **context** for the facts. Answers the questions: _Who? What? Where? When? Which?_ Examples: `DimCustomer`, `DimProduct`, `DimDate`, `DimRegion`. Much smaller than fact tables.                         |
| **Grain**                          | The level of detail in a fact table. Example: _"One row = one individual product line within one sales order."_ Defining the grain is the most important design decision you make.                                                        |
| **Conformed Dimension**            | A dimension table shared across multiple fact tables (e.g., `DimDate` is used by both `FactSales` and `FactInventory`). This is what enables cross-process analysis.                                                                      |
| **ETL (Extract, Transform, Load)** | The data pipeline pattern: **Extract** data from source systems → **Transform** it (clean, join, aggregate) → **Load** it into the data warehouse. SSIS is Microsoft's ETL tool.                                                          |
| **ELT (Extract, Load, Transform)** | Modern cloud pattern: Extract → Load raw data first → Transform inside the warehouse using SQL. Used in Azure Data Factory / Databricks pipelines.                                                                                        |
| **Normalization**                  | Organizing data to eliminate duplication by breaking it into many related tables. Used in OLTP systems. Efficient for writes but slow for reads.                                                                                          |
| **Denormalization**                | Collapsing related tables into fewer, wider tables to avoid joins. Used in OLAP/data warehouses. Faster reads but uses more storage.                                                                                                      |
| **OLTP**                           | **Online Transactional Processing.** Databases optimized for fast INSERT/UPDATE/DELETE operations. Highly normalized. Used in live applications (e.g., order management systems).                                                         |
| **OLAP**                           | **Online Analytical Processing.** Databases optimized for fast complex reads and aggregations. Denormalized (Star Schema). Used in BI reporting.                                                                                          |

#### ✅ Topic 1: OLAP vs OLTP _(interview_prep.md line 29)_

| Dimension      | OLTP                                         | OLAP                                        |
| :------------- | :------------------------------------------- | :------------------------------------------ |
| **Purpose**    | Day-to-day transactions (orders, payments)   | Historical analysis and reporting           |
| **Schema**     | Highly normalized (3NF, many tables)         | Denormalized (Star/Snowflake, fewer joins)  |
| **Operations** | Mostly INSERT / UPDATE / DELETE              | Mostly SELECT with complex aggregations     |
| **Query Type** | Simple, fast, single-row                     | Complex, slow, returns millions of rows     |
| **Users**      | Clerks, customers, applications              | Analysts, managers, BI tools (Power BI)     |
| **Example**    | Order Management System (SQL Server OLTP DB) | Sales Data Warehouse (Azure Synapse / SSAS) |

#### ✅ Topic 2: Schema Types — Star, Snowflake, Galaxy _(interview_prep.md line 28)_

| Schema                          | Structure                                    | Best For                                          | Trade-off                            |
| :------------------------------ | :------------------------------------------- | :------------------------------------------------ | :----------------------------------- |
| **Star**                        | 1 Fact + fully denormalized Dimensions       | Power BI, fast queries (default BI choice)        | More storage used                    |
| **Snowflake**                   | 1 Fact + normalized Dimension sub-tables     | Saving storage, enforcing data integrity          | More JOINs, slower query performance |
| **Galaxy (Fact Constellation)** | Multiple Fact tables + shared conformed Dims | Enterprise models comparing 2+ business processes | Most complex to design               |

- **Star Schema:** Dimension tables are fully flattened — only **one JOIN** needed from Fact to any attribute. Power BI is built around this model.
  - **Example:** `FactSales` joins directly to `DimProduct` (which contains `ProductID`, `ProductName`, `SubcategoryName`, and `CategoryName` all in one wide table).
  - **When to use:** **95% of the time in modern BI.** Storage is cheap, but compute (joins) is expensive. Power BI and Tableau perform best with Star Schemas because they minimize JOIN paths.

- **Snowflake Schema:** Dimensions are split into sub-tables (normalized). Saves disk but adds cascading joins.
  - **Example:** `FactSales` joins to `DimProduct`. To find the category name, `DimProduct` must join to `DimSubcategory`, which then joins to `DimCategory`.
  - **When to use:** When you have a massive dimension table (e.g., 50 million customers) and strict data governance requires normalization, or when you are severely constrained on disk space (rare nowadays).

- **Galaxy Schema (Fact Constellation):** _(Trick question favorite)_ Multiple fact tables share the same conformed dimensions.
  - **Example:** You have `FactSales` (records when items are sold) and `FactInventory` (records daily stock levels). Both tables connect to the exact same `DimDate` and `DimProduct` tables.
  - **When to use:** When the business asks: _"Show me yesterday's sales vs. remaining inventory for each product."_ You need a Galaxy schema to bridge two different business processes (Sales and Inventory) using shared dimensions.

#### Topic 3: Advanced Fact Table Design _(from Topic 7)_

| Fact Table Type           | Description                                                                                                                                      | When to use                                         | Giải thích tiếng Việt                                                                                |
| :------------------------ | :----------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------- | :--------------------------------------------------------------------------------------------------- |
| **Transactional**         | Records an event precisely when it happens (e.g., a single sales checkout). Extremely fast inserts, massive volume.                              | Every time an event occurs.                         | _Bảng sự kiện giao dịch: Ghi nhận ngay khi sự kiện xảy ra (vd: quẹt thẻ). Nhanh, dữ liệu cực lớn._   |
| **Periodic Snapshot**     | Records the state of something at regular intervals (e.g., daily bank balance).                                                                  | Trend analysis over time.                           | _Bảng chụp nhanh định kỳ: Lưu trạng thái theo chu kỳ (vd: chốt số dư mỗi ngày)._                     |
| **Accumulating Snapshot** | Records the entire lifecycle of a process with multiple milestones (e.g., Order Placed -> Shipped -> Delivered). Has multiple date foreign keys. | Tracking processes with clear start/end milestones. | _Bảng chụp nhanh tích lũy: Lưu toàn bộ vòng đời (vd: Ngày đặt -> Ngày giao). Được update nhiều lần._ |
| **Factless Fact**         | A fact table with no measurable numbers (e.g., tracking student attendance). It records that an _event_ happened.                                | Tracking events/coverage.                           | _Bảng Fact không có số đo lường: Chỉ để ghi nhận một sự kiện có xảy ra (vd: điểm danh học sinh)._    |

#### ✅ Topic 3.5: Step-by-Step Data Modeling Case Study (Fact + Dim Design) [CRITICAL FOR TONIGHT]

_Jake Nguyen's Tip: You will be asked to design Dim + Fact tables for a specific business process (e.g., HR/Payroll, Retail Sales, or Flight Booking). Use this structured 4-step approach to answer._

##### 1. The 4-Step Dimensional Design Process (Kimball Methodology)
- **Step 1: Select the Business Process:** Identify the exact business event you want to analyze (e.g., "Employee Timesheets", "Sales Transactions").
- **Step 2: Declare the Grain:** Define precisely what one row in the Fact table represents (e.g., "One row = One timesheet entry per employee per day"). Always choose the lowest, most atomic grain.
- **Step 3: Identify the Dimensions:** Determine the descriptive attributes (Who, What, Where, When, Why) that contextually describe the event. (e.g., `DimEmployee`, `DimClient`, `DimDate`, `DimDepartment`).
- **Step 4: Identify the Facts:** Determine the numeric, measurable metrics to be calculated/aggregated (e.g., `HoursWorked`, `RegularHours`, `OvertimeHours`, `GrossPay`).

##### 2. Real-World Example: HR & Payroll System (Ready Workforce case study)
If asked to model a system like your current project:

*   **Grain:** One row per employee daily timesheet punch.
*   **Fact Table (`FactTimesheet`):**
    *   `TimesheetKey` (PK - Surrogate Key)
    *   `EmployeeKey` (FK)
    *   `ClientKey` (FK)
    *   `DateKey` (FK)
    *   `PayTypeKey` (FK)
    *   `HoursWorked` (Numeric)
    *   `OvertimeHours` (Numeric)
    *   `RegularHours` (Numeric)
    *   `GrossPay` (Numeric)
*   **Dimension Tables:**
    *   `DimEmployee`: `EmployeeKey` (PK), `EmployeeID` (NK), `FullName`, `JobTitle`, `HireDate`, `DepartmentName`.
    *   `DimClient`: `ClientKey` (PK), `ClientID` (NK), `ClientName`, `Industry`, `Location`.
    *   `DimDate`: `DateKey` (PK), `FullDate`, `Year`, `Quarter`, `Month`, `DayOfWeek`, `IsHoliday`.
    *   `DimPayType`: `PayTypeKey` (PK), `PayTypeCode`, `PayTypeName`, `RateMultiplier`.

##### 3. Key Architectural Guidelines to Mention (For Senior Points):
- **Always use Surrogate Keys (SK):** Use an integer (identity column or sequence) as the Primary Key in Dimension tables, and join the Fact table to the SK, NOT the Natural Key (NK) from the source system. *Rationale:* Protects the DW when source IDs change (e.g., an employee is re-assigned a new ID in the source CRM) and optimizes join speed in SQL Server.
- **Star Schema over Snowflake:** Advocate for the Star Schema. *Rationale:* Reduces the number of JOINs, which speeds up SQL reads and runs significantly faster in Power BI’s VertiPaq in-memory engine.
- **Conformed Dimensions:** Point out that `DimDate` is a conformed dimension, which allows us to analyze both Sales and Timesheets on the same timeline (enabling a Galaxy/Fact Constellation schema later).

##### 4. Additional Common Interview Case Studies

###### Case Study A: E-Commerce / Retail Sales
*   **Grain:** One row per individual item purchased on a receipt (Order Line Item).
*   **Fact Table (`FactSales`):**
    *   `SalesKey` (PK - Surrogate Key)
    *   `OrderNumber` (Degenerate Dimension - kept in Fact to group items, no separate Dim table needed)
    *   `CustomerKey` (FK)
    *   `ProductKey` (FK)
    *   `StoreKey` (FK)
    *   `DateKey` (FK)
    *   `Quantity` (Fact - Additive)
    *   `UnitPrice` (Fact - Semi-additive)
    *   `DiscountAmount` (Fact - Additive)
    *   `NetSalesAmount` (Fact - Additive: `(Quantity * UnitPrice) - DiscountAmount`)
*   **Dimension Tables:**
    *   `DimCustomer`: `CustomerKey` (PK), `CustomerID` (NK), `CustomerName`, `Gender`, `City`, `PostalCode`.
    *   `DimProduct`: `ProductKey` (PK), `ProductID` (NK), `ProductName`, `Category`, `Subcategory`, `Color`.
    *   `DimStore`: `StoreKey` (PK), `StoreID` (NK), `StoreName`, `StoreCity`, `StoreCountry`.
    *   `DimDate`: `DateKey` (PK), `FullDate`, `Year`, `Month`, `DayOfWeek`, `IsHoliday`.

###### Case Study B: Ride-Hailing Service (Uber/Grab Style)
*   **Grain:** One row per completed trip.
*   **Fact Table (`FactRides`):**
    *   `RideKey` (PK - Surrogate Key)
    *   `RideID` (Degenerate Dimension - Unique ride number)
    *   `PassengerKey` (FK)
    *   `DriverKey` (FK)
    *   `PickupLocationKey` (FK - points to `DimLocation`)
    *   `DropoffLocationKey` (FK - points to `DimLocation` - Role-Playing Dimension example)
    *   `DateKey` (FK - points to `DimDate`)
    *   `TripDurationSeconds` (Fact)
    *   `TripDistanceMiles` (Fact)
    *   `FareAmount` (Fact)
    *   `TipAmount` (Fact)
    *   `RatingByPassenger` (Fact - Non-additive/Averageable)
*   **Dimension Tables:**
    *   `DimPassenger`: `PassengerKey` (PK), `PassengerID` (NK), `PassengerName`, `SignupDate`.
    *   `DimDriver`: `DriverKey` (PK), `DriverID` (NK), `DriverName`, `LicensePlate`, `Rating`.
    *   `DimLocation`: `LocationKey` (PK), `StreetAddress`, `Neighborhood`, `City`, `Latitude`, `Longitude`.

###### Case Study C: Subscription / SaaS (Monthly MRR Tracking)
*   **Grain:** One row per active subscription per month (Periodic Snapshot Fact Table).
*   **Fact Table (`FactMonthlySubscriptionSnapshot`):**
    *   `SnapshotKey` (PK - Surrogate Key)
    *   `DateKey` (FK - points to end of the month in `DimDate`)
    *   `CustomerKey` (FK)
    *   `SubscriptionKey` (FK)
    *   `PlanKey` (FK)
    *   `MonthlyRecurringRevenue` (MRR - Fact)
    *   `IsActive` (Fact - Boolean 1/0 indicator)
*   **Dimension Tables:**
    *   `DimSubscription`: `SubscriptionKey` (PK), `SubscriptionID` (NK), `StartDate`, `EndDate`, `AutoRenewFlag`.
    *   `DimPlan`: `PlanKey` (PK), `PlanID` (NK), `PlanName`, `BillingCycle` (Monthly/Annual), `Price`.

> _Giải thích tiếng Việt (Kịch bản phỏng vấn):_
> _Khi được yêu cầu thiết kế hệ thống dữ liệu, hãy trình bày đủ 4 bước Kimball: (1) Xác định nghiệp vụ, (2) Xác định Grain (độ chi tiết thấp nhất - vd: 1 dòng = 1 lượt điểm danh mỗi ngày), (3) Xác định Dim (Employee, Date, Client), và (4) Xác định Fact (Số giờ làm, Lương)._
> _Nhớ nhắc đến 3 nguyên tắc vàng để ghi điểm:_
> 1. _**Dùng Surrogate Key** (Khóa thay thế tự sinh dạng số) cho bảng Dim thay vì dùng mã gốc hệ thống để tăng hiệu năng JOIN và tránh lỗi khi hệ thống nguồn thay đổi._
> 2. _**Ưu tiên Star Schema** hơn Snowflake để giảm số lượng JOIN giúp Power BI và SSAS chạy nhanh hơn._
> 3. _**Dùng Conformed Dimension** (như DimDate dùng chung cho nhiều Fact) giúp liên kết các báo cáo doanh nghiệp chéo nhau dễ dàng._
> 4. _**Hiểu rõ các loại Dimension đặc biệt:** Role-Playing Dimension (như DimLocation đóng vai trò cả Pickup và Dropoff trong FactRides), và Degenerate Dimension (như OrderNumber lưu thẳng ở Fact mà không cần bảng Dim riêng)._

#### ✅ Topic 4: Handling Many-to-Many Relationships

**The Problem:**
In relational databases, you cannot link two tables directly if multiple records in Table A relate to multiple records in Table B.
_Example:_ One `Student` can enroll in many `Courses`, and one `Course` can have many `Students`. If you try to join them directly, you get massive data duplication (a Cartesian product).

**The Standard Solution: The Bridge Table (Junction Table)**
To resolve a Many-to-Many relationship cleanly in SQL, you must create a third table in the middle to "bridge" them. This breaks the Many-to-Many down into two separate **One-to-Many** relationships.

**Alternative Solutions (And why they are usually worse):**
If the interviewer asks _"Is there any other way?"_, you can mention these workarounds to show deep experience:

1. **Native BI Engine Features (Power BI / SSAS):** You can set up a direct Many-to-Many relationship in the BI tool using **Bi-directional Cross Filtering**.
   - _Why it's risky:_ It causes "ambiguity" in the data model (the engine gets confused about which path to take to filter data) and severely impacts performance. Only use it as a last resort on very small datasets.
2. **Flattening into Delimited Strings (e.g., CSV) or JSON:** Instead of a bridge table, Table A has a column storing a list of IDs (e.g., `CourseIDs = "101, 102, 105"` or `[101, 102, 105]`).
   - _Why it's risky:_ Violates First Normal Form (1NF). In SQL Server, parsing JSON or splitting strings to do a JOIN is incredibly slow compared to a standard Bridge Table join.
3. **Denormalized Wide Columns:** If you know the absolute maximum limit (e.g., a student can take max 3 courses), you create `Course1_ID`, `Course2_ID`, `Course3_ID` directly in the Student table.
   - _Why it's risky:_ It's inflexible. If a student takes 4 courses, your schema breaks and requires a database redesign.

**Example Structure:**

1. **`DimStudent`** (StudentID, Name)
2. **`DimCourse`** (CourseID, CourseName)
3. **`FactEnrollment` (The Bridge Table):** Contains `StudentID` and `CourseID`.

**How it looks in SQL:**

```sql
SELECT
    s.Name AS StudentName,
    c.CourseName
FROM DimStudent s
JOIN FactEnrollment e ON s.StudentID = e.StudentID  -- Bridge table join 1
JOIN DimCourse c ON e.CourseID = c.CourseID;        -- Bridge table join 2
```

> **Interview Tip (BI Context):** In Power BI or SSAS Tabular, Many-to-Many relationships can be created natively in the engine, but it is **highly discouraged** due to severe performance issues and ambiguous filtering. The best practice is always to resolve it at the SQL Database layer using a Bridge/Fact table before importing it into the BI tool.

---

#### ✅ Topic 5: SCD Type 1 & Type 2 _(interview_prep.md line 26)_

| SCD Type                 | Strategy                                                                                                                    | History Kept?          | When to Use                                                                      |
| :----------------------- | :-------------------------------------------------------------------------------------------------------------------------- | :--------------------- | :------------------------------------------------------------------------------- |
| **Type 1 — Overwrite**   | Simply update the existing row. Old value is gone.                                                                          | ❌ No                  | Correcting data errors (typos, wrong codes). Not for business attribute changes. |
| **Type 2 — Add New Row** | Keep old row (mark as inactive), insert a new row with updated value. Use `IsActive` flag + `EffectiveDate` / `ExpiryDate`. | ✅ Full history        | Tracking business changes over time (customer moved city, changed segment).      |
| **Type 3 — Add Column**  | Add a `Previous_Value` column alongside the `Current_Value` column.                                                         | ⚠️ Only 1 version back | When you only need "current vs previous" — very limited.                         |

**Type 2 Example — How a row looks:**

| CustomerKey | CustomerID | City        | IsActive | EffectiveDate | ExpiryDate |
| ----------- | ---------- | ----------- | -------- | ------------- | ---------- |
| 1           | C001       | New York    | 0        | 2022-01-01    | 2023-06-30 |
| 2           | C001       | Los Angeles | 1        | 2023-07-01    | 9999-12-31 |

#### Topic 6: Advanced SCD _(from Topic 9)_ & Late-Arriving Dimensions

- **SCD Type 6:** A hybrid of 1, 2, and 3. Keeps historical rows (Type 2), but every row also has a column showing the current state (Type 1), allowing you to easily filter by "History as it was" or "History mapped to today's state."
  > _Kết hợp cả Type 1, 2, 3. Giữ lại các dòng lịch sử nhưng cột trạng thái hiện tại luôn bị ghi đè. Giúp dễ dàng xem lịch sử theo trạng thái hiện tại._
- **Late-Arriving Dimensions:** When fact data arrives before dimension data (e.g., a sale is recorded but the new customer hasn't been added to DimCustomer yet).
  - _Fix:_ Insert an "Unknown" or "Placeholder" dimension record (e.g., ID = -1) so fact data can load without failing foreign key constraints. Update the dimension row when the actual data arrives.
    > _Dữ liệu Fact đến sớm hơn Dimension. Cách xử lý: Chèn 1 dòng tạm (Unknown/Placeholder) vào bảng Dimension để không bị lỗi khóa ngoại (Foreign Key), sau đó update lại khi có dữ liệu thật._

## Section 4: SSIS (Integration Services) & ETL Workflows

#### ✅ Topic 7: ETL/SSIS Task Types _(interview_prep.md line 24)_

While you should know the basic tasks, a senior BI Developer needs to explain _how they connect together_ to build a resilient data pipeline.

| Task Type                   | What It Does                                                                                  | Example                                       |
| :-------------------------- | :-------------------------------------------------------------------------------------------- | :-------------------------------------------- |
| **Data Flow Task**          | The core ETL container. Moves and transforms data from Source → Transformation → Destination. | Extract from SQL → Lookup → Load to DW        |
| **Execute SQL Task**        | Runs a T-SQL statement (stored proc, DDL, DML) against a database.                            | Truncate staging table, call a SP             |
| **File System Task**        | Copies, moves, renames, or deletes files on disk.                                             | Archive processed CSV files                   |
| **Send Mail Task**          | Sends an email notification (success/failure alerts).                                         | Email team when package fails                 |
| **Script Task**             | Runs custom C# or VB.NET logic for complex business rules not supported natively.             | Custom FTP download, REST API call            |
| **For Each Loop Container** | Iterates over a collection (files in a folder, rows in a dataset).                            | Process one file at a time from a drop folder |
| **Sequence Container**      | Groups related tasks together for organization and shared error handling.                     | Group all staging load tasks                  |

**Deep Dive & Real-World Example (How to explain in an interview):**

- **The Scenario:** Imagine you receive daily sales data as CSV files dropped into an FTP folder, and you need to load them into a SQL Data Warehouse.
- **The Execution Flow (Control Flow Layer):**
  1. **Execute SQL Task:** First, run `TRUNCATE TABLE StagingSales` to clear yesterday's temporary data.
     > _Chạy lệnh TRUNCATE bằng Execute SQL Task để dọn dẹp bảng tạm (staging) trước khi load dữ liệu mới._
  2. **For Each Loop Container:** Configure this to look at the FTP folder and loop through every `*.csv` file.
     > _Dùng For Each Loop để quét qua toàn bộ các file CSV có trong thư mục._
  3. **Data Flow Task (Inside the loop):** For each file, the Data Flow executes:
     - **Flat File Source:** Reads the current CSV.
     - **Derived Column / Data Conversion (Transformations):** Cleans up bad dates or trims spaces.
     - **Lookup (Transformation):** Looks up the `CustomerID` from the CSV against the `DimCustomer` table to get the `CustomerKey`. If a lookup fails, route it to an Error Output.
     - **OLE DB Destination:** Inserts the cleaned rows into the `StagingSales` table.
       > _Trong Data Flow: Đọc file -> Dùng Derived Column để chuẩn hóa -> Dùng Lookup để dò tìm khóa ngoại (như hàm VLOOKUP) -> Đổ vào bảng Staging. Các dòng lỗi (không dò ra) sẽ đẩy ra luồng Error._
  4. **File System Task (Inside the loop):** Once the Data Flow finishes successfully for that file, move the processed CSV to an "Archive" folder so it isn't processed again tomorrow.
     > _Dùng File System Task để di chuyển (Move) file CSV đã xử lý xong sang thư mục Archive (lưu trữ)._
  5. **Execute SQL Task:** Finally, call a Stored Procedure (e.g., `EXEC sp_MergeSales`) to run a `MERGE` statement, UPSERTING data from `StagingSales` into `FactSales`.
     > _Cuối cùng, gọi Stored Procedure để chạy lệnh MERGE, đưa dữ liệu từ bảng Staging vào bảng FactSales chính thức._

#### Topic 8: SSIS Visuals & Architecture Examples (from JoeyBlue SQL Trainings)

_The following breakdown helps explain the foundational concepts of SSIS workflows, ETL processes, and package structures._

**1. ETL Process Overview**
The ETL process in SSIS consists of three main stages:

- **Extract:** Retrieve data from various sources like SQL Server, Excel, and flat files.
- **Transform:** Apply transformations such as data conversions and lookups.
- **Load:** Store the transformed data into a data warehouse.

**2. SSIS Package Workflow**
An SSIS package is divided into Control Flow and Data Flow components:

- **SSIS Package:** The overall container that includes all components.
- **Control Flow:** Manages the sequence of tasks (e.g., Execute SQL Task, Data Flow Task, Script Task, File System Task).
- **Data Flow:** A subsection of the Control Flow that manages the flow of data from sources to destinations, using transformations such as data conversions and lookups.

**3. Control Flow vs. Data Flow**
Control Flow and Data Flow are distinct components in SSIS.

- **Control Flow:** Examples include looping through files, executing SQL commands, or running custom scripts.
- **Data Flow:** Examples include transforming data, performing lookups, and aggregations.

**4. Connections in SSIS**
SSIS uses various connection types to integrate with different data sources:

- **OLE DB Connection:** For SQL Server databases.
- **Excel Connection:** To read from or write to Excel files.
- **Flat File Connection:** To handle CSV or text files.
  _Connections are used within the Data Flow to connect Sources and Destinations._

**5. Error Handling in SSIS**
Error handling is critical in SSIS to maintain data quality.

- **Error Output:** Errors (e.g., in a Data Flow Task) can be redirected to an output path for further review.
- **Flat File Destination:** Failed rows are saved for analysis without breaking the entire package.

**6. Deployment and Scheduling**

- **Deployment:** Deploy SSIS packages using Visual Studio to the SSIS Catalog.
- **Scheduling:** Use SQL Server Agent to schedule packages, ensuring they run automatically at set intervals.

**7. Accounting/Finance ETL Example Scenario**
To demonstrate these concepts, consider an accounting example:

- **Extract:** Retrieve financial transactions from SQL Server, exchange rates from an Excel file, and supplier data from a CSV file.
- **Transform:** Use Lookups to enrich transaction data with customer and supplier details. Convert transaction amounts to a common currency using the exchange rates from the Excel file.
- **Load:** Store the transformed data into a data warehouse for financial analysis.

_Implementation Details:_

- **Control Flow:**
  1. Start with an Execute SQL Task to create staging tables.
  2. Use a Data Flow Task to extract and transform the data.
  3. Include a Script Task to apply any custom transformations.
  4. Add a File System Task to archive processed files.
- **Data Flow:**
  1. Extract data from SQL Server, Excel, and CSV sources.
  2. Perform transformations such as lookups to combine customer and transaction data.
  3. Convert currency values using data from the Excel file.
  4. Load the transformed data into a data warehouse for further analysis.

#### Topic 9: SSIS Toolbox Deep Dive & Advanced ETL Workflows (from JoeyBlue SQL Trainings)

_The SSIS Toolbox contains dozens of components. Based on the 2-hour end-to-end tutorial, here is a categorized deep dive into the most critical tools and how they are used in real-world scenarios._

##### 1. Control Flow Tasks (The Orchestrators)

Control Flow manages the _execution order_ of operations, not the data itself.

- **Data Flow Task:** The bridge to the Data Flow engine. It executes the actual ETL extraction and transformation.
- **Execute SQL Task:** Used to prepare the environment (e.g., `TRUNCATE TABLE`, creating temporary staging tables) or finalize the load (e.g., running `MERGE` statements).
- **Script Task (C# / VB.NET):** Used for operations SSIS cannot do natively. For example, making an **API Call** to fetch live Exchange Rates before passing the JSON data down the pipeline.
- **File System Task:** Used for file management (e.g., archiving or deleting a CSV after it has been loaded).

##### 2. Data Flow Sources & Destinations

Inside the Data Flow Task, you move data from Source to Destination.

- **OLE DB Source / Destination:** Used for connecting to SQL Server databases. _Best Practice: Use "Table or view - fast load" in the OLE DB Destination for bulk insert performance._
- **ADO NET Source / Destination:** Used for .NET data providers. Often necessary for connecting to certain cloud databases or when utilizing specific providers where OLE DB isn't supported.
- **Flat File Source / Destination:** Used to read or write CSV/TXT files (e.g., loading Supplier Data or exporting an audit report). Requires careful configuration of Delimiters and Column Data Types.
- **Excel Source:** Used to read `.xlsx` files (e.g., Exchange Rates). Often requires data type casting because Excel guesses column types.
- **XML Source:** Parses hierarchical XML documents and translates the tags into relational, tabular rows for downstream processing.

##### 3. Data Flow Transformations (The Modifiers)

These components manipulate the data as it flows through the pipeline. Understanding exactly when to use which transformation is a core interview topic.

- **Data Conversion:**
  - **What it does:** Resolves data type mismatch errors.
  - **When to use:** Crucial when importing from Flat Files (CSV) or Excel. SSIS often reads CSV data as string (`VARCHAR`), so you must use this to safely cast strings into `INT`, `DECIMAL`, or `DATETIME` before inserting into SQL Server.
  - > _Giải thích: Ép kiểu dữ liệu. CSV thường bị hiểu lầm là dạng Text, nên bắt buộc dùng tool này để đổi Text thành Số hoặc Ngày tháng trước khi nạp vào DB._

- **Derived Column:**
  - **What it does:** Creates new columns or modifies existing ones using expressions (similar to creating calculated columns in Excel or SQL).
  - **When to use:** String manipulation (e.g., extracting First Name from Full Name), math calculations (e.g., `Amount * ExchangeRate`), or replacing NULL values.
  - > _Giải thích: Tính toán cột mới. Rất hay dùng để làm phép nhân (tính doanh thu, tỷ giá) hoặc cắt ghép chuỗi._

- **Lookup:**
  - **What it does:** Compares incoming rows to a reference table, acting exactly like a SQL `LEFT JOIN` or Excel `VLOOKUP`.
  - **Handling No Matches (Crucial!):** You can configure the Lookup to redirect rows with "No Match" to a separate error path instead of failing the component. This is critical for catching missing Supplier IDs or unknown Currencies without crashing the ETL process.
  - > _Giải thích: Tương đương VLOOKUP. Quan trọng nhất là kỹ thuật hứng các dòng "No Match" để không làm sập (crash) toàn bộ quá trình ETL. Khoe kỹ năng này khi phỏng vấn sẽ rất ăn điểm._

- **Union All:**
  - **What it does:** Combines multiple data streams into a single output vertically (like a SQL `UNION ALL`).
  - **When to use:** Useful if you are reading from multiple regional CSV files (e.g., `Sales_North.csv` + `Sales_South.csv`) and want to process them together.
  - > _Giải thích: Gộp dữ liệu từ nhiều nguồn vào làm một luồng duy nhất._

- **Aggregate / Sort:**
  - **What it does:** Sorts incoming rows and uses Aggregate to `GROUP BY` and summarize data.
  - **When to use:** Used to handle duplicate data or summarize transactions before loading. _Warning: These are "blocking" transformations, meaning they must hold all data in RAM before proceeding, making them very slow for large datasets._
  - > _Giải thích: Dùng để Gom nhóm (GROUP BY) và Loại bỏ trùng lặp. Lưu ý: Đây là thao tác ngốn RAM (Blocking), nên xử lý bằng SQL sẽ nhanh hơn là dùng Tool này trong SSIS._

- **Conditional Split:**
  - **What it does:** Routes data rows to different paths based on specific conditions, acting like an `IF/ELSE` or `SWITCH` statement.
  - **When to use:** Example: If `Amount < 0` send to `RefundPath`, else send to `SalesPath`.
  - > _Giải thích: Rẽ nhánh luồng dữ liệu (If / Else)._

- **Multicast:**
  - **What it does:** Duplicates a single data stream into multiple exact copies.
  - **When to use:** When you need to send the exact same data to two different places at the same time (e.g., Sending one copy to the Database and another copy to a Flat File for auditing).
  - > _Giải thích: Phân thân luồng dữ liệu thành nhiều bản sao y hệt nhau để ghi vào nhiều nơi cùng lúc._

- **Script Component:**
  - **What it does:** Runs _inside_ the Data Flow and processes data row-by-row using C# or VB.NET.
  - **When to use:** When native SSIS tools cannot handle the complexity (e.g., custom regex parsing, advanced JSON parsing per row).
  - > _Giải thích: Viết code C# để xử lý từng dòng dữ liệu khi các công cụ có sẵn của SSIS không làm được._

- **Fuzzy Lookup / Fuzzy Grouping:**
  - **What it does:** Uses algorithms to find approximate matches instead of exact matches (requires an active SQL Server connection to build temporary index tables).
  - **When to use:** Data cleansing and deduplication (e.g., matching "Jon Doe" with "John Doe" or identifying duplicate customer addresses).
  - > _Giải thích: Tìm kiếm và gom nhóm "gần đúng". Rất hay dùng để làm sạch dữ liệu (Data Cleansing) khi thông tin người dùng bị gõ sai chính tả._

- **Pivot / Unpivot:**
  - **What it does:** Pivot turns rows into columns; Unpivot turns columns into rows.
  - **When to use:** Normalizing wide flat files (Unpivot) or preparing summarized cross-tab data for reporting (Pivot).
  - > _Giải thích: Chuyển đổi dữ liệu từ Hàng sang Cột (Pivot) và ngược lại (Unpivot). Thường dùng để chuẩn hóa dữ liệu bị trải ngang từ các file Excel._

- **Row / Percentage Sampling:**
  - **What it does:** Extracts a random subset of rows (either an exact number or a percentage) from the data stream.
  - **When to use:** Rapidly testing a heavy ETL pipeline without waiting for millions of rows to load, or generating sample data for Machine Learning models.
  - > _Giải thích: Trích xuất ngẫu nhiên một lượng nhỏ dữ liệu để test thử luồng ETL cho nhanh, thay vì phải chờ nạp toàn bộ hàng triệu dòng._

##### 4. Data Flow Mechanics: Paths, Error Handling & Metadata

Beyond just components, the Data Flow relies on strict mechanics to move data safely:

- **Paths (Precedence in Data Flow):** Unlike Control Flow arrows (which define task order), Data Flow Paths physically carry the data from one component's output to another's input. You can attach **Data Viewers** directly onto Paths to inspect the data in memory.
- **Error Outputs (Row-Level Redirection):** Most transformations and destinations allow you to configure an Error Output. Instead of failing the entire package when a row errors (e.g., truncation, data type mismatch, division by zero), you can redirect that specific row to a different path. These error rows automatically include two critical system columns: `ErrorCode` (why it failed) and `ErrorColumn` (which column caused it).
- **External Metadata:** When building a Data Flow, SSIS takes an offline snapshot of the source/destination schema called "External Metadata". It uses this to validate data types and columns before you even run the package.
- **Connection Managers:** Required by Sources, Destinations, and some Transformations (like Lookup) to interact with external data.

> _Giải thích: Trong Data Flow, mũi tên (Paths) dùng để vận chuyển dữ liệu. Quan trọng nhất là tính năng Error Output: nếu 1 dòng dữ liệu bị lỗi (ví dụ sai kiểu dữ liệu), thay vì làm sập cả luồng, ta có thể rẽ nhánh dòng lỗi đó ra chỗ khác để xử lý, lúc này SSIS sẽ tự động gắn thêm 2 cột báo lỗi là `ErrorCode` và `ErrorColumn`. Ngoài ra, SSIS luôn lưu lại bản sao cấu trúc bảng (External Metadata) để tự động kiểm tra lỗi (validate) ngay cả khi bạn đang code offline._

##### 5. Debugging & Deployment Workflows

- **Data Viewers:** You can attach a Data Viewer to the paths between transformations. This pauses execution and opens a grid showing the exact data rows at that exact point in time—critical for debugging Data Type or Lookup errors.
- **Project Parameters & Connection Strings:** Instead of hardcoding database server names, use Project Parameters. This allows you to easily switch Connection Strings from the "Development" server to the "Production" server.
- **SSISDB Catalog & Deployment:** The modern way to deploy packages. You build the project in Visual Studio and deploy it to the SSISDB Catalog on SQL Server. From there, you map Environment Parameters.
- **SQL Server Agent:** Once deployed, you create a Job in SQL Server Agent to schedule the package. You can configure the job steps and review the Job History logs if the ETL fails overnight.

> **💡 Bonus Interview Tip: How to explain the SSIS Toolbox verbally**
>
> **Q: Can you explain the SSIS Toolbox and which transformations you use most often?**
> **Answer:** "The SSIS Toolbox changes depending on whether you are working in the Control Flow or Data Flow tab. In the Control Flow, I use tasks like the `Execute SQL Task` to prepare tables, and the `Data Flow Task` to trigger the ETL. In the Data Flow, I use components to actually move data. My most used transformation is the **Lookup** transformation. I specifically utilize its error output configuration—instead of letting the entire package fail when a lookup has no match (like an unknown Customer ID), I redirect the 'No Match' output to a separate staging error table. This allows the ETL pipeline to finish successfully while giving the business a report of missing dimensions to investigate."
>
> _Giải thích tiếng Việt (Kịch bản trả lời): Trong Control Flow mình dùng Execute SQL Task để chuẩn bị data, còn Data Flow Task để gọi luồng ETL. Trong Data Flow, công cụ mình hay dùng nhất là Lookup (giống VLOOKUP). Khác biệt ở chỗ, thay vì để cả hệ thống sập khi không tìm thấy ID (No match), mình điều hướng những dòng lỗi đó ra một bảng riêng. Quá trình ETL vẫn chạy bình thường, và hôm sau team Business có thể xử lý các dữ liệu bị thiếu đó._
>
> **🎙️ Mock Interview Script: Explaining Data Flow Components**
> **"When I work inside a Data Flow Task, I break the components down into three main categories: Sources, Transformations, and Destinations.**
>
> **1. For Sources and Destinations:** I primarily use the **OLE DB** component when connecting to SQL Server, enabling the **'Fast Load'** option to ensure bulk insert performance. For external flat files, I use the **Flat File Source**.
>
> **2. For Transformations:** This is where the real work happens. I frequently rely on four main tools:
>
> - **First is the Lookup transformation.** I use it to perform reference checks, very similar to a `LEFT JOIN` in SQL.
> - **Second is the Derived Column.** I use this to calculate new values on the fly, such as currency conversions.
> - **Third is Data Conversion.** Because flat files bring in everything as strings, I use this to safely cast those strings into precise SQL Server data types like `INT` or `DECIMAL`.
> - **And finally, Conditional Split.** I use it to route data rows down different paths based on specific business rules, acting just like an `IF / ELSE` statement.
>
> **Overall, combining these components allows me to build a robust pipeline that cleans and shapes the data before it hits the data warehouse."**

#### ✅ Topic 10: End-to-End ETL Data Validation _(interview_prep.md line 25)_

A complete validation strategy runs checks at **3 stages** of the pipeline:

1. **Pre-Load (Source Validation):**
   - Check row counts match between source and staging extract.
   - Validate no NULL values in NOT NULL columns (primary keys, mandatory fields).
   - Check data types and value ranges (e.g., `SaleAmount > 0`, `Date IS NOT NULL`).

2. **During Load (Transformation Validation):**
   - Lookup failures logged — referential integrity checks (e.g., does `CustomerID` from fact exist in `DimCustomer`?).
   - Duplicate detection before loading (using `ROW_NUMBER()` in staging).

3. **Post-Load (Destination Validation):**
   - Row count reconciliation: source row count = destination row count.
   - Checksum comparison: `SUM(Amount)` in source = `SUM(Amount)` in target.
   - Load any failed/rejected rows into an `ErrorLog` table for investigation.

#### Topic 11: SSIS Performance Tuning & Incremental Loads

- **SSIS Buffer Sizing:** Tuning `DefaultBufferMaxRows` and `DefaultBufferSize` to match your server's architecture stops SSIS from swapping data to disk, massively speeding up data flows.
  > _Tối ưu Buffer: Chỉnh RAM cho luồng data flow để SSIS không bị tràn RAM xuống ổ cứng, giúp chạy cực nhanh._
- **Synchronous vs Asynchronous Transformations:**
  - _Synchronous:_ Data flows straight through (e.g., Data Conversion, Derived Column). Very fast.
  - _Asynchronous:_ The transformation must hold and block the data pipeline to process all records before releasing them (e.g., Sort, Aggregate). Avoid these in SSIS; push Sorts/Aggregates down to the SQL Server Engine.
    > _Đồng bộ vs Bất đồng bộ: Đồng bộ là dữ liệu chảy tuột đi (nhanh). Bất đồng bộ (như Sort, Group By) sẽ chặn luồng dữ liệu lại để tính toán (rất chậm). Lời khuyên: Đừng dùng Sort trong SSIS, hãy Sort bằng SQL trước._
- **CDC (Change Data Capture) vs Watermarks:**
  - _Watermark:_ Using an `UpdatedDate` column to pull new records. Simple, but misses hard deletes.
  - _CDC:_ SQL Server natively reads the transaction log to track every `INSERT`, `UPDATE`, and `DELETE`. Best for strict auditing and tracking deletes.
    > _Lấy dữ liệu tăng thêm (Incremental): Watermark dùng cột Ngày Cập Nhật (dễ làm nhưng không biết dòng nào bị xóa). CDC đọc thẳng từ log của SQL để bắt mọi hành động Thêm/Sửa/Xóa._

#### Topic 12: SSIS Interview Questions (Deep Dive)

**Q: Can you explain the difference between Non-Blocking, Semi-Blocking, and Blocking Transformations in SSIS?**

- **Non-Blocking:** Processes data row-by-row as it passes through in memory without holding it back. Extremely fast. (e.g., Derived Column, Data Conversion, Lookup).
- **Semi-Blocking:** Needs to hold a portion of the data in memory before it can output anything. (e.g., Merge, Merge Join).
- **Blocking:** Must read and hold _all_ incoming data in RAM before it can output the very first row. Very slow and memory-intensive for large datasets. (e.g., Aggregate, Sort).
  > _Giải thích: Các loại biến đổi: Non-Blocking (chạy từng dòng, cực nhanh, vd: Derived Column), Semi-Blocking (giữ một phần data rồi mới nhả ra, vd: Merge), Blocking (phải nạp toàn bộ data vào RAM rồi mới xử lý, cực chậm và ngốn RAM, vd: Sort, Aggregate). Đi làm thực tế luôn cố gắng tránh dùng công cụ Blocking trong SSIS._

**Q: What is a Checkpoint in SSIS and how do you configure it?**
Checkpoints allow an SSIS package to restart from the exact point of failure instead of running from the very beginning. To configure it, you set `SaveCheckpoints = True` at the package level, specify a `CheckpointFileName` (an XML file to store the state), and set `CheckpointUsage = IfExists`. It only works at the Control Flow level (you cannot restart halfway through a Data Flow Task).

> _Giải thích: Checkpoint giúp package chạy lại đúng từ cái Task bị lỗi thay vì chạy lại từ đầu. Cấu hình bằng cách lưu trạng thái vào 1 file XML. Lưu ý: Chỉ hoạt động ở Control Flow, không thể lưu trạng thái dở dang bên trong một Data Flow Task._

**Q: How do you resolve a "32-bit vs 64-bit" execution error when running SSIS via SQL Server Agent?**
This typically happens when importing/exporting Excel files. Visual Studio runs in 32-bit, so the package works perfectly during development. But SQL Server Agent runs in 64-bit by default and may lack the 64-bit Excel drivers. The fix is to open the SQL Server Agent Job Step, go to the "Execution options" tab, and check the box **"Use 32-bit runtime"**.

> _Giải thích: Lỗi kinh điển khi thao tác với file Excel. Trên máy Dev chạy ngon vì Visual Studio là 32-bit, lên Server chạy lỗi vì SQL Agent là 64-bit. Cách sửa: Mở cấu hình Job trong SQL Agent và tick chọn ô "Use 32-bit runtime"._

**Q: How do you design an Incremental Load in SSIS without using CDC?**
I would use the **Lookup Transformation** against the target Data Warehouse table.

1. The source data flows into the Lookup.
2. The **"No Match"** output represents brand-new records. I route these directly to an OLE DB Destination for **INSERT**.
3. The **"Match"** output represents existing records. I use a **Conditional Split** to compare the incoming source columns against the lookup target columns (often using a Checksum or Hash). If the values are different, I route them to an OLE DB Command (or an Update Staging table) for **UPDATE**.
   > _Giải thích: Thiết kế lấy dữ liệu Incremental bằng Lookup: Dòng nào 'No Match' thì Insert mới. Dòng nào 'Match' thì dùng Conditional Split để so sánh xem dữ liệu gốc có bị thay đổi không, nếu có đổi thì mới Update._

**Q: What is SSIS and what features does it have that are not in standard SQL Server?**
SQL Server Integration Services (SSIS) is an enterprise-level data integration and ETL (Extract, Transform, Load) tool. While standard SQL Server is primarily designed for storing and querying data, SSIS provides features that cannot be achieved with standard SQL commands alone. These include connecting to disparate external sources (e.g., FTP, Web Services, Excel), performing complex in-memory data transformations, and orchestrating advanced automated workflows.

**Q: What is database migration, and what steps are involved using SSIS?**
Migration depends on the source and target. If you are just upgrading versions of SQL Server, a standard Backup and Restore is usually sufficient. However, if you are moving between completely different systems (e.g., from MySQL to SQL Server), the migration involves:

1. Recreating the database structure (schema) on the new target.
2. Manually resolving any schema or data type incompatibilities.
3. Building SSIS packages to extract, transform, and load the actual data from the old system to the new one.

> _Giải thích: Tóm tắt 2 câu trên: SSIS là công cụ ETL chuyên dụng làm được những thứ SQL không làm được (như tải file FTP, gọi Web Service). Khi "migrate" (chuyển đổi) database khác hệ quản trị (vd MySQL sang SQL Server), ta phải tạo lại cấu trúc bảng, sửa lỗi tương thích, rồi dùng SSIS để bơm dữ liệu qua._

**Q: What is the core structure (architecture) of an SSIS Package?**
An SSIS package is the fundamental unit of deployment and execution. Its internal structure consists of 5 main elements:

1. **Control Flow:** The orchestrator that defines the sequence of tasks (the workflow) using Precedence Constraints.
2. **Data Flow:** A specialized task within the Control Flow that handles the actual extraction, transformation, and loading (ETL) of data in memory.
3. **Connection Managers:** The bridge components that store credentials and connection strings to connect to external data sources and destinations.
4. **Event Handlers:** Separate workflows that trigger automatically in response to specific events (like `OnError`, `OnPreExecute`).
5. **Variables & Parameters:** Used to store and pass dynamic values (like file paths or environment names) across the package during runtime.

> _Giải thích: Một gói SSIS (Package) có cấu trúc gồm 5 phần chính: **Control Flow** (Điều phối luồng công việc), **Data Flow** (Nơi bơm và xử lý dữ liệu), **Connection Managers** (Quản lý kết nối tới DB/File), **Event Handlers** (Xử lý sự kiện/lỗi), và **Variables & Parameters** (Lưu biến số để cấu hình động)._

**Q: What is the function of Connection Managers in SSIS and what are common types?**
Connection Managers are used to define and establish connections to external data sources. They can be created at two levels:

- **Project Level:** Accessible to _all_ packages within the project.
- **Package Level:** Limited to that specific package only.

Common types include:

- **OLE DB Connection Manager:** Used to connect to relational databases (like SQL Server or Oracle).
- **Flat File Connection Manager:** Used for reading or writing text files (like CSV).
- **File Connection Manager:** Used to read, write, or manage files and directories (often for Excel files or moving files around).
  > _Giải thích: Connection Manager dùng để kết nối tới nguồn dữ liệu. Có các loại phổ biến như OLE DB (kết nối database), Flat File (kết nối file text/csv), và File (kết nối/quản lý file Excel, thư mục). Nó có 2 cấp độ: Project Level (dùng chung) và Package Level (chỉ dùng cho 1 package)._

**Q: What is the 'Delay Validation' property?**
The `DelayValidation` property (often set to `True` on connection managers or tasks) allows the package to bypass metadata validation at the start of execution. This is extremely useful when the package relies on an object (like a table) that is created dynamically at runtime and does not exist during development or initial validation.

> _Giải thích: Thuộc tính `DelayValidation` giúp bỏ qua bước kiểm tra lỗi lúc package mới bắt đầu chạy. Nó cực kỳ hữu ích khi bạn có một bảng được tạo tự động trong lúc chạy (tức là bảng đó chưa hề tồn tại ở thời điểm đầu)._

**Q: How do you use a temporary table in an SSIS package?**
To use a temp table in a Data Flow Task, you must use a **global temporary table** (prefixing the table name with `##`, e.g., `##TempTable`) instead of a local temp table (`#`). Additionally, you must set the **`RetainSameConnection`** property of the OLE DB Connection Manager to `True` so that the temp table persists across different tasks in the same session.

> _Giải thích: Để dùng bảng tạm (temp table) trong Data Flow, bạn bắt buộc phải tạo bảng tạm toàn cục (bắt đầu bằng `##`). Đồng thời, phải thiết lập thuộc tính `RetainSameConnection = True` ở Connection Manager để giữ nguyên phiên kết nối, nếu không bảng tạm sẽ bị xóa mất trước khi Data Flow kịp chạy._

**Q: What is the difference between Control Flow and Data Flow?**

- **Control Flow:** The orchestrator. It defines the _sequence_ of operations (workflow) using Precedence Constraints. It handles tasks like running SQL scripts, sending emails, and looping (For Each), but it _does not_ move data itself.
- **Data Flow:** The data engine. It lives _inside_ a Data Flow Task (which is just one part of the Control Flow). It is responsible for the actual extraction, transformation in memory, and loading of records from source to destination.
  > _Giải thích: Control Flow là bộ điều phối luồng công việc (thứ tự chạy, gửi email, vòng lặp) và không chứa dữ liệu. Data Flow nằm bên trong Control Flow, là nơi thực sự bơm, nạp và biến đổi dữ liệu trên RAM._

**Q: What are the main types of Components in the SSIS Data Flow?**
SSIS utilizes various components to process data:

- **Sources:** Built-in components used to extract data from external sources.
  - _Examples:_ OLE DB Source (SQL Server/Oracle), Flat File Source (CSV/TXT), Excel Source, XML Source.
- **Destinations:** Built-in components used to load data into target locations.
  - _Examples:_ OLE DB Destination (SQL Server), Flat File Destination (creates CSVs), Recordset Destination (saves data into an SSIS memory variable).
- **Transformations:** Built-in components used to modify, clean, or route the data in transit.
  - _Examples:_ Lookup (for VLOOKUP-style joins), Conditional Split (for IF/ELSE routing), Derived Column (to calculate new columns), Data Conversion (to cast data types).

  _(Note: While SSIS provides many built-in components, developers also have the ability to create their own custom components using C#)._

  > _Giải thích: Data Flow có 3 loại Component chính: Source (đầu hút: OLE DB Source, Flat File), Destination (đầu xả: OLE DB Destination, Recordset) và Transformation (bộ lọc/biến đổi: Lookup, Conditional Split). Ngoài các tool có sẵn, ta cũng có thể tự code Custom Component._

**Q: What are some important Transformation Components in the Data Flow?** 
- **Data Conversion Transformation:** Used to convert data from one data type to another (e.g., converting a string to an integer).
- **Conditional Split Transformation:** Used to direct data rows to different outputs based on specified conditions, exactly like an `IF...ELSE` or `SWITCH` statement in programming. You can define multiple expressions to route data to different paths.
- **Script Component:** Used within the Data Flow Task to transform or process data rows individually (e.g., data cleansing or custom calculations) using C# or VB.NET.
  > _Giải thích: Data Conversion dùng để ép kiểu dữ liệu. Conditional Split dùng để rẽ nhánh dữ liệu dựa trên điều kiện (giống lệnh IF ELSE). Script Component dùng để viết code C#/VB.NET xử lý logic phức tạp cho từng dòng dữ liệu (row-by-row)._

**Q: What is the difference between a Script Task and a Script Component?**

- **Script Task:** Used in the **Control Flow** to perform tasks like file manipulation, API calls, or complex logic that is _not_ part of the data flow.
- **Script Component:** Used within the **Data Flow** to transform or process data rows individually as they move from source to destination.
  > _Giải thích: Cả hai đều dùng để viết code C#/VB.NET. Tuy nhiên, Script Task nằm ở Control Flow (chạy tác vụ chung như quản lý file), còn Script Component nằm trong Data Flow (chuyên dùng để xử lý, biến đổi từng dòng dữ liệu)._

**Q: What is the difference between an Execute SQL Task and an Execute T-SQL Task?**

- **Execute T-SQL Task:** Supports _only_ static queries, strictly uses Transact-SQL, and requires ADO.NET connections. It is less flexible.
- **Execute SQL Task:** Highly flexible. It supports dynamic queries (via expressions and parameters), multiple connection types (OLEDB, ADO.NET, ODBC), and other SQL dialects (for example, it can be used to run commands that create Excel sheets).
  > _Giải thích: T-SQL Task rất hạn chế, chỉ chạy lệnh tĩnh và bắt buộc dùng kết nối ADO.NET. Còn SQL Task mạnh hơn nhiều, cho phép truyền biến động (dynamic), hỗ trợ đủ loại kết nối và thậm chí có thể chạy lệnh để tạo file Excel._

**Q: What are Precedence Constraints in SSIS?**
They are the connectors (arrows) between tasks in the Control Flow that dictate the execution order and conditions. There are three main types:

- **Success (Green):** Task B runs only if Task A succeeds.
- **Failure (Red):** Task B runs only if Task A fails (useful for error handling/email alerts).
- **Completion (Blue):** Task B runs after Task A finishes, regardless of whether it succeeded or failed.
  _Advanced Use Case (Expressions):_ You can evaluate expressions on Precedence Constraints. For example, to run different tasks based on the day (weekdays vs. weekends), use an Execute SQL Task to retrieve the current day name, then use Precedence Constraints with expressions (e.g., `@DayName == "Saturday"`) to route the workflow to the correct container.
  > _Giải thích: Là các mũi tên nối giữa các Task trong Control Flow để quyết định điều kiện chạy: Thành công (Xanh lá), Thất bại (Đỏ), hoặc Hoàn thành (Xanh dương). Đặc biệt, bạn có thể gắn "Biểu thức điều kiện" (Expression) lên mũi tên. Ví dụ: kiểm tra hôm nay là cuối tuần hay ngày thường để rẽ nhánh chạy các quy trình khác nhau._

**Q: How is the SSIS Runtime Engine different from the Data Flow Pipeline Engine?**

- **Runtime Engine (Control Flow Engine):** Manages the overall package execution, variables, logging, transactions, and the orchestration of tasks (Control Flow).
- **Data Flow Pipeline Engine:** A highly optimized, multi-threaded engine specifically dedicated to the Data Flow Task. It manages buffers (memory) to process data in memory without staging it to disk, making data transformations extremely fast.
  > _Giải thích: Runtime Engine quản lý toàn bộ gói (package), biến số và thứ tự các Task. Pipeline Engine là động cơ chuyên biệt cho Data Flow, quản lý bộ nhớ đệm (buffer) để biến đổi dữ liệu siêu tốc trên RAM mà không cần ghi xuống ổ cứng._

**Q: What are the main SSIS Package Storage Locations and Deployment Models?**
There are two main deployment models and storage locations:

1. **Project Deployment Model (Modern - SQL Server 2012+):** You build the project to generate an `.ispac` file, then deploy it directly to SQL Server into the **SSIS Catalog (SSISDB)**.
   - _SSIS Catalog:_ A central storage point in SQL Server Management Studio (SSMS) for SSIS projects, packages, parameters, and environments.
2. **Package Deployment Model (Legacy):** You deploy packages directly to the **File System** (as `.dtsx` files) or store them in the SQL Server **`msdb` database**.

> _Giải thích: Vị trí lưu trữ và deploy: Cách hiện đại là lưu thẳng lên SSIS Catalog (SSISDB) trên SQL Server. Cách cũ là lưu ở File System dưới dạng file .dtsx hoặc lưu thẳng vào database hệ thống `msdb`._

**Q: What are the types of package configurations used when moving SSIS packages between environments?**
Configuration properties are used to **externalize package settings** (like usernames, passwords, and server connection strings). This ensures the package runs correctly in different environments (e.g., Dev to Prod) without modifying the package itself or hardcoding values. The 5 main types of configurations for package deployment are:

1. **XML Configuration file**
2. **Environment variable**
3. **Registry entry**
4. **Parent package variable**
5. **SQL Server table**

> _Giải thích: File Config hoặc Parameter dùng để lưu các thông số thay đổi được (như chuỗi kết nối, mật khẩu). Khi đẩy code lên Prod, thay vì sửa code, bạn chỉ cần cấu hình lại các thông số này. Có 5 cách cấu hình phổ biến: file XML, biến môi trường (Environment variable), Registry, biến từ package cha (Parent package variable), hoặc bảng SQL Server._

**Q: How can you execute an SSIS package from the command prompt?**
You can use the built-in utility called **DTExec.exe**. By providing the file path of the package in the command line, you can trigger its execution entirely outside of the Visual Studio environment.

> _Giải thích: Để chạy package bằng giao diện dòng lệnh (CMD), bạn dùng công cụ DTExec.exe truyền kèm đường dẫn của file package._

**Q: How do you schedule an SSIS package?**
You use the **SQL Server Agent** within SQL Server Management Studio (SSMS). By creating a new 'Job' and adding a step that points to your package file, you can set a 'Schedule' to determine its frequency (e.g., daily) and execution time.

> _Giải thích: Để đặt lịch chạy tự động, bạn dùng công cụ SQL Server Agent trong SSMS. Tạo một 'Job', trỏ tới file package của bạn, rồi cài đặt lịch chạy (ví dụ chạy lúc 2 giờ sáng mỗi ngày)._

**Q: What is the difference between a For Loop and a Foreach Loop Container?**

- **For Loop:** Executes a workflow a specific number of times based on defined conditions (initialization, evaluation condition, and assignment), similar to a `for` loop in programming.
- **Foreach Loop:** Iterates over a _collection of items_ (like files in a folder or rows in a dataset), similar to a `foreach` loop in programming.
  > _Giải thích: For Loop chạy theo số vòng lặp có điều kiện (ví dụ chạy từ 1 đến 10). Foreach Loop dùng để duyệt qua các phần tử trong một bộ sưu tập (ví dụ từng file CSV trong thư mục)._

**Q: Explain the Lookup Transformation and its Cache Modes?**
The Lookup Transformation is used to perform a JOIN in memory to fetch related data (like a VLOOKUP in Excel). It has three cache modes:

- **Full Cache (Default):** Queries the database _once_ before the Data Flow starts and loads the entire reference table into RAM. Extremely fast for processing, but consumes a lot of memory.
- **Partial Cache:** Caches only the rows that are successfully matched as the data flows. Hits the database for any new keys.
- **No Cache:** Hits the database for _every single row_ in the data pipeline. Very slow, only used if the reference table is massive and memory is severely restricted.
  > _Giải thích: Full Cache nạp toàn bộ bảng tham chiếu lên RAM (rất nhanh nhưng ngốn RAM). Partial Cache chỉ nhớ những dòng đã tra cứu. No Cache dòng nào tới thì query dòng đó xuống DB (rất chậm)._
  > _Note on Duplicates:_ If multiple matches are found, the Lookup transformation is typically configured to return **only one record** from the reference dataset based on its internal logic.
  > _Lưu ý về dữ liệu trùng lặp: Nếu có nhiều dòng khớp nhau ở bảng tham chiếu, Lookup mặc định chỉ trả về một dòng duy nhất (dòng đầu tiên tìm thấy)._

**Q: How do you handle errors in SSIS and what are the Error Handling Options in the Data Flow?**
Error handling happens at two levels:

1. **Control Flow Level (Event Handlers):** You configure Event Handlers (like `OnError`) to execute specific workflows (e.g., sending failure emails) when a task fails.
2. **Data Flow Level (Error Outputs):** When a component encounters an error (like data truncation), you have three options:
   - **Fail Component:** The default behavior. The process stops completely on the first error.
   - **Ignore Failure:** Allows the package to skip the bad data and continue processing the rest.
   - **Redirect Row:** Sends the error rows down a red Error Output path to a separate destination (like an error log table) for later review, while allowing good rows to continue.

> _Giải thích: Ở Data Flow có 3 cách xử lý lỗi: 'Fail Component' (lỗi là dừng luôn), 'Ignore Failure' (lỗi thì bỏ qua chạy tiếp), và 'Redirect Row' (đá dòng lỗi ra một luồng riêng màu đỏ để lưu lại, các dòng đúng vẫn chạy bình thường)._

**Q: How do you debug an SSIS package?**
You can debug packages by placing **Breakpoints** on Control Flow tasks to pause execution and inspect the state of variables. During execution, you can also use the **Progress/Execution Results tab** in Visual Studio to monitor performance and identify exactly where issues occur. (Note: Breakpoints cannot be placed _inside_ the Data Flow, but you can use Data Viewers to inspect rows in transit).

> _Giải thích: Để debug, bạn có thể đặt Breakpoint ở các Task trong Control Flow để xem giá trị biến. Hoặc qua tab Progress để xem log chạy. Lưu ý là không đặt được Breakpoint bên trong Data Flow, mà phải dùng Data Viewer để xem dữ liệu đang chảy qua dây nối._

**Q: What is Event Logging in SSIS?**
Logging captures runtime events (like `OnError`, `OnPreExecute`, and `OnPostExecute`). SSIS provides **Log Providers** (Text files, SQL Server, XML, Windows Event Log) to record these details.
_Inheritance:_ You can configure logging at the Package, Container, or Task level. If you configure it at a Container level, all tasks within that container will automatically inherit that logging configuration.

> _Giải thích: Logging lưu lại các sự kiện (như OnError, OnPreExecute). Bạn có thể thiết lập Log ở cấp độ Package, Container hoặc Task. Nếu cài ở Container, tất cả các Task bên trong sẽ kế thừa cấu hình log đó._

**Q: What should you do if an SSIS package is taking a very long time to run?**
You should implement logging specifically on the `OnPreExecute` and `OnPostExecute` events for all tasks in the package. By analyzing the start and end times captured in the logs, you can pinpoint the exact task causing the delay. Once identified, you can optimize that specific SQL query, stored procedure, or data flow process.

> _Giải thích: Nếu package chạy quá lâu, hãy bật log cho sự kiện `OnPreExecute` (lúc bắt đầu) và `OnPostExecute` (lúc chạy xong). Nhìn vào log sẽ biết chính xác Task nào ngốn nhiều thời gian nhất để tập trung tối ưu chỗ đó._

**Q: What are SSIS Expressions?**
An SSIS expression is a combination of symbols, identifiers, literals, and functions that evaluate to a single data value. They are commonly used alongside variables for **dynamic configuration** within packages (e.g., dynamically changing a file path based on today's date).

> _Giải thích: Expression là các biểu thức logic (hàm, công thức) dùng để cấu hình động (dynamic) cho package, ví dụ như tự động lấy ngày giờ hiện tại để ghép vào tên file._

**Q: What is the difference between Variables and Parameters in SSIS?**

- **Variables:** Used to store values that can be accessed and changed by the package _at runtime_ (essential for dynamic operations). They have different scopes (e.g., Package-level vs Container-level). You can monitor their current values using the 'Variables' window during execution/debugging.
- **Parameters:** Passed from the outside (like from a SQL Server Agent Job) when the package starts. They are **read-only** during execution.
  > _Giải thích: Biến (Variables) dùng để lưu giá trị và có thể bị thay đổi trong lúc package đang chạy (rất quan trọng để cấu hình động). Biến có scope (phạm vi hoạt động) riêng và có thể được theo dõi qua cửa sổ 'Variables' khi debug. Ngược lại, Tham số (Parameters) truyền từ ngoài vào và chỉ được đọc (read-only)._

**Q: How do you implement transactions in SSIS?**
Transactions are managed via the `TransactionOption` property, available at the package, container, and task levels. To use them, you typically set a container (like a Sequence Container) to **Required** and ensure the **MSDTC (Microsoft Distributed Transaction Coordinator)** service is running on the machine. The three settings are:

- **Required:** Starts a new transaction.
- **Supported:** Joins a transaction if one exists, otherwise runs without one.
- **NotSupported:** Will not join any transactions.
  > _Giải thích: Giao dịch (Transaction) đảm bảo tính toàn vẹn (nếu 1 task lỗi thì toàn bộ sẽ Rollback). Để dùng, set TransactionOption là Required, và phải đảm bảo service MSDTC của Windows đang chạy._

**Q: What is a Checkpoint in SSIS?**
Checkpoints allow a failed SSIS package to restart from the exact point of failure, rather than starting all over from the beginning. It saves the execution state in an XML file.
_Important Catch:_ Checkpoints only work at the **Control Flow** level. If a Data Flow Task fails halfway through, the checkpoint will force the _entire_ Data Flow Task to run again from scratch.

> _Giải thích: Checkpoints giúp package chạy lại từ chỗ bị lỗi (thay vì chạy lại từ đầu). Lưu ý là nó chỉ lưu vết ở tầng Control Flow, nếu lỗi giữa chừng bên trong Data Flow thì vẫn phải nạp lại Data Flow đó từ đầu._

**Q: What is an Incremental Load and why is it used?**
An incremental load processes only **new or modified records** from a source system into the destination. This is much more efficient than a full load, which would require truncating and reloading the entire destination table every time.

> _Giải thích: Lấy dữ liệu tăng thêm (Incremental Load) chỉ lấy các dòng mới hoặc bị sửa. Nó tối ưu và nhanh hơn rất nhiều so với Full Load (phải xóa trắng bảng đích rồi nạp lại toàn bộ)._

**Q: What is the difference between 'Table or View' and 'Table or View - Fast Load' in the OLE DB Destination?**

- **Table or View:** Performs a standard insert, adding one record at a time. It is very slow for large datasets.
- **Table or View - Fast Load:** Uses a **bulk-insert** operation to drastically improve performance by inserting data in batches rather than individually. You can further tune performance by modifying the 'Maximum insert commit size' property.
  > _Giải thích: Tùy chọn 'Table or View' nạp dữ liệu từng dòng một (rất chậm). Còn 'Fast Load' dùng cơ chế bulk-insert nạp dữ liệu theo từng mẻ lớn (batches), giúp tốc độ nạp nhanh hơn gấp nhiều lần._

**Q: What are the disadvantages of running SQL commands inside a Data Flow (OLE DB Command)?**
While the Execute SQL Task in the Control Flow operates on entire sets of data, using an **OLE DB Command** transformation _inside_ a Data Flow is highly inefficient for heavy operations. It executes the SQL statement (SELECT, DELETE, or UPDATE) **row-by-row** rather than using set-based processing, causing severe bottlenecks.

> _Giải thích: Trong Control Flow, Execute SQL Task chạy lệnh một lần cho toàn bộ dữ liệu (rất nhanh). Nhưng dùng OLE DB Command bên trong Data Flow thì lệnh SQL sẽ bị thực thi từng dòng một (row-by-row), rất chậm và không nên dùng cho dữ liệu lớn._

**Q: How should you handle very large data sets for SCD (Slowly Changing Dimensions) in SSIS?**
While the built-in SCD Transformation wizard is easy to use, it performs row-by-row operations and becomes a massive performance bottleneck for large datasets. For large data, you should avoid the wizard and manually build the SCD logic using a combination of **Lookup Transformations, Conditional Splits, and optimized OLE DB Destinations** for bulk operations.

> _Giải thích: Công cụ SCD có sẵn của SSIS chạy từng dòng một (rất chậm). Với dữ liệu siêu lớn, không nên dùng nó mà hãy tự "lắp ráp" logic SCD bằng Lookup, Conditional Split và Update theo mẻ (bulk update) để tối ưu hiệu suất._

**Q: Which is faster for an incremental load: Slowly Changing Dimension (SCD) wizard or Lookup Transformation?**
The **Lookup Transformation** is significantly faster. The SCD wizard uses the OLE DB Command transformation under the hood, which forces the engine to process updates row-by-row. In contrast, using a Lookup to identify changes allows you to stage the new/changed data first, and then perform a set-based update (like a `MERGE` statement) in a single execution.

> _Giải thích: Dùng Lookup nhanh hơn rất nhiều. Trình thủ thuật SCD có sẵn dùng OLE DB Command chạy từng dòng (row-by-row). Còn Lookup giúp ta rẽ nhánh để lấy ra các dòng cần cập nhật, đổ vào bảng tạm (staging) rồi chạy lệnh Update theo mẻ (set-based) 1 lần duy nhất._

**Q: How do you optimize a Lookup Transformation, and how does it differ from a Merge Join?**

- **Optimization:** Because a Lookup (in Full Cache mode) loads the reference dataset into RAM, you should never select an entire table. Instead, write a custom SQL query (`SELECT KeyColumn, ValueColumn FROM ReferenceTable`) to pull only the strictly necessary columns, minimizing memory consumption.
- **Lookup vs. Merge Join:**
  - **Lookup:** Acts like a Left/Inner Join. Does **not** require sorted inputs. It caches data in memory. Crucially, if there are duplicate matches, Lookup returns only the **first matching row**.
  - **Merge Join:** Supports Inner, Left, and Full Outer Joins. It strictly requires both input datasets to be **sorted** on the join keys beforehand. It does not load the whole table into memory, and it handles one-to-many relationships (returning all matching rows).

> _Giải thích: Tối ưu Lookup: Vì Lookup nạp dữ liệu lên RAM, đừng bao giờ select nguyên cả bảng. Hãy tự viết câu SQL chỉ select đúng cột Khóa và cột Cần Lấy. Phân biệt với Merge Join: Lookup không cần sort dữ liệu, dùng RAM, và chỉ lấy 1 dòng đầu tiên nếu bị trùng lặp. Merge Join thì ép buộc phải Sort cả 2 bên trước khi join, nhưng hỗ trợ nhiều kiểu join (Full Outer) và lấy được tất cả các dòng bị trùng (1-nhiều)._

**Q: What is the purpose of the Data Profiling Task in SSIS?**
The Data Profiling Task is used in the Control Flow for **data quality analysis**. It analyzes source data to check for issues like NULL counts, value distributions, pattern matching, and column lengths. It ensures the data meets quality standards _before_ processing it.

> _Giải thích: Data Profiling Task dùng để phân tích chất lượng dữ liệu. Nó giúp kiểm tra xem cột có bao nhiêu dữ liệu NULL, phân bổ dữ liệu ra sao... nhằm đảm bảo nguồn data sạch trước khi đưa vào luồng ETL._

**Q: What is the difference between the Merge and Union All transformations?**
Both transformations combine multiple datasets into a single output stream, but:

- **Union All:** Simple and fast. Does _not_ require the input datasets to be sorted.
- **Merge:** Requires that all input datasets be **sorted** beforehand. It combines them based on the sorted key.
  > _Giải thích: Cả hai đều dùng để gộp các luồng dữ liệu. Union All thì gộp thẳng (không cần sắp xếp). Còn Merge thì bắt buộc dữ liệu đầu vào phải được sắp xếp (sorted) trước thì mới chạy được._

**Q: What is the difference between a Copy Column and a Derived Column transformation?**

- **Copy Column:** Specifically used to create a direct, exact copy of an existing column.
- **Derived Column:** A much more versatile tool used for creating new columns, modifying existing data, or applying functions and expressions to columns (e.g., concatenating First and Last Name).
  > _Giải thích: Copy Column chỉ làm đúng 1 việc là nhân bản (copy y hệt) một cột. Derived Column mạnh hơn rất nhiều, dùng để tính toán, nối chuỗi, hoặc tạo cột mới dựa trên các biểu thức logic._

**Q: How can you send an email from an SSIS package?**
For basic notifications (using an open SMTP server), you use the built-in **Send Mail Task**. For advanced needs (like sending through Gmail SMTP with authentication, or generating HTML-formatted reports from SQL query results and embedding them in the email body), you must use a **Script Task** written in C#.

> _Giải thích: Để gửi email cơ bản, dùng 'Send Mail Task'. Nhưng nếu cần gửi qua Gmail (cần xác thực) hoặc nhúng bảng báo cáo HTML đẹp mắt vào email, bạn bắt buộc phải dùng 'Script Task' để code bằng C#._

**Q: How can you move files from one folder to another in SSIS?**
For simple moves, copies, or renames, use the **File System Task**. If the file handling requires complex custom logic (like checking specific file metadata before moving), you can write custom code in a **Script Task**.

> _Giải thích: Di chuyển, copy, đổi tên file đơn giản thì dùng 'File System Task'. Nếu có logic phức tạp thì dùng 'Script Task'._

**Q: Which task is used to download files from an FTP server?**
You use the standard **FTP Task** for basic upload/download operations. If the FTP server requires specific secure protocols (like SFTP) or custom handling not supported natively, you use a **Script Task** with a third-party C# library.

> _Giải thích: Dùng 'FTP Task' mặc định để tải file. Nếu là máy chủ SFTP (bảo mật cao) mà FTP Task không hỗ trợ, phải dùng 'Script Task' để tự code._

**Q: How do you download data from a web service (API) in SSIS?**
There are two main approaches:

1. Use the built-in **Web Service Task** provided by SSIS (typically used for simpler SOAP services).
2. Write custom C# code within a **Script Task** to handle more modern, complex REST API requests, authentication, and parsing.

> _Giải thích: Có 2 cách để lấy data từ Web API: Dùng 'Web Service Task' mặc định (dành cho SOAP cũ) hoặc dùng 'Script Task' viết code C# (rất mạnh, xử lý được REST API hiện đại)._

**Q: How do you call one SSIS package from another?**
You use the **Execute Package Task** in the Control Flow. You can link the child package by setting a project reference (if they are in the same project) or by specifying the full file path.

> _Giải thích: Để gọi một package khác chạy bên trong package hiện tại, dùng 'Execute Package Task'. Bạn có thể trỏ tới package con bằng Project Reference hoặc đường dẫn file._

**Q: What is the Bulk Insert Task and how does it handle existing data?**
The **Bulk Insert Task** (used in the Control Flow, unlike the OLE DB Destination in the Data Flow) is used to rapidly transfer data directly from a text file to a SQL Server table or view. By default, it **appends** data if the destination table already has records. If you want to replace the data, you must use an Execute SQL Task to `TRUNCATE` the table before running the Bulk Insert.

> _Giải thích: 'Bulk Insert Task' nằm ở Control Flow, dùng để nạp siêu tốc dữ liệu từ file text thẳng vào SQL. Mặc định nó sẽ ghi thêm (append). Nếu muốn ghi đè, phải chạy Execute SQL Task để xóa bảng (Truncate) trước khi nạp._

**Q: Behavioral: What is the most complex SSIS package you have worked on?**
_Interview Strategy:_ Combine the tasks mentioned above into a single, cohesive story.
**Example Answer:** "One of the most complex packages I built was a fully automated end-to-end pipeline. It started by connecting to a vendor's FTP server using an FTP Task to download daily files. A Script Task then unzipped the files. I used a For Each Loop Container to iterate through the CSVs, pulling them through a Data Flow where I used Lookup Transformations for data matching against our CRM, routing bad data to an Error table. Finally, the processed results were exported, zipped back up, and uploaded to another FTP server for the client, followed by a Send Mail Task that blasted out an HTML summary report to the stakeholders."

> _Giải thích: Câu hỏi kinh nghiệm. Hãy kể một chuỗi quy trình: Tải file từ FTP -> Giải nén bằng Script Task -> Lặp For Each qua từng file CSV -> Dùng Lookup đối chiếu dữ liệu -> Xuất kết quả -> Nén lại đẩy lên FTP -> Gửi Email báo cáo._

---

## Section 5: BI Tools & Data Cleansing

#### Topic 13: SSAS (SQL Server Analysis Services)

| Engine               | Storage/Architecture                      | Query Language | Best For                                    | Giải thích tiếng Việt                                                                                  |
| :------------------- | :---------------------------------------- | :------------- | :------------------------------------------ | :----------------------------------------------------------------------------------------------------- |
| **Tabular**          | In-memory columnar (VertiPaq). Very fast. | DAX            | Modern BI, Power BI integration.            | _Chạy trên RAM, lưu trữ theo cột. Rất nhanh, dùng DAX, chuẩn của Power BI hiện tại._                   |
| **Multidimensional** | Disk-based cubes.                         | MDX            | Complex many-to-many financial allocations. | _Công nghệ cũ (Cubes) lưu trên ổ cứng, dùng MDX. Tốt cho các bài toán phân bổ tài chính cực phức tạp._ |

#### Topic 14: Power BI Storage Modes

| Mode                 | How it works                                                                     | Best For                           | Giải thích tiếng Việt                                                                                    |
| :------------------- | :------------------------------------------------------------------------------- | :--------------------------------- | :------------------------------------------------------------------------------------------------------- |
| **Import Mode**      | Data is compressed into Power BI's memory (VertiPaq). Fastest performance.       | Most standard dashboards.          | _Load hẳn dữ liệu vào RAM của Power BI. Nhanh nhất nhưng bị giới hạn dung lượng._                        |
| **DirectQuery**      | Sends SQL queries back to the DB in real-time. No data stored in PBI.            | Massive datasets, real-time needs. | _Truy vấn trực tiếp xuống Database. Chậm hơn do phụ thuộc mạng và DB, nhưng xem được dữ liệu real-time._ |
| **Composite Models** | Combines Import Mode (for small Dimensions) and DirectQuery (for massive Facts). | Enterprise scale BI.               | _Kết hợp cả hai: Bảng nhỏ thì Import, bảng to thì DirectQuery._                                          |

#### Topic 15: Advanced DAX & Evaluation Context

- **Filter Context:** The set of filters applied to the data model _before_ the calculation happens (e.g., clicking '2023' on a slicer, or putting 'Region' on a visual axis).
  > _Ngữ cảnh Lọc: Là các bộ lọc đang được áp dụng (từ Slicer, từ trục biểu đồ) trước khi hàm tính toán chạy._
- **Row Context:** Exists when iterating over a table row-by-row (e.g., creating a Calculated Column or using `SUMX`). It knows exactly which row it is currently calculating, but it _does not_ filter the data.
  > _Ngữ cảnh Dòng: Xảy ra khi duyệt từng dòng (như hàm SUMX). Nó chỉ biết nó đang ở dòng nào chứ không có tác dụng lọc dữ liệu._
- **Context Transition:** The magic of the `CALCULATE()` function. It transforms an existing Row Context into a Filter Context.
  > _Chuyển đổi Ngữ cảnh: Hàm CALCULATE có phép thuật biến Ngữ cảnh Dòng thành Ngữ cảnh Lọc._

#### Topic 16: Troubleshooting Slow BI Dashboards & Data Quality

- **Debugging Workflow:**
  1. Use **Performance Analyzer** in Power BI to find if the bottleneck is DAX, Visual Rendering, or Network.
  2. Copy slow DAX to **DAX Studio** to analyze the physical query plan.
  3. **Shift Left:** If DAX is doing heavy string manipulation, push that logic back to the SQL database.
     > _Quy trình bắt bệnh: Dùng Performance Analyzer xem lỗi do DAX hay do biểu đồ -> Dùng DAX Studio soi chi tiết -> Nếu code DAX quá phức tạp thì đẩy (Shift Left) logic đó về cho SQL xử lý._
- **VertiPaq Cardinality:** High cardinality (many unique values, like a `DateTime` column down to the millisecond) ruins compression. _Optimization:_ Split `DateTime` into separate `Date` and `Time` columns.
  > _Tối ưu Cardinality: Cột Thời gian tính đến mili-giây có quá nhiều giá trị khác biệt sẽ làm mất tính nén của VertiPaq. Giải pháp: Tách riêng cột Ngày và cột Giờ._
- **Advanced Deduplication (Golden Record):** Instead of blindly deleting duplicates, define a "Golden Record" hierarchy (e.g., trust the CRM system over the marketing system based on predefined business rules).
  > _Xử lý trùng lặp nâng cao: Không xóa bừa. Đặt ra luật "Golden Record" (ví dụ: nếu trùng email, luôn lấy thông tin từ hệ thống CRM làm chuẩn)._

---

## Section 6: Behavioral & Client Research (Demonstrating Seniority)

**Focus:** Proving you are a senior-level fit culturally and professionally.

- **Research Pinnacle Group:**
  - _Core:_ Visit [www.pinnacle1.com](http://www.pinnacle1.com).
  - _Advanced:_ Analyze how their workforce/staffing solutions can be driven by the BI reporting and analytics you will build. Think about the business value.
- **The "Tell me about yourself" Pitch:**
  - _Core:_ Draft a concise 5-minute career history.
  - _Advanced:_ **Bridge your Data Engineering background** (Python, Spark, cloud architecture) with this BI role. Show how your deeper engineering knowledge makes you a stronger BI Developer who understands the entire data lifecycle.

  **Answer Details:**
  - **Pitching Your Background:** _"I come from a strong Data Engineering background using Python, Spark, and heavy SQL. This means I don't just know how to build a pretty Power BI dashboard—I deeply understand the infrastructure behind it. I know how to optimize the underlying database queries, design robust ETL pipelines, and tune performance at the engine level so that the BI presentation layer is both accurate and lightning-fast."_

- **STAR Method Practice (Situation, Task, Action, Result):**
  - Prepare 1 story about fixing a major architectural mistake or optimizing a terribly slow query.
  - Prepare 1 story about handling critical feedback from business stakeholders.

  **Answer Details:**
  - **Situation:** Our main dashboard was taking 45 seconds to load because the underlying view was using multiple nested CTEs and correlated subqueries.
  - **Task:** I was tasked with bringing the load time under 5 seconds.
  - **Action:** I rewrote the SQL logic to replace the correlated subqueries with `ROW_NUMBER()` window functions, eliminating millions of unnecessary reads. I also materialized the final dataset into an indexed physical table overnight rather than calculating it on the fly.
  - **Result:** The query execution dropped from 45 seconds to 2 seconds. User adoption of the dashboard increased by 40% because it was finally responsive.

- **Handling Development Challenges:**
  - Be prepared to discuss how you troubleshoot errors.
  - _Example Answer:_ "When I face a new challenge, my first step is leveraging online resources like Google and StackOverflow, as most ETL challenges have been encountered and documented by others. For specific technical errors—for instance, if I run into a DLL error inside a Script Task—I know it is often a referencing issue. I will troubleshoot by checking the references in the script editor or ensuring the DLL is correctly restarted or re-registered in the Global Assembly Cache (GAC) if necessary."

---
