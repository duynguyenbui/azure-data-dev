# Hiểu SSIS và SSAS Một Cách Đơn Giản

> **Mục tiêu:** Giải thích hai công cụ quan trọng nhất trong hệ sinh thái Microsoft BI bằng ngôn ngữ dễ hiểu nhất, thông qua ví dụ thực tế.

---

## 🏭 Hãy tưởng tượng một Nhà Máy Báo Cáo

Để hiểu toàn bộ hệ thống BI, hãy hình dung như sau:

```
[Nguồn Dữ Liệu]  ---(SSIS)-->  [Kho Dữ Liệu]  ---(SSAS)-->  [Power BI / Excel]
(CRM, ERP, CSV)     (Xe tải)     (Nhà kho)       (Người kho)   (Giám đốc xem)
```

*   **SSIS** = Người lái xe tải, vận chuyển và xử lý hàng hóa từ nhà cung cấp về kho.
*   **Kho dữ liệu (Data Warehouse)** = Nhà kho lưu trữ tất cả hàng hóa.
*   **SSAS** = Người quản lý kho, tổ chức và đóng gói hàng hóa thành các "gói báo cáo" mà giám đốc dễ hiểu.
*   **Power BI** = Màn hình giám đốc dùng để xem số liệu.

---

## 1. SSIS — SQL Server Integration Services

### 🤔 SSIS là gì?

**SSIS là công cụ ETL (Extract - Transform - Load).** Nó chịu trách nhiệm di chuyển dữ liệu từ các hệ thống nguồn vào Data Warehouse của bạn.

*   **Extract (E - Trích xuất):** Lấy dữ liệu ra từ nguồn (SQL Server, Oracle, file Excel, CSV, API...)
*   **Transform (T - Biến đổi):** Làm sạch và chuẩn hóa dữ liệu (xóa bản trùng, chuyển đổi định dạng ngày tháng, ghép nối họ tên...)
*   **Load (L - Nạp vào):** Đổ dữ liệu sạch vào Data Warehouse.

### 🍳 Ví dụ thực tế: Quán cà phê chuỗi

Giả sử bạn đang làm SQL Developer cho một chuỗi cà phê có 50 chi nhánh. Mỗi chi nhánh dùng một phần mềm quản lý bán hàng khác nhau. Vào lúc 2 giờ sáng mỗi ngày, hệ thống cần:

1.  **Extract:** Lấy dữ liệu đơn hàng từ 50 chi nhánh (50 nguồn khác nhau).
2.  **Transform:** Chuẩn hóa — Chi nhánh A ghi ngày "09/05/2026", chi nhánh B ghi "2026-05-09". SSIS chuyển tất cả về cùng một định dạng.
3.  **Load:** Đổ tất cả vào bảng `FactSales` trong Data Warehouse.

**Sáng ra, Giám đốc mở báo cáo và thấy ngay doanh thu toàn hệ thống ngày hôm qua.**

### 🧩 Cấu trúc của SSIS Package

SSIS gồm hai tầng chính:

#### Tầng 1: Control Flow (Luồng điều khiển)
Đây là **kịch bản tổng thể** — làm việc gì trước, việc gì sau.

```
[Bước 1] Xóa staging table        ✅
     ↓
[Bước 2] Data Flow Task (lấy data) ✅
     ↓
[Bước 3] Chạy MERGE statement     ✅
     ↓
[Bước 4] Gửi email báo cáo thành công ✅
```

Nếu Bước 2 thất bại → Nhảy thẳng sang → Gửi email báo lỗi.

#### Tầng 2: Data Flow (Luồng dữ liệu)
Đây là **dây chuyền sản xuất** — dữ liệu đi qua từng bước xử lý như trên một băng chuyền.

```
[Source: SQL Server]
     ↓
[Lookup: Tìm CustomerID]  ← Tra bảng DimCustomer
     ↓
[Derived Column: Tạo cột LoadDate = GETDATE()]
     ↓
[Conditional Split: Tách data tốt vs data lỗi]
     ↓             ↓
[Destination:   [Error Table:
 FactSales]      Log_Errors]
```

### ⭐ Các thành phần hay dùng nhất

| Thành phần | Làm gì | Tương đương SQL |
|---|---|---|
| **Execute SQL Task** | Chạy một câu SQL bất kỳ | Giống `EXEC stored_proc` |
| **Foreach Loop** | Lặp qua nhiều file | Giống `WHILE` loop |
| **Lookup** | Tìm kiếm giá trị trong bảng khác | Giống `LEFT JOIN` |
| **Derived Column** | Tạo hohoặc sửa cột | Giống `CASE WHEN` trong SELECT |
| **Conditional Split** | Phân luồng dữ liệu | Giống `IF / ELSE` |
| **Data Conversion** | Đổi kiểu dữ liệu | Giống `CAST()` / `CONVERT()` |

---

## 2. SSAS — SQL Server Analysis Services

### 🤔 SSAS là gì?

SSAS là **tầng ngữ nghĩa (Semantic Layer)** nằm giữa Data Warehouse và công cụ báo cáo (Power BI, Excel).

**Vấn đề:** Data Warehouse có thể có hàng chục bảng phức tạp. Bạn không thể bắt Giám đốc tự viết SQL với 5 cái JOIN để xem doanh thu!

