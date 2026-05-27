# Lộ Trình Chi Tiết Phát Triển Lên Middle Data Engineer (Azure & Modern Data Stack Focus)

Lộ trình này được thiết kế để giúp bạn nâng cao năng lực từ Junior lên Middle Data Engineer, tập trung vào hệ sinh thái **Microsoft Azure**, **Azure Databricks**, **dbt** và các nguyên lý thiết kế hệ thống dữ liệu hiện đại dựa trên bản đồ lộ trình `roadmap.sh`.

---

## 🎯 Mục Tiêu Của Một Middle Data Engineer
* **Tự chủ (Independence)**: Có khả năng tự thiết kế, xây dựng và vận hành các pipeline dữ liệu (ETL/ELT) từ đầu đến cuối mà ít cần sự giám sát.
* **Tối ưu hóa (Optimization)**: Hiểu sâu về cấu trúc lưu trữ và tính toán để tối ưu chi phí, hiệu năng (SQL Query tuning, Spark optimization).
* **Chuẩn hóa (Standards)**: Áp dụng các kỹ thuật phần mềm vào dữ liệu (DataOps): CI/CD, viết test cho data, Infrastructure as Code (IaC).
* **Đảm bảo chất lượng (Data Governance)**: Quản lý Data Quality, Data Lineage và bảo mật dữ liệu.

---

## 🗺️ Chi Tiết Lộ Trình Học & Thực Hành (5 Giai Đoạn)

### Giai Đoạn 1: Làm Chủ Cơ Sở Dữ Liệu & Mô Hình Hóa Dữ Liệu (Data Modeling)
*Đối với Middle level, bạn không chỉ viết SQL chạy được mà phải tối ưu và thiết kế được hệ thống lưu trữ bền vững.*

* **Kiến thức cốt lõi:**
  * **Advanced SQL**: Window Functions, Common Table Expressions (CTEs), Recursive Queries, tối ưu hóa Query Execution Plan, Indexing (Clustered/Non-clustered), Partitioning.
  * **Data Modeling**: 
    * Thiết kế lược đồ **Star Schema** và **Snowflake Schema** (Fact & Dimension tables).
    * Hiểu và thiết kế **Slowly Changing Dimensions (SCD)**: Type 1 (overwrite), Type 2 (history tracking - *rất quan trọng*), và Type 3/4.
    * Phân biệt kiến trúc **OLTP** (giao dịch, chuẩn hóa 3NF) và **OLAP** (phân tích, khử chuẩn hóa).
  * **Học phần thực hành**: Thiết kế một Data Warehouse lưu trữ thông tin đơn hàng của một trang thương mại điện tử từ các bảng nguồn OLTP.

---

### Giai Đoạn 2: Xây Dựng Data Lakehouse Với Azure Databricks & PySpark
*Chuyển dịch từ xử lý dữ liệu nhỏ (Pandas, Single Node) sang xử lý dữ liệu lớn, phân tán (Distributed Computing).*

* **Kiến thức cốt lõi:**
  * **Distributed Systems Basics**: Hiểu về kiến trúc Master-Worker, cách dữ liệu được chia nhỏ (partitioning) và xử lý song song.
  * **Apache Spark / PySpark**:
    * Spark Architecture: Driver, Executors, Tasks, Jobs, Stages.
    * Phân biệt Transformation (Lazy Evaluation) và Action.
    * Tối ưu hóa Spark: Shuffle partitions, Caching, Broadcast Joins (để tránh di chuyển dữ liệu lớn qua mạng).
  * **Delta Lake**:
    * Hiểu cấu trúc của Delta Lake (Parquet files + Transaction Log).
    * Áp dụng các tính năng nâng cao: ACID Transactions, Time Travel (truy vấn dữ liệu lịch sử), Schema Enforcement/Evolution, và lệnh `MERGE` (Upsert).
  * **Azure Databricks**:
    * Sử dụng Databricks Notebooks, quản lý Clusters (Single Node vs Multi Node, Autoscaling).
    * Tích hợp với **Azure Blob Storage / ADLS Gen2** qua Unity Catalog hoặc Mount points bảo mật.
  * **Học phần thực hành**: Viết một script PySpark trên Databricks để đọc dữ liệu thô dạng JSON/CSV từ Azure Blob Storage, làm sạch, chuẩn hóa và ghi vào Delta Table dạng Silver/Gold.

---

### Giai Đoạn 3: Chuyển Đổi Dữ Liệu Chuyên Nghiệp Với dbt (Data Build Tool)
*dbt là công cụ tiêu chuẩn để thực hiện phần "T" (Transform) trong ELT hiện đại.*

