# SQL Technical Questions & Solutions

This document combines the technical test questions with their corresponding solutions and explanations. Use this to practice your problem-solving and verify your logic.

---

## Problem 1: Duplicate Job Postings

### Table: Job Postings

| job_id | company_id | title            |
| :----- | :--------- | :--------------- |
| 248    | 827        | Business Analyst |
| 149    | 845        | Business Analyst |
| 945    | 345        | Data Analyst     |
| 164    | 345        | Data Analyst     |
| 172    | 244        | Data Engineer    |

### Question 1: Find companies with duplicate job postings

_Write a query to return the company or companies with duplicate job postings. Result should include `company_id`, number of duplicate job postings._

**Solution:**

```sql
SELECT
    company_id,
    COUNT(job_id) AS number_of_duplicate_job_postings
FROM
    job_postings
GROUP BY
    company_id
HAVING
    COUNT(job_id) > 1;
```

**Why this works:** We group by `company_id` and use the `HAVING` clause to filter out any groups that only have 1 job posting.

### Question 2: Delete duplicate job postings

_Write a query to delete duplicate Job Postings for each company, only keep 1 job posting per company that has the maximum `job_id`._

**Solution:**

```sql
WITH RankedPostings AS (
    SELECT
        job_id,
        ROW_NUMBER() OVER(PARTITION BY company_id ORDER BY job_id DESC) as rn
    FROM
        job_postings
)
DELETE FROM job_postings
WHERE job_id IN (
    SELECT job_id
    FROM RankedPostings
    WHERE rn > 1
);
```

**Why this works:** We use a CTE and the `ROW_NUMBER()` window function to rank jobs for each company. By ordering by `job_id DESC`, the maximum `job_id` gets `rn = 1`. We then delete any `job_id` where `rn > 1` (the duplicates).

---

## Problem 2: Employee Hierarchy & Salaries

### Table: Employees

| employee_id | name               | salary | department_id | manager_id |
| :---------- | :----------------- | :----- | :------------ | :--------- |
| 1           | Emma Thompson      | 3800   | 1             | 6          |
| 2           | Daniel Rodriguez   | 2230   | 1             | 7          |
| 3           | Olivia Smith       | 7000   | 1             | 8          |
| 4           | Noah Johnson       | 6800   | 2             | 9          |
| 5           | Sophia Martinez    | 1750   | 1             | 11         |
| 6           | Liam Brown         | 13000  | 3             | NULL       |
| 7           | Ava Garcia         | 12500  | 3             | NULL       |
| 8           | William Davis      | 6800   | 2             | NULL       |
| 9           | Isabella Wilson    | 11000  | 3             | NULL       |
| 10          | James Anderson     | 4000   | 1             | 11         |
| 11          | Mia Taylor         | 10800  | 3             | NULL       |
| 12          | Benjamin Hernandez | 9500   | 3             | 8          |
| 13          | Charlotte Miller   | 7000   | 2             | 6          |
| 14          | Logan Moore        | 8000   | 2             | 6          |

### Question 1: Find the manager with the most direct reports

_Write a query to return the manager that has the most direct reports. Result should include manager_id, manager name, number of direct reports._

**Solution:**

```sql
WITH ManagerCounts AS (
    SELECT
        e.manager_id,
        m.name AS manager_name,
        COUNT(e.employee_id) AS number_of_direct_reports,
        RANK() OVER (ORDER BY COUNT(e.employee_id) DESC) as rnk
    FROM
        Employees e
    JOIN
        Employees m ON e.manager_id = m.employee_id
    GROUP BY
        e.manager_id,
        m.name
)
SELECT
    manager_id,
    manager_name,
    number_of_direct_reports
FROM
    ManagerCounts
WHERE
    rnk = 1;
```

**Why this works:** We join the `Employees` table to itself to get the manager's name. We group by the manager and count the number of direct reports. We use the `RANK()` window function to assign a rank based on the count in descending order, then filter for rank 1 in the outer query to handle ties correctly.

### Question 2: Find managers whose direct reports' average salary > overall average salary

_Write a query to return the manager(s) that have average salary of their direct reports higher than the average salary of all employees. Result should include manager_id, manager name, average salary of direct reports, average salary of all employees._

**Solution:**

```sql
WITH AllEmployeesAvg AS (
    SELECT AVG(CAST(salary AS DECIMAL(10,2))) AS avg_salary_all
    FROM Employees
),
ManagerAvg AS (
    SELECT
        e.manager_id,
        m.name AS manager_name,
        AVG(CAST(e.salary AS DECIMAL(10,2))) AS avg_salary_direct_reports
    FROM
        Employees e
    JOIN
        Employees m ON e.manager_id = m.employee_id
    GROUP BY
        e.manager_id,
        m.name
)
SELECT
    m.manager_id,
    m.manager_name,
    m.avg_salary_direct_reports,
    a.avg_salary_all
FROM
    ManagerAvg m
CROSS JOIN
    AllEmployeesAvg a
WHERE
    m.avg_salary_direct_reports > a.avg_salary_all;
```

**Why this works:** We calculate the overall average salary in one CTE (`AllEmployeesAvg`) and the average salary per manager's direct reports in another CTE (`ManagerAvg`). We join the `Employees` table to itself in `ManagerAvg` to get the manager's name. Finally, we cross join the two CTEs to compare the manager's average with the overall average and filter accordingly.

---

## Problem 3: Sales Running Totals & Daily Rankings

### Table: Sales

| sale_id | salesperson_id | sale_date  | amount |
| :------ | :------------- | :--------- | :----- |
| 1       | 101            | 2023-10-01 | 500    |
| 2       | 101            | 2023-10-02 | 300    |
| 3       | 101            | 2023-10-03 | 700    |
| 4       | 102            | 2023-10-01 | 450    |
| 5       | 102            | 2023-10-03 | 900    |
| 6       | 101            | 2023-10-04 | 200    |
| 7       | 102            | 2023-10-04 | 600    |

### Question 1: Calculate running total of sales for each salesperson

_Write a query to calculate the cumulative total sales amount (running total) for each salesperson, ordered by `sale_date`._

**Solution:**

```sql
SELECT
    sale_id,
    salesperson_id,
    sale_date,
    amount,
    SUM(amount) OVER (PARTITION BY salesperson_id ORDER BY sale_date) AS running_total
FROM
    Sales
ORDER BY
    salesperson_id,
    sale_date;
```

**Why this works:** We use the `SUM()` window function partitioned by `salesperson_id` and ordered by `sale_date`. The `ORDER BY` inside the `OVER` clause defaults to calculating the sum from the first row of the partition up to the current row, creating a running total.

### Question 2: Find the top salesperson for each day

_Write a query to find the top 1 salesperson with the highest total sales amount for each day. If there is a tie, include all tied salespeople._

**Solution:**

```sql
WITH DailySales AS (
    SELECT
        sale_date,
        salesperson_id,
        SUM(amount) AS total_daily_amount
    FROM
        Sales
    GROUP BY
        sale_date,
        salesperson_id
),
RankedSales AS (
    SELECT
        sale_date,
        salesperson_id,
        total_daily_amount,
        DENSE_RANK() OVER (PARTITION BY sale_date ORDER BY total_daily_amount DESC) as rnk
    FROM
        DailySales
)
SELECT
    sale_date,
    salesperson_id,
    total_daily_amount
FROM
    RankedSales
WHERE
    rnk = 1;
```

