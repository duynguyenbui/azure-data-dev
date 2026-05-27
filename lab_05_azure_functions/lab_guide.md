# Hướng dẫn Lab 05: Enterprise Serverless Data Processing: Azure Functions as Custom ETL & Event-Driven Orchestration

Chào mừng bạn đến với lab thực hành nâng cao về **Azure Functions** trong môi trường doanh nghiệp. Đây không phải một lab "Hello World" thông thường — chúng ta sẽ xây dựng một hệ thống xử lý dữ liệu Serverless cấp production, kết hợp giải thích sâu về kiến trúc và quyết định thiết kế như một **kỹ sư dữ liệu senior** thực thụ.

---

## Kịch bản Nghiệp vụ (The Business Scenario)

Công ty thương mại điện tử **ShopVN** vận hành sàn bán hàng với hàng chục ngàn đơn hàng mỗi ngày. Hệ thống đặt hàng của đối tác bên thứ ba cung cấp REST API để lấy đơn hàng định kỳ. Bộ phận kế toán upload file CSV hóa đơn lên Azure Blob Storage hàng ngày. Toàn bộ pipeline cần phản ứng theo sự kiện (event-driven), không cần server quản lý, và chi phí tính theo mức sử dụng thực tế.

**Giải pháp:** Một hệ sinh thái **Azure Functions** — mỗi Function là một microservice chuyên biệt, tự scale, tự phục hồi khi lỗi.

| Function | Trigger | Vai trò |
|---|---|---|
| `OrderIngestionTimer` | Timer (15 phút) | Gọi REST API đối tác, ghi vào ADLS |
| `OrderTransformHTTP` | HTTP | Custom Skill cho ADF — validate & transform |
| `InvoiceCSVBlob` | Blob | Parse CSV upload, ghi vào Azure SQL |
| `OrderOrchestrator` | Durable (Orchestrator) | Fan-out/fan-in song song |
| `BatchProcessor` | Durable (Activity) | Worker xử lý từng batch, publish Event Hub |

---

## 🧠 Kiến thức nền tảng: Tại sao chọn Azure Functions thay vì các lựa chọn khác?

Trước khi bắt tay vào lab, hãy hiểu **tại sao** chúng ta chọn Azure Functions thay vì các dịch vụ khác — đây là câu hỏi mà interviewer senior luôn hỏi.

**Azure Functions vs Azure App Service:**
App Service chạy liên tục 24/7 dù không có request nào — bạn trả tiền cho idle time. Functions chỉ tính phí khi code thực sự chạy. Cho workload như "cứ 15 phút chạy 30 giây", Functions rẻ hơn App Service ~50 lần. App Service phù hợp hơn cho web application cần latency nhất quán và không có cold start.

**Azure Functions vs Azure Kubernetes Service (AKS):**
AKS cho phép kiểm soát hoàn toàn infrastructure nhưng yêu cầu đội DevOps quản lý cluster, patching, scaling policies. Functions là fully managed — Microsoft lo toàn bộ hạ tầng. Cho ETL workloads event-driven, Functions cho time-to-market nhanh hơn 10 lần và total cost of ownership thấp hơn đáng kể.

**Azure Functions vs Logic Apps:**
Logic Apps dùng cho orchestration workflow với GUI drag-and-drop, phù hợp với business analyst. Functions dùng cho custom code logic phức tạp, validation với Pydantic, retry patterns tùy chỉnh. Trong lab này, chúng ta cần business logic phức tạp nên Functions là lựa chọn đúng.

**Azure Functions vs Azure Data Factory:**
ADF chuyên về data movement và transformation theo DAG (pipeline). Functions phù hợp cho event-driven reactions và custom code. Trong thực tế enterprise, hai dịch vụ này **bổ sung cho nhau**: ADF orchestrates the overall flow, Functions handles custom logic that ADF cannot do natively (Phase 4 của lab này minh họa điều đó).

**Consumption Plan vs Premium Plan:**
Consumption Plan (Serverless thuần túy): scale từ 0, cold start 1-3 giây, timeout tối đa 10 phút, giá cực rẻ (~0$ cho 1 triệu request/tháng đầu miễn phí). Premium Plan: warm instances (không có cold start), VNet integration, timeout không giới hạn, chạy liên tục — phù hợp production. Lab này dùng Consumption để học đúng bản chất Serverless, nhưng production ShopVN thực sự sẽ cần Premium.

**Cold Start là gì và tại sao quan trọng?**
Khi Function App đã "nguội" (không có request trong vài phút), Azure thu hồi tài nguyên về 0. Lần request tiếp theo phải "khởi động lại" container từ đầu (cold start), gây delay 1-3 giây với Python. Với Timer Trigger chạy mỗi 15 phút, cold start là chấp nhận được. Với HTTP Trigger serving user requests, cold start là vấn đề UX nghiêm trọng — phải dùng Premium Plan với Always Ready instances.

---

## Phase 1: Thiết lập Hạ tầng Enterprise

> **Mục đích:** Tạo toàn bộ hạ tầng nền tảng theo đúng thứ tự phụ thuộc. Trong enterprise, thứ tự tạo tài nguyên quan trọng vì Key Vault phải tồn tại trước khi Function App reference secrets từ đó. Resource Group là "thùng chứa" — xóa Resource Group là xóa sạch tất cả mọi thứ bên trong, giúp cleanup lab dễ dàng.

> **🧠 Kiến thức nền tảng: Resource Group như một "Project Folder"**
> Trong Azure, không có khái niệm "project" — thay vào đó bạn dùng Resource Group. Mọi resource trong một RG chung billing, chung access control (RBAC), và quan trọng nhất: xóa RG là xóa tất cả. Trong enterprise, mỗi project thường có ít nhất 3 RG: `-dev`, `-staging`, `-prod`. Đặt tên theo convention `rg-{project}-{env}-{region}` giúp tìm kiếm và quản lý khi tổ chức có hàng trăm RG.

### Bước 1: Tạo Resource Group

