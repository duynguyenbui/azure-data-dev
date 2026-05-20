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

---

## Problem 20: Moving Average & Window Functions

### Table: DailyRevenue

**Scenario:** You have a table containing the daily revenue of a business.

| date       | revenue |
| :--------- | :------ |
| 2023-11-01 | 1500    |
| 2023-11-02 | 2000    |
| 2023-11-03 | 2500    |
| 2023-11-04 | 1800    |
| 2023-11-05 | 2200    |
| 2023-11-06 | 3000    |

### Question 1: Calculate a 3-Day Moving Average

_Write a query to calculate the 3-day moving average of revenue for each day (including the current day and the 2 preceding days). If there are fewer than 2 preceding days, average what is available._

**Solution:**

```sql
SELECT
    date,
    revenue,
    AVG(CAST(revenue AS DECIMAL(10,2))) OVER (
        ORDER BY date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_3d
FROM
    DailyRevenue
ORDER BY
    date;
```

**Why this works:** The `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` frame clause inside the `OVER` clause specifically limits the window to the current row and the two previous rows based on the `ORDER BY date`. The `AVG` is then computed over only those rows.

---

## Problem 21: Cross Apply for Top N per Category

### Tables: Departments, Employees (Reused from Problem 2)

**Scenario:** We have `Departments` and `Employees`. We want to find the top 2 highest paid employees in each department.

| department_id | department_name |
| :------------ | :-------------- |
| 1             | Engineering     |
| 2             | Marketing       |
| 3             | Sales           |

### Question 1: Find Top 2 Earners per Department using CROSS APPLY

_Write a query using `CROSS APPLY` to find the top 2 highest-paid employees in each department._

**Solution:**

```sql
SELECT
    d.department_name,
    e.name AS employee_name,
    e.salary
FROM
    Departments d
CROSS APPLY (
    SELECT TOP 2
        name,
        salary
    FROM
        Employees emp
    WHERE
        emp.department_id = d.department_id
    ORDER BY
        salary DESC
) e
ORDER BY
    d.department_name,
    e.salary DESC;
```

**Why this works:** `CROSS APPLY` allows you to evaluate a subquery or table-valued function for each row in the outer table (`Departments`). Here, for every department, the subquery selects its top 2 earners, effectively passing the `d.department_id` into the inner query. This is a very clean way to do a "Top N per group" without window functions like `ROW_NUMBER()`.

---

## Problem 22: Relational Division (Exact Matching)

### Tables: Candidates, RequiredSkills

**Scenario:** You need to find candidates who possess _all_ the required skills for a specific job profile. This is known as "Relational Division".

| candidate_id | skill   |
| :----------- | :------ |
| 101          | Python  |
| 101          | SQL     |
| 101          | PowerBI |
| 102          | SQL     |
| 102          | Tableau |
| 103          | Python  |
| 103          | SQL     |

| required_skill |
| :------------- |
| SQL            |
| Python         |

### Question 1: Find candidates who have all required skills

_Write a query to find the `candidate_id`s of candidates who have exactly all the skills listed in the `RequiredSkills` table._

**Solution:**

```sql
SELECT
    c.candidate_id
FROM
    Candidates c
JOIN
    RequiredSkills rs ON c.skill = rs.required_skill
GROUP BY
    c.candidate_id
HAVING
    COUNT(DISTINCT c.skill) = (SELECT COUNT(*) FROM RequiredSkills);
```

**Why this works:** We join the candidates with the required skills to filter out irrelevant skills. Then, we group by candidate and count how many _distinct_ required skills they matched. If that count matches the total number of required skills, it means the candidate has them all.

---

## Problem 23: Market Basket Analysis (Product Pairs)

### Table: OrderDetails

**Scenario:** You want to analyze which products are frequently bought together in the same order.

| order_id | product_name |
| :------- | :----------- |
| 1        | Apple        |
| 1        | Banana       |
| 1        | Cherry       |
| 2        | Apple        |
| 2        | Banana       |
| 3        | Banana       |
| 3        | Cherry       |

### Question 1: Find pairs of products bought together

_Write a query to find the frequency of pairs of products bought in the same order. Return `product_1`, `product_2`, and the `frequency` of them appearing together._

**Solution:**

```sql
SELECT
    o1.product_name AS product_1,
    o2.product_name AS product_2,
    COUNT(DISTINCT o1.order_id) AS frequency
FROM
    OrderDetails o1
JOIN
    OrderDetails o2 ON o1.order_id = o2.order_id
                   AND o1.product_name < o2.product_name
GROUP BY
    o1.product_name,
    o2.product_name
ORDER BY
    frequency DESC;
```