**Why this works:** First, we aggregate sales per person per day using a CTE (`DailySales`). Then, we use the `DENSE_RANK()` window function to rank salespeople per day based on their total sales. Finally, we filter the results to only include `rnk = 1`, which automatically includes ties.

---

## Problem 4: Consecutive Login Streaks (Gaps and Islands)

### Table: UserLogins

| login_id | user_id | login_date |
| :------- | :------ | :--------- |
| 1        | 1       | 2023-01-01 |
| 2        | 1       | 2023-01-02 |
| 3        | 1       | 2023-01-03 |
| 4        | 1       | 2023-01-06 |
| 5        | 1       | 2023-01-07 |
| 6        | 2       | 2023-01-01 |
| 7        | 2       | 2023-01-05 |

### Question 1: Find the longest streak of consecutive daily logins

_Write a query to identify the longest streak of consecutive daily logins for each user. Result should include `user_id` and `max_consecutive_days`._

**Solution (Using ROW_NUMBER Difference):**

```sql
WITH RankedDates AS (
    SELECT
        user_id,
        login_date,
        -- Generate a row number for each user's logins, ordered by date
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date) AS rn
    FROM
        (SELECT DISTINCT user_id, login_date FROM UserLogins) AS distinct_logins
),
GroupedIslands AS (
    SELECT
        user_id,
        login_date,
        -- Subtracting the row number (as days) from the login date groups consecutive days into the same 'island_date'
        DATEADD(day, -rn, login_date) AS island_date
    FROM
        RankedDates
),
StreakLengths AS (
    SELECT
        user_id,
        island_date,
        COUNT(*) AS consecutive_days
    FROM
        GroupedIslands
    GROUP BY
        user_id,
        island_date
)
SELECT
    user_id,
    MAX(consecutive_days) AS max_consecutive_days
FROM
    StreakLengths
GROUP BY
    user_id;
```

**Why this works:** This uses the classic "Gaps and Islands" approach. By assigning a sequential `ROW_NUMBER` to ordered dates and subtracting that number of days from the actual date, consecutive dates will all result in the _same_ constant date (the "island" grouping key). We then count how many records belong to each group and find the maximum count per user.

**Alternative Solution (Using LAG):**

```sql
WITH DistinctLogins AS (
    SELECT DISTINCT user_id, login_date FROM UserLogins
),
LagDates AS (
    SELECT
        user_id,
        login_date,
        LAG(login_date) OVER (PARTITION BY user_id ORDER BY login_date) AS prev_login_date
    FROM
        DistinctLogins
),
IslandStarts AS (
    SELECT
        user_id,
        login_date,
        -- If previous date is null or more than 1 day ago, it's the start of a new island
        CASE
            WHEN prev_login_date IS NULL OR DATEDIFF(day, prev_login_date, login_date) > 1 THEN 1
            ELSE 0
        END AS is_new_island
    FROM
        LagDates
),
IslandGroups AS (
    SELECT
        user_id,
        login_date,
        -- Running sum of the flags creates a unique ID for each island
        SUM(is_new_island) OVER (PARTITION BY user_id ORDER BY login_date) AS island_id
    FROM
        IslandStarts
),
StreakLengths AS (
    SELECT
        user_id,
        island_id,
        COUNT(*) AS consecutive_days
    FROM
        IslandGroups
    GROUP BY
        user_id,
        island_id
)
SELECT
    user_id,
    MAX(consecutive_days) AS max_consecutive_days
FROM
    StreakLengths
GROUP BY
    user_id;
```

**Why this works:** We use `LAG()` to get the previous date. A `CASE` statement flags `1` if the gap is > 1 day. A running `SUM()` of these flags generates a unique `island_id` for each streak, which we then group by and count.

---

## Problem 5: Subscription Validations

### Table: Subscriptions

| sub_id | customer_id | start_date | end_date   | status    |
| :----- | :---------- | :--------- | :--------- | :-------- |
| 1      | 1001        | 2023-01-01 | 2023-03-31 | Cancelled |
| 2      | 1002        | 2023-02-15 | NULL       | Active    |
| 3      | 1001        | 2023-05-01 | NULL       | Active    |
| 4      | 1003        | 2023-01-10 | 2023-02-10 | Cancelled |

### Question 1: Active subscriptions at the end of each month in 2023

_Write a query to find the number of active subscriptions at the end of each month in the year 2023. An active subscription for a month means its `start_date` is on or before the last day of the month, and its `end_date` is either `NULL` or after the last day of the month._

**Solution:**

```sql
WITH Months AS (
    -- Hardcode or generate the last day of each month in 2023
    SELECT CAST('2023-01-31' AS DATE) AS month_end_date UNION ALL
    SELECT CAST('2023-02-28' AS DATE) UNION ALL
    SELECT CAST('2023-03-31' AS DATE) UNION ALL
    SELECT CAST('2023-04-30' AS DATE) UNION ALL
    SELECT CAST('2023-05-31' AS DATE) UNION ALL
    SELECT CAST('2023-06-30' AS DATE) UNION ALL
    SELECT CAST('2023-07-31' AS DATE) UNION ALL
    SELECT CAST('2023-08-31' AS DATE) UNION ALL
    SELECT CAST('2023-09-30' AS DATE) UNION ALL
    SELECT CAST('2023-10-31' AS DATE) UNION ALL
    SELECT CAST('2023-11-30' AS DATE) UNION ALL
    SELECT CAST('2023-12-31' AS DATE)
)
SELECT
    m.month_end_date,
    COUNT(s.sub_id) AS active_subscriptions
FROM
    Months m
LEFT JOIN
    Subscriptions s
    ON s.start_date <= m.month_end_date
    AND (s.end_date IS NULL OR s.end_date > m.month_end_date)
GROUP BY
    m.month_end_date
ORDER BY
    m.month_end_date;
```

**Why this works:** We create a set of reference dates (the end of each month) using a CTE. Then, we use a Non-Equi JOIN to match each month's end date against subscriptions that were valid at that point in time. We then count the subscriptions per month.

---

## Problem 6: Recursive CTE (Organizational Hierarchy)

### Table: Employees (Reused from Problem 2)

### Question 1: Find the organizational hierarchy using Recursive CTE

_Write a query using a Recursive CTE to find the organizational hierarchy. Return the `employee_id`, `name`, their hierarchy `level` (where the top-level manager/CEO is Level 1), and their management `path`._

**Solution:**

```sql
WITH RecursiveCTE AS (
    -- Anchor member: Select the top-level managers (where manager_id is NULL)
    SELECT
        employee_id,
        name,
        manager_id,
        1 AS level,
        CAST(name AS VARCHAR(1000)) AS path
    FROM
        Employees
    WHERE
        manager_id IS NULL

    UNION ALL

    -- Recursive member: Join the CTE to the Employees table to find direct reports
    SELECT
        e.employee_id,
        e.name,
        e.manager_id,
        r.level + 1,
        CAST(r.path + ' > ' + e.name AS VARCHAR(1000))
    FROM
        Employees e
    INNER JOIN
        RecursiveCTE r ON e.manager_id = r.employee_id
)
SELECT
    employee_id,
    name,
    level,
    path
FROM
    RecursiveCTE
ORDER BY
    path;
```

