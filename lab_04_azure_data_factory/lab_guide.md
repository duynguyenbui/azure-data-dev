# Hướng dẫn Lab 04: Enterprise Azure Data Engineering: Real-World ELT & Medallion Architecture

If you want to understand how Azure Data Factory is used in **real-life enterprise environments**, this is the definitive lab. We will move beyond simple copies and build a robust, production-grade **ELT (Extract, Load, Transform)** pipeline implementing the **Medallion Architecture** (Bronze, Silver, Gold).

## Why Are We Building This? (The Business Scenario)

Every day, employees update customer records in a source ERP database (`Source.Customer`). They might fix a typo in a name, change an email address, or add brand new customers.

The Business Intelligence (BI) team needs all of this updated data in the Data Warehouse (`DWH.DimCustomer`) to build dashboards. However, you can't just blindly copy and paste the entire table every day—that would create millions of duplicate records.

The purpose of this pipeline is to orchestrate a highly efficient ELT process to solve this problem:

1. **Extract to Bronze (Data Lake):** Grab the raw data from the SQL source and dump it into a Parquet file for immutable, high-speed backup.
2. **Load to Silver (Staging):** Load that Parquet file into a temporary `Staging` table in the Data Warehouse.
3. **Transform to Gold (The Upsert):** Run a SQL `MERGE` statement to compare the temporary staging data against the final `Gold` table, updating existing customers and inserting new ones without creating duplicates.
4. **Operational Auditing:** Log the exact start time, end time, and success/failure status into a tracking table so data engineers have a permanent record if anything breaks.

## Real-World Enterprise Requirements

In the real world, you don't just move data from A to B. You must:

1. **Secure Credentials:** Never hardcode passwords. We will use **Azure Key Vault**.
2. **Layered Data (Medallion):**
   - **Bronze (Raw):** Extract data from operational systems to a Data Lake (Parquet format).
   - **Silver (Staging):** Load Data Lake files into a staging table in the Data Warehouse.
   - **Gold (Serving):** Execute a SQL `MERGE` (UPSERT) to integrate data into the final Dimension/Fact tables.
3. **Audit Logging:** Every pipeline must log when it starts, succeeds, or fails into a central Audit table, capturing exact error messages.

---

## Phase 1: Enterprise Infrastructure & Security

### Step 1: Resource Group & Key Vault

> **Purpose:** Resource Groups act as a logical container to manage and delete all related lab resources together. Azure Key Vault securely stores sensitive credentials (like database passwords) so they are never hardcoded in pipelines or code—a mandatory enterprise security practice.

**1. Create the Resource Group**