**Why this works:** We self-join the `OrderDetails` table on the same `order_id`. The crucial part is the inequality condition `o1.product_name < o2.product_name`. This prevents joining a product to itself (Apple-Apple) and prevents getting duplicate pairs in reverse order (Apple-Banana and Banana-Apple).

---

## Problem 24: Overlapping Date Ranges (Merging Intervals)

### Table: Promotions

**Scenario:** A marketing department runs several promotions. Sometimes the date ranges of these promotions overlap. You need to find the consolidated, continuous periods where _any_ promotion was running.

| promo_id | start_date | end_date   |
| :------- | :--------- | :--------- |
| 1        | 2023-01-01 | 2023-01-10 |
| 2        | 2023-01-05 | 2023-01-15 |
| 3        | 2023-01-20 | 2023-01-25 |
| 4        | 2023-01-22 | 2023-01-30 |

### Question 1: Consolidate overlapping date ranges

_Write a query to merge overlapping promotion periods into consolidated start and end dates. Return `merged_start_date` and `merged_end_date`._

**Solution:**

```sql
WITH RollingMax AS (
    SELECT
        promo_id,
        start_date,
        end_date,
        -- Find the maximum end date of all intervals that started BEFORE the current one
        MAX(end_date) OVER (ORDER BY start_date ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) as max_previous_end_date
    FROM Promotions
),
IslandStarts AS (
    SELECT
        promo_id,
        start_date,
        end_date,
        -- If the current start date is strictly greater than the max end date of all previous intervals,
        -- it means it doesn't overlap and starts a new merged interval ("island")
        CASE WHEN start_date > max_previous_end_date OR max_previous_end_date IS NULL THEN 1 ELSE 0 END AS is_new_island
    FROM RollingMax
),
Islands AS (
    SELECT
        promo_id,
        start_date,
        end_date,
        SUM(is_new_island) OVER (ORDER BY start_date) AS island_id
    FROM IslandStarts
)
SELECT
    MIN(start_date) AS merged_start_date,
    MAX(end_date) AS merged_end_date
FROM Islands
GROUP BY island_id
ORDER BY merged_start_date;
```

**Why this works:** This is the standard "Packing Intervals" technique using window functions.

1. `RollingMax` calculates the highest `end_date` seen so far.
2. `IslandStarts` checks if the current `start_date` is later than that highest previous `end_date`. If so, a gap exists, so we mark it as the start of a new group (`is_new_island = 1`).
3. `Islands` creates an identifier for each grouped period by doing a running sum of the flags.
4. The final query groups by that identifier and takes the MIN and MAX dates for each block.

---

## Problem 25: Logical Window Frames (RANGE)

### Table: SalaryPeers

**Scenario:** HR wants a report showing for every employee, how many other employees have a salary that is within $1,000 of their salary. This requires creating a logical window frame based on the numeric value of the salary, not physical rows.

| name    | salary |
| :------ | :----- |
| Alice   | 50000  |
| Bob     | 50500  |
| Charlie | 51500  |
| David   | 60000  |

### Question 1: Find the number of salary peers within $1,000

_Write a query to calculate how many OTHER employees have a salary within a $1,000 range of the current employee's salary. Return the employee's `name`, `salary`, and `peers_within_1000`._

**Solution 1 (Standard SQL - e.g., PostgreSQL, MySQL):**

```sql
SELECT
    name,
    salary,
    -- Count everyone in the window, then subtract 1 so we don't count the employee themselves
    COUNT(*) OVER (
        ORDER BY salary
        RANGE BETWEEN 1000 PRECEDING AND 1000 FOLLOWING
    ) - 1 AS peers_within_1000
FROM SalaryPeers
ORDER BY salary;
```

**Solution 2 (Microsoft SQL Server / T-SQL):**

As the error message indicates, SQL Server explicitly restricts `RANGE` to `UNBOUNDED` and `CURRENT ROW`. To solve this in T-SQL, we must use a self-join to manually recreate the logical window:

```sql
SELECT
    e1.name,
    e1.salary,
    COUNT(e2.name) - 1 AS peers_within_1000
FROM
    SalaryPeers e1
LEFT JOIN
    SalaryPeers e2
    ON e2.salary BETWEEN e1.salary - 1000 AND e1.salary + 1000
GROUP BY
    e1.name,
    e1.salary
ORDER BY
    e1.salary;
```

**Why this works:**

