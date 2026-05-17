# Advanced SQL & Data Modelling — Complete Interview Prep

_Targets the JD requirement: "Advanced SQL knowledge and experience (stored procedures, functions, triggers) and understanding of data warehousing and data modelling."_

---

## PART 1: Stored Procedures

### What Is a Stored Procedure?

A **Stored Procedure (SP)** is a named, pre-compiled collection of T-SQL statements stored in the database. Because SQL Server compiles and caches the execution plan the first time a SP runs, subsequent executions are significantly faster than sending raw query strings from an application.

### Why Use Stored Procedures?

| Benefit | Explanation |
|---|---|
| **Performance** | Execution plan is compiled once and cached. Reduces parsing overhead. |
| **Security** | You can grant `EXECUTE` permission on an SP without giving users direct `SELECT`/`INSERT` access to underlying tables. |
| **Maintainability** | Business logic lives in one place. Change the SP, and every application that calls it gets the fix automatically. |
| **Encapsulation** | Hides complex business rules (like payroll calculations) behind a clean interface. |

### Basic Structure with Best Practices

```sql
CREATE OR ALTER PROCEDURE dbo.usp_GetEmployeePaySummary
    @EmployeeID    INT,
    @PayPeriodDate DATE
AS
BEGIN
    -- Best Practice 1: Always include SET NOCOUNT ON.
    -- This suppresses the "N rows affected" message, reducing unnecessary
    -- network traffic between SQL Server and the calling application.
    SET NOCOUNT ON;

    SELECT
        e.EmployeeID,
        e.FullName,
        p.GrossPay,
        p.TaxDeducted,
        p.NetPay
    FROM dbo.Employee    e
    JOIN dbo.PayrollRun  p ON e.EmployeeID = p.EmployeeID
    WHERE e.EmployeeID   = @EmployeeID
      AND p.PayPeriodDate = @PayPeriodDate;
END;
GO
```

> **Interview Tip:** Avoid the `sp_` prefix. SQL Server always searches the `master` system database first for any SP named with `sp_`, which adds unnecessary overhead. Use `usp_` (User Stored Procedure) instead.

---

### Advanced: Transaction Management & Error Handling

In ETL and payroll systems, partial failures are catastrophic. If step 3 of a 5-step process fails, you must roll back steps 1 and 2. This requires explicit transaction control combined with `TRY...CATCH`.

```sql
CREATE OR ALTER PROCEDURE dbo.usp_ProcessPayRun
    @PayPeriodDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Use a local variable to capture errors from inside the CATCH block
    DECLARE @ErrorMessage    NVARCHAR(4000);
    DECLARE @ErrorSeverity   INT;
    DECLARE @ErrorState      INT;

    BEGIN TRY
        -- Mark the start of an atomic operation
        BEGIN TRANSACTION;

            -- Step 1: Insert summary rows into the pay run staging table
            INSERT INTO dbo.PayRunStaging (EmployeeID, GrossPay, PayPeriodDate)
            SELECT
                EmployeeID,
                SUM(HoursWorked * HourlyRate) AS GrossPay,
                @PayPeriodDate
            FROM dbo.TimesheetEntries
            WHERE PayPeriodDate = @PayPeriodDate
            GROUP BY EmployeeID;

            -- Step 2: Calculate tax and update the staging table
            UPDATE s
            SET    s.TaxDeducted = s.GrossPay * t.TaxRate,
                   s.NetPay      = s.GrossPay - (s.GrossPay * t.TaxRate)
            FROM   dbo.PayRunStaging s
            JOIN   dbo.TaxBracket    t ON s.GrossPay BETWEEN t.MinAmount AND t.MaxAmount
            WHERE  s.PayPeriodDate = @PayPeriodDate;

            -- Step 3: Move validated data from staging into the final PayrollRun table
            INSERT INTO dbo.PayrollRun (EmployeeID, GrossPay, TaxDeducted, NetPay, PayPeriodDate)
            SELECT EmployeeID, GrossPay, TaxDeducted, NetPay, PayPeriodDate
            FROM   dbo.PayRunStaging
            WHERE  PayPeriodDate = @PayPeriodDate;

        -- If all steps succeeded, make the changes permanent
        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        -- If ANY step failed, undo everything back to the BEGIN TRANSACTION point
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Capture the actual error details
        SELECT
            @ErrorMessage  = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState    = ERROR_STATE();

        -- Log the error to an audit table for investigation
        INSERT INTO dbo.ErrorLog (ProcedureName, ErrorMessage, OccurredAt)
        VALUES ('usp_ProcessPayRun', @ErrorMessage, GETDATE());

        -- Re-raise the error to the calling application so it knows the run failed
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
END;
GO
```

