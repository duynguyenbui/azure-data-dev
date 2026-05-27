# Hướng dẫn Lab 01: End-to-End Data Pipeline trên Azure Databricks và dbt

> **Mức độ**: Advanced
> **Thời gian ước tính**: 3-4 giờ
> **Công nghệ**: Azure ADLS Gen2, Databricks Access Connector, Unity Catalog, Delta Live Tables (DLT) Auto Loader, dbt Cloud, Databricks SQL Dashboards

---

## Tổng quan kiến trúc (Architecture Overview)

Bài lab này xây dựng một luồng dữ liệu ELT (Extract, Load, Transform) đầy đủ theo chuẩn **Medallion Architecture** (Bronze → Silver → Gold) áp dụng thực tế trong các công ty.

```
┌─────────────────────────────────────────────────────────────────────┐
│                         AZURE CLOUD                                 │
│                                                                     │
│  ┌────────────────────┐    IAM Role Assignment (RBAC)               │
│  │  Access Connector  │────────────────────────────────┐            │
│  │  (Managed Identity)│                                │            │
│  └────────────────────┘                                ▼            │
│                                              ┌──────────────────┐   │
│                                              │   ADLS Gen2      │   │
│                                              │  datalabdev001   │   │
│   Upload CSV ──────────────────────────────► │  container:      │   │
│                                              │   raw-data/      │   │
│                                              │   ├── customers/ │   │
│                                              │   └── orders/    │   │
│                                              └────────┬─────────┘   │
│                                                       │             │
│                          Unity Catalog (External Location)          │
│                                                       │             │
│                                              ┌────────▼─────────┐   │
│                                              │  Azure Databricks │   │
│                                              │  dbw-lab-dev-001  │   │
│                                              │                   │   │
│                                              │  DLT Pipeline     │   │
│                                              │  (@dlt.table)     │   │
│                                              │       │           │   │
│                                              │  Bronze: raw_*    │   │
│                                              │       │           │   │
│                                              │  dbt Models       │   │
│                                              │  Silver: stg_*    │   │
│                                              │  Gold: dim_/fct_  │   │
│                                              │       │           │   │
│                                              │  SQL Dashboards   │   │
│                                              └───────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Tên tài nguyên chuẩn (Resource Naming Convention)

> **Lưu ý**: Trong bài lab này, tất cả tài nguyên đã được đặt tên sẵn theo chuẩn `<loại>-<môi trường>-<số thứ tự>`. Bạn chỉ cần copy-paste tên vào.

| Tài nguyên Azure         | Tên đặt sẵn                    | Giải thích                                  |
|--------------------------|--------------------------------|---------------------------------------------|
| Resource Group           | `rg-databricks-lab-dev`        | Nhóm tất cả tài nguyên vào một chỗ          |
| Storage Account (ADLS)   | `datalabdev001`                | Tên phải viết liền thường, không dấu        |
| Container                | `raw-data`                     | Nơi chứa file đầu vào                       |
| Access Connector         | `ac-databricks-lab-dev`        | Managed Identity của Databricks             |
| Databricks Workspace     | `dbw-lab-dev-001`              | Workspace chính                             |
| DLT Pipeline             | `dlt-ingestion-bronze`         | Pipeline Auto Loader                        |
| dbt Project              | `dbt_databricks_lab`           | Thư mục code dbt trong repo                 |
| SQL Warehouse            | `wh-lab-serverless`            | Compute cho dbt & Dashboards                |

---

## Bước 1: Tạo Resource Group trên Azure Portal

**Tại sao?** Resource Group là container logic để gom tất cả tài nguyên Azure vào một chỗ. Khi xong lab, ta chỉ cần xóa một Resource Group là sạch toàn bộ, không sót thứ gì.

1. Đăng nhập [portal.azure.com](https://portal.azure.com).
2. Tìm **Resource groups** → **+ Create**.
3. Điền thông tin:
   - **Subscription**: Chọn subscription của bạn.
   - **Resource group**: `rg-databricks-lab-dev`
   - **Region**: `Southeast Asia`
4. Nhấn **Review + create** → **Create**.

---

## Bước 2: Tạo Azure Databricks Workspace (Premium Tier)

**Tại sao?** Phải chọn Premium tier vì chỉ Premium mới hỗ trợ **Unity Catalog** (quản trị dữ liệu tập trung) và **SQL Warehouse Serverless** (cần cho dbt và Dashboards).

1. Tìm **Azure Databricks** → **+ Create**.
2. Điền thông tin:
   - **Resource group**: `rg-databricks-lab-dev`
   - **Workspace name**: `dbw-lab-dev-001`
   - **Region**: `Southeast Asia`
   - **Pricing Tier**: **Premium** ← Bắt buộc
3. Nhấn **Review + create** → **Create**. Đợi ~3 phút.
4. Sau khi tạo xong, nhấn **Launch Workspace** để vào Databricks UI.

---

## Bước 3: Tạo Azure Data Lake Storage Gen2 (ADLS Gen2)

**Tại sao?** ADLS Gen2 là "kho lạnh" lưu trữ dữ liệu thô (raw) dưới dạng file với chi phí cực thấp. Tính năng **Hierarchical Namespace** biến Storage Account thông thường thành Data Lake thực sự với cấu trúc thư mục chuẩn.

1. Tìm **Storage accounts** → **+ Create**.
2. Điền thông tin:
   - **Resource group**: `rg-databricks-lab-dev`
   - **Storage account name**: `datalabdev001`
   - **Region**: `Southeast Asia`
   - **Performance**: Standard
   - **Redundancy**: LRS (Locally Redundant — đủ dùng cho lab)
3. Chuyển sang tab **Advanced**:
   - **Hierarchical namespace**: ✅ **Enable** ← Bắt buộc, đây là điểm biến Storage thành Data Lake Gen2.
4. Nhấn **Review + create** → **Create**.
5. Sau khi tạo xong, vào Storage Account → **Containers** → **+ Container**:
   - **Name**: `raw-data`
   - **Access level**: Private
6. Bên trong container `raw-data`, tạo hai thư mục:
   - Nhấn **+ Add Directory** → `customers`
   - Nhấn **+ Add Directory** → `orders`
7. Upload dữ liệu mẫu:
   - Vào thư mục `customers/` → Upload file `lab_01_databricks_dbt/data/customers.csv`.
   - Vào thư mục `orders/` → Upload file `lab_01_databricks_dbt/data/orders.csv`.

---

## Bước 4: Tạo Access Connector for Azure Databricks

**Tại sao?** Đây là bước mà nhiều hướng dẫn bỏ qua nhưng lại cực kỳ quan trọng về mặt bảo mật. **Access Connector** là một Azure Resource độc lập đại diện cho **System-Assigned Managed Identity** của Databricks. Thay vì lưu Access Key vào code (nguy hiểm, phải xoay vòng định kỳ), ta cấp quyền cho cái "danh tính ảo" này và Databricks sẽ tự động dùng nó khi cần truy cập Data Lake.

1. Trên Azure Portal, tìm kiếm **"Access Connector for Azure Databricks"**.
2. Nhấn **+ Create**.
3. Điền thông tin:
   - **Resource group**: `rg-databricks-lab-dev`
   - **Name**: `ac-databricks-lab-dev`
   - **Region**: `Southeast Asia`
4. Nhấn **Review + create** → **Create**.
5. **Lấy Resource ID**: Sau khi tạo xong, vào resource **`ac-databricks-lab-dev`** → tab **Overview** → Copy giá trị **Resource ID**. (Dạng: `/subscriptions/.../resourceGroups/.../providers/Microsoft.Databricks/accessConnectors/ac-databricks-lab-dev`). Dán vào Notepad tạm thời.

---

## Bước 5: Phân quyền IAM (Azure RBAC) cho Access Connector

**Tại sao?** Azure hoạt động theo mô hình "Least Privilege" — mọi thứ mặc định đều bị từ chối. Ta phải chủ động cấp quyền `Storage Blob Data Contributor` để Access Connector (Managed Identity của Databricks) có thể đọc/ghi dữ liệu vào Storage Account.

1. Vào Storage Account **`datalabdev001`**.
2. Chọn **Access control (IAM)** ở menu bên trái → **+ Add** → **Add role assignment**.
3. **Tab Role**: Tìm và chọn **Storage Blob Data Contributor** → **Next**.
4. **Tab Members**:
   - **Assign access to**: Chọn **Managed identity**.
   - Nhấn **+ Select members**.
   - Trong dropdown **Managed identity**, chọn **Access Connector for Azure Databricks**.
   - Chọn **`ac-databricks-lab-dev`** → **Select**.
5. Nhấn **Review + assign** → **Assign**.

> ⚠️ **Lưu ý**: Việc phân quyền IAM có thể mất vài phút để có hiệu lực trên Azure.

---

## Bước 6: Cấu hình Unity Catalog — Storage Credential & External Location

**Tại sao?** Unity Catalog là lớp quản trị dữ liệu tập trung của Databricks. **Storage Credential** là cầu nối an toàn từ Databricks sang Azure (dùng Access Connector). **External Location** định nghĩa đường dẫn cụ thể trong Data Lake mà Databricks được phép truy cập.

### 6.1 Tạo Storage Credential

1. Vào Databricks Workspace **`dbw-lab-dev-001`** → **Catalog** (biểu tượng catalog bên trái) → **External Data** → **Storage Credentials** → **+ Add a storage credential**.
2. Điền thông tin:
   - **Credential type**: Azure Managed Identity
   - **Storage credential name**: `sc-datalabdev001`
   - **Access Connector ID**: Dán **Resource ID** đã copy ở Bước 4 vào đây.
3. Nhấn **Create**.

### 6.2 Tạo External Location

1. Trong **Catalog** → **External Data** → **External Locations** → **+ Add an external location**.
2. Điền thông tin:
   - **External location name**: `el-raw-data`
   - **URL**: `abfss://raw-data@datalabdev001.dfs.core.windows.net/`
   - **Storage credential**: `sc-datalabdev001`
