# 🚀 Lộ Trình Học Tập — Data Engineer @ FPT Software

> **Mục tiêu**: Trang bị đầy đủ kiến thức & kỹ năng theo yêu cầu JD Data Engineer tại FPT Software, với trọng tâm là **Snowflake**, **Cloud (AWS/Azure/GCP)**, **ETL/ELT pipelines**, và **modern data stack**.
>
> **Thời gian ước tính**: 16–20 tuần (học song song lý thuyết + thực hành)

---

## 📋 Tổng Quan Yêu Cầu Từ JD

| Nhóm kỹ năng | Yêu cầu chính | Mức độ |
| :--- | :--- | :---: |
| **Snowflake** | Data modeling, performance tuning, cost optimization | ⭐⭐⭐ Bắt buộc |
| **Cloud** | AWS / Azure / GCP — ít nhất 1 nền tảng thành thạo | ⭐⭐⭐ Bắt buộc |
| **SQL** | Advanced SQL, query optimization | ⭐⭐⭐ Bắt buộc |
| **Python** | Scripting, data processing | ⭐⭐⭐ Bắt buộc |
| **ETL/ELT Tools** | Airflow, dbt, ADF, Glue | ⭐⭐⭐ Bắt buộc |
| **Data Warehousing** | Star schema, Snowflake schema, pipeline design | ⭐⭐⭐ Bắt buộc |
| **dbt / Modern Data Stack** | dbt Core/Cloud, modern ELT | ⭐⭐ Nên có |
| **Data Streaming** | Kafka, Kinesis | ⭐⭐ Nên có |
| **Big Data** | Spark, Hadoop | ⭐ Tốt nếu có |
| **Chứng chỉ** | Snowflake hoặc Cloud certifications | ⭐⭐ Nên có |
| **Tiếng Anh** | Giao tiếp tốt (nói + viết) | ⭐⭐⭐ Bắt buộc |

---

## 🗺️ Chi Tiết Lộ Trình (6 Giai Đoạn)

---

### 🔷 Giai Đoạn 1: Nền Tảng SQL & Mô Hình Hóa Dữ Liệu (Tuần 1–3)

> *SQL là ngôn ngữ chính của Data Engineer. Bạn phải viết SQL tối ưu, không chỉ "chạy được".*

#### 📚 Kiến thức cần nắm

- **Advanced SQL**:
  - Window Functions: `ROW_NUMBER()`, `RANK()`, `DENSE_RANK()`, `LAG()`, `LEAD()`, `NTILE()`
  - Common Table Expressions (CTEs) — bao gồm Recursive CTEs
  - Subqueries tối ưu vs JOIN performance
  - Query Execution Plan: đọc hiểu và tối ưu
  - Indexing strategies (Clustered / Non-clustered)
  - Partitioning & Clustering

- **Data Warehousing Concepts**:
  - Phân biệt **OLTP** (chuẩn hóa 3NF, phục vụ giao dịch) vs **OLAP** (khử chuẩn hóa, phục vụ phân tích)
  - **Star Schema**: Fact tables + Dimension tables
  - **Snowflake Schema**: Dimension tables được chuẩn hóa thêm
  - **Slowly Changing Dimensions (SCD)**: Type 1 (ghi đè), Type 2 (lưu lịch sử), Type 3 (cột mới)
  - Data Vault 2.0 (khái niệm cơ bản: Hub, Link, Satellite)

- **Data Pipeline Design**:
  - ETL vs ELT — khi nào dùng cái nào
  - Batch vs Stream processing
  - Idempotency trong pipeline (chạy lại không tạo dữ liệu trùng)
  - Backfill strategies

#### 🛠️ Thực hành

