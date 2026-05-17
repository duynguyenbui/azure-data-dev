# Final Interview Cheat Sheet: Innovature BPO SQL Developer

_Review this cheat sheet right before your interview. It covers the core technical concepts, key vocabulary, and behavioral reminders to ensure you sound confident, professional, and fully prepared._

## 1. Advanced T-SQL & Performance Tuning

- **Window Functions:** `ROW_NUMBER()`, `RANK()`, `DENSE_RANK()`. Used for deduplication and calculating running totals.
- **CTEs (Common Table Expressions):** Used to make complex subqueries readable and to handle recursive hierarchies (e.g., employee-manager relationships).
- **Performance Tuning Steps:**
  1. Check the **Execution Plan** in SSMS (look for Table Scans, expensive sorts, warnings).
  2. Ensure proper **Indexing** (Clustered vs. Non-Clustered) and fix fragmentation.
  3. Remove cursors (row-by-row processing) in favor of **set-based logic**.
  4. Use temporary tables (`#temp`) instead of table variables (`@table`) for large datasets, as temp tables have statistics the optimizer can use.

## 2. ETL & Data Warehousing (SSIS)

- **Control Flow vs. Data Flow:** Control flow dictates the _order_ of tasks (logic, loops). Data Flow handles the actual _movement and transformation_ of data in memory.
- **Incremental Loads:** Don't truncate and load everything. Use `MERGE` statements or High-Water Marks (timestamps) to only load new or updated data.
- **SCD (Slowly Changing Dimensions):**
  - _Type 1:_ Overwrite old data (no historical tracking).
  - _Type 2:_ Add a new row, expire the old row using `IsActive` flags and `EndDate` (preserves history).

## 3. Microsoft Azure Data Stack

- **Azure Data Factory (ADF):** The cloud equivalent of SSIS. Key terms: _Pipelines_, _Linked Services_ (connections), and _Datasets_.
- **SSIS Migration:** How to move on-prem SSIS to the cloud? Answer: "Lift and shift using the **Azure-SSIS Integration Runtime** in ADF."
- **Azure Synapse Analytics:** Used for massive data warehouses. Uses **MPP** (Massively Parallel Processing) instead of traditional SMP. Uses Hash, Replicate, and Round-Robin table distribution.
- **Azure DevOps:** Automates database and pipeline deployments using Git version control and **CI/CD pipelines**, replacing manual executions.

## 4. SSAS (Analysis Services) & Power BI

- **SSAS Models:** Always advocate for **Tabular Models** (modern, in-memory, highly compressed via the VertiPaq engine) over old Multidimensional Cubes.
- **Language:** Tabular models use **DAX** (Data Analysis Expressions) for calculations.
- **Power BI:** Connects seamlessly to Tabular SSAS models. "If the backend model and DAX are built efficiently, the front-end visualization is straightforward."

## 5. Behavioral & Communication Strategy

- **The STAR Method:** For behavioral questions, always format your answer as: **Situation -> Task -> Action -> Result**. Keep it focused on _your_ actions.
- **Client Communication Strategy:** "I prefer jumping on a quick online call over long email chains. I practice active listening, repeat requirements back to ensure alignment, and explain my technical fixes in clear, non-technical business language."
- **Your Value Proposition:** "At Ready Workforce, I handle heavy-lifting backend SQL, complex payroll/leave logic, and daily ETL pipelines. I am comfortable taking ownership of projects and working independently."

## 6. Power Phrases to Remember

- "I love owning a project **end-to-end**."
- "My goal is to make sure the data is **spot-on** without over-engineering things."
- "I prefer to **hit the ground running** and be proactive."
- "We don't need to reinvent the wheel, we can **lift and shift** our legacy packages."

---

**Take a deep breath, speak at a comfortable pace, and smile. You have exactly the experience they are looking for! You are going to do great!**