1. Đăng nhập [portal.azure.com](https://portal.azure.com).
2. Tìm **Resource groups** > **+ Create**.
3. Điền thông tin:
   - **Resource group:** `rg-shopvn-functions-dev`
   - **Region:** `Southeast Asia`.
4. Nhấn **Review + create** → **Create**.

### Bước 2: Tạo Storage Account (ADLS Gen2)

> **🧠 Kiến thức nền tảng: Tại sao Functions cần Storage Account?**
> Azure Functions không chỉ dùng Storage để lưu data. Bên dưới, Functions Runtime dùng Azure Storage để: (1) Lưu code và binaries của Function App, (2) Lưu state của Durable Functions (orchestration history, checkpoints), (3) Lưu timer state và lease locks để đảm bảo Timer Trigger chỉ chạy trên một instance duy nhất (leader election). Nếu Storage Account bị xóa, toàn bộ Function App sẽ ngừng hoạt động ngay lập tức.
> Chúng ta bật **Hierarchical Namespace** để biến Storage thành ADLS Gen2 — một Data Lake thực sự với thư mục thực sự (không phải fake folders bằng prefix như Blob Storage thông thường). Điều này cho phép partition dữ liệu theo `year=/month=/day=/` và set ACL permissions trên từng thư mục riêng lẻ.

1. Tìm **Storage accounts** > **+ Create**.
2. Điền thông tin:
   - **Resource group:** `rg-shopvn-functions-dev`
   - **Storage account name:** `stshopvnfunc001` _(lowercase, globally unique)_
   - **Region:** Cùng region với Resource Group _(QUAN TRỌNG: Functions App và Storage phải cùng region để tránh cross-region latency và egress charges)_.
   - **Performance:** Standard.
   - **Redundancy:** LRS (cho lab), ZRS hoặc GRS (cho production).
3. Tab **Advanced** → bật **Enable hierarchical namespace** ✅.
4. **Review + create** → **Create**.
5. Sau khi tạo, vào **Containers** → tạo:
   - `bronze-orders` — raw data từ Order API
   - `bronze-invoices` — file CSV hóa đơn
   - `silver-processed` — data đã xử lý

### Bước 3: Tạo Azure SQL Database

> **🧠 Kiến thức nền tảng: Tại sao Azure SQL cho transactional data?**
> ADLS Gen2 tối ưu cho analytical workloads (Parquet, large batch reads). Azure SQL tối ưu cho transactional workloads: ACID transactions, row-level locking, foreign key constraints, và stored procedures. Hóa đơn sau khi parse từ CSV cần ACID guarantees — không thể chấp nhận duplicate invoices hay partial inserts. Đây là lý do chúng ta dùng SQL cho `dbo.Invoices` thay vì ghi thêm vào ADLS.
> Trong production, ShopVN sẽ dùng **Azure SQL với Read Replicas** cho reporting, và **Change Data Capture (CDC)** để stream changes từ SQL sang ADLS cho analytics — một kiến trúc HTAP (Hybrid Transactional/Analytical Processing) hoàn chỉnh.

1. Tìm **SQL databases** > **+ Create**.
2. Điền:
   - **Database name:** `sqldb-shopvn-orders`
   - **Server:** Click **Create new** → Server name: `sqlserver-shopvn-001{suffix}`, Authentication: SQL auth, Login: `sqladmin`, Password: `ShopVN@P@ssw0rd!`.
3. **Compute + storage** → **Configure database** → chọn **Basic** tier (~$5/month).
4. Tab **Networking** → Allow Azure services: **Yes** ✅ → Add current client IP: **Yes** ✅.
5. **Review + create** → **Create**.

**Tạo schema trong SQL:**

```sql
-- Bảng chính lưu hóa đơn từ CSV
CREATE TABLE dbo.Invoices (
    InvoiceID       VARCHAR(50) PRIMARY KEY,
    OrderDate       DATE,
    CustomerID      VARCHAR(50),
    CustomerName    NVARCHAR(200),
    ProductCode     VARCHAR(50),
    Quantity        INT,
    UnitPrice       DECIMAL(18, 2),
    TotalAmount     DECIMAL(18, 2),
    Status          VARCHAR(20) DEFAULT 'PENDING',
    IngestionTime   DATETIME2 DEFAULT SYSDATETIME(),
    SourceFile      VARCHAR(500)
);

-- Audit log mỗi lần Function chạy
CREATE TABLE dbo.FunctionExecutionLog (
    LogID           INT IDENTITY(1,1) PRIMARY KEY,
    FunctionName    VARCHAR(100),
    TriggerSource   VARCHAR(500),
    ExecutionTime   DATETIME2 DEFAULT SYSDATETIME(),
    Status          VARCHAR(20),
    RecordsProcessed INT DEFAULT 0,
    ErrorMessage    NVARCHAR(MAX)
);

CREATE INDEX IX_Invoices_OrderDate ON dbo.Invoices (OrderDate);
CREATE INDEX IX_Invoices_CustomerID ON dbo.Invoices (CustomerID);
```

### Bước 4: Tạo Event Hub Namespace

> **🧠 Kiến thức nền tảng: Event Hub là gì và tại sao không dùng Service Bus?**
> Event Hub là **managed Kafka-compatible** service — được thiết kế cho **high-throughput event streaming** (hàng triệu events/giây). Nó lưu events trong retention window (1-7 ngày) và nhiều consumers có thể đọc độc lập (consumer groups). Service Bus ngược lại là **message broker** với queuing semantics — mỗi message chỉ được đọc bởi một consumer, có dead-letter queue, supports transactions.
> Chúng ta chọn Event Hub vì kết quả xử lý đơn hàng cần được broadcast cho nhiều downstream systems song song (notification service, inventory service, analytics) — đây là pub/sub pattern, phù hợp Event Hub. Nếu chỉ cần một consumer duy nhất (như gửi email notification), Service Bus sẽ phù hợp hơn.

1. Tìm **Event Hubs** > **+ Create**.
2. Điền: Namespace `evhns-shopvn-orders`, Pricing tier: Basic, Region: cùng region.
3. **Create** → vào namespace → **Event Hubs** → **+ Event Hub**: tên `order-processing-results`, partitions: 4.

### Bước 5: Tạo Application Insights

> **🧠 Kiến thức nền tảng: Hậu quả của việc bỏ qua Application Insights**
> Nếu bỏ qua Application Insights, bạn đang "bay mù" trong production. Hãy hình dung: Timer Trigger chạy mỗi 15 phút, nhưng đột nhiên Partner API timeout. Không có monitoring, bạn sẽ không biết điều này xảy ra cho đến khi sếp hỏi "sao data warehouse thiếu 4 tiếng đơn hàng?". Với Application Insights, bạn nhận alert email sau 5 phút đầu tiên bị lỗi.
> Application Insights cung cấp: **Distributed Tracing** (trace một request qua nhiều Functions), **Live Metrics Stream** (xem real-time invocations), **Dependency Tracking** (tự động đo latency mỗi lần gọi SQL hay HTTP), và **Smart Detection** (AI tự phát hiện anomaly). Đây là sự khác biệt giữa "script chạy trên cloud" và "production system thực sự".

1. Tìm **Application Insights** > **+ Create**.
2. Điền: Name `appi-shopvn-functions`, Resource mode: Workspace-based.
3. **Create** → vào resource → copy **Connection String** (dùng ở Phase 2).

### Bước 6: Tạo Azure Functions App

> **🧠 Kiến thức nền tảng: Functions App là gì về mặt cơ sở hạ tầng?**
> Một Functions App là một container cho nhiều individual Functions (Timer, HTTP, Blob...). Tất cả Functions trong cùng một App chia sẻ: cùng một set of App Settings (environment variables), cùng một Managed Identity, cùng một Application Insights instance, và quan trọng nhất — cùng một Consumption Plan. Điều này có nghĩa là nếu một Function đang tiêu thụ nhiều resources, nó có thể ảnh hưởng đến performance của các Functions khác. Trong enterprise với workloads rất khác nhau, thường tách thành nhiều Function Apps riêng biệt.

1. Tìm **Function App** > **+ Create**.
2. Điền:
   - **Function App name:** `func-shopvn-etl-001` _(globally unique)_
   - **Runtime stack:** Python, **Version:** 3.11
   - **Hosting plan:** Consumption (Serverless) ✅
   - **Storage account:** `stshopvnfunc001`
   - **Application Insights:** `appi-shopvn-functions`
3. **Review + create** → **Create**.

---

## Phase 2: Bảo mật với Managed Identity & Key Vault

> **🧠 Kiến thức nền tảng: Vòng luẩn quẩn của secret management và cách thoát ra**
> Trong nhiều tổ chức, secrets được quản lý theo cách nguy hiểm: developer paste connection string vào App Settings dưới dạng plain text, hoặc tệ hơn là hard-code trong code và commit lên Git. Điều này tạo ra "secret sprawl" — secrets phân tán khắp nơi, không có audit trail, không thể rotate dễ dàng.
> Managed Identity + Key Vault giải quyết vấn đề này theo mô hình **zero-secret**: Function App không bao giờ biết password SQL là gì. Thay vào đó, Azure AD cấp cho Function App một identity (như CMND cho người), Key Vault kiểm tra identity đó có quyền đọc secret không, và nếu có thì trả về secret chỉ trong memory tại runtime. Không có gì được lưu trong code hay config files. Đây là tiêu chuẩn security của mọi enterprise có compliance requirements (PCI-DSS, ISO 27001, SOC 2).
> **Hậu quả của việc bỏ qua:** Bất kỳ developer nào có quyền xem App Settings trong portal đều có thể đọc được SQL password. Nếu tài khoản Azure của họ bị compromise, attacker có ngay toàn bộ credentials của production database.

### Bước 1: Tạo Key Vault

1. Tìm **Key vaults** > **+ Create**.
2. Điền: Name `kv-shopvn-func-001`, Pricing tier: Standard.
3. Tab **Access configuration** → **Permission model:** Azure role-based access control (RBAC).
4. **Create**.
5. Gán quyền cho bạn: IAM → **+ Add role assignment** → Role: **Key Vault Secrets Officer** → Assign to: tài khoản của bạn. ⚠️ Chờ 3-5 phút.

**Tạo Secrets:**

| Secret Name | Value |
|---|---|
| `sql-connection-string` | `Driver={ODBC Driver 18 for SQL Server};Server=tcp:sqlserver-shopvn-001.database.windows.net,1433;Database=sqldb-shopvn-orders;Uid=sqladmin;Pwd=ShopVN@P@ssw0rd!;Encrypt=yes;` |
| `eventhub-connection-string` | _(Event Hub Namespace → Shared access policies → RootManageSharedAccessKey → Connection string)_ |
| `partner-api-key` | `shopvn-demo-api-key-12345` |
| `adls-connection-string` | _(Storage Account → Access keys → Connection string)_ |

### Bước 2: Bật Managed Identity cho Function App

> **Managed Identity là gì?** Khi bật System-Assigned Managed Identity, Azure tự động tạo một service principal trong Azure AD với tên giống Function App. Service principal này có lifecycle gắn với Function App — khi Function App bị xóa, identity cũng tự xóa. Function App dùng identity này để xác thực với bất kỳ Azure service nào hỗ trợ Azure AD auth (Key Vault, Storage, SQL, Event Hub...) mà không cần password.

1. Vào **Function App** `func-shopvn-etl-001` → **Identity**.
2. Tab **System assigned** → toggle **On** → **Save** → **Yes**.
3. Copy **Object (principal) ID**.

### Bước 3: Cấp quyền Key Vault cho Function App

1. Vào Key Vault → **Access control (IAM)** → **+ Add role assignment**.
2. Role: **Key Vault Secrets User** → Assign to: **Managed identity** → chọn `func-shopvn-etl-001`.
3. **Review + assign**. ⚠️ Chờ 2-3 phút để Azure propagate.

### Bước 4: Cấu hình Key Vault References trong App Settings

> Key Vault Reference syntax `@Microsoft.KeyVault(SecretUri=...)` cho phép Function App tự động resolve secret tại runtime mà không cần code thay đổi.

1. Vào Function App → **Configuration** → **Application settings** → **+ New application setting**:

| Name | Value |
|---|---|
| `SQL_CONNECTION_STRING` | `@Microsoft.KeyVault(SecretUri=https://kv-shopvn-func-001.vault.azure.net/secrets/sql-connection-string/)` |
| `EVENTHUB_CONNECTION_STRING` | `@Microsoft.KeyVault(SecretUri=https://kv-shopvn-func-001.vault.azure.net/secrets/eventhub-connection-string/)` |
| `PARTNER_API_KEY` | `@Microsoft.KeyVault(SecretUri=https://kv-shopvn-func-001.vault.azure.net/secrets/partner-api-key/)` |
| `ADLS_CONNECTION_STRING` | `@Microsoft.KeyVault(SecretUri=https://kv-shopvn-func-001.vault.azure.net/secrets/adls-connection-string/)` |
| `ADLS_ACCOUNT_NAME` | `stshopvnfunc001` |
| `EVENTHUB_NAME` | `order-processing-results` |
| `PARTNER_API_BASE_URL` | `https://api.partner-orders.shopvn.com` |

2. **Save**. Sau khi restart, mỗi Key Vault Reference sẽ hiện ✅ nếu đúng, hoặc ❌ nếu cấu hình quyền sai.

---

## Phase 3: Timer Trigger — Periodic API Ingestion

> **🧠 Kiến thức nền tảng: Idempotency — Tại sao không thể bỏ qua**
> Trong distributed systems, bất kỳ operation nào cũng có thể bị thực thi nhiều lần: Timer Trigger có thể fire 2 lần cho cùng một window do infrastructure issue, retry policy có thể re-run function sau failure, Azure có thể restart host giữa chừng. Nếu mỗi lần chạy bạn đều append data vào ADLS mà không check, bạn sẽ có duplicate orders. Idempotency đảm bảo "chạy 1 lần hay 100 lần đều cho kết quả như nhau".
> Pattern của chúng ta: dùng "marker file" trong ADLS (`_markers/window_20240115_1415.done`). Trước khi ghi data, check marker file tồn tại chưa. Nếu rồi → skip. Nếu chưa → ghi data → ghi marker. Đây là **exactly-once semantics** đơn giản nhưng hiệu quả cho batch processing.

### Cấu trúc dự án

```
shopvn-functions/
├── host.json
├── requirements.txt
├── local.settings.json          # KHÔNG commit lên Git
├── order_ingestion_timer/
│   ├── __init__.py
│   └── function.json
├── order_transform_http/
│   ├── __init__.py
│   └── function.json
├── invoice_csv_blob/
│   ├── __init__.py
│   └── function.json
├── order_orchestrator/
│   ├── __init__.py
│   └── function.json
└── batch_processor/
    ├── __init__.py
    └── function.json
```

**`host.json`:**

```json
{
  "version": "2.0",
  "logging": {
    "applicationInsights": {
      "samplingSettings": { "isEnabled": true, "excludedTypes": "Request" }
    },
    "logLevel": { "default": "Information", "Function": "Information" }
  },
  "functionTimeout": "00:10:00",
  "retry": {
    "strategy": "exponentialBackoff",
    "maxRetryCount": 3,
    "minimumInterval": "00:00:05",
    "maximumInterval": "00:00:30"
  },
  "extensions": {
    "durableTask": { "hubName": "ShopVNTaskHub" }
  }
}
```

**`requirements.txt`:**

```
azure-functions==1.18.0
azure-identity==1.16.0
azure-storage-blob==12.19.0
azure-eventhub==5.11.6
azure-durable-functions==1.2.9
httpx==0.27.0
pydantic==2.6.0
pyodbc==5.1.0
opencensus-ext-azure==1.1.13
tenacity==8.2.3
```

### `order_ingestion_timer/function.json`

```json
{
  "scriptFile": "__init__.py",
  "bindings": [
    {
      "name": "timerTrigger",
      "type": "timerTrigger",
      "direction": "in",
      "schedule": "0 */15 * * * *"
    }
  ]
}
```

> **Giải thích CRON expression:** `0 */15 * * * *` = giây thứ 0, mỗi 15 phút, mọi giờ, mọi ngày. Azure Functions CRON có 6 fields (thêm Seconds ở đầu so với Unix CRON). Nếu bạn viết `*/15 * * * *` (5 fields), Functions sẽ báo lỗi.

### `order_ingestion_timer/__init__.py`

```python
"""
OrderIngestionTimer: Thu nạp đơn hàng từ Partner API mỗi 15 phút.
Pattern: Stateless timer với idempotency check via ADLS marker file.
"""
import json
import logging
import os
from datetime import datetime, timezone, timedelta

import azure.functions as func
import httpx
from azure.storage.blob import BlobServiceClient
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type
from opencensus.ext.azure.log_exporter import AzureLogHandler

logger = logging.getLogger(__name__)
logger.addHandler(AzureLogHandler(
    connection_string=os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING", "")
))

API_BASE_URL = os.environ["PARTNER_API_BASE_URL"]
API_KEY = os.environ["PARTNER_API_KEY"]
ADLS_CONN_STR = os.environ["ADLS_CONNECTION_STRING"]
BRONZE_CONTAINER = "bronze-orders"


def _build_window_id(run_time: datetime) -> str:
    """Tạo idempotency key từ 15-minute time window."""
    rounded = run_time.replace(minute=(run_time.minute // 15) * 15, second=0, microsecond=0)
    return f"window_{rounded.strftime('%Y%m%d_%H%M')}"


@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=2, max=10),
    retry=retry_if_exception_type((httpx.TimeoutException, httpx.NetworkError)),
    reraise=True
)
def _fetch_orders_from_api(since_minutes: int = 15) -> list[dict]:
    """
    Gọi Partner REST API với exponential backoff retry.
    tenacity library cung cấp decorator-based retry logic, sạch hơn try/except loop thủ công.
    Retry chỉ áp dụng cho transient errors (timeout, network) — không retry HTTP 4xx (lỗi input).
    """
    since_dt = (datetime.now(timezone.utc) - timedelta(minutes=since_minutes)).isoformat()
    with httpx.Client(timeout=30.0) as client:
        response = client.get(
            f"{API_BASE_URL}/v2/orders",
            headers={"X-API-Key": API_KEY, "Accept": "application/json"},
            params={"since": since_dt, "status": "confirmed", "limit": 1000}
        )
        response.raise_for_status()
        return response.json().get("orders", [])


def _idempotency_check(container_client, window_id: str) -> bool:
    """True nếu window này đã được xử lý trước đó."""
    blob = container_client.get_blob_client(f"_markers/{window_id}.done")
    return blob.exists()


def _write_to_adls(container_client, orders: list[dict], run_time: datetime, window_id: str) -> str:
    """Ghi JSONL file theo partition year/month/day. Ghi marker file sau khi thành công."""
    blob_path = (
        f"year={run_time.year:04d}/month={run_time.month:02d}/"
        f"day={run_time.day:02d}/{window_id}.jsonl"
    )
    content = "\n".join(json.dumps(o, ensure_ascii=False, default=str) for o in orders)
    container_client.get_blob_client(blob_path).upload_blob(content.encode(), overwrite=True)
    container_client.get_blob_client(f"_markers/{window_id}.done").upload_blob(
        json.dumps({"window_id": window_id, "records": len(orders)}).encode(), overwrite=True
    )
    return blob_path


def main(timerTrigger: func.TimerRequest) -> None:
    run_time = datetime.now(timezone.utc)
    window_id = _build_window_id(run_time)

    logger.info("OrderIngestionTimer STARTED", extra={
        "custom_dimensions": {"window_id": window_id, "past_due": timerTrigger.past_due}
    })

    if timerTrigger.past_due:
        logger.warning("Timer is past due — may be catching up from backlog")

    try:
        blob_client = BlobServiceClient.from_connection_string(ADLS_CONN_STR)
        container = blob_client.get_container_client(BRONZE_CONTAINER)

        if _idempotency_check(container, window_id):
            logger.info("SKIPPED — window already processed", extra={"custom_dimensions": {"window_id": window_id}})
            return

        orders = _fetch_orders_from_api(since_minutes=15)
        logger.info(f"Fetched {len(orders)} orders", extra={"custom_dimensions": {"count": len(orders)}})

        if orders:
            blob_path = _write_to_adls(container, orders, run_time, window_id)
            logger.info("Written to ADLS", extra={"custom_dimensions": {"path": blob_path, "records": len(orders)}})
        else:
            logger.info("No new orders in this window")

    except httpx.HTTPStatusError as exc:
        logger.exception(f"Partner API HTTP error {exc.response.status_code}")
        raise
    except Exception as exc:
        logger.exception(f"Unexpected error: {exc}")
        raise
```

---

## Phase 4: HTTP Trigger — Custom Transformation API (ADF Custom Skill)

> **🧠 Kiến thức nền tảng: Tại sao ADF cần gọi Functions?**
> Azure Data Factory có hàng chục built-in activities (Copy, Mapping Data Flow, Stored Procedure...) nhưng có những business logic mà ADF không thể làm natively: gọi external REST API với custom auth, chạy Python code với custom libraries, validate dữ liệu theo business rules phức tạp. Giải pháp là **Custom Activity** — ADF gọi HTTP endpoint (Function App) và nhận kết quả. Function App xử lý logic, trả về JSON. ADF tiếp tục pipeline với output đó.
> Pydantic v2 được chọn cho validation vì: (1) Schema được định nghĩa bằng Python class, IDE có autocomplete, (2) Error messages rõ ràng và structured, (3) Type coercion tự động (string "42" → int 42), (4) Hiệu suất parse nhanh hơn marshmallow ~2-5 lần. RFC 7807 error format đảm bảo ADF (và bất kỳ consumer nào) biết chính xác field nào sai mà không cần parse error message text.

### `order_transform_http/function.json`

```json
{
  "scriptFile": "__init__.py",
  "bindings": [
    {
      "authLevel": "function",
      "type": "httpTrigger",
      "direction": "in",
      "name": "req",
      "methods": ["post"]
    },
    {
      "type": "http",
      "direction": "out",
      "name": "$return"
    }
  ]
}
```

> **`authLevel: "function"`** nghĩa là mỗi request cần có `?code=<function_key>` trong URL hoặc header `x-functions-key`. Level `anonymous` không cần key (chỉ dùng cho health check endpoints). Level `admin` yêu cầu master key — dùng cho admin APIs. Trong ADF Custom Activity, ta configure function key vào ADF Linked Service.

### `order_transform_http/__init__.py`

```python
"""
OrderTransformHTTP: Được ADF gọi như Custom Activity.
Validate bằng Pydantic v2, trả về RFC 7807 error format khi validation fail.
"""
import json
import logging
import os
from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional

import azure.functions as func
from pydantic import BaseModel, Field, field_validator, model_validator, ValidationError
from opencensus.ext.azure.log_exporter import AzureLogHandler

logger = logging.getLogger(__name__)
logger.addHandler(AzureLogHandler(
    connection_string=os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING", "")
))


class OrderLineItem(BaseModel):
    product_code: str = Field(..., min_length=3, max_length=50)
    quantity: int = Field(..., gt=0, le=10000)
    unit_price: float = Field(..., gt=0)
    discount_pct: float = Field(default=0.0, ge=0.0, le=100.0)

    @field_validator("product_code")
    @classmethod
    def uppercase_sku(cls, v: str) -> str:
        return v.strip().upper()

    @property
    def line_total(self) -> Decimal:
        gross = Decimal(str(self.quantity)) * Decimal(str(self.unit_price))
        discount = gross * Decimal(str(self.discount_pct)) / Decimal("100")
        return (gross - discount).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


class RawOrderPayload(BaseModel):
    order_id: str = Field(..., min_length=1, max_length=100)
    customer_id: str = Field(..., min_length=1)
    order_date: str
    currency: str = Field(default="VND", pattern=r"^[A-Z]{3}$")
    line_items: list[OrderLineItem] = Field(..., min_length=1, max_length=500)
    shipping_address: Optional[str] = None

    @field_validator("order_date")
    @classmethod
    def validate_date_format(cls, v: str) -> str:
        try:
            datetime.strptime(v, "%Y-%m-%d")
        except ValueError:
            raise ValueError("Must be YYYY-MM-DD format")
        return v

    @model_validator(mode="after")
    def positive_total(self) -> "RawOrderPayload":
        total = sum(item.line_total for item in self.line_items)
        if total <= 0:
            raise ValueError("Order total must be > 0 after discounts")
        return self


def _transform(payload: RawOrderPayload) -> dict:
    """
    Business rules ShopVN:
    - Tổng hóa đơn > 5 triệu VND → IS_PRIORITY = True → ưu tiên xử lý
    - Làm tròn mọi giá trị tiền tệ xuống 2 chữ số thập phân
    """
    total = sum(item.line_total for item in payload.line_items)
    return {
        "order_id": payload.order_id,
        "customer_id": payload.customer_id,
        "order_date": payload.order_date,
        "currency": payload.currency,
        "line_items": [
            {"product_code": i.product_code, "quantity": i.quantity,
             "unit_price": float(i.unit_price), "discount_pct": i.discount_pct,
             "line_total_vnd": float(i.line_total)}
            for i in payload.line_items
        ],
        "order_total_vnd": float(total),
        "is_priority": total > Decimal("5000000"),
        "item_count": len(payload.line_items),
        "shipping_address": payload.shipping_address,
        "processed_at": datetime.now(timezone.utc).isoformat(),
        "processed_by": "ShopVN-OrderTransformHTTP/1.0"
    }


def main(req: func.HttpRequest) -> func.HttpResponse:
    correlation_id = req.headers.get("X-Correlation-ID", "unknown")

    try:
        body = req.get_json()
    except ValueError:
        return func.HttpResponse(
            json.dumps({"type": "https://shopvn.com/errors/invalid-json",
                        "title": "Invalid JSON", "status": 400}),
            status_code=400, mimetype="application/problem+json"
        )

    try:
        payload = RawOrderPayload.model_validate(body)
    except ValidationError as exc:
        errors = exc.errors(include_url=False)
        logger.warning("Validation failed", extra={"custom_dimensions": {
            "correlation_id": correlation_id, "error_count": len(errors)
        }})
        return func.HttpResponse(
            json.dumps({
                "type": "https://shopvn.com/errors/validation-failed",
                "title": "Validation Failed", "status": 422,
                "errors": [{"field": ".".join(str(x) for x in e["loc"]), "message": e["msg"]}
                           for e in errors]
            }),
            status_code=422, mimetype="application/problem+json"
        )

    try:
        result = _transform(payload)
        logger.info("Transformed successfully", extra={"custom_dimensions": {
            "order_id": result["order_id"],
            "total_vnd": result["order_total_vnd"],
            "is_priority": result["is_priority"],
            "correlation_id": correlation_id
        }})
        return func.HttpResponse(
            json.dumps({"status": "success", "data": result}),
            status_code=200, mimetype="application/json"
        )
    except Exception as exc:
        logger.exception(f"Transformation error: {exc}")
        return func.HttpResponse(
            json.dumps({"type": "https://shopvn.com/errors/internal", "status": 500}),
            status_code=500, mimetype="application/problem+json"
        )
```

---

## Phase 5: Blob Trigger — Event-Driven CSV Processing

> **🧠 Kiến thức nền tảng: Blob Trigger polling delay và cách khắc phục**
> Blob Trigger tiêu chuẩn dùng polling — Azure Functions kiểm tra container mỗi vài phút để phát hiện blob mới. Delay có thể lên đến 10 phút trong Consumption Plan. Trong production, điều này không chấp nhận được khi kế toán upload CSV và mong đợi data vào SQL trong vài giây.
> Giải pháp enterprise: dùng **Event Grid + Blob Trigger** (hay còn gọi là Event Grid-based Blob Trigger). Event Grid kích hoạt Function ngay khi blob được tạo (< 1 giây). Lab này dùng Blob Trigger cơ bản để đơn giản hóa setup, nhưng comment trong code sẽ chỉ rõ chỗ cần thay đổi cho production.
> **Connection pooling với pyodbc:** Mỗi lần Function gọi `pyodbc.connect()`, nó tạo một TCP connection mới đến SQL Server — tốn ~50-200ms. pyodbc tự động pool connections cùng connection string, nghĩa là lần gọi thứ 2 trở đi sẽ reuse connection sẵn có. Tuy nhiên, trong Consumption Plan mỗi invocation là một process mới → không có persistent pool. Giải pháp: dùng **Azure SQL Elastic Pool** ở database side hoặc chuyển sang Premium Plan + Azure SQL Driver cải thiện.

### `invoice_csv_blob/function.json`

```json
{
  "scriptFile": "__init__.py",
  "bindings": [
    {
      "name": "myblob",
      "type": "blobTrigger",
      "direction": "in",
      "path": "bronze-invoices/{filename}",
      "connection": "ADLS_CONNECTION_STRING"
    }
  ]
}
```

### `invoice_csv_blob/__init__.py`

```python
"""
InvoiceCSVBlob: Xử lý file CSV khi upload vào ADLS.
Dùng MERGE thay vì INSERT để xử lý re-upload cùng file (idempotency).
BATCH_SIZE=500 cân bằng giữa memory footprint và SQL round-trips.
"""
import csv
import io
import logging
import os
from typing import Iterator

import azure.functions as func
import pyodbc
from opencensus.ext.azure.log_exporter import AzureLogHandler

logger = logging.getLogger(__name__)
logger.addHandler(AzureLogHandler(
    connection_string=os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING", "")
))

SQL_CONN_STR = os.environ["SQL_CONNECTION_STRING"]
BATCH_SIZE = 500


def _get_conn() -> pyodbc.Connection:
    conn = pyodbc.connect(SQL_CONN_STR, autocommit=False)
    conn.setencoding(encoding="utf-8")
    return conn


def _parse_csv(content: bytes) -> Iterator[dict]:
    """Parse CSV với BOM handling (Excel thường export UTF-8 BOM)."""
    text = content.decode("utf-8-sig")
    reader = csv.DictReader(io.StringIO(text))
    required = {"InvoiceID","OrderDate","CustomerID","CustomerName","ProductCode","Quantity","UnitPrice","TotalAmount"}
    if not required.issubset(set(reader.fieldnames or [])):
        raise ValueError(f"Missing columns: {required - set(reader.fieldnames or [])}")

    for row_num, row in enumerate(reader, start=2):
        try:
            yield {
                "InvoiceID": row["InvoiceID"].strip(),
                "OrderDate": row["OrderDate"].strip(),
                "CustomerID": row["CustomerID"].strip(),
                "CustomerName": row["CustomerName"].strip(),
                "ProductCode": row["ProductCode"].strip(),
                "Quantity": int(row["Quantity"]),
                "UnitPrice": float(row["UnitPrice"]),
                "TotalAmount": float(row["TotalAmount"]),
                "Status": row.get("Status", "PENDING").strip()
            }
        except (ValueError, KeyError) as e:
            logger.warning(f"Skipping malformed row {row_num}: {e}")


def _bulk_upsert(conn: pyodbc.Connection, rows: list[dict], source_file: str) -> int:
    """
    MERGE thay vì INSERT để đảm bảo idempotency.
    Nếu kế toán upload lại cùng file, records đã tồn tại sẽ bị skip (NOT MATCHED only).
    """
    cursor = conn.cursor()
    sql = """
        MERGE dbo.Invoices AS target
        USING (VALUES (?,?,?,?,?,?,?,?,?,?)) AS src
            (InvoiceID,OrderDate,CustomerID,CustomerName,ProductCode,Quantity,UnitPrice,TotalAmount,Status,SourceFile)
        ON target.InvoiceID = src.InvoiceID
        WHEN NOT MATCHED THEN
            INSERT (InvoiceID,OrderDate,CustomerID,CustomerName,ProductCode,Quantity,UnitPrice,TotalAmount,Status,SourceFile)
            VALUES (src.InvoiceID,src.OrderDate,src.CustomerID,src.CustomerName,src.ProductCode,
                    src.Quantity,src.UnitPrice,src.TotalAmount,src.Status,src.SourceFile);
    """
    params = [(r["InvoiceID"],r["OrderDate"],r["CustomerID"],r["CustomerName"],
               r["ProductCode"],r["Quantity"],r["UnitPrice"],r["TotalAmount"],
               r["Status"],source_file) for r in rows]
    cursor.executemany(sql, params)
    conn.commit()
    return len(rows)


def main(myblob: func.InputStream) -> None:
    filename = myblob.name
    logger.info(f"InvoiceCSVBlob triggered: {filename}",
                extra={"custom_dimensions": {"filename": filename, "size_bytes": myblob.length}})

    if not filename.lower().endswith(".csv"):
        logger.info(f"Skipping non-CSV: {filename}")
        return

    content = myblob.read()
    total_upserted = 0
    batch: list[dict] = []

    try:
        conn = _get_conn()
        for row in _parse_csv(content):
            batch.append(row)
            if len(batch) >= BATCH_SIZE:
                total_upserted += _bulk_upsert(conn, batch, filename)
                batch.clear()
        if batch:
            total_upserted += _bulk_upsert(conn, batch, filename)

        conn.execute(
            "INSERT INTO dbo.FunctionExecutionLog (FunctionName,TriggerSource,Status,RecordsProcessed) VALUES (?,?,?,?)",
            ("InvoiceCSVBlob", filename, "SUCCESS", total_upserted)
        )
        conn.commit()
        conn.close()

        logger.info(f"CSV processed: {total_upserted} records",
                    extra={"custom_dimensions": {"filename": filename, "records": total_upserted}})
    except Exception as exc:
        logger.exception(f"Error processing {filename}: {exc}")
        raise
```

---

## Phase 6: Durable Functions — Fan-out/Fan-in Orchestration

> **🧠 Kiến thức nền tảng: Tại sao Durable Functions thay vì queue-based approach?**
> Cách truyền thống để xử lý parallel jobs: đẩy N messages vào Azure Queue Storage, N worker Functions đọc và xử lý, một "aggregator" function tổng hợp kết quả. Vấn đề: làm thế nào biết khi nào tất cả N workers hoàn thành? Bạn phải tự implement counter trong Redis hay SQL — phức tạp và dễ có race conditions.
> Durable Functions giải quyết hoàn toàn vấn đề này bằng **Orchestrator Pattern**: Orchestrator là một stateful coroutine — nó "nhớ" mình đã gửi bao nhiêu tasks, task nào đã xong, và chờ tất cả hoàn thành với `yield context.task_all(tasks)`. State được lưu tự động vào Azure Storage (Table + Blob) sau mỗi checkpoint.
> **Orchestrator phải DETERMINISTIC:** Orchestrator code chạy nhiều lần (replay) khi checkpoint được load lại. Nếu bạn gọi `datetime.now()` trực tiếp trong Orchestrator, mỗi replay sẽ cho giá trị khác nhau → logic sai. Luôn dùng `context.current_utc_datetime` thay thế. Tương tự, không gọi HTTP hay database trực tiếp trong Orchestrator — đó là việc của Activity Functions.
> **Actor Model:** Mỗi Orchestrator instance là một Actor — có private state, xử lý messages tuần tự. Durable Functions implement Actor model trên Azure Storage, cho phép scale đến hàng nghìn concurrent orchestrations mà không cần manage infrastructure.

### `order_orchestrator/__init__.py`

```python
"""
OrderOrchestrator: HTTP Starter + Durable Orchestrator.
Fan-out: gửi N batches đến BatchProcessor đồng thời.
Fan-in: task_all() chờ TẤT CẢ hoàn thành trước khi return summary.
"""
import json
import logging
import os

import azure.functions as func
import azure.durable_functions as df
from opencensus.ext.azure.log_exporter import AzureLogHandler

logger = logging.getLogger(__name__)
logger.addHandler(AzureLogHandler(
    connection_string=os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING", "")
))


async def http_start(req: func.HttpRequest, client: df.DurableOrchestrationClient) -> func.HttpResponse:
    try:
        body = req.get_json()
        batches = body.get("batches", [])
        if not batches:
            return func.HttpResponse(
                json.dumps({"error": "'batches' is required and must be non-empty"}),
                status_code=400, mimetype="application/json"
            )
    except ValueError:
        return func.HttpResponse("Invalid JSON", status_code=400)

    instance_id = await client.start_new("orchestrator_fn", None, {"batches": batches})
    logger.info(f"Orchestration started: {instance_id}",
                extra={"custom_dimensions": {"instance_id": instance_id, "batch_count": len(batches)}})
    return client.create_check_status_response(req, instance_id)


def orchestrator_fn(context: df.DurableOrchestrationContext):
    """
    QUAN TRỌNG: Đây là generator function (dùng yield, không phải async/await).
    Orchestrator sẽ được replay nhiều lần — mỗi lần Activity hoàn thành,
    Orchestrator được resume từ đầu với history đã có. Đây là lý do phải deterministic.
    """
    input_data = context.get_input()
    batches: list = input_data.get("batches", [])

    # Fan-out: Tạo tất cả tasks đồng thời — KHÔNG yield từng task một
    tasks = [
        context.call_activity("batch_processor", {"batch_id": i, "orders": batch})
        for i, batch in enumerate(batches)
    ]

    # Fan-in: Chờ TẤT CẢ tasks hoàn thành cùng lúc
    results = yield context.task_all(tasks)

    summary = {
        "instance_id": context.instance_id,
        "total_batches": len(batches),
        "total_processed": sum(r.get("processed_count", 0) for r in results),
        "total_failed": sum(r.get("failed_count", 0) for r in results),
        "successful_batches": sum(1 for r in results if r.get("status") == "success")
    }
    return summary


main = df.Orchestrator.from_orchestrator_func(orchestrator_fn)
```

### `batch_processor/__init__.py`

```python
"""
BatchProcessor: Activity Function — worker thực thi.
Được gọi bởi Orchestrator theo fan-out pattern.
Publish kết quả ra Event Hub sau khi xử lý.
"""
import json
import logging
import os
from datetime import datetime, timezone

import azure.durable_functions as df
from azure.eventhub import EventHubProducerClient, EventData
from opencensus.ext.azure.log_exporter import AzureLogHandler

logger = logging.getLogger(__name__)
logger.addHandler(AzureLogHandler(
    connection_string=os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING", "")
))

EVENTHUB_CONN_STR = os.environ["EVENTHUB_CONNECTION_STRING"]
EVENTHUB_NAME = os.environ["EVENTHUB_NAME"]


def _publish_events(events: list[dict]) -> None:
    producer = EventHubProducerClient.from_connection_string(EVENTHUB_CONN_STR, eventhub_name=EVENTHUB_NAME)
    with producer:
        batch = producer.create_batch()
        for e in events:
            batch.add(EventData(json.dumps(e, default=str)))
        producer.send_batch(batch)


def main(payload: dict) -> dict:
    batch_id = payload.get("batch_id", 0)
    orders = payload.get("orders", [])
    processed, failed = 0, 0
    events = []

    for order in orders:
        try:
            events.append({
                "order_id": order.get("order_id", "unknown"),
                "batch_id": batch_id,
                "processed_at": datetime.now(timezone.utc).isoformat(),
                "status": "processed"
            })
            processed += 1
        except Exception as e:
            logger.warning(f"Order processing error: {e}")
            failed += 1

    if events:
        _publish_events(events)

    result = {"batch_id": batch_id, "processed_count": processed,
              "failed_count": failed, "status": "success" if failed == 0 else "partial"}
    logger.info(f"Batch {batch_id} done: {processed} processed",
                extra={"custom_dimensions": result})
    return result
```

---

## Phase 7: Monitoring với Application Insights

> **🧠 Kiến thức nền tảng: Structured Logging vs Plain Text Logging**
> `logger.info("Processed 42 orders")` là plain text — không thể query "tổng số orders đã xử lý trong 24h qua" từ log này vì phải parse string. `logger.info("Processed orders", extra={"custom_dimensions": {"order_count": 42}})` là structured logging — Application Insights lưu `order_count` như một queryable column.
> Trong Kusto Query Language (KQL), bạn có thể viết `traces | summarize sum(toint(customDimensions.order_count)) by bin(timestamp, 1h)` để tổng hợp metrics. Đây là sự khác biệt giữa "có logs" và "có observability thực sự".

### Kusto Queries cho ShopVN Dashboard

```kusto
// 1. Tổng quan invocations trong 4h qua
requests
| where timestamp > ago(4h)
| summarize total = count(), failures = countif(success == false) by name
| extend failure_rate = round(100.0 * failures / total, 2)
| order by failure_rate desc

// 2. Theo dõi đơn hàng ingest theo window
traces
| where timestamp > ago(24h)
| where customDimensions has "window_id"
| project timestamp,
          window_id = tostring(customDimensions.window_id),
          order_count = toint(customDimensions.count)
| order by timestamp desc

// 3. Performance P50/P95/P99 theo Function
requests
| where timestamp > ago(1h)
| summarize p50=percentile(duration,50), p95=percentile(duration,95), p99=percentile(duration,99) by name

// 4. Exceptions grouped by message
exceptions
| where timestamp > ago(24h)
| summarize count() by outerMessage, cloud_RoleName
| order by count_ desc
```

### Tạo Alert Rule — Failure Rate

1. Vào Application Insights → **Alerts** → **+ Create alert rule**.
2. **Condition:** Metric → **Failed requests** → Threshold: Static, Greater than `5` trong 5 phút.
3. **Actions:** Tạo Action Group → Email `on-call@shopvn.com`.
4. **Alert name:** `shopvn-functions-high-failure-rate`, Severity: 2.

---

## Phase 8: Local Development Setup

> **🧠 Kiến thức nền tảng: Tại sao phát triển local quan trọng?**
> Deploy lên Azure để test mỗi thay đổi nhỏ tốn 3-5 phút/lần và tốn tiền. Local development với Azurite + Functions Core Tools cho phép: iteration nhanh (save file → Ctrl+C → func start → test trong 10 giây), debug với VS Code breakpoints, test error cases mà production data không có. Đây là workflow của mọi senior Functions developer.

### Cài đặt Prerequisites

```bash
# Azure Functions Core Tools v4
brew tap azure/functions
brew install azure-functions-core-tools@4
func --version  # Verify: 4.x.x

# Azurite — Azure Storage local emulator
npm install -g azurite

# Khởi động Azurite trong terminal riêng
azurite --silent --location ./azurite-data --debug ./azurite-data/debug.log
```

### `local.settings.json`

> ⚠️ KHÔNG commit file này lên Git. Thêm ngay vào `.gitignore`.

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "python",
    "APPLICATIONINSIGHTS_CONNECTION_STRING": "InstrumentationKey=your-key;...",
    "SQL_CONNECTION_STRING": "Driver={ODBC Driver 18 for SQL Server};Server=tcp:sqlserver-shopvn-001.database.windows.net,...",
    "EVENTHUB_CONNECTION_STRING": "Endpoint=sb://evhns-shopvn-orders.servicebus.windows.net/;...",
    "EVENTHUB_NAME": "order-processing-results",
    "ADLS_CONNECTION_STRING": "DefaultEndpointsProtocol=https;AccountName=stshopvnfunc001;...",
    "ADLS_ACCOUNT_NAME": "stshopvnfunc001",
    "PARTNER_API_BASE_URL": "https://api.partner-orders.shopvn.com",
    "PARTNER_API_KEY": "shopvn-demo-api-key-12345"
  }
}
```

### Chạy và Test Local

```bash
python3.11 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
func start

