# Hướng dẫn Lab 13: Cấu Trúc Big Data Streaming Pipeline với Azure Event Hubs và Databricks

> **Mức độ**: Advanced
> **Thời gian ước tính**: 2-3 giờ
> **Công nghệ**: Azure Event Hubs (Kafka protocol), Azure Databricks, Apache Spark Structured Streaming, Delta Lake.

---

## 📖 Bối cảnh nghiệp vụ (The Business Scenario)

Công ty công nghệ tài chính (Fintech) **PayTech** xử lý hàng triệu giao dịch ví điện tử mỗi ngày. Họ đang xây dựng hệ thống **Anti-Fraud (Chống gian lận)** với 2 yêu cầu khắt khe:
1. **Real-time Alert**: Bất kỳ người dùng nào thực hiện **hơn 5 giao dịch trong vòng 1 phút** phải bị ghi nhận cảnh báo ngay lập tức.
2. **Cold Storage**: Mọi dữ liệu giao dịch (dù có gian lận hay không) đều phải được lưu trữ vĩnh viễn xuống Data Lake (chuẩn Delta Lake) để làm báo cáo và huấn luyện AI.

Mô hình kiến trúc được chọn:
- **Azure Event Hubs**: Đóng vai trò là ống nước khổng lồ (Message Broker) hứng dữ liệu với tốc độ cao, thay thế cho việc tự xây dựng cụm Apache Kafka tốn kém.
- **Azure Databricks (Spark Streaming)**: Khả năng xử lý **Tumbling Window** để đếm giao dịch theo từng phút một cách chính xác.

### Sơ đồ Kiến trúc (Architecture Diagram)

```mermaid
graph TD
    %% Định nghĩa Style
    classDef producer fill:#f9f,stroke:#333,stroke-width:2px;
    classDef azure fill:#0072C6,stroke:#fff,stroke-width:2px,color:#fff;
    classDef dbx fill:#FF3621,stroke:#fff,stroke-width:2px,color:#fff;
    classDef storage fill:#0089D6,stroke:#fff,stroke-width:2px,color:#fff;

    %% Các thành phần
    subgraph "Data Generation"
        P1(Python Script<br/>Transaction Producer) ::: producer
    end

    subgraph "Azure Cloud"
        EH[Azure Event Hubs<br/>Namespace: evhns-paytech-lab-dev<br/>Topic: transactions] ::: azure
        
        subgraph "Azure Databricks"
            SPARK[Spark Structured Streaming<br/>1. Read Stream Kafka API<br/>2. Parse JSON & Watermark<br/>3. Tumbling Window Aggregation] ::: dbx
        end
        
        ADLS[(Azure Data Lake Gen2<br/>Delta Table: fraud_alerts)] ::: storage
    end

    %% Luồng dữ liệu
    P1 -- "Send JSON Events<br/>(Kafka Protocol)" --> EH
    EH -- "Micro-batch Read<br/>(Continuous)" --> SPARK
    SPARK -- "Write Stream<br/>(Append Mode)" --> ADLS
```

---

## 🏷️ Tên tài nguyên chuẩn (Resource Naming Convention)

> 💡 **Tip**: Sử dụng đúng các tên dưới đây khi tạo tài nguyên trên Azure Portal để đảm bảo code trong bài lab hoạt động ngay mà không cần sửa đổi.

| Phân loại | Tài nguyên Azure | Tên đặt sẵn (Copy & Paste) | Mục đích sử dụng |
|---|---|---|---|
| **Quản lý chung** | Resource Group | `rg-streaming-lab-dev` | Nhóm chứa toàn bộ tài nguyên của Lab 13 |
| **Streaming (Ingestion)**| Event Hubs Namespace | `evhns-paytech-lab-dev` *(Phải thêm số đuôi nếu bị trùng)* | Máy chủ quản lý các Topic (Kafka cluster) |
| **Streaming (Topic)** | Event Hub | `transactions` | Topic cụ thể để lưu trữ luồng giao dịch |
| **Xử lý (Compute)** | Databricks Workspace | `dbw-streaming-lab-dev` | Môi trường chạy Spark Structured Streaming |
| **Lưu trữ (Storage)** | Storage Account (ADLS Gen2)| `dlsstreaminglabdev001` *(Thêm số nếu bị trùng)* | Lưu Delta Table và Checkpoint (Chuẩn Enterprise) |

