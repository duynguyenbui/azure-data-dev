# Databricks notebook source
# MAGIC %md
# MAGIC # Lab 14: Data Pipeline Design Principles - Idempotency & Schema Evolution
# MAGIC 
# MAGIC In this notebook, you will learn and implement the following core design principles for data pipelines:
# MAGIC 1. **Idempotency**: Ensuring that running the pipeline multiple times does not create duplicates.
# MAGIC 2. **Incremental Upsert (Merge)**: Handling late arriving data and status updates (Change Data Capture).
# MAGIC 3. **Audit Columns**: Incorporating system metadata for pipeline traceability.
# MAGIC 4. **Schema Evolution**: Managing schema drift when new source fields are added.

# COMMAND ----------

# CELL 1: Define Storage Account Paths
# Replace 'dlsstreaminglabdev001' with your actual storage account name
storage_account_name = "dlsstreaminglabdev001"
container_name = "pipeline-design-lab"

# Define raw landing paths for our batches
raw_base_path = f"abfss://{container_name}@{storage_account_name}.dfs.core.windows.net"

# Target Delta Table path (Silver Layer)
target_delta_path = f"{raw_base_path}/silver/orders"

# Print paths for verification
print(f"Target Delta Path: {target_delta_path}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Phase 1: Naive Ingestion (Non-Idempotent)
# MAGIC First, we will ingest Batch 1 (initial) and Batch 2 (duplicates) using standard `append` to see the duplicate record problem.

# COMMAND ----------

# CELL 2: Read Batch 1 and write to Delta Table
from pyspark.sql.functions import col, current_timestamp, input_file_name

# Schema for incoming JSON data
from pyspark.sql.types import StructType, StructField, StringType, DoubleType

json_schema = StructType([
    StructField("order_id", StringType(), True),
    StructField("customer_id", StringType(), True),
    StructField("order_date", StringType(), True),
    StructField("amount", DoubleType(), True),
    StructField("status", StringType(), True)
])

# Read Batch 1
df_batch_1 = spark.read \
    .schema(json_schema) \
    .json(f"{raw_base_path}/landing/batch_1_initial.json")

# Write Batch 1 to Delta Lake (creating the table)
df_batch_1.write \
    .format("delta") \
    .mode("append") \
    .save(target_delta_path)

print("Batch 1 written successfully.")

# COMMAND ----------

# CELL 3: Read and Append Batch 2 (Contains duplicates of ORD004 and ORD005)
df_batch_2 = spark.read \
    .schema(json_schema) \
    .json(f"{raw_base_path}/landing/batch_2_duplicates.json")

df_batch_2.write \
    .format("delta") \
    .mode("append") \
    .save(target_delta_path)

print("Batch 2 appended successfully.")

# COMMAND ----------

# CELL 4: Check for duplicates in the target table
# Let's count records and list details. We should have 5 + 4 = 9 records, but ORD004 and ORD005 are duplicates.
df_orders = spark.read.format("delta").load(target_delta_path)
df_orders.createOrReplaceTempView("orders_naive")

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Query 1: Check duplicate orders
# MAGIC SELECT order_id, COUNT(*) as count
# MAGIC FROM orders_naive
# MAGIC GROUP BY order_id
# MAGIC HAVING count > 1;

# COMMAND ----------

# MAGIC %md
# MAGIC ## Phase 2: Achieving Idempotency via Delta `MERGE` (Upsert)
# MAGIC Now we will wipe the table, add **Audit Columns**, and rewrite the ingestion using a `MERGE` statement to ensure that running duplicates does not create double records.

# COMMAND ----------

# CELL 5: Clean up the old directory to start fresh
dbutils.fs.rm(target_delta_path, recurse=True)
print("Cleared naive orders directory.")

# COMMAND ----------

# CELL 6: Implement Idempotent Ingestion Function
# This function will load a landing file and merge it into our Silver Delta Table.
# It also appends audit columns:
# - `_created_at`: timestamp when record first inserted
# - `_updated_at`: timestamp when record updated
# - `_source_file`: path of source file for traceability
# - `_hash_key`: md5 hash of core columns to detect changes if needed

from pyspark.sql.functions import current_timestamp, input_file_name, md5, concat_ws, lit

def ingest_batch_idempotent(file_path):
    # 1. Read landing data
    df_raw = spark.read.schema(json_schema).json(file_path)
    
    # 2. Add audit columns
    df_transformed = df_raw \
        .withColumn("_created_at", current_timestamp()) \
        .withColumn("_updated_at", current_timestamp()) \
        .withColumn("_source_file", input_file_name())
        
    # Check if target delta table exists
    from delta.tables import DeltaTable
    
    if not DeltaTable.isDeltaTable(spark, target_delta_path):
        # Initial write (Create table)
        print("Delta table does not exist. Creating table with Batch 1...")
        df_transformed.write.format("delta").mode("overwrite").save(target_delta_path)
    else:
        # Table exists, perform MERGE (Upsert)
        print(f"Merging data from {file_path}...")
        target_table = DeltaTable.forPath(spark, target_delta_path)
        
        # Merge conditions
        target_table.alias("t") \
            .merge(
                source = df_transformed.alias("s"),
                condition = "t.order_id = s.order_id"
            ) \
            .whenMatchedUpdate(set = {
                "customer_id": "s.customer_id",
                "order_date": "s.order_date",
                "amount": "s.amount",
                "status": "s.status",
                "_updated_at": "current_timestamp()",
                "_source_file": "s._source_file"
            }) \
            .whenNotMatchedInsert(values = {
                "order_id": "s.order_id",
                "customer_id": "s.customer_id",
                "order_date": "s.order_date",
                "amount": "s.amount",
                "status": "s.status",
                "_created_at": "current_timestamp()",
                "_updated_at": "current_timestamp()",
                "_source_file": "s._source_file"
            }) \
            .execute()

# COMMAND ----------

# CELL 7: Ingest Batch 1 (Initial) and Batch 2 (Duplicates) using the idempotent function
ingest_batch_idempotent(f"{raw_base_path}/landing/batch_1_initial.json")
ingest_batch_idempotent(f"{raw_base_path}/landing/batch_2_duplicates.json")

# COMMAND ----------

# CELL 8: Register table and verify duplicates
df_idempotent_orders = spark.read.format("delta").load(target_delta_path)
df_idempotent_orders.createOrReplaceTempView("orders_idempotent")

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Check duplicates again. There should be ZERO rows returned, meaning no duplicates.
# MAGIC SELECT order_id, COUNT(*) as count
# MAGIC FROM orders_idempotent
# MAGIC GROUP BY order_id
# MAGIC HAVING count > 1;

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Verify total unique records. There should be exactly 7 records (ORD001 - ORD007)
# MAGIC SELECT COUNT(*) as total_records FROM orders_idempotent;

# COMMAND ----------

# MAGIC %md
# MAGIC ## Phase 3: Incremental Updates (CDC / Status Updates)
# MAGIC Now let's ingest Batch 3, which contains status updates for `ORD001` (Pending -> Shipped), `ORD002` (Processing -> Delivered), and `ORD005` (Pending -> Processing), plus one new order (`ORD008`).

# COMMAND ----------

# CELL 9: Ingest Batch 3
ingest_batch_idempotent(f"{raw_base_path}/landing/batch_3_updates.json")

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Verify that ORD002 is now 'Delivered' and ORD001 is 'Shipped', while total record count is 8.
# MAGIC SELECT order_id, status, _created_at, _updated_at 
# MAGIC FROM orders_idempotent 
# MAGIC WHERE order_id IN ('ORD001', 'ORD002', 'ORD008');

# COMMAND ----------

# MAGIC %md
# MAGIC ## Phase 4: Schema Evolution & Schema Drift
# MAGIC In Batch 4, the source system introduces a new column `discount_applied` (boolean). Let's see how Delta Lake handles this change.

# COMMAND ----------

# CELL 10: Try to read and write Batch 4 (Will fail by default or ignore due to schema drift mismatch)
# We need to define a new schema that includes the new column to read it properly.
json_schema_drift = StructType([
    StructField("order_id", StringType(), True),
    StructField("customer_id", StringType(), True),
    StructField("order_date", StringType(), True),
    StructField("amount", DoubleType(), True),
    StructField("status", StringType(), True),
    StructField("discount_applied", StringType(), True) # New column
])

df_batch_4 = spark.read \
    .schema(json_schema_drift) \
    .json(f"{raw_base_path}/landing/batch_4_schema_drift.json") \
    .withColumn("_created_at", current_timestamp()) \
    .withColumn("_updated_at", current_timestamp()) \
    .withColumn("_source_file", input_file_name())

# Attempting to write this df to the existing Delta table
try:
    df_batch_4.write.format("delta").mode("append").save(target_delta_path)
except Exception as e:
    print(f"❌ Failed as expected due to Schema Enforcement:\n {str(e)[:250]}...")

# COMMAND ----------

# CELL 11: Implement Schema Evolution using mergeSchema option
# To allow Delta to automatically add the new column to our table schema, we use .option("mergeSchema", "true")
print("Writing Batch 4 with Schema Evolution enabled...")
df_batch_4.write \
    .format("delta") \
    .mode("append") \
    .option("mergeSchema", "true") \
    .save(target_delta_path)

print("Batch 4 written successfully with Schema Evolution.")

# COMMAND ----------

# CELL 12: Query final table schema and records
df_final = spark.read.format("delta").load(target_delta_path)
df_final.createOrReplaceTempView("orders_final")
df_final.printSchema()

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Observe that older records have NULL for the new 'discount_applied' column
# MAGIC SELECT order_id, status, discount_applied
# MAGIC FROM orders_final;
