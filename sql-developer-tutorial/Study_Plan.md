# 2-Day Intensive Interview Prep Plan: SQL Developer at Innovature BPO

This plan is tailored specifically to the requirements mentioned in the Innovature BPO Job Description, focusing on the Microsoft BI Stack (SQL Server, SSIS, SSAS, Azure) and Data Warehousing concepts.

> **Goal:** You don't need to master everything from scratch in 2 days. The goal is to review key concepts, understand the architecture, prepare for common interview questions, and articulate your hands-on experience confidently.

## Day 0: Excellent in English Communidation

\_Create a markdown file to stimulate the conversation using English

- **👉 Read the Script:** [Day0_English_Interview_Simulation.md](Day0_English_Interview_Simulation.md)

---

## Day 1: Core Database, ETL, and Data Modeling (Saturday)

### Morning (8:00 AM - 12:00 PM): Advanced SQL & Database Objects

_The JD emphasizes "Advanced SQL knowledge" including stored procedures, functions, and triggers._

- **Stored Procedures vs. Functions:** Understand the differences (e.g., procedures can have output parameters and modify data; functions must return a value and cannot modify database state).
  - **👉 Read the Deep Dive:** [Day1_StoredProcs_vs_Functions.md](Day1_StoredProcs_vs_Functions.md)
- **Triggers:** Review `AFTER` and `INSTEAD OF` triggers. Understand the `inserted` and `deleted` virtual tables.
  - **👉 Read the Deep Dive:** [Day1_Triggers_DeepDive.md](Day1_Triggers_DeepDive.md)
- **Performance Tuning (Crucial):**
  - Indexes (Clustered vs. Non-clustered).
  - Execution plans (how to read them, identifying bottlenecks like table scans vs. index seeks).
  - Common Table Expressions (CTEs), Window Functions (`ROW_NUMBER()`, `RANK()`), and Temporary Tables vs. Table Variables.
  - **👉 Read the Deep Dive:** [Day1_PerformanceTuning_DeepDive.md](Day1_PerformanceTuning_DeepDive.md)
- **Action Item:** Practice writing a complex stored procedure that uses a CTE and window functions.

### Afternoon (1:00 PM - 4:00 PM): Data Warehousing & Data Modeling

_The JD mentions "understanding of data warehousing and data modelling."_

- **Concepts to review:**
  - OLTP vs. OLAP.
  - Star Schema vs. Snowflake Schema (Why Star Schema is optimized for SSAS).
  - Fact Tables vs. Dimension Tables (Surrogate keys vs Natural keys).
  - Slowly Changing Dimensions (SCD) - Focus on Type 1, Type 2, and Type 3.
  - **👉 Read the Deep Dive:** [Day1_DataModeling_DeepDive.md](Day1_DataModeling_DeepDive.md)
- **Action Item:** Be ready to draw/explain a simple Star Schema for a typical business process (e.g., Sales or Customer Service).

### Late Afternoon (4:30 PM - 7:30 PM): SSIS (Integration Services) & ETL Pipelines

_The JD mentions "Design, development, and maintenance of ETLs and data pipelines" using SSIS._

- **Core SSIS Components:** Control Flow vs. Data Flow.
- **Common Tasks:** Execute SQL Task, Data Flow Task, For Loop Container, Sequence Container.
- **Common Transformations:** Lookup, Derived Column, Conditional Split, Merge Join, Data Conversion.
- **Error Handling & Debugging:** How to handle bad data (redirect rows), logging, and event handlers.
- **👉 Read the Deep Dive:** [Day1_SSIS_ETL_DeepDive.md](Day1_SSIS_ETL_DeepDive.md)
- **👉 Read the Concept Guide:** [Innovature_ETL_End_to_End.md](Innovature_ETL_End_to_End.md) (Connecting SSIS concepts directly to the Job Description)
- **Action Item:** Prepare a story about a time you designed an ETL pipeline, how you handled data extraction, transformation rules, and loading strategies (incremental load vs. full load).

- **Connecting the Dots (SSAS & Azure):** Understanding how on-premise SSIS/SSAS maps to the Microsoft Azure Cloud Tech Stack (ADF, Synapse, DevOps) based on the JD.
  - **👉 Read the Deep Dive:** [Day1_SSAS_DAX_vs_MDX.md](Day1_SSAS_DAX_vs_MDX.md) (Understanding DAX vs MDX and Tabular vs Cubes)
  - **👉 Read the Deep Dive:** [Day2_Azure_SSAS_TechStack_DeepDive.md](Day2_Azure_SSAS_TechStack_DeepDive.md)

---

## Day 2: Cloud (Azure), Analytics, and Behavioral Prep (Sunday)

### Morning (8:00 AM - 11:30 AM): Microsoft Azure Data Stack

_The JD highlights "Azure Data Warehousing, Data Factory, and Azure DevOps."_

- **Azure Data Factory (ADF):**
  - Understand the modern equivalent of SSIS in the cloud.
  - Concepts: Pipelines, Activities, Datasets, Linked Services, Integration Runtimes (Self-hosted vs. Azure IR).
- **Azure Synapse Analytics (formerly SQL Data Warehouse):**
  - Understand Massively Parallel Processing (MPP) vs. traditional SMP.
  - Distribution types: Hash, Round-Robin, Replicate.
- **Azure DevOps:**
  - Basics of CI/CD for databases and pipelines (Repos, Pipelines, Boards).
- **Action Item:** Compare SSIS and Azure Data Factory conceptually. Be able to explain how you would migrate an on-prem SSIS package to Azure (using SSIS Integration Runtime in ADF).

### Afternoon (1:00 PM - 3:00 PM): SSAS, Reporting, and Basic Programming

_The JD mentions "SSAS" and "Basic C# or Python."_

- **SSAS (Analysis Services):**
  - Tabular models vs. Multidimensional models (focus more on Tabular as it's the modern standard).
  - DAX (Data Analysis Expressions) basics.
- **Reporting (Power BI):**
  - **👉 Read the Deep Dive:** [Day2_PowerBI_DeepDive.md](Day2_PowerBI_DeepDive.md)
  - Data visualization principles. How you ensure "data availability and accuracy" for reports.
- **Basic C#/Python:**
  - Review basic syntax. In an ETL context, Python is often used for scripting API data ingestion, and C# is used inside SSIS Script Tasks. Be able to explain how you've used either for automation or custom data transformations.

### Late Afternoon (3:30 PM - 6:30 PM): Behavioral & Situational Preparation

_The JD emphasizes being "highly organized", "attention to detail", and working in an "entrepreneurial environment"._

- **Prepare STAR Stories (Situation, Task, Action, Result):**
  - _Troubleshooting:_ "Tell me about a time you had to identify and resolve a data or reporting issue under pressure."
  - _Project Management:_ "Describe a time you managed multiple projects on interrelated timelines."
  - _Process Improvement:_ "How have you improved or automated a recurring process?"
- **Company Research:** Review the Innovature BPO website (https://innovatureinc.com), their core values, and their recent awards ("HR Asia Award"). Be ready to answer "Why Innovature BPO?"
- **Logistics:** Prepare your background, test your webcam/mic (since it's remote/hybrid, the interview will likely be on Teams or Zoom).

### Evening (7:00 PM onwards): Rest and Review

- Do a light review of your notes.
- Get a good night's sleep. Do not cram new information.

---

> **Key Interview Tip:** If you are asked a technical question you don't know the exact answer to, explain how you would find the answer or how you would troubleshoot the problem. They value "getting things done" and problem-solving skills highly.
