# ETL, Data Modeling, and BI Technical Preparation

This document serves as a focused review guide for the ETL, Data Modeling, and BI Tools sections of the interview, extracted directly from the comprehensive study plan.

---

## 1. ETL / SSIS / Data Flows

### Task Types in SSIS (Control Flow)

The Control Flow acts as the orchestrator of the package, determining the sequence of operations.

- **Data Flow Task:** The bridge to the Data Flow engine where actual data extraction, transformation, and loading occur in memory.
- **Execute SQL Task:** Runs T-SQL statements (e.g., `TRUNCATE TABLE`, `MERGE`). Highly flexible (supports dynamic queries).
- **File System Task:** Manages files on disk (copy, move, delete). Useful for archiving processed CSVs.
- **Send Mail Task:** Sends email notifications, often used in error handling workflows.
- **Script Task (C#/VB.NET):** Used for logic SSIS cannot do natively in the Control Flow (e.g., REST API calls, custom FTP handling).
- **For Each Loop Container:** Iterates over collections, such as processing every `.csv` file in a specific folder.

### Data Flow Components: Sources & Destinations

- **OLE DB Source/Destination:** Standard for SQL Server. _Best Practice:_ Use "Table or view - fast load" in the destination for bulk insert performance.
- **ADO NET Source/Destination:** Used for .NET providers, often necessary for cloud databases.
- **Flat File Source/Destination:** For reading/writing CSV/TXT files. Requires careful configuration of data types.
- **Excel Source:** Reads `.xlsx` files. Often requires data type casting (`Data Conversion`) because Excel guesses column types.
- **XML Source:** Parses hierarchical XML into tabular rows.

### Key Transformations

- **Lookup:** Compares incoming rows to a reference table (like `LEFT JOIN` or `VLOOKUP`). Extremely fast in "Full Cache" mode.
- **Conditional Split:** Routes rows to different paths based on logic (`IF/ELSE` or `SWITCH`).
- **Derived Column:** Creates new columns or modifies existing ones using expressions (e.g., concatenating strings, math).
- **Data Conversion:** Safely casts data types (e.g., converting Flat File strings to `INT` or `DECIMAL`).
- **Pivot / Unpivot:** Pivot turns rows into columns; Unpivot normalizes wide columns back into rows.
- **Sort / Aggregate:** Grouping and ordering data. _Warning:_ These are **Blocking** transformations. They hold all data in RAM before proceeding, making them very slow. Push this logic to SQL whenever possible.
- **Fuzzy Grouping / Lookup:** Uses algorithms to find approximate matches (e.g., catching spelling mistakes) for data cleansing.

### Error Handling in Data Flows

- **Error Outputs:** When a component fails (e.g., data truncation), you can configure the error output instead of failing the whole package.
  - _Fail Component:_ Default. Stops execution.
  - _Ignore Failure:_ Skips the bad data and continues.
  - _Redirect Row:_ Sends the bad row down a red path to an error table.
- **ErrorCode & ErrorColumn:** SSIS automatically appends these two columns to redirected rows so you know exactly why and where the failure occurred.

### Connection Managers and External Metadata

- **Connection Managers:** Establish connections to external sources. They can be scoped at the **Project Level** (shared across all packages) or **Package Level**.
- **External Metadata:** SSIS takes an offline snapshot of the source/destination schema to validate data types before running.
- **DelayValidation:** Setting this to `True` tells SSIS to skip checking external metadata at startup. Useful if a destination table is created dynamically by an `Execute SQL Task` at runtime.

### End-to-End ETL Data Validation Methods

1.  **Pre-Load (Source):** Check row counts match source extract. Validate no NULLs in mandatory fields.
2.  **During Load (Transform):** Monitor Lookup failures (referential integrity). Detect duplicates using `ROW_NUMBER()`.
3.  **Post-Load (Destination):** Reconcile final row counts. Compare checksums (e.g., `SUM(Amount)` in source = target). Route rejected rows to an `ErrorLog` table.

### Slowly Changing Dimensions (SCD)

- **Type 1 (Overwrite):** Updates existing record. Keeps no history.
- **Type 2 (Add New Row):** Keeps old row (marks `IsActive = 0`), inserts new row with updated values and new `EffectiveDate`. Keeps full history.
- **Performance Note:** Do **not** use the built-in SCD Wizard for large datasets (it processes row-by-row). Instead, use a **Lookup** to identify new vs. changed records, stage them, and use a SQL `MERGE` or batch `UPDATE/INSERT` for performance.

---

## 2. Data Modeling & Warehousing

### Difference between OLAP and OLTP

| Feature        | OLTP (Online Transactional Processing)       | OLAP (Online Analytical Processing)        |
| :------------- | :------------------------------------------- | :----------------------------------------- |
| **Purpose**    | Day-to-day transactions (inserts/updates)    | Historical analysis and reporting          |
| **Schema**     | Highly normalized (3NF) to prevent anomalies | Denormalized (Star Schema) for fast reads  |
| **Query Type** | Simple, fast, single-row                     | Complex aggregations over millions of rows |

### Schema Types

- **Star Schema:** 1 Fact table surrounded by fully denormalized Dimension tables. The standard and most performant model for BI tools like Power BI.
- **Snowflake Schema:** Dimension tables are normalized into sub-tables. Saves disk space but requires more `JOIN`s, leading to slower read performance.
- **Galaxy Schema (Fact Constellation):** Multiple Fact tables that share the same "Conformed Dimensions" (e.g., `FactSales` and `FactInventory` both joining to the same `DimDate` and `DimProduct`).

---

## 3. BI Tools & Data Cleansing

### Power BI Usage, Dashboards, & Storage Modes

- **Import Mode:** Data is compressed into Power BI's memory engine (VertiPaq). Fastest performance, standard for most dashboards.
- **DirectQuery:** Sends SQL queries directly back to the database in real-time. Good for massive datasets but slower UI performance.
- **Evaluation Contexts (DAX):**
  - _Filter Context:_ Filters applied from slicers/visuals before calculation.
  - _Row Context:_ Iterating row-by-row (e.g., Calculated Columns).
  - _Context Transition:_ Using `CALCULATE()` to turn a Row Context into a Filter Context.

### Data Cleansing, Profiling, and Visualization Practices

- **SSIS Data Profiling Task:** Used in the Control Flow to analyze source data quality (checking for NULL counts, pattern matching, value distribution) before ETL processing begins.
- **VertiPaq Cardinality:** Power BI's memory engine compresses data by finding repeating values. Columns with high cardinality (many unique values, like exact milliseconds) ruin compression. _Practice:_ Split `DateTime` into separate `Date` and `Time` columns.
- **Advanced Deduplication:** Establish a "Golden Record" hierarchy rather than blindly deleting duplicates. For example, business rules might dictate that CRM data is more trustworthy than Marketing system data when merging duplicate customers.
- **Shift Left:** If you find yourself writing highly complex string manipulation DAX in Power BI, push that logic "left" into the SQL Database / ETL layer for better performance.