> **Interview Answer:** _"In all my ETL stored procedures, I always wrap multi-step operations in a `BEGIN TRANSACTION / COMMIT` block inside a `TRY...CATCH`. If any step fails, the `CATCH` block rolls back the entire transaction so we never end up with partial data in the system. I also log all errors into an `ErrorLog` table for post-incident analysis."_

---

## PART 2: User-Defined Functions (UDFs)

Functions are designed for **pure computation** — they take input, calculate something, and return a result. They **cannot** modify database state.

### Type 1: Scalar Functions — Return a Single Value

A classic use case is calculating a value that is needed across many different queries, like an employee's tenure in years.

```sql
CREATE OR ALTER FUNCTION dbo.fn_CalculateTenureYears
(
    @HireDate DATE
)
RETURNS INT
AS
BEGIN
    RETURN DATEDIFF(YEAR, @HireDate, GETDATE())
         - CASE
               WHEN (MONTH(@HireDate) > MONTH(GETDATE()))
                 OR (MONTH(@HireDate) = MONTH(GETDATE()) AND DAY(@HireDate) > DAY(GETDATE()))
               THEN 1
               ELSE 0
           END;
END;
GO

-- Usage:
SELECT
    EmployeeID,
    FullName,
    HireDate,
    dbo.fn_CalculateTenureYears(HireDate) AS TenureYears
FROM dbo.Employee;
```

> ⚠️ **Critical Performance Warning:** Scalar functions called in a `SELECT` or `WHERE` clause against a large table force **Row-By-Agonizing-Row (RBAR)** execution. SQL Server calls the function once per row, effectively disabling set-based performance. For large ETL datasets, use an **Inline Table-Valued Function** instead.

---

### Type 2: Inline Table-Valued Functions (iTVF) — Return a Table (The Performant Choice)

An iTVF is treated by the SQL optimizer as an **inline view** (like a parameterized view). It is always preferred over Scalar Functions for large datasets because the optimizer can push predicates inside and generate an efficient execution plan.

```sql
-- This function returns a full pay summary for any given pay period.
-- Think of it as a "parameterized view".
CREATE OR ALTER FUNCTION dbo.fn_GetPaySummaryByPeriod
(
    @PayPeriodDate DATE
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        e.EmployeeID,
        e.FullName,
        d.DepartmentName,
        SUM(t.HoursWorked)              AS TotalHours,
        SUM(t.HoursWorked * e.HourlyRate) AS GrossPay
    FROM dbo.TimesheetEntries t
    JOIN dbo.Employee         e ON t.EmployeeID     = e.EmployeeID
    JOIN dbo.Department       d ON e.DepartmentID   = d.DepartmentID
    WHERE t.PayPeriodDate = @PayPeriodDate
    GROUP BY e.EmployeeID, e.FullName, d.DepartmentName
);
GO

-- Usage: The optimizer treats this EXACTLY like a regular table join.
-- You can filter, join, and aggregate on top of it efficiently.
SELECT *
FROM   dbo.fn_GetPaySummaryByPeriod('2025-05-01')
WHERE  GrossPay > 5000
ORDER BY GrossPay DESC;
```