---

## 🛠️ Phase 1: Khởi tạo Hạ tầng trên Azure Portal (Click-by-click)

### Bước 1: Tạo Resource Group
1. Đăng nhập [Azure Portal](https://portal.azure.com/).
2. Trên thanh tìm kiếm, gõ **Resource groups** và chọn nó.
3. Bấm **+ Create** (Tạo mới).
   - **Subscription**: Chọn sub của bạn.
   - **Resource group**: Nhập chính xác `rg-streaming-lab-dev`.
   - **Region**: Chọn `Southeast Asia`.
4. Bấm **Review + create** -> Bấm tiếp **Create**.

### Bước 2: Tạo Azure Event Hubs Namespace
1. Trên thanh tìm kiếm, gõ **Event Hubs** và chọn.
2. Bấm **+ Create**.
3. Điền các thông tin:
   - **Resource group**: Chọn `rg-streaming-lab-dev`.
   - **Namespace name**: `evhns-paytech-lab-dev` (Nếu hệ thống báo tên này đã có người dùng, hãy thêm số vào cuối, ví dụ: `evhns-paytech-lab-dev-01`).
   - **Location**: `Southeast Asia`.
   - **Pricing tier**: Mở dropdown và chọn **Standard**. *(Lưu ý: Bắt buộc chọn Standard, bản Basic không hỗ trợ Kafka protocol và không có đủ Consumer Groups).*
   - **Throughput Units**: Để mặc định là `1`. (1 TU cho phép gửi 1MB/s, hoàn toàn dư dả cho Lab).
4. Bấm **Review + create** -> Chờ báo "Validation passed" -> Bấm **Create**.
5. (Đợi khoảng 2-3 phút cho quá trình Deployment hoàn tất).

### Bước 3: Tạo Topic (Event Hub)
1. Khi Namespace đã tạo xong, bấm **Go to resource** để vào trang quản lý `evhns-paytech-lab-dev`.
2. Ở thanh menu bên trái, cuộn xuống mục **Entities**, bấm vào **Event Hubs**.
3. Bấm nút **+ Event Hub** (dấu cộng ở cạnh trên).
4. Điền cấu hình Topic:
   - **Name**: Nhập `transactions`
   - **Partition Count**: Nhập `4` (Tạo 4 luồng xử lý song song).
   - **Message Retention**: `1` (Giữ dữ liệu trong 1 ngày, sau đó tự xóa).
5. Bấm **Review + create** -> **Create**.

### Bước 4: Lấy Chìa khóa kết nối (Connection String)
Để Python hoặc Databricks có thể kết nối vào Event Hubs, chúng ta cần mật khẩu (Shared Access Key).
1. Vẫn ở trang Namespace `evhns-paytech-lab-dev`, nhìn menu bên trái, mục **Settings**, chọn **Shared access policies**.
2. Bấm vào policy mặc định có tên: `RootManageSharedAccessKey`.
3. Bảng bên phải hiện ra, tìm ô **Connection string–primary key**.
4. Bấm biểu tượng **Copy** bên cạnh nó. (Nó sẽ có dạng: `Endpoint=sb://evhns-paytech...`).
5. Mở Notepad trên máy tính và dán chuỗi này vào cất tạm.

### Bước 5: Tạo Storage Account, Access Connector và Phân quyền IAM (Chuẩn Enterprise)
Trong thực tế doanh nghiệp hiện đại, không ai lưu trữ Access Key dạng Text (plain-text) trong code. Thay vào đó, ta sử dụng **Azure Databricks Access Connector** (Managed Identity) kết hợp với **Unity Catalog**.

**1. Tạo Storage Account (ADLS Gen2):**
1. Trên thanh tìm kiếm Azure Portal, gõ **Storage accounts** và chọn nó -> Bấm **+ Create**.
2. **Resource group**: `rg-streaming-lab-dev`.
3. **Storage account name**: `dlsstreaminglabdev001`.
4. **Region**: `Southeast Asia`.
5. Tab **Advanced** -> Tích chọn hộp **Enable hierarchical namespace** -> **Review + create** -> **Create**.
6. Khi xong, tạo một **Container** tên là `fraud-alerts`.

**2. Tạo Databricks Access Connector:**
1. Trên thanh tìm kiếm, gõ **Access Connector for Azure Databricks** -> **+ Create**.
2. **Resource group**: `rg-streaming-lab-dev`.
3. **Name**: `dbac-streaming-lab-dev`.
4. **Region**: `Southeast Asia`.
5. Bấm **Review + create** -> **Create**. 
6. Đợi tạo xong, bấm **Go to resource**. Ở trang tổng quan (Overview), copy giá trị của trường **Resource ID** (Nó có dạng `/subscriptions/.../providers/Microsoft.Databricks/accessConnectors/dbac-streaming-lab-dev`) cất vào Notepad.

**3. Phân quyền IAM (Gắn quyền cho Connector):**
1. Quay lại trang **Storage account** `dlsstreaminglabdev001` vừa tạo.
2. Ở menu trái, chọn **Access Control (IAM)** -> **+ Add** -> **Add role assignment**.
3. Tab **Role**: Tìm và chọn quyền **Storage Blob Data Contributor** -> Bấm Next.
4. Tab **Members**: Chọn **Managed identity** -> Bấm **+ Select members**.
5. Trong bảng hiện ra, mục Managed identity chọn *Access Connector for Azure Databricks*, sau đó click chọn `dbac-streaming-lab-dev` -> Bấm Select -> Bấm Next -> **Review + assign**.
*(Bước này cho phép Access Connector có toàn quyền đọc/ghi vào Data Lake mà không cần mật khẩu).*

---

## 🐍 Phase 2: Chạy bộ giả lập dữ liệu (Python Producer)

Chúng ta không có dữ liệu ví điện tử thật, nên cần dùng đoạn script Python để đóng vai trò là hàng nghìn người dùng đang giao dịch và đẩy dữ liệu lên Azure.

1. Đảm bảo máy tính của bạn (hoặc máy ảo) đã cài đặt thư viện kết nối:
   ```bash
   pip install azure-eventhub
   ```
2. Mở file `lab_13_streaming_big_data/scripts/transaction_producer.py` trong thư mục code.
3. Thay thế biến `CONNECTION_STR` bằng chuỗi bạn vừa copy ở Phase 1 - Bước 4.
4. Lưu file và chạy script từ Terminal:
   ```bash
   python scripts/transaction_producer.py
   ```
5. Bạn sẽ thấy màn hình in ra liên tục thông báo báo hiệu giao dịch đang được bắn thẳng lên đám mây Azure. **Hãy để Terminal này chạy ngầm (không tắt)** và chuyển sang Phase 3.

---

## ⚡ Phase 3: Databricks Spark Structured Streaming

### Bước 1: Khởi tạo Databricks Workspace & Cluster
1. Trở lại Azure Portal, tìm **Azure Databricks** -> **Create**.
   - **Resource group**: `rg-streaming-lab-dev`
   - **Workspace name**: `dbw-streaming-lab-dev`
   - **Region**: `Southeast Asia`
   - **Pricing Tier**: **Premium** (Để dùng các tính năng nâng cao).
2. Bấm **Review + Create** -> **Create**. Đợi 5 phút.
3. Khi xong, bấm **Launch Workspace** để mở Databricks.
4. Ở menu trái của Databricks, chọn **Compute** -> **Create compute**.
   - **Compute name**: `streaming-cluster`
   - **Databricks Runtime Version**: `14.3 LTS (Scala 2.12, Spark 3.5.0)` hoặc mới hơn.
   - **Node type**: Để mặc định, bỏ chọn "Enable autoscaling" để tiết kiệm, set Worker về `1`.
   - Bấm **Create compute**. (Đợi cluster màu xanh lá).

### Bước 2: Cấu hình Unity Catalog (Storage Credential & External Location)
Để Databricks sử dụng được Access Connector vừa tạo, ta phải thiết lập Unity Catalog.

1. Tại Workspace Databricks, menu trái chọn **Catalog** (Catalog Explorer).
2. Nhìn cột menu ngoài cùng bên trái, phần **External Data**, chọn **Storage credentials** -> Bấm **Create credential**.
   - **Credential name**: `cred_streaming_lab`
   - **Access Connector ID**: Dán cái `Resource ID` bạn copy ở Bước 5 phần 2 vào đây.
   - Bấm **Create**.
3. Tiếp tục ở menu trái, chọn **External locations** -> Bấm **Create location**.
   - **External location name**: `ext_fraud_alerts`
   - **URL**: `abfss://fraud-alerts@dlsstreaminglabdev001.dfs.core.windows.net/`
   - **Storage credential**: Chọn `cred_streaming_lab` vừa tạo.
   - Bấm **Create**.
*(Kể từ giờ, Databricks Workspace của bạn đã được kết nối an toàn với Data Lake thông qua Access Connector mà không cần bất kỳ dòng code nhúng mật khẩu nào).*

### Bước 3: Tạo Notebook xử lý
1. Ở menu trái Databricks, chọn **Workspace** -> Chọn thư mục **Users** -> Chọn thư mục tên của bạn.
2. Bấm **Create** -> **Notebook**.
3. Tên Notebook: `Realtime_Fraud_Detection`.
4. Viết và chạy từng Cell (Ô lệnh) dưới đây.

#### Cell 1: Định nghĩa kết nối tới Event Hubs (Giao thức Kafka)
```python
# Lấy URL của Server từ Connection string của bạn. 
# Thay chữ "evhns-paytech-lab-dev" thành tên thực tế nếu bạn có đổi tên.
EH_NAMESPACE = "evhns-paytech-lab-dev"

bootstrap_servers = f"{EH_NAMESPACE}.servicebus.windows.net:9093"
topic_name = "transactions"

# COPY TOÀN BỘ CONNECTION STRING (EVENT HUBS) VÀO ĐÂY
connection_string = "Endpoint=sb://evhns-paytech-lab-dev.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=YOUR_KEY"

# Cấu hình bảo mật (JAAS) theo chuẩn Kafka
eh_sasl = f'kafkashaded.org.apache.kafka.common.security.plain.PlainLoginModule required \
    username="$ConnectionString" \
    password="{connection_string}";'
```

#### Cell 2: Khai báo luồng đọc (Extract - Bronze Layer)
Lệnh `readStream` báo cho Spark biết: "Đây không phải dữ liệu tĩnh, đây là một dòng sông dữ liệu đang chảy".

```python
# Đọc data stream từ Event Hubs
df_raw_stream = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", bootstrap_servers) \
    .option("subscribe", topic_name) \
    .option("kafka.sasl.mechanism", "PLAIN") \
    .option("kafka.security.protocol", "SASL_SSL") \
    .option("kafka.sasl.jaas.config", eh_sasl) \
    .option("startingOffsets", "latest") \
    .option("maxOffsetsPerTrigger", 500) \
    .load()

# Xem dữ liệu thô (chuỗi nhị phân)
display(df_raw_stream)
```
*(Bấm chạy Cell 2 (Shift+Enter). Bạn sẽ thấy bảng xuất hiện và các dòng mới liên tục nhảy lên. Hủy chạy cell này (bấm nút vuông Stop) để đi tiếp).*

#### Cell 3: Parse JSON & Watermarking (Transform - Silver Layer)
Dữ liệu đang ở dạng binary. Ta phải dịch nó thành JSON có các cột rõ ràng. 

```python
from pyspark.sql.functions import from_json, col, window, count, sum
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, TimestampType

# Khai báo cấu trúc JSON y hệt như code Python ở Phase 2
schema = StructType([
    StructField("transaction_id", StringType(), True),
    StructField("user_id", StringType(), True),
    StructField("amount", DoubleType(), True),
    StructField("currency", StringType(), True),
    StructField("timestamp", TimestampType(), True)
])

# Dịch nhị phân -> Chuỗi -> Bảng
df_parsed = df_raw_stream \
    .selectExpr("CAST(value AS STRING) as json_payload") \
    .select(from_json(col("json_payload"), schema).alias("data")) \
    .select("data.*")

# THÊM WATERMARK: Spark sẽ lưu dữ liệu trong RAM. Nếu không có watermark, RAM sẽ đầy.
# Lệnh dưới nghĩa là: "Tôi chỉ giữ trong RAM các sự kiện trễ tối đa 1 phút. Sau 1 phút, hãy xóa khỏi RAM".
df_watermarked = df_parsed.withWatermark("timestamp", "1 minute")
```

#### Cell 4: Đếm gian lận bằng Tumbling Window
Tumbling Window cắt thời gian thành những ô 1 phút (ví dụ từ 10:00:00 đến 10:00:59, 10:01:00 đến 10:01:59).

```python
# Gom nhóm theo khoảng thời gian (1 phút) và theo User
df_fraud_alerts = df_watermarked \
    .groupBy(
        window(col("timestamp"), "1 minute"), 
        col("user_id")
    ) \
    .agg(
        count("transaction_id").alias("total_transactions"),
        sum("amount").alias("total_amount_usd")
    ) \
    .filter(col("total_transactions") > 5) # Yêu cầu nghiệp vụ: > 5 giao dịch / phút là gian lận

# Bạn sẽ thấy User "U001" hiện lên liên tục vì script Python đã cố tình dồn giao dịch cho user này
display(df_fraud_alerts)
```
*(Bấm Stop sau khi xem xong).*

#### Cell 5: Ghi cảnh báo gian lận xuống Delta Lake (Load - Gold Layer)
Màn hình chỉ để xem chơi. Trong thực tế, hệ thống phải lưu kết quả vĩnh viễn xuống Data Lake (ADLS Gen2). Chúng ta sẽ dùng giao thức `abfss://` của Azure.

```python
# Điền tên Storage Account của bạn (mặc định là dlsstreaminglabdev001)
storage_account_name = "dlsstreaminglabdev001"

# Khai báo đường dẫn tới ADLS Gen2 theo chuẩn: abfss://<container>@<storage-account>.dfs.core.windows.net/
adls_path = f"abfss://fraud-alerts@{storage_account_name}.dfs.core.windows.net"

# Nơi lưu trữ trạng thái của Spark (rất quan trọng để không bị đọc trùng nếu cluster sập)
checkpoint_location = f"{adls_path}/checkpoints/fraud_alerts"

# Vị trí thư mục Delta Table để lưu dữ liệu
table_location = f"{adls_path}/delta/fraud_alerts"

# Khởi chạy luồng ghi ngầm
streaming_query = df_fraud_alerts.writeStream \
    .format("delta") \
    .outputMode("append") \
    .option("checkpointLocation", checkpoint_location) \
    .start(table_location)

print("✅ Đang ghi dữ liệu ngầm vào Delta Lake...")
```

#### Cell 6: Truy vấn Delta Lake bằng SQL
Mở một cell mới và đóng vai trò là Data Analyst, dùng SQL query trực tiếp vào file Delta mà luồng Stream đang liên tục đổ dữ liệu vào.

```sql
%sql
SELECT 
  window.start AS Time_Start, 
  window.end AS Time_End, 
  user_id AS Suspicious_User, 
  total_transactions 
-- Thay dlsstreaminglabdev001 bằng tên Storage Account thực tế của bạn nếu có đổi tên
FROM delta.`abfss://fraud-alerts@dlsstreaminglabdev001.dfs.core.windows.net/delta/fraud_alerts`
ORDER BY window.start DESC
```
Cứ cách vài chục giây, bạn bấm chạy lại cell SQL này, bạn sẽ thấy các dòng cảnh báo gian lận mới liên tục xuất hiện. 

#### Cell 7: Dừng luồng ghi dữ liệu (Programmatic Stop)
Để dừng luồng streaming đang chạy bằng code (hoặc bạn có thể bấm nút **Interrupt/Cancel** trực tiếp ở góc trái phía trên cell chạy Stream):

```python
streaming_query.stop()
```

---

## 🧹 Phase 4: Dọn dẹp tài nguyên (RẤT QUAN TRỌNG)
Các tài nguyên Cloud tính tiền theo giờ, đặc biệt là Databricks và Event Hubs, hãy dừng và xóa để tránh phát sinh chi phí ngoài ý muốn.

1. **Dừng Python Script**: Trở lại Terminal máy tính chạy script giả lập dữ liệu và bấm `Ctrl + C`.
2. **Dừng Streaming Query**: Trong Databricks Notebook, chạy **Cell 7** ở trên hoặc bấm **Interrupt** các cell đang chạy stream.
3. **Dừng Cluster Databricks**: Vào mục **Compute** ở menu trái -> Chọn cluster `streaming-cluster` -> Bấm nút **Terminate** (hoặc Stop).
4. **Xóa Resource Group**: 
   - Vào Azure Portal -> **Resource groups** -> `rg-streaming-lab-dev`.
   - Bấm **Delete resource group**, gõ đúng tên `rg-streaming-lab-dev` để xác nhận và nhấn **Delete**.

*(Việc xóa Resource Group đảm bảo bạn không bị tính thêm bất kỳ khoản phí phát sinh nào từ các tài nguyên này).*
