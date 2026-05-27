import dlt
from pyspark.sql.functions import *

# 1. Read configuration parameter from Pipeline Settings instead of hardcoding (Flexible when moving from Dev to Prod)
try:
    storage_path = spark.conf.get("pipeline.storage_path")
except Exception as e:
    # Default value for local testing if parameter is not passed
    storage_path = "abfss://raw-data@<storage_account_name>.dfs.core.windows.net/"

# 2. Ingestion processing for Customers table
@dlt.table(
    name="raw_customers",
    comment="Table containing raw customer data, auto-ingested from ADLS Gen2. The _rescued_data column contains data with format errors.",
    table_properties={"quality": "bronze"}
)
# Data Quality: If customer data is missing an ID, we consider it garbage and DROP it
@dlt.expect_or_drop("valid_customer_id", "customer_id IS NOT NULL")
def ingest_customers():
    return (
        spark.readStream.format("cloudFiles")
        .option("cloudFiles.format", "csv")
        .option("cloudFiles.inferColumnTypes", "true") # Auto-infer data types
        .option("cloudFiles.schemaEvolutionMode", "addNewColumns") # Automatically capture new columns if any
        .option("cloudFiles.schemaLocation", f"{storage_path}/_schemas/customers") # Save schema at checkpoint
        .option("header", "true")
        .load(f"{storage_path}/customers/")
    )

# 3. Ingestion processing for Orders table
@dlt.table(
    name="raw_orders",
    comment="Table containing raw order data, auto-ingested from ADLS Gen2.",
    table_properties={"quality": "bronze"}
)
# Data Quality: Warn if the order amount is negative, but STILL keep the record for investigation (do not DROP)
@dlt.expect("valid_total_amount", "total_amount >= 0")
def ingest_orders():
    return (
        spark.readStream.format("cloudFiles")
        .option("cloudFiles.format", "csv")
        .option("cloudFiles.inferColumnTypes", "true")
        .option("cloudFiles.schemaEvolutionMode", "addNewColumns")
        .option("cloudFiles.schemaLocation", f"{storage_path}/_schemas/orders")
        .option("header", "true")
        .load(f"{storage_path}/orders/")
    )
