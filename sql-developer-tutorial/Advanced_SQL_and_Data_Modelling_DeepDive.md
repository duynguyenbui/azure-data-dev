# Deep Dive: Advanced SQL & Data Modelling

_This guide directly addresses the Innovature BPO Job Description requirement: "Advanced SQL knowledge and experience (stored procedures, functions, triggers) and understanding of data warehousing and data modelling."_

---

## Part 1: Advanced SQL Objects

As a Senior SQL Developer, you must know not just _how_ to write these objects, but _when_ and _why_ to use them.

### 1. Stored Procedures (The Workhorses)

Stored Procedures (SPs) are pre-compiled batches of SQL statements. They are the backbone of ETL processes and backend business logic.

- **Key Capabilities:**
  - Can perform DML operations (`INSERT`, `UPDATE`, `DELETE`).
  - Can manage transactions (`BEGIN TRAN`, `COMMIT`, `ROLLBACK`).
  - Can handle complex error handling (`TRY...CATCH`).
  - Can return multiple result sets.
- **Best Practices:** Always use `SET NOCOUNT ON` to reduce network traffic. Avoid using the `sp_` prefix when naming, as SQL Server checks the `master` database first for those, causing a slight performance hit.

### 2. User-Defined Functions (UDFs) (The Calculators)

Functions are designed to encapsulate reusable calculation logic.

- **Types of Functions:**
  - **Scalar Functions:** Return a single value (e.g., calculating an employee's exact age based on DOB).
  - **Table-Valued Functions (TVFs):** Return a table. Inline TVFs are generally highly performant as the optimizer treats them like views.
- **Crucial Limitations:** Functions _cannot_ change database state. You cannot perform `INSERT`, `UPDATE`, or `DELETE` inside a function. You also cannot use non-deterministic built-in functions like `NEWID()` or `RAND()` directly inside some UDFs.
- **Performance Warning:** Scalar functions can be notorious performance killers if used in the `SELECT` or `WHERE` clause of a large query, as they often force row-by-row execution (RBAR - Row By Agonizing Row) rather than set-based execution.

### 3. Triggers (The Automated Listeners)

A trigger is a special type of stored procedure that fires automatically in response to specific events (`INSERT`, `UPDATE`, `DELETE`).

- **The Virtual Tables:** Inside a DML trigger, you have access to two special virtual tables: `INSERTED` (holds new/updated values) and `DELETED` (holds old values).
- **Use Cases:** Perfect for **Audit Logging** (e.g., recording the old salary, new salary, user, and timestamp into an `AuditLog` table whenever an `Employee` row is updated).
- **Best Practices:** Keep triggers extremely lightweight. Because a trigger runs in the same transaction as the `INSERT/UPDATE` statement that fired it, a slow trigger will slow down the entire system and can lead to severe blocking and deadlocking.

---

## Part 2: Data Warehousing & Data Modelling

Moving data from a transactional application (like Ready Workforce) into a Data Warehouse requires restructuring the data for reporting efficiency. This is known as **Dimensional Modelling** (specifically, the Kimball Methodology).

### 1. OLTP vs. OLAP

- **OLTP (Online Transaction Processing):** The application database. It is highly normalized (3rd Normal Form) to reduce data redundancy and make `INSERT/UPDATE` operations extremely fast. (e.g., splitting Employees, Departments, and Roles into many tables).
- **OLAP (Online Analytical Processing):** The Data Warehouse. It is purposely denormalized to make `SELECT` queries and aggregations extremely fast for BI tools like Power BI.

### 2. The Star Schema

A Star Schema is the gold standard for data warehousing. It consists of a central **Fact table** surrounded by **Dimension tables**.

#### A. Fact Tables (The "Metrics")

Fact tables contain the measurable, quantitative events of the business.

- _Examples:_ `GrossPay`, `LeaveHoursTaken`, `SalesAmount`.
- _The Grain:_ The most important decision in data modelling is defining the "grain" (the level of detail) of the fact table. For example, is the grain "one row per pay period per employee" or "one row per daily timesheet entry"?
- _Types of Facts:_
  - **Additive:** Can be summed across all dimensions (e.g., Sales Amount).
  - **Semi-Additive:** Can be summed across some dimensions but not others (e.g., Account Balances can be summed across customers, but not across dates).
  - **Non-Additive:** Cannot be summed (e.g., Ratios or Percentages).

#### B. Dimension Tables (The "Context")

Dimension tables contain the descriptive attributes that you use to filter, group, and slice the fact data.

- _Examples:_ `DimEmployee` (Name, Age, Gender), `DimDate` (Year, Quarter, Month), `DimDepartment`.
- _Surrogate Keys:_ Dimension tables should always use an auto-incrementing integer (Surrogate Key) as their Primary Key, rather than relying on the application's natural key (like an EmployeeID string). This improves join performance and handles historical changes.

### 3. Slowly Changing Dimensions (SCD)

When dimension data changes over time (e.g., an employee moves from the HR department to the IT department), how do you track it?

- **SCD Type 1 (Overwrite):** Simply overwrite the old department with the new one. You lose the historical record. (Fast, but bad for historical reporting).
- **SCD Type 2 (Add New Row):** You expire the old row by setting an `EndDate` and an `IsCurrent = 0` flag, and insert a brand new row for the employee with the new department, a new `StartDate`, and `IsCurrent = 1`. This preserves full historical accuracy and is the industry standard for Data Warehouses.

---

## Part 3: Mock Interview Q&A

**Q1: We have a complex calculation that determines an employee's exact leave entitlement based on tenure, local laws, and contract type. We need to apply this to millions of rows in our data warehouse. Would you put this logic in a Scalar Function or a Stored Procedure?**

**Your Answer:** "While a Scalar Function seems logically perfect because it encapsulates the calculation, applying it to millions of rows in a `SELECT` statement can cause severe performance issues because it forces row-by-row execution (RBAR). Instead, I would handle this inside a **Stored Procedure**. I would write the logic using set-based operations—perhaps leveraging an inline Table-Valued Function or CTEs—and store the calculated results into a staging or fact table. This ensures the optimizer can process the data in bulk, which is critical for ETL performance."

**Q2: Can you explain the difference between a Star Schema and a highly normalized database? Why do we use Star Schemas in Data Warehousing?**

**Your Answer:** "A highly normalized database, like an OLTP system, minimizes data duplication. It’s great for fast application inserts and updates, but it requires joining dozens of tables to get a simple report, which makes querying very slow.
A Star Schema is purposely denormalized. It centralizes our measurable metrics in a Fact table and surrounds it with descriptive Dimension tables. We use Star Schemas in Data Warehouses because it drastically reduces the number of `JOINs` required, making read performance incredibly fast. It also makes the data model highly intuitive for business users and tools like Power BI or SSAS."