3. Nhấn **Create**.
4. Nhấn **Test connection** để xác nhận kết nối thành công.

---

## Bước 7: Tạo SQL Warehouse (Serverless)

**Tại sao?** SQL Warehouse là compute được tối ưu hóa đặc biệt cho SQL workload (không phải Spark tổng quát). Loại **Serverless** chỉ tính tiền khi đang xử lý query, tự động bật/tắt theo giây. Cả dbt và SQL Dashboards đều kết nối vào đây.

1. Trong Databricks Workspace, chuyển sang persona **SQL** (menu góc trên trái).
2. Vào **SQL Warehouses** → **+ Create SQL Warehouse**.
3. Điền thông tin:
   - **Name**: `wh-lab-serverless`
   - **Cluster size**: X-Small (đủ cho lab)
   - **Type**: Serverless ← Chọn nếu có, nếu không có thì chọn Pro
   - **Auto stop**: 10 minutes (tự tắt sau 10 phút idle)
4. Nhấn **Create**. Đợi Warehouse khởi động.
5. **Lấy Connection Details**: Vào Warehouse **`wh-lab-serverless`** → **Connection details**. Copy:
   - `Server hostname` (ví dụ: `adb-xxxxxxxx.xx.azuredatabricks.net`)
   - `HTTP path` (ví dụ: `/sql/1.0/warehouses/xxxxxxxx`)
   Dán vào Notepad tạm thời.