---

## PART 3: Triggers

### What Is a Trigger?

A trigger is a special stored procedure that fires **automatically** in response to DML events (`INSERT`, `UPDATE`, `DELETE`) on a specific table. It runs **within the same transaction** as the originating statement — this is the most critical thing to understand about triggers.

### The INSERTED and DELETED Virtual Tables

Inside any DML trigger, SQL Server provides two special in-memory virtual tables:

| Virtual Table | Available In | Contains |
|---|---|---|
| `INSERTED` | `INSERT`, `UPDATE` | The **new** values (after the change) |
| `DELETED` | `DELETE`, `UPDATE` | The **old** values (before the change) |

For an `UPDATE`, both tables are populated: `DELETED` holds the before state, `INSERTED` holds the after state.

---

### Practical Example: Salary Change Audit Log

This is one of the most common real-world trigger use cases — automatically recording who changed what and when, without any application code changes needed.

```sql
-- First, create the audit log table
CREATE TABLE dbo.SalaryAuditLog (
    AuditID        INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID     INT            NOT NULL,
    OldSalary      DECIMAL(10, 2) NOT NULL,
    NewSalary      DECIMAL(10, 2) NOT NULL,
    ChangedByUser  NVARCHAR(128)  NOT NULL,
    ChangedAt      DATETIME2      NOT NULL DEFAULT GETDATE()
);
GO

-- Create the trigger on the Employee table
CREATE OR ALTER TRIGGER trg_Employee_SalaryAudit
ON dbo.Employee
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Only fire if the Salary column was actually changed.
    -- This is critical for performance — avoid running audit logic for
    -- unrelated UPDATE statements (e.g., updating an address).
    IF NOT UPDATE(Salary)
        RETURN;

    INSERT INTO dbo.SalaryAuditLog (EmployeeID, OldSalary, NewSalary, ChangedByUser)
    SELECT
        i.EmployeeID,
        d.Salary          AS OldSalary,   -- from DELETED (before state)
        i.Salary          AS NewSalary,   -- from INSERTED (after state)
        SYSTEM_USER       AS ChangedByUser
    FROM INSERTED i
    JOIN DELETED  d ON i.EmployeeID = d.EmployeeID
    WHERE i.Salary <> d.Salary; -- Extra safety: only log actual salary differences
END;
GO
```

> **Interview Answer:** _"I use triggers primarily for audit logging in payroll systems, where knowing who changed a salary is a compliance requirement. My rule of thumb is to always check `IF NOT UPDATE(column)` at the top of the trigger to make sure it only runs when the relevant column actually changed. This prevents the trigger from firing on unrelated `UPDATE` statements and keeps it as lightweight as possible."_

---

### Trigger Anti-Patterns (What NOT to Do)

```sql
-- ❌ BAD: Never call a slow stored procedure inside a trigger.
-- This forces every single INSERT on the Orders table to wait for the
-- full email-sending process before it can complete.
CREATE TRIGGER trg_Order_SendEmail
ON dbo.Orders
AFTER INSERT
AS
BEGIN
    -- This blocks the entire transaction until the email is sent!
    EXEC dbo.usp_SendConfirmationEmail; -- DO NOT DO THIS
END;
```

---

## PART 4: Data Warehousing & Dimensional Modelling

### OLTP vs. OLAP — The Fundamental Difference

| Aspect | OLTP (Application DB) | OLAP (Data Warehouse) |
|---|---|---|
| **Purpose** | Record day-to-day transactions | Support reporting and analysis |
| **Design** | Highly normalized (3NF) | Denormalized (Star Schema) |
| **Optimization** | Fast `INSERT` / `UPDATE` | Fast `SELECT` / aggregations |
| **Query Type** | Affects a few rows at a time | Scans millions of rows |
| **Example** | Ready Workforce app database | Payroll Analytics Data Warehouse |