# Test HTTP Trigger
curl -X POST http://localhost:7071/api/OrderTransformHTTP \
  -H "Content-Type: application/json" \
  -d '{"order_id":"ORD-001","customer_id":"CUST-001","order_date":"2024-01-15","currency":"VND","line_items":[{"product_code":"SKU-001","quantity":5,"unit_price":1200000}]}'

# Test Timer Trigger thủ công (không cần chờ schedule)
curl -X POST http://localhost:7071/admin/functions/OrderIngestionTimer \
  -H "Content-Type: application/json" -d '{"input":""}'
```

---

## Phase 9: CI/CD Deployment via GitHub Actions

> **🧠 Kiến thức nền tảng: Tại sao CI/CD là bắt buộc trong enterprise?**
> Không có CI/CD nghĩa là: developer deploy code chưa test thủ công lên production, không có audit trail về ai deploy gì lúc nào, deploy lúc 2 giờ sáng để "tránh người dùng" vì sợ lỗi. Với GitHub Actions: mỗi Pull Request tự động chạy tests và lint — code không pass không được merge. Mỗi merge vào `main` tự động deploy — không cần manual step. Có full audit trail trong GitHub. Deployment pipeline có health check tự động rollback nếu deploy xong nhưng app không healthy.

### Tạo GitHub Secrets

Repo → **Settings** → **Secrets and variables** → **Actions**:

| Secret | Value |
|---|---|
| `AZURE_FUNCTIONAPP_PUBLISH_PROFILE` | Download từ Function App → **Get publish profile** |
| `AZURE_FUNCTIONAPP_NAME` | `func-shopvn-etl-001` |

### `.github/workflows/deploy-functions.yml`

```yaml
name: Deploy ShopVN Azure Functions

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  PYTHON_VERSION: "3.11"