1. **Standard SQL:** The `RANGE` keyword evaluates the logical value of the data in the `ORDER BY` clause. For "Bob" ($50,500), SQL dynamically creates a window from $49,500 to $51,500.
2. **SQL Server:** We mimic the `RANGE` behavior by joining the table to itself (`e1` to `e2`). For every row in `e1`, we find all rows in `e2` where the salary falls within the `e1.salary +/- 1000` boundary. Then we group by `e1` and count the matches (subtracting 1 to exclude the employee matching themselves).

---

## Problem 26: ROWS vs RANGE Behavior with Ties (SQL Server Supported)

### Table: PlayerScores

**Scenario:** We are tracking the points a player scores in a game. Notice that the player scored twice on `2023-01-02`. We want to see how `ROWS` and `RANGE` handle a running total when there are duplicate values in the `ORDER BY` clause. This perfectly demonstrates what `RANGE` does in SQL Server natively.

| score_date | points |
| :--------- | :----- |
| 2023-01-01 | 10     |
| 2023-01-02 | 15     |
| 2023-01-02 | 5      |
| 2023-01-03 | 20     |

### Question 1: Demonstrate ROWS vs RANGE for Running Totals

_Write a query that calculates two running totals of points ordered by `score_date`: one using `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`, and another using `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`._

**Solution:**

```sql
SELECT
    score_date,
    points,
    -- ROWS: Strict line-by-line physical calculation
    SUM(points) OVER (
        ORDER BY score_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total_rows,

    -- RANGE: Logical calculation treating identical dates as peers
    SUM(points) OVER (
        ORDER BY score_date
        RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total_range
FROM
    PlayerScores
ORDER BY
    score_date;
```

**Why this works:**

1. **`ROWS`** calculates the total line-by-line. On `Jan 02`, it processes the `15` point row first (Total: 25), and then the `5` point row next (Total: 30).
2. **`RANGE`** looks at the logical value (`Jan 02`). It sees two rows share this same value, so it treats them as a single group. It sums the entire group's points for that day (15 + 5 = 20) and adds it to the previous total (10). Thus, BOTH rows for `Jan 02` receive a running total of `30`.

_Interview Tip: If you just write `SUM(points) OVER (ORDER BY score_date)`, SQL Server silently defaults to the `RANGE` behavior. Because `RANGE` has to scan ahead to find ties, it is noticeably slower than `ROWS` on large datasets. Always write `ROWS UNBOUNDED PRECEDING` if you don't need tie-handling!_

---

## Problem 27: Department Top Three Salaries (LeetCode Hard)

### Tables: Employee_LC, Department_LC

**Scenario:** A company's executives are interested in seeing who earns the most money in each of the company's departments. A high earner in a department is an employee who has a salary in the top three unique salaries for that department.

| id  | name  | salary | departmentId |
| :-- | :---- | :----- | :----------- |
| 1   | Joe   | 85000  | 1            |
| 2   | Henry | 80000  | 2            |
| 3   | Sam   | 60000  | 2            |
| 4   | Max   | 90000  | 1            |
| 5   | Janet | 69000  | 1            |
| 6   | Randy | 85000  | 1            |
| 7   | Will  | 70000  | 1            |

| id  | name  |
| :-- | :---- |
| 1   | IT    |
| 2   | Sales |

### Question 1: Find the top 3 high earners per department

_Write a solution to find the employees who are high earners in each of the departments. Return `Department`, `Employee`, and `Salary`._

**Solution (T-SQL):**

```sql
WITH RankedSalaries AS (
    SELECT
        d.name AS Department,
        e.name AS Employee,
        e.salary AS Salary,
        DENSE_RANK() OVER (PARTITION BY e.departmentId ORDER BY e.salary DESC) AS salary_rank
    FROM
        Employee_LC e
    JOIN
        Department_LC d ON e.departmentId = d.id
)
SELECT
    Department,
    Employee,
    Salary
FROM
    RankedSalaries
WHERE
    salary_rank <= 3;
```

**Why this works:** We use `DENSE_RANK()` because the problem asks for the "top three _unique_ salaries". If two people tie for the highest salary (e.g., Max and Randy both make $85,000), they both get Rank 1. The next highest salary gets Rank 2. If we used `RANK()`, the next highest salary would get Rank 3. If we used `ROW_NUMBER()`, ties would be broken arbitrarily.

---

## Problem 28: Human Traffic of Stadium (LeetCode Hard)

### Table: Stadium

**Scenario:** We have a table displaying the `id`, `visit_date`, and `people` attending a stadium. We want to identify the busy days.

