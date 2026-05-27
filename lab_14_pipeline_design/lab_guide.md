# Hướng dẫn Lab 14: Nguyên Lý Thiết Kế Data Pipeline (Idempotency, CDC/Merge và Schema Evolution)

> **Mức độ**: Intermediate/Advanced
> **Thời gian ước tính**: 1.5 - 2 giờ
> **Công nghệ**: Azure Storage (ADLS Gen2), Azure Databricks, PySpark, Delta Lake.

---

## 📖 Bối cảnh lý thuyết (Theory & Principles)

Khi thiết kế một **Data Pipeline** trong môi trường doanh nghiệp, kỹ sư dữ liệu không chỉ đơn thuần kéo thả hay viết code để chuyển dữ liệu từ A sang B. Bạn phải đối mặt với các bài toán thực tế phức tạp:
1.  **Mất mạng hoặc crash giữa chừng**: Pipeline đang chạy nửa chừng thì sập. Khi khởi động lại, làm sao để không ghi trùng dữ liệu cũ?
2.  **Gửi trùng file**: Hệ thống nguồn gửi một file dữ liệu 2 lần do lỗi logic của họ. Pipeline của bạn có tự động nhận diện và loại bỏ trùng lặp?
3.  **Thay đổi trạng thái dữ liệu (CDC - Change Data Capture)**: Bản ghi hôm nay cập nhật trạng thái mới (ví dụ đơn hàng chuyển từ `Pending` sang `Shipped`). Làm sao để cập nhật dòng cũ trên Data Warehouse thay vì chèn thêm dòng mới?
4.  **Trôi lệch cấu trúc dữ liệu (Schema Drift)**: Hôm nay hệ thống nguồn thêm một cột mới vào file JSON mà không báo trước. Pipeline sẽ sập hay tự thích ứng?

Bài lab này sẽ hướng dẫn bạn giải quyết triệt để 3 bài toán trên thông qua việc thiết kế một **Idempotent Data Pipeline** sử dụng **Delta Lake** trên **Azure Databricks**.

### Các khái niệm cốt lõi cần nắm:
*   **Idempotency (Tính bất biến/Nhất quán)**: Là tính chất mà khi một pipeline chạy một lần hay nhiều lần với cùng một dữ liệu đầu vào, kết quả lưu trữ ở bảng đích vẫn không thay đổi (không sinh ra dòng trùng lặp, không sai lệch tổng số tiền).
*   **Audit Columns (Cột kiểm toán)**: Các cột kỹ thuật như `_created_at`, `_updated_at`, `_source_file` được chèn vào bảng đích để hỗ trợ việc truy vết nguồn gốc (Data Lineage) và sửa lỗi (Debugging).
*   **Schema Enforcement (Bắt buộc cấu trúc)**: Tính năng an toàn của Delta Lake, tự động ngăn chặn việc ghi đè/chèn dữ liệu có cấu trúc khác với cấu trúc bảng hiện tại để tránh làm hỏng bảng dữ liệu.
*   **Schema Evolution (Tiến hóa cấu trúc)**: Khả năng tự động thay đổi cấu trúc bảng đích (thêm cột mới) một cách an toàn mà không cần dựng lại bảng từ đầu.

---

## 🏷️ Tên tài nguyên chuẩn (Resource Naming Convention)

Sử dụng đúng các tên dưới đây khi tạo tài nguyên trên Azure Portal để đảm bảo code hoạt động ngay mà không cần sửa đổi.

| Phân loại | Tài nguyên Azure | Tên đặt sẵn (Copy & Paste) | Mục đích sử dụng |
|---|---|---|---|
| **Quản lý chung** | Resource Group | `rg-pipelinedesign-lab-dev` | Nhóm chứa toàn bộ tài nguyên của Lab 14 |
| **Lưu trữ (Storage)** | Storage Account (ADLS Gen2) | `dlspipelinedesignlab001` *(Thêm số đuôi nếu bị trùng)* | Lưu trữ dữ liệu thô (Landing) và Delta Table (Silver) |
| **Lưu trữ (Container)**| Blob Container | `pipeline-design-lab` | Container chính để lưu trữ dữ liệu của Lab |
| **Tính toán (Compute)**| Databricks Workspace | `dbw-pipelinedesign-lab-dev` | Môi trường chạy notebook PySpark/SQL |