jobs:
  test:
    name: Unit Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "${{ env.PYTHON_VERSION }}" }
      - run: pip install -r requirements.txt pytest pytest-mock
      - run: pytest tests/ -v --tb=short --junit-xml=test-results.xml
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: test-results, path: test-results.xml }

  lint:
    name: Code Quality
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "${{ env.PYTHON_VERSION }}" }
      - run: pip install flake8 black isort
      - run: black --check --diff .
      - run: isort --check-only --diff .
      - run: flake8 . --max-line-length=120 --exclude=.venv

  deploy:
    name: Deploy to Azure
    runs-on: ubuntu-latest
    needs: [test, lint]
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "${{ env.PYTHON_VERSION }}" }
      - run: pip install --target=".python_packages/lib/site-packages" -r requirements.txt
      - uses: Azure/functions-action@v1
        with:
          app-name: ${{ secrets.AZURE_FUNCTIONAPP_NAME }}
          package: "."
          publish-profile: ${{ secrets.AZURE_FUNCTIONAPP_PUBLISH_PROFILE }}
          scm-do-build-during-deployment: true
          enable-oryx-build: true
      - name: Health check post-deploy
        run: |
          sleep 30
          STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
            "https://${{ secrets.AZURE_FUNCTIONAPP_NAME }}.azurewebsites.net/api/health")
          [ "$STATUS" = "200" ] || { echo "Health check failed: $STATUS"; exit 1; }
