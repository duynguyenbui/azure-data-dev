import os
import json
from datetime import datetime, timedelta

# Create the data output directory
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Common helper to save JSON data
def save_batch(filename, data):
    filepath = os.path.join(OUTPUT_DIR, filename)
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"✅ Generated: {filepath} ({len(data)} records)")

def generate_batches():
    # Base datetime
    base_time = datetime(2026, 5, 27, 10, 0, 0)
    
    # ----------------------------------------------------
    # BATCH 1: Initial orders (Standard schema)
    # ----------------------------------------------------
    batch_1 = [
        {"order_id": "ORD001", "customer_id": "C01", "order_date": (base_time - timedelta(hours=2)).isoformat(), "amount": 150.0, "status": "Pending"},
        {"order_id": "ORD002", "customer_id": "C02", "order_date": (base_time - timedelta(hours=1.5)).isoformat(), "amount": 85.5, "status": "Processing"},
        {"order_id": "ORD003", "customer_id": "C03", "order_date": (base_time - timedelta(hours=1)).isoformat(), "amount": 340.0, "status": "Shipped"},
        {"order_id": "ORD004", "customer_id": "C04", "order_date": (base_time - timedelta(minutes=45)).isoformat(), "amount": 25.0, "status": "Pending"},
        {"order_id": "ORD005", "customer_id": "C01", "order_date": (base_time - timedelta(minutes=30)).isoformat(), "amount": 99.9, "status": "Pending"}
    ]
    save_batch("batch_1_initial.json", batch_1)
    
    # ----------------------------------------------------
    # BATCH 2: Duplicates & New Orders (Testing Idempotency)
    # ----------------------------------------------------
    # ORD004 and ORD005 are duplicates (exact copy of Batch 1)
    # ORD006 and ORD007 are brand new
    batch_2 = [
        {"order_id": "ORD004", "customer_id": "C04", "order_date": (base_time - timedelta(minutes=45)).isoformat(), "amount": 25.0, "status": "Pending"}, # DUPLICATE
        {"order_id": "ORD005", "customer_id": "C01", "order_date": (base_time - timedelta(minutes=30)).isoformat(), "amount": 99.9, "status": "Pending"}, # DUPLICATE
        {"order_id": "ORD006", "customer_id": "C05", "order_date": (base_time + timedelta(minutes=5)).isoformat(), "amount": 120.0, "status": "Pending"},
        {"order_id": "ORD007", "customer_id": "C02", "order_date": (base_time + timedelta(minutes=15)).isoformat(), "amount": 45.0, "status": "Pending"}
    ]
    save_batch("batch_2_duplicates.json", batch_2)
    
    # ----------------------------------------------------
    # BATCH 3: Updates (Testing CDC / Merge Updates)
    # ----------------------------------------------------
    # ORD001, ORD002, ORD005 have updated statuses (e.g., Shipped or Delivered)
    # ORD008 is brand new
    batch_3 = [
        {"order_id": "ORD001", "customer_id": "C01", "order_date": (base_time - timedelta(hours=2)).isoformat(), "amount": 150.0, "status": "Shipped"}, # UPDATE status
        {"order_id": "ORD002", "customer_id": "C02", "order_date": (base_time - timedelta(hours=1.5)).isoformat(), "amount": 85.5, "status": "Delivered"}, # UPDATE status
        {"order_id": "ORD005", "customer_id": "C01", "order_date": (base_time - timedelta(minutes=30)).isoformat(), "amount": 99.9, "status": "Processing"}, # UPDATE status
        {"order_id": "ORD008", "customer_id": "C06", "order_date": (base_time + timedelta(minutes=30)).isoformat(), "amount": 310.5, "status": "Pending"}
    ]
    save_batch("batch_3_updates.json", batch_3)
    
    # ----------------------------------------------------
    # BATCH 4: Schema Drift (Testing Schema Evolution)
    # ----------------------------------------------------
    # Adds a new column: discount_applied (boolean)
    batch_4 = [
        {"order_id": "ORD009", "customer_id": "C03", "order_date": (base_time + timedelta(hours=1)).isoformat(), "amount": 75.0, "status": "Pending", "discount_applied": True},
        {"order_id": "ORD010", "customer_id": "C07", "order_date": (base_time + timedelta(hours=1.5)).isoformat(), "amount": 200.0, "status": "Pending", "discount_applied": False}
    ]
    save_batch("batch_4_schema_drift.json", batch_4)

if __name__ == "__main__":
    print("🚀 Starting generation of Mock Order batches...")
    generate_batches()
    print("✨ All batches generated successfully inside 'lab_14_pipeline_design/data/'.")