**Why this works:** Recursive CTEs have two parts separated by a `UNION ALL`. The first part (Anchor) gets the starting point (e.g., the CEOs). The second part (Recursive) joins the original table back to the CTE itself. It keeps looping, taking the employees from the previous step and finding _their_ direct reports, incrementing the `level` and appending the `name` to the `path` string until no more direct reports are found.

---

## Problem 7: PIVOT Operator

### Table: EmployeeSkills

| employee_id | skill_name | proficiency |
| :---------- | :--------- | :---------- |
| 1           | SQL        | 5           |
| 1           | Python     | 4           |
| 2           | SQL        | 3           |
| 2           | Python     | 5           |
| 2           | PowerBI    | 4           |
| 3           | PowerBI    | 5           |

### Question 1: Pivot the skills table

_Write a query using the `PIVOT` operator to transform the table so that each `employee_id` has exactly one row, with columns for `SQL`, `Python`, and `PowerBI` showing their proficiency. If they don't have the skill, the value should be `NULL`._

**Solution:**

```sql
SELECT
    employee_id,
    [SQL],
    [Python],
    [PowerBI]
FROM
    (SELECT employee_id, skill_name, proficiency FROM EmployeeSkills) AS SourceTable
PIVOT
(
    MAX(proficiency)
    FOR skill_name IN ([SQL], [Python], [PowerBI])
) AS PivotTable;
```

**Why this works:** The `PIVOT` operator rotates data from rows into columns. It requires a Source Table (subquery selecting only the needed columns), an Aggregate Function (`MAX` in this case), and a `FOR ... IN` clause defining which values from the row-level column (`skill_name`) should become actual column headers.

---

## Problem 8: Bill of Materials (Recursive CTE)

### Table: BillOfMaterials

**Scenario:** You work for a manufacturing company. The table below shows which components are required to build a parent product. A "Bicycle" requires a "Wheel Assembly", and a "Wheel Assembly" requires "Tires" and "Spokes".

| ComponentID | ComponentName  | ParentComponentID | QuantityRequired |
| :---------- | :------------- | :---------------- | :--------------- |
| 1           | Bicycle        | NULL              | 1                |
| 2           | Wheel Assembly | 1                 | 2                |
| 3           | Frame          | 1                 | 1                |
| 4           | Tire           | 2                 | 1                |
| 5           | Rim            | 2                 | 1                |
| 6           | Spoke          | 2                 | 36               |
| 7           | Handlebar      | 1                 | 1                |
| 8           | Grip           | 7                 | 2                |
| 9           | Brake Cable    | 7                 | 2                |

### Question 1: Total components needed for a Bicycle

_Write a query using a **Recursive CTE** to find ALL components needed to build a **'Bicycle' (ComponentID = 1)**. Your output should traverse down the hierarchy and calculate the **total quantity needed** for each component to build the entire bicycle. Return the `ComponentID`, `ComponentName`, `Level`, and `TotalQuantityNeeded`._

**Solution:**

```sql
WITH BOM_CTE AS (
    -- 1. Anchor Member: Start with the final product (Bicycle, ComponentID = 1)
    SELECT
        ComponentID,
        ComponentName,
        ParentComponentID,
        1 AS Level,
        QuantityRequired AS TotalQuantityNeeded
    FROM
        BillOfMaterials
    WHERE
        ComponentID = 1 -- The top-level parent

    UNION ALL

    -- 2. Recursive Member: Join children to their parents
    SELECT
        child.ComponentID,
        child.ComponentName,
        child.ParentComponentID,
        parent.Level + 1 AS Level,
        -- Multiply the parent's total quantity by the child's required quantity
        (parent.TotalQuantityNeeded * child.QuantityRequired) AS TotalQuantityNeeded
    FROM
        BillOfMaterials child
    INNER JOIN
        BOM_CTE parent ON child.ParentComponentID = parent.ComponentID
)
SELECT
    ComponentID,
    ComponentName,
    Level,
    TotalQuantityNeeded
FROM
    BOM_CTE
ORDER BY
    Level, ComponentID;
```

**Why this works:** The Anchor starts strictly with the Bicycle. The Recursive Join connects the raw `BillOfMaterials` table (child) back to the `BOM_CTE` (parent). To find the true total quantity needed (e.g., total spokes), we multiply the child's base requirement (36) by the parent's total requirement (2 Wheels).

---

## Problem 9: Advanced Gaps and Islands

### Table: ServerStatusLogs

**Scenario:** You have a table logging the status of a server ('Online' or 'Offline') over time. The status is logged sporadically.

| log_id | server_id | status  | log_time            |
| :----- | :-------- | :------ | :------------------ |
| 1      | Server_A  | Online  | 2023-10-01 10:00:00 |
| 2      | Server_A  | Online  | 2023-10-01 10:15:00 |
| 3      | Server_A  | Offline | 2023-10-01 10:30:00 |
| 4      | Server_A  | Offline | 2023-10-01 10:45:00 |
| 5      | Server_A  | Offline | 2023-10-01 11:00:00 |
| 6      | Server_A  | Online  | 2023-10-01 11:15:00 |
| 7      | Server_B  | Online  | 2023-10-01 10:00:00 |
| 8      | Server_B  | Offline | 2023-10-01 10:10:00 |

### Question 1: Group consecutive identical statuses into "sessions"

_Write a query to group consecutive identical statuses into single "sessions" for each server. Your result should return the `server_id`, the `status`, the `start_time` of that continuous status block, and the `end_time` of that status block._

**Solution (Difference of Row Numbers Method):**

```sql
WITH RankedLogs AS (
    SELECT
        server_id,
        status,
        log_time,
        -- Sequence 1: Row number partitioned by server_id only
        ROW_NUMBER() OVER(PARTITION BY server_id ORDER BY log_time) AS rn_total,
        -- Sequence 2: Row number partitioned by server_id AND status
        ROW_NUMBER() OVER(PARTITION BY server_id, status ORDER BY log_time) AS rn_status
    FROM
        ServerStatusLogs
),
GroupedSessions AS (
    SELECT
        server_id,
        status,
        log_time,
        -- The difference between the two sequences creates a unique "Island ID"
        (rn_total - rn_status) AS island_id
    FROM
        RankedLogs
)
SELECT
    server_id,
    status,
    MIN(log_time) AS start_time,
    MAX(log_time) AS end_time
FROM
    GroupedSessions
GROUP BY
    server_id,
    status,
    island_id
ORDER BY
    server_id,
    start_time;
```

**Why this works:** Because `rn_total` and `rn_status` both increase by 1 for every row within a continuous block of the same status, their difference (`rn_total - rn_status`) remains constant. The moment the status changes, `rn_status` jumps to a different sequence, generating a new constant difference. This creates a perfect unique `island_id`.

**Alternative Solution (LAG Method):**

```sql
WITH LaggedLogs AS (
    SELECT
        server_id,
        status,
        log_time,
        LAG(status) OVER(PARTITION BY server_id ORDER BY log_time) AS prev_status
    FROM
        ServerStatusLogs
),
FlaggedChanges AS (
    SELECT
        server_id,
        status,
        log_time,
        -- If status changed, flag it as 1 to indicate a new island started.
        CASE
            WHEN status <> prev_status OR prev_status IS NULL THEN 1
            ELSE 0
        END AS is_new_island
    FROM
        LaggedLogs
),
GroupedSessions AS (
    SELECT
        server_id,
        status,
        log_time,
        -- A running sum of the flags creates a unique sequential ID
        SUM(is_new_island) OVER(PARTITION BY server_id ORDER BY log_time) AS island_id
    FROM
        FlaggedChanges
)
SELECT
    server_id,
    status,
    MIN(log_time) AS start_time,
    MAX(log_time) AS end_time
FROM
    GroupedSessions
GROUP BY
    server_id,
    status,
    island_id
ORDER BY
    server_id,
    start_time;
```