```

---

## Phase 10: End-to-End Testing & Cleanup

### Test Plan Toàn diện

**Test 1: Timer Trigger**

```bash
# Trigger thủ công qua admin API
curl -X POST "https://func-shopvn-etl-001.azurewebsites.net/admin/functions/OrderIngestionTimer" \
  -H "x-functions-key: <MASTER_KEY>" \
  -H "Content-Type: application/json" -d '{"input":""}'

# Verify file trong ADLS
az storage blob list --account-name stshopvnfunc001 \
  --container-name bronze-orders --auth-mode login --output table

# Verify idempotency: trigger lại ngay lập tức — không được tạo file thứ 2
```

**Test 2: HTTP Trigger — 3 scenarios**

```bash
FUNC_URL="https://func-shopvn-etl-001.azurewebsites.net/api/OrderTransformHTTP?code=<KEY>"

# Scenario A: Valid, non-priority (total = 1,000,000 VND)
curl -X POST "$FUNC_URL" -H "Content-Type: application/json" \
  -d '{"order_id":"T001","customer_id":"C001","order_date":"2024-01-15","currency":"VND","line_items":[{"product_code":"SKU-A","quantity":2,"unit_price":500000}]}'
# Expected: HTTP 200, is_priority=false

# Scenario B: Priority order (total = 30,000,000 VND)
curl -X POST "$FUNC_URL" -H "Content-Type: application/json" \
  -d '{"order_id":"T002","customer_id":"C002","order_date":"2024-01-15","currency":"VND","line_items":[{"product_code":"SKU-B","quantity":3,"unit_price":10000000}]}'
