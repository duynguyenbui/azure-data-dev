# Hướng dẫn Lab 02: Getting Started với Azure Synapse Analytics

> [!NOTE]
> Bài lab này sẽ hướng dẫn bạn toàn bộ quy trình từ lúc tự tay khởi tạo Azure Data Lake Gen2, Synapse Workspace, khám phá Synapse Studio, sử dụng Serverless SQL Pool để truy vấn dữ liệu trực tiếp, cho đến tạo một Data Pipeline nâng cao với IAM.

## Mục tiêu bài Lab
- Khởi tạo Azure Data Lake Storage Gen2 (kích hoạt Hierarchical namespace).
- Khởi tạo Azure Synapse Workspace.
- Làm quen với giao diện Azure Synapse Studio.
- Sử dụng **Serverless SQL Pool** để khám phá dữ liệu (Data Exploration) mà không cần cấu hình server.
- Tạo một **Synapse Pipeline** để tích hợp dữ liệu bằng chuẩn kết nối bảo mật (IAM / Managed Identity).

## Điều kiện tiên quyết
- Có một tài khoản Microsoft Azure (có thể sử dụng Free trial hoặc Pay-as-you-go).

---

## Bước 1: Khởi tạo Storage Account (Azure Data Lake Gen2)

Trước tiên, bạn cần chuẩn bị một kho lưu trữ Data Lake Gen2. Đây sẽ là "ổ cứng" mặc định cho hệ thống Synapse của bạn sau này.