* **Kiến thức cốt lõi:**
  * **dbt Architecture**: Hiểu mô hình hoạt động của dbt (dbt Core vs dbt Cloud).
  * **dbt Models & Materializations**: Viết các model dạng `view`, `table`, `incremental` (tăng trưởng), và `ephemeral`.
  * **Jinja & Macros**: Sử dụng Jinja template để viết SQL động, tạo các hàm macro tái sử dụng.
  * **Testing & Documentation**:
    * Viết các schema test (unique, not_null, accepted_values, relationships) và custom data tests.
    * Tạo và xem tài liệu tự động (`dbt docs generate`).
  * **dbt với Databricks**: Cấu hình adapter `dbt-databricks` để dbt chạy trực tiếp trên SQL Warehouse hoặc Spark Cluster của Databricks.
  * **Học phần thực hành**: Cài đặt dbt Core cục bộ, kết nối với Databricks SQL Warehouse, xây dựng các model biến đổi dữ liệu từ tầng Bronze sang Silver và Gold, đồng thời cấu hình incremental loading cho các bảng lớn.

---

### Giai Đoạn 4: Điều Phối Pipeline (Orchestration) & Ingestion trên Azure
*Kết nối các thành phần đơn lẻ thành một hệ thống tự động chạy theo lịch trình hoặc sự kiện.*

* **Kiến thức cốt lõi:**
  * **Data Ingestion (Nạp dữ liệu)**:
    * Batch Ingestion: Sử dụng **Azure Data Factory (ADF)** để copy dữ liệu từ các nguồn (SQL Server, REST API, SFTP) vào Azure Data Lake.
    * Real-time/Stream Ingestion: Hiểu cơ chế hoạt động của **Apache Kafka** hoặc **Azure Event Hubs** (Partitions, Consumer Groups).
  * **Data Orchestration (Điều phối)**:
    * Sử dụng **Apache Airflow** hoặc **Azure Data Factory (ADF) Triggers** để lên lịch và quản lý luồng chạy của dbt, Databricks Notebooks.
    * Thiết kế luồng xử lý lỗi (Retry, Alerting qua Slack/Teams/Email).
  * **Học phần thực hành**: Thiết lập một Azure Data Factory pipeline để tự động hóa: 
    1. Copy file dữ liệu từ API vào ADLS Gen2.
    2. Gọi Databricks Job để chạy PySpark biến đổi dữ liệu.
    3. Trigger dbt để cập nhật các bảng báo cáo và chạy kiểm tra chất lượng (tests).

---

### Giai Đoạn 5: DataOps, Governance & Bảo Mật (Middle-to-Senior Transition)
*Phần phân biệt giữa một kỹ sư biết code và một kỹ sư chuyên nghiệp biết xây dựng hệ thống tin cậy.*

* **Kiến thức cốt lõi:**
  * **Docker**: Đóng gói các ứng dụng dbt hoặc Airflow vào container để đảm bảo tính nhất quán giữa môi trường Local và Production.
  * **CI/CD cho Data**:
    * Thiết lập GitHub Actions tự động kiểm tra code (linting SQL với `sqlfluff`, chạy thử dbt test) khi có Pull Request mới.
  * **Data Quality & Lineage**:
    * Sử dụng các thư viện như **Great Expectations** hoặc dbt tests để giám sát chất lượng dữ liệu đầu ra.
    * Quản lý Data Lineage bằng Unity Catalog trên Databricks để biết dữ liệu đi từ đâu đến đâu.
  * **Security**: Mã hóa dữ liệu (Encryption at rest/in transit), quản lý quyền truy cập (RBAC - Role-Based Access Control) thông qua Azure Active Directory (Microsoft Entra ID) và quản lý Key/Secret qua **Azure Key Vault**.

---

## 🛠️ Checklist Đánh Giá Bản Thân (Self-Assessment Checklist)

| Chủ đề | Mức độ hiểu biết tự đánh giá (1-5) | Việc cần làm tiếp theo |
| :--- | :---: | :--- |
| **SQL & Modeling** | [ ] | Luyện tập thiết kế SCD Type 2 và viết Query Tuning. |
| **PySpark & Databricks** | [ ] | Viết code Spark không bị lỗi Out-Of-Memory (OOM). |
| **dbt (Data Build Tool)** | [ ] | Áp dụng incremental materialization và viết custom test. |
| **Azure Data Services** | [ ] | Thành thạo ADF, ADLS Gen2, Event Hubs. |
| **Orchestration (Airflow)** | [ ] | Thiết lập DAGs quản lý luồng dữ liệu phức tạp. |
| **DataOps (CI/CD, Docker)** | [ ] | Tạo GitHub Action chạy tự động dbt run/test khi commit code. |

---

> [!TIP]
> **Lời khuyên thực chiến**: Đừng cố gắng học thuộc lý thuyết. Hãy bắt đầu bằng cách xây dựng một **End-to-End Side Project** nhỏ trên tài khoản Azure Free Tier của bạn. Việc tự mình giải quyết các lỗi kết nối, phân quyền trên Azure, và cấu hình dbt sẽ giúp bạn lên tay nhanh nhất!
