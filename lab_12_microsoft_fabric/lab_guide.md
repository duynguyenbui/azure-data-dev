# Hướng dẫn Lab 12: Enterprise Data Platform với Microsoft Fabric: Medallion Architecture, Real-Time Intelligence & Direct Lake

Chào mừng bạn đến với tài liệu Lab thực hành cấp độ doanh nghiệp về Microsoft Fabric. Đây là một nền tảng phân tích hợp nhất (Unified Analytics Platform) được Microsoft xây dựng trên nền OneLake — một "data lake" logic duy nhất cho toàn tổ chức. Lab này sẽ đưa bạn đi qua toàn bộ vòng đời dữ liệu: từ batch ingestion, real-time streaming, Spark transformation, ML forecasting, đến self-service BI — tất cả trong một nền tảng duy nhất.

---

## Kịch bản Nghiệp vụ (The Business Scenario)

Tập đoàn bán lẻ **RetailVN** đang vận hành **500 cửa hàng** trên toàn quốc với hàng triệu giao dịch bán hàng mỗi ngày. Ban Giám đốc đặt ra 4 yêu cầu chiến lược cấp bách:

1. **Batch Analytics:** Mỗi đêm nạp toàn bộ giao dịch bán hàng từ Azure SQL vào OneLake để phân tích tổng hợp doanh số theo ngày.
2. **Real-Time Inventory:** Theo dõi tồn kho theo thời gian thực từ hệ thống POS (Point-of-Sale) của 500 cửa hàng. Khi tồn kho một mặt hàng xuống dưới ngưỡng, hệ thống phải cảnh báo tức thì.
3. **Demand Forecasting:** Xây dựng mô hình dự báo nhu cầu (ML) để tối ưu hóa đặt hàng và tránh hết hàng.
4. **Self-Service BI:** Nhân viên nghiệp vụ có thể tự tạo báo cáo Power BI kết nối trực tiếp vào dữ liệu mà không cần IT hỗ trợ.

### Kiến trúc Giải pháp

```
┌─────────────────────────────────────────────────────────────────┐
│                     MICROSOFT FABRIC                            │
│                                                                 │
│  Azure SQL ──► Dataflow Gen2 ──► BRONZE Lakehouse (Delta)       │
│  (Batch)                                                        │
│                                                                 │
│  POS Systems ──► Eventstream ──► KQL Database (Real-Time)       │
│  (Streaming)                                                    │
│                                                                 │
│  BRONZE ──► Spark Notebook ──► SILVER Lakehouse (Delta MERGE)   │
│                                                                 │
│  SILVER ──► MLflow Experiment ──► GOLD Lakehouse (Forecast)     │
│                                                                 │
│  GOLD ──► Direct Lake Semantic Model ──► Power BI Reports       │
│                                                                 │
│  Purview ──────────────────────────────► Governance & Lineage   │
│                                                                 │
│  Data Activator ────────────────────► Alerting & Automation     │
└─────────────────────────────────────────────────────────────────┘
```

> **Tại sao Microsoft Fabric?** Trong môi trường doanh nghiệp truyền thống, mỗi bước trong kiến trúc trên đòi hỏi một công cụ riêng biệt: Azure Data Factory, Azure Databricks, Azure Synapse, Azure Stream Analytics, Power BI Service... Điều này tạo ra sự phức tạp về vận hành, chi phí licensing, và quản trị dữ liệu bị phân mảnh. Microsoft Fabric hợp nhất tất cả vào một nền tảng duy nhất với **OneLake** làm trung tâm lưu trữ, giảm đáng kể độ phức tạp và chi phí vận hành.

---

## Phase 1: Thiết lập Fabric Workspace & Governance

> **Mục đích:** Workspace trong Microsoft Fabric là không gian làm việc cô lập cho một dự án hoặc một team. Tất cả các item (Lakehouse, Pipeline, Notebook, Report...) đều sống bên trong Workspace. Việc cấu hình đúng từ đầu về phân quyền và Capacity là nền tảng bắt buộc cho môi trường enterprise.

### Bước 1: Kích hoạt Microsoft Fabric Trial

> **Fabric Capacity là gì?** Không giống Power BI Pro (license theo user), Microsoft Fabric tính phí theo **Capacity** — tài nguyên tính toán dùng chung cho toàn tenant. Mỗi Capacity Unit (CU) tương ứng với một lượng sức mạnh tính toán. Trong Lab này, chúng ta sử dụng **Trial Capacity** miễn phí 60 ngày (64 CU).