| id  | visit_date | people |
| :-- | :--------- | :----- |
| 1   | 2017-01-01 | 10     |
| 2   | 2017-01-02 | 109    |
| 3   | 2017-01-03 | 150    |
| 4   | 2017-01-04 | 99     |
| 5   | 2017-01-05 | 145    |
| 6   | 2017-01-06 | 1455   |
| 7   | 2017-01-07 | 199    |
| 8   | 2017-01-09 | 188    |

### Question 1: Find 3 or more consecutive busy days

_Write a solution to display the records with three or more consecutive rows with `people >= 100` each. Return the records ordered by `visit_date` in ascending order._

**Solution (T-SQL - Gaps and Islands approach):**

```sql
WITH BusyDays AS (
    -- Step 1: Filter only busy days and calculate the gap identifier
    SELECT
        id,
        visit_date,
        people,
        DATEADD(day, -ROW_NUMBER() OVER (ORDER BY visit_date), visit_date) AS group_id
    FROM
        Stadium
    WHERE
        people >= 100
),
GroupCounts AS (
    -- Step 2: Count how many consecutive days are in each group
    SELECT
        id,
        visit_date,
        people,
        COUNT(*) OVER (PARTITION BY group_id) AS days_in_group
    FROM
        BusyDays
)
-- Step 3: Filter groups with 3 or more days
SELECT
    id,
    visit_date,
    people
FROM
    GroupCounts
WHERE
    days_in_group >= 3
ORDER BY
    visit_date ASC;
```

**Why this works:** This is a classic "Gaps and Islands" problem solved using the `DATEADD` and `ROW_NUMBER()` trick. This is much safer than using `ID` because IDs can have gaps if records are deleted, but dates are always consistent.

1. We filter for `people >= 100`.
2. We assign a `ROW_NUMBER()` to these filtered rows based on their `visit_date`.
3. If the dates are consecutive, subtracting their `ROW_NUMBER` (in days) from the `visit_date` will always result in the exact same base date! We use `DATEADD(day, -ROW_NUMBER, visit_date)` to find this base date, which serves as a perfect, unique `group_id` for that island of consecutive days.
4. We then use a window function `COUNT(*) OVER (PARTITION BY group_id)` to find the size of each consecutive group and filter for sizes `>= 3`.

---

## Problem 29: Exchange Seats (LeetCode Medium)

### Table: Seat

**Scenario:** A school wants to swap the seats of every two consecutive students. If the number of students is odd, the id of the last student is not swapped.

| id  | student |
| :-- | :------ |
| 1   | Abbot   |
| 2   | Doris   |
| 3   | Emerson |
| 4   | Green   |
| 5   | Jeames  |

### Question 1: Swap adjacent seats

_Write a solution to swap the seat id of every two consecutive students. Return the result table ordered by `id` in ascending order._

**Solution (T-SQL):**

```sql
SELECT
    CASE
        -- If it's an odd ID and it's NOT the last row, swap with the next ID
        WHEN id % 2 <> 0 AND id != (SELECT MAX(id) FROM Seat) THEN id + 1
        -- If it's an even ID, swap with the previous ID
        WHEN id % 2 = 0 THEN id - 1
        -- If it's an odd ID and it IS the last row, keep it the same
        ELSE id
    END AS id,
    student
FROM
    Seat
ORDER BY
    id ASC;
```

**Alternative Solution (Using LEAD/LAG Window Functions):**

```sql
SELECT
    id,
    CASE
        WHEN id % 2 = 1 THEN ISNULL(LEAD(student) OVER (ORDER BY id), student)
        ELSE LAG(student) OVER (ORDER BY id)
    END AS student
FROM
    Seat
ORDER BY
    id;
```

**Why this works:**

- The first solution dynamically calculates the new `id` using modulo math (`% 2`) to identify odd/even rows. It handles the edge case of an odd total number of rows by checking against `MAX(id)`.
- The second solution is often preferred in modern SQL because it keeps the `id` stable and uses `LEAD` (look ahead 1 row) and `LAG` (look behind 1 row) to pull the names from the adjacent rows. `ISNULL` catches the odd-numbered last row where `LEAD` returns `NULL`.

---

## Problem 30: Trips and Users (Hard)

### Tables: Trips, Users

**Scenario:** The `Trips` table holds all taxi trips. Each trip has a unique Id, Client_Id, Driver_Id, City_Id, Status, and Request_at. The `Users` table holds all users (clients and drivers) and their role and banned status.

### Question 1: Cancellation Rate

