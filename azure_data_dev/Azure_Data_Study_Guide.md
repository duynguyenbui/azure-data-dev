# Azure Data Stack Study Guide: Data Factory, Synapse, and DevOps

This document is designed to help you master the core Azure Data components essential for a SQL Developer / Data Engineer role. It focuses on **Azure Data Factory (ADF)**, **Azure Data Warehousing (Azure Synapse Analytics)**, and **Azure DevOps** for CI/CD in data projects.

---

## 1. Azure Data Factory (ADF)

_ADF is a cloud-based data integration service that allows you to create data-driven workflows for orchestrating and automating data movement and data transformation._

### Core Concepts You Must Know

- **Linked Services:** These are connection strings. They define the connection information needed for ADF to connect to external resources (e.g., Azure SQL DB, Amazon S3, On-Premise SQL Server).
- **Datasets:** Represent the structure of the data within the linked data stores (e.g., a specific table in a SQL Database or a specific CSV file in Blob Storage).
- **Activities:** The processing steps in a pipeline.
  - _Data Movement:_ Copy Activity.
  - _Data Transformation:_ Mapping Data Flows, Databricks Notebook execution, Stored Procedure activity.
  - _Control Flow:_ ForEach, If Condition, Filter, Get Metadata, Lookup.
- **Pipelines:** A logical grouping of activities that perform a task together.
- **Integration Runtime (IR):** The compute infrastructure used by ADF to provide data integration capabilities.
  - _Azure IR:_ Fully managed, serverless compute in Azure.
  - _Self-Hosted IR (SHIR):_ Installed on an on-premises machine or a VM inside a VNet to access resources behind a firewall.
  - _Azure-SSIS IR:_ Used to lift and shift existing SSIS packages to Azure.

### Key Interview Topics

- **Copy Activity vs. Mapping Data Flows:** Copy Activity is just for moving data (EL in ELT). Data Flows provide a visual interface for complex transformations (ETL) and run on Apache Spark clusters under the hood.
- **Handling Incremental Loads (Delta Loads):** How do you only load new/updated data? (Using Watermark columns, `GetMetadata` activity, and `Lookup` activity to get the last load time).
- **Triggers:** How pipelines are executed (Schedule, Tumbling Window, Event-based like Blob arrival).

---

## 2. Azure Data Warehousing (Azure Synapse Analytics - Dedicated SQL Pool)

_Formerly SQL Data Warehouse. It's an enterprise data warehousing platform that uses a Massively Parallel Processing (MPP) architecture to run complex queries across petabytes of data quickly._

### Core Concepts You Must Know

- **MPP Architecture:** Unlike SMP (Symmetric Multiprocessing - like standard SQL Server), MPP distributes processing across multiple compute nodes.
  - _Control Node:_ The brain. Client apps connect here. It optimizes and coordinates queries.
  - _Compute Nodes:_ Provide the computational power. Data is stored here.
  - _Data Movement Service (DMS):_ Moves data between compute nodes when necessary to execute parallel queries.