1. Đăng nhập vào [app.fabric.microsoft.com](https://app.fabric.microsoft.com) bằng tài khoản Microsoft 365.
2. Nếu bạn chưa có Fabric capacity, bạn sẽ thấy banner **"Try Microsoft Fabric for free"**. Click vào đó.
3. Chọn **Start Trial** và xác nhận. Azure sẽ cấp cho bạn 60 ngày dùng thử với **64 Fabric Capacity Units (F64)**.
4. Sau khi kích hoạt, click biểu tượng **Fabric** ở góc trái để vào trang chủ.

> **Lưu ý quan trọng:** Nếu bạn dùng tenant của tổ chức, cần xin cấp quyền từ Fabric Admin. Nếu muốn dùng tài khoản cá nhân, hãy tạo Microsoft 365 Developer Program tại [developer.microsoft.com/microsoft-365](https://developer.microsoft.com/microsoft-365) để có tenant riêng miễn phí.

### Bước 2: Tạo Workspace cho RetailVN

1. Trong giao diện Fabric, click **Workspaces** ở thanh menu bên trái.
2. Click **+ New workspace** ở góc trên.
3. Điền thông tin:
   - **Name:** `RetailVN-DataPlatform`
   - **Description:** `Enterprise analytics platform for RetailVN 500 stores`
4. Mở rộng phần **Advanced**:
   - **License mode:** Chọn **Trial** (hoặc Premium nếu bạn có capacity thật).
   - **Default storage format:** Giữ nguyên **Delta Lake** — đây là lý do Fabric mạnh hơn các nền tảng cũ (toàn bộ data đều ở định dạng Delta).
5. Click **Apply** để tạo workspace.

### Bước 3: Cấu hình Workspace Admin Settings & Roles

> **Workspace Roles trong Fabric:** Fabric sử dụng mô hình phân quyền 4 cấp, mỗi cấp có quyền hạn khác nhau đối với toàn bộ Workspace:
>
> | Role | Quyền hạn |
> |---|---|
> | **Admin** | Toàn quyền: cấu hình, xóa workspace, thêm/xóa thành viên |
> | **Member** | Tạo và chia sẻ nội dung, không xóa workspace |
> | **Contributor** | Tạo và chỉnh sửa nội dung, không chia sẻ |
> | **Viewer** | Chỉ xem nội dung đã được publish |

1. Trong Workspace `RetailVN-DataPlatform`, click biểu tượng **...** (More options) ở góc trên phải.
2. Chọn **Workspace settings**.
3. Trong tab **People and groups**:
   - Click **+ Add people or groups**.
   - Thêm tài khoản của bạn với role **Admin**.
   - (Trong môi trường thực tế) Thêm nhóm Data Engineer với role **Member**, nhóm Data Analyst với role **Contributor**, nhóm Business Users với role **Viewer**.
4. Trong tab **OneLake** (nếu hiển thị): Giữ nguyên cấu hình mặc định.
5. Click **Save** để lưu.

> **Best Practice — Git Integration:** Trong môi trường production, bạn nên kết nối Workspace với Azure DevOps hoặc GitHub. Vào **Workspace settings** > **Git integration** và kết nối với repository của bạn. Toàn bộ thay đổi (Notebooks, Pipelines, Reports) sẽ được version-control như code thực sự.

---

## Phase 2: OneLake Architecture — Nền tảng Lưu trữ Hợp nhất

> **Mục đích:** Trước khi xây dựng bất kỳ thứ gì, bạn cần hiểu OneLake — đây là sự khác biệt cốt lõi của Microsoft Fabric so với tất cả các nền tảng trước đây. Hiểu sai OneLake là hiểu sai toàn bộ Fabric.

### OneLake là gì?

> **Định nghĩa:** **OneLake** là một Data Lake logic duy nhất cho toàn bộ tenant Microsoft Fabric, tương tự như **OneDrive cho dữ liệu doanh nghiệp**. Dù bạn tạo bao nhiêu Workspace hay Lakehouse đi nữa, tất cả dữ liệu vật lý đều nằm tại một địa điểm lưu trữ duy nhất — được Microsoft quản lý tự động trên Azure Data Lake Storage Gen2 bên dưới.
>
> **Điều này có nghĩa là:**
> - **Không cần tạo Storage Account:** Microsoft tự quản lý hạ tầng lưu trữ.
> - **Không copy data giữa các dịch vụ:** Spark Notebook, SQL Endpoint, Power BI đều đọc cùng một file Delta trên OneLake.
> - **Địa chỉ ABFS chuẩn:** Mỗi Lakehouse có địa chỉ `abfss://<workspace>@onelake.dfs.fabric.microsoft.com/<lakehouse>/Tables/...`

### Shortcut vs. Copy — Hai chiến lược quan trọng

| | **Shortcut** | **Copy (Full Ingestion)** |
|---|---|---|
| **Bản chất** | Pointer (con trỏ) tới data ở nơi khác | Sao chép vật lý data vào OneLake |
| **Chi phí lưu trữ** | Không tốn thêm | Tốn thêm (nhân đôi data) |
| **Latency** | Phụ thuộc nguồn gốc | Nhanh (data ở local) |
| **Khi nào dùng** | Data partner, ADLS Gen2 hiện có | Cần transform, cần Delta format |
| **Ví dụ RetailVN** | Shortcut tới data ERP cũ trên ADLS | Copy từ Azure SQL vào Bronze Lakehouse |

### OneLake File Explorer (Windows)

> **Tip cho Data Engineer:** Microsoft cung cấp **OneLake File Explorer** — một ứng dụng Windows tích hợp OneLake vào Windows Explorer như ổ đĩa mạng. Bạn có thể kéo thả file Delta, Parquet trực tiếp vào Lakehouse mà không cần portal. Tải tại: **Fabric Settings** > **OneLake** > **Download OneLake File Explorer**.

---

## Phase 3: Xây dựng Lakehouse & Medallion Architecture

> **Mục đích:** Medallion Architecture chia dữ liệu thành 3 tầng chất lượng tăng dần. Trong Fabric, chúng ta có thể implement theo 2 cách: **3 Lakehouse riêng biệt** (cô lập rõ ràng, phân quyền theo tầng) hoặc **1 Lakehouse với 3 Schema** (đơn giản hơn, chia sẻ một endpoint). Lab này sử dụng **3 Lakehouse riêng biệt** theo chuẩn Enterprise.

### Bước 1: Tạo Bronze Lakehouse

> **Bronze Layer:** Nơi lưu trữ dữ liệu thô (raw), nguyên bản từ nguồn. Không được sửa đổi nội dung. Đây là "Single Source of Truth" để replay nếu cần.

1. Trong Workspace `RetailVN-DataPlatform`, click **+ New item**.
2. Tìm và chọn **Lakehouse**.
3. **Name:** `LH_Bronze_RetailVN`
4. Click **Create**. Fabric sẽ khởi tạo Lakehouse với hai khu vực:
   - **Tables/**: Lưu Delta Tables (có thể query bằng SQL).
   - **Files/**: Lưu file thô (CSV, JSON, Parquet, hình ảnh...).

### Bước 2: Tạo Silver & Gold Lakehouse

Lặp lại quy trình trên để tạo thêm 2 Lakehouse:
- **Name:** `LH_Silver_RetailVN` — Dữ liệu đã được làm sạch, validate, join.
- **Name:** `LH_Gold_RetailVN` — Dữ liệu aggregate, business-ready, forecast results.

> **Mẹo:** Sau khi tạo xong 3 Lakehouse, trong màn hình Workspace bạn sẽ thấy mỗi Lakehouse đi kèm với một **SQL Analytics Endpoint** tự động (hình biểu tượng SQL). Đây là cách bạn kết nối Power BI hay chạy T-SQL trực tiếp lên data mà không cần cấu hình thêm bất cứ thứ gì.

### Bước 3: Delta Table Format — Deep Dive

> **Delta Lake là gì?** Delta Lake là một storage layer mã nguồn mở chạy trên dữ liệu Parquet, thêm vào các tính năng của một database thực sự:
>
> - **ACID Transactions:** Đảm bảo dữ liệu không bị corrupt khi nhiều job ghi đồng thời.
> - **Time Travel:** `SELECT * FROM sales VERSION AS OF 3` — quay ngược về phiên bản thứ 3.
> - **Schema Enforcement:** Từ chối ghi nếu schema không khớp.
> - **Upsert (MERGE):** Hỗ trợ SCD Type 2 mà không cần stored procedure.
> - **Transaction Log:** Mọi thao tác được ghi vào `_delta_log/` dưới dạng JSON — audit trail hoàn hảo.

Để xem chi tiết Delta Log của một bảng, chạy lệnh sau trong Notebook:
```python
# Xem lịch sử thay đổi của bảng Delta
display(spark.sql("DESCRIBE HISTORY LH_Bronze_RetailVN.sales_transactions"))
```

Cấu hình Table Properties quan trọng cho môi trường production:
```sql
-- Bật tính năng Change Data Feed để downstream consumer đọc incremental
ALTER TABLE LH_Bronze_RetailVN.sales_transactions
SET TBLPROPERTIES (
    'delta.enableChangeDataFeed' = 'true',
    'delta.autoOptimize.optimizeWrite' = 'true',     -- Tự động gộp small files khi ghi
    'delta.autoOptimize.autoCompact' = 'true',        -- Tự động compact định kỳ
    'delta.logRetentionDuration' = 'interval 30 days' -- Giữ lịch sử 30 ngày
);
```

---

## Phase 4: Data Ingestion — Batch Path (Dataflow Gen2 & Pipelines)

> **Mục đích:** Hàng đêm vào lúc 2:00 AM, pipeline sẽ tự động kéo toàn bộ giao dịch bán hàng trong ngày từ Azure SQL vào Bronze Lakehouse, sau đó trigger job transform lên Silver.

### Bước 1: Tạo Dataflow Gen2 cho No-Code ETL

> **Dataflow Gen2 là gì?** Dataflow Gen2 là công cụ ETL low-code/no-code trong Fabric, tương tự Power Query nhưng chạy ở cloud scale. Nó hỗ trợ 150+ connectors và cho phép Data Analyst (không biết code) tự xây dựng pipeline ingestion. Kết quả được tự động chuyển đổi thành Spark job ở backend.

1. Trong Workspace, click **+ New item** > **Dataflow Gen2**.
2. **Name:** `DFG2_Ingest_SalesTransactions`
3. Giao diện Power Query sẽ mở. Click **Get data** ở thanh trên.
4. Tìm và chọn **Azure SQL Database**.
5. Điền thông tin kết nối Azure SQL của RetailVN:
   - **Server:** `sqlserver-retailvn.database.windows.net`
   - **Database:** `retailvn-operational`
   - **Authentication kind:** Chọn **Organizational account** hoặc **Basic** với credentials.
6. Chọn bảng **`dbo.SalesTransactions`** và click **Select related tables** để kéo thêm các bảng liên quan (Products, Stores).
7. **Áp dụng các transformation trong Power Query Editor:**

   ```
   # Bước transform tiêu biểu:
   - Remove Columns: Xóa các cột internal không cần thiết (audit columns của ERP)
   - Filter Rows: Chỉ lấy giao dịch có TransactionDate = Date.From(DateTime.LocalNow()) - 1
   - Change Type: Đảm bảo kiểu dữ liệu chính xác (Decimal cho Amount, Date cho TransactionDate)
   - Rename Columns: Đổi tên theo naming convention: snake_case
   ```

8. Cấu hình **Data destination**:
   - Click **Add data destination** ở góc dưới phải.
   - Chọn **Lakehouse**.
   - Chọn **LH_Bronze_RetailVN** > **Tables** > **New table** > **sales_transactions_raw**.
   - **Update method:** Chọn **Append** (thêm mới, không xóa cũ).
9. Click **Publish** để lưu Dataflow.

> **Tại sao dùng Append thay vì Replace ở Bronze?** Bronze Layer phải là immutable (bất biến). Nếu Replace, bạn sẽ mất dữ liệu lịch sử và không thể replay khi có bug. Append đảm bảo mọi bản ghi gốc đều được lưu giữ vĩnh viễn.

### Bước 2: Tạo Fabric Pipeline cho Orchestration

> **Fabric Pipeline vs. Dataflow:** Dataflow Gen2 giỏi về transformation và có giao diện no-code. Nhưng để **orchestrate** nhiều bước (chạy A xong mới chạy B, nếu lỗi thì notify), bạn cần **Fabric Pipeline** — tương tự Azure Data Factory nhưng tích hợp native trong Fabric.

1. Trong Workspace, click **+ New item** > **Data pipeline**.
2. **Name:** `PL_NightlyBatch_RetailVN`
3. Trong Pipeline Editor, thêm các Activities theo thứ tự:

**Activity 1: Validate Source Connectivity**
- Kéo **Script activity** vào canvas. Đổi tên: `ValidateSource`.
- Trong tab **Settings**: Chọn connection tới Azure SQL, chạy script:
  ```sql
  -- Kiểm tra có data mới hôm qua không
  SELECT COUNT(*) AS RecordCount
  FROM dbo.SalesTransactions
  WHERE CAST(TransactionDate AS DATE) = CAST(GETDATE() - 1 AS DATE)
  ```
- Nếu count = 0, pipeline sẽ vẫn chạy nhưng ghi log cảnh báo.

**Activity 2: Run Dataflow Gen2**
- Kéo **Dataflow activity** vào canvas. Đổi tên: `IngestToBronze`.
- Kết nối mũi tên **Success** từ `ValidateSource` sang `IngestToBronze`.
- Trong tab **Settings**: Chọn Dataflow `DFG2_Ingest_SalesTransactions`.

**Activity 3: Trigger Spark Notebook (Silver Transform)**
- Kéo **Notebook activity**. Đổi tên: `TransformToSilver`.
- Kết nối **Success** từ `IngestToBronze`.
- Trong **Settings**: Chọn Notebook `NB_Silver_Transform` (sẽ tạo ở Phase 6).
- Trong **Base parameters**: Thêm parameter `processing_date` với giá trị `@formatDateTime(addDays(utcNow(), -1), 'yyyy-MM-dd')`.

**Activity 4: Send Notification on Failure**
- Kéo **Office 365 Outlook activity**. Đổi tên: `NotifyOnFailure`.
- Kết nối **mũi tên đỏ (Failure)** từ cả 3 activities trên vào đây.
- Cấu hình email thông báo tới team Data Engineering khi có lỗi.

### Bước 3: Thiết lập Schedule Trigger

1. Trong Pipeline Editor, click **Schedule** ở thanh menu trên.
2. Click **+ Add schedule trigger**.
3. Cấu hình:
   - **Repeat:** Daily
   - **Time:** 02:00 AM (Indochina Time / UTC+7)
   - **Start date:** Ngày hôm nay.
   - **Timezone:** SE Asia Standard Time
4. Click **Apply**.

> **Best Practice — Trigger Window:** Chọn thời gian chạy lúc 2:00 AM — sau giờ cao điểm của cửa hàng (thường đóng cửa lúc 22:00) và trước khi người dùng bắt đầu xem báo cáo buổi sáng (7:00 AM). Đây là "maintenance window" tiêu chuẩn trong enterprise.

---

## Phase 5: Data Ingestion — Real-Time Path (Eventstream & KQL)

> **Mục đích:** Hệ thống POS của 500 cửa hàng gửi event tồn kho mỗi khi có giao dịch bán hàng. Chúng ta cần nhận, xử lý và lưu trữ real-time data này để cảnh báo khi tồn kho xuống thấp.

### Bước 1: Tạo KQL Database (Real-Time Store)

> **KQL Database là gì?** KQL Database (Kusto Query Language Database) là một time-series database được tối ưu hóa cho dữ liệu real-time. Không giống SQL Database (tối ưu cho OLTP) hay Lakehouse (tối ưu cho batch analytics), KQL Database có thể ingest **hàng triệu events/giây** và query kết quả trong **milliseconds** nhờ kiến trúc columnar store với index tự động.

1. Trong Workspace, click **+ New item** > **KQL Database** (có thể tìm trong mục Real-Time Intelligence).
2. **Name:** `KQL_Inventory_RetailVN`
3. Chọn **New database** > Click **Create**.
4. Sau khi tạo, mở KQL Database Editor và tạo bảng nhận inventory events:

```kql
// Tạo bảng lưu inventory events từ POS systems
.create table InventoryEvents (
    EventTime: datetime,
    StoreId: string,
    ProductId: string,
    ProductName: string,
    CurrentStock: int,
    TransactionType: string,    // 'SALE', 'RESTOCK', 'ADJUSTMENT'
    QuantityChanged: int,
    WarehouseRegion: string
)

// Cấu hình retention policy: giữ raw events 90 ngày
.alter-merge table InventoryEvents policy retention softdelete = 90d

// Tạo materialized view để tính tồn kho hiện tại theo thời gian thực
.create materialized-view with (backfill=true) CurrentStockByProduct on table InventoryEvents
{
    InventoryEvents
    | summarize CurrentStock = take_any(CurrentStock) by StoreId, ProductId, ProductName
    | where EventTime == max(EventTime)
}
```

### Bước 2: Tạo Eventstream — Kết nối POS Systems

> **Eventstream là gì?** Eventstream là dịch vụ trong Fabric cho phép nhận, route và process real-time data streams từ nhiều nguồn (Azure Event Hub, IoT Hub, Custom App, Kafka...) và đưa tới nhiều đích (KQL Database, Lakehouse, Custom Endpoint...). Eventstream thay thế hoàn toàn Azure Stream Analytics trong hệ sinh thái Fabric.

1. Trong Workspace, click **+ New item** > **Eventstream**.
2. **Name:** `ES_POS_InventoryStream`
3. Trong Eventstream Editor, thêm **Source**:
   - Click **New source** > Chọn **Azure Event Hubs** (POS systems của RetailVN gửi events tới Event Hub).
   - Điền connection string của Event Hub: `retailvn-pos-eventhub`.
   - **Consumer group:** `fabric-eventstream`
   - **Data format:** `JSON`
4. Thêm **Transformation** (tùy chọn):
   - Click **Operations** > **Filter**: Loại bỏ events có `CurrentStock < 0` (dữ liệu lỗi từ POS).
   - Click **Operations** > **Manage fields**: Thêm cột `ProcessedTime = EventEnqueuedUtcTime`.
5. Thêm **Destination** tới KQL Database:
   - Click **New destination** > Chọn **KQL Database**.
   - Chọn `KQL_Inventory_RetailVN` > Table `InventoryEvents`.
   - Click **Add**.
6. Thêm **Destination** thứ hai tới Bronze Lakehouse (để lưu raw events cho analytics):
   - Click **New destination** > Chọn **Lakehouse**.
   - Chọn `LH_Bronze_RetailVN` > **New table** > `pos_events_raw`.
7. Click **Publish** để activate Eventstream.

> **Kiến trúc Fan-Out:** Lưu ý rằng Eventstream được cấu hình gửi data tới **hai đích cùng lúc**: KQL Database (cho real-time alerts) và Bronze Lakehouse (cho historical analysis). Đây là pattern "fan-out" — một stream, nhiều consumer — giúp tránh phải copy data hay chạy pipeline riêng biệt.

### Bước 3: Xây dựng Real-Time Dashboard

1. Trong Workspace, click **+ New item** > **Real-Time Dashboard**.
2. **Name:** `RTD_Inventory_Monitor`
3. Click **New data source** > Chọn **KQL Database** > Chọn `KQL_Inventory_RetailVN`.
4. Thêm các tile query:

**Tile 1 — Cảnh báo tồn kho thấp:**
```kql
InventoryEvents
| where EventTime > ago(1h)
| summarize LatestStock = arg_max(EventTime, CurrentStock) by StoreId, ProductId, ProductName
| where LatestStock.CurrentStock < 10
| project StoreId, ProductId, ProductName, CurrentStock = LatestStock.CurrentStock
| order by CurrentStock asc
```

**Tile 2 — Biểu đồ tồn kho theo thời gian (5 phút/interval):**
```kql
InventoryEvents
| where EventTime > ago(6h)
| where StoreId == "HN001"           // Filter by store
| summarize AvgStock = avg(CurrentStock) by bin(EventTime, 5m), ProductId
| render timechart
```

**Tile 3 — Top 10 sản phẩm bán chạy nhất hôm nay:**
```kql
InventoryEvents
| where EventTime > startofday(now()) and TransactionType == "SALE"
| summarize TotalSold = sum(abs(QuantityChanged)) by ProductName
| top 10 by TotalSold desc
```

5. Đặt **Auto-refresh: 30 seconds** cho Dashboard.
6. Click **Save** và **Share** với Operations team.

---

## Phase 6: Data Transformation với Spark Notebooks

> **Mục đích:** Chuyển dữ liệu thô từ Bronze sang Silver, áp dụng data quality checks, handle SCD Type 2 với Delta MERGE, và tối ưu hóa Delta tables cho query performance.

### Bước 1: Tạo Silver Transformation Notebook

1. Trong Workspace, click **+ New item** > **Notebook**.
2. **Name:** `NB_Silver_Transform`
3. Trong Notebook, click **Add lakehouse** > Chọn cả `LH_Bronze_RetailVN` và `LH_Silver_RetailVN`.
4. Dán code PySpark sau vào các cells:

**Cell 1 — Setup & Configuration:**
```python
# ============================================================
# NB_Silver_Transform: Bronze → Silver Transformation
# Business: RetailVN 500 Stores
# Author: Data Engineering Team
# ============================================================

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, trim, upper, lower, to_date, to_timestamp,
    when, isnan, isnull, regexp_replace, lit,
    current_timestamp, sha2, concat_ws, coalesce,
    year, month, dayofmonth, hour
)
from pyspark.sql.types import DecimalType, IntegerType, StringType
from delta.tables import DeltaTable
import logging

# Logging configuration
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("SilverTransform")

# Parameters (injected from Pipeline trigger)
dbutils.widgets.text("processing_date", "")
processing_date = dbutils.widgets.get("processing_date")

if not processing_date:
    from datetime import datetime, timedelta
    processing_date = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")

logger.info(f"Processing date: {processing_date}")
print(f"✅ Processing date: {processing_date}")
```

**Cell 2 — Data Quality Check Function:**
```python
def run_data_quality_checks(df, table_name: str) -> dict:
    """
    Chạy các kiểm tra chất lượng dữ liệu và trả về báo cáo.
    Trong enterprise, kết quả này thường được ghi vào Data Quality Log table.
    """
    total_rows = df.count()
    
    quality_report = {
        "table": table_name,
        "total_rows": total_rows,
        "checks": {}
    }
    
    # Check 1: Null check trên các cột bắt buộc
    mandatory_cols = ["transaction_id", "store_id", "product_id", "transaction_date", "amount"]
    for col_name in mandatory_cols:
        if col_name in df.columns:
            null_count = df.filter(col(col_name).isNull() | (col(col_name) == "")).count()
            quality_report["checks"][f"null_{col_name}"] = {
                "null_count": null_count,
                "pass": null_count == 0
            }
    
    # Check 2: Amount phải dương (không âm)
    if "amount" in df.columns:
        negative_amount = df.filter(col("amount") <= 0).count()
        quality_report["checks"]["negative_amount"] = {
            "count": negative_amount,
            "pass": negative_amount == 0
        }
    
    # Check 3: Date range hợp lệ (không có ngày tương lai)
    if "transaction_date" in df.columns:
        future_dates = df.filter(col("transaction_date") > current_timestamp()).count()
        quality_report["checks"]["future_dates"] = {
            "count": future_dates,
            "pass": future_dates == 0
        }
    
    # In báo cáo
    passed = sum(1 for c in quality_report["checks"].values() if c.get("pass", False))
    total_checks = len(quality_report["checks"])
    print(f"📊 DQ Report for {table_name}: {passed}/{total_checks} checks passed")
    
    for check_name, result in quality_report["checks"].items():
        icon = "✅" if result.get("pass") else "❌"
        print(f"  {icon} {check_name}: {result}")
    
    return quality_report
```

**Cell 3 — Read & Transform Sales Transactions:**
```python
# ---- READ FROM BRONZE ----
bronze_sales = (
    spark.read.table("LH_Bronze_RetailVN.sales_transactions_raw")
    .filter(col("transaction_date") == processing_date)
)

print(f"📥 Bronze records loaded: {bronze_sales.count():,}")

# ---- TRANSFORMATION ----
silver_sales = (
    bronze_sales
    # 1. Standardize string columns
    .withColumn("store_id", trim(upper(col("store_id"))))
    .withColumn("product_id", trim(upper(col("product_id"))))
    .withColumn("cashier_name", trim(col("cashier_name")))
    
    # 2. Fix data types
    .withColumn("amount", col("amount").cast(DecimalType(18, 2)))
    .withColumn("quantity", col("quantity").cast(IntegerType()))
    .withColumn("transaction_date", to_timestamp(col("transaction_date"), "yyyy-MM-dd HH:mm:ss"))
    
    # 3. Derive new columns
    .withColumn("transaction_year", year(col("transaction_date")))
    .withColumn("transaction_month", month(col("transaction_date")))
    .withColumn("transaction_day", dayofmonth(col("transaction_date")))
    .withColumn("transaction_hour", hour(col("transaction_date")))
    
    # 4. Categorize transaction size
    .withColumn("transaction_tier",
        when(col("amount") >= 5_000_000, "Premium")
        .when(col("amount") >= 1_000_000, "Standard")
        .otherwise("Small")
    )
    
    # 5. Generate surrogate key
    .withColumn("transaction_key", sha2(
        concat_ws("|", col("transaction_id"), col("store_id"), col("transaction_date")), 256
    ))
    
    # 6. Add audit columns
    .withColumn("silver_load_ts", current_timestamp())
    .withColumn("source_system", lit("RetailVN-POS"))
    
    # 7. Drop rows with null mandatory keys (kết quả DQ check thất bại)
    .filter(col("transaction_id").isNotNull())
    .filter(col("amount") > 0)
    .dropDuplicates(["transaction_id"])
)

# Run data quality checks
dq_report = run_data_quality_checks(silver_sales, "silver_sales_transactions")

print(f"📤 Silver records to write: {silver_sales.count():,}")
```

**Cell 4 — Write to Silver with Delta MERGE (SCD Type 1):**
```python
# ---- WRITE TO SILVER LAKEHOUSE ----
silver_table_name = "LH_Silver_RetailVN.sales_transactions"

# Kiểm tra bảng đích đã tồn tại chưa
table_exists = spark.catalog.tableExists(silver_table_name)

if not table_exists:
    # Lần đầu: ghi trực tiếp và tạo bảng mới
    (silver_sales.write
        .format("delta")
        .mode("overwrite")
        .partitionBy("transaction_year", "transaction_month")
        .saveAsTable(silver_table_name))
    print(f"✅ Created new Silver table: {silver_table_name}")
else:
    # Các lần tiếp theo: dùng MERGE (UPSERT) để tránh duplicate
    delta_target = DeltaTable.forName(spark, silver_table_name)
    
    (delta_target.alias("target")
        .merge(
            silver_sales.alias("source"),
            "target.transaction_id = source.transaction_id"
        )
        # Nếu transaction đã tồn tại, cập nhật (SCD Type 1)
        .whenMatchedUpdateAll()
        # Nếu transaction mới, thêm vào
        .whenNotMatchedInsertAll()
        .execute()
    )
    
    # Lấy metrics sau MERGE
    merge_metrics = spark.sql(f"""
        SELECT operationMetrics
        FROM (DESCRIBE HISTORY {silver_table_name})
        LIMIT 1
    """).collect()[0][0]
    
    print(f"✅ MERGE completed: {merge_metrics}")
```

**Cell 5 — SCD Type 2 cho Product Dimension:**
```python
# ---- SCD TYPE 2 PATTERN cho Products (giữ lịch sử thay đổi giá) ----
from pyspark.sql.functions import expr

bronze_products = spark.read.table("LH_Bronze_RetailVN.products_raw")
silver_products_table = "LH_Silver_RetailVN.dim_products"

# Source data mới nhất
source_df = (bronze_products
    .withColumn("effective_start_date", current_timestamp())
    .withColumn("effective_end_date", lit(None).cast("timestamp"))
    .withColumn("is_current", lit(True))
    .withColumn("row_hash", sha2(
        concat_ws("|", col("product_id"), col("product_name"), col("unit_price"), col("category")), 256
    ))
)

if spark.catalog.tableExists(silver_products_table):
    delta_target = DeltaTable.forName(spark, silver_products_table)
    
    (delta_target.alias("target")
        .merge(
            source_df.alias("source"),
            # Chỉ match trên natural key + is_current để không đụng vào record cũ đã expire
            "target.product_id = source.product_id AND target.is_current = true"
        )
        # Nếu hash thay đổi = giá hoặc tên sản phẩm thay đổi → EXPIRE record cũ
        .whenMatchedUpdate(
            condition = "target.row_hash != source.row_hash",
            set = {
                "is_current": "false",
                "effective_end_date": "source.effective_start_date"
            }
        )
        # Không làm gì nếu hash giống nhau (không có thay đổi)
        .whenNotMatchedInsertAll()  # Thêm record mới (kể cả version mới của sản phẩm đã thay đổi)
        .execute()
    )
    print("✅ SCD Type 2 MERGE completed for dim_products")
else:
    source_df.write.format("delta").mode("overwrite").saveAsTable(silver_products_table)
    print("✅ Created new dim_products table")
```

**Cell 6 — Delta Table Optimization:**
```python
# ---- TABLE OPTIMIZATION ----
# Chạy sau khi ghi dữ liệu để cải thiện query performance

print("🔧 Running OPTIMIZE & ZORDER...")

# OPTIMIZE: Gộp nhiều small Parquet files thành ít file lớn hơn
# Đây là bước quan trọng vì streaming/micro-batch tạo ra nhiều small files
spark.sql(f"""
    OPTIMIZE {silver_table_name}
    ZORDER BY (store_id, product_id)
""")
# ZORDER BY: Sắp xếp dữ liệu vật lý theo store_id và product_id
# → Khi query WHERE store_id = 'HN001', Spark chỉ đọc các file liên quan (data skipping)
# → Giảm 70-90% dữ liệu phải scan, query nhanh hơn nhiều lần

# Xóa file Delta cũ không còn được tham chiếu (sau 7 ngày)
spark.sql(f"VACUUM {silver_table_name} RETAIN 168 HOURS")

print("✅ Optimization completed!")
print(f"📊 Table stats:")
display(spark.sql(f"DESCRIBE DETAIL {silver_table_name}"))
```

---

## Phase 7: ML với Fabric MLflow — Demand Forecasting

> **Mục đích:** Xây dựng mô hình dự báo nhu cầu (Demand Forecasting) sử dụng dữ liệu lịch sử bán hàng từ Silver Layer. Kết quả dự báo được lưu vào Gold Layer để Power BI hiển thị cho Purchasing team.

### Bước 1: Tạo ML Experiment Notebook

1. Trong Workspace, click **+ New item** > **Notebook**.
2. **Name:** `NB_ML_DemandForecasting`
3. Kết nối tới `LH_Silver_RetailVN` và `LH_Gold_RetailVN`.

**Cell 1 — MLflow Setup trong Fabric:**
```python
# ============================================================
# NB_ML_DemandForecasting: Demand Forecasting với MLflow
# Algorithm: LightGBM Regression
# Target: Dự báo sales_quantity 7 ngày tiếp theo theo (store, product)
# ============================================================

import mlflow
import mlflow.lightgbm
import lightgbm as lgb
import pandas as pd
import numpy as np
from sklearn.model_selection import TimeSeriesSplit
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from pyspark.sql.functions import col, lag, avg, stddev
from pyspark.sql.window import Window

# Trong Fabric, MLflow tự động kết nối tới Fabric ML Experiment
# Không cần set tracking URI thủ công như Databricks
mlflow.set_experiment("RetailVN_DemandForecasting_v2")
print("✅ MLflow Experiment configured")
print(f"📍 Tracking URI: {mlflow.get_tracking_uri()}")
```

**Cell 2 — Feature Engineering:**
```python
# ---- FEATURE ENGINEERING ----
# Đọc 90 ngày lịch sử bán hàng từ Silver
raw_df = spark.sql("""
    SELECT
        transaction_date,
        store_id,
        product_id,
        SUM(quantity) as daily_quantity,
        SUM(amount) as daily_revenue,
        COUNT(*) as transaction_count
    FROM LH_Silver_RetailVN.sales_transactions
    WHERE transaction_date >= date_sub(current_date(), 90)
    GROUP BY transaction_date, store_id, product_id
    ORDER BY store_id, product_id, transaction_date
""")

# Tạo Lag Features (lịch sử bán hàng 1, 7, 14 ngày trước)
window_spec = Window.partitionBy("store_id", "product_id").orderBy("transaction_date")

feature_df = (raw_df
    .withColumn("qty_lag_1d", lag("daily_quantity", 1).over(window_spec))
    .withColumn("qty_lag_7d", lag("daily_quantity", 7).over(window_spec))
    .withColumn("qty_lag_14d", lag("daily_quantity", 14).over(window_spec))
    .withColumn("qty_rolling_7d_avg",
        avg("daily_quantity").over(window_spec.rowsBetween(-7, -1)))
    .withColumn("qty_rolling_7d_std",
        stddev("daily_quantity").over(window_spec.rowsBetween(-7, -1)))
    .dropna()
)

# Convert sang Pandas để train ML model
train_pd = feature_df.toPandas()
train_pd["transaction_date"] = pd.to_datetime(train_pd["transaction_date"])
train_pd["day_of_week"] = train_pd["transaction_date"].dt.dayofweek
train_pd["is_weekend"] = (train_pd["day_of_week"] >= 5).astype(int)
train_pd["day_of_month"] = train_pd["transaction_date"].dt.day
train_pd["month"] = train_pd["transaction_date"].dt.month

print(f"📊 Training data shape: {train_pd.shape}")
print(train_pd.head(3))
```

**Cell 3 — Train Model với MLflow Tracking:**
```python
# ---- FEATURE COLUMNS ----
feature_cols = [
    "qty_lag_1d", "qty_lag_7d", "qty_lag_14d",
    "qty_rolling_7d_avg", "qty_rolling_7d_std",
    "day_of_week", "is_weekend", "day_of_month", "month",
    "transaction_count"
]
target_col = "daily_quantity"

X = train_pd[feature_cols]
y = train_pd[target_col]

# Time-Series Cross Validation (không dùng random split vì data có thứ tự thời gian!)
tscv = TimeSeriesSplit(n_splits=5)

# ---- MLFLOW EXPERIMENT RUN ----
with mlflow.start_run(run_name="LightGBM_RetailVN_v1") as run:
    run_id = run.info.run_id
    print(f"🚀 MLflow Run ID: {run_id}")
    
    # Hyperparameters
    params = {
        "objective": "regression",
        "metric": "mae",
        "learning_rate": 0.05,
        "num_leaves": 31,
        "max_depth": -1,
        "n_estimators": 500,
        "min_data_in_leaf": 20,
        "feature_fraction": 0.8,
        "bagging_fraction": 0.8,
        "bagging_freq": 5,
        "random_state": 42
    }
    mlflow.log_params(params)
    
    # Train với cross-validation
    cv_maes = []
    cv_rmses = []
    
    for fold, (train_idx, val_idx) in enumerate(tscv.split(X)):
        X_train, X_val = X.iloc[train_idx], X.iloc[val_idx]
        y_train, y_val = y.iloc[train_idx], y.iloc[val_idx]
        
        model = lgb.LGBMRegressor(**params)
        model.fit(
            X_train, y_train,
            eval_set=[(X_val, y_val)],
            callbacks=[lgb.early_stopping(50), lgb.log_evaluation(100)]
        )
        
        y_pred = model.predict(X_val)
        mae = mean_absolute_error(y_val, y_pred)
        rmse = np.sqrt(mean_squared_error(y_val, y_pred))
        
        cv_maes.append(mae)
        cv_rmses.append(rmse)
        mlflow.log_metric(f"fold_{fold}_mae", mae)
        mlflow.log_metric(f"fold_{fold}_rmse", rmse)
    
    # Log average metrics
    avg_mae = np.mean(cv_maes)
    avg_rmse = np.mean(cv_rmses)
    mlflow.log_metric("cv_avg_mae", avg_mae)
    mlflow.log_metric("cv_avg_rmse", avg_rmse)
    
    print(f"📈 CV Average MAE: {avg_mae:.2f}")
    print(f"📈 CV Average RMSE: {avg_rmse:.2f}")
    
    # Train final model trên toàn bộ data
    final_model = lgb.LGBMRegressor(**params)
    final_model.fit(X, y)
    
    # Log Feature Importance
    feature_importance = pd.DataFrame({
        "feature": feature_cols,
        "importance": final_model.feature_importances_
    }).sort_values("importance", ascending=False)
    
    mlflow.log_text(feature_importance.to_string(), "feature_importance.txt")
    
    # Register Model vào Fabric ML Model Registry
    mlflow.lightgbm.log_model(
        final_model,
        artifact_path="demand_forecast_model",
        registered_model_name="RetailVN_DemandForecasting"
    )
    
    print(f"✅ Model registered: RetailVN_DemandForecasting")
    print(f"📁 Artifacts logged to MLflow Run: {run_id}")
```

**Cell 4 — Batch Inference & Write to Gold:**
```python
# ---- BATCH INFERENCE → GOLD LAYER ----
import mlflow.lightgbm

# Load model mới nhất từ Registry
model_name = "RetailVN_DemandForecasting"
model = mlflow.lightgbm.load_model(f"models:/{model_name}/latest")

# Dự báo 7 ngày tiếp theo cho mỗi cặp (store, product)
latest_features = feature_df.orderBy(
    col("store_id"), col("product_id"), col("transaction_date").desc()
).dropDuplicates(["store_id", "product_id"]).toPandas()

latest_X = latest_features[feature_cols]
forecasts = model.predict(latest_X)

forecast_df = latest_features[["store_id", "product_id"]].copy()
forecast_df["forecasted_quantity_7d"] = forecasts.round(0).astype(int)
forecast_df["recommended_reorder_qty"] = (forecast_df["forecasted_quantity_7d"] * 1.2).astype(int)
forecast_df["forecast_date"] = pd.Timestamp.now().strftime("%Y-%m-%d")
forecast_df["model_version"] = "latest"

# Write to Gold Lakehouse
forecast_spark = spark.createDataFrame(forecast_df)
(forecast_spark.write
    .format("delta")
    .mode("overwrite")
    .saveAsTable("LH_Gold_RetailVN.demand_forecast"))

print(f"✅ Forecast written to Gold: {forecast_spark.count():,} records")
display(forecast_spark.limit(10))
```

---

## Phase 8: Direct Lake Power BI — Self-Service BI

> **Mục đích:** Tạo Semantic Model kết nối trực tiếp với Gold Lakehouse qua chế độ Direct Lake — nhanh hơn DirectQuery, không cần import data, và luôn fresh theo thời gian thực.

### Direct Lake vs. Import vs. DirectQuery

> **So sánh ba chế độ kết nối Power BI:**
>
> | | **Import** | **DirectQuery** | **Direct Lake** |
> |---|---|---|---|
> | **Cách hoạt động** | Copy toàn bộ data vào RAM của Power BI | Mỗi visual gửi SQL query tới nguồn | Đọc Delta files trực tiếp từ OneLake |
> | **Tốc độ query** | ⚡ Nhanh nhất | 🐢 Chậm (phụ thuộc DB) | ⚡ Gần bằng Import |
> | **Data freshness** | ❌ Cũ (cần manual refresh) | ✅ Real-time | ✅ Luôn fresh |
> | **Giới hạn data** | ❌ Bị giới hạn bởi RAM | ✅ Không giới hạn | ✅ Không giới hạn |
> | **Chỉ hoạt động với** | Bất kỳ nguồn nào | Bất kỳ nguồn nào | **OneLake Delta Tables** |
>
> **Direct Lake là chế độ mặc định và được khuyến nghị cho mọi Lakehouse trong Fabric.**

### Bước 1: Tạo Semantic Model từ Gold Lakehouse

1. Mở `LH_Gold_RetailVN` trong Workspace.
2. Ở thanh trên, click **New semantic model** (hoặc vào **SQL Analytics Endpoint** > **Reporting** > **New semantic model**).
3. **Name:** `SM_RetailVN_Analytics`
4. Chọn các Delta Tables cần đưa vào model:
   - `LH_Gold_RetailVN.sales_summary_daily`
   - `LH_Gold_RetailVN.demand_forecast`
   - `LH_Silver_RetailVN.dim_products` (shortcut hoặc kéo từ Silver)
   - `LH_Silver_RetailVN.dim_stores`
5. Click **Confirm**. Fabric sẽ tạo Semantic Model với Direct Lake mode tự động.

### Bước 2: Định nghĩa Relationships & DAX Measures

1. Mở Semantic Model `SM_RetailVN_Analytics`.
2. Trong tab **Model view**, tạo relationships:
   - `sales_summary_daily[product_id]` → `dim_products[product_id]` (Many-to-One)
   - `sales_summary_daily[store_id]` → `dim_stores[store_id]` (Many-to-One)
   - `demand_forecast[product_id]` → `dim_products[product_id]` (Many-to-One)

3. Trong tab **Data view**, tạo các DAX Measures quan trọng:

```dax
-- Total Revenue (Tổng doanh thu)
Total Revenue = SUM(sales_summary_daily[daily_revenue])

-- Revenue MoM Growth (Tăng trưởng so với tháng trước)
Revenue MoM Growth % =
VAR CurrentRevenue = [Total Revenue]
VAR PreviousRevenue =
    CALCULATE(
        [Total Revenue],
        DATEADD(sales_summary_daily[transaction_date], -1, MONTH)
    )
RETURN
    DIVIDE(CurrentRevenue - PreviousRevenue, PreviousRevenue, 0)

-- Average Daily Transaction Value
Avg Transaction Value =
DIVIDE(
    SUM(sales_summary_daily[daily_revenue]),
    SUM(sales_summary_daily[transaction_count]),
    0
)

-- Stores with Low Forecast Stock Alert
Stores Needing Reorder =
CALCULATE(
    DISTINCTCOUNT(demand_forecast[store_id]),
    demand_forecast[recommended_reorder_qty] > 0
)

-- Revenue per Store
Revenue per Store =
DIVIDE([Total Revenue], DISTINCTCOUNT(sales_summary_daily[store_id]), 0)
```

### Bước 3: Cấu hình Incremental Refresh

> **Tại sao cần Incremental Refresh?** Khi bảng Gold có hàng tỷ dòng, không thể refresh toàn bộ mỗi lần. Incremental Refresh chỉ refresh dữ liệu mới (vài ngày gần nhất) và giữ nguyên dữ liệu cũ đã được cache. Điều này giảm 95% thời gian refresh.

> **Lưu ý:** Incremental Refresh trong Direct Lake mode hoạt động khác với Import mode. Trong Direct Lake, Fabric tự động biết partition nào cần refresh dựa trên Delta Log — không cần cấu hình thủ công như Import mode.

Để cấu hình (nếu cần hybrid mode):
1. Mở Power BI Desktop > Kết nối tới Semantic Model.
2. Right-click bảng `sales_summary_daily` > **Incremental refresh**.
3. Cấu hình:
   - **Archive data starting:** 3 years before refresh date.
   - **Refresh data starting:** 7 days before refresh date.
   - **Detect data changes:** Chọn cột `silver_load_ts`.

### Bước 4: Publish Report lên Fabric

1. Trong Workspace, click **+ New item** > **Report**.
2. Chọn Semantic Model `SM_RetailVN_Analytics`.
3. Xây dựng báo cáo với các visual:
   - **Card:** Total Revenue, Total Transactions, Stores with Low Stock Alert.
   - **Line Chart:** Revenue Trend by Week (last 12 weeks).
   - **Bar Chart:** Top 20 Products by Revenue.
   - **Map:** Revenue by Store Location (nếu có lat/long).
   - **Table:** Demand Forecast với Recommended Reorder Quantity.
4. **Name:** `RPT_RetailVN_Executive_Dashboard`
5. Click **Save** và **Publish to workspace**.

---

## Phase 9: Governance với Microsoft Purview Integration

> **Mục đích:** Quản trị dữ liệu (Data Governance) là yêu cầu bắt buộc trong môi trường enterprise. Microsoft Purview tích hợp native với Fabric để cung cấp Data Lineage, Sensitivity Labels, và Data Catalog — giúp đáp ứng các yêu cầu compliance (GDPR, PCI-DSS, ISO 27001).

### Bước 1: Kết nối Fabric với Microsoft Purview

> **Microsoft Purview là gì?** Microsoft Purview là nền tảng quản trị dữ liệu (Data Governance) của Microsoft, bao gồm Data Catalog (khám phá dữ liệu), Data Lineage (theo dõi nguồn gốc), Information Protection (phân loại độ nhạy cảm), và Compliance (tuân thủ quy định). Purview là giải pháp thay thế thế hệ mới của Azure Purview.

1. Trong Fabric Admin Portal (fabric.microsoft.com > Settings > Admin portal):
   - Vào **Tenant settings** > tìm **Microsoft Purview hub**.
   - Bật **Allow Purview integration** = **Enabled**.
2. Mở **Microsoft Purview** tại [purview.microsoft.com](https://purview.microsoft.com).
3. Trong Purview, vào **Data Map** > **Data sources** > **Register**.
4. Chọn **Microsoft Fabric** > Chọn tenant của bạn.
5. Cấu hình scan:
   - **Scan name:** `Fabric-RetailVN-Scan`
   - **Scan trigger:** Weekly (Chủ Nhật 0:00 AM)
   - **Scan scope:** Chọn Workspace `RetailVN-DataPlatform`
6. Click **Run scan** lần đầu để index tất cả Lakehouses.

### Bước 2: Gắn Sensitivity Labels

> **Sensitivity Labels (Nhãn Độ nhạy cảm):** Là cơ chế phân loại dữ liệu của Microsoft Information Protection. Khi bạn gắn nhãn "Confidential" lên một Delta Table, Purview sẽ tự động áp dụng encryption, prevent sharing, và audit access — phù hợp với GDPR cho dữ liệu cá nhân khách hàng.

1. Trong Purview > **Data Catalog** > Tìm bảng `LH_Silver_RetailVN.sales_transactions`.
2. Click vào bảng > Tab **Properties** > **Edit**.
3. Trong **Sensitivity label**: Chọn **Confidential - Finance** (cho dữ liệu giao dịch).
4. Lặp lại cho `dim_products` với label **General** (dữ liệu công khai nội bộ).
5. Với bất kỳ bảng nào chứa thông tin khách hàng (tên, email, SĐT): Chọn **Highly Confidential - GDPR**.

> **Quan trọng:** Khi Sensitivity Label được gắn trong Purview, Power BI reports kết nối tới data đó sẽ **tự động kế thừa** label. Nếu người dùng cố tải báo cáo chứa "Highly Confidential" data ra file Excel, hệ thống sẽ tự động mã hóa file đó.

### Bước 3: Xem Data Lineage

1. Trong Purview > **Data Catalog** > Tìm bảng `LH_Gold_RetailVN.demand_forecast`.
2. Click vào bảng > Tab **Lineage**.
3. Purview sẽ vẽ đồ thị lineage tự động:

```
Azure SQL (dbo.SalesTransactions)
    ↓  [Dataflow Gen2: DFG2_Ingest_SalesTransactions]
LH_Bronze_RetailVN.sales_transactions_raw
    ↓  [Notebook: NB_Silver_Transform]
LH_Silver_RetailVN.sales_transactions
    ↓  [Notebook: NB_ML_DemandForecasting]
LH_Gold_RetailVN.demand_forecast
    ↓  [Semantic Model: SM_RetailVN_Analytics]
RPT_RetailVN_Executive_Dashboard
```

> **Giá trị thực tế của Lineage:** Khi có sự cố (ví dụ: phát hiện bug trong Dataflow khiến dữ liệu bị sai), đồ thị lineage giúp Data Engineering team biết ngay **tất cả** các báo cáo Power BI và ML models nào đang bị ảnh hưởng — để thông báo cho stakeholders và rollback kịp thời.

### Bước 4: Data Catalog — Self-Service Discovery

1. Trong Purview > **Data Catalog** > **Browse by source type** > **Microsoft Fabric**.
2. Business Analysts có thể search: _"sales transactions"_ và tìm thấy bảng Silver đã được đội Data Engineering annotate với mô tả, business glossary terms, và sample data.
3. Thêm Business Glossary Term:
   - Vào **Glossary** > **New term** > Name: `Daily Revenue`
   - **Definition:** "Tổng doanh thu giao dịch trong một ngày, tính theo VNĐ, bao gồm VAT"
   - **Linked assets:** `LH_Silver_RetailVN.sales_transactions.daily_revenue`
4. Click **Save**. Business users giờ có thể tìm kiếm bằng business terms thay vì tên kỹ thuật.

---

## Phase 10: Monitoring, Alerting với Data Activator & Cleanup

> **Mục đích:** Data Activator là tính năng "no-code alerting engine" trong Fabric. Nó theo dõi dữ liệu trong KQL Database hoặc Power BI Report theo thời gian thực và tự động trigger actions (gửi email, gọi Power Automate, start Pipeline) khi điều kiện được thỏa mãn — mà không cần viết bất kỳ dòng code nào.

### Bước 1: Tạo Reflex (Data Activator Alert)

> **Reflex là gì?** Trong Data Activator, một "Reflex" là một rule engine: bạn định nghĩa **điều kiện** (khi tồn kho < 10 đơn vị) và **hành động** (gửi Teams message tới Store Manager). Data Activator liên tục monitor data và trigger action ngay khi điều kiện xảy ra.

1. Trong Workspace, click **+ New item** > **Reflex** (Data Activator).
2. **Name:** `REFLEX_LowInventoryAlert`
3. Chọn **KQL Database** làm nguồn dữ liệu > Chọn `KQL_Inventory_RetailVN`.
4. Cấu hình trigger query:
```kql
CurrentStockByProduct
| where CurrentStock < 10
| project StoreId, ProductId, ProductName, CurrentStock
```
5. Cấu hình **Action**:
   - **Action type:** Microsoft Teams message
   - **Recipient:** `@store-operations` team channel
   - **Message:** `⚠️ LOW STOCK ALERT: {ProductName} tại cửa hàng {StoreId} chỉ còn {CurrentStock} đơn vị. Cần đặt hàng ngay!`
6. **Check frequency:** Every 5 minutes.
7. Click **Create**.

### Bước 2: Monitor Fabric Capacity & Pipeline Health

> **Fabric Capacity Metrics App:** Microsoft cung cấp một Power BI app chuyên dụng để theo dõi việc sử dụng Capacity. Mỗi Spark Job, Notebook run, Pipeline activity đều tiêu thụ CU (Capacity Units). Nếu vượt quá quota, các job sẽ bị throttle.

1. Trong Fabric Admin Portal > **Capacity settings** > Chọn capacity của bạn.
2. Click **Open capacity metrics app** để mở Power BI dashboard theo dõi:
   - CU utilization by workload (Spark, SQL, Pipelines).
   - Throttling events.
   - Top consumers (Notebooks, Lakehouses).

**Kiểm tra Pipeline Runs:**
1. Trong Workspace, mở Pipeline `PL_NightlyBatch_RetailVN`.
2. Click **Run history** để xem toàn bộ lần chạy: thời gian, status, duration của từng activity.
3. Nếu có lần chạy Failed, click vào để xem error message và stack trace.

**Kiểm tra Notebook Spark Jobs:**
1. Trong bất kỳ Notebook nào, click biểu tượng **Spark** ở góc trên để mở Spark UI.
2. Spark UI hiển thị DAG execution, Stage timing, và Task distribution — giúp identify bottleneck trong Spark job.

### Bước 3: End-to-End Validation

Chạy bộ kiểm tra toàn diện để xác nhận toàn bộ pipeline hoạt động đúng:

```python
# Notebook: NB_E2E_Validation
# Chạy sau khi toàn bộ các Phase đã được thiết lập

print("=" * 60)
print("END-TO-END VALIDATION: RetailVN Data Platform")
print("=" * 60)

checks = []

# Check 1: Bronze data ingested today
bronze_count = spark.sql("""
    SELECT COUNT(*) as cnt FROM LH_Bronze_RetailVN.sales_transactions_raw
    WHERE CAST(transaction_date AS DATE) = CURRENT_DATE() - 1
""").collect()[0]['cnt']
checks.append(("Bronze Ingestion", bronze_count > 0, f"{bronze_count:,} records"))

# Check 2: Silver transformation ran
silver_count = spark.sql("""
    SELECT COUNT(*) as cnt FROM LH_Silver_RetailVN.sales_transactions
    WHERE CAST(transaction_date AS DATE) = CURRENT_DATE() - 1
""").collect()[0]['cnt']
checks.append(("Silver Transform", silver_count > 0, f"{silver_count:,} records"))

# Check 3: No data quality issues
null_check = spark.sql("""
    SELECT COUNT(*) as cnt FROM LH_Silver_RetailVN.sales_transactions
    WHERE transaction_id IS NULL OR amount IS NULL
""").collect()[0]['cnt']
checks.append(("Data Quality", null_check == 0, f"{null_check} null records"))

# Check 4: Gold forecast updated
gold_count = spark.sql("""
    SELECT COUNT(*) as cnt FROM LH_Gold_RetailVN.demand_forecast
    WHERE forecast_date = CURRENT_DATE()
""").collect()[0]['cnt']
checks.append(("Gold Forecast", gold_count > 0, f"{gold_count:,} store-product forecasts"))

# Print results
for check_name, passed, detail in checks:
    icon = "✅" if passed else "❌"
    print(f"{icon} {check_name}: {detail}")

all_passed = all(passed for _, passed, _ in checks)
print("\n" + "=" * 60)
print(f"OVERALL STATUS: {'✅ ALL CHECKS PASSED' if all_passed else '❌ SOME CHECKS FAILED'}")
print("=" * 60)
```

### Bước 4: Dọn Dẹp Tài Nguyên (Cleanup)

> **Mục đích:** Sau khi hoàn thành Lab, xóa toàn bộ tài nguyên để tránh tốn Fabric Capacity (trial có hạn 60 ngày nhưng vẫn nên quản lý tốt). Không giống Azure Portal (cần xóa từng resource), trong Fabric chỉ cần xóa Workspace là toàn bộ items và data trong đó sẽ được dọn sạch.

1. Vào **Workspaces** > Click **...** bên cạnh `RetailVN-DataPlatform`.
2. Chọn **Workspace settings** > Kéo xuống cuối trang.
3. Click **Delete this workspace** > Nhập tên workspace để xác nhận > Click **Delete**.

> **Lưu ý:** Xóa Workspace sẽ xóa toàn bộ Lakehouses, Notebooks, Pipelines, Reports, Eventstreams, KQL Databases trong đó. Data trong OneLake được lưu trữ trong Workspace cũng sẽ bị xóa vĩnh viễn. Hãy backup bất kỳ dữ liệu nào quan trọng trước khi xóa.

Nếu có sử dụng Azure Resources bên ngoài (Azure SQL, Azure Event Hub):
1. Đăng nhập [portal.azure.com](https://portal.azure.com).
2. Vào **Resource groups** > Tìm resource group liên quan (ví dụ: `rg-retailvn-lab`).
3. Click **Delete resource group** > Xác nhận tên > Click **Delete**.

---

## Tổng Kết & Các Khái niệm Chính

Bạn vừa xây dựng một **Enterprise Data Platform hoàn chỉnh** trên Microsoft Fabric, bao gồm:

| Phase | Công nghệ sử dụng | Kết quả đạt được |
|---|---|---|
| **1** | Workspace, Capacity | Môi trường enterprise được phân quyền |
| **2** | OneLake, Shortcuts | Hiểu kiến trúc lưu trữ thống nhất |
| **3** | Lakehouse, Delta Lake | Medallion Architecture 3 tầng |
| **4** | Dataflow Gen2, Pipelines | Batch ingestion từ Azure SQL tự động hàng đêm |
| **5** | Eventstream, KQL Database | Real-time inventory monitoring 500 cửa hàng |
| **6** | Spark Notebooks, Delta MERGE | Silver transformation, SCD Type 2, OPTIMIZE |
| **7** | MLflow, LightGBM | Demand Forecasting model với đầy đủ MLOps |
| **8** | Direct Lake, Semantic Model | Self-service Power BI không cần import data |
| **9** | Microsoft Purview | Governance, Lineage, Sensitivity Labels |
| **10** | Data Activator, Capacity Metrics | Real-time alerting và monitoring |

> **Điểm khác biệt cốt lõi của Microsoft Fabric:** Toàn bộ 10 phases trên được thực hiện trong **một nền tảng duy nhất** với **một Storage Layer duy nhất (OneLake)**. Dữ liệu không cần copy hay chuyển đổi giữa các dịch vụ — Spark Notebook, SQL Endpoint, Power BI, và KQL Database đều đọc cùng một Delta file. Đây là bước tiến lớn so với kiến trúc truyền thống (ADF + Databricks + Synapse + Power BI Service) vốn đòi hỏi nhiều team vận hành và chi phí tích hợp cao.

---

*Lab hoàn thành. RetailVN giờ có một nền tảng dữ liệu thống nhất, từ raw transaction đến executive dashboard, với đầy đủ governance và real-time alerting — tất cả trong Microsoft Fabric.*
