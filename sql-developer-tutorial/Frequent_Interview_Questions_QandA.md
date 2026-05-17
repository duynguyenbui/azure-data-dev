# Frequent Interview Questions & Answers Master List

*This document contains the most frequent technical, situational, and behavioral questions asked in Senior SQL Developer and BI interviews, specifically tailored for your Innovature BPO interview and your Ready Workforce experience.*

---

## 0. The Introduction & General Communication

**Q: "Tell me a little bit about yourself and your background."**
**A:** "Thank you for having me. I am a highly technical SQL Developer with over [X] years of hands-on experience. Writing efficient, advanced SQL is the core of what I do every day. Beyond writing new code, a major part of my role at Ready Workforce involves diving into older, legacy SQL scripts—untangling complex logic and optimizing slow queries without breaking existing functionality. I am also highly proficient in the Microsoft BI stack (SSIS and SSAS) and I am currently working with cloud technologies like Azure Data Factory. I'm a detail-oriented person who enjoys taking ownership of projects and ensuring data is accurate and available."

**Q: "How do you approach communicating with English-speaking clients or non-technical stakeholders?"**
**A:** "The key to great communication is keeping things simple and proactive. I try to avoid long, confusing email chains. If there is an issue or a new requirement, my first step is to jump on a quick online call. I practice active listening and repeat their core requirements back to them to ensure we are aligned. Once I solve the issue in the backend, I explain the resolution to them in clear, non-technical language—focusing entirely on how the data solves their business problem rather than the complex SQL underneath."

---

## 1. Advanced T-SQL & Database Engine

**Q: What is the difference between a Stored Procedure and a User-Defined Function?**
**A:** "A stored procedure is used to execute business logic and can modify data (INSERT/UPDATE/DELETE), handle transactions, and use TRY...CATCH blocks. A function is purely for calculations—it returns a single value (Scalar) or a table (Table-Valued) and **cannot** change database state. I always avoid using Scalar functions on large datasets because they force slow, row-by-row execution."

**Q: Can you explain Window Functions and give an example of when you've used one?**
**A:** "Window functions perform calculations across a set of rows related to the current row, without actually grouping the output into a single row like `GROUP BY` does. I frequently use `ROW_NUMBER() OVER (PARTITION BY EmployeeID ORDER BY EffectiveDate DESC)` to find the most recent pay record or department for an employee, or to identify and quarantine duplicate records in an ETL pipeline."

**Q: How do you troubleshoot a slow-running query?**
**A:** "My first step is to generate the **Actual Execution Plan** in SSMS. I look for warnings, expensive operations like large sorts, or Table Scans. Usually, the issue is a missing or fragmented index. If the indexes are healthy, I look at the code—often I need to replace a cursor with set-based logic, or change a table variable to a temporary `#temp` table so the optimizer has statistics to work with."

**Q: What are CTEs (Common Table Expressions) and why do you use them?**
**A:** "CTEs act as temporary, named result sets within a single `SELECT` statement. I use them primarily for two reasons: First, to make complex, nested subqueries much more readable and maintainable. Second, to write recursive queries, such as building an organizational chart where employees report to managers."

**Q: What is the logical execution order of a SQL query?**
**A:** "This is crucial for understanding how to optimize and debug. The engine does not read top-to-bottom like we do. The logical order is:
1. **FROM / JOIN:** (Pulls the base data together)
2. **WHERE:** (Filters the raw data)
3. **GROUP BY:** (Aggregates the filtered data)
4. **HAVING:** (Filters the aggregated data)
5. **SELECT:** (Returns the specific columns/expressions)
6. **ORDER BY:** (Sorts the final result set)
7. **TOP / LIMIT:** (Restricts the number of returned rows)
Knowing this explains why you can't use a column alias defined in the `SELECT` clause inside a `WHERE` clause—because the `WHERE` clause is executed first!"

---

## 2. Data Warehousing & ETL (SSIS / ADF)