# Expected: HTTP 200, is_priority=true

# Scenario C: Validation failure
curl -X POST "$FUNC_URL" -H "Content-Type: application/json" \
  -d '{"order_id":"","line_items":[]}'
# Expected: HTTP 422, RFC 7807 error body
```

**Test 3: Blob Trigger — CSV Upload**

```bash
cat > test_invoices.csv << 'EOF'
InvoiceID,OrderDate,CustomerID,CustomerName,ProductCode,Quantity,UnitPrice,TotalAmount,Status
INV-001,2024-01-15,CUST-001,Nguyễn Văn A,SKU-001,2,500000,1000000,CONFIRMED
INV-002,2024-01-15,CUST-002,Trần Thị B,SKU-002,1,2000000,2000000,PENDING
EOF

az storage blob upload \
  --account-name stshopvnfunc001 \
  --container-name bronze-invoices \
  --name "invoices_20240115.csv" \
  --file test_invoices.csv --auth-mode login

# Verify trong SQL sau 1-5 phút:
# SELECT * FROM dbo.Invoices WHERE SourceFile LIKE '%invoices_20240115%';
# SELECT * FROM dbo.FunctionExecutionLog ORDER BY ExecutionTime DESC;

# Test idempotency: upload lại cùng file → không có duplicate rows
```

**Test 4: Durable Orchestration**

```bash
curl -X POST "https://func-shopvn-etl-001.azurewebsites.net/api/orchestrate-orders?code=<KEY>" \
  -H "Content-Type: application/json" \
  -d '{"batches":[[{"order_id":"O1"},{"order_id":"O2"}],[{"order_id":"O3"}]]}'
