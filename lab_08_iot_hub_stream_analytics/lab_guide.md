# Hướng dẫn Lab 08: Enterprise Real-Time Telemetry Pipeline: Azure IoT Hub, Event Hubs & Stream Analytics

Chào mừng bạn đến với bài lab chuyên sâu này. Đây không chỉ là bài hướng dẫn click-by-click — đây là một **textbook kết hợp với lab thực hành**. Sau khi hoàn thành, bạn sẽ không chỉ biết _cách làm_, mà còn hiểu sâu **tại sao** mỗi quyết định kiến trúc tồn tại, và điều gì xảy ra nếu bạn bỏ qua nó trong môi trường production thực tế.

---

## Kịch bản Nghiệp vụ (The Business Scenario)

**TechManufacture** là một tập đoàn sản xuất lớn với nhà máy đặt tại Bình Dương vận hành hơn **1.000 cảm biến công nghiệp (Industrial Sensors)**. Các cảm biến này liên tục đo đạc:

- 🌡️ **Nhiệt độ máy móc (Machine Temperature):** Nếu vượt ngưỡng `85°C`, máy có nguy cơ cháy nổ.
- 📳 **Độ rung (Vibration Level):** Rung bất thường báo hiệu ổ trục (bearing) bị mài mòn.
- ⚡ **Mức tiêu thụ điện năng (Power Consumption):** Tăng đột biến là dấu hiệu quá tải.

**Vấn đề hiện tại:** Kỹ sư phải đi bộ kiểm tra từng máy thủ công 2 lần/ca. Nếu máy quá nhiệt ban đêm, không ai biết cho đến sáng hôm sau — khi thiệt hại đã xảy ra rồi.

**Giải pháp:** Xây dựng hệ thống **Real-Time Telemetry Pipeline** trên Azure:
1. Mỗi cảm biến gửi telemetry lên **Azure IoT Hub** liên tục (mỗi 5 giây).
2. **Azure Stream Analytics** đọc luồng dữ liệu, phát hiện bất thường, phân luồng theo mục đích.
3. Nếu phát hiện ngưỡng nguy hiểm → **Ghi cảnh báo vào Azure SQL** (Alert Table).
4. Mọi dữ liệu thô → Lưu trữ lạnh tại **ADLS Gen2** để phân tích sau.
5. Giám sát viên nhận cảnh báo ngay lập tức, phản ứng trong vòng 60 giây — không phải 8 tiếng.

## Kiến trúc Giải pháp (Solution Architecture)

```
[1000 Industrial Sensors]
        │  (MQTT / AMQP / HTTPS)
        ▼
[ Azure IoT Hub ]  ←── [ Azure Key Vault ] (Secrets & Connection Strings)
        │
        │  (Built-in Event Hub endpoint)
        ▼
[ Azure Stream Analytics ]
   ├── Query 1: Raw Passthrough  ──────────► [ ADLS Gen2 / cold-path/ ]
   ├── Query 2: Anomaly Detection (TUMBLING) ► [ ADLS Gen2 / anomalies/ ]
   └── Query 3: Threshold Alert ────────────► [ Azure SQL / Alerts.SensorAlert ]
                                                       │
                                              [ Power BI Dashboard ]  (tùy chọn)
```

> **🧠 Kiến thức nền tảng: Tại sao cần kiến trúc nhiều lớp này?**
>
> Câu hỏi đầu tiên bạn nên đặt ra: _"Tại sao không gửi thẳng sensor data vào SQL database?"_
>
> Câu trả lời nằm ở **quy mô và tốc độ**. Với 1.000 sensors gửi mỗi 5 giây, bạn có **200 messages/giây = 17 triệu messages/ngày**. Azure SQL Serverless ở tier cơ bản chỉ chịu được ~100-200 writes/giây trước khi bắt đầu timeout. Ngoài ra, SQL không thể tự phát hiện pattern phức tạp theo thời gian (ví dụ: "Máy A liên tục tăng nhiệt trong 3 phút liên tiếp?").
>
> Kiến trúc này giải quyết bằng cách **tách biệt ingestion, processing, và storage**: IoT Hub làm buffer (hấp thụ mọi tốc độ ghi), Stream Analytics làm compute (phát hiện anomaly bằng window functions), còn SQL chỉ nhận alerts đã được lọc — giảm ~99% write load so với ghi tất cả.

---

## Phase 1: Thiết lập Hạ tầng Enterprise

> **Purpose:** Xây dựng nền tảng hạ tầng an toàn trước khi triển khai bất kỳ dịch vụ nào. Mọi tài nguyên phải được gom nhóm, bảo mật credentials bằng Key Vault, và cấu hình storage đúng chuẩn.
>
> **Why does this matter?** Thiếu một Resource Group rõ ràng dẫn đến rác hệ thống khi kết thúc dự án, chi phí khó kiểm soát, và rủi ro bảo mật khi credentials bị hardcode. Đây là lý do các team enterprise luôn bắt đầu từ đây.

### Bước 1.1: Tạo Resource Group

Resource Group là "container" logic gom tất cả tài nguyên của dự án. Sau lab, bạn chỉ cần xóa Resource Group này là sạch toàn bộ, không lo sót tài nguyên.