- Log in to [portal.azure.com](https://portal.azure.com).
- In the top search bar, type **Resource groups** and select it from the dropdown.
- Click the **+ Create** button (usually top left).
- **Subscription:** Select your active subscription.
- **Resource group:** Type `rg-enterprise-data-001`.
- **Region:** Select a region close to you (e.g., _East US_).
- Click **Review + create** at the bottom, then click **Create**.

**2. Create the Key Vault**

> **What is Key Vault?** Azure Key Vault is a highly secure, encrypted digital safe in the cloud. Instead of typing your SQL database password directly into Data Factory (where anyone could read it), you save the password inside the Key Vault as a "Secret". Later, Data Factory will secretly retrieve the password from here at runtime to connect to your database. This prevents passwords from leaking in your code.

- In the top search bar, type **Key vaults** and select it.
- Click **+ Create**.
- **Subscription:** Select your subscription.
- **Resource group:** Select the `rg-enterprise-data-001` you just created.
- **Key vault name:** Type a globally unique name (e.g., `kv-entdata-001nbui` - _Note: it must be unique across all of Azure, so add some numbers/initials_).
- **Region:** Match your resource group region.
- **Pricing tier:** Standard.
- Click **Review + create**, wait for validation, and click **Create**.

**3. Add the Secret to Key Vault**

> **What is IAM (Identity and Access Management)?** IAM is the framework Azure uses to control who can do what. Even if you _created_ the Key Vault, Azure's strict security model (RBAC) doesn't automatically give you permission to view or create the _secrets inside it_. You must explicitly assign yourself a role to manage the actual data inside the vault.

**Step 3a: Assign Yourself Permission (IAM)**

- Once the deployment is complete, click **Go to resource** to open your Key Vault.
- In the left-hand menu, near the top, click on **Access control (IAM)**.
- Click the **+ Add** button at the top of the page, then select **Add role assignment**.
- In the "Job function roles" list, search for and select **Key Vault Secrets Officer**. Click **Next**.
- Under "Assign access to", ensure **User, group, or service principal** is selected.
- Click **+ Select members**. Search for your own email address/name (the account you are logged in with), click it, and click **Select**.
- Click **Review + assign** at the bottom, and then **Review + assign** again to confirm.
- **CRITICAL:** Wait 3 to 5 minutes for Azure to propagate this new security rule before proceeding.

**Step 3b: Create the Secret**

- In the Key Vault's left-hand menu, scroll down to the **Objects** section and click **Secrets**.
- Click **+ Generate/Import** at the top.
- **Upload options:** Manual.
- **Name:** Type `sql-admin-password`.
- **Value:** Type your strong password (e.g., `P@ssw0rd123!!`).
- Click **Create** at the bottom.

### Step 2: Azure Data Lake Storage Gen2 (Bronze Layer)

> **Purpose:** ADLS Gen2 provides massively scalable, cost-effective storage with a hierarchical directory structure. It acts as the "Bronze" layer in our Medallion Architecture, storing raw, unprocessed data exactly as extracted from the source systems.

**1. Create the Storage Account**

- In the top search bar, type **Storage accounts** and select it.
- Click **+ Create**.
- **Resource group:** Select `rg-enterprise-data-001`.
- **Storage account name:** Type a globally unique name, lowercase letters and numbers only (e.g., `stdatalake001nbui`).
- **Region:** Match your previous region.
- **Performance:** Standard.
- **Redundancy:** Select **Locally-redundant storage (LRS)** to save costs for this lab.
  > **Understanding Redundancy:** Redundancy dictates how Azure backs up your data to prevent data loss.
  >
  > - **LRS (Locally-Redundant):** 3 copies stored inside the same physical building. Cheapest option, perfect for labs.
  > - **ZRS (Zone-Redundant):** 3 copies spread across 3 different physical buildings in the same city. Enterprise standard for high availability.
  > - **GRS (Geo-Redundant):** Copies data to a completely different geographic region hundreds of miles away. Enterprise standard for disaster recovery.

**2. Enable Hierarchical Namespace (The ADLS Gen2 secret)**

> **What is Hierarchical Namespace?** By default, standard Azure Blob Storage is "flat"—it doesn't have real folders (it just fakes them by putting slashes in file names). Enabling "Hierarchical Namespace" upgrades the storage into a true Data Lake. It creates a real file system with actual directories. This is mandatory for Big Data tools (like Databricks or Synapse) because it allows them to move or rename massive folders instantly and lets you set strict security permissions on specific folders.

- Click the **Next: Advanced >** button at the bottom of the screen.
- Scroll down to the **Data Lake Storage Gen2** section.
- Check the box for **Enable hierarchical namespace**. _(This is the critical step that turns regular Blob storage into a true Data Lake)._
- Click **Review**, then click **Create**.

**3. Create the Bronze Container**

- Once deployed, click **Go to resource**.
- In the left-hand menu under **Data storage**, click **Containers**.
- Click **+ Container** at the top.
- **Name:** Type `bronze-raw`.
- **Public access level:** Leave as Private (no anonymous access).
- Click **Create**.

> **Concept Check: Storage Accounts vs. Containers**
>
> - **Storage Account:** Think of a Storage Account as a massive, limitless external hard drive provided by Microsoft in the cloud. It is the top-level resource that acts as the physical home for your data.
> - **Container:** Inside the Storage Account, a "Container" acts exactly like a root partition or a master folder on your hard drive (similar to the `C:\` or `D:\` drive). You cannot upload files directly into a Storage Account; you must create a Container first to hold them. In Step 2, we created the `bronze-raw` container to act as the master root folder for all of our raw, unprocessed data.

### Step 3: Azure SQL Database (Source & Data Warehouse)

> **Purpose:** Azure SQL acts as both our operational ERP source system and our target Data Warehouse (Silver/Gold layers) for this lab. It provides a powerful relational engine to transform data via Stored Procedures and serve it cleanly to BI tools.

_To save costs in this lab, we will use a single Azure SQL Database to act as BOTH our Source ERP system and our Target Data Warehouse._

**1. Create the Database and Server**

- In the top search bar, type **SQL databases** and select it.
- Click **+ Create**.
- **Resource group:** Select `rg-enterprise-data-001`.
- **Database name:** Type `sqldb-enterprise-001`.
- **Server:** Click the **Create new** link below the dropdown.
  - **Server name:** Type a globally unique name (e.g., `sqlserver-ent-001nbui`).
  - **Location:** Match your previous region.
  - **Authentication method:** Select **Use SQL authentication**.
  - **Server admin login:** Type `sqladmin`.
  - **Password:** Type the exact password you stored in your Key Vault earlier (`P@ssw0rd123!!`).
  - **Confirm password:** Retype it.
  - Click **OK**.

**2. Configure Compute & Backups to Save Costs**

- Back on the main database creation screen, under _Compute + storage_, click **Configure database**.
- Click on the **Looking for basic, standard, premium?** link (or dropdown menu, depending on the portal UI update).
- Select the **Basic** tier (This is the DTU-based basic model, which usually costs ~$5/month).
- Click **Apply**.
- **Backup storage redundancy:** Scroll down slightly on the main page and select **Locally-redundant backup storage** (This saves money for the lab. Geo-redundant is used in the enterprise to recover data if an entire region goes down).

**3. Configure Networking & Data**

- Click **Next: Networking >** at the bottom.
- **Connectivity method:** Select **Public endpoint**.
- **Allow Azure services and resources to access this server:** Select **Yes**. _(CRITICAL: Without this, Azure Data Factory won't be able to connect to the database later)._
- **Add current client IP address:** Select **Yes**. _(This allows you to run the SQL scripts in Phase 4 from your own computer or the Azure Portal Query Editor)._
- Click **Next: Security >**, then click **Next: Additional settings >**.
- Under **Use existing data**, ensure **None** is selected.
- Click **Review + create**, then click **Create**.

---

## Phase 4: Create the Real-Life Data & Schemas

> **Purpose:** To simulate a real-world environment by setting up an operational source table, a staging table (Silver layer), a dimension table (Gold layer), and an audit log table to capture pipeline execution history.

We need tables to represent our Source, our Staging, our Gold Dimension, and our Auditing.

1. In the Azure Portal, go to your SQL Database -> **Query editor**. Log in.
2. Run the following SQL script to build the entire enterprise architecture:

```sql
-- 1. Create Architectural Schemas
CREATE SCHEMA Source;
GO
CREATE SCHEMA Audit;
GO
CREATE SCHEMA Staging;
GO
CREATE SCHEMA DWH;
GO

-- 2. Source Operational Data (The ERP System)
CREATE TABLE Source.Customer (
    CustomerID INT PRIMARY KEY,
    FullName VARCHAR(100),
    Email VARCHAR(100),
    LastModified DATETIME DEFAULT GETDATE()
);
INSERT INTO Source.Customer (CustomerID, FullName, Email) VALUES
(1, 'John Doe', 'john@email.com'),
(2, 'Jane Smith', 'jane@email.com');

-- 3. The Audit Table (For Pipeline Logging)
CREATE TABLE Audit.PipelineLogs (
    LogID INT IDENTITY(1,1),
    PipelineName VARCHAR(100),
    RunId VARCHAR(100),
    Status VARCHAR(20),
    StartTime DATETIME DEFAULT GETDATE(),
    EndTime DATETIME,
    ErrorMessage VARCHAR(MAX)
);

-- 4. Silver Layer: Staging Table
CREATE TABLE Staging.Customer (
    CustomerID INT,
    FullName VARCHAR(100),
    Email VARCHAR(100)
);

-- 5. Gold Layer: Target Dimension Table
CREATE TABLE DWH.DimCustomer (
    CustomerKey INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT,
    FullName VARCHAR(100),
    Email VARCHAR(100),
    InsertedDate DATETIME DEFAULT GETDATE(),
    UpdatedDate DATETIME DEFAULT GETDATE()
);
```

### Create the Stored Procedures

Run this script to create the logging and UPSERT logic:

```sql
-- Proc 1: Update the Audit Log
CREATE PROCEDURE Audit.usp_LogPipeline
    @PipelineName VARCHAR(100),
    @RunId VARCHAR(100),
    @Status VARCHAR(20),
    @ErrorMessage VARCHAR(MAX) = NULL
AS
BEGIN
    IF @Status = 'Running'
        INSERT INTO Audit.PipelineLogs (PipelineName, RunId, Status, StartTime)
        VALUES (@PipelineName, @RunId, @Status, GETDATE());
    ELSE
        UPDATE Audit.PipelineLogs
        SET Status = @Status, EndTime = GETDATE(), ErrorMessage = @ErrorMessage
        WHERE RunId = @RunId;
END;
GO

-- Proc 2: The ELT MERGE (UPSERT)
CREATE PROCEDURE DWH.usp_UpsertCustomer AS
BEGIN
    -- Merge Staging data into the Gold Dimension
    MERGE DWH.DimCustomer AS Target
    USING Staging.Customer AS Source
    ON (Target.CustomerID = Source.CustomerID)

    -- If customer exists, update them
    WHEN MATCHED THEN
        UPDATE SET Target.FullName = Source.FullName, Target.Email = Source.Email, Target.UpdatedDate = GETDATE()

    -- If customer is new, insert them
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (CustomerID, FullName, Email) VALUES (Source.CustomerID, Source.FullName, Source.Email);

    -- Clean out staging for the next run
    TRUNCATE TABLE Staging.Customer;
END;
```

---

## Phase 5: Build the Enterprise Data Factory

> **Purpose:** Azure Data Factory (ADF) is the cloud-based ETL and data integration service that allows you to create data-driven workflows for orchestrating data movement and transforming data at scale.

**1. Create the Azure Data Factory**

- In the top search bar of the Azure Portal, type **Data factories** and select it.
- Click **+ Create**.
- **Subscription:** Select your subscription.
- **Resource group:** Select `rg-enterprise-data-001`.
- **Name:** Type a globally unique name (e.g., `adf-enterprise-001nbui`).
- **Region:** Match your previous region.
- **Version:** Leave it as V2.
- Click **Next: Git configuration >**.
- Check the box for **Configure Git later** (For this lab, we will use the live mode to keep it simple, but in an enterprise environment, you would always link this to an Azure DevOps or GitHub repository).
- Click **Review + create**, then click **Create**.

**2. Launch ADF Studio**

- Once the deployment completes, click **Go to resource**.
- In the center of the Data Factory overview page, click the **Launch studio** button.
- This will open a new browser tab for the Azure Data Factory Studio, which is the dedicated UI where you will build all your pipelines.

### Step 5a: Grant Data Factory Access to Key Vault (IAM)

> **Why did you get a 'Forbidden' error?** Even though _you_ have access to the Key Vault, your Data Factory does not. Azure services use "Managed Identities" (which act like invisible service accounts) to talk to each other securely. We must explicitly grant your Data Factory permission to read secrets from the Key Vault.

1. Go back to your main Azure Portal tab (leave ADF Studio open).
2. Navigate to your Key Vault (`kv-entdata-001nbui`).
3. Click on **Access control (IAM)** in the left menu.
4. Click **+ Add** -> **Add role assignment** at the top.
5. Search for and select the **Key Vault Secrets User** role (this grants read-only access to secrets, which is all ADF needs) and click **Next**.
6. Under "Assign access to", select **Managed identity**.
7. Click **+ Select members**.
   - **Subscription:** Select your subscription.
   - **Managed identity:** Select **Data Factory (V2)**.
   - Select your Data Factory (`adf-enterprise-001nbui`) from the list and click **Select**.
8. Click **Review + assign**, and then **Review + assign** again.
9. **CRITICAL:** Wait 2 to 3 minutes for Azure's security system to propagate this new rule before testing the connection in Data Factory.

### Step 5b: Secure Linked Services via Key Vault

> **Purpose:** Linked Services are the "connection strings" of Data Factory. By integrating them with Key Vault, ADF securely retrieves passwords at runtime without exposing them to developers or saving them in the ADF portal.

1. In ADF Studio, go to the **Manage** hub (toolbox icon on the far left) -> **Linked services** -> **New**.
2. **Azure Key Vault:** Create a linked service to your Key Vault. Name it `ls_akv`. Select your subscription and Key Vault. Create it.
3. **Azure SQL Database:** Create a new linked service. Name it `ls_sql_enterprise`.
   - Server & Database: Select your resources.
   - User name: `sqladmin`.
   - **Password type:** Select **Azure Key Vault**.
   - AKV linked service: Select `ls_akv`.
   - Secret name: `sql-admin-password`.
   - Click Test Connection and Create. _(This is how professionals secure databases!)_
4. **Azure Data Lake Storage Gen2:** Create a linked service. Name it `ls_adls_gen2`. Point it to your storage account.

### Step 5c: Create Datasets

> **Purpose:** Datasets represent the structural view of your data.
>
> **Concept Check: What is a Parameterized Dataset?**
> Normally, if you have 100 tables in your database, you would have to manually create 100 different datasets in ADF. That is terrible for maintenance!
> Instead, we are creating a single "blank template" dataset. By creating **Parameters** (`SchemaName` and `TableName`), we are creating empty variables.
> When we map those variables using **Dynamic Content** (like `@dataset().TableName`), we are telling Data Factory: _"Don't hardcode a specific table name here. Wait until the pipeline actually runs, and I will pass the exact table name to you on the fly."_

**1. Create a Parameterized SQL Dataset**

- In ADF Studio, look at the far left menu and click the **Author** hub (the pencil icon).
- Hover over **Datasets**, click the **...** (Actions menu), and select **New dataset**.
- Search for **Azure SQL Database**, click it, and click **Continue**.
- **Name:** Type `ds_sql_table`.
- **Linked service:** Select `ls_sql_enterprise` (the one you created earlier).
- **Table name:** Leave this completely blank for now. Click **OK**.
- With the new `ds_sql_table` open on your screen, click the **Parameters** tab at the bottom.
- Click **+ New** twice to create two parameters:
  - First Parameter Name: `SchemaName` (Type: String)
  - Second Parameter Name: `TableName` (Type: String)
- Now, click the **Connection** tab at the bottom.
- Under the "Table" section, check the box that says **Enter manually** (some older versions of ADF say **Edit**).
- Two text boxes will appear. Click inside the first box (Schema), a blue link will appear saying **Add dynamic content [Alt+P]**. Click it.
- In the dynamic content window, click on your `SchemaName` parameter. It will insert `@dataset().SchemaName`. Click **OK**.
- Repeat for the second box (Table). Click **Add dynamic content**, select `TableName`, which inserts `@dataset().TableName`, and click **OK**.

**2. Create a Parquet Dataset (Data Lake)**

- Hover over **Datasets** on the left menu again, click **...** -> **New dataset**.
- Search for **Azure Data Lake Storage Gen2**, select it, and click **Continue**.
- Format: Select **Parquet** and click **Continue**.
- **Name:** Type `ds_adls_parquet`.
- **Linked service:** Select `ls_adls_gen2`.
- **File path:** You will see three text boxes side-by-side.
  - First box (**File system**): Type `bronze-raw` (this is your container).
  - Second box (**Directory**): Leave this completely blank.
  - Third box (**File**): Type `customer_extract.parquet`. _(Note: It is completely fine that this file doesn't exist yet! Because this dataset will be used as a destination, Data Factory will create the file automatically when the pipeline runs)._
- Click **OK**.

> **Troubleshooting 'PathNotFound' Error:**
> If you test the connection and get an error saying `ErrorCode: 'PathNotFound'`, it means you forgot to create the container in Phase 1! The Data Factory is trying to look inside a folder that doesn't physically exist. To fix this, go to your Storage Account in the Azure Portal, click **Containers** on the left menu, and create a container named exactly `bronze-raw`. Then test again!

---

## Phase 6: The Master ELT Pipeline Architecture

> **Purpose:** To orchestrate the entire ELT workflow. This pipeline extracts raw data to the lake (Bronze), loads it into staging (Silver), executes an UPSERT (Gold), and logs the success or failure of the process for operational monitoring.

Create a new pipeline named `PL_Enterprise_ELT_Customer`.

**1. Log Pipeline Start (Stored Procedure)**

- Drag a **Stored procedure** activity. Name: `LogStart`.
- Linked service: `ls_sql_enterprise`. Stored proc: `[Audit].[usp_LogPipeline]`.
- Parameters:
  - `PipelineName`: `@pipeline().Pipeline`
  - `RunId`: `@pipeline().RunId`
  - `Status`: `Running`

**2. Extract Source to Bronze Data Lake (Copy Activity)**

> **Purpose:** The Copy Activity is the workhorse of ADF. Here, we configure it to read data from our SQL source and write it as a highly-compressed Parquet file into our Bronze Data Lake container.

- In the Activities pane on the far left, expand the **Move and transform** category.
- Drag a **Copy data** activity onto the canvas.
- **General Tab (Bottom Pane):**
  - Change the **Name** to `ExtractToBronze`.
- **Connect the Activities:** Click the small green square (Success constraint) on the right side of the `LogStart` activity, and drag the line to connect it to the `ExtractToBronze` activity.
- **Source Tab:**
  - Click on the `ExtractToBronze` activity, then click the **Source** tab at the bottom.
  - **Source dataset:** Select your SQL dataset (`ds_sql_table`).
  - Because we parameterized this dataset earlier, two new text boxes will appear below it asking for the dataset property values.
  - **SchemaName:** Type `Source`.
  - **TableName:** Type `Customer`.
- **Sink Tab:**
  - Click the **Sink** tab.
  - **Sink dataset:** Select your Data Lake Parquet dataset (`ds_adls_parquet`).

**3. Load Bronze to Silver Staging (Copy Activity)**

- Drag a **Copy data** activity. Name: `LoadToSilver`. Draw a green line from `ExtractToBronze` to `LoadToSilver`.
- **Source:** `ds_adls_parquet`.
- **Sink:** `ds_sql_table` (Schema: `Staging`, Table: `Customer`).
- Under Sink settings, check **Auto create table** (optional, but good practice).

**4. Transform Silver to Gold (Stored Procedure)**

- Drag a **Stored procedure**. Name: `UpsertToGold`. Draw a green line from `LoadToSilver` to `UpsertToGold`.
- Linked service: `ls_sql_enterprise`. Stored proc: `[DWH].[usp_UpsertCustomer]`.

**5. Log Success (Stored Procedure)**

- Drag a **Stored procedure**. Name: `LogSuccess`. Draw a green line from `UpsertToGold` to `LogSuccess`.
- Parameters: `PipelineName`: `@pipeline().Pipeline`, `RunId`: `@pipeline().RunId`, `Status`: `Success`.

**6. Log Failure (Stored Procedure) - CRITICAL ERROR HANDLING**

- Drag a **Stored procedure**. Name: `LogFailure`.
- Draw a **RED line (Failure)** from `ExtractToBronze` to `LogFailure`. Draw red lines from `LoadToSilver` and `UpsertToGold` to `LogFailure` as well.
- Parameters:
  - `PipelineName`: `@pipeline().Pipeline`
  - `RunId`: `@pipeline().RunId`
  - `Status`: `Failed`
  - `ErrorMessage`: `@activity('ExtractToBronze').error.message` (You can make this dynamic based on which activity fails in real life).

---

## Phase 7: Test the Enterprise Flow

> **Purpose:** To validate the Medallion architecture by ensuring initial loads succeed, and subsequent runs correctly identify and update existing records (UPSERT) without creating duplicates, while maintaining an accurate audit trail.

### Test 1: The Initial Run

1. Click **Debug** in ADF.
2. Watch the steps execute sequentially. Once `LogSuccess` finishes, go to your SQL Database.
3. Run `SELECT * FROM DWH.DimCustomer`. You will see John Doe and Jane Smith.
4. Run `SELECT * FROM Audit.PipelineLogs`. You will see a beautiful log entry capturing the exact start and end time of your pipeline!

### Test 2: The UPSERT in Action

1. In SQL Query Editor, let's simulate the ERP system updating an email and adding a new user:
   ```sql
   UPDATE Source.Customer SET Email = 'john.doe@newcompany.com' WHERE CustomerID = 1;
   INSERT INTO Source.Customer (CustomerID, FullName, Email) VALUES (3, 'Alice Johnson', 'alice@email.com');
   ```
2. Go to ADF and click **Debug** again.
3. Once finished, query `DWH.DimCustomer`.
4. **Notice the magic:** John Doe's email is updated, Alice is added, and Jane remains untouched. The `UpdatedDate` for John reflects the exact time the `MERGE` statement ran!

Congratulations! You have built a true, production-ready Azure Data Factory ELT architecture.