- **Table Distributions (CRITICAL for performance):**
  - _Hash Distribution:_ Distributes rows based on a hashing algorithm applied to a single column. Excellent for large fact tables. (Rule of thumb: Hash on a column that is frequently used in joins or aggregations, doesn't have data skew, and has many distinct values).
  - _Round-Robin:_ Distributes data evenly and randomly. Good for staging tables.
  - _Replicate:_ Caches a full copy of the table on _every_ compute node. Excellent for small dimension tables to avoid data movement during joins.
- **Indexing Strategies:**
  - _Clustered Columnstore Index (CCI):_ The default and recommended index for large tables. It offers the highest level of data compression and query performance.
  - _Heap:_ Good for fast data loading (staging tables).
  - _Clustered/Non-Clustered Indexes:_ Traditional row-store indexes, used for highly selective single-row lookups.

### Key Interview Topics

- **PolyBase vs. COPY Command:** Best practices for loading data into Synapse. The `COPY` command is the newer, more flexible, and faster way to load data from Azure Blob/Data Lake compared to PolyBase.
- **CETAS (Create External Table As Select):** Used to export data from Synapse to Azure Data Lake Storage or to transform data externally.
- **Result Set Caching:** Synapse can cache the results of a query. If the same query is run again and the underlying data hasn't changed, it returns the cached result instantly (0 compute used).

---

## 3. Azure DevOps for Data Projects

_Bringing software engineering best practices (CI/CD) to data engineering._

### Core Concepts You Must Know

- **Azure Repos:** Git repositories for source control.
- **Azure Pipelines:** CI/CD pipelines defined usually via YAML (or classic visual designer) to build, test, and deploy code.
- **Azure Boards:** Agile project management (Kanban boards, sprints, epics, issues).

### CI/CD for Azure Data Factory

1.  **Git Integration:** ADF is connected to an Azure DevOps Git repo. Developers work in feature branches and create Pull Requests into the `main` (or `collaboration`) branch.
2.  **ARM Templates:** When code is merged to `main`, ADF automatically generates an Azure Resource Manager (ARM) template and saves it in a hidden branch called `adf_publish`.
3.  **Release Pipeline:** An Azure Pipeline is triggered by changes to the `adf_publish` branch. It takes the ARM template and deploys it to higher environments (QA, UAT, Prod).
4.  **Parameterization:** Connection strings and environment-specific variables are parameterized in the ARM template so they can be overridden during deployment (e.g., changing the SQL Server name from DEV to PROD).

### CI/CD for SQL Databases / Synapse

1.  **SSDT (SQL Server Data Tools) Projects:** The database schema is stored as code (`.sql` files) in a Visual Studio Database Project.
2.  **DACPAC:** The CI pipeline builds the SSDT project into a `.dacpac` (Data-Tier Application Package) artifact.
3.  **Deployment:** The CD pipeline uses a task (like `SqlAzureDacpacDeployment`) to deploy the `.dacpac` to the target database. The DACPAC deployment engine compares the desired state (in the dacpac) with the current state (in the DB) and generates/executes the necessary `ALTER` scripts.
4.  _Alternative:_ Migration-based approaches like Flyway or DbUp, where you write explicit versioned SQL scripts (e.g., `V1__Create_Tables.sql`, `V2__Add_Column.sql`).

---

## 4. Hands-on Practice / Interview Scenarios to Master

**Scenario 1: End-to-End Pipeline**

- **Task:** How would you ingest daily sales data from an on-premise SQL Server, transform it, and load it into an Azure Synapse Data Warehouse?
- **Answer Strategy:**
  1.  Install a Self-Hosted Integration Runtime on-prem.
  2.  Use ADF Copy Activity to extract data incrementally (using a watermark) to Azure Data Lake Storage (ADLS Gen2) in Parquet format.
  3.  Use the `COPY INTO` command (via a Stored Procedure activity in ADF) to load the Parquet files from ADLS into a Round-Robin staging table in Synapse.
  4.  Run a Stored Procedure in Synapse to merge (upsert) the data from the staging table into the final Hash-Distributed Fact table.

**Scenario 2: Performance Troubleshooting in Synapse**

- **Task:** A query joining a Fact table and a Dimension table is running very slowly in Synapse. How do you fix it?
- **Answer Strategy:** Check the execution plan (using `DBCC PDW_SHOWEXECUTIONPLAN` or `sys.dm_pdw_request_steps`). Look for **Data Movement Operations** (like `ShuffleMove` or `BroadcastMove`). If a dimension table is being shuffled, change its distribution from Hash/Round-Robin to **Replicate**.

**Scenario 3: CI/CD Strategy**

- **Task:** How do you ensure a new linked service in ADF doesn't break production when deployed?
- **Answer Strategy:** Explain Git integration. Developers create a branch, test locally in the DEV ADF environment. Create a PR for code review. Once merged, the release pipeline deploys the ARM template. CRITICALLY: We use ARM template parameters to override the Linked Service credentials to point to the Production database instead of DEV during the release phase, often integrating with **Azure Key Vault** so passwords aren't stored in plain text.