_Write a SQL query to find the cancellation rate of requests with unbanned users (both client and driver must not be banned) each day between "2013-10-01" and "2013-10-03". Round Cancellation Rate to two decimal points._

**Solution (T-SQL):**

```sql
SELECT
    t.request_at AS Day,
    ROUND(
        SUM(CASE WHEN t.status IN ('cancelled_by_driver', 'cancelled_by_client') THEN 1.0 ELSE 0.0 END)
        / COUNT(*),
    2) AS 'Cancellation Rate'
FROM
    Trips t
JOIN
    Users c ON t.client_id = c.users_id AND c.banned = 'No'
JOIN
    Users d ON t.driver_id = d.users_id AND d.banned = 'No'
WHERE
    t.request_at BETWEEN '2013-10-01' AND '2013-10-03'
GROUP BY
    t.request_at;
```

**Why this works:** We join the `Users` table twice (once for clients, once for drivers) to ensure neither is banned. Then, we use conditional aggregation (`SUM(CASE...)`) to count cancelled trips, cast as `1.0` to force decimal division, and divide by the total `COUNT(*)` for that day.

---

## Problem 31: Consecutive Numbers (Medium)

### Table: Logs

**Scenario:** We have a `Logs` table with an auto-incrementing `id` and a `num` column.

### Question 1: Find 3 consecutive numbers

_Write an SQL query to find all numbers that appear at least three times consecutively._

**Solution (T-SQL):**

```sql
WITH LaggedLogs AS (
    SELECT
        num,
        LAG(num, 1) OVER (ORDER BY id) AS prev_num_1,
        LAG(num, 2) OVER (ORDER BY id) AS prev_num_2
    FROM
        Logs
)
SELECT DISTINCT
    num AS ConsecutiveNums
FROM
    LaggedLogs
WHERE
    num = prev_num_1 AND num = prev_num_2;
```

**Why this works:** The `LAG` window function is perfect here. By looking back 1 row (`prev_num_1`) and 2 rows (`prev_num_2`), we can evaluate three consecutive rows in a single evaluation context. If the current number equals the previous two, it's a 3-consecutive streak. `DISTINCT` ensures we don't list a number multiple times if the streak is 4+ long.

---

## Problem 32: Game Play Analysis IV (Medium)

### Table: Activity

**Scenario:** The `Activity` table tracks `player_id`, `device_id`, `event_date`, and `games_played`.

### Question 1: Day 1 Retention

_Write an SQL query to report the fraction of players that logged in again on the day after the day they first logged in, rounded to 2 decimal places. In other words, you need to count the number of players that logged in for at least two consecutive days starting from their first login date, then divide that number by the total number of players._

**Solution (T-SQL):**

```sql
WITH FirstLogins AS (
    SELECT
        player_id,
        MIN(event_date) AS first_login_date
    FROM
        Activity
    GROUP BY
        player_id
)
SELECT
    ROUND(
        CAST(COUNT(a.player_id) AS FLOAT) / (SELECT COUNT(DISTINCT player_id) FROM Activity),
    2) AS fraction
FROM
    FirstLogins f
JOIN
    Activity a ON f.player_id = a.player_id
              AND a.event_date = DATEADD(day, 1, f.first_login_date);
```

**Why this works:** This is the canonical way to calculate retention. First, we find the absolute minimum (first) login date per player in a CTE. Then, we join back to the `Activity` table, checking if there exists a record for that same player exactly 1 day after (`DATEADD(day, 1)`) their first login.

---

## Problem 33: Tree Node (Medium)

### Table: Tree

**Scenario:** We have a table representing a generic tree structure with `id` and `p_id` (parent ID).

### Question 1: Categorize Nodes

_Write an SQL query to report the type of each node in the tree. Return `Root` (no parent), `Inner` (has parent and children), or `Leaf` (has parent, no children)._

**Solution (T-SQL):**

```sql
SELECT
    id,
    CASE
        WHEN p_id IS NULL THEN 'Root'
        WHEN id IN (SELECT p_id FROM Tree WHERE p_id IS NOT NULL) THEN 'Inner'
        ELSE 'Leaf'
    END AS type
FROM
    Tree
ORDER BY
    id;
```

**Why this works:** The `CASE` statement perfectly mirrors the hierarchical logic.

1. If it has no parent, it's the `Root`.
2. If its `id` appears in the `p_id` column of _other_ nodes, it has children, making it an `Inner` node.
3. If it fails both above, it must be a `Leaf`.

---

## Problem 34: Average Salary: Departments VS Company (Hard)

### Tables: Salary, Employee