---

## 🛠️ Phase 1: Tạo Hạ tầng trên Azure Portal (Click-by-click)

### Bước 1: Tạo Resource Group
1. Đăng nhập [Azure Portal](https://portal.azure.com/).
2. Tìm kiếm **Resource groups** -> Bấm **+ Create**.
   - **Resource group**: `rg-pipelinedesign-lab-dev`
   - **Region**: Chọn `Southeast Asia`.
3. Bấm **Review + create** -> **Create**.

### Bước 2: Tạo Storage Account (ADLS Gen2)
1. Tìm kiếm **Storage accounts** -> Bấm **+ Create**.
2. Thiết lập thông tin:
   - **Resource group**: Chọn `rg-pipelinedesign-lab-dev`.
   - **Storage account name**: `dlspipelinedesignlab001` *(Nếu báo trùng tên, thêm số vào sau ví dụ: `dlspipelinedesignlab002`).*
   - **Region**: `Southeast Asia`.
3. Chọn tab **Advanced** -> Cuộn xuống mục **Data Lake Storage Gen2** -> Tích chọn **Enable hierarchical namespace**. (Đây là bước quyết định để chuyển đổi từ Blob Storage thông thường sang Azure Data Lake Storage Gen2).
4. Bấm **Review + create** -> Bấm **Create**. Chờ khoảng 1-2 phút cho đến khi hoàn thành.
5. Truy cập vào Storage Account vừa tạo, ở menu trái mục **Data storage**, bấm **Containers** -> Bấm **+ Container** -> Tạo container tên là `pipeline-design-lab`.

### Bước 3: Tạo Azure Databricks Workspace
1. Trên thanh tìm kiếm Azure Portal, gõ **Azure Databricks** -> Bấm **+ Create**.
2. Cấu hình thông tin:
   - **Resource group**: `rg-pipelinedesign-lab-dev`.
   - **Workspace name**: `dbw-pipelinedesign-lab-dev`.
   - **Region**: `Southeast Asia`.
   - **Pricing Tier**: **Premium** (hoặc Standard đều được cho bài lab này).
3. Bấm **Review + create** -> Bấm **Create**. Quá trình khởi tạo Databricks sẽ mất khoảng 3-5 phút.

---

## 🐍 Phase 2: Giả lập và Tải dữ liệu nguồn lên Data Lake

Chúng ta cần có dữ liệu mô phỏng các lỗi thực tế trong pipeline. Chúng ta sẽ chạy script Python có sẵn để sinh ra 4 file JSON đại diện cho 4 lô dữ liệu (batches).

### Bước 1: Chạy Python Data Generator
1. Mở Terminal/CMD trên máy của bạn và di chuyển tới thư mục của project.
2. Chạy lệnh sau để sinh dữ liệu thô:
   ```bash
   python lab_14_pipeline_design/scripts/data_generator.py
   ```
3. Script sẽ tự tạo thư mục `lab_14_pipeline_design/data/` chứa 4 file JSON:
   *   `batch_1_initial.json`: Danh sách 5 đơn hàng đầu tiên.
   *   `batch_2_duplicates.json`: Chứa 2 đơn hàng mới và **2 đơn hàng bị trùng lặp y hệt** từ Batch 1 (để kiểm tra tính Idempotent).
   *   `batch_3_updates.json`: Chứa dữ liệu **cập nhật trạng thái đơn hàng** (Change Data Capture) của các đơn hàng cũ (ví dụ: chuyển trạng thái từ `Pending` sang `Delivered`), kèm 1 đơn hàng mới.
   *   `batch_4_schema_drift.json`: Chứa đơn hàng mới nhưng có **thêm cột mới** tên là `discount_applied` (báo hiệu sự trôi lệch cấu trúc dữ liệu - Schema Drift).

### Bước 2: Tải dữ liệu lên Azure Storage Account
1. Trở lại Azure Portal, vào Storage Account `dlspipelinedesignlab001` -> chọn **Containers** -> truy cập vào `pipeline-design-lab`.
2. Bấm nút **+ Add Directory** để tạo một thư mục ảo tên là `landing`.
3. Nhấp đúp chuột để vào thư mục `landing` vừa tạo.
4. Bấm **Upload** -> Chọn và tải cả 4 file JSON vừa tạo ở Bước 1 lên đây.

Đường dẫn lưu trữ trên đám mây của dữ liệu nguồn lúc này sẽ là:
`abfss://pipeline-design-lab@dlspipelinedesignlab001.dfs.core.windows.net/landing/`

---

## ⚡ Phase 3: Thực hiện Pipeline trên Databricks Notebook

### Bước 1: Khởi động Compute Cluster
1. Truy cập vào Databricks Workspace vừa tạo bằng cách bấm **Launch Workspace**.
2. Ở menu trái chọn **Compute** -> Bấm **Create compute**.
   - **Compute name**: `pipeline-cluster`.
   - **Access mode**: `Single user` (hoặc Shared).
   - **Runtime version**: `14.3 LTS (Scala 2.12, Spark 3.5.0)` hoặc mới hơn.
   - Chọn **Single Node** (để tiết kiệm chi phí làm lab).
3. Bấm **Create compute** và đợi khoảng 3 phút cho cluster chuyển sang trạng thái tích xanh lá.

### Bước 2: Tạo Storage Credential & External Location (Unity Catalog)
Để Databricks có quyền đọc/ghi vào Storage Account một cách an toàn:
1. Tạo một **Access Connector for Azure Databricks** trên Azure Portal tên là `dbac-pipelinedesign-lab-dev` nằm ở Resource Group `rg-pipelinedesign-lab-dev`.
2. Phân quyền cho Access Connector này trên Storage Account `dlspipelinedesignlab001` với vai trò là **Storage Blob Data Contributor** (trong mục Access Control IAM).
3. Trong Databricks Workspace, chọn **Catalog** -> **Storage credentials** -> **Create credential** (dán Resource ID của Access Connector vào).
4. Chọn **External locations** -> **Create location** -> Đặt tên `ext_pipeline_design` -> Điền URL là `abfss://pipeline-design-lab@dlspipelinedesignlab001.dfs.core.windows.net/` và chọn storage credential vừa tạo ở trên.

*(Bước này đã được học chi tiết ở bài Lab 13).*

### Bước 3: Import Notebook và Thực hành từng bước
1. Tại menu trái Databricks, chọn **Workspace** -> chọn thư mục User của bạn -> Bấm **Create** -> **Notebook**.
2. Bạn có thể copy nội dung từ file code mẫu [Idempotent_Pipeline.py](file:///Users/nguyenbui/Projects/sql-developer/lab_14_pipeline_design/notebooks/Idempotent_Pipeline.py) và dán trực tiếp vào các Cell của Notebook mới tạo.
3. Chạy từng Cell theo hướng dẫn dưới đây để quan sát hành vi của pipeline:

---

### Phân tích chi tiết các bước trong Notebook:

#### 1. Phase 1: Ingest thô bằng phương pháp `append` thông thường (Không có tính Idempotent)
Ở **Cell 2 & 3**, chúng ta đọc Batch 1 rồi ghi vào bảng Delta, sau đó đọc Batch 2 (chứa bản ghi trùng) và trực tiếp append vào bảng.

Khi chạy truy vấn SQL ở **Cell 4**:
```sql
SELECT order_id, COUNT(*) as count
FROM orders_naive
GROUP BY order_id
HAVING count > 1;
```
Bạn sẽ thấy kết quả trả về các đơn hàng `ORD004` và `ORD005` có số lượng là `2`. Điều này chứng tỏ **pipeline bị trùng lặp dữ liệu**, gây sai lệch các báo cáo doanh thu nếu chạy lại file cũ.

---

#### 2. Phase 2: Đảm bảo tính Idempotency bằng câu lệnh `MERGE` (Upsert)
Chúng ta tiến hành xóa bảng cũ để làm lại từ đầu (**Cell 5**). Ở **Cell 6**, chúng ta viết hàm `ingest_batch_idempotent(file_path)` có cấu trúc như sau:
1.  **Thêm các cột Audit**:
    ```python
    df_transformed = df_raw \
        .withColumn("_created_at", current_timestamp()) \
        .withColumn("_updated_at", current_timestamp()) \
        .withColumn("_source_file", input_file_name())
    ```
2.  **Sử dụng Delta `MERGE`**:
    Nếu bảng chưa tồn tại, ta ghi đè để khởi tạo bảng. Nếu bảng đã có dữ liệu, ta dùng lệnh `merge` dựa trên khóa chính `order_id`:
    *   **Khi khớp khóa (`whenMatchedUpdate`)**: Cập nhật thông tin và ghi đè thời gian sửa đổi `_updated_at`.
    *   **Khi không khớp khóa (`whenNotMatchedInsert`)**: Chèn dòng mới và ghi nhận thời gian tạo `_created_at`.

Chạy **Cell 7** để ingest cả Batch 1 và Batch 2 thông qua hàm này. Sau đó chạy **Cell 8 & 9 (SQL)** để kiểm tra:
*   Bảng chỉ có đúng 7 dòng đơn hàng độc nhất.
*   Không có bất kỳ đơn hàng nào bị trùng lặp.
**=> Pipeline đã đạt tính Idempotent thành công!**

---

#### 3. Phase 3: Cập nhật trạng thái tăng trưởng (CDC)
Trong Batch 3, trạng thái của đơn hàng `ORD002` đổi từ `Processing` sang `Delivered`. 

Chạy **Cell 9** để ingest Batch 3. Nhờ câu lệnh `MERGE` ở trên, Spark sẽ tự động phát hiện `ORD002` đã tồn tại, thực hiện cập nhật cột `status` thành `Delivered` và thay đổi giá trị cột `_updated_at` thành thời điểm hiện tại, trong khi cột `_created_at` vẫn được giữ nguyên để bảo toàn thời gian tạo đơn hàng ban đầu.

---

#### 4. Phase 4: Xử lý Schema Drift (Trôi lệch cấu trúc dữ liệu)
Trong Batch 4, hệ thống nguồn gửi thêm cột `discount_applied`. 

*   **Chạy Cell 10**: Khi cố tình append dữ liệu Batch 4 vào bảng, Spark sẽ lập tức trả về lỗi lỗi cấu trúc:
    `❌ Failed as expected due to Schema Enforcement...`
    Đây là cơ chế bảo vệ của Delta Lake nhằm ngăn chặn dữ liệu bẩn phá hỏng cấu trúc bảng đích.
*   **Chạy Cell 11**: Chúng ta bật tính năng **Schema Evolution** bằng cách thêm tùy chọn `.option("mergeSchema", "true")`.
    ```python
    df_batch_4.write \
        .format("delta") \
        .mode("append") \
        .option("mergeSchema", "true") \
        .save(target_delta_path)
    ```
    Lúc này, Spark ghi nhận thành công và tự động cập nhật schema của Delta Table để bổ sung cột `discount_applied`.
*   **Chạy Cell 12**: Kiểm tra kết quả, các đơn hàng cũ (từ Batch 1-3) tự động nhận giá trị `null` ở cột `discount_applied`, trong khi đơn hàng mới ở Batch 4 hiển thị giá trị đúng (`True` hoặc `False`).

---

## 🧹 Phase 4: Dọn dẹp tài nguyên (RẤT QUAN TRỌNG)

Tránh phát sinh chi phí ngoài ý muốn trên Azure:
1. Vào Azure Databricks -> **Compute** -> Chọn cluster `pipeline-cluster` -> Bấm nút **Terminate** (Stop) để tắt máy chủ ảo.
2. Trở lại Azure Portal -> **Resource groups** -> chọn `rg-pipelinedesign-lab-dev`.
3. Bấm **Delete resource group**, nhập tên để xác nhận xóa sạch toàn bộ tài nguyên (Workspace, Storage Account, Access Connector).