---

## Problem 10: Median Salary by Department (Hard)

### Table: EmployeeSalaries

**Scenario:** SQL Server has no native `MEDIAN()` function. You must derive it from first principles using window functions.

| emp_id | name         | department  | salary |
| :----- | :----------- | :---------- | :----- |
| 1      | Alice Turner | Engineering | 90000  |
| 2      | Bob Chen     | Engineering | 110000 |
| 3      | Carol White  | Engineering | 95000  |
| 4      | David Kim    | Engineering | 80000  |
| 5      | Eva Green    | Engineering | 105000 |
| 6      | Frank Lopez  | Sales       | 55000  |
| 7      | Grace Hall   | Sales       | 60000  |
| 8      | Henry Scott  | Sales       | 55000  |
| 9      | Isla Brown   | Sales       | 72000  |

### Question 1: Find the median salary for each department

_SQL Server has no `MEDIAN()` function. Write a query to calculate the median salary for each department without using any aggregate functions other than `AVG`. Your result should return `department` and `median_salary`._

**Solution:**

```sql
WITH RankedSalaries AS (
    SELECT
        department,
        salary,
        -- Rank ascending: assigns 1 to lowest salary per dept
        ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary ASC)  AS rn_asc,
        -- Rank descending: assigns 1 to highest salary per dept
        ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS rn_desc
    FROM EmployeeSalaries
)
SELECT
    department,
    -- For odd count: rn_asc = rn_desc (the exact middle row)
    -- For even count: rn_asc and rn_desc overlap by 1 (the two middle rows)
    -- AVG of those rows gives the correct median in both cases
    AVG(CAST(salary AS DECIMAL(10,2))) AS median_salary
FROM RankedSalaries
WHERE ABS(rn_asc - rn_desc) <= 1  -- The two-pointer overlap condition
GROUP BY department
ORDER BY department;
```

**Why this works:** The key insight is the **two-pointer trick**. We assign both an ascending and descending rank to every salary within each department.

- For an **odd** number of rows (e.g., 5 rows), the true middle row will have the exact same rank from both directions (`rn_asc = 3, rn_desc = 3`). The difference is `0`.
- For an **even** number of rows (e.g., 4 rows), there is no single middle row. The two middle rows will have ranks that are exactly 1 apart (`rn_asc = 2, rn_desc = 3` and `rn_asc = 3, rn_desc = 2`). The absolute difference is `1`.
- The `WHERE ABS(rn_asc - rn_desc) <= 1` condition perfectly captures the single middle row in the odd case (diff 0), and both middle rows in the even case (diff 1). `AVG()` then computes the final median correctly.

---

## Problem 11: Nth Highest Salary (Hard)

### Table: EmployeeSalaries (Reused from Problem 10)

### Question 1: Write a stored procedure to find the Nth highest distinct salary

_This is a classic HackerRank problem. Write a **reusable stored procedure** (or a parameterized query) that accepts an integer `N` and returns the Nth highest **distinct** salary from the `EmployeeSalaries` table. If `N` is larger than the number of distinct salaries, return `NULL`._

**Solution (Stored Procedure with DENSE_RANK):**

```sql
CREATE PROCEDURE GetNthHighestSalary
    @N INT
AS
BEGIN
    -- Guard against invalid input
    IF @N <= 0
    BEGIN
        SELECT CAST(NULL AS DECIMAL(10,2)) AS NthHighestSalary;
        RETURN;
    END

    WITH RankedSalaries AS (
        SELECT
            salary,
            DENSE_RANK() OVER (ORDER BY salary DESC) AS salary_rank
        FROM EmployeeSalaries
    )
    SELECT TOP 1
        CAST(salary AS DECIMAL(10,2)) AS NthHighestSalary
    FROM RankedSalaries
    WHERE salary_rank = @N;
    -- Returns NULL automatically if no row matches (N is too large)
END;

-- Test: 2nd highest salary
EXEC GetNthHighestSalary @N = 2;
```

**Alternative (Inline Query using OFFSET-FETCH):**

```sql
DECLARE @N INT = 2;

SELECT DISTINCT salary AS NthHighestSalary
FROM EmployeeSalaries
ORDER BY salary DESC
OFFSET (@N - 1) ROWS
FETCH NEXT 1 ROWS ONLY;
```

**Why this works (DENSE_RANK approach):** Using `DENSE_RANK()` rather than `ROW_NUMBER()` is critical. If two employees share the highest salary (e.g., $110,000), `ROW_NUMBER()` would arbitrarily assign them ranks 1 and 2, making the "2nd highest" incorrect. `DENSE_RANK()` gives both the same rank of 1, so the true 2nd distinct salary correctly receives rank 2.

**Why OFFSET-FETCH works:** `OFFSET (@N - 1) ROWS` skips the first N-1 results, and `FETCH NEXT 1 ROWS ONLY` grabs the next one. Using `SELECT DISTINCT` first ensures we're skipping over duplicate salaries to find the Nth **unique** value.

---

## Problem 12: Dynamic PIVOT with STRING_AGG (Hard)

### Tables: SalesQuarterly

**Scenario:** Your product list is dynamic — new products are added constantly. A static `PIVOT` would break every time a new product appears. Build a solution that works regardless of how many products exist.

| sale_year | product_name | total_revenue |
| :-------- | :----------- | :------------ |
| 2022      | Laptop       | 150000        |
| 2022      | Monitor      | 80000         |
| 2022      | Keyboard     | 25000         |
| 2023      | Laptop       | 175000        |
| 2023      | Monitor      | 95000         |
| 2023      | Keyboard     | 30000         |
| 2023      | Webcam       | 40000         |

### Question 1: Pivot product revenues by year — dynamically

_Write a query that pivots the `SalesQuarterly` table so each row is a `sale_year` and each column is a unique `product_name`. Since new products are added regularly, the solution must generate the column list **dynamically at runtime** using Dynamic SQL._

**Solution:**

```sql
DECLARE @cols    NVARCHAR(MAX);
DECLARE @sql     NVARCHAR(MAX);

-- Step 1: Build the column list dynamically using STRING_AGG
-- This generates: [Keyboard], [Laptop], [Monitor], [Webcam]
SELECT @cols = STRING_AGG(QUOTENAME(product_name), ', ')
               WITHIN GROUP (ORDER BY product_name)
FROM (SELECT DISTINCT product_name FROM SalesQuarterly) AS products;

-- Step 2: Inject the dynamic column list into the PIVOT query
SET @sql = N'
    SELECT sale_year, ' + @cols + N'
    FROM (
        SELECT sale_year, product_name, total_revenue
        FROM SalesQuarterly
    ) AS SourceTable
    PIVOT (
        SUM(total_revenue)
        FOR product_name IN (' + @cols + N')
    ) AS PivotTable
    ORDER BY sale_year;
';

-- Step 3: Execute safely using sp_executesql
EXEC sp_executesql @sql;
```

**Expected Output:**
| sale_year | Keyboard | Laptop | Monitor | Webcam |
| :-------- | :------- | :----- | :------ | :----- |
| 2022 | 25000 | 150000 | 80000 | NULL |
| 2023 | 30000 | 175000 | 95000 | 40000 |