**Scenario:** We have monthly salary payments and an employee table detailing their department.

### Question 1: Compare Averages

_Write an SQL query to report the comparison result (higher/lower/same) of the average salary of employees in a department to the company's average salary for each month._

**Solution (T-SQL):**

```sql
WITH MonthlyAverages AS (
    SELECT
        CONVERT(VARCHAR(7), s.pay_date, 120) AS pay_month,
        e.department_id,
        AVG(CAST(s.amount AS FLOAT)) OVER (PARTITION BY CONVERT(VARCHAR(7), s.pay_date, 120), e.department_id) AS dept_avg,
        AVG(CAST(s.amount AS FLOAT)) OVER (PARTITION BY CONVERT(VARCHAR(7), s.pay_date, 120)) AS company_avg
    FROM
        Salary s
    JOIN
        Employee e ON s.employee_id = e.employee_id
)
SELECT DISTINCT
    pay_month,
    department_id,
    CASE
        WHEN dept_avg > company_avg THEN 'higher'
        WHEN dept_avg < company_avg THEN 'lower'
        ELSE 'same'
    END AS comparison
FROM
    MonthlyAverages
ORDER BY
    pay_month DESC, department_id;
```

**Why this works:** We leverage window functions heavily here. We calculate the `dept_avg` partitioned by both month and department, while simultaneously calculating the `company_avg` partitioned _only_ by month. Because window functions preserve rows, we `SELECT DISTINCT` at the end to collapse the results and output the `CASE` comparison.

---

## Problem 35: Investments in 2016 (Medium)

### Table: Insurance

**Scenario:** We have insurance records with `pid` (policy ID), `tiv_2015`, `tiv_2016`, `lat`, and `lon`.

### Question 1: Calculate Total Value

_Write an SQL query to report the sum of all total investment values in 2016 (`tiv_2016`), for all policyholders who: 1) have the same `tiv_2015` value as one or more other policyholders, and 2) are not located in the same city as any other policyholder (i.e., unique lat/lon pair)._

**Solution (T-SQL):**

```sql
WITH InvestmentCounts AS (
    SELECT
        tiv_2016,
        COUNT(*) OVER (PARTITION BY tiv_2015) AS count_2015,
        COUNT(*) OVER (PARTITION BY lat, lon) AS count_location
    FROM
        Insurance
)
SELECT
    ROUND(SUM(tiv_2016), 2) AS tiv_2016
FROM
    InvestmentCounts
WHERE
    count_2015 > 1
    AND count_location = 1;
```

**Why this works (The Window Function Filter Method):** 
Window functions (`COUNT(*) OVER`) are incredibly powerful for identifying uniqueness without messy subqueries. 
- **The Concept:** The problem asks us to filter data based on 2 opposite conditions: one must be "duplicated" (tiv_2015) and one must be "strictly unique" (lat/lon). 
- **The Execution:** Instead of writing complex `WHERE tiv_2015 IN (SELECT ... GROUP BY ... HAVING COUNT > 1)` and another `WHERE (lat, lon) IN (SELECT ... HAVING COUNT = 1)`, we can calculate and append the group counts directly to every row using `COUNT(*) OVER (PARTITION BY ...)`.
- **The Filter:** In the outer query, we simply filter for `count_2015 > 1` (has duplicates) and `count_location = 1` (is completely unique). 

*Interview Tip: Whenever an interview question asks you to find "unique" records or "records shared by others", try to use `COUNT() OVER(PARTITION BY...)` instead of `GROUP BY` subqueries. It shows you know how to write modern, performant, and clean SQL.*

---

## Problem 36: Active Businesses (Medium)

### Table: Events

**Scenario:** An `Events` table logs the `business_id`, `event_type`, and `occurences`.

### Question 1: Find Active Businesses

_An active business is a business that has more than one event type such that their occurrences is strictly greater than the average occurrences of that event type among all businesses. Write an SQL query to find all active businesses._

**Solution (T-SQL):**

```sql
WITH EventAverages AS (
    SELECT
        business_id,
        event_type,
        occurences,
        AVG(CAST(occurences AS FLOAT)) OVER (PARTITION BY event_type) AS avg_event
    FROM
        Events
)
SELECT
    business_id
FROM
    EventAverages
WHERE
    occurences > avg_event
GROUP BY
    business_id
HAVING
    COUNT(event_type) > 1;
```

**Why this works:** We use a window function to attach the global average for each `event_type` to every row. Then, we filter for only the rows where the business's occurrences beat the average. Finally, we `GROUP BY` the business and ensure they beat the average in _more than one_ event type (`HAVING COUNT > 1`).