**Giải pháp SSAS:** Bạn xây dựng một "Model" — một bản đơn giản hóa của Data Warehouse — trong đó:
*   Các mối quan hệ đã được định nghĩa sẵn.
*   Các phép tính (như "Doanh thu năm nay", "Tăng trưởng so với tháng trước") đã được viết sẵn bằng DAX.
*   Giám đốc chỉ cần kéo thả trong Power BI.

### 🏠 Ví dụ thực tế: Trung tâm thương mại

Hãy tưởng tượng Data Warehouse là **kho hàng khổng lồ** phía sau. Nhân viên kho biết chỗ mọi thứ, nhưng khách hàng không thể vào kho mà tự tìm.

**SSAS** giống như **gian hàng trưng bày** — nó lấy đồ từ kho ra, sắp xếp gọn gàng, dán nhãn rõ ràng ("Giày", "Quần áo", "Túi xách"). Khách hàng (Giám đốc dùng Power BI) chỉ cần đến gian hàng và tự phục vụ.

### 🧩 Hai loại SSAS Model

#### Multidimensional (Cube) — Cũ, ít dùng
*   Cách tiếp cận từ những năm 2000.
*   Dùng ngôn ngữ **MDX** (rất khó viết).
*   Cần phải cấu hình "Aggregations" thủ công.

#### Tabular (Model) — Hiện đại, cần biết ✅
*   Cách tiếp cận từ năm 2012 trở đi.
*   Dùng ngôn ngữ **DAX** (giống Excel, dễ hơn MDX).
*   Lưu dữ liệu trong bộ nhớ RAM bằng engine **VertiPaq** — nhanh kinh khủng.
*   **Đây là nền tảng của Power BI.**

> 🧠 **Lưu ý quan trọng:** Power BI Desktop thực chất là một SSAS Tabular Model chạy cục bộ trên máy của bạn. Đó là lý do khi bạn học SSAS Tabular, bạn cũng hiểu luôn cách Power BI hoạt động.

### ⭐ DAX — Ngôn ngữ của SSAS Tabular

DAX (Data Analysis Expressions) là ngôn ngữ bạn dùng để viết các phép tính trong SSAS.

```dax
-- Tổng doanh thu
Total Revenue = SUM(FactSales[SalesAmount])

-- Doanh thu năm ngoái
Revenue LY = CALCULATE([Total Revenue], DATEADD('Date'[Date], -1, YEAR))

-- Tỉ lệ tăng trưởng
Revenue Growth % = 
    DIVIDE([Total Revenue] - [Revenue LY], [Revenue LY], 0)
```

Bạn viết các phép tính này một lần trong SSAS. Sau đó, bất kỳ báo cáo nào kết nối vào SSAS đều có thể dùng "Revenue Growth %" mà không cần viết lại.

---

## 🔗 Mối quan hệ giữa SSIS và SSAS

Đây là luồng dữ liệu hoàn chỉnh từ đầu đến cuối:

```
Bước 1 (SSIS):    Source DB → [ETL Pipeline] → Data Warehouse
                  (Lấy data thô)  (Làm sạch)    (Lưu trữ)

Bước 2 (SSAS):    Data Warehouse → [Process Tabular Model] → SSAS Model
                  (Nguồn sạch)     (Đọc và nạp vào RAM)     (Sẵn sàng truy vấn)

Bước 3 (Power BI): SSAS Model → [Live Connection] → Dashboard
                   (Nguồn chân lý)  (Kết nối trực tiếp)  (Giám đốc xem)
```

### Ai làm gì trong thực tế?

| Ai | Công cụ | Làm gì |
|---|---|---|
| **SQL Developer (Bạn)** | SSIS | Xây dựng và duy trì ETL pipeline |
| **SQL Developer (Bạn)** | SSAS | Xây dựng Tabular Model, viết DAX |
| **Data Analyst** | Power BI | Kết nối vào SSAS, vẽ biểu đồ |
| **Business User** | Power BI | Xem báo cáo, ra quyết định |

---

## 📝 Tóm tắt nhanh cho phỏng vấn

| | SSIS | SSAS |
|---|---|---|
| **Là gì?** | ETL Tool — Di chuyển dữ liệu | Semantic Layer — Mô hình hóa dữ liệu |
| **Làm gì?** | Extract, Transform, Load | Tổ chức, tính toán, phục vụ báo cáo |
| **Input** | Nhiều nguồn thô (DB, CSV, API) | Data Warehouse sạch |
| **Output** | Data Warehouse sạch | Model sẵn sàng cho Power BI/Excel |
| **Ngôn ngữ** | Không cần code (kéo thả) + T-SQL | DAX |
| **Chạy khi nào?** | Theo lịch (VD: 2 giờ sáng mỗi ngày) | Sau khi SSIS xong (VD: 3 giờ sáng) |

---

## 💬 Cách trả lời phỏng vấn

**Câu hỏi:** "Bạn có thể giải thích SSIS và SSAS làm gì không?"

**Trả lời:**
> "In a complete BI solution, SSIS and SSAS play two very different but complementary roles. SSIS is responsible for the data pipeline — it extracts data from multiple source systems, cleans and transforms it, and loads it into the Data Warehouse on a schedule. Once the Data Warehouse is populated, SSAS takes over as the Semantic Layer. It reads the clean, structured data from the Warehouse and builds a Tabular Model in memory, with pre-defined relationships and DAX calculations like Year-to-Date revenue. Reporting tools like Power BI or Excel then connect to this SSAS model, so business users get fast, consistent, and accurate data without needing to write a single line of SQL."