**Why this works:** A static `PIVOT` requires column names hardcoded inside `IN (...)`. The moment a new product (`Webcam`) is added, a static query will silently miss it. The Dynamic SQL approach has three steps: **Step 1** uses `STRING_AGG` with `QUOTENAME()` (which wraps each name in `[]` to safely handle spaces/special characters) to build a comma-separated column string at runtime. **Step 2** injects that string into both the `SELECT` and the `FOR ... IN` clause. **Step 3** uses `sp_executesql` (not `EXEC()`) which is the secure, parameterizable way to execute dynamic SQL — it prevents SQL injection risks.

---

## Problem 13: Implementing SCD Type 2 with MERGE (Hard)

### Tables: DimCustomer (Target) & CustomerStaging (Source)

**Scenario:** This is a real-world enterprise ETL pattern. Your nightly pipeline loads new customer data into a staging table. You must synchronize the production dimension table using a full **SCD Type 2** implementation — preserving history by expiring old rows and inserting new ones, while updating unchanged rows where necessary.

**DimCustomer (Target — the production dimension):**
| CustomerKey | CustomerID | CustomerName | Email | IsActive | EffectiveDate | ExpiryDate |
| :---------- | :--------- | :-------------- | :----------------------- | :------- | :------------ | :--------- |
| 1 | C001 | Alice Johnson | alice@old.com | 1 | 2023-01-01 | 9999-12-31 |
| 2 | C002 | Bob Smith | bob@company.com | 1 | 2023-01-01 | 9999-12-31 |
| 3 | C003 | Carol Williams | carol@company.com | 1 | 2023-03-15 | 9999-12-31 |