---

## Problem 37: Students Report By Geography (Hard)

### Table: Student

**Scenario:** We have a list of students and the continent they are from.

### Question 1: Pivot the Data

_Write an SQL query to pivot the continents column such that each name is sorted alphabetically and displayed underneath its corresponding continent. The output headers should be America, Asia, and Europe._

**Solution (T-SQL - Native PIVOT):**

```sql
WITH RankedStudents AS (
    SELECT
        name,
        continent,
        ROW_NUMBER() OVER (PARTITION BY continent ORDER BY name) AS rn
    FROM
        Student
)
SELECT 
    [America], 
    [Asia], 
    [Europe]
FROM 
    RankedStudents
PIVOT (
    MAX(name)
    FOR continent IN ([America], [Asia], [Europe])
) AS PivotTable;
```

**Why this works:** SQL Server has a native `PIVOT` operator specifically designed to transform rows into columns.
1. We still MUST use `ROW_NUMBER()` in the CTE to create an invisible "grid index" (`rn`). If we didn't have `rn`, the `PIVOT` would just aggregate every student in a continent into a single row.
2. The `PIVOT` clause requires an aggregate function, so we use `MAX(name)`. Because our `rn` guarantees there is only one name per `rn` per `continent`, `MAX()` simply returns that exact string.
3. The `FOR continent IN (...)` clause dynamically generates our new column headers.

---

## Problem 38: Nth Highest Salary (Medium)

### Table: Employee

**Scenario:** We need to find the Nth highest salary.

### Question 1: Dynamic Ranking

_Write an SQL query to report the Nth highest salary from the Employee table. If there is no Nth highest salary, the query should report null._

**Solution (T-SQL):**

```sql
-- Assuming N = 2 for this example. In a stored procedure, this would be a parameter @N.
DECLARE @N INT = 2;

WITH RankedSalaries AS (
    SELECT
        salary,
        DENSE_RANK() OVER (ORDER BY salary DESC) AS rnk
    FROM
        Employee
)
SELECT
    MAX(salary) AS getNthHighestSalary
FROM
    RankedSalaries
WHERE
    rnk = @N;
```

**Why this works:** We use `DENSE_RANK()` to rank distinct salaries (so if two people tie for 1st, the next highest is exactly 2nd). We wrap the final select in `MAX(salary)` because if no rows match `rnk = @N` (e.g., asking for the 5th highest when only 3 exist), standard SQL returns an empty set, but using an aggregate like `MAX()` over an empty set guarantees it will return exactly one row containing `NULL`, fulfilling the requirement.

---

## Problem 39: Managers with at Least 5 Direct Reports (Medium)

### Table: Employee

**Scenario:** The employee table has an `id` and a `managerId`.

### Question 1: Find Busy Managers

_Write an SQL query to report the managers with at least five direct reports._

**Solution (T-SQL):**

```sql
SELECT
    m.name
FROM
    Employee e
JOIN
    Employee m ON e.managerId = m.id
GROUP BY
    m.id, m.name
HAVING
    COUNT(e.id) >= 5;
```

**Why this works:** We self-join the table to link reports (`e`) to their managers (`m`). We group by the manager's ID and name, and then filter using the `HAVING` clause to only include managers who have 5 or more reports.

---

## Problem 40: Rank Scores (Medium)

### Table: Scores

**Scenario:** We need to rank scores from highest to lowest. If there is a tie between two scores, both should have the same ranking. After a tie, the next ranking number should be the next consecutive integer value.

### Question 1: Rank the scores

_Write an SQL query to rank the scores._

**Solution:**

```sql
SELECT
    score,
    DENSE_RANK() OVER (ORDER BY score DESC) AS rank
FROM
    Scores
ORDER BY
    score DESC;
```

**Why this works:** The `DENSE_RANK()` window function assigns a rank to each row within a result set partition, with no gaps in ranking values. This perfectly matches the requirement that after a tie, the next ranking is the next consecutive integer.

---

## Problem 41: Rising Temperature (Easy)

### Table: Weather

**Scenario:** The `Weather` table contains weather data by date.

### Question 1: Find dates with higher temperatures than the previous date

_Write an SQL query to find all dates' `id` with higher temperatures compared to its previous dates (yesterday)._

**Solution:**

```sql
SELECT
    w1.id
FROM
    Weather w1
JOIN
    Weather w2 ON DATEADD(day, 1, w2.recordDate) = w1.recordDate
WHERE
    w1.temperature > w2.temperature;
```