---

### The Star Schema: Fact Tables + Dimension Tables

```
                    ┌─────────────┐
                    │  DimDate    │
                    │  DateKey PK │
                    └──────┬──────┘
                           │
  ┌─────────────┐    ┌──────┴──────────────┐    ┌────────────────┐
  │ DimEmployee │    │   FactPayrollRun     │    │ DimDepartment  │
  │ EmployeeKey ├────┤ EmployeeKey  (FK)    ├────┤ DepartmentKey  │
  │ FullName    │    │ DateKey      (FK)    │    │ DepartmentName │
  │ HireDate    │    │ DepartmentKey (FK)   │    └────────────────┘
  │ Gender      │    │ GrossPay             │
  └─────────────┘    │ TaxDeducted          │
                     │ NetPay               │
                     │ TotalHoursWorked     │
                     └──────────────────────┘
```

#### Surrogate Keys vs. Natural Keys

Dimension tables should **always** use an auto-incrementing integer (Surrogate Key) as the Primary Key, **not** the source system's natural key (e.g., `EmployeeID = 'EMP-0042'`).

**Why?**
1. **Performance:** Integer joins are always faster than string joins.
2. **SCD Support:** When an employee's record changes and you add a new version (SCD Type 2), the `EmployeeID` natural key stays the same, but you generate a new unique `EmployeeKey` for the new version. The Fact table can then correctly link historical pay records to the old version of the employee.

```sql
-- Example: DimEmployee with Surrogate Key and SCD Type 2 columns
CREATE TABLE dbo.DimEmployee (
    EmployeeKey   INT IDENTITY(1,1) PRIMARY KEY,  -- Surrogate Key (generated by DW)
    EmployeeID    INT           NOT NULL,           -- Natural Key (from source system)
    FullName      NVARCHAR(200) NOT NULL,
    DepartmentName NVARCHAR(100) NOT NULL,
    HourlyRate    DECIMAL(10, 2) NOT NULL,
    -- SCD Type 2 tracking columns
    EffectiveDate DATE          NOT NULL,
    ExpiryDate    DATE          NULL,               -- NULL = currently active record
    IsCurrent     BIT           NOT NULL DEFAULT 1
);
```

---

### Slowly Changing Dimensions (SCD) — A Guaranteed Interview Topic

When a dimension attribute changes over time (e.g., an employee changes department), you must decide how the Data Warehouse handles the history.