---

## Bước 8: Tạo DLT Pipeline (Advanced Auto Loader — Bronze Layer)

**Tại sao?** Delta Live Tables (DLT) là framework ETL khai báo (declarative) của Databricks. Thay vì quản lý Spark Streaming thủ công, ta dùng decorator `@dlt.table` và Databricks tự lo việc quản lý cluster, retry khi lỗi, và lineage graph. Kết hợp với Auto Loader (`cloudFiles`), nó tự động phát hiện file mới trên ADLS mà không cần cron job.

1. Vào Databricks Workspace → **Workflows** → **Delta Live Tables** → **+ Create pipeline**.
2. Tạo Notebook nguồn:
   - Vào **Workspace** → **+ New** → **Notebook**.
   - Đặt tên: `nb-dlt-bronze-ingestion`.
   - Copy toàn bộ code từ file `lab_01_databricks_dbt/etl/autoloader_pipeline.py` vào notebook này.
3. Quay lại **Delta Live Tables** → **+ Create pipeline** và điền cấu hình:
   - **Pipeline name**: `dlt-ingestion-bronze`
   - **Product edition**: **Advanced**
   - **Pipeline mode**: **Triggered**
   - **Source code**: Trỏ tới notebook `nb-dlt-bronze-ingestion` vừa tạo.
   - **Destination**: Chọn **Unity Catalog**, Catalog: `hive_metastore`, Target schema: `default`.
4. Thêm **Pipeline Parameters** (Advanced Configuration):
   - Nhấn **Advanced** → **Add configuration**.
   - **Key**: `pipeline.storage_path`
   - **Value**: `abfss://raw-data@datalabdev001.dfs.core.windows.net/`
5. Nhấn **Create**.
6. Nhấn **Start** để chạy pipeline lần đầu. Quan sát DLT Graph hiển thị lineage, trạng thái Data Quality metrics trên UI.
7. Sau khi hoàn thành, kiểm tra trên **Catalog** → Database `default`. Hai bảng `raw_customers` và `raw_orders` đã xuất hiện dưới dạng Delta tables.

---

## Bước 9: Học dbt từ đầu và triển khai Data Modeling

### 📚 dbt là gì? Tại sao cần nó?

**dbt (data build tool)** là công cụ dành cho Analytics Engineer để thực hiện bước **T (Transform)** trong quy trình **ELT**. Điểm khác biệt cốt lõi so với các công cụ ETL truyền thống:

| Công cụ ETL truyền thống | dbt |
|--------------------------|-----|
| Viết Python/Java phức tạp | Chỉ viết câu lệnh `SELECT` SQL |
| Phải tự tạo bảng, view thủ công | dbt tự tạo bảng/view dựa trên config |
| Khó biết bảng nào phụ thuộc bảng nào | Tự sinh Lineage Graph trực quan |
| Không có unit test | Có sẵn data tests (not null, unique, FK...) |
| Documentation viết tay | Tự sinh documentation website |

**Tư duy cốt lõi của dbt**: Mỗi file `.sql` là một **Model** — bạn chỉ viết `SELECT`, dbt tự biết cần `CREATE VIEW` hay `CREATE TABLE`.

---

### 📂 Hiểu cấu trúc thư mục dbt

Dưới đây là cấu trúc của project lab này và vai trò của từng file:

```
dbt_databricks_lab/
├── dbt_project.yml          ← Cấu hình toàn dự án (tên, đường dẫn, materialization)
├── profiles.yml             ← Kết nối tới Databricks (chỉ dùng khi chạy local)
└── models/
    ├── staging/             ← Tầng Silver: Làm sạch dữ liệu thô
    │   ├── sources.yml      ← Khai báo bảng Bronze (raw) là "nguồn"
    │   ├── stg_customers.sql
    │   └── stg_orders.sql
    └── marts/               ← Tầng Gold: Mô hình hóa cho BI
        ├── dim_customers.sql
        └── fct_orders.sql
```

---

### 🔑 Khái niệm 1: `sources.yml` — Khai báo nguồn dữ liệu

**File**: `models/staging/sources.yml`

**Tại sao cần file này?** Sau khi DLT Pipeline tạo ra bảng `raw_customers` và `raw_orders` ở Bronze layer, dbt cần biết những bảng đó ở đâu. File `sources.yml` chính là bản khai báo "nguồn dữ liệu đầu vào" cho dbt. Khi dbt biết đây là `source`, nó sẽ:
- Vẽ điểm bắt đầu (origin) trong Lineage Graph
- Cho phép bạn chạy `dbt source freshness` để kiểm tra dữ liệu có cũ quá không

```yaml
# models/staging/sources.yml
version: 2

sources:
  - name: default               # Tên alias để dùng trong SQL: {{ source('default', 'raw_customers') }}
    description: "Schema Bronze chứa dữ liệu thô do DLT Pipeline tạo ra."
    database: hive_metastore    # Catalog trên Databricks
    schema: default             # Schema (database) trên Databricks
    tables:
      - name: raw_customers
        description: "Dữ liệu khách hàng thô từ ADLS Gen2 qua Auto Loader."
      - name: raw_orders
        description: "Dữ liệu đơn hàng thô từ ADLS Gen2 qua Auto Loader."
```

---

### 🔑 Khái niệm 2: Staging Models — Tầng Silver (Làm sạch dữ liệu)

**Files**: `stg_customers.sql`, `stg_orders.sql`

**Tại sao lại có tầng Staging?** Dữ liệu thô (Bronze) thường có nhiều vấn đề: kiểu dữ liệu sai, tên cột không chuẩn, có giá trị `NULL` bẩn... Tầng Staging có một nhiệm vụ duy nhất: **chuẩn hóa (standardize) dữ liệu thô thành dữ liệu sạch**. Nguyên tắc là chỉ đọc từ `source()`, không join với bảng khác.

**`{{ source('tên_source', 'tên_bảng') }}`**: Đây là cú pháp hàm của dbt. Thay vì viết tên bảng cứng (`default.raw_customers`), ta dùng hàm này để dbt tự tạo đường dẫn đúng và theo dõi lineage.

```sql
-- models/staging/stg_customers.sql
-- Materialization: VIEW (khai báo trong dbt_project.yml)
-- Tại sao VIEW? Staging chỉ là bước làm sạch, không cần lưu vật lý. VIEW tiết kiệm storage.

with source as (
    -- Hàm source() khai báo đây là điểm bắt đầu trong lineage graph
    select * from {{ source('default', 'raw_customers') }}
),

renamed as (
    select
        -- Cast kiểu dữ liệu: Dữ liệu từ CSV vào đều là string, cần ép kiểu đúng
        cast(customer_id as integer) as customer_id,
        -- Chuẩn hóa tên cột (lowercase, snake_case)
        first_name,
        last_name,
        lower(email) as email,   -- Chuẩn hóa email thành chữ thường
        country
    from source
    -- Loại bỏ các dòng không có customer_id (dữ liệu bẩn)
    where customer_id is not null
)

select * from renamed
```

```sql
-- models/staging/stg_orders.sql
with source as (
    select * from {{ source('default', 'raw_orders') }}
),

renamed as (
    select
        cast(order_id as integer)       as order_id,
        cast(customer_id as integer)    as customer_id,
        cast(order_date as date)        as order_date,
        lower(status)                   as status,
        cast(total_amount as double)    as total_amount
    from source
    where order_id is not null
)

select * from renamed
```

**Lưu ý**: Sau khi chạy, các model này trở thành VIEW trên Databricks schema `dbt_dev`. Ví dụ: `dbt_dev.stg_customers`.

---

### 🔑 Khái niệm 3: `{{ ref() }}` — Cách dbt biết thứ tự chạy

**Tại sao dùng `ref()` thay vì tên bảng cứng?** Khi bạn viết `{{ ref('stg_customers') }}`, dbt sẽ:
1. Tự động biết `dim_customers` phụ thuộc vào `stg_customers`
2. Đảm bảo `stg_customers` được tạo **trước** khi tạo `dim_customers`
3. Vẽ mũi tên phụ thuộc trong Lineage Graph

Nếu bạn viết cứng tên bảng `dbt_dev.stg_customers`, dbt sẽ mù hoàn toàn về mối quan hệ này.

---

