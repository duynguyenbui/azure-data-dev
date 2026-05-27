# Hướng dẫn Lab 03: Enterprise Azure Databricks: Dự án Bảo hiểm Ô tô Thông minh (Smart Car Insurance) & Medallion Architecture

Chào mừng bạn đến với tài liệu hướng dẫn (Lab) cấu hình chi tiết Azure Databricks trong môi trường doanh nghiệp. Tài liệu này được biên soạn từng bước (step-by-step), bao gồm giải thích các khái niệm kiến trúc, cấu hình hạ tầng, và viết mã nguồn.

---

## 1. Kịch bản Nghiệp vụ (The Business Scenario) & Kiến trúc Giải pháp

Công ty Bảo hiểm Ô tô **SmartInsure** muốn tự động hóa quy trình xử lý yêu cầu bồi thường (Claims).
- **Dữ liệu nguồn:** Thông tin hợp đồng lưu tại SQL Server; Dữ liệu ảnh hiện trường tai nạn do khách hàng upload lên Cloud.
- **Vấn đề:** Quy trình giám định thủ công mất 3-5 ngày.
- **Giải pháp:** Xây dựng hệ thống tự động đánh giá thiệt hại bằng AI (Computer Vision) ngay khi ảnh được upload.

### Kiến trúc Medallion (Medallion Architecture)
> **Định nghĩa:** Kiến trúc Medallion là một mẫu thiết kế dữ liệu (data design pattern) chia dữ liệu thành các tầng Bronze, Silver và Gold nhằm tăng dần chất lượng và cấu trúc của dữ liệu khi nó di chuyển qua từng giai đoạn.

Để xử lý luồng dữ liệu này, chúng ta áp dụng Kiến trúc Medallion do Databricks đề xuất:
1. **Bronze Layer (Raw):** Chứa dữ liệu gốc, nguyên bản từ các nguồn.
2. **Silver Layer (Cleaned & Conformed):** Dữ liệu được làm sạch, lọc bỏ bản ghi lỗi, liên kết (Join) thông tin khách hàng với ảnh tai nạn.
3. **Gold Layer (Aggregated & Business-level):** Dữ liệu sẵn sàng phục vụ báo cáo BI, tích hợp kết quả dự đoán của mô hình AI.

---

## Phase 1: Thiết lập Hạ tầng Enterprise & Unity Catalog

Trong môi trường doanh nghiệp, bảo mật là yếu tố hàng đầu. Databricks sử dụng **Unity Catalog** để quản lý quyền truy cập tập trung.

> **Định nghĩa:** **Unity Catalog** là giải pháp quản trị dữ liệu thống nhất trên nền tảng Databricks. Nó cho phép bạn quản lý tập trung việc kiểm soát truy cập, kiểm toán (audit), quyền nguồn gốc dữ liệu (lineage), và khám phá dữ liệu trên toàn bộ các workspace của doanh nghiệp.

### Bước 1: Tạo Resource Group (Môi trường chứa tài nguyên)
> **Mục đích:** Gom nhóm toàn bộ tài nguyên (Storage, Databricks, SQL...) vào chung một nơi để dễ dàng quản lý chi phí, phân quyền và xóa dự án khi không còn sử dụng mà không sợ sót rác hệ thống.

Trước khi tạo bất kỳ dịch vụ nào, bạn cần tạo một Resource Group (RG) để gom nhóm tất cả các tài nguyên của dự án lại với nhau.