#### SCD Type 1: Overwrite (No History)
Simply update the existing row. The old value is permanently lost.
- **When to use it:** For corrections (e.g., fixing a typo in an employee's name). You don't need to track the history of a name typo.
- **Downside:** Historical fact records will appear to have always belonged to the *new* department, making historical analysis inaccurate.

```sql
-- SCD Type 1: Simple overwrite — history is lost
UPDATE dbo.DimEmployee
SET    DepartmentName = 'Information Technology'
WHERE  EmployeeID = 42
  AND  IsCurrent = 1;
```

#### SCD Type 2: Add a New Row (Full History Preserved)
Expire the old row and insert a brand new row for the changed record. This is the **industry standard** for preserving accurate historical analysis.

```sql
-- SCD Type 2: Step 1 — expire the existing active record
UPDATE dbo.DimEmployee
SET    ExpiryDate = CAST(GETDATE() AS DATE),
       IsCurrent  = 0
WHERE  EmployeeID = 42
  AND  IsCurrent  = 1;

-- SCD Type 2: Step 2 — insert a new row for the new version
INSERT INTO dbo.DimEmployee (EmployeeID, FullName, DepartmentName, HourlyRate, EffectiveDate, ExpiryDate, IsCurrent)
SELECT
    42,
    'John Smith',
    'Information Technology',   -- The new department
    35.00,
    CAST(GETDATE() AS DATE),
    NULL,                        -- No expiry date = currently active
    1
;
```

> **Interview Answer:** _"In our data warehouse, all dimension tables are designed to support SCD Type 2. When an employee changes their department, we never overwrite their history. Instead, we expire the old row by setting its `ExpiryDate` and flipping `IsCurrent` to 0, then we insert a fresh row with the new department. This means our Fact table's historical payroll records remain correctly linked to the department the employee was in when they were actually paid — not their current department. This is critical for accurate year-over-year reporting."_

---

### Incremental Loading with MERGE (The ETL Workhorse)

Loading a full dump of data every night is inefficient. For large tables, you only want to process rows that are **new** or **changed**. The `MERGE` statement handles this in one elegant operation.

```sql
-- This MERGE loads data from a staging table into the DimEmployee dimension.
-- It handles 3 scenarios in one statement:
--   1. If a matching employee exists and data has changed -> UPDATE it (SCD Type 1 fields)
--   2. If no match exists -> INSERT it as a new employee
--   3. If a source record is no longer in the source -> (optional) flag as inactive

MERGE dbo.DimEmployee AS Target
USING dbo.Staging_Employee AS Source
    ON (Target.EmployeeID = Source.EmployeeID AND Target.IsCurrent = 1)

-- Scenario 1: Record exists but department has changed (SCD Type 2 handled separately,
-- this handles simple Type 1 fields like HourlyRate corrections)
WHEN MATCHED AND Target.HourlyRate <> Source.HourlyRate THEN
    UPDATE SET
        Target.HourlyRate = Source.HourlyRate

-- Scenario 2: Brand new employee — insert them
WHEN NOT MATCHED BY TARGET THEN
    INSERT (EmployeeID, FullName, DepartmentName, HourlyRate, EffectiveDate, IsCurrent)
    VALUES (Source.EmployeeID, Source.FullName, Source.DepartmentName,
            Source.HourlyRate, CAST(GETDATE() AS DATE), 1)

-- Scenario 3: Employee exists in DW but was removed from source — deactivate them
WHEN NOT MATCHED BY SOURCE AND Target.IsCurrent = 1 THEN
    UPDATE SET
        Target.IsCurrent  = 0,
        Target.ExpiryDate = CAST(GETDATE() AS DATE);
GO
```

---

## PART 5: Quick-Fire Interview Q&A

**Q: What is the difference between a Scalar Function and an Inline Table-Valued Function?**
> _"A Scalar Function returns a single value and is often a performance bottleneck because it forces row-by-row execution. An Inline TVF returns a table and is treated by the optimizer like a view—it can be parallelized and the optimizer can push predicates inside it. For any function used on large datasets in an ETL, I always prefer iTVFs."_

**Q: When would you use a trigger instead of putting logic in a stored procedure?**
> _"I use triggers when I need something to happen automatically and invisibly every time a table changes, regardless of which application or stored procedure caused the change—like writing to an audit log. But I keep triggers extremely lightweight. The moment a trigger needs complex logic, I move that logic to a scheduled job or an explicit call in a stored procedure, because a slow trigger blocks the originating transaction and can cause deadlocks."_

**Q: Why do you always use surrogate keys in Dimension tables?**
> _"Two reasons. First, integer joins are always faster than string joins, which matters at scale in a data warehouse. Second, surrogate keys make SCD Type 2 possible. When an employee changes departments, the source system's EmployeeID doesn't change, but we insert a new dimension row and assign a new surrogate key. The fact table then correctly points to the old version for old records and the new version for new records—something impossible to do cleanly with natural keys alone."_

**Q: What is the "grain" of a fact table and why does it matter?**
> _"The grain defines the level of detail of a single row in the fact table. For example, 'one row per employee per pay period' vs. 'one row per daily timesheet entry per employee.' Defining the grain correctly is the most important design decision because it determines what questions you can and cannot answer with the data. A coarser grain is faster but less flexible; a finer grain is more powerful but requires more storage and aggregation at query time."_