**Q: Explain the difference between an OLTP database and an OLAP data warehouse.**
**A:** "An OLTP database (like Ready Workforce) is highly normalized to minimize data duplication and ensure fast INSERTs and UPDATEs. An OLAP Data Warehouse is purposely denormalized into a **Star Schema** (Fact and Dimension tables) to drastically reduce the number of joins required, making read-heavy reporting and aggregations extremely fast."

**Q: What is a Slowly Changing Dimension (SCD) and how do you handle it?**
**A:** "SCD refers to how we track dimension data that changes over time—like an employee changing departments. 
*   **SCD Type 1:** Overwrites the old data. History is lost.
*   **SCD Type 2:** The industry standard for data warehouses. We expire the old record by setting an `EndDate` and `IsCurrent = 0`, then insert a new row with the new department and `IsCurrent = 1`. This preserves full historical accuracy for past pay periods."

**Q: How do you approach an Incremental Load versus a Full Load?**
**A:** "A full load truncates the target table and reloads everything, which is only viable for small lookup tables. For massive fact tables, I always design incremental loads. I use 'High-Water Marks' (like a `LastModifiedDate`) to pull only new or changed records from the source, and then use a `MERGE` statement to INSERT new rows and UPDATE existing ones efficiently."

**Q: How would you migrate our legacy on-premise SSIS packages to Azure?**
**A:** "We don't need to rebuild them from scratch. We can use a 'lift and shift' approach by provisioning an **Azure-SSIS Integration Runtime** within Azure Data Factory. This allows us to run our existing SSIS packages natively in the cloud while orchestrating them via ADF pipelines."

---

## 3. SSAS & Power BI

**Q: What is the difference between Tabular and Multidimensional models in SSAS?**
**A:** "Multidimensional models are the older technology using Cubes and the MDX language. **Tabular models** are the modern standard. They run in-memory using the VertiPaq compression engine, making them incredibly fast, and they use **DAX** for calculations. I always advocate for building Tabular models because they integrate seamlessly with Power BI."

**Q: How do you ensure a Power BI dashboard is highly performant?**
**A:** "Performance starts at the backend, not in Power BI. I ensure the data warehouse is modelled correctly as a Star Schema, and that the heavy lifting is done in SQL or SSAS. If the underlying SSAS Tabular model is well-designed and the DAX measures are efficient, the Power BI dashboard will naturally be fast and responsive."

---

## 4. Behavioral & Scenario-Based Questions

**Q: How do you handle working with legacy or 'spaghetti' code?**
**A:** "A big part of my role at Ready Workforce involves diving into older, complex legacy SQL scripts. I am very comfortable reverse-engineering stored procedures to understand the original developer's intent. Dealing with legacy code has made me a much stronger developer because it forces you to truly understand the database engine before you start refactoring and optimizing."

**Q: Tell me about a time you had to resolve a conflict or push back on a request from a stakeholder.**
**A:** "When I encounter a disagreement over a technical approach or timeline, my first step is always to jump on a quick call. Most conflicts stem from miscommunication. I actively listen to their concerns, acknowledge the business need, and then calmly explain the technical constraints. I never just say 'no'—I always offer alternative solutions. Taking the emotion out of it and focusing on the shared business goal gets everyone back on the same page."

**Q: Imagine an overnight ETL pipeline fails and the morning reports are empty. What do you do?**
**A:** "First, I immediately check the execution logs in SSIS or ADF to identify the exact error—whether it's a timeout, bad data type, or truncation. While investigating, I proactively message the stakeholders to acknowledge the issue and provide an ETA. Once I find and fix the root cause, I re-run the pipeline. Finally, I document the issue and update the code (like adding better TRY...CATCH handling) to prevent it from happening again."

**Q: How do you manage your time when you have multiple competing deadlines?**
**A:** "I rely heavily on prioritization and time-blocking. I map out my interrelated timelines to see where projects overlap with my daily ETL support duties. I tackle critical pipeline issues in the morning and dedicate my afternoons to deep-focus SQL development. If I see a bottleneck approaching, I proactively over-communicate with my manager or stakeholders to adjust expectations early, rather than waiting until the deadline is missed."
