import time
import json
import random
import uuid
from datetime import datetime, timezone
from azure.eventhub import EventHubProducerClient, EventData

# ==========================================
# CẤU HÌNH KẾT NỐI (Lấy từ Azure Portal)
# ==========================================
# Thay thế chuỗi bên dưới bằng Connection String của Event Hubs Namespace
CONNECTION_STR = "Endpoint=sb://evhns-paytech-lab-dev.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=YOUR_KEY_HERE"

# Tên Topic (Event Hub) đã tạo
EVENTHUB_NAME = "transactions"

# ==========================================

def generate_transaction():
    """Hàm giả lập tạo ra 1 giao dịch ví điện tử"""
    # Cố tình dồn nhiều giao dịch cho user U001 để test kịch bản gian lận (fraud)
    user_id = random.choices(
        population=["U001", "U002", "U003", "U004", "U005"], 
        weights=[0.6, 0.1, 0.1, 0.1, 0.1], 
        k=1
    )[0]
    
    return {
        "transaction_id": str(uuid.uuid4()),
        "user_id": user_id,
        "amount": round(random.uniform(10.0, 500.0), 2),
        "currency": "USD",
        # Timestamp chuẩn ISO 8601 (UTC) - Rất quan trọng để Spark xử lý Windowing
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

def run():
    # Khởi tạo client kết nối tới Event Hubs
    producer = EventHubProducerClient.from_connection_string(
        conn_str=CONNECTION_STR, 
        eventhub_name=EVENTHUB_NAME
    )
    
    print(f"🚀 Bắt đầu bắn giao dịch vào Event Hub: '{EVENTHUB_NAME}'...")
    try:
        with producer:
            while True:
                # Tạo một batch (gói) để gửi nhiều sự kiện cùng lúc nhằm tối ưu hiệu năng
                event_data_batch = producer.create_batch()
                
                # Bắn 10 giao dịch mỗi đợt
                for _ in range(10):
                    txn = generate_transaction()
                    
                    # Serialize dictionary thành chuỗi JSON trước khi gửi
                    event_data = EventData(json.dumps(txn))
                    
                    # Gán Partition Key = user_id
                    # Việc này đảm bảo toàn bộ giao dịch của cùng 1 user sẽ đi vào cùng 1 Partition,
                    # giúp xử lý theo đúng thứ tự thời gian.
                    event_data_batch.add(event_data)
                
                # Gửi batch lên Azure
                producer.send_batch(event_data_batch)
                
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Đã gửi 10 giao dịch...")
                
                # Nghỉ 1 giây rồi bắn tiếp
                time.sleep(1)
                
    except KeyboardInterrupt:
        print("\n⏹️ Đã dừng bắn dữ liệu (bởi người dùng).")
    except Exception as e:
        print(f"\n❌ Lỗi xảy ra: {str(e)}")

if __name__ == '__main__':
    run()