### 🔑 Khái niệm 4: Marts Models — Tầng Gold (Dimensional Modeling)

**Files**: `dim_customers.sql`, `fct_orders.sql`

**Tại sao lại chia thành `dim_` và `fct_`?** Đây là chuẩn **Kimball Dimensional Modeling** — cách thiết kế dữ liệu phổ biến nhất trong Data Warehousing:
- **Dimension Table (`dim_`)**: Chứa thông tin mô tả về đối tượng (Khách hàng, Sản phẩm...). Thay đổi chậm.
- **Fact Table (`fct_`)**: Chứa các sự kiện, giao dịch (Đơn hàng, Thanh toán...). Thay đổi liên tục, tăng theo thời gian.

**Materialization TABLE**: Các Mart được tạo thành bảng vật lý vì BI tool sẽ query liên tục vào đây. TABLE cho phép Databricks cache kết quả và query nhanh hơn VIEW nhiều lần.

```sql
-- models/marts/dim_customers.sql
-- Materialization: TABLE (khai báo trong dbt_project.yml)
-- Mục đích: Bảng mô tả khách hàng, làm giàu thêm các chỉ số tổng hợp

with customers as (
    -- ref() thay vì tên bảng cứng → dbt biết dependency
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

-- Tính toán các chỉ số tổng hợp theo từng khách hàng
customer_order_summary as (
    select
        customer_id,
        min(order_date)             as first_order_date,
        max(order_date)             as most_recent_order_date,
        count(order_id)             as number_of_orders,
        sum(total_amount)           as total_spent,
        avg(total_amount)           as avg_order_value
    from orders
    group by customer_id
),

final as (
    select
        c.customer_id,
        c.first_name,
        c.last_name,
        c.email,
        c.country,
        -- coalesce trả về 0 nếu khách hàng chưa có đơn nào
        coalesce(s.first_order_date,       null)   as first_order_date,
        coalesce(s.most_recent_order_date, null)   as most_recent_order_date,
        coalesce(s.number_of_orders,       0)      as number_of_orders,
        coalesce(s.total_spent,            0.0)    as total_spent,
        coalesce(s.avg_order_value,        0.0)    as avg_order_value,
        -- Phân loại khách hàng theo giá trị: VIP / Regular / New
        case
            when coalesce(s.total_spent, 0) >= 400 then 'VIP'
            when coalesce(s.number_of_orders, 0) >= 2  then 'Regular'
            else 'New'
        end as customer_segment
    from customers c
    left join customer_order_summary s using (customer_id)
)

select * from final
```

```sql
-- models/marts/fct_orders.sql
-- Materialization: TABLE
-- Mục đích: Bảng sự kiện đơn hàng, dùng cho phân tích doanh thu và hiệu suất

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

final as (
    select
        o.order_id,
        o.customer_id,
        o.order_date,
        -- Lấy thêm thông tin của khách hàng để phục vụ báo cáo theo quốc gia
        c.country               as customer_country,
        o.status,
        o.total_amount,
        -- Phân loại đơn hàng theo giá trị
        case
            when o.total_amount >= 300 then 'High Value'
            when o.total_amount >= 100 then 'Mid Value'
            else 'Low Value'
        end as order_value_tier
    from orders o
    left join customers c using (customer_id)
)

select * from final
```

---

### 9.1 Tạo tài khoản dbt Cloud (Miễn phí)