- [ ] Giải 30 bài SQL trên [LeetCode](https://leetcode.com/studyplan/top-sql-50/) hoặc [HackerRank](https://www.hackerrank.com/domains/sql)
- [ ] Thiết kế Star Schema cho hệ thống e-commerce (orders, products, customers, time)
- [ ] Viết script tạo SCD Type 2 bằng SQL thuần (sử dụng `MERGE` statement)
- [ ] Vẽ ERD cho ít nhất 2 use case thực tế bằng [dbdiagram.io](https://dbdiagram.io)

#### 📖 Tài liệu tham khảo

- 📘 *The Data Warehouse Toolkit* — Ralph Kimball (sách gối đầu giường)
- 🎥 [SQL Tutorial - Full Database Course (freeCodeCamp)](https://www.youtube.com/watch?v=HXV3zeQKqGY)
- 📝 [Star Schema vs Snowflake Schema](https://www.guru99.com/star-snowflake-data-warehousing.html)

---

### 🔷 Giai Đoạn 2: Làm Chủ Snowflake (Tuần 4–7)

> *Snowflake là trọng tâm số 1 của JD. Bạn cần hiểu sâu kiến trúc, tối ưu hiệu năng và quản lý chi phí.*

#### 📚 Kiến thức cần nắm

- **Kiến trúc Snowflake**:
  - 3 lớp kiến trúc: **Cloud Services** → **Query Processing (Virtual Warehouses)** → **Database Storage**
  - Tách biệt Storage và Compute (và ý nghĩa thực tế)
  - Micro-partitions & Data Clustering
  - Metadata management tự động

- **Data Modeling trong Snowflake**:
  - Database → Schema → Table/View/Stage
  - Table types: Permanent, Transient, Temporary, External
  - `VARIANT`, `OBJECT`, `ARRAY` — xử lý dữ liệu semi-structured (JSON, Parquet, Avro)
  - Streams & Tasks — Change Data Capture (CDC) native trong Snowflake
  - Dynamic Tables — materialized views thế hệ mới

- **Performance Tuning**:
  - **Clustering Keys**: Khi nào cần, cách chọn
  - **Search Optimization Service**
  - **Materialized Views** vs Regular Views
  - Query Profile: đọc hiểu, phát hiện bottleneck (Spillage, Pruning, Remote I/O)
  - **Result Caching** (3 tầng: Result Cache → Local Disk Cache → Remote Disk)

- **Cost Optimization**:
  - Virtual Warehouse sizing: X-Small → 6X-Large
  - Auto-suspend & Auto-resume
  - Multi-cluster warehouses
  - Resource Monitors & Credit alerts
  - Warehouse utilization monitoring

- **Data Loading & Unloading**:
  - Internal Stages vs External Stages (S3, Azure Blob, GCS)
  - `COPY INTO` — bulk loading
  - **Snowpipe** — continuous/automated loading
  - File formats: CSV, JSON, Parquet, Avro, ORC

- **Security & Governance**:
  - Role-Based Access Control (RBAC): `ACCOUNTADMIN`, `SYSADMIN`, `SECURITYADMIN`
  - Row Access Policies & Column-level Security (Masking Policies)
  - Time Travel (1–90 ngày) & Fail-safe
  - Data Sharing (Secure Data Sharing, Marketplace)

#### 🛠️ Thực hành

- [ ] Tạo tài khoản Snowflake Trial (30 ngày miễn phí, $400 credit)
- [ ] Thiết kế Data Warehouse hoàn chỉnh: `RAW` → `STAGING` → `ANALYTICS` schemas
- [ ] Load dữ liệu JSON semi-structured vào Snowflake, flatten bằng `LATERAL FLATTEN`
- [ ] Cấu hình Snowpipe tự động load từ S3/Azure Blob
- [ ] Phân tích Query Profile cho 5 query chậm, áp dụng Clustering Key để cải thiện
- [ ] Thiết lập Resource Monitor cảnh báo khi tiêu quá 50% credit hàng tháng
- [ ] Tạo Streams + Tasks để xây dựng CDC pipeline đơn giản
- [ ] Lab: Hoàn thành [Snowflake Hands-On Essentials](https://learn.snowflake.com/en/courses/) (miễn phí)

#### 📖 Tài liệu tham khảo

- 🎓 [Snowflake University](https://learn.snowflake.com/) — Khóa học chính thức miễn phí
- 📘 [Snowflake Documentation](https://docs.snowflake.com/)
- 🎥 [Snowflake YouTube Channel](https://www.youtube.com/@SnowflakeInc)
- 📝 [Snowflake Cookbook](https://quickstarts.snowflake.com/) — Hands-on guides

#### 🏅 Chứng chỉ khuyến nghị

- **SnowPro Core Certification** (COF-C02) — Chứng chỉ nền tảng, **nên thi sớm**
- **SnowPro Advanced: Data Engineer** — Mục tiêu dài hạn

---

### 🔷 Giai Đoạn 3: Cloud Platform — AWS / Azure / GCP (Tuần 8–10)

> *JD yêu cầu kinh nghiệm cloud. Chọn 1 nền tảng làm chính, hiểu cơ bản 2 nền tảng còn lại.*

#### 📚 Kiến thức cần nắm (Chọn 1 làm chính)

**🔶 AWS (Phổ biến nhất cho Snowflake)**

| Dịch vụ | Vai trò trong Data Engineering |
| :--- | :--- |
| **S3** | Data Lake storage — lưu raw data, staging |
| **IAM** | Quản lý quyền truy cập, roles, policies |
| **Lambda** | Serverless compute cho event-driven pipelines |
| **Glue** | ETL service — crawlers, jobs, catalog |
| **Kinesis** | Real-time data streaming |
| **Redshift** | Cloud data warehouse (đối thủ Snowflake) |
| **CloudWatch** | Monitoring & logging |
| **EventBridge** | Event-driven orchestration |

**🔷 Azure (FPT có nhiều dự án Azure)**

| Dịch vụ | Vai trò trong Data Engineering |
| :--- | :--- |
| **ADLS Gen2** | Data Lake storage |
| **Azure Data Factory** | ETL/ELT orchestration |
| **Azure Functions** | Serverless compute |
| **Azure Event Hubs** | Real-time streaming (tương tự Kafka) |
| **Azure Synapse** | Analytics workspace |
| **Key Vault** | Quản lý secrets & keys |
| **Azure DevOps** | CI/CD pipelines |

**🟢 GCP**

| Dịch vụ | Vai trò trong Data Engineering |
| :--- | :--- |
| **GCS** | Cloud storage |
| **BigQuery** | Serverless data warehouse |
| **Dataflow** | Stream/batch processing (Apache Beam) |
| **Pub/Sub** | Messaging & streaming |
| **Cloud Composer** | Managed Airflow |
| **Dataproc** | Managed Spark/Hadoop |

#### 📚 Kiến thức chung (Cross-cloud)

- **Networking cơ bản**: VPC, Subnets, Security Groups/Firewall
- **IAM & RBAC**: Quản lý quyền truy cập trên cloud
- **Infrastructure as Code**: Terraform cơ bản (tạo S3 bucket, IAM role)
- **Cost Management**: Billing alerts, reserved instances, spot instances

#### 🛠️ Thực hành

- [ ] Tạo tài khoản AWS Free Tier hoặc Azure Free Account
- [ ] Thiết lập S3 bucket / ADLS Gen2 làm Data Lake
- [ ] Cấu hình IAM roles cho Snowflake external stage (Storage Integration)
- [ ] Tạo Lambda/Azure Function đơn giản trigger khi có file mới upload
- [ ] Viết Terraform script tạo S3 bucket + IAM policy
- [ ] Kết nối Snowflake với cloud storage (External Stage + Storage Integration)

#### 🏅 Chứng chỉ khuyến nghị

- **AWS**: AWS Certified Cloud Practitioner → AWS Certified Data Engineer - Associate
- **Azure**: AZ-900 (Fundamentals) → DP-203 (Data Engineering)
- **GCP**: Google Cloud Digital Leader → Professional Data Engineer

---

### 🔷 Giai Đoạn 4: Python & Công Cụ ETL/ELT (Tuần 11–14)

> *Python là ngôn ngữ keo dán của Data Engineering. Kết hợp với các công cụ ETL/ELT để xây dựng pipeline chuyên nghiệp.*

#### 📚 Python cho Data Engineering

- **Cơ bản nâng cao**:
  - File I/O: đọc/ghi CSV, JSON, Parquet
  - Error handling & logging best practices
  - Virtual environments (`venv`, `poetry`, `uv`)
  - Type hints & code quality (`mypy`, `ruff`)

- **Thư viện quan trọng**:
  - `pandas` — xử lý dữ liệu dạng bảng
  - `requests` / `httpx` — gọi REST APIs
  - `snowflake-connector-python` — kết nối Snowflake từ Python
  - `sqlalchemy` — ORM & database abstraction
  - `boto3` — AWS SDK cho Python
  - `azure-storage-blob` — Azure SDK

- **Design Patterns cho Pipeline**:
  - Configuration management (environment variables, config files)
  - Modular pipeline design (extract → transform → load functions)
  - Retry logic & exponential backoff
  - Unit testing với `pytest`

#### 📚 ETL/ELT Tools

**🔸 dbt (Data Build Tool) — Quan trọng nhất**

- dbt Core vs dbt Cloud
- Models & Materializations: `view`, `table`, `incremental`, `ephemeral`
- Sources & Seeds
- Jinja templating & Macros
- Testing: schema tests (`unique`, `not_null`, `relationships`) + custom tests
- Documentation: `dbt docs generate` & `dbt docs serve`
- Packages: `dbt-utils`, `dbt-expectations`
- Adapter: `dbt-snowflake`
- Environments: `dev` / `staging` / `prod`
- CI/CD: `dbt build` trong GitHub Actions

**🔸 Apache Airflow**

- Kiến trúc: Scheduler, Webserver, Workers, Metadata DB
- DAGs (Directed Acyclic Graphs) — định nghĩa workflow
- Operators: `PythonOperator`, `BashOperator`, `SnowflakeOperator`
- Sensors: `S3KeySensor`, `ExternalTaskSensor`
- XComs — truyền dữ liệu giữa các tasks
- Connections & Variables — quản lý credentials
- Best practices: idempotent DAGs, dynamic DAG generation

**🔸 Azure Data Factory (ADF)**

- Pipelines, Activities, Datasets, Linked Services
- Copy Activity — data movement
- Data Flows — visual ETL
- Triggers: Schedule, Tumbling Window, Event-based
- Integration Runtime: Azure IR, Self-hosted IR
- Parameterization & Dynamic content

**🔸 AWS Glue**

- Glue Crawlers & Data Catalog
- Glue ETL Jobs (PySpark)
- Glue Studio — visual ETL
- Bookmarks — incremental processing

#### 🛠️ Thực hành

- [ ] Viết Python script kết nối Snowflake, đọc/ghi dữ liệu bằng `snowflake-connector-python`
- [ ] Xây dựng mini ETL pipeline bằng Python thuần: API → Transform → Load vào Snowflake
- [ ] Cài đặt dbt Core, kết nối Snowflake, xây dựng project với 3 tầng: `staging` → `intermediate` → `marts`
- [ ] Viết dbt tests + macros + documentation
- [ ] Cài đặt Airflow (Docker Compose), tạo DAG điều phối: extract → dbt run → dbt test
- [ ] Tạo ADF pipeline: Copy Activity từ Blob Storage → Snowflake (sử dụng Snowflake Linked Service)
- [ ] Lab thực hành: Xây dựng end-to-end pipeline hoàn chỉnh

#### 📖 Tài liệu tham khảo

- 📘 [dbt Documentation](https://docs.getdbt.com/)
- 📘 [dbt Learn (free courses)](https://learn.getdbt.com/)
- 🎥 [Airflow Tutorial (Astronomer)](https://www.astronomer.io/docs/learn/)
- 📘 [ADF Documentation](https://learn.microsoft.com/en-us/azure/data-factory/)

---

### 🔷 Giai Đoạn 5: Data Streaming & Big Data (Tuần 15–17)

> *Đây là "Nice to have" trong JD nhưng sẽ giúp bạn nổi bật hơn các ứng viên khác.*

#### 📚 Data Streaming

- **Apache Kafka**:
  - Kiến trúc: Brokers, Topics, Partitions, Consumer Groups
  - Producers & Consumers
  - Kafka Connect — kết nối với Snowflake (Snowflake Kafka Connector)
  - Schema Registry & Avro serialization
  - Exactly-once semantics

- **AWS Kinesis**:
  - Kinesis Data Streams vs Kinesis Data Firehose
  - Shard management
  - Kết nối Kinesis → Snowflake (qua Snowpipe Streaming)

- **Azure Event Hubs**:
  - Tương tự Kafka (hỗ trợ Kafka protocol)
  - Capture feature — tự động lưu events vào Blob Storage

- **Snowflake Streaming**:
  - Snowpipe Streaming API — low-latency ingestion
  - Kafka Connector cho Snowflake

#### 📚 Big Data Tools

- **Apache Spark** (cơ bản):
  - Kiến trúc: Driver, Executors, Partitions
  - RDD vs DataFrame vs Dataset
  - Transformations (lazy) vs Actions
  - PySpark cơ bản: đọc/ghi Parquet, filter, join, aggregate
  - Spark SQL
  - Kết nối Spark với Snowflake (Spark Connector)

- **Hadoop Ecosystem** (khái niệm):
  - HDFS — distributed file system
  - YARN — resource management
  - Hive — SQL-on-Hadoop
  - *Lưu ý: Hadoop đang dần được thay thế bởi cloud-native solutions*

#### 🛠️ Thực hành

- [ ] Chạy Kafka locally (Docker), tạo producer/consumer đơn giản
- [ ] Cấu hình Kafka Connect Snowflake Sink Connector
- [ ] Viết PySpark job đọc CSV → transform → ghi Parquet
- [ ] Kết nối PySpark với Snowflake bằng Spark Connector
- [ ] Lab: Xây dựng streaming pipeline: Kafka → Snowpipe Streaming → Snowflake

#### 📖 Tài liệu tham khảo

- 🎥 [Kafka Tutorial (Confluent)](https://developer.confluent.io/get-started/)
- 📘 [Spark Documentation](https://spark.apache.org/docs/latest/)
- 📘 [Snowflake Kafka Connector](https://docs.snowflake.com/en/user-guide/kafka-connector)

---

### 🔷 Giai Đoạn 6: Kỹ Năng Mềm, Quy Trình & Chứng Chỉ (Tuần 18–20)

> *FPT Software là môi trường quốc tế. Tiếng Anh tốt + làm việc Agile là yêu cầu bắt buộc.*

#### 📚 Tiếng Anh Chuyên Ngành

- **Technical Writing**: Viết documentation, email, Jira tickets bằng tiếng Anh
- **Speaking**: Tham gia daily standup, sprint review bằng tiếng Anh
- **Reading**: Đọc hiểu technical docs, error messages, Stack Overflow
- **Từ vựng chuyên ngành**: pipeline, ingestion, throughput, latency, schema drift, data lineage, idempotent, orchestration, partitioning, pruning

#### 📚 Agile/Scrum

- Các ceremony: Daily Standup, Sprint Planning, Sprint Review, Retrospective
- User Stories & Acceptance Criteria
- Estimation: Story Points, Planning Poker
- Tools: Jira, Confluence
- Definition of Done (DoD) cho data tasks

#### 📚 Data Governance & Best Practices

- Data Quality dimensions: Completeness, Accuracy, Consistency, Timeliness
- Data Lineage — theo dõi nguồn gốc dữ liệu
- Data Catalog — tổ chức metadata
- Security: Encryption at rest / in transit, PII masking
- Version control: Git branching strategy (GitFlow / Trunk-based)
- Code review best practices

#### 🛠️ Thực hành

- [ ] Viết 1 bài blog kỹ thuật bằng tiếng Anh (Medium / Dev.to)
- [ ] Tham gia 1 dự án open source nhỏ trên GitHub (contribute docs hoặc fix bug)
- [ ] Thiết lập Jira board mô phỏng 1 sprint với data engineering tasks
- [ ] Tạo Git repo với branching strategy, PR template, và CI/CD (GitHub Actions)
- [ ] Luyện mock interview bằng tiếng Anh (câu hỏi kỹ thuật + behavioral)

#### 🏅 Lộ trình chứng chỉ đề xuất

| Thứ tự | Chứng chỉ | Lý do |
| :---: | :--- | :--- |
| 1️⃣ | **SnowPro Core (COF-C02)** | Chứng minh năng lực Snowflake — yêu cầu số 1 của JD |
| 2️⃣ | **AWS Cloud Practitioner** hoặc **AZ-900** | Nền tảng cloud cơ bản |
| 3️⃣ | **dbt Analytics Engineering Certification** | Modern data stack |
| 4️⃣ | **AWS Data Engineer Associate** hoặc **DP-203** | Cloud data engineering chuyên sâu |
| 5️⃣ | **SnowPro Advanced: Data Engineer** | Snowflake nâng cao (mục tiêu dài hạn) |

---

## 📊 Tổng Quan Timeline

```
Tuần 1─3    ███████████░░░░░░░░░░░░░░░░░░░  GĐ 1: SQL & Data Modeling
Tuần 4─7    ░░░░░░░████████████████░░░░░░░  GĐ 2: Snowflake ⭐ TRỌNG TÂM
Tuần 8─10   ░░░░░░░░░░░░░░░░░████████░░░░  GĐ 3: Cloud Platform
Tuần 11─14  ░░░░░░░░░░░░░░░░░░░░░████████  GĐ 4: Python & ETL/ELT Tools
Tuần 15─17  ░░░░░░░░░░░░░░░░░░░░░░░░█████  GĐ 5: Streaming & Big Data
Tuần 18─20  ░░░░░░░░░░░░░░░░░░░░░░░░░░███  GĐ 6: Soft Skills & Certs
```

> [!TIP]
> **Giai đoạn 2 (Snowflake)** và **Giai đoạn 4 (ETL/ELT)** là hai phần quan trọng nhất. Dành ít nhất 60% thời gian thực hành cho hai giai đoạn này.

---

## 🎯 Dự Án Capstone — End-to-End Data Pipeline

Sau khi hoàn thành 6 giai đoạn, xây dựng **1 dự án tổng hợp** để trình bày trong phỏng vấn:

### Đề bài gợi ý: "E-Commerce Analytics Platform"

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Data Sources │    │   Ingestion  │    │  Snowflake   │    │  Analytics   │
│              │    │              │    │  Warehouse   │    │              │
│ • REST API   │───▶│ • Python     │───▶│              │───▶│ • Dashboard  │
│ • CSV files  │    │ • Snowpipe   │    │ RAW → STG →  │    │   (Metabase) │
│ • Database   │    │ • ADF/Glue   │    │ ANALYTICS    │    │              │
│ • Kafka      │    │              │    │              │    │ • Reports    │
└──────────────┘    └──────────────┘    │ dbt models   │    └──────────────┘
                                        │ + tests      │
                                        └──────────────┘
                                              │
                                    ┌─────────┴─────────┐
                                    │   Orchestration    │
                                    │   (Airflow DAGs)   │
                                    └────────────────────┘
```

**Yêu cầu dự án:**
1. **Ingestion**: Thu thập dữ liệu từ ít nhất 2 nguồn (API + file/database)
2. **Storage**: Load vào Snowflake qua External Stage + Snowpipe
3. **Transformation**: dbt project với staging → intermediate → marts layers
4. **Quality**: dbt tests + data freshness checks
5. **Orchestration**: Airflow DAG điều phối toàn bộ pipeline
6. **Monitoring**: Alerting khi pipeline fail
7. **Documentation**: README + dbt docs + ERD diagram
8. **Version Control**: Git repo với CI/CD (GitHub Actions chạy `dbt build`)

---

## ✅ Checklist Tự Đánh Giá Trước Phỏng Vấn

| # | Câu hỏi tự kiểm tra | Trả lời được? |
| :---: | :--- | :---: |
| 1 | Giải thích sự khác biệt giữa Star Schema và Snowflake Schema? | ☐ |
| 2 | Kiến trúc 3 lớp của Snowflake là gì? Tại sao tách Storage & Compute? | ☐ |
| 3 | Clustering Key trong Snowflake hoạt động thế nào? Khi nào cần dùng? | ☐ |
| 4 | Phân biệt Snowpipe và Snowpipe Streaming? | ☐ |
| 5 | dbt incremental model hoạt động thế nào? Khi nào dùng `merge` vs `delete+insert`? | ☐ |
| 6 | Airflow DAG là gì? Giải thích idempotency trong DAG design? | ☐ |
| 7 | Giải thích ETL vs ELT? Tại sao ELT phù hợp hơn với Snowflake? | ☐ |
| 8 | Time Travel trong Snowflake dùng để làm gì? Giới hạn bao nhiêu ngày? | ☐ |
| 9 | Làm thế nào để tối ưu chi phí Virtual Warehouse trong Snowflake? | ☐ |
| 10 | Bạn xử lý schema drift (thay đổi cấu trúc dữ liệu nguồn) như thế nào? | ☐ |
| 11 | Giải thích Kafka Partition và Consumer Group? | ☐ |
| 12 | Làm thế nào để đảm bảo Data Quality trong pipeline? | ☐ |

---

## 📚 Tài Nguyên Học Tập Tổng Hợp

### Khóa học miễn phí
- 🎓 [Snowflake University](https://learn.snowflake.com/) — Tất cả khóa học chính thức
- 🎓 [dbt Learn](https://learn.getdbt.com/) — dbt Fundamentals (miễn phí)
- 🎓 [Astronomer Academy](https://www.astronomer.io/docs/learn/) — Airflow tutorials
- 🎓 [AWS Skill Builder](https://skillbuilder.aws/) — AWS training miễn phí

### Sách
- 📘 *The Data Warehouse Toolkit* — Ralph Kimball
- 📘 *Fundamentals of Data Engineering* — Joe Reis & Matt Housley
- 📘 *Data Pipelines Pocket Reference* — James Densmore

### Cộng đồng
- 💬 [Snowflake Community](https://community.snowflake.com/)
- 💬 [dbt Community Slack](https://www.getdbt.com/community/)
- 💬 [r/dataengineering](https://www.reddit.com/r/dataengineering/)
- 💬 [Data Engineering Vietnam (Facebook)](https://www.facebook.com/groups/dataengineeringvietnam)

### YouTube Channels
- 🎥 [Snowflake](https://www.youtube.com/@SnowflakeInc)
- 🎥 [Seattle Data Guy](https://www.youtube.com/@SeattleDataGuy)
- 🎥 [Darshil Parmar](https://www.youtube.com/@DarshilParmar)
- 🎥 [Andreas Kretz](https://www.youtube.com/@andreaskayy)

---

> [!IMPORTANT]
> **Chiến lược học hiệu quả nhất**: Không cần học hết lý thuyết rồi mới thực hành. Hãy áp dụng nguyên tắc **70/30** — 70% thời gian thực hành trên Snowflake Trial + Cloud Free Tier, 30% đọc docs và xem video. Mỗi giai đoạn nên kết thúc bằng một mini-project có thể demo được.

> [!TIP]
> **Mẹo phỏng vấn FPT Software**: Chuẩn bị ít nhất 2 câu chuyện thực tế (STAR method) về cách bạn giải quyết vấn đề data pipeline (lỗi, performance, data quality). Interviewer thường hỏi "Tell me about a time when..." bằng tiếng Anh.