1. Đăng nhập [portal.azure.com](https://portal.azure.com).
2. Tìm **Resource groups** → **+ Create**.
3. Điền thông tin:
   - **Subscription:** Chọn subscription của bạn.
   - **Resource group:** `rg-techmanufacture-iot-001`
   - **Region:** `Southeast Asia` (hoặc region gần bạn nhất).
4. Nhấn **Review + create** → **Create**.

> 💡 **Naming Convention:** Cấu trúc `rg-[project]-[workload]-[instance]` là chuẩn của Microsoft Cloud Adoption Framework (CAF). Đặt tên chuẩn từ đầu giúp quản lý chi phí và phân quyền dễ dàng hơn rất nhiều khi hệ thống lớn lên với hàng chục resource groups.

### Bước 1.2: Tạo Azure Key Vault

> **Purpose:** Azure Key Vault là chiếc két sắt số hóa — nơi lưu trữ mọi credentials, connection strings, và secrets một cách được mã hóa (AES-256). Stream Analytics, Python scripts, và các service khác sẽ đọc secrets từ đây thay vì hardcode trong code.
>
> **Why does this matter?** Trong thực tế, hàng trăm vụ vi phạm dữ liệu mỗi năm xảy ra do developers vô tình commit credentials lên GitHub. Chỉ cần một secret bị lộ trong file Python, kẻ tấn công có thể inject fake sensor data vào hệ thống để phá vỡ dây chuyền sản xuất.

> **🧠 Kiến thức nền tảng: Hệ quả nếu bỏ qua Key Vault**
>
> Giả sử bạn hardcode IoT Hub connection string trực tiếp trong Python script như `CONN_STR = "HostName=iothub-techmfg.azure-devices.net;SharedAccessKey=abc123..."` và đẩy lên GitHub. Điều gì xảy ra?
>
> Ngay sau khi push, các bot tự động (GitHub Secret Scanning, TruffleHog, GitGuardian) — và cả hacker — quét toàn bộ public repos mỗi vài giây. Trong vòng **15-30 phút**, connection string của bạn có thể bị lấy và dùng để: (1) gửi hàng triệu fake messages làm quá tải IoT Hub, (2) inject dữ liệu sai khiến hệ thống cảnh báo hoặc _không_ cảnh báo khi cần, (3) phát sinh chi phí Azure khổng lồ. Key Vault kết hợp Managed Identity loại bỏ hoàn toàn secret khỏi code — không có gì để lộ.

1. Tìm **Key vaults** → **+ Create**.
2. Điền thông tin:
   - **Resource group:** `rg-techmanufacture-iot-001`
   - **Key vault name:** `kv-techmfg-iot-001[suffix]` _(tên phải unique toàn cầu — thêm 3-4 ký tự cá nhân)_
   - **Region:** Match resource group.
   - **Pricing tier:** Standard.
3. Click **Review + create** → **Create**.

**Cấp quyền cho bản thân (IAM - RBAC):**

> **🧠 Kiến thức nền tảng: RBAC là gì và tại sao creator không tự động có quyền?**
>
> Azure dùng **Role-Based Access Control (RBAC)** theo nguyên tắc "deny by default". Dù bạn là người TẠO ra Key Vault, điều đó không nghĩa là bạn được phép đọc secrets bên trong — đây là hai quyền tách biệt nhau hoàn toàn.
>
> Tại sao thiết kế như vậy? Trong doanh nghiệp, người tạo ra Key Vault (DevOps team) không nhất thiết phải biết nội dung secrets bên trong (chứa password của DBA team). Tách biệt quyền "quản lý Key Vault" và "đọc secrets trong Key Vault" cho phép áp dụng **Separation of Duties** — một nguyên tắc security quan trọng trong compliance (SOC 2, ISO 27001).

4. Mở Key Vault vừa tạo → **Access control (IAM)** → **+ Add** → **Add role assignment**.
5. Tìm và chọn **Key Vault Secrets Officer** → **Next**.
6. **Assign access to:** User, group, or service principal.
7. **+ Select members** → Tìm email của bạn → **Select**.
8. **Review + assign** → **Review + assign**.
9. ⏳ **Đợi 3–5 phút** để Azure propagate rule mới này (Azure AD token cache cần thời gian để refresh).

**Thêm Secret đầu tiên (placeholder cho IoT Hub):**

10. Trong Key Vault → **Objects** → **Secrets** → **+ Generate/Import**.
11. **Name:** `iothub-connection-string` _(giá trị thực sẽ điền sau khi tạo IoT Hub)_
12. **Value:** `placeholder`
13. Click **Create**.

### Bước 1.3: Tạo Azure IoT Hub

> **Purpose:** IoT Hub là trung tâm giao tiếp hai chiều (bidirectional) giữa đám mây và hàng ngàn thiết bị IoT. Nó đóng vai trò "cổng vào" (ingress gateway) tiếp nhận hàng triệu messages/ngày với độ trễ thấp, đảm bảo không mất dữ liệu.
>
> **Why does this matter?** IoT Hub là foundation của toàn bộ pipeline. Nếu không có nó, 1.000 sensors sẽ phải kết nối trực tiếp vào ADLS hoặc SQL — điều hoàn toàn không khả thi về mặt bảo mật (mỗi sensor cần credentials riêng, quản lý không được) và scale (SQL không chịu nổi 200 concurrent TCP connections từ sensors).

> **🧠 Kiến thức nền tảng: IoT Hub vs Event Hubs vs Apache Kafka — Chọn khi nào?**
>
> Đây là câu hỏi phỏng vấn senior rất phổ biến. Ba lựa chọn này đều là "message brokers" nhưng có use cases khác nhau rõ ràng:
>
> **Azure Event Hubs:** Là một _raw message bus_ tốc độ cao (millions of events/second). Dùng khi bạn có các publisher đã biết danh tính (server backends, microservices) và chỉ cần ingestion + replay. Không có device management, không có bidirectional comms. Phí thấp hơn IoT Hub.
>
> **Azure IoT Hub:** Là Event Hubs _cộng thêm_ toàn bộ lớp quản lý thiết bị IoT: Device Identity Registry (xác thực từng thiết bị), Device Twin (state management), Direct Methods (cloud → device commands), Message Routing, File Upload. Dùng khi bạn có hàng ngàn thiết bị vật lý cần quản lý vòng đời. Đây là lý do ta chọn IoT Hub cho TechManufacture.
>
> **Apache Kafka (tự host hoặc Confluent Cloud):** Là lựa chọn tốt nhất khi bạn cần vendor-agnostic, muốn chạy on-premise, hoặc cần ecosystem rộng lớn (Kafka Connect, ksqlDB). Latency cực thấp, throughput cực cao. Trade-off: bạn phải tự quản lý cluster (hoặc trả phí Confluent Cloud cao). Dùng ở các công ty lớn như Grab, Tiki, Shopee.
>
> **Kết luận:** IoT Hub là lựa chọn tối ưu cho TechManufacture vì: (1) thiết bị IoT cần authentication riêng, (2) cần Direct Methods để emergency shutdown từ xa, (3) cần Device Twin để track trạng thái offline sensors.

> **🧠 Kiến thức nền tảng: Các protocol IoT Hub hỗ trợ — MQTT, AMQP, HTTPS**
>
> IoT Hub hỗ trợ 3 protocols:
> - **MQTT (Message Queuing Telemetry Transport):** Nhẹ nhất (header chỉ 2 bytes!), được thiết kế cho thiết bị có RAM ít, pin yếu. Dùng trên Raspberry Pi, Arduino, ESP32. Port 8883 (TLS) hoặc 1883 (no TLS — không khuyến nghị).
> - **AMQP (Advanced Message Queuing Protocol):** Nặng hơn MQTT, phù hợp thiết bị có kết nối ổn định và RAM đủ. Hỗ trợ multiplexing (nhiều kênh trên 1 TCP connection). Dùng trên industrial gateways.
> - **HTTPS:** Mọi thiết bị đều hiểu. Đơn giản nhất nhưng tốn nhất (mỗi message là 1 HTTP request với full header overhead). Chỉ dùng khi thiết bị không hỗ trợ MQTT/AMQP.
>
> Python SDK mặc định dùng **MQTT** — phù hợp cho lab và production lightweight sensors.

1. Tìm **IoT Hub** → **+ Create**.
2. Điền thông tin:
   - **Resource group:** `rg-techmanufacture-iot-001`
   - **IoT hub name:** `iothub-techmfg-001[suffix]` _(unique toàn cầu)_
   - **Region:** Match resource group.
3. Click **Next: Networking** → **Connectivity configuration:** Public access (cho lab).
4. Click **Next: Management**:
   - **Pricing and scale tier:** **F1: Free tier** (8.000 messages/ngày — đủ cho lab).
   - Nếu đã dùng F1 tier ở subscription khác: Chọn **S1: Standard** ($25/tháng, cancel sau lab).
5. Click **Review + create** → **Create**.

**Lấy IoT Hub Connection String và lưu vào Key Vault:**

6. Mở IoT Hub → **Security settings** → **Shared access policies** → Click **iothubowner**.
7. Copy **Primary connection string**.
8. Quay lại Key Vault → **Secrets** → Chọn `iothub-connection-string` → **New Version**.
9. **Value:** Dán connection string → **Create**.

**Đăng ký thiết bị IoT (Device Provisioning):**

> **🧠 Kiến thức nền tảng: Device Identity Registry — Tại sao thiết bị phải "đăng ký" trước?**
>
> Trong thế giới thực, cảm biến công nghiệp được lắp đặt bởi kỹ thuật viên hiện trường. Nếu bất kỳ thiết bị nào cũng có thể kết nối IoT Hub và gửi data, kẻ tấn công chỉ cần mua một cảm biến tương tự và inject fake data — ví dụ: báo nhiệt độ bình thường trong khi máy đang quá nhiệt thực sự.
>
> Device Identity Registry giải quyết bằng cách: mỗi thiết bị khi được lắp đặt phải được **provisioned** trước (đăng ký vào registry). IoT Hub cấp cho nó một cặp key riêng. Khi kết nối, thiết bị phải prove identity bằng key đó (Symmetric Key hoặc X.509 Certificate). Thiết bị không đăng ký → bị reject ngay lập tức.
>
> Trong production với 1.000+ devices, bạn dùng **Device Provisioning Service (DPS)** để tự động hóa quá trình này — kỹ thuật viên chỉ cần cắm thiết bị vào, DPS tự provisioning không cần đăng nhập portal.

10. IoT Hub → **Device management** → **Devices** → **+ Add Device**.
11. **Device ID:** `sensor-machine-001`
12. **Authentication type:** Symmetric key.
13. **Auto-generate keys:** ✅ Checked.
14. Click **Save**.
15. Lặp lại để tạo thêm `sensor-machine-002` và `sensor-machine-003`.
16. Click `sensor-machine-001` → Copy **Primary Connection String** (cần cho Phase 3).

### Bước 1.4: Tạo Azure Data Lake Storage Gen2 (Cold Path Storage)

> **Purpose:** ADLS Gen2 lưu trữ toàn bộ dữ liệu telemetry thô (cold path) và dữ liệu anomaly đã được phân loại. Đây là "data lake" để chạy machine learning batch jobs, audit trails, và historical analysis.
>
> **Why does this matter?** Cold path data là "bảo hiểm" của bạn. Giả sử Stream Analytics có bug và ghi sai alerts vào SQL — với cold path, bạn có thể replay lại toàn bộ raw data qua pipeline mới để tái tạo đúng kết quả. Không có cold path = không có khả năng recovery.

> **🧠 Kiến thức nền tảng: Hierarchical Namespace — Tại sao đây là "bí mật" của ADLS Gen2?**
>
> Azure Blob Storage thông thường lưu files theo mô hình "flat" — không có folder thực sự. Khi bạn tạo file `data/2024/01/sensor.json`, Azure thực ra chỉ tạo một object với _tên chứa dấu slash_ — không phải folder thực. Điều này gây ra vấn đề lớn:
>
> 1. **Rename/Move cực chậm:** Đổi tên folder `2024/` thành `archive/2024/` phải copy từng file một rồi xóa bản gốc — với petabytes data, mất hàng tiếng.
> 2. **Permission không granular:** Không thể set permission riêng cho folder `gold/` mà chỉ cho `bronze/` thôi.
> 3. **Big Data tools không tương thích:** Spark, Hive, Presto dùng POSIX file system operations — chúng cần folder thực sự.
>
> **Hierarchical Namespace** bật lên thì Azure thực sự tạo folder thực với inode riêng (giống Linux ext4). Rename folder petabytes = O(1) atomic operation. Permission set được theo từng folder. Đây là lý do ADLS Gen2 (Blob + Hierarchical Namespace) là tiêu chuẩn enterprise, không phải plain Blob Storage.

1. Tìm **Storage accounts** → **+ Create**.
2. Điền:
   - **Resource group:** `rg-techmanufacture-iot-001`
   - **Storage account name:** `sttechiotlake001[suffix]` _(lowercase, no hyphens, max 24 chars)_
   - **Region:** Match resource group.
   - **Redundancy:** LRS (cho lab).
3. Click **Next: Advanced**.
4. **Data Lake Storage Gen2** → ✅ **Enable hierarchical namespace** ← _Bước quan trọng nhất!_
5. Click **Review** → **Create**.

**Tạo containers:**

6. Mở Storage Account → **Containers** → **+ Container**.
7. Tạo 3 containers:
   - `cold-path` — dữ liệu thô toàn bộ từ sensors
   - `anomalies` — events bất thường đã được Stream Analytics phát hiện
   - `checkpoints` — Stream Analytics lưu offset để resume khi job restart

### Bước 1.5: Tạo Azure SQL Database (Alert Storage)

> **Purpose:** Azure SQL lưu bảng `Alerts.SensorAlert` — nơi Stream Analytics ghi cảnh báo theo thời gian thực. Đây là "hot path" để giám sát viên và Power BI query tức thì.
>
> **Why does this matter?** SQL là ngôn ngữ chung mà operations team, Power BI, Power Automate, và Logic Apps đều hiểu. Khi có alert mới trong SQL, Power Automate có thể tự động gửi Teams message hoặc SMS cho kỹ sư trực ca.

1. Tìm **SQL databases** → **+ Create**.
2. Điền:
   - **Resource group:** `rg-techmanufacture-iot-001`
   - **Database name:** `sqldb-techmfg-alerts`
   - **Server:** Click **Create new**:
     - **Server name:** `sqlserver-techmfg-[suffix]`
     - **Authentication:** SQL authentication.
     - **Admin login:** `sqladmin`
     - **Password:** `P@ssw0rdIoT2024!!`
     - Click **OK**.
3. **Compute + storage:** Click **Configure database** → **Basic** tier (~$5/tháng).
4. Click **Next: Networking**:
   - **Connectivity:** Public endpoint.
   - **Allow Azure services:** ✅ Yes.
   - **Add current client IP:** ✅ Yes.
5. Click **Review + create** → **Create**.

**Lưu SQL password vào Key Vault:**

6. Key Vault → **Secrets** → **+ Generate/Import**.
7. **Name:** `sql-admin-password`, **Value:** `P@ssw0rdIoT2024!!` → **Create**.

---

## Phase 2: Bảo mật Kiến trúc (IAM, Managed Identity & Network)

> **Purpose:** Bảo mật từng kết nối trong kiến trúc bằng nguyên tắc **Least Privilege** — mỗi service chỉ được cấp quyền tối thiểu cần thiết. Không có service nào giữ password cứng trong config.
>
> **Why does this matter?** Một secret bị lộ trong kiến trúc IoT không chỉ là rủi ro data breach — nó có thể cho phép kẻ tấn công inject lệnh shutdown vào máy móc đang vận hành, gây nguy hiểm tính mạng công nhân.

> **🧠 Kiến thức nền tảng: Managed Identity — Cơ chế hoạt động bên trong**
>
> Managed Identity là tính năng của Azure Active Directory (Entra ID) cho phép một Azure service (ví dụ: Stream Analytics job) có một **identity tự động** mà không cần bạn tạo password hay quản lý.
>
> Cơ chế hoạt động: Khi Stream Analytics cần ghi vào ADLS Gen2, nó gửi request đến **Azure Instance Metadata Service (IMDS)** — một endpoint nội bộ chỉ accessible từ trong Azure VM/service (`http://169.254.169.254`). IMDS trả về **JWT token** ngắn hạn (1 giờ) được ký bởi Azure AD. Stream Analytics dùng token này để authenticate với ADLS — không cần password, không thể bị steal vì token expire sau 1 giờ và chỉ sinh ra bên trong Azure infrastructure.
>
> So với **Service Principal + Secret**: Service Principal cần bạn tạo secret (có thể expire, phải rotate thủ công, có thể bị leak). Managed Identity hoàn toàn tự động — Azure tạo, rotate, và revoke. Trong production enterprise, đây là lựa chọn bắt buộc.

### Bước 2.1: Bật Managed Identity cho Stream Analytics Job

_(Stream Analytics Job sẽ tạo ở Phase 4 — ghi nhớ quay lại bước này sau)_

Sau khi tạo Stream Analytics Job:
1. Mở job → **Settings** → **Identity** → Tab **System assigned** → **On** → **Save**.

**Gán quyền vào ADLS Gen2:**
2. Mở Storage Account → **Access Control (IAM)** → **+ Add** → **Add role assignment**.
3. Chọn **Storage Blob Data Contributor** → **Next**.
4. **Assign access to:** Managed identity → **+ Select members** → Chọn Stream Analytics job → **Select**.
5. **Review + assign** → **Review + assign**.

### Bước 2.2: Cấu hình IP Filter trên IoT Hub

> **🧠 Kiến thức nền tảng: Tại sao IoT Hub không dùng NSG như VM?**
>
> NSG (Network Security Group) là firewall cho Azure Virtual Network (VNet). IoT Hub là **fully managed service** — Microsoft quản lý infrastructure bên dưới, bạn không có VNet để attach NSG. Thay vào đó, IoT Hub cung cấp **IP Filter Rules** để whitelist/blacklist IP ranges ở application layer.
>
> Trong production enterprise, giải pháp tốt hơn là dùng **IoT Hub Private Endpoint** — đặt IoT Hub hoàn toàn bên trong VNet, chỉ accessible qua private IP. Sensors kết nối qua VPN hoặc ExpressRoute. Đây là chuẩn zero-trust networking cho OT (Operational Technology) environments.

1. Mở IoT Hub → **Security settings** → **IP filter** → **+ Add IP filter rule**.
2. **Name:** `allow-office-ip`, **Action:** Allow, **IP range:** IP công ty của bạn.
3. Click **Save**.

> **Troubleshooting:** Nếu Python simulator báo lỗi kết nối sau bước này, kiểm tra IP công khai tại [whatismyip.com](https://whatismyip.com) và thêm vào whitelist. Trong môi trường lab học, bạn có thể skip bước IP Filter.

### Bước 2.3: Lưu Device Connection String vào Key Vault

1. Key Vault → **Secrets** → **+ Generate/Import**.
2. **Name:** `device-sensor-001-connstring`
3. **Value:** Connection string của `sensor-machine-001` từ Bước 1.3.
4. Click **Create**. Lặp lại cho `sensor-machine-002` và `sensor-machine-003`.

---

## Phase 3: Device Simulation — Python Production-Grade Client

> **Purpose:** Viết Python script mô phỏng chính xác hành vi của 1.000 cảm biến: gửi telemetry định kỳ, xử lý kết nối bị ngắt, cập nhật Device Twin, và hỗ trợ Direct Methods.
>
> **Why does this matter?** Code production-grade với retry logic, structured logging, và error handling là tiêu chuẩn để team có thể debug, monitor, và operate hệ thống 24/7. "Happy path" code không tồn tại trong production — mạng factory sẽ bị ngắt, máy chủ sẽ overload, certificates sẽ expire.

> **🧠 Kiến thức nền tảng: Exponential Backoff — Tại sao không retry ngay lập tức?**
>
> Khi kết nối bị ngắt, reflex tự nhiên là retry ngay lập tức. Nhưng điều này gây ra vấn đề **thundering herd**: nếu IoT Hub tạm thời overloaded khiến 1.000 sensors bị disconnect đồng thời, và tất cả cùng retry ngay → 1.000 request cùng lúc → càng overload hơn → vòng lặp vô tận.
>
> **Exponential backoff** giải quyết bằng cách tăng thời gian chờ theo cấp số nhân: 2s → 4s → 8s → 16s → ... → cap ở 120s. Nếu thêm **jitter** (random thêm 0-1s), các devices sẽ retry vào những thời điểm khác nhau, trải đều load. AWS, Google, Azure đều recommend pattern này trong documentation của họ.

### Bước 3.1: Cài đặt Dependencies

```bash
pip install azure-iot-device==2.13.1 azure-identity==1.15.0 azure-keyvault-secrets==4.7.0
```

### Bước 3.2: Cấu trúc Telemetry Payload

Đây là "contract" dữ liệu mà tất cả downstream systems sẽ dựa vào. Thay đổi schema mà không thông báo = phá vỡ Stream Analytics queries và ML models:

```json
{
  "deviceId": "sensor-machine-001",
  "machineId": "LINE-A-CNC-01",
  "timestamp": "2024-01-15T08:30:00.123Z",
  "telemetry": {
    "temperature": 78.5,
    "vibration": 0.42,
    "powerConsumption": 142.7
  },
  "metadata": {
    "firmwareVersion": "2.1.4",
    "sensorType": "industrial-triaxis",
    "location": "factory-floor-zone-a"
  }
}
```

### Bước 3.3: Production Python Simulator

Tạo file `sensor_simulator.py`:

```python
"""
TechManufacture Industrial Sensor Simulator
Production-grade IoT client với retry logic, Device Twin, và Direct Methods.
"""

import json
import logging
import os
import random
import signal
import sys
import time
from datetime import datetime, timezone
from typing import Optional

from azure.iot.device import IoTHubDeviceClient, Message, MethodResponse
from azure.iot.device.exceptions import ConnectionDroppedError, ConnectionFailedError

# ─── Logging Configuration ────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%SZ",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler("sensor_simulator.log"),
    ],
)
logger = logging.getLogger("TechManufacture.Sensor")

# ─── Sensor Configuration ─────────────────────────────────────────────────────
SENSOR_CONFIG = {
    "deviceId": "sensor-machine-001",
    "machineId": "LINE-A-CNC-01",
    "location": "factory-floor-zone-a",
    "firmwareVersion": "2.1.4",
    "sensorType": "industrial-triaxis",
    "temp_normal_range": (55.0, 75.0),
    "vibration_normal_range": (0.1, 0.5),
    "power_normal_range": (120.0, 160.0),
    "temp_critical_threshold": 85.0,
    "vibration_critical_threshold": 0.9,
    "telemetry_interval_seconds": 5,
    "anomaly_probability": 0.05,  # 5% cơ hội sinh anomaly để test cảnh báo
}


def get_connection_string_from_keyvault(vault_url: str, secret_name: str) -> str:
    """
    Đọc connection string từ Azure Key Vault — pattern bắt buộc trong production.
    DefaultAzureCredential tự dùng Managed Identity trên Azure, az CLI credential ở local.
    """
    from azure.identity import DefaultAzureCredential
    from azure.keyvault.secrets import SecretClient

    credential = DefaultAzureCredential()
    client = SecretClient(vault_url=vault_url, credential=credential)
    secret = client.get_secret(secret_name)
    logger.info(f"Successfully retrieved secret '{secret_name}' from Key Vault.")
    return secret.value


def generate_telemetry(config: dict, force_anomaly: bool = False) -> dict:
    """Sinh telemetry payload. force_anomaly=True để inject bất thường có kiểm soát."""
    if force_anomaly or random.random() < config["anomaly_probability"]:
        temperature = round(random.uniform(88.0, 95.0), 2)
        vibration = round(random.uniform(0.85, 1.2), 3)
        power = round(random.uniform(185.0, 210.0), 2)
        logger.warning(f"⚠️  ANOMALY INJECTED: temp={temperature}°C, vib={vibration}g")
    else:
        temperature = round(random.uniform(*config["temp_normal_range"]), 2)
        vibration = round(random.uniform(*config["vibration_normal_range"]), 3)
        power = round(random.uniform(*config["power_normal_range"]), 2)

    return {
        "deviceId": config["deviceId"],
        "machineId": config["machineId"],
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "telemetry": {
            "temperature": temperature,
            "vibration": vibration,
            "powerConsumption": power,
        },
        "metadata": {
            "firmwareVersion": config["firmwareVersion"],
            "sensorType": config["sensorType"],
            "location": config["location"],
        },
    }


def handle_direct_method(method_request) -> MethodResponse:
    """
    Direct Methods cho phép cloud ra lệnh cho thiết bị theo thời gian thực.
    Trong thực tế: emergency shutdown, thay đổi sampling rate, trigger calibration.
    """
    logger.info(f"📞 Direct Method: '{method_request.name}' | Payload: {method_request.payload}")

    if method_request.name == "emergencyShutdown":
        logger.critical("🚨 EMERGENCY SHUTDOWN command received!")
        return MethodResponse.create_from_method_request(
            method_request, status=200,
            payload={"status": "shutdown_initiated", "machine": SENSOR_CONFIG["machineId"]}
        )
    elif method_request.name == "setSamplingRate":
        new_rate = method_request.payload.get("intervalSeconds", 5)
        SENSOR_CONFIG["telemetry_interval_seconds"] = new_rate
        logger.info(f"⚙️  Sampling rate updated to {new_rate}s")
        return MethodResponse.create_from_method_request(
            method_request, status=200, payload={"newInterval": new_rate}
        )
    else:
        return MethodResponse.create_from_method_request(
            method_request, status=404, payload={"error": "Unknown method"}
        )


def update_device_twin(client: IoTHubDeviceClient, config: dict) -> None:
    """
    Device Twin reported properties — cập nhật trạng thái thiết bị lên cloud.
    Cloud có thể đọc trạng thái này bất cứ lúc nào, kể cả khi device offline.
    """
    reported_props = {
        "firmware": config["firmwareVersion"],
        "location": config["location"],
        "operationalStatus": "running",
        "lastBootTime": datetime.now(timezone.utc).isoformat(),
        "connectivity": {
            "protocol": "MQTT",
            "telemetryIntervalSeconds": config["telemetry_interval_seconds"],
        },
    }
    client.patch_twin_reported_properties(reported_props)
    logger.info("✅ Device Twin reported properties updated.")


class SensorSimulator:
    """
    Production-grade simulator: exponential backoff retry, graceful shutdown,
    Device Twin updates, Direct Method handling.
    """
    MAX_RETRY_ATTEMPTS = 10
    INITIAL_BACKOFF_SECONDS = 2
    MAX_BACKOFF_SECONDS = 120

    def __init__(self, connection_string: str, config: dict):
        self.connection_string = connection_string
        self.config = config
        self.client: Optional[IoTHubDeviceClient] = None
        self._running = False
        self._message_count = 0
        signal.signal(signal.SIGTERM, self._handle_shutdown)
        signal.signal(signal.SIGINT, self._handle_shutdown)

    def _handle_shutdown(self, signum, frame):
        logger.info(f"🛑 Shutdown signal (signal {signum}). Stopping gracefully...")
        self._running = False

    def _connect_with_retry(self) -> IoTHubDeviceClient:
        """Exponential backoff connection — tự hồi phục khi mạng factory gián đoạn."""
        attempt = 0
        backoff = self.INITIAL_BACKOFF_SECONDS

        while attempt < self.MAX_RETRY_ATTEMPTS:
            try:
                logger.info(f"🔌 Connecting (attempt {attempt + 1}/{self.MAX_RETRY_ATTEMPTS})...")
                client = IoTHubDeviceClient.create_from_connection_string(
                    self.connection_string, keep_alive=30, connection_retry=False
                )
                client.connect()
                logger.info("✅ Connected to IoT Hub!")
                return client
            except (ConnectionFailedError, ConnectionDroppedError) as e:
                attempt += 1
                if attempt >= self.MAX_RETRY_ATTEMPTS:
                    logger.error(f"❌ Failed after {self.MAX_RETRY_ATTEMPTS} attempts.")
                    raise
                logger.warning(f"⚠️  Failed: {e}. Retry in {backoff}s...")
                time.sleep(backoff)
                backoff = min(backoff * 2, self.MAX_BACKOFF_SECONDS)  # Exponential backoff

    def run(self, test_anomaly_after_messages: int = 0):
        self._running = True
        self.client = self._connect_with_retry()
        self.client.on_method_request_received = lambda req: self.client.send_method_response(
            handle_direct_method(req)
        )
        update_device_twin(self.client, self.config)

        interval = self.config["telemetry_interval_seconds"]
        logger.info(f"🚀 Telemetry loop started. Interval: {interval}s | Device: {self.config['deviceId']}")

        while self._running:
            try:
                force_anomaly = (
                    test_anomaly_after_messages > 0
                    and self._message_count == test_anomaly_after_messages
                )
                payload = generate_telemetry(self.config, force_anomaly=force_anomaly)
                message = Message(json.dumps(payload))
                message.content_type = "application/json"
                message.content_encoding = "utf-8"
                message.custom_properties["sensorType"] = self.config["sensorType"]
                message.custom_properties["machineId"] = self.config["machineId"]

                self.client.send_message(message)
                self._message_count += 1
                t = payload["telemetry"]
                logger.info(
                    f"📤 #{self._message_count:05d} | "
                    f"Temp: {t['temperature']:5.1f}°C | "
                    f"Vib: {t['vibration']:.3f}g | "
                    f"Power: {t['powerConsumption']:6.1f}W"
                )
                time.sleep(interval)

            except (ConnectionDroppedError, ConnectionFailedError) as e:
                logger.warning(f"⚠️  Connection lost: {e}. Reconnecting...")
                try:
                    self.client.disconnect()
                except Exception:
                    pass
                self.client = self._connect_with_retry()
            except Exception as e:
                logger.error(f"❌ Unexpected error: {e}", exc_info=True)
                time.sleep(5)

        logger.info(f"🛑 Stopped. Total messages sent: {self._message_count}")
        try:
            self.client.shutdown()
        except Exception:
            pass


if __name__ == "__main__":
    # Production: dùng Key Vault. Lab: set env var IOTHUB_DEVICE_CONNECTION_STRING
    # vault_url = "https://kv-techmfg-iot-001.vault.azure.net/"
    # conn_str = get_connection_string_from_keyvault(vault_url, "device-sensor-001-connstring")
    conn_str = os.environ.get(
        "IOTHUB_DEVICE_CONNECTION_STRING",
        "HostName=YOUR_IOTHUB.azure-devices.net;DeviceId=sensor-machine-001;SharedAccessKey=YOUR_KEY"
    )
    simulator = SensorSimulator(connection_string=conn_str, config=SENSOR_CONFIG)
    simulator.run()
```

### Bước 3.4: Chạy và Xác nhận

```bash
export IOTHUB_DEVICE_CONNECTION_STRING="HostName=iothub-techmfg-001.azure-devices.net;DeviceId=sensor-machine-001;SharedAccessKey=..."
python sensor_simulator.py
```

Xác nhận data đến IoT Hub:
```bash
az iot hub monitor-events --hub-name iothub-techmfg-001 --output table
```

---

## Phase 4: Azure Stream Analytics — 3 Queries Xử lý Luồng Thời gian thực

> **Purpose:** Stream Analytics đọc hàng triệu events/giây từ IoT Hub, chạy SQL-style queries thời gian thực, và tự động phân luồng dữ liệu tới ADLS (cold path) và Azure SQL (alerts).
>
> **Why does this matter?** Đây là "não bộ" của toàn bộ pipeline. Nếu không có Stream Analytics, bạn phải tự xây dựng Kafka + Flink/Spark Streaming cluster — tốn kém, phức tạp, và cần đội DevOps riêng để vận hành.

> **🧠 Kiến thức nền tảng: Windowing Functions — Trái tim của Stream Processing**
>
> Câu hỏi cốt lõi của stream processing: _"Khi nào thì tính toán kết quả?"_ Không thể chờ tất cả data đến (stream là vô hạn), nhưng tính mỗi event một lần thì không đủ context. **Window functions** giải quyết bằng cách nhóm events theo thời gian:
>
> - **Tumbling Window:** Cửa sổ cố định, **không chồng lên nhau**. Ví dụ: tính trung bình nhiệt độ mỗi 1 phút chính xác (00:00–01:00, 01:00–02:00, ...). Mỗi event thuộc đúng 1 cửa sổ. **Dùng trong lab này cho anomaly detection.**
>
> - **Hopping Window:** Cửa sổ có kích thước cố định nhưng **di chuyển theo bước nhỏ hơn**. Ví dụ: window 5 phút, nhảy mỗi 1 phút (00:00–05:00, 01:00–06:00, ...). Mỗi event có thể thuộc nhiều cửa sổ. Dùng khi bạn muốn "rolling average" — ví dụ: nhiệt độ trung bình 5 phút qua, update mỗi phút.
>
> - **Sliding Window:** Cửa sổ kết thúc mỗi khi có event xảy ra, tính ngược lại một khoảng thời gian. Phức tạp nhất, chỉ dùng khi cần phản ứng tức thì với mỗi event (ví dụ: phát hiện 3 lỗi liên tiếp trong 30 giây bất kỳ).
>
> - **Session Window:** Nhóm events theo "phiên hoạt động" — cửa sổ đóng lại sau khoảng nghỉ (gap). Dùng cho user behavior analytics.
>
> **Lý do chọn TumblingWindow cho TechManufacture:** SLA yêu cầu "phát hiện anomaly trong 60 giây". Window 30s (Query 3) + Stream Analytics latency ~10-15s = tổng ~45s < 60s. ✅ Nếu dùng SlidingWindow, mỗi event sẽ trigger tính toán — quá nhiều writes vào SQL không cần thiết.

### Bước 4.1: Tạo Stream Analytics Job

1. Tìm **Stream Analytics jobs** → **+ Create**.
2. Điền:
   - **Resource group:** `rg-techmanufacture-iot-001`
   - **Job name:** `asa-techmfg-realtime`
   - **Region:** Match resource group.
   - **Hosting environment:** Cloud.
   - **Streaming units:** 1 (đủ cho lab; production 3-6 tùy throughput).
3. Click **Review + create** → **Create**.
4. Mở job → **Settings** → **Identity** → **System assigned** → **On** → **Save**.
5. Thực hiện gán IAM như Phase 2.

### Bước 4.2: Cấu hình Input — IoT Hub

1. Mở job → **Job topology** → **Inputs** → **+ Add stream input** → **IoT Hub**.
2. Điền:
   - **Input alias:** `IoTHubInput`
   - **IoT Hub:** `iothub-techmfg-001`.
   - **Consumer group:** `$Default`.
   - **Shared access policy:** `iothubowner`.
   - **Event serialization format:** JSON, UTF-8.
3. Click **Save**.

> **Troubleshooting:** Nếu **Test connection** lỗi `Unauthorized`, kiểm tra Shared Access Policy và đảm bảo simulator đang chạy và gửi messages.

### Bước 4.3: Cấu hình Outputs

**Output 1 — ADLS Gen2 Cold Path:**
1. **Outputs** → **+ Add** → **Azure Data Lake Storage Gen2**.
   - **Alias:** `ADLSColdPath`, Storage: `sttechiotlake001`, **Auth: Managed Identity** ✅
   - **Container:** `cold-path`, **Path:** `{date}/{time}`, Format: JSON.

**Output 2 — ADLS Gen2 Anomaly Path:**
2. **Outputs** → **+ Add** → **Azure Data Lake Storage Gen2**.
   - **Alias:** `ADLSAnomalyPath`, Storage: `sttechiotlake001`, **Auth: Managed Identity** ✅
   - **Container:** `anomalies`, **Path:** `{date}`, Format: JSON.

**Output 3 — Azure SQL Alerts:**
3. **Outputs** → **+ Add** → **Azure SQL Database**.
   - **Alias:** `SQLAlerts`, Database: `sqldb-techmfg-alerts`.
   - **Auth:** SQL Server Authentication, User: `sqladmin`, Password: `P@ssw0rdIoT2024!!`.
   - **Table:** `Alerts.SensorAlert`.

### Bước 4.4: Tạo Alert Table trong Azure SQL

Azure SQL → **Query editor** → Đăng nhập → Chạy:

```sql
-- Tạo Schema và bảng Alerts
CREATE SCHEMA Alerts;
GO

CREATE TABLE Alerts.SensorAlert (
    AlertId          INT IDENTITY(1,1) PRIMARY KEY,
    DeviceId         NVARCHAR(100)   NOT NULL,
    MachineId        NVARCHAR(100)   NOT NULL,
    AlertType        NVARCHAR(50)    NOT NULL,   -- 'HIGH_TEMPERATURE', 'HIGH_VIBRATION', etc.
    Temperature      FLOAT           NULL,
    Vibration        FLOAT           NULL,
    PowerConsumption FLOAT           NULL,
    WindowStart      DATETIME2       NOT NULL,
    WindowEnd        DATETIME2       NOT NULL,
    EventCount       INT             NOT NULL,
    Severity         NVARCHAR(20)    NOT NULL,   -- 'WARNING', 'CRITICAL'
    CreatedAt        DATETIME2       DEFAULT GETUTCDATE(),
    IsAcknowledged   BIT             DEFAULT 0
);

-- Index để tăng tốc query theo device và thời gian
CREATE INDEX IX_SensorAlert_DeviceId_CreatedAt
    ON Alerts.SensorAlert (DeviceId, CreatedAt DESC);

-- View để giám sát viên xem cảnh báo chưa xử lý
CREATE VIEW Alerts.UnacknowledgedAlerts AS
SELECT
    AlertId, DeviceId, MachineId, AlertType, Severity,
    Temperature, Vibration, PowerConsumption,
    WindowEnd AS AlertTime, EventCount,
    DATEDIFF(MINUTE, WindowEnd, GETUTCDATE()) AS MinutesSinceAlert
FROM Alerts.SensorAlert
WHERE IsAcknowledged = 0;
GO
```

### Bước 4.5: Viết 3 Stream Analytics Queries

Mở job → **Job topology** → **Query** → Dán toàn bộ query:

```sql
-- ═══════════════════════════════════════════════════════════════════════════
-- QUERY 1: RAW PASSTHROUGH — Cold Path. Ghi TOÀN BỘ dữ liệu thô vào ADLS.
-- Lý do: Không được mất một message nào. Cold path cho phép replay/reprocess
--        nếu queries khác có bug, hoặc để train ML models sau.
-- ═══════════════════════════════════════════════════════════════════════════
SELECT
    IoTHub.ConnectionDeviceId                                          AS deviceId,
    GetRecordPropertyValue(telemetry, 'temperature')                   AS temperature,
    GetRecordPropertyValue(telemetry, 'vibration')                     AS vibration,
    GetRecordPropertyValue(telemetry, 'powerConsumption')              AS powerConsumption,
    GetRecordPropertyValue(metadata, 'machineId')                      AS machineId,
    GetRecordPropertyValue(metadata, 'location')                       AS location,
    GetRecordPropertyValue(metadata, 'firmwareVersion')                AS firmwareVersion,
    EventEnqueuedUtcTime                                               AS enqueuedTime,
    System.Timestamp()                                                 AS streamAnalyticsTime
INTO [ADLSColdPath]
FROM [IoTHubInput]
TIMESTAMP BY EventEnqueuedUtcTime;


-- ═══════════════════════════════════════════════════════════════════════════
-- QUERY 2: ANOMALY DETECTION — TumblingWindow 1 phút.
-- Tính TRUNG BÌNH trong cả cửa sổ để tránh false positives từ 1 spike ngắn.
-- Lý do dùng TumblingWindow: Không overlap — mỗi event thuộc 1 cửa sổ, không đếm trùng.
-- HAVING lọc chỉ những cửa sổ vượt ngưỡng trung bình — ghi vào anomalies/ để phân tích.
-- ═══════════════════════════════════════════════════════════════════════════
SELECT
    GetRecordPropertyValue(metadata, 'machineId')                                    AS machineId,
    IoTHub.ConnectionDeviceId                                                        AS deviceId,
    System.Timestamp()                                                               AS windowEndTime,
    AVG(CAST(GetRecordPropertyValue(telemetry, 'temperature') AS FLOAT))             AS avgTemperature,
    MAX(CAST(GetRecordPropertyValue(telemetry, 'temperature') AS FLOAT))             AS maxTemperature,
    AVG(CAST(GetRecordPropertyValue(telemetry, 'vibration') AS FLOAT))               AS avgVibration,
    MAX(CAST(GetRecordPropertyValue(telemetry, 'vibration') AS FLOAT))               AS maxVibration,
    AVG(CAST(GetRecordPropertyValue(telemetry, 'powerConsumption') AS FLOAT))        AS avgPowerConsumption,
    COUNT(*)                                                                         AS eventCount,
    'ANOMALY_WINDOW'                                                                 AS recordType
INTO [ADLSAnomalyPath]
FROM [IoTHubInput]
TIMESTAMP BY EventEnqueuedUtcTime
GROUP BY
    IoTHub.ConnectionDeviceId,
    GetRecordPropertyValue(metadata, 'machineId'),
    TumblingWindow(minute, 1)
HAVING
    AVG(CAST(GetRecordPropertyValue(telemetry, 'temperature') AS FLOAT)) > 75.0
    OR AVG(CAST(GetRecordPropertyValue(telemetry, 'vibration') AS FLOAT)) > 0.7;


-- ═══════════════════════════════════════════════════════════════════════════
-- QUERY 3: THRESHOLD ALERT — TumblingWindow 30 giây → ghi alert vào SQL.
-- Lý do window 30s: SLA = phát hiện trong 60s. 30s window + ~15s ASA latency < 60s.
-- Severity CRITICAL khi vượt ngưỡng cực cao — để ưu tiên xử lý khẩn cấp.
-- ═══════════════════════════════════════════════════════════════════════════
SELECT
    IoTHub.ConnectionDeviceId                                                        AS DeviceId,
    GetRecordPropertyValue(metadata, 'machineId')                                    AS MachineId,
    CASE
        WHEN MAX(CAST(GetRecordPropertyValue(telemetry, 'temperature') AS FLOAT)) > 85.0
             AND MAX(CAST(GetRecordPropertyValue(telemetry, 'vibration') AS FLOAT)) > 0.9
             THEN 'HIGH_TEMP_AND_VIBRATION'
        WHEN MAX(CAST(GetRecordPropertyValue(telemetry, 'temperature') AS FLOAT)) > 85.0
             THEN 'HIGH_TEMPERATURE'
        WHEN MAX(CAST(GetRecordPropertyValue(telemetry, 'vibration') AS FLOAT)) > 0.9
             THEN 'HIGH_VIBRATION'
        ELSE 'POWER_SURGE'
    END                                                                              AS AlertType,
    MAX(CAST(GetRecordPropertyValue(telemetry, 'temperature') AS FLOAT))             AS Temperature,
    MAX(CAST(GetRecordPropertyValue(telemetry, 'vibration') AS FLOAT))               AS Vibration,
    MAX(CAST(GetRecordPropertyValue(telemetry, 'powerConsumption') AS FLOAT))        AS PowerConsumption,
    DATEADD(second, -30, System.Timestamp())                                         AS WindowStart,
    System.Timestamp()                                                               AS WindowEnd,
    COUNT(*)                                                                         AS EventCount,
    CASE
        WHEN MAX(CAST(GetRecordPropertyValue(telemetry, 'temperature') AS FLOAT)) > 92.0
             OR MAX(CAST(GetRecordPropertyValue(telemetry, 'vibration') AS FLOAT)) > 1.1
             THEN 'CRITICAL'
        ELSE 'WARNING'
    END                                                                              AS Severity
INTO [SQLAlerts]
FROM [IoTHubInput]
TIMESTAMP BY EventEnqueuedUtcTime
GROUP BY
    IoTHub.ConnectionDeviceId,
    GetRecordPropertyValue(metadata, 'machineId'),
    TumblingWindow(second, 30)
HAVING
    MAX(CAST(GetRecordPropertyValue(telemetry, 'temperature') AS FLOAT)) > 85.0
    OR MAX(CAST(GetRecordPropertyValue(telemetry, 'vibration') AS FLOAT)) > 0.9
    OR MAX(CAST(GetRecordPropertyValue(telemetry, 'powerConsumption') AS FLOAT)) > 200.0;
```

Click **Save query** → **Overview** → **Start** → **Now** → **Start**. Chờ ~2 phút để job Running.

---

## Phase 5: Output Routing — Xác nhận Data Flows

> **Purpose:** Kiểm tra từng đầu ra hoạt động đúng: ADLS nhận data thô, ADLS nhận anomaly windows, SQL nhận alerts. Đây là bước "proof of correctness" của kiến trúc.
>
> **Why does this matter?** Trong SLA production, nếu cold-path dừng ghi mà không ai biết, bạn mất months của audit trail. Monitoring từng output là bắt buộc.

> **🧠 Kiến thức nền tảng: Lambda vs Kappa Architecture — TechManufacture dùng cái nào?**
>
> **Lambda Architecture** (Jay Kreps, 2011): Xử lý data theo 2 đường song song — **batch layer** (xử lý chính xác nhưng chậm, hàng giờ/ngày) và **speed layer** (xử lý gần real-time nhưng approximate). Kết quả từ 2 layers được merge lại. Ưu điểm: batch layer luôn có thể correct lỗi của speed layer. Nhược điểm: duy trì 2 codebase song song, phức tạp.
>
> **Kappa Architecture** (Jay Kreps, 2014): Chỉ có **1 streaming layer** duy nhất. Khi cần reprocess, replay lại toàn bộ event stream từ đầu qua pipeline mới. Đơn giản hơn, nhưng đòi hỏi event store phải lưu lâu (IoT Hub mặc định 1-7 ngày tùy tier).
>
> **TechManufacture dùng biến thể Kappa**: Stream Analytics xử lý real-time (speed layer), ADLS Gen2 cold-path lưu raw events để reprocess khi cần (replay thay cho batch layer). Đây là kiến trúc phổ biến nhất trong Azure ecosystem hiện nay vì Stream Analytics đủ mạnh để làm cả hai vai trò.

### Bước 5.1: Xác nhận ADLS Gen2 Cold Path

1. Storage Account → **Containers** → `cold-path` → Duyệt vào thư mục `YYYY/MM/DD/HH/`.
2. Sau 5 phút, bạn sẽ thấy file JSON được tạo tự động.

> **Troubleshooting:** Nếu sau 5 phút không có file, vào Stream Analytics → **Monitoring** → **Metrics** → Metric **Output Events**. Nếu = 0, kiểm tra query syntax và output configuration. Nếu > 0 nhưng không thấy file, kiểm tra Managed Identity IAM permissions.

### Bước 5.2: Xác nhận Azure SQL Alerts

SQL → **Query editor**:
```sql
SELECT TOP 20
    AlertId, DeviceId, MachineId, AlertType, Severity,
    ROUND(Temperature, 2) AS Temperature,
    ROUND(Vibration, 3)   AS Vibration,
    WindowEnd             AS AlertTime,
    EventCount
FROM Alerts.SensorAlert
ORDER BY AlertId DESC;
```

### Bước 5.3: (Tùy chọn) Power BI Real-Time Dashboard

1. **Power BI Desktop** → **Get Data** → **Azure SQL Database**.
2. Server: `sqlserver-techmfg-[suffix].database.windows.net`, Database: `sqldb-techmfg-alerts`.
3. Mode: **DirectQuery** _(không phải Import — DirectQuery query live data, không cache)_.
4. Load `Alerts.SensorAlert` → Tạo Table Visual với: `DeviceId`, `AlertType`, `Severity`, `Temperature`, `AlertTime`.
5. View → Performance Analyzer → Set auto-refresh 60 giây.

---

## Phase 6: End-to-End Testing — Inject Anomaly và Xác nhận Pipeline

> **Purpose:** Kiểm chứng toàn bộ pipeline bằng cách inject dữ liệu bất thường có kiểm soát và xác nhận đi đúng đường qua từng layer trong đúng thời gian SLA.
>
> **Why does this matter?** Trong SLA production, bạn phải có automated E2E tests sau mỗi deploy. Tests này validate: (1) data đến IoT Hub, (2) Stream Analytics xử lý đúng threshold, (3) Alert xuất hiện trong SQL đúng thời hạn, (4) Cold-path không bị thiếu.

### Bước 6.1: Inject Anomaly có kiểm soát

Tạo file `e2e_test.py`:

```python
"""E2E Test: Inject anomaly có kiểm soát để validate pipeline end-to-end."""

import json
import os
import time
from datetime import datetime, timezone
from azure.iot.device import IoTHubDeviceClient, Message

DEVICE_CONN_STR = os.environ.get("IOTHUB_DEVICE_CONNECTION_STRING", "YOUR_CONN_STRING")

TEST_CASES = [
    ("HIGH_TEMPERATURE",  {"temperature": 91.5, "vibration": 0.3,  "powerConsumption": 145.0}, "WARNING"),
    ("HIGH_VIBRATION",    {"temperature": 68.0, "vibration": 1.05, "powerConsumption": 142.0}, "WARNING"),
    ("CRITICAL_COMBINED", {"temperature": 93.2, "vibration": 1.15, "powerConsumption": 205.0}, "CRITICAL"),
]

def inject_test_messages(client, alert_type: str, telemetry: dict, expected_severity: str):
    """Gửi 5 messages liên tiếp để đảm bảo nằm trong TumblingWindow 30s."""
    print(f"\n📋 Test: {alert_type} | Expected severity: {expected_severity}")
    for i in range(5):
        payload = {
            "deviceId": "sensor-machine-001",
            "machineId": "LINE-A-CNC-01",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "telemetry": telemetry,
            "metadata": {"firmwareVersion": "2.1.4", "sensorType": "industrial-triaxis", "location": "factory-floor-zone-a"},
        }
        msg = Message(json.dumps(payload))
        msg.content_type = "application/json"
        msg.content_encoding = "utf-8"
        client.send_message(msg)
        print(f"   📤 Sent message {i+1}/5 | temp={telemetry['temperature']}°C | vib={telemetry['vibration']}g")
        time.sleep(1)
    print(f"   ⏳ Waiting 40s for Stream Analytics window to close...")
    time.sleep(40)

if __name__ == "__main__":
    print("🧪 E2E Test Suite: Connecting...")
    client = IoTHubDeviceClient.create_from_connection_string(DEVICE_CONN_STR)
    client.connect()
    print("✅ Connected.\n")

    for alert_type, telemetry, expected_severity in TEST_CASES:
        inject_test_messages(client, alert_type, telemetry, expected_severity)

    client.shutdown()
    print("\n✅ All test messages injected. Run SQL verification query now.")
```

```bash
python e2e_test.py
```

### Bước 6.2: Xác nhận Alert trong SQL

```sql
-- Verify E2E test results
SELECT
    AlertId, DeviceId, AlertType, Severity,
    ROUND(Temperature, 2) AS Temperature,
    ROUND(Vibration, 3)   AS Vibration,
    EventCount,
    WindowEnd             AS AlertTime,
    DATEDIFF(SECOND, WindowEnd, GETUTCDATE()) AS SecondsAgo
FROM Alerts.SensorAlert
WHERE CreatedAt > DATEADD(MINUTE, -15, GETUTCDATE())
ORDER BY AlertId DESC;
```

**Kết quả kỳ vọng:**

| AlertType | Severity | Temperature | Vibration | SecondsAgo |
|-----------|----------|-------------|-----------|-----------|
| HIGH_TEMP_AND_VIBRATION | CRITICAL | 93.2 | 1.15 | ~60 |
| HIGH_VIBRATION | WARNING | 68.0 | 1.05 | ~100 |
| HIGH_TEMPERATURE | WARNING | 91.5 | 0.30 | ~140 |

### Bước 6.3: Xác nhận Cold Path và Anomaly Path

1. `cold-path` container: File JSON mới nhất phải chứa events từ test.
2. `anomalies` container: Nếu avgTemp > 75°C trong cửa sổ 1 phút, file JSON phải xuất hiện.
3. Stream Analytics → **Monitoring** → **Metrics** → Verify Output Events cho cả 3 outputs đều > 0.

---

## Phase 7: Dọn dẹp Tài nguyên (Cleanup)

> **Purpose:** Xóa toàn bộ hạ tầng để Azure ngừng tính phí. Đây là thói quen bắt buộc sau mọi lab thực hành.
>
> **Why does this matter?** Stream Analytics, IoT Hub S1, và Azure SQL là paid services. Quên tắt trong 1 tuần = mất ~$50–100 USD không cần thiết.

### Bước 7.1: Dừng Services trước

**Stop Stream Analytics Job:**
1. Mở job → **Overview** → **Stop** → Confirm. Chờ status **Stopped**.

**Stop Python Simulator:**
2. Terminal simulator → **Ctrl + C** → Script gracefully shutdown, log tổng messages đã gửi.

### Bước 7.2: Xóa Resource Group

1. [portal.azure.com](https://portal.azure.com) → **Resource groups** → `rg-techmanufacture-iot-001`.
2. Click **Delete resource group** → Gõ xác nhận: `rg-techmanufacture-iot-001` → **Delete**.
3. Quá trình xóa: **5–10 phút**. Azure notification khi hoàn tất.

> ⚠️ **Lưu ý:** Mọi dữ liệu trong ADLS, SQL, và IoT Hub sẽ mất vĩnh viễn. Download/export trước nếu muốn giữ lại.

---

## Tổng kết — Kiến thức Then Chốt

Bạn vừa xây dựng một hệ thống IoT enterprise-grade hoàn chỉnh. Đây là tóm tắt các quyết định thiết kế quan trọng và lý do tại sao:

| Quyết định | Lý do | Hệ quả nếu bỏ qua |
|-----------|-------|-------------------|
| **IoT Hub thay vì Event Hubs** | Device identity, Twin, Direct Methods | Không thể emergency shutdown từ xa, không biết device nào gửi sai data |
| **Key Vault + Managed Identity** | Zero hardcoded secrets | Secret bị leak → fake data injection, phá vỡ sản xuất |
| **TumblingWindow 30s cho alerts** | SLA < 60s, không đếm trùng | SlidingWindow gây quá nhiều SQL writes; 60s window vi phạm SLA |
| **ADLS cold path song song** | Replay/reprocess khi cần | Bug trong Stream Analytics = mất data vĩnh viễn, không khôi phục được |
| **Exponential backoff trong Python** | Network factory không ổn định | Thundering herd khi IoT Hub overloaded, cascade failure |
| **Hierarchical Namespace ADLS** | Folder-level permissions, fast rename | Không thể phân quyền granular, rename petabyte folder mất hàng tiếng |

**Bước tiếp theo để nâng cấp Production:**
- 🔒 IoT Hub Private Endpoint (loại bỏ public internet exposure)
- 📊 Azure Monitor Alerts khi SQL alert count tăng đột biến (gửi Teams/SMS)
- 🤖 Azure Machine Learning để train predictive maintenance từ cold-path data
- 🔄 Dead Letter Queue xử lý malformed messages từ sensor firmware lỗi
- 📦 Docker container cho simulator, deploy lên Azure IoT Edge tại nhà máy
- 🏭 Device Provisioning Service (DPS) để auto-provision 1.000 sensors không cần portal

---

*Lab được thiết kế theo chuẩn Microsoft Azure Well-Architected Framework — Security, Reliability, Performance Efficiency, và Operational Excellence pillars.*