# Response chứa statusQueryGetUri

# Poll status
curl "<statusQueryGetUri>"
# Expected: runtimeStatus = "Completed", total_processed = 3
```

### Dọn dẹp Tài nguyên

> **Quy tắc vàng:** Sau mỗi lab, LUÔN xóa tài nguyên. Azure tính phí ngay cả khi bạn không dùng (SQL Database tính phí 24/7, Event Hub tính phí theo throughput units).

```bash
# Xóa toàn bộ Resource Group và TẤT CẢ tài nguyên bên trong
az group delete --name rg-shopvn-functions-dev --yes --no-wait

# Verify đã xóa (sau vài phút)
az group show --name rg-shopvn-functions-dev 2>&1
```

---

## Tổng kết: Kiến trúc Patterns & Design Decisions

| Pattern | Ví dụ trong Lab | Tại sao quan trọng |
|---|---|---|
| **Idempotency với Marker File** | Timer Trigger | Tránh duplicate data khi retry |
| **Exponential Backoff Retry** | API calls với tenacity | Handle transient network failures |
| **Managed Identity + Key Vault** | Tất cả Functions | Zero-secret trong code — enterprise security |
| **Pydantic v2 Validation** | HTTP Trigger | Type-safe, IDE-friendly input validation |
| **RFC 7807 Error Format** | HTTP Trigger errors | Chuẩn REST API error contract |
| **MERGE thay vì INSERT** | Blob Trigger SQL write | Idempotent upsert tránh duplicates |
| **Fan-out/Fan-in** | Durable Orchestrator | Parallel processing với automatic aggregation |
| **Structured Custom Dimensions** | Mọi logger.info() | Queryable telemetry trong KQL |
| **Event-Driven Architecture** | Blob Trigger + Event Hub | Loose coupling giữa services |
| **CI/CD với Health Check** | GitHub Actions | Deployment tự động với safety net |

**Bước tiếp theo trong hành trình học Azure Functions:**
- Tìm hiểu **Azure Functions Premium Plan** với VNet Integration và Always Ready
- Nghiên cứu **KEDA (Kubernetes Event-Driven Autoscaling)** khi cần deploy Functions trên AKS
- Explore **Azure Functions Flex Consumption** — thế hệ mới kết hợp ưu điểm cả Consumption và Premium
- Kết hợp lab này với ADF lab: dùng `OrderTransformHTTP` như Custom Activity thực sự trong ADF pipeline

Chúc mừng! Bạn đã xây dựng thành công một hệ sinh thái Azure Functions production-grade với đầy đủ bảo mật, idempotency, monitoring, và CI/CD — hiểu không chỉ **cách làm** mà còn **tại sao làm vậy**.