**Why this works:** We join the `Weather` table to itself. By adding 1 day to `w2.recordDate` and matching it to `w1.recordDate`, we effectively align each day (`w1`) with its yesterday (`w2`). Then we simply filter for rows where today's temperature (`w1.temperature`) is greater than yesterday's temperature (`w2.temperature`).

---

## Problem 42: Capital Gain/Loss (Medium)

### Table: Stocks

**Scenario:** The `Stocks` table contains the buy and sell prices of various stocks over different days. Each stock's operation consists of paired 'Buy' and 'Sell' days (meaning each buy is eventually followed by a sell).

### Question 1: Calculate Total Capital Gain/Loss

_Write an SQL query to report the Capital gain/loss for each stock. The Capital gain/loss of a stock is the total gain or loss after buying and selling the stock one or many times._

**Solution:**

```sql
SELECT
    stock_name,
    SUM(CASE WHEN operation = 'Buy' THEN -price ELSE price END) AS capital_gain_loss
FROM
    Stocks
GROUP BY
    stock_name;
```

**Why this works:** We group the records by `stock_name`. For each stock, a 'Buy' operation represents money spent (a negative amount), and a 'Sell' operation represents money gained (a positive amount). By summing these up conditionally using a `CASE` statement, we get the net capital gain or loss.

---

## Problem 43: Average Time of Process per Machine (Medium)

### Table: MachineActivity

**Scenario:** We have logs of machines processing tasks. Each process consists of a "start" and an "end" activity.

### Question 1: Find Processing Time

_Write an SQL query to calculate the average time each machine takes to complete a process. The time to complete a process is the 'end' timestamp minus the 'start' timestamp. The average time is calculated by the total time to complete every process on the machine divided by the number of processes that were run._

**Solution (using self-join):**

```sql
SELECT
    a1.machine_id,
    ROUND(AVG(a2.timestamp - a1.timestamp), 3) AS processing_time
FROM
    MachineActivity a1
JOIN
    MachineActivity a2
    ON a1.machine_id = a2.machine_id
    AND a1.process_id = a2.process_id
    AND a1.activity_type = 'start'
    AND a2.activity_type = 'end'
GROUP BY
    a1.machine_id;
```

**Why this works:** The self-join correctly pairs up the 'start' and 'end' events for the exact same `machine_id` and `process_id`. Taking the average of their timestamp difference natively handles calculating the average processing time per machine.

---

## Problem 44: Apples & Oranges (Medium)

### Table: FruitSales

**Scenario:** We have a table tracking daily sales of apples and oranges.

### Question 1: Difference in Sales

_Write an SQL query to report the difference between the number of apples and oranges sold each day. Return the result table ordered by `sale_date`._

**Solution:**

```sql
SELECT
    sale_date,
    SUM(CASE WHEN fruit = 'apples' THEN sold_num ELSE -sold_num END) AS diff
FROM
    FruitSales
GROUP BY
    sale_date
ORDER BY
    sale_date;
```

**Why this works:** Using a conditional `SUM()` with a `CASE` statement allows you to pivot the data in-place. If the fruit is an apple, we add the sold amount. If the fruit is an orange, we subtract the sold amount. Grouping by date calculates the total net difference natively.

---

## Problem 45: Find Median Given Frequency of Numbers (Hard)

### Table: Numbers

**Scenario:** Instead of a traditional array of numbers, the numbers are stored as a frequency table.

### Question 1: Calculate the Median

_Write an SQL query to find the median of all the numbers. The median should be calculated effectively despite the data being represented as frequencies rather than distinct rows._

**Solution:**

```sql
WITH CumulativeFrequencies AS (
    SELECT
        num,
        frequency,
        SUM(frequency) OVER (ORDER BY num ASC) AS asc_cum_freq,
        SUM(frequency) OVER (ORDER BY num DESC) AS desc_cum_freq,
        SUM(frequency) OVER () AS total_freq
    FROM
        Numbers
)
SELECT
    AVG(CAST(num AS DECIMAL(10,2))) AS median
FROM
    CumulativeFrequencies
WHERE
    asc_cum_freq >= total_freq / 2.0
    AND desc_cum_freq >= total_freq / 2.0;
```

**Why this works:** The median of a sequence is always the element that splits the set into two halves. By calculating running totals of the frequencies from both ends (ascending and descending), we can find the element(s) where the cumulative counts from both directions overlap the middle point (`total_freq / 2.0`). Taking the `AVG()` naturally handles cases where the total count is even and the median bridges two different numbers.