1. Truy cập [cloud.getdbt.com](https://cloud.getdbt.com/) → Đăng ký tài khoản Developer (miễn phí cho 1 người dùng).

### 9.2 Tạo Project và kết nối Databricks

1. Trong dbt Cloud → **+ New project** → Đặt tên `databricks-lab-project`.
2. Phần **Choose a connection** → Chọn **Databricks**.
3. Điền Connection Details (lấy từ Bước 7):
   - **Server Hostname**: Giá trị `Server hostname` đã copy ở Bước 7
   - **HTTP Path**: Giá trị `HTTP path` đã copy ở Bước 7
   - **Catalog**: `hive_metastore`
   - **Schema**: `dbt_dev`
4. **Authentication**: Chọn **Personal Access Token**. Để lấy token:
   - Vào Databricks → Tên tài khoản (góc trên phải) → **Settings** → **Developer** → **Access tokens** → **Generate new token**.
   - **Comment**: `dbt-cloud-token`, **Lifetime**: 90 days → **Generate** → Copy token.
   - Dán token vào dbt Cloud.
5. Nhấn **Test connection** → Kết nối thành công → **Continue**.

### 9.3 Deploy Code lên dbt Cloud IDE

1. Chọn **Managed Repository** → **Continue**.
2. Vào **Develop** → IDE web xuất hiện.
3. Trong IDE, tạo cấu trúc thư mục như sau (nhấn chuột phải vào `models` → **New folder**):
   ```
   models/
   ├── staging/
   └── marts/
   ```
4. Tạo từng file và dán nội dung đã giải thích ở trên vào:
   - `models/staging/sources.yml` — Khai báo nguồn Bronze
   - `models/staging/schema.yml` — Định nghĩa test cho tầng Staging (Làm sạch)
   - `models/staging/stg_customers.sql` — Làm sạch khách hàng
   - `models/staging/stg_orders.sql` — Làm sạch đơn hàng
   - `models/marts/schema.yml` — Định nghĩa test cho tầng Marts (BI Modeling)
   - `models/marts/dim_customers.sql` — Dimension bảng khách hàng
   - `models/marts/fct_orders.sql` — Fact bảng đơn hàng
5. Nhấn **Save All** (hoặc `Ctrl+S`).

---

### 📚 dbt Data Testing — Bảo vệ chất lượng dữ liệu

**Tại sao cần Data Testing?**
Dữ liệu trong Data Lakehouse là thực thể "động" — cấu trúc có thể thay đổi, đối tác có thể gửi file lỗi, logic code bị bug. Nếu không có bộ lọc chất lượng dữ liệu (Data Quality Gates), dữ liệu bẩn sẽ đi thẳng vào báo cáo và làm sai lệch quyết định kinh doanh. dbt cung cấp cơ chế viết test khai báo (declarative test) cực kỳ đơn giản qua file `schema.yml`.

#### 1. Tạo file cấu hình test cho tầng Staging
Tạo file `models/staging/schema.yml` và dán nội dung sau:

```yaml
version: 2

models:
  - name: stg_customers
    description: "Dữ liệu khách hàng đã được làm sạch và chuẩn hóa kiểu dữ liệu."
    columns:
      - name: customer_id
        description: "Khóa chính của khách hàng"
        tests:
          - unique     # Đảm bảo không trùng lặp ID khách hàng
          - not_null   # Đảm bảo ID khách hàng không được để trống (NULL)
      - name: email
        description: "Email khách hàng (đã chuyển thành chữ thường)"
        tests:
          - not_null   # Bắt buộc phải có email để liên hệ

  - name: stg_orders
    description: "Dữ liệu đơn hàng đã được làm sạch và chuẩn hóa kiểu dữ liệu."
    columns:
      - name: order_id
        description: "Khóa chính của đơn hàng"
        tests:
          - unique
          - not_null
      - name: customer_id
        description: "Khóa ngoại tham chiếu đến khách hàng"
        tests:
          - not_null
      - name: status
        description: "Trạng thái của đơn hàng"
        tests:
          - accepted_values:
              values: ['completed', 'shipped', 'processing', 'cancelled'] # Chỉ chấp nhận các trạng thái này
```

#### 2. Tạo file cấu hình test cho tầng Marts
Tạo file `models/marts/schema.yml` và dán nội dung sau:

```yaml
version: 2

models:
  - name: dim_customers
    description: "Bảng chiều (Dimension Table) chứa thông tin khách hàng và các chỉ số tích lũy."
    columns:
      - name: customer_id
        description: "Khóa chính của khách hàng"
        tests:
          - unique
          - not_null
      - name: customer_segment
        description: "Phân khúc khách hàng (VIP / Regular / New)"
        tests:
          - accepted_values:
              values: ['VIP', 'Regular', 'New']

  - name: fct_orders
    description: "Bảng sự kiện (Fact Table) chứa thông tin chi tiết từng đơn hàng."
    columns:
      - name: order_id
        description: "Khóa chính của đơn hàng"
        tests:
          - unique
          - not_null
      - name: customer_id
        description: "Khóa ngoại tham chiếu đến dim_customers"
        tests:
          - not_null
          - relationships:
              to: ref('dim_customers')    # Referential Integrity Test (Kiểm tra tính toàn vẹn tham chiếu)
              field: customer_id          # Đảm bảo customer_id trong fct_orders phải tồn tại trong dim_customers
      - name: order_value_tier
        description: "Phân loại giá trị đơn hàng (High Value / Mid Value / Low Value)"
        tests:
          - accepted_values:
              values: ['High Value', 'Mid Value', 'Low Value']
```

> 💡 **Mẹo nâng cao**: Test `relationships` là cách tuyệt vời để phát hiện lỗi "mất liên kết" dữ liệu (Orphaned Records) giữa các bảng giao dịch (Fact) và bảng danh mục (Dimension).

---

### 9.4 Chạy và kiểm tra dbt

Trong Terminal của dbt Cloud IDE:

```bash
# Bước 1: Kiểm tra kết nối tới Databricks SQL Warehouse
dbt debug

# Bước 2: Chạy toàn bộ pipeline (Silver + Gold layer)
# dbt tự sắp xếp thứ tự: sources → staging → marts
dbt run

# Bước 3: Chạy data tests để đảm bảo chất lượng dữ liệu dựa trên schema.yml đã cấu hình
# dbt sẽ chạy truy vấn SQL ngầm để đếm các dòng vi phạm. Nếu count > 0, test sẽ báo FAIL.
dbt test

# Mẹo: Chạy cả run và test kết hợp trong 1 câu lệnh để tối ưu hiệu năng
dbt build

# Bước 4: Tạo website documentation + lineage graph tương tác
dbt docs generate
dbt docs serve
# Nhấn vào biểu tượng 📄 ở góc trái IDE để xem Lineage Graph trực quan
```

**Kiểm tra kết quả trên Databricks**: Vào **Catalog** → schema `dbt_dev`. Bạn sẽ thấy 4 objects:
- `stg_customers` (VIEW)
- `stg_orders` (VIEW)
- `dim_customers` (TABLE — có thêm cột `customer_segment`)
- `fct_orders` (TABLE — có thêm cột `order_value_tier`)

---

## Bước 10: Xây dựng Báo cáo với Databricks SQL Dashboards

**Tại sao?** Databricks SQL Dashboards là công cụ BI Cloud Native 100%, không cần cài đặt gì thêm, chạy trực tiếp trên SQL Warehouse `wh-lab-serverless`. Phù hợp khi bạn cần chia sẻ báo cáo nhanh cho đồng nghiệp mà không cần license Power BI.

### 10.1 Tạo Query

1. Trong Databricks UI → Persona **SQL** → **Queries** → **+ Create query**.
2. Đảm bảo đang chọn Warehouse `wh-lab-serverless` (dropdown góc trên phải Editor).

**Query 1 — Top 10 Khách hàng VIP:**
```sql
SELECT 
    customer_id,
    first_name || ' ' || last_name AS full_name,
    country,
    number_of_orders,
    ROUND(total_spent, 2) AS total_spent,
    ROUND(total_spent / NULLIF(number_of_orders, 0), 2) AS avg_order_value
FROM dbt_dev.dim_customers
ORDER BY total_spent DESC
LIMIT 10;
```
- Nhấn **Run** → **+ Add visualization** → Chọn **Table** → Lưu lại tên `viz-top10-customers`.

**Query 2 — Doanh thu theo quốc gia:**
```sql
SELECT 
    customer_country,
    COUNT(order_id) AS total_orders,
    ROUND(SUM(total_amount), 2) AS total_revenue,
    ROUND(AVG(total_amount), 2) AS avg_order_value
FROM dbt_dev.fct_orders
WHERE status = 'completed'
GROUP BY customer_country
ORDER BY total_revenue DESC;
```
- Nhấn **Run** → **+ Add visualization** → Chọn **Bar chart** → X: `customer_country`, Y: `total_revenue` → Lưu tên `viz-revenue-by-country`.

### 10.2 Đóng gói Dashboard

1. **Dashboards** → **+ Create dashboard** → Đặt tên `dashboard-ecommerce-overview`.
2. Nhấn **Add** → **Visualization** → Thêm cả hai visualizations vào.
3. Kéo thả, resize cho đẹp mắt.
4. Nhấn **Publish** → Copy link → Chia sẻ cho đồng nghiệp xem mà không cần tài khoản Databricks (nếu cấu hình public sharing).

---

## Bước 11: Orchestration tự động bằng Databricks Workflows (Multi-task Job)

**Tại sao?**
Trong môi trường doanh nghiệp thực tế, không ai vào UI bấm nút chạy DLT thủ công hay gõ lệnh `dbt run` mỗi ngày. Toàn bộ quy trình từ tải file lên Data Lake $\rightarrow$ DLT Ingestion $\rightarrow$ dbt Transformation & Testing phải chạy tự động theo một chuỗi (DAG). **Databricks Workflows** là bộ lập lịch (Orchestrator) tích hợp sẵn, giúp tự động hóa toàn bộ luồng, đảm bảo dbt chỉ chạy khi DLT hoàn thành thành công, và tự động gửi cảnh báo nếu bất kỳ bước nào thất bại.

1. Trong Databricks Workspace, chuyển sang persona **Data Engineering** ở menu góc trên trái.
2. Vào **Workflows** (biểu tượng lịch trình ở menu trái) → Nhấn **+ Create job**.
3. Cấu hình **Task 1: Ingestion (Bronze Layer)**:
   - **Task name**: `ingest_raw_data`
   - **Type**: **Delta Live Tables pipeline**
   - **Pipeline**: Chọn pipeline `dlt-ingestion-bronze` đã tạo ở Bước 8.
   - Nhấn **Create task**.
4. Cấu hình **Task 2: Transformation & Test (Silver & Gold Layers)**:
   - Trong giao diện thiết kế DAG vừa tạo, nhấn vào nút **+ Add task** (nằm ngay dưới Task `ingest_raw_data`).
   - **Task name**: `transform_and_test_dbt`
   - **Type**: **dbt** (Hoặc chọn **dbt Cloud** nếu bạn đã liên kết tài khoản dbt Cloud qua Partner Connect).
   - **Source**: Chọn Git repository chứa thư mục `dbt_databricks_lab`.
   - **dbt commands**: Điền lệnh `dbt build` (lệnh này chạy cả `run` và `test`).
   - **SQL Warehouse**: Chọn `wh-lab-serverless`.
   - **Depends on**: Đảm bảo trường này đang chọn `ingest_raw_data` (Task 1). điều này bắt buộc Task 2 phải đợi Task 1 chạy thành công mới được khởi chạy.
   - Nhấn **Create task**.
5. Cấu hình **Lập lịch chạy tự động (Schedule)**:
   - Ở bảng thuộc tính bên phải màn hình (Job details) → tìm mục **Schedules** → Nhấp **Add schedule**.
   - **Trigger type**: Scheduled
   - **Schedule**: Chọn chạy hàng ngày (Every day) vào lúc **02:00 AM** (giờ thấp điểm hệ thống và đảm bảo dữ liệu ngày hôm trước đã cập nhật đủ trên Data Lake).
   - Nhấn **Save**.
6. Cấu hình **Gửi cảnh báo lỗi (Notifications)**:
   - Ở mục **Job details** bên phải → tìm **Notifications** → Nhấp **Add email**.
   - Điền email của bạn.
   - Chọn checkbox **On failure** (Gửi mail khi lỗi).
   - Nhấn **Save**.
7. **Kiểm tra hoạt động**:
   - Nhấn nút **Run now** ở góc trên phải để chạy thử nghiệm toàn bộ Job.
   - Quan sát tiến trình chạy song song của DAG trên màn hình. Nếu cả hai task hiển thị màu xanh lá cây là thành công!

---

## Bước 12: Dọn dẹp tài nguyên (Cleanup) — QUAN TRỌNG!

**Tại sao?** Các tài nguyên Azure tính tiền liên tục kể cả khi không sử dụng (đặc biệt là Databricks Cluster và SQL Warehouse). Sau khi hoàn thành lab, **BẮT BUỘC** phải dọn dẹp để tránh phát sinh chi phí không mong muốn.

### 12.1 Dừng SQL Warehouse (Ngay lập tức)
- Databricks → SQL → SQL Warehouses → `wh-lab-serverless` → **Stop**. (Warehouse Serverless sẽ tự stop sau 10 phút, nhưng dừng thủ công ngay để chắc chắn không tốn phí).

### 12.2 Dừng Cluster (Ngay lập tức)
- Databricks → Compute → Cluster đang chạy → **Terminate**.

### 12.3 Xóa toàn bộ Resource Group (Xóa mọi thứ chỉ với 1 click)
Đây là bước quan trọng nhất. Vì tất cả tài nguyên đều nằm trong `rg-databricks-lab-dev`, ta chỉ cần xóa Resource Group là sạch sẽ toàn bộ.
1. Vào Azure Portal → **Resource groups** → Chọn **`rg-databricks-lab-dev`**.
2. Nhấn **Delete resource group**.
3. Điền tên `rg-databricks-lab-dev` vào ô xác nhận → Nhấn **Delete**.
4. Đợi ~5-10 phút. Tất cả tài nguyên bên dưới (Storage Account, Access Connector, Databricks Workspace) sẽ bị xóa hoàn toàn.

> ⚠️ **Kiểm tra sau khi xóa**: Vào **All resources** trên Azure Portal và lọc theo tag `rg-databricks-lab-dev` để đảm bảo không còn tài nguyên nào bị sót.

### 12.4 Dọn dẹp dbt Cloud (Tùy chọn)
- Đăng nhập [cloud.getdbt.com](https://cloud.getdbt.com/) → Settings → Projects → Xóa project `databricks-lab-project`.

---

## Tổng kết kiến trúc đã xây dựng

| Tầng / Thành phần | Công nghệ | Bảng / Artifact | Vai trò | Kiểm soát Chất lượng (Data Quality) |
|---|---|---|---|---|
| **Ingestion** | ADLS Gen2 + Access Connector | `raw-data/customers/*.csv` | Lưu trữ raw file | Azure RBAC (Storage Blob Data Contributor) |
| **Bronze** | DLT + Auto Loader | `default.raw_customers`, `default.raw_orders` | Delta table thô, bắt file mới tự động | DLT Expectation (`customer_id is not null`) |
| **Silver** | dbt Staging | `dbt_dev.stg_customers`, `dbt_dev.stg_orders` | Chuẩn hóa, làm sạch và cast kiểu dữ liệu | dbt Schema Tests (`unique`, `not_null`, `accepted_values`) |
| **Gold** | dbt Marts | `dbt_dev.dim_customers`, `dbt_dev.fct_orders` | Mô hình Dimensional (Fact/Dim), phân khúc kinh doanh | dbt Referential Test (`relationships` kiểm tra khóa ngoại) |
| **Orchestration** | Databricks Workflows | `job-ecommerce-etl-pipeline` | Tự động hóa lập lịch chạy DLT $\rightarrow$ dbt | Tự động Email cảnh báo lỗi (Notifications) |
| **Reporting** | Databricks SQL Dashboards | `dashboard-ecommerce-overview` | Báo cáo trực quan Cloud-Native | Kiểm soát truy cập thông qua SQL Warehouse |