**CustomerStaging (Source — today's fresh data from source system):**
| CustomerID | CustomerName | Email |
| :--------- | :-------------- | :----------------------- |
| C001 | Alice Johnson | alice@new.com |
| C002 | Bob Smith | bob@company.com |
| C004 | David Brown | david@company.com |

> **Changes:** `C001`'s email changed (needs SCD2 new row). `C002` is unchanged. `C003` is gone (deleted from source). `C004` is brand new.

### Question 1: Implement a full SCD Type 2 load using MERGE

_Write a T-SQL script that implements a complete SCD Type 2 pattern. It must: (1) **Expire** old `DimCustomer` rows where data has changed, (2) **Insert** new versioned rows for changed records, (3) **Insert** brand new customers, and (4) **Expire** customers that no longer exist in the source._

**Solution:**

```sql
DECLARE @Today DATE = CAST(GETDATE() AS DATE);

-- ============================================================
-- STEP 1: Expire rows where tracked attributes have changed
-- We cannot use MERGE for this step cleanly.
-- We UPDATE the existing active row to set its ExpiryDate = today.
-- ============================================================
UPDATE dim
SET
    dim.IsActive    = 0,
    dim.ExpiryDate  = @Today
FROM DimCustomer dim
INNER JOIN CustomerStaging stg
    ON dim.CustomerID = stg.CustomerID
WHERE
    dim.IsActive = 1
    AND dim.ExpiryDate = '9999-12-31'
    AND (
        dim.CustomerName <> stg.CustomerName
        OR dim.Email     <> stg.Email
    );

-- ============================================================
-- STEP 2: Use MERGE with HOLDLOCK to safely handle
--         new records (inserts) and deleted source records (expires).
-- ============================================================
MERGE INTO DimCustomer WITH (HOLDLOCK) AS Target
USING CustomerStaging AS Source
ON Target.CustomerID = Source.CustomerID
   AND Target.IsActive = 1

-- Case 1: Record exists in both — attribute is unchanged, do nothing (no UPDATE needed)
-- Case 2: WHEN NOT MATCHED BY TARGET — brand new customer OR re-insert after expiry
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CustomerID, CustomerName, Email, IsActive, EffectiveDate, ExpiryDate)
    VALUES (
        Source.CustomerID,
        Source.CustomerName,
        Source.Email,
        1,
        @Today,
        '9999-12-31'
    )

-- Case 3: Customer exists in DimCustomer (active) but NOT in today's source — expire it
WHEN NOT MATCHED BY SOURCE AND Target.IsActive = 1 THEN
    UPDATE SET
        Target.IsActive   = 0,
        Target.ExpiryDate = @Today;

-- ============================================================
-- STEP 3: Insert new active rows for the records we expired in Step 1
-- (These are the "changed attribute" rows that need a new history entry)
-- ============================================================
INSERT INTO DimCustomer (CustomerID, CustomerName, Email, IsActive, EffectiveDate, ExpiryDate)
SELECT
    stg.CustomerID,
    stg.CustomerName,
    stg.Email,
    1,
    @Today,
    '9999-12-31'
FROM CustomerStaging stg
INNER JOIN DimCustomer dim
    ON stg.CustomerID = dim.CustomerID
WHERE
    dim.IsActive   = 0          -- The row was just expired in Step 1
    AND dim.ExpiryDate = @Today; -- Confirms it was expired TODAY (not historically)
```

**Expected Result After Script Runs (DimCustomer):**
| CustomerKey | CustomerID | CustomerName | Email | IsActive | EffectiveDate | ExpiryDate |
| :---------- | :--------- | :------------- | :-------------- | :------- | :------------ | :--------- |
| 1 | C001 | Alice Johnson | alice@old.com | **0** | 2023-01-01 | **Today** |
| 2 | C002 | Bob Smith | bob@company.com | 1 | 2023-01-01 | 9999-12-31 |
| 3 | C003 | Carol Williams | carol@company.com | **0** | 2023-03-15 | **Today** |
| 4 _(new)_ | C001 | Alice Johnson | alice@new.com | **1** | **Today** | 9999-12-31 |
| 5 _(new)_ | C004 | David Brown | david@company.com | **1** | **Today** | 9999-12-31 |

**Why this works (3-Step pattern):** A single `MERGE` cannot cleanly implement SCD2 because the "changed attribute" case requires **two** DML operations per row: an `UPDATE` to expire the old row, and an `INSERT` to create the new version. T-SQL's `MERGE` only allows one action per matched row. The professional solution separates this into 3 steps: (1) **Expire changed rows** using a targeted `UPDATE JOIN`. (2) **Use MERGE** only for the clean cases: inserting new customers and expiring deleted ones. The `WITH (HOLDLOCK)` hint is mandatory to prevent race condition deadlocks in concurrent ETL environments. (3) **Re-insert new versions** of the changed rows by finding records that were just expired today.

---

## Problem 14: Period-over-Period Analysis with LEAD & LAG

### Table: MonthlyRevenue

**Scenario:** A BI developer is often asked to build reports showing month-over-month or year-over-year growth. This problem tests your ability to use `LAG` and `LEAD` for business reporting.

| revenue_id | region | report_month | revenue |
| :--------- | :----- | :----------- | :------ |
| 1          | North  | 2023-01-01   | 120000  |
| 2          | North  | 2023-02-01   | 135000  |
| 3          | North  | 2023-03-01   | 128000  |
| 4          | North  | 2023-04-01   | 142000  |
| 5          | South  | 2023-01-01   | 90000   |
| 6          | South  | 2023-02-01   | 87000   |
| 7          | South  | 2023-03-01   | 95000   |
| 8          | South  | 2023-04-01   | 101000  |

### Question 1: Calculate month-over-month revenue change

_Write a query to return `region`, `report_month`, `revenue`, the `previous_month_revenue`, the absolute `mom_change`, and the `mom_pct_change` (rounded to 2 decimal places). If there is no previous month for a region, those columns should be `NULL`._

**Solution:**

```sql
SELECT
    region,
    report_month,
    revenue,
    LAG(revenue) OVER (PARTITION BY region ORDER BY report_month) AS previous_month_revenue,
    revenue - LAG(revenue) OVER (PARTITION BY region ORDER BY report_month) AS mom_change,
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (PARTITION BY region ORDER BY report_month))
             / NULLIF(LAG(revenue) OVER (PARTITION BY region ORDER BY report_month), 0),
        2
    ) AS mom_pct_change
FROM
    MonthlyRevenue
ORDER BY
    region, report_month;
```

**Why this works:** `LAG(revenue) OVER (PARTITION BY region ORDER BY report_month)` fetches the previous row's `revenue` within the same region. For the first month per region it returns `NULL`, which correctly propagates to the change columns. `NULLIF(..., 0)` in the denominator prevents division-by-zero errors. Wrapping the whole expression in `ROUND()` keeps the percentage clean.

### Question 2: Flag months where revenue declined versus the same month last year

_You now have two years of data (2022 and 2023). Write a query to identify months in 2023 where revenue **declined** compared to the same calendar month in 2022. Return `region`, `report_month`, `revenue_2023`, `revenue_2022`, and `yoy_change`._

**Extended table (add these rows for the question):**
| revenue_id | region | report_month | revenue |
| :--------- | :----- | :----------- | :------ |
| 9 | North | 2022-01-01 | 115000 |
| 10 | North | 2022-02-01 | 130000 |
| 11 | North | 2022-03-01 | 131000 |
| 12 | North | 2022-04-01 | 143000 |

**Solution:**

```sql
WITH YearlyPivot AS (
    SELECT
        region,
        report_month,
        revenue,
        YEAR(report_month)  AS yr,
        MONTH(report_month) AS mn
    FROM MonthlyRevenue
)
SELECT
    y23.region,
    y23.report_month,
    y23.revenue AS revenue_2023,
    y22.revenue AS revenue_2022,
    y23.revenue - y22.revenue AS yoy_change
FROM
    YearlyPivot y23
JOIN
    YearlyPivot y22
    ON  y23.region = y22.region
    AND y23.mn     = y22.mn
    AND y23.yr     = 2023
    AND y22.yr     = 2022
WHERE
    y23.revenue < y22.revenue   -- Only declining months
ORDER BY
    y23.region, y23.report_month;
```

**Why this works:** We self-join `MonthlyRevenue` on the same `region` and calendar `MONTH`, aligning 2023 rows with their 2022 counterpart. The `WHERE` clause filters to rows where 2023 revenue is lower, isolating the declines. This is a very common pattern in BI reporting for YoY variance analysis.

---

## Problem 15: Scalar UDFs & Inline Table-Valued Functions

### Scenario

_The interview prep guide mentions scalar UDFs and table-valued functions. This problem tests your ability to encapsulate reusable business logic._

### Question 1: Create a scalar UDF to calculate age in years

_Write a **scalar UDF** called `dbo.fn_GetAgeInYears` that accepts a `@DateOfBirth DATE` parameter and returns the person's current age as an `INT`. Handle the edge case where the birthday hasn't occurred yet this year._

**Solution:**

```sql
CREATE FUNCTION dbo.fn_GetAgeInYears
(
    @DateOfBirth DATE
)
RETURNS INT
AS
BEGIN
    DECLARE @Age INT;

    SET @Age = DATEDIFF(year, @DateOfBirth, GETDATE())
               -- Subtract 1 if birthday hasn't happened yet this calendar year
             - CASE
                   WHEN MONTH(@DateOfBirth) > MONTH(GETDATE()) THEN 1
                   WHEN MONTH(@DateOfBirth) = MONTH(GETDATE())
                    AND DAY(@DateOfBirth)   > DAY(GETDATE())  THEN 1
                   ELSE 0
               END;

    RETURN @Age;
END;

-- Usage
SELECT dbo.fn_GetAgeInYears('1990-11-25') AS Age; -- Returns 34 (as of May 2025)
```

**Why this works:** `DATEDIFF(year, ...)` gives the raw year difference but doesn't account for whether the birthday has occurred yet in the current year. The `CASE` expression checks whether the birth month/day is still in the future this year and subtracts 1 if so, giving the precise age.

### Question 2: Create an inline table-valued function (iTVF) for active employees by department

_Write an **inline TVF** called `dbo.fn_GetActiveEmployeesByDept` that accepts `@DepartmentId INT` and returns a table of active employees (from the `Employees` table in Problem 2). Explain why an iTVF is preferred over a multi-statement TVF for performance._

**Solution:**

```sql
CREATE FUNCTION dbo.fn_GetActiveEmployeesByDept
(
    @DepartmentId INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        employee_id,
        name,
        salary,
        department_id,
        manager_id
    FROM
        Employees
    WHERE
        department_id = @DepartmentId
);

-- Usage: treat it like a parameterised view
SELECT * FROM dbo.fn_GetActiveEmployeesByDept(1);

-- Can also be used in joins (a key advantage over scalar UDFs)
SELECT
    e.employee_id,
    e.name,
    e.salary
FROM
    dbo.fn_GetActiveEmployeesByDept(1) AS e
WHERE
    e.salary > 5000;
```

**Why iTVF is preferred over multi-statement TVF:** An **inline TVF** (`RETURNS TABLE AS RETURN (single SELECT)`) is essentially a **parameterised view** — the query optimizer can look _inside_ it, push predicates down, and use indexes efficiently. A **multi-statement TVF** (using `BEGIN...END` with a declared table variable) is opaque to the optimizer; it must fully populate the table variable before the caller's query can filter it, which is dramatically slower on large datasets.

---

## Problem 16: Temp Tables vs CTEs

### Scenario

_The interview prep guide lists "Temp tables (global, local) vs CTEs" as a key topic. This problem tests your conceptual and practical understanding._

### Question 1: Conceptual — when to use each?

_Explain the difference between a **local temp table** (`#temp`), a **global temp table** (`##temp`), and a **CTE**. When would you choose one over the other in an ETL pipeline?_

**Answer:**

| Feature             | CTE                                           | `#temp` (Local Temp Table)                                              | `##temp` (Global Temp Table)           |
| :------------------ | :-------------------------------------------- | :---------------------------------------------------------------------- | :------------------------------------- |
| Scope               | Single query/statement only                   | Current session only                                                    | All sessions until creator disconnects |
| Persistence         | Disappears after query ends                   | Dropped when session ends (or explicitly)                               | Dropped when all sessions close        |
| Indexable           | No                                            | **Yes** — can add indexes                                               | **Yes** — can add indexes              |
| Statistics          | No                                            | **Yes** — optimizer uses them                                           | **Yes**                                |
| Reusable in session | No — must re-define each time                 | **Yes**                                                                 | **Yes**                                |
| Best use case       | Readable, single-use logic; recursive queries | Multi-step ETL, intermediate staging, large result sets needing indexes | Cross-session sharing (rare)           |

**Rule of thumb for ETL:**

- Use a **CTE** when the intermediate result is small, used once, and readability is the goal.
- Use a **`#temp` table** when: the result set is large (>10k rows), you need to join it multiple times, or you need to add an index to speed up a subsequent join.
- **Never** use `##global temp tables` in concurrent ETL — two pipeline sessions will collide on the same table name.

### Question 2: Practical — rewrite a slow nested subquery using a temp table

_The following query is slow because the subquery in the `WHERE` clause is evaluated for every row. Rewrite it using a local temp table to materialise the result first._

**Slow original query:**

```sql
-- Anti-pattern: correlated subquery runs once per outer row
SELECT
    e.employee_id,
    e.name,
    e.salary
FROM Employees e
WHERE e.salary > (
    SELECT AVG(salary)
    FROM Employees
    WHERE department_id = e.department_id  -- correlated!
);
```

**Rewrite using a temp table:**

```sql
-- Step 1: Materialise the per-department average once
SELECT
    department_id,
    AVG(CAST(salary AS DECIMAL(10,2))) AS avg_dept_salary
INTO #DeptAvg
FROM Employees
GROUP BY department_id;

-- Optional but recommended: index the join column
CREATE INDEX IX_DeptAvg_DeptId ON #DeptAvg (department_id);

-- Step 2: Simple join — no repeated subquery execution
SELECT
    e.employee_id,
    e.name,
    e.salary
FROM Employees e
JOIN #DeptAvg d ON e.department_id = d.department_id
WHERE e.salary > d.avg_dept_salary;

-- Clean up
DROP TABLE #DeptAvg;
```

**Why this works:** The correlated subquery forces SQL Server to recalculate the average for every single employee row. Materialising the result into a `#temp` table runs the average calculation **once per department**. The index on `department_id` then makes the join fast.

---

## Problem 17: ETL Data Validation & Row-Count Reconciliation

### Scenario

_A core responsibility of a BI/ETL developer is to validate that data moved correctly between systems. This problem simulates a common "end-to-end ETL validation" task._

### Tables

**SourceOrders (the upstream system extract):**
| order_id | customer_id | order_date | amount | status |
| :------- | :---------- | :--------- | :----- | :------- |
| 1001 | C01 | 2023-10-01 | 500 | Complete |
| 1002 | C02 | 2023-10-01 | 300 | Complete |
| 1003 | C03 | 2023-10-02 | 750 | Pending |
| 1004 | C01 | 2023-10-02 | 200 | Complete |
| 1005 | C04 | 2023-10-03 | 420 | Complete |

**TargetOrders (the data warehouse load):**
| order_id | customer_id | order_date | amount | status |
| :------- | :---------- | :--------- | :----- | :------- |
| 1001 | C01 | 2023-10-01 | 500 | Complete |
| 1002 | C02 | 2023-10-01 | **350**| Complete |
| 1004 | C01 | 2023-10-02 | 200 | Complete |
| 1005 | C04 | 2023-10-03 | 420 | Complete |

> **Issues:** `1003` is missing entirely. `1002` has an incorrect `amount`.

### Question 1: Write a reconciliation query to find all discrepancies

_Write a single T-SQL query that compares `SourceOrders` and `TargetOrders` and returns a report of all discrepancies. The result should identify: (1) rows missing from the target, (2) rows in the target not in the source (orphans), and (3) rows present in both but with mismatched column values. Include a `discrepancy_type` column._

**Solution:**

```sql
-- 1. Missing from Target (in source but not in target)
SELECT
    s.order_id,
    'Missing from Target' AS discrepancy_type,
    s.customer_id     AS src_customer_id, NULL AS tgt_customer_id,
    s.order_date      AS src_order_date,  NULL AS tgt_order_date,
    s.amount          AS src_amount,      NULL AS tgt_amount,
    s.status          AS src_status,      NULL AS tgt_status
FROM SourceOrders s
LEFT JOIN TargetOrders t ON s.order_id = t.order_id
WHERE t.order_id IS NULL

UNION ALL

-- 2. Orphan in Target (in target but not in source)
SELECT
    t.order_id,
    'Orphan in Target',
    NULL, t.customer_id,
    NULL, t.order_date,
    NULL, t.amount,
    NULL, t.status
FROM TargetOrders t
LEFT JOIN SourceOrders s ON t.order_id = s.order_id
WHERE s.order_id IS NULL

UNION ALL

-- 3. Data mismatch (exists in both but values differ)
SELECT
    s.order_id,
    'Data Mismatch',
    s.customer_id, t.customer_id,
    s.order_date,  t.order_date,
    s.amount,      t.amount,
    s.status,      t.status
FROM SourceOrders s
JOIN TargetOrders t ON s.order_id = t.order_id
WHERE
    s.customer_id <> t.customer_id
    OR s.order_date <> t.order_date
    OR s.amount     <> t.amount
    OR s.status     <> t.status

ORDER BY discrepancy_type, order_id;
```

**Expected Output:**
| order_id | discrepancy_type | src_amount | tgt_amount |
| :------- | :------------------- | :--------- | :--------- |
| 1002 | Data Mismatch | 300 | 350 |
| 1003 | Missing from Target | 750 | NULL |

**Why this works:** Three separate `SELECT` blocks cover the three possible reconciliation failure modes, combined with `UNION ALL` into a single scannable report. `LEFT JOIN ... WHERE t.order_id IS NULL` is the standard pattern for finding missing rows. The mismatch block uses an `INNER JOIN` to confirm both sides exist, then compares each tracked column. In production ETL, this pattern is typically wrapped in a stored procedure and its results written to an audit/reconciliation table.

### Question 2: Write a summary validation report using aggregates

_Write a query that produces a single-row summary comparing the two tables side by side: total row count, distinct customer count, and total amount. This is the "control total" check._

**Solution:**

```sql
SELECT
    (SELECT COUNT(*)          FROM SourceOrders) AS src_row_count,
    (SELECT COUNT(*)          FROM TargetOrders) AS tgt_row_count,
    (SELECT COUNT(DISTINCT customer_id) FROM SourceOrders) AS src_distinct_customers,
    (SELECT COUNT(DISTINCT customer_id) FROM TargetOrders) AS tgt_distinct_customers,
    (SELECT SUM(amount)       FROM SourceOrders) AS src_total_amount,
    (SELECT SUM(amount)       FROM TargetOrders) AS tgt_total_amount,
    -- Derived: are the counts and totals matching?
    CASE WHEN (SELECT COUNT(*) FROM SourceOrders) = (SELECT COUNT(*) FROM TargetOrders) THEN 'PASS' ELSE 'FAIL' END AS row_count_check,
    CASE WHEN (SELECT SUM(amount) FROM SourceOrders) = (SELECT SUM(amount) FROM TargetOrders) THEN 'PASS' ELSE 'FAIL' END AS total_amount_check;
```

**Why this works:** Control-total checks are the fastest validation gate in any ETL pipeline. Before comparing row-by-row, always check the aggregate counts and sums first — a discrepancy here immediately flags a problem without the cost of a full row-level join.

---

## Problem 18: Star Schema Queries (Fact + Dimension Joins)

### Scenario

_Data Warehousing is a key topic in the interview. This problem simulates a classic star-schema reporting query — the bread and butter of BI development._

### Tables

**FactSales:**
| sale_key | date_key | product_key | customer_key | store_key | quantity | unit_price | discount |
| :------- | :------- | :---------- | :----------- | :-------- | :------- | :--------- | :------- |
| 1 | 20231001 | 101 | 501 | 10 | 2 | 1500 | 0.10 |
| 2 | 20231001 | 102 | 502 | 10 | 1 | 800 | 0.00 |
| 3 | 20231015 | 101 | 501 | 20 | 1 | 1500 | 0.05 |
| 4 | 20231201 | 103 | 503 | 10 | 3 | 200 | 0.00 |
| 5 | 20231201 | 102 | 502 | 20 | 2 | 800 | 0.15 |

**DimDate:**
| date_key | full_date | year | quarter | month | month_name |
| :------- | :--------- | :--- | :------ | :---- | :--------- |
| 20231001 | 2023-10-01 | 2023 | 4 | 10 | October |
| 20231015 | 2023-10-15 | 2023 | 4 | 10 | October |
| 20231201 | 2023-12-01 | 2023 | 4 | 12 | December |

**DimProduct:**
| product_key | product_name | category | subcategory |
| :---------- | :----------- | :---------- | :---------- |
| 101 | Laptop Pro | Electronics | Computers |
| 102 | Wireless KB | Electronics | Peripherals |
| 103 | Desk Chair | Furniture | Seating |

**DimStore:**
| store_key | store_name | region |
| :-------- | :----------- | :----- |
| 10 | Sydney CBD | NSW |
| 20 | Melbourne CC | VIC |

### Question 1: Total net revenue by product category and quarter

_Write a query against the star schema to produce a report of **total net revenue** (quantity × unit_price × (1 - discount)) broken down by **product category** and **quarter**. Order by quarter, then category._

**Solution:**

```sql
SELECT
    d.quarter,
    p.category,
    SUM(f.quantity * f.unit_price * (1 - f.discount)) AS net_revenue
FROM
    FactSales f
JOIN DimDate    d ON f.date_key    = d.date_key
JOIN DimProduct p ON f.product_key = p.product_key
GROUP BY
    d.quarter,
    p.category
ORDER BY
    d.quarter,
    p.category;
```

**Expected Output:**
| quarter | category | net_revenue |
| :------ | :---------- | :---------- |
| 4 | Electronics | 6,555.00 |
| 4 | Furniture | 600.00 |

**Why this works:** This is the canonical star-schema query: start from the fact table and join outward to dimensions. Always join **fact → dimension**, never dimension → dimension. Applying the business rule (net_revenue formula) inside the `SUM()` aggregation keeps the query efficient by not materialising a calculated column.

### Question 2: Find the top-selling product per region (handling ties with DENSE_RANK)

_Write a query to find the product with the highest total net revenue in each region. If there is a tie, include all tied products. Return `region`, `product_name`, and `total_net_revenue`._

**Solution:**

```sql
WITH RegionProductRevenue AS (
    SELECT
        st.region,
        p.product_name,
        SUM(f.quantity * f.unit_price * (1 - f.discount)) AS total_net_revenue
    FROM
        FactSales f
    JOIN DimStore   st ON f.store_key   = st.store_key
    JOIN DimProduct p  ON f.product_key = p.product_key
    GROUP BY
        st.region,
        p.product_name
),
Ranked AS (
    SELECT
        region,
        product_name,
        total_net_revenue,
        DENSE_RANK() OVER (PARTITION BY region ORDER BY total_net_revenue DESC) AS rnk
    FROM
        RegionProductRevenue
)
SELECT
    region,
    product_name,
    total_net_revenue
FROM
    Ranked
WHERE rnk = 1
ORDER BY region;
```

**Why this works:** The first CTE aggregates revenue per region-product pair. The second CTE applies `DENSE_RANK()` partitioned by `region` so each region ranks its own products independently. `WHERE rnk = 1` returns the top product(s) per region, correctly including ties. Using `DENSE_RANK()` instead of `ROW_NUMBER()` is critical — `ROW_NUMBER()` would arbitrarily drop tied products.

---

## Problem 19: Index Theory — Clustered vs Non-Clustered

### Scenario

_The interview prep guide lists "Index: Cluster vs Non Cluster" as a key technical topic. This problem tests both conceptual understanding and practical query-writing._

### Question 1: Conceptual — Clustered vs Non-Clustered Index

_Explain the core difference between a **Clustered Index** and a **Non-Clustered Index**. When would you add each, and what are the trade-offs?_

**Answer:**

| Feature            | Clustered Index                                    | Non-Clustered Index                                    |
| :----------------- | :------------------------------------------------- | :----------------------------------------------------- |
| Physical sort      | **Physically** sorts table rows on disk            | Separate structure; rows stay in heap order            |
| Per table          | **Only 1** allowed per table                       | Up to 999 per table                                    |
| Leaf node contains | The actual data row                                | Pointer (row locator) back to the data row             |
| Best for           | Range scans on the primary key; `ORDER BY` the key | Selective lookups on non-key columns; covering indexes |
| Write cost         | Higher on INSERT/UPDATE (pages must stay sorted)   | Moderate (separate structure maintained)               |
| Read speed         | Fastest for key-based range queries                | Faster than heap for column-selective queries          |

**Rule of thumb:**

- The **Clustered Index** should almost always be your primary key (usually an identity column), because every other index uses it as its row locator.
- **Non-Clustered Indexes** are added for columns frequently used in `WHERE`, `JOIN ON`, or `ORDER BY` clauses where the clustered index doesn't help.
- A **Covering Index** (Non-Clustered with `INCLUDE` columns) is the most powerful optimization: it allows SQL Server to satisfy a query entirely from the index without touching the base table (an "Index Seek + No Key Lookup").

### Question 2: Practical — Identify the index problem and fix it

_The following query runs slowly on a 10-million-row `Orders` table. The table only has a Clustered Index on `order_id`. Identify the performance problem and write the T-SQL to fix it._

**Slow query:**

```sql
-- This query is called 500 times per minute by the reporting dashboard
SELECT
    order_id,
    customer_id,
    order_date,
    total_amount
FROM Orders
WHERE
    customer_id = 'C0042'
    AND order_date >= '2023-01-01';
```

**Solution:**

```sql
-- Problem: SQL Server must do a full Clustered Index Scan (reads all 10M rows)
-- because customer_id and order_date are not indexed.

-- Fix: Create a Non-Clustered Covering Index
-- - Key columns: customer_id, order_date (the WHERE predicates — most selective first)
-- - INCLUDE columns: order_id, total_amount (the SELECT columns, avoids a Key Lookup)
CREATE NONCLUSTERED INDEX IX_Orders_CustomerId_OrderDate
ON Orders (customer_id, order_date)
INCLUDE (total_amount);
-- Note: order_id is already the clustered key, so it's automatically part of every
-- non-clustered index leaf node — no need to INCLUDE it explicitly.
```

**Why this works:**

1. **Without the index:** SQL Server has no way to find rows for `customer_id = 'C0042'` without reading every row (Clustered Index Scan — very slow).
2. **With the index:** SQL Server does an **Index Seek** directly to `customer_id = 'C0042'` and then filters the narrow date range. This reads only a handful of pages instead of millions.
3. **Why `INCLUDE (total_amount)`:** Without it, SQL Server would need to do a **Key Lookup** — jumping from the non-clustered index back to the clustered index to fetch `total_amount` for every matched row. The `INCLUDE` makes the index **covering** (self-sufficient), eliminating that expensive back-and-forth. This is the single most common index optimization a BI developer should know.