1. Đăng nhập vào [Azure Portal](https://portal.azure.com/).
2. Ở thanh tìm kiếm, gõ **Storage accounts** và chọn nó.
3. Click nút **+ Create** để tạo tài khoản mới.
4. Tại tab **Basics**, điền thông tin:
   - **Resource group:** Click *Create new*, đặt tên `rg-synapse-lab`.
   - **Storage account name:** Viết liền không dấu, phải là duy nhất (ví dụ: `adlsdlvn2026`).
   - **Region:** Chọn khu vực gần bạn (ví dụ: *Southeast Asia*).
5. Chuyển sang tab **Advanced** (đây là bước quan trọng nhất):
   - Tìm mục **Data Lake Storage Gen2** và đánh dấu tick vào **Enable hierarchical namespace**. Bước này biến một Blob Storage thông thường thành một Data Lake Gen2 thực thụ.
6. Click **Review + create** -> Đợi báo *Validation passed* -> Click **Create**.
7. Đợi khoảng 1 phút để tạo xong, click **Go to resource**.
8. Trong trang quản lý Storage Account vừa tạo, nhìn menu bên trái chọn **Containers** (dưới mục Data storage). Click **+ Container**, đặt tên là `users` rồi nhấn **Create**.

---

## Bước 2: Khởi tạo (Provision) Azure Synapse Workspace

Sau khi đã có Data Lake, bước tiếp theo là tạo bộ máy Synapse Analytics và gắn nó với Data Lake vừa tạo.

1. Trên thanh tìm kiếm Azure Portal, gõ **Azure Synapse Analytics** và chọn nó.
2. Click nút **+ Create** (Tạo mới).
3. Ở tab **Basics**, điền các thông tin sau:
   - **Subscription:** Chọn gói đăng ký Azure của bạn.
   - **Resource group:** Chọn lại `rg-synapse-lab` đã tạo ở bước 1.
   - **Workspace name:** Đặt tên workspace (duy nhất, ví dụ: `synapse-lab-vn-2026`).
   - **Region:** Chọn cùng khu vực với Storage (ví dụ: *Southeast Asia*).
   - **Select Data Lake Storage Gen 2:** 
     - *Account name:* **Chọn từ danh sách thả xuống** cái tên Storage Account bạn vừa tạo ở Bước 1 (`adlsdlvn2026`).
     - *File system name:* Chọn container `users` bạn đã tạo.
   - **ĐẶC BIỆT QUAN TRỌNG:** Đánh dấu tick vào ô *"Assign myself the Storage Blob Data Contributor role on the Data Lake Storage Gen2 account"*. Nếu quên tick, bạn sẽ không thể mở Data Lake sau này.
4. Chuyển sang tab **Security** (ngay cạnh tab Basics):
   - Tại mục Authentication, nhập tài khoản vào **SQL Server admin login** (ví dụ: `sqladminuser`) và thiết lập **Password** (bạn có thể dùng `AzureData@2026!`). *(Lưu ý: Hãy ghi nhớ kỹ tài khoản và mật khẩu này để kết nối Synapse từ công cụ bên ngoài sau này).*
   - Tại mục *System assigned managed identity permission*, ô *Allow network access to Data Lake Storage Gen2 account* có thể không cần tick do Storage của bạn đã được cấu hình Public access ở Bước 1.
5. Click nút **Review + create** ở dưới cùng. Đợi hệ thống báo *Validation passed* rồi click **Create**.
6. Đợi 3-5 phút cho đến khi báo *Your deployment is complete*, click **Go to resource** để đi tới Workspace của bạn.

---

## Bước 3: Khám phá Azure Synapse Studio

Azure Synapse Studio là trung tâm điều khiển (workspace) hợp nhất dành cho data preparation, data management, data exploration và data warehousing.

1. Trong trang quản lý resource của **Azure Synapse workspace**, tìm phần *Overview* và click vào nút **Open Synapse Studio**.
2. Bạn sẽ thấy menu bên trái với các Hub chức năng chính:
   - **Data:** Quản lý cơ sở dữ liệu nội bộ (SQL, Spark) và kết nối với dữ liệu bên ngoài (Linked data như Data Lake).
   - **Develop:** Không gian làm việc chứa các SQL script, Notebooks, Data flows, và Power BI reports.
   - **Integrate:** Nơi xây dựng và quản lý các Pipelines (tương tự như giao diện của Azure Data Factory).
   - **Monitor:** Theo dõi quá trình chạy của pipelines, SQL requests, Spark applications và Integration Runtimes.
   - **Manage:** Quản trị cấu hình workspace, phân quyền bảo mật, Linked Services, và Integration Runtimes.

---

## Bước 4: Truy vấn dữ liệu trên Data Lake bằng Serverless SQL Pool

Serverless SQL Pool là tính năng đặc biệt của Synapse cho phép bạn query trực tiếp dữ liệu dạng file (Parquet, CSV, JSON) nằm trên Data Lake bằng ngôn ngữ T-SQL mà không cần phải load dữ liệu vào database (ETL). Bạn chỉ trả tiền cho lượng dữ liệu được quét.

Chúng ta sẽ sử dụng bộ dữ liệu mẫu NYC Taxi (dữ liệu mở do Azure cung cấp) để thực hành.

1. Mở Synapse Studio, chuyển sang Hub **Develop** ở menu bên trái.
2. Click vào biểu tượng dấu **+** và chọn **SQL script**.
3. Ở thanh công cụ phía trên cùng của Script, đảm bảo mục *Connect to* đang được chọn là **Built-in** (đây chính là Serverless SQL pool mặc định).
4. Dán đoạn mã T-SQL sau vào trình soạn thảo:

```sql
-- Truy vấn 100 chuyến xe taxi đầu tiên từ tập dữ liệu mở Parquet
SELECT
    TOP 100 *
FROM
    OPENROWSET(
        BULK 'https://azureopendatastorage.blob.core.windows.net/nyctlc/yellow/puYear=2019/puMonth=*/*.parquet',
        FORMAT='PARQUET'
    ) AS [nyc_taxi_data]
```

5. Nhấn nút **Run** (biểu tượng mũi tên).
6. **Kết quả:** Sau vài giây, bạn sẽ thấy dữ liệu hiển thị ở dạng bảng lưới (Table) ngay phía dưới trình soạn thảo.

> [!TIP]
> Bạn có thể click vào nút **Chart** ở góc bên phải của khung kết quả để tạo các biểu đồ trực quan nhanh (Bar chart, Line chart, v.v.) ngay trên Synapse Studio để phân tích nhanh xu hướng dữ liệu.

---

## Bước 5: Lấy dữ liệu nâng cao (Sử dụng Advanced Connect / IAM)

Trong thực tế, bạn sẽ lấy dữ liệu từ các nguồn bảo mật nội bộ (như tài khoản Data Lake khác hoặc Azure SQL Database). Để bảo mật, thay vì dùng password, ta sẽ thiết lập **IAM (Managed Identity)** của chính Synapse Workspace để xác thực (Advanced Connect).

### 5.1: Cấu hình IAM trên Azure Portal
Synapse cần được cấp quyền (Role) để đọc dữ liệu từ nguồn:
1. Mở [Azure Portal](https://portal.azure.com/), truy cập vào **Azure Data Lake Storage Gen2** chứa dữ liệu nguồn.
2. Ở menu bên trái, chọn **Access control (IAM)**.
3. Click **+ Add** -> **Add role assignment**.
4. Chọn role **Storage Blob Data Reader** (hoặc Contributor) -> **Next**.
5. Ở mục *Assign access to*, chọn **Managed identity**.
6. Click **+ Select members**, tìm chọn Subscription của bạn, chọn loại **Synapse workspace**, và click vào tên Workspace của bạn -> **Select** -> **Review + assign**.
*(Workspace của bạn giờ đã có quyền truy cập vào Data Lake).*

### 5.2: Tạo Linked Service an toàn (Advanced Connect)
1. Trong **Synapse Studio**, chuyển sang Hub **Manage** -> mục **Linked services**.
2. Click **+ New**, chọn **Azure Data Lake Storage Gen2** -> **Continue**.
3. Cấu hình kết nối nâng cao:
   - **Name:** `ADLS_Source_ManagedIdentity`
   - **Authentication method:** Bắt buộc chọn **System Assigned Managed Identity**. Đây chính là tính năng kết nối bảo mật nhất.
   - Chọn Subscription và tài khoản Storage nguồn.
4. Click **Test connection**. Nếu hiện *Connection successful*, click **Create**.

### 5.3: Tạo Pipeline lấy dữ liệu
1. Chuyển sang Hub **Integrate**, click dấu **+** -> **Pipeline**. Đặt tên pipeline ở bên phải là `Ingest_Secure_Data`.
2. Gõ tìm **Copy data** trong mục Activities và kéo thả vào canvas.
3. Cấu hình activity:
   - **Source:** Click **+ New** tạo dataset -> chọn Storage Gen2 -> Format (CSV/Parquet). Ở mục *Linked service*, chọn `ADLS_Source_ManagedIdentity`. Duyệt chọn file/folder bạn muốn lấy.
   - **Sink:** Click **+ New** tạo dataset trỏ tới Data Lake mặc định của workspace hiện tại, chọn folder lưu (ví dụ: `raw-zone`).
4. Nhấn **Debug** để chạy thử. Synapse sẽ dùng danh tính IAM của chính nó để tải dữ liệu về một cách an toàn. Kiểm tra kết quả tại Hub **Monitor**!

---

## Bước 6: Dọn dẹp tài nguyên (Clean up resources)

> [!CAUTION]
> Azure Synapse Analytics, đặc biệt là tính năng **Dedicated SQL Pool** (kho dữ liệu truyền thống) và **Apache Spark Pool**, được tính phí theo giờ và có thể phát sinh chi phí lớn nếu bạn quên tắt.

1. **Serverless SQL Pool (Built-in):** Bạn không cần phải tạm dừng (pause) vì tính năng này hoàn toàn Serverless, bạn chỉ bị tính phí khi bấm nút `Run` query (dựa trên dung lượng TB processed).
2. **Dedicated SQL Pool / Spark Pool:** Nếu bạn có tạo thêm các pool này trong mục *Manage* -> *SQL/Spark pools*, hãy chắc chắn rằng bạn đã nhấn nút **Pause** sau khi thực hành xong.
3. Nếu bạn đã hoàn toàn học xong bài lab và không có ý định sử dụng lại, cách tốt nhất là truy cập Azure Portal và **Xóa toàn bộ Resource Group** (`rg-synapse-lab`) chứa Synapse workspace và Data Lake để tránh mọi chi phí ẩn phát sinh.

## Kết luận
Chúc mừng! Bạn đã hoàn thành các tác vụ cốt lõi nhất đối với một kỹ sư dữ liệu trên nền tảng Azure Synapse Analytics:
- Tự tay tạo Data Lake Gen2 và khởi tạo Data Platform.
- Làm quen với kiến trúc giao diện các Hub của Synapse Studio.
- Sử dụng T-SQL hiện đại để truy vấn dữ liệu Big Data (Parquet) trực tiếp từ Data Lake bằng Serverless SQL Pool.
- Thiết kế một Pipeline tích hợp dữ liệu cơ bản nhưng chuẩn bảo mật cấp độ doanh nghiệp (Managed Identity).