1. Đăng nhập [portal.azure.com](https://portal.azure.com).
2. Tìm **Resource groups** > **Create**.
3. Điền thông tin chuẩn:
   - **Subscription:** Chọn subscription của bạn.
   - **Resource group:** `rg-smartinsure-dev-sea` (Tên chuẩn theo dự án SmartInsure).
   - **Region:** `Southeast Asia`.
4. Nhấn **Review + create** -> **Create**.
*(Mẹo: Dành cho Data Engineer thích dùng lệnh Terminal: `az group create --name rg-smartinsure-dev-sea --location southeastasia`)*

### Bước 2: Tạo Storage Account (ADLS Gen2)
> **Mục đích:** Tạo ra một "Data Lake" khổng lồ với chi phí siêu rẻ để chứa mọi loại dữ liệu thô: từ file ảnh hiện trường (phi cấu trúc) đến file CSV, Parquet mà không bị giới hạn dung lượng.

1. Đăng nhập [portal.azure.com](https://portal.azure.com).
2. Tìm **Storage accounts** > **Create**.
3. Điền thông tin:
   - Name: `stinsurelake001`
   - Region: Chọn khu vực gần bạn (ví dụ: Southeast Asia).
   - **Lưu ý quan trọng:** Chuyển sang tab **Advanced**, bật **Enable hierarchical namespace** (Bắt buộc để trở thành Data Lake Gen2).
4. Nhấn **Review + Create**.
5. Sau khi tạo xong, vào **Containers**, tạo 3 thư mục: `bronze-raw`, `silver-cleaned`, `gold-analytics`.

### Bước 3: Tạo Azure Databricks Workspace
> **Mục đích:** Cung cấp môi trường điện toán đám mây với sức mạnh tính toán song song (Spark) khổng lồ. Đây sẽ là "bộ não" nơi chúng ta viết code để xử lý, làm sạch và phân tích dữ liệu, cũng như chạy mô hình AI.

> **💡 LƯU Ý QUAN TRỌNG VỀ CHI PHÍ (Dành cho Lab):** 
> Mặc dù tiêu chí của chúng ta là sử dụng cấu hình rẻ nhất/miễn phí, nhưng ở mục **Pricing Tier**, bạn **BẮT BUỘC phải chọn Premium**. Gói Standard (rẻ hơn) sẽ KHÔNG có tính năng bảo mật Unity Catalog (cốt lõi của bài Lab này). 
> Tuy nhiên đừng lo, tiền chỉ tính khi bạn bật máy chủ (Cluster) lên chạy code. Ở các bước sau, tôi sẽ hướng dẫn bạn tạo Cluster loại **nhỏ nhất, rẻ nhất (Single Node)** và cài đặt **tự động tắt sau 15 phút** để tối ưu chi phí (gần như bằng không nếu làm nhanh).

1. Đăng nhập [portal.azure.com](https://portal.azure.com).
2. Tìm **Azure Databricks** > **Create**.
3. Điền thông tin:
   - **Workspace name:** `adb-smartinsure-dev`
   - **Region:** `Southeast Asia` (Phải cùng Region với Resource Group).
   - **Pricing Tier:** Chọn **Premium** (hoặc Trial - 14 Days Free Premium nếu Azure có hiển thị cho bạn).
4. Nhấn **Review + Create** -> **Create**.
5. Đợi tạo xong, chọn **Go to resource** -> **Launch Workspace**.

### Bước 4: Thiết lập Unity Catalog & External Location
> **Mục đích:** Thiết lập kết nối bảo mật không dùng mật khẩu. Databricks sẽ được cấp quyền truy cập vào Data Lake thông qua một cầu nối chuyên dụng có tên là "Access Connector".

> **Định nghĩa:** **Access Connector for Azure Databricks** là một tài nguyên đặc biệt của Azure đóng vai trò làm cầu nối bảo mật giữa Unity Catalog của Databricks và Azure Storage (thay vì dùng mật khẩu). Nó sử dụng Managed Identity (Định danh được quản lý) ẩn bên dưới để tự động xác thực.

Để Databricks có quyền đọc/ghi vào `stinsurelake001` một cách bảo mật:
1. Tại Azure Portal, tìm và tạo dịch vụ **Access Connector for Azure Databricks** (Tên: `databricks-access-connector`, cùng Resource Group và Region).
2. Mở Storage Account `stinsurelake001` > **Access Control (IAM)** > **Add role assignment**. Gán quyền **Storage Blob Data Contributor** cho cái `databricks-access-connector` vừa tạo (Phân loại: Managed identity).
3. Mở `databricks-access-connector` lên, bấm **JSON View** và copy chuỗi **Resource ID** của nó.
4. Trong Databricks Workspace, mở menu **Catalog** > tab **Credentials** (hoặc Storage Credentials). Tạo Credential mới (Type: Azure Managed Identity) và dán Resource ID vừa copy vào mục **Access Connector ID**.
5. Chuyển sang tab **External Locations**, tạo một External Location trỏ tới URL `abfss://bronze-raw@stinsurelake001.dfs.core.windows.net/` sử dụng Storage Credential vừa tạo.
   - *(Lưu ý thực tế: Nếu khi bấm Save hiện bảng lỗi đỏ chữ **File Events Permissions Not Verified**, bạn chỉ cần kéo xuống dưới cùng và bấm nút **Force create the location / Skip and create** để bỏ qua. Tính năng này không bắt buộc cho Lab).*

### Bước 5: Tạo Cấu trúc Catalog & Phân quyền
> **Mục đích:** Xây dựng cấu trúc thư mục logic (Catalog > Schema > Table/Volume) để dễ dàng quản lý và cấp quyền truy cập chi tiết cho từng phòng ban (ví dụ: Data Engineer được xem Data thô, Business Analyst chỉ được xem Data sạch).

Mở một Notebook SQL trong Databricks (Nếu giao diện Databricks của bạn là bản **Serverless** mới, chỉ cần chọn **+ New -> Notebook**, đổi sang SQL và chạy, hệ thống sẽ tự cấp máy chủ ngầm mà không cần bạn tự tạo Compute thủ công) và thực thi lần lượt:

```sql
-- 1. Create a dedicated Catalog for the project
CREATE CATALOG IF NOT EXISTS smart_insurance;
USE CATALOG smart_insurance;

-- 2. Create 3 Schemas corresponding to the 3 data layers
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

-- 3. Create a Volume to store unstructured files (Crash images)
CREATE VOLUME IF NOT EXISTS bronze.crash_images
COMMENT 'Volume to store original crash images uploaded by customers';

-- 4. (Optional) Grant permissions to the Data Scientist group
-- Assuming there is a 'data_scientists' group in Databricks
GRANT USAGE ON CATALOG smart_insurance TO `data_scientists`;
GRANT SELECT ON SCHEMA silver TO `data_scientists`;
```

---

## Phase 2: Ingest dữ liệu thô (Bronze Layer)

### Bước 1: Thu nạp Dữ liệu từ Cloud Storage (Images & Metadata) bằng Delta Live Tables (DLT)
> **Mục đích:** Dùng framework khai báo DLT (y hệt như dự án thực tế) để tự động hút ảnh tai nạn và metadata từ Data Lake (S3/ADLS) vào Databricks mà không cần viết code lập lịch hay quản lý checkpoint thủ công.

> **Định nghĩa:** **Delta Live Tables (DLT)** là một framework Data Engineering tích hợp sẵn của Databricks giúp xây dựng các pipeline xử lý dữ liệu mạnh mẽ, tự động quản lý hạ tầng, xử lý lỗi và vẽ sơ đồ luồng dữ liệu (lineage graph).

**Phần A: Chuẩn bị Code DLT**
Tạo một Notebook Python tên là `01_Ingest_Cloud_Storage` và dán đoạn code khai báo DLT sau vào (LƯU Ý: Tuyệt đối KHÔNG bấm Run trong Notebook này vì DLT chỉ chạy thông qua Pipeline):

```python
import dlt

# Configure paths
source_image_path = "abfss://bronze-raw@stinsurelake001.dfs.core.windows.net/claims/images/"
source_meta_path = "abfss://bronze-raw@stinsurelake001.dfs.core.windows.net/claims/metadata/"

# 1. DLT Table for Images (using Auto Loader cloudFiles)
@dlt.table(
    name="raw_crash_images",
    comment="Raw crash images ingested via Auto Loader",
    table_properties={"quality": "bronze"}
)
def raw_images_table():
    return (
        spark.readStream
        .format("cloudFiles")
        .option("cloudFiles.format", "binaryFile")
        .option("pathGlobFilter", "*.jpg")
        .load(source_image_path)
    )

# 2. DLT Table for Metadata
@dlt.table(
    name="claim_images_meta",
    comment="Metadata for crash images",
    table_properties={"quality": "bronze"}
)
def meta_table():
    return (
        spark.readStream
        .format("cloudFiles")
        .option("cloudFiles.format", "csv")
        .option("cloudFiles.inferColumnTypes", "true")
        .option("header", "true")
        .load(source_meta_path)
    )
```

**Phần B: Tạo và Khởi chạy DLT Pipeline**
1. Ở menu trái của Databricks, chọn **Jobs & Pipelines** > tab **Delta Live Tables**.
2. Bấm **Create pipeline**.
3. Điền thông tin:
   - Pipeline name: `smart_insurance_bronze_pipeline`
   - Pipeline mode: `Triggered`
   - Source code: Chọn file Notebook `01_Ingest_Cloud_Storage` vừa lưu.
   - Destination: `Unity Catalog` (Catalog: `smart_insurance`, Target schema: `bronze`)
4. Bấm **Create** và sau đó bấm **Start** để kích hoạt cỗ máy. Databricks sẽ tự động vẽ sơ đồ và hút dữ liệu.

### Bước 2: Thu nạp Dữ liệu Khách hàng bằng Delta Live Tables (Đường tắt)
> **Mục đích:** Thay vì phải tốn tiền dựng một máy chủ Azure SQL đắt đỏ chỉ để mô phỏng LakeFlow Connect, chúng ta sẽ "đi đường tắt" bằng cách dùng luôn cỗ máy DLT để hút trực tiếp các file dữ liệu khách hàng (CSV) từ Data Lake vào tầng Bronze.

**Cập nhật Code vào Pipeline hiện tại**
Trở lại file Notebook `01_Ingest_Cloud_Storage` (nơi bạn vừa viết code hút ảnh), hãy dán THÊM đoạn code dưới đây vào cuối file. Đoạn code này sẽ khai báo thêm 3 bảng DLT để hút dữ liệu Customer, Policy và Claim.

```python
# Configure path for SQL Server CSV exports
source_sql_path = "abfss://bronze-raw@stinsurelake001.dfs.core.windows.net/sql_server/"

# 3. DLT Table for Customer
@dlt.table(
    name="raw_customer",
    comment="Raw customer data from static CSV export",
    table_properties={"quality": "bronze"}
)
def raw_customer():
    return (
        spark.readStream.format("cloudFiles")
        .option("cloudFiles.format", "csv")
        .option("cloudFiles.inferColumnTypes", "true")
        .option("header", "true")
        .option("pathGlobFilter", "customers.csv")
        .load(source_sql_path)
    )

# 4. DLT Table for Policy
@dlt.table(
    name="raw_policy",
    comment="Raw policy data from static CSV export",
    table_properties={"quality": "bronze"}
)
def raw_policy():
    return (
        spark.readStream.format("cloudFiles")
        .option("cloudFiles.format", "csv")
        .option("cloudFiles.inferColumnTypes", "true")
        .option("header", "true")
        .option("pathGlobFilter", "policies.csv")
        .load(source_sql_path)
    )

# 5. DLT Table for Claim
@dlt.table(
    name="raw_claim",
    comment="Raw claim data from static CSV export",
    table_properties={"quality": "bronze"}
)
def raw_claim():
    return (
        spark.readStream.format("cloudFiles")
        .option("cloudFiles.format", "csv")
        .option("cloudFiles.inferColumnTypes", "true")
        .option("header", "true")
        .option("pathGlobFilter", "claims.csv")
        .load(source_sql_path)
    )
```

**Khởi chạy lại Pipeline**
1. Mở lại màn hình **Jobs & Pipelines** > **Delta Live Tables**.
2. Chọn cái cỗ máy `smart_insurance_bronze_pipeline` lúc nãy.
3. Bấm **Start** một lần nữa. Cỗ máy sẽ tự động nhận diện đoạn code mới thêm vào, mở rộng mạng lưới sơ đồ (Lineage Graph) ra thành 5 bảng, và tự động hút nốt số dữ liệu khách hàng này vào Tầng Bronze.

---

## Phase 3: Chuẩn hóa & Liên kết Dữ liệu (Silver Layer)

Ở tầng này, chúng ta sẽ thực hiện làm sạch dữ liệu từ Tầng Bronze. Thay vì phải viết code `MERGE` phức tạp, Databricks cung cấp một tính năng cực kỳ mạnh mẽ trong DLT gọi là **Data Quality Expectations** (Kỳ vọng chất lượng dữ liệu). Nó giống như một "chốt kiểm dịch", giúp tự động lọc bỏ các dòng dữ liệu bị lỗi (thiếu ID, sai định dạng ngày tháng) ra khỏi hệ thống.

### Bước 1: Tạo Notebook xử lý Silver
1. Trong Workspace, tạo một Notebook mới tên là `02_Process_Silver`.
2. Dán đoạn code DLT dưới đây vào. Đoạn code này sẽ đọc dữ liệu từ các bảng `raw_` (Bronze) mà chúng ta vừa tạo, làm sạch chúng, và xuất ra các bảng `silver_`.

```python
import dlt
from pyspark.sql.functions import col, to_date, initcap, split, size, when, concat, lit, abs, regexp_extract

catalog = "smart_insurance"
bronze_schema = "bronze"
silver_schema = "silver"

# --- 1. CLEAN POLICY ---
@dlt.table(
    name=f"{catalog}.{silver_schema}.policy",
    comment="Cleaned policies",
    table_properties={"quality": "silver"}
)
@dlt.expect("valid_policy_no", "policy_no IS NOT NULL") # Drop row if policy number is null
def policy():
    return (
        dlt.readStream(f"{catalog}.{bronze_schema}.raw_policy")
        .withColumn("premium", abs("premium")) # Convert premium to absolute value
        .drop("_rescued_data")
    )

# --- 2. CLEAN CLAIM ---
@dlt.table(
    name=f"{catalog}.{silver_schema}.claim",
    comment="Cleaned claims",
    table_properties={"quality": "silver"}
)
@dlt.expect_all({
    "valid_claim_number": "claim_no IS NOT NULL",
    "valid_incident_hour": "incident_hour BETWEEN 0 AND 23" # Incident hour must be between 0 and 23
})
def claim():
    df = dlt.readStream(f"{catalog}.{bronze_schema}.raw_claim")
    return (
        df.withColumn("claim_date", to_date(col("claim_date")))
        .withColumn("incident_date", to_date(col("date"), "yyyy-MM-dd"))
        .withColumn("license_issue_date", to_date(col("license_issue_date"), "dd-MM-yyyy"))
        .withColumnRenamed("hour", "incident_hour")
        .withColumnRenamed("type", "incident_type")
        .withColumnRenamed("severity", "incident_severity")
        .drop("date", "_rescued_data")
    )

# --- 3. CLEAN CUSTOMER ---
@dlt.table(
    name=f"{catalog}.{silver_schema}.customer",
    comment="Cleaned customers",
    table_properties={"quality": "silver"}
)
@dlt.expect_all({
    "valid_customer_id": "customer_id IS NOT NULL"
})
def customer():
    df = dlt.readStream(f"{catalog}.{bronze_schema}.raw_customer")
    
    # Tách cột Name thành First Name và Last Name
    name_normalized = when(
        size(split(col("name"), ",")) == 2,
        concat(
            initcap(split(col("name"), ",").getItem(1)), lit(" "),
            initcap(split(col("name"), ",").getItem(0))
        )
    ).otherwise(initcap(col("name")))

    return (
        df
        .withColumn("date_of_birth", to_date(col("date_of_birth"), "dd-MM-yyyy"))
        .withColumn("firstname", split(name_normalized, " ").getItem(0))
        .withColumn("lastname", split(name_normalized, " ").getItem(1))
        .withColumn("address", concat(col("borough"), lit(", "), col("zip_code")))
        .drop("name", "_rescued_data")
    )

# --- 4. CLEAN IMAGES ---
@dlt.table(
    name=f"{catalog}.{silver_schema}.crash_images",
    comment="Enriched claim images",
    table_properties={"quality": "silver"}
)
def crash_images():
    df = dlt.readStream(f"{catalog}.{bronze_schema}.raw_crash_images")
    return df.withColumn("image_name", regexp_extract(col("path"), r".*/(.*?.jpg)", 1))
```

### Bước 2: Nối Notebook Silver vào Pipeline hiện tại
Điều tuyệt vời nhất của DLT là bạn KHÔNG cần phải tạo một Pipeline mới. Bạn chỉ cần gắn cái Notebook `02_Process_Silver` này vào chung cỗ máy ban nãy là nó sẽ tự động nối các đường ống lại với nhau!

1. Mở lại **Jobs & Pipelines** > **Delta Live Tables**.
2. Chọn Pipeline `smart_insurance_bronze_pipeline` của bạn.
3. Ở góc trên cùng bên phải, bấm nút **Settings** (Cài đặt).
4. Tìm mục **Source code** (Nơi bạn chọn file Notebook lúc trước), bấm nút **Add source code** (hoặc dấu `+`).
5. Chọn tới file `02_Process_Silver` mà bạn vừa tạo.
6. Kéo xuống phần **Target schema** (nếu có), đổi tên bảng đích thành `silver` thay vì `bronze` (Hoặc nếu cài đặt Catalog của Pipeline đang khóa ở schema `bronze`, hãy để nguyên, nó sẽ tự lưu theo cấu trúc DLT).
7. Bấm **Save**.
8. Bấm **Start** để cỗ máy chạy lại. Bạn sẽ thấy sơ đồ Pipeline lúc này phình to ra, các luồng dữ liệu từ bảng `raw_` sẽ được làm sạch và chảy trực tiếp sang bảng `silver_`!

---

## Phase 4: Machine Learning & MLOps với MLflow

> **Định nghĩa:** **MLflow** là một nền tảng mã nguồn mở quản lý vòng đời Machine Learning, bao gồm việc ghi nhận (tracking) các lần huấn luyện mô hình, quản lý phiên bản mô hình (Model Registry), và triển khai mô hình.

Tạo Notebook `03_Model_Training_MLflow`. Sử dụng Cluster loại **Databricks Runtime for Machine Learning (MLR)**.

### Bước 0: Chuẩn bị Bảng Dữ liệu Huấn luyện từ Storage
> **Mục đích:** Đọc các tệp ảnh huấn luyện mẫu đã tải lên Data Lake, bóc tách nhãn từ tên tệp (ví dụ: "ok", "minor", "major") rồi lưu vào Delta Table để mô hình AI có thể đọc và học trực tiếp.

Thực thi đoạn mã PySpark này đầu tiên để tạo bảng dữ liệu mẫu:

```python
# 1. Read labeled images from Data Lake
raw_labeled_df = (spark.read.format("binaryFile")
                  .load("abfss://bronze-raw@stinsurelake001.dfs.core.windows.net/training_imgs/"))

# 2. Extract label from filename (e.g., "1-minor (3).png" -> "minor")
from pyspark.sql.functions import regexp_extract, col, when

labeled_df = (raw_labeled_df
              .withColumn("FileName", regexp_extract(col("path"), r"([^/]+)$", 1))
              .withColumn("LabelText", regexp_extract(col("FileName"), r"-([a-zA-Z]+)", 1))
              # Map text labels to integers for PyTorch training (0: OK, 1: Minor, 2: Major, 3: Other)
              .withColumn("label", when(col("LabelText") == "ok", 0)
                                   .when(col("LabelText") == "minor", 1)
                                   .when(col("LabelText") == "major", 2)
                                   .otherwise(3))
              .select("content", "label"))

# 3. Write to Silver table to use as training data
labeled_df.write.mode("overwrite").saveAsTable("smart_insurance.silver.labeled_claims")
print("Successfully created labeled dataset!")
```

### Bước 1: Chuẩn bị Dữ liệu (DataLoader & Transforms)
> **Mục đích:** Biến đổi các file hình ảnh thành các ma trận số học (Tensor) và đóng gói thành từng lô (batch) để nhồi vào mô hình AI huấn luyện, vì AI chỉ hiểu số chứ không hiểu hình ảnh.

```python
import mlflow
import mlflow.pytorch
import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import models, transforms
from PIL import Image
import io
import pandas as pd
from torch.utils.data import Dataset, DataLoader

# Configure MLflow
mlflow.set_experiment("/Shared/SmartCarInsurance_DamageClassifier")

# Define Dataset to read Binary images from Delta Table
class CrashImageDataset(Dataset):
    def __init__(self, spark_df, transform=None):
        self.data = spark_df.select("content", "label").toPandas()
        self.transform = transform
        
    def __len__(self):
        return len(self.data)
        
    def __getitem__(self, idx):
        img_bytes = self.data.iloc[idx]["content"]
        label = self.data.iloc[idx]["label"]
        image = Image.open(io.BytesIO(img_bytes)).convert("RGB")
        if self.transform:
            image = self.transform(image)
        return image, label

# Configure image transformations for ResNet
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

# Load labeled data
spark_train_df = spark.read.table("smart_insurance.silver.labeled_claims")
dataset = CrashImageDataset(spark_train_df, transform=transform)
dataloader = DataLoader(dataset, batch_size=16, shuffle=True)
```

### Bước 2: Huấn luyện & Ghi nhận vào Unity Catalog
> **Mục đích:** Dạy cho mô hình AI cách nhận biết mức độ hỏng hóc của xe, đồng thời dùng MLflow để tự động ghi chép lại toàn bộ quá trình học (điểm số, tham số) và lưu trữ phiên bản mô hình tốt nhất vào kho.

```python
# 1. Fine-tune ResNet50
model = models.resnet50(pretrained=True)
num_ftrs = model.fc.in_features
model.fc = nn.Linear(num_ftrs, 4) # 4 Damage Levels

criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=0.001)

# 2. Tạo một lớp vỏ bọc (Wrapper) để tự động dịch ảnh Bytes -> Tensor cho AI hiểu
# (Khắc phục hoàn toàn lỗi không tương thích định dạng dữ liệu)
import mlflow.pyfunc
from mlflow.models.signature import infer_signature

class CarDamageWrapper(mlflow.pyfunc.PythonModel):
    def __init__(self, trained_model):
        self.model = trained_model
        
    def predict(self, context, model_input):
        import io
        import torch
        from PIL import Image
        from torchvision import transforms
        
        transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
        ])
        
        self.model.eval()
        preds = []
        for img_bytes in model_input["content"]:
            image = Image.open(io.BytesIO(img_bytes)).convert("RGB")
            tensor = transform(image).unsqueeze(0)
            with torch.no_grad():
                output = self.model(tensor)
                pred = torch.argmax(output, dim=1).item()
                preds.append(pred)
        return pd.Series(preds)

# 3. Track experiment with MLflow
with mlflow.start_run() as run:
    mlflow.log_params({"model_architecture": "resnet50", "epochs": 5, "learning_rate": 0.001})
    
    model.train()
    for epoch in range(1): # Simulate 1 epoch for fast demo
        running_loss = 0.0
        for inputs, labels in dataloader:
            labels = labels.long() # Đảm bảo đúng định dạng cho CrossEntropyLoss

            optimizer.zero_grad()
            outputs = model(inputs)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()
            running_loss += loss.item()
            
        epoch_loss = running_loss / len(dataloader)
        mlflow.log_metric("loss", epoch_loss, step=epoch)
        print(f"Epoch Loss: {epoch_loss}")
        
    # 4. Bọc mô hình lại và Ký tên (Signature) để Unity Catalog chấp nhận
    wrapped_model = CarDamageWrapper(model)
    
    sample_input = pd.DataFrame({"content": [b"dummy_bytes_for_signature"]})
    sample_output = pd.Series([1])
    signature = infer_signature(sample_input, sample_output)

    # Đăng ký mô hình lên Unity Catalog với định dạng PyFunc
    mlflow.pyfunc.log_model(
        artifact_path="model", 
        python_model=wrapped_model,
        registered_model_name="smart_insurance.gold.car_damage_classifier",
        signature=signature
    )
    print("Mô hình đã được đóng gói, ký tên và đăng ký THÀNH CÔNG lên Unity Catalog!")
```

**Đánh dấu phiên bản Champion bằng SQL:**
```sql
ALTER MODEL smart_insurance.gold.car_damage_classifier SET TAGS ('stage' = 'production');
```

---

## Phase 5: Phục vụ Mô hình (Model Serving & Batch Inference)

> **Định nghĩa:** **Model Serving** là quá trình triển khai một mô hình Machine Learning thành một API (như REST endpoint) để các ứng dụng khác (ví dụ: app di động) có thể gọi và nhận kết quả dự đoán (inference) theo thời gian thực.

### Bước 1: Suy luận Hàng loạt (Batch Inference) trên Delta Table
> **Mục đích:** Tận dụng sức mạnh xử lý song song của Databricks để tự động chấm điểm thiệt hại cho hàng chục ngàn bức ảnh mới mỗi đêm trong thời gian cực ngắn, chuẩn bị sẵn dữ liệu cho báo cáo sáng hôm sau.

Được sử dụng trong các Data Pipeline chạy định kỳ hàng đêm. Lợi ích của `mlflow.pyfunc.spark_udf` là mô hình sẽ được phân tương tác trên các Worker Node của Spark, xử lý hàng triệu ảnh cực nhanh.

```python
# Cài đặt thư viện bắt buộc cho các Worker (Máy chủ phụ)
%pip install torch torchvision mlflow pandas pillow

import mlflow
from mlflow import MlflowClient
from pyspark.sql.functions import struct, col, expr

# --- Tự động tìm Version mới nhất ---
model_name = "smart_insurance.gold.car_damage_classifier"
client = MlflowClient()
versions = client.search_model_versions(f"name='{model_name}'")
latest_version = sorted([int(v.version) for v in versions])[-1] 
print(f"Đang sử dụng Mô hình phiên bản số: {latest_version}")
# ------------------------------------

# 1. Gọi Giám khảo AI từ trong kho ra
model_uri = f"models:/{model_name}/{latest_version}"
predict_udf = mlflow.pyfunc.spark_udf(spark, model_uri=model_uri)

# 2. Đọc toàn bộ ảnh tai nạn ở tầng Silver
unprocessed_claims = spark.read.table("smart_insurance.silver.crash_images")

# 3. Bản dịch ngôn ngữ
mapping_expr = "CASE predicted_damage_code WHEN 0 THEN 'OK' WHEN 1 THEN 'Minor' WHEN 2 THEN 'Major' ELSE 'Total Loss' END"

# 4. Chấm điểm và Xuất kết quả
predictions_df = (unprocessed_claims
                  .withColumn("predicted_damage_code", predict_udf(struct(col("content"))))
                  .withColumn("AI_Prediction", expr(mapping_expr)))

predictions_df.write.mode("overwrite").saveAsTable("smart_insurance.gold.fact_claims_damage")
display(predictions_df.select("path", "AI_Prediction"))
```

### Bước 2: Gọi REST API Thời gian thực (Client Application)
> **Mục đích:** Biến mô hình AI thành một dịch vụ web 24/7. Nhờ đó, ứng dụng di động của công ty bảo hiểm có thể gửi ảnh chụp hiện trường lên và nhận kết quả đánh giá thiệt hại ngay lập tức trong vài giây.

Sau khi tạo **Model Serving Endpoint** trong giao diện Databricks, ứng dụng Mobile có thể gửi yêu cầu HTTP để nhận kết quả ngay.

*Ví dụ mã Python Backend:*
```python
import requests
import json
import base64

DATABRICKS_HOST = "https://adb-xxx.azuredatabricks.net"
DATABRICKS_TOKEN = "dapi_your_token_here"
ENDPOINT_URL = f"{DATABRICKS_HOST}/serving-endpoints/car-damage-classifier-api/invocations"

# Đọc ảnh và mã hóa base64
with open("test_crash.jpg", "rb") as image_file:
    encoded_string = base64.b64encode(image_file.read()).decode('utf-8')

headers = {"Authorization": f"Bearer {DATABRICKS_TOKEN}", "Content-Type": "application/json"}
data = {
    "dataframe_records": [
        {"content": encoded_string}
    ]
}

response = requests.post(ENDPOINT_URL, headers=headers, json=data)
print("Kết quả đánh giá AI:", response.json())
```

---

## Phase 6: Khai thác Dữ liệu & AI/BI Genie

> **Định nghĩa:** **AI/BI Genie** là tính năng báo cáo thông minh của Databricks, cho phép người dùng đặt câu hỏi bằng ngôn ngữ tự nhiên (tiếng Anh/Việt) để truy vấn dữ liệu trực tiếp từ các bảng thay vì phải tự viết câu lệnh SQL hay vẽ biểu đồ thủ công.

### Bước 1: Xây dựng Bảng Gold Tổng hợp
> **Mục đích:** Lắp ghép tất cả các mảnh ghép rời rạc (Thông tin khách hàng + Kết quả AI chấm điểm ảnh) thành một bảng dữ liệu duy nhất, hoàn chỉnh và thân thiện nhất để phục vụ cho việc vẽ biểu đồ cho ban giám đốc.

Tạo Data Mart phục vụ báo cáo:
```sql
CREATE OR REPLACE TABLE smart_insurance.gold.customer_claims_analysis AS
SELECT 
    c.CustomerID,
    c.FullName,
    c.Email,
    f.ClaimID,
    f.damage_level,
    f.modificationTime as ClaimDate
FROM 
    smart_insurance.silver.customers c
INNER JOIN 
    smart_insurance.gold.fact_claims_damage f
ON 
    c.CustomerID = f.ClaimID;
```

### Bước 2: Cấu hình AI/BI Genie
> **Mục đích:** Giúp các sếp và nhân viên nghiệp vụ (những người không rành viết code SQL) có thể tự do hỏi đáp, tra cứu dữ liệu dự án bằng ngôn ngữ tự nhiên giống như đang chat với ChatGPT.

1. Chọn **AI/BI** > **Genie** > **New Genie Space**.
2. Chọn bảng `smart_insurance.gold.customer_claims_analysis`.
3. Cung cấp ngữ cảnh (Instructions):
   - *"Trường `damage_level` bao gồm các mức độ thiệt hại của xe ô tô: Minor, Moderate, Severe, Total Loss."*
   - *"Khi người dùng hỏi về thời gian, hãy sử dụng trường `ClaimDate`."*
4. Click **Publish**. Bây giờ Giám đốc có thể chat: *"Cho tôi biết top 5 khách hàng có nhiều yêu cầu bồi thường Total Loss nhất trong tháng này"* và nhận được ngay biểu đồ.

---

## Phase 7: Quy trình Kiểm thử Toàn diện (E2E Test)

Để đảm bảo toàn bộ kiến trúc chạy mượt mà:
1. **Kiểm tra Auto Loader:** Tải 1 file ảnh `claim_9999_test.jpg` vào ADLS.
2. **Kiểm tra Silver Layer:** Chạy lại file `02_Process_Silver` để xem bảng `silver.crash_images` có tăng thêm dòng dữ liệu ClaimID = 9999 không.
3. **Kiểm tra Batch Inference:** Chạy lại quá trình Model Scoring để tạo bảng Gold.
4. **Kiểm tra BI:** Viết truy vấn `SELECT * FROM smart_insurance.gold.customer_claims_analysis WHERE ClaimID = 9999;` để xem mức độ thiệt hại AI vừa phân loại.

---

## Phase 8: Dọn dẹp Tài nguyên (Clean up)

> **Mục đích:** Xóa toàn bộ hạ tầng đã tạo để hệ thống ngừng tính phí dịch vụ trên Azure. Đây là thói quen bắt buộc sau khi hoàn thành các bài Lab thực hành.

Chỉ cần một thao tác duy nhất là bạn có thể xóa sạch mọi thứ vì chúng ta đã gom tất cả vào chung một Resource Group ở Bước 1.

1. Đăng nhập [portal.azure.com](https://portal.azure.com).
2. Mở mục **Resource groups**.
3. Chọn `rg-smartinsure-dev-sea`.
4. Bấm nút **Delete resource group** (hình thùng rác) ở menu trên cùng.
5. Gõ lại tên `rg-smartinsure-dev-sea` vào ô xác nhận và bấm **Delete**. 
Quá trình xóa sẽ diễn ra trong vài phút và Azure sẽ không còn tính bất kỳ chi phí nào nữa.
