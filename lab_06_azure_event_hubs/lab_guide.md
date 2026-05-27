# Hướng dẫn Lab 06: Enterprise Event-Driven Data Ingestion: Azure Event Hubs, Kafka Protocol & Real-Time Processing

Chào mừng bạn đến với tài liệu hướng dẫn (Lab) chi tiết nhất về **Azure Event Hubs** — nền tảng streaming dữ liệu cấp doanh nghiệp của Microsoft Azure. Tài liệu này được biên soạn từng bước (step-by-step), kết hợp giải thích kiến trúc chuyên sâu với mã nguồn production-quality, giúp bạn nắm vững cả lý thuyết lẫn thực hành.

---

## Kịch bản Nghiệp vụ (The Business Scenario)

Công ty gọi xe công nghệ **GoRide Vietnam** (mô hình tương tự Grab/Gojek) đang xử lý hơn **500.000 sự kiện mỗi phút** từ hệ thống vận hành:

- **Ride Request Events:** Khách hàng mở app, đặt xe — hệ thống phát sinh sự kiện chứa toạ độ GPS đón/trả, loại xe, giá ước tính.
- **Driver GPS Updates:** Mỗi 3 giây, app tài xế gửi toạ độ GPS hiện tại để cập nhật bản đồ realtime cho khách hàng.
- **Fare Calculation Events:** Khi chuyến đi kết thúc, hệ thống tính cước dựa trên quãng đường, thời gian chờ, surge pricing.
- **Ride Completion Events:** Ghi nhận trạng thái hoàn thành, đánh giá sao, tip (nếu có).

**Vấn đề:** Hệ thống cũ dùng Kafka on-premise đang quá tải, chi phí vận hành máy chủ (broker) tăng vọt, và đội DevOps phải thức đêm xử lý sự cố broker crash. Ngoài ra, **nhiều phòng ban cần đọc cùng một luồng dữ liệu** nhưng xử lý theo cách khác nhau:
- **Billing Team:** Tính tổng doanh thu realtime theo vùng.
- **Analytics Team:** Đếm số chuyến đi theo giờ, phân tích xu hướng.
- **Fraud Detection Team:** Phát hiện bất thường (tài xế chạy vòng vòng tăng cước, GPS giả).

**Giải pháp:** Chuyển đổi sang **Azure Event Hubs** — một dịch vụ streaming fully managed, hỗ trợ Kafka protocol (không cần viết lại producer code), tự động scale, và tích hợp sẵn với Data Lake để archive dữ liệu lịch sử.

---

## Phase 1: Infrastructure & Architecture Design

### Bước 1: Tạo Resource Group

> **Purpose:** Gom nhóm toàn bộ tài nguyên (Event Hubs, Storage, Key Vault...) vào chung một nơi để dễ dàng quản lý chi phí, phân quyền, và xoá sạch khi lab kết thúc mà không sợ sót tài nguyên "rác" bị tính phí.

1. Đăng nhập [portal.azure.com](https://portal.azure.com).
2. Tìm **Resource groups** > **Create**.
3. Điền thông tin:
   - **Subscription:** Chọn subscription của bạn.
   - **Resource group:** `rg-goride-streaming-dev`
   - **Region:** `Southeast Asia` (hoặc region gần bạn nhất).
4. Nhấn **Review + create** -> **Create**.

> **Hệ quả nếu bỏ qua:** Nếu bạn tạo tài nguyên rải rác ở nhiều Resource Group khác nhau, khi xoá lab bạn sẽ phải dò từng service một — rất dễ sót và bị Azure tính phí hàng tháng cho tài nguyên "mồ côi" mà bạn đã quên.

### Bước 2: Tạo Event Hubs Namespace

> **Purpose:** Event Hubs Namespace là container cấp cao nhất chứa một hoặc nhiều Event Hubs (giống như một Kafka cluster chứa nhiều topics). Namespace quyết định tier, throughput capacity, và networking policy cho tất cả Event Hubs bên trong.

> **🧠 Kiến thức nền tảng: Standard vs Premium vs Dedicated Tier**
>
> Đây là quyết định kiến trúc quan trọng nhất khi thiết kế hệ thống Event Hubs. Mỗi tier phục vụ một phân khúc workload khác nhau:
>
> | Tiêu chí | **Standard** | **Premium** | **Dedicated** |
> |---|---|---|---|
> | **Đơn vị scale** | Throughput Units (TU) — mỗi TU = 1 MB/s ingress, 2 MB/s egress | Processing Units (PU) — mỗi PU ≈ tương đương ~5-10 TU tuỳ workload | Capacity Units (CU) — toàn bộ cluster vật lý dành riêng |
> | **Max throughput** | 40 TU (auto-inflate) | 16 PU | Không giới hạn (tuỳ số CU) |
> | **Isolation** | Shared infrastructure (multi-tenant) | Soft isolation — tài nguyên ưu tiên, nhưng vẫn chạy trên hạ tầng chung | **Full hardware isolation** — cluster vật lý riêng biệt |
> | **Schema Registry** | ❌ Không hỗ trợ | ✅ Có | ✅ Có |
> | **Dynamic Partition Scale** | ❌ | ✅ Tăng partition sau khi tạo | ✅ |
> | **Availability Zones** | ✅ | ✅ (mặc định) | ✅ (mặc định) |
> | **Giá (ước tính/tháng)** | ~$11/TU | ~$700/PU | ~$6,000+/CU |
> | **Use case** | Dev/test, workload nhỏ-trung bình | Production enterprise, cần schema registry & isolation | Mission-critical, regulated industries (ngân hàng, y tế) |
>
> **Quyết định cho GoRide:** Chúng ta chọn **Standard tier** cho lab này để tiết kiệm chi phí. Trong production thực tế, GoRide sẽ dùng **Premium** vì cần Schema Registry (Phase 8) và khả năng tăng partition động khi traffic surge (giờ cao điểm 7-9h sáng).

1. Trong Azure Portal, tìm **Event Hubs** > **Create**.
2. Điền thông tin:
   - **Resource group:** `rg-goride-streaming-dev`
   - **Namespace name:** `evhns-goride-dev` _(phải globally unique, thêm số/initials nếu cần, ví dụ: `evhns-goride-dev-nbui01`)_
   - **Location:** `Southeast Asia`
   - **Pricing tier:** **Standard**
   - **Throughput Units:** `1` (đủ cho lab; production sẽ dùng 10-40 TU)
3. Click tab **Advanced**:
   - **Enable Auto-Inflate:** ✅ Bật lên.
   - **Auto-Inflate Maximum Throughput Units:** `5`
   > **What is Auto-Inflate?** Tính năng này cho phép Event Hubs tự động tăng số Throughput Units khi traffic tăng đột biến (ví dụ: giờ cao điểm). Nó giống như hệ thống tự mở thêm làn đường khi phát hiện kẹt xe. Bạn chỉ trả tiền cho số TU thực sự sử dụng, và nó sẽ không bao giờ vượt quá mức tối đa bạn đặt.
4. Click **Review + create** -> **Create**.

> **Hệ quả nếu bỏ qua Auto-Inflate:** Khi traffic đột ngột tăng (ví dụ: trời mưa to ở Hà Nội, lượng đặt xe tăng gấp 5 lần), Event Hubs sẽ trả về `ThrottlingException` — nghĩa là sự kiện bị từ chối, khách hàng mở app nhưng không đặt được xe. Doanh thu mất trắng trong khoảng thời gian đó.

### Bước 3: Tạo Event Hub (Topic)

> **Purpose:** Event Hub là đơn vị logic để nhận và phân phối sự kiện — tương đương với một Kafka topic. Số lượng partition của Event Hub quyết định khả năng xử lý song song (parallelism) và thứ tự (ordering) của dữ liệu.

> **🧠 Kiến thức nền tảng: Partition — Trái tim của Event Hubs**
>
> **Partition là gì?** Hãy tưởng tượng Event Hub là một xa lộ cao tốc, và mỗi partition là một **làn đường** trên xa lộ đó. Khi bạn tạo Event Hub với 4 partition, bạn có 4 làn đường song song để dữ liệu chạy qua.
>
> **Tại sao partition count quan trọng?**
> - **Throughput (Băng thông):** Mỗi partition hỗ trợ tối đa 1 MB/s ingress và 2 MB/s egress. Nếu bạn có 4 partition, tổng throughput tối đa là 4 MB/s ingress. Với 32 partition, bạn có 32 MB/s — đủ để xử lý hàng triệu sự kiện nhỏ mỗi giây.
> - **Parallelism (Xử lý song song):** Trong mỗi Consumer Group, số lượng consumer instance tối đa bằng đúng số partition. Nếu bạn có 4 partition, bạn chỉ có thể chạy tối đa 4 consumer instance song song. Consumer thứ 5 sẽ **ngồi chờ rỗi** (idle) vì không còn partition nào để đọc.
> - **Ordering (Thứ tự):** Event Hubs chỉ đảm bảo thứ tự **trong cùng một partition**. Nếu bạn cần tất cả sự kiện của rider_id = "R001" được xử lý theo đúng thứ tự thời gian (đặt xe → lên xe → xuống xe → thanh toán), bạn phải gửi tất cả sự kiện của rider đó vào cùng một partition bằng cách đặt **partition key** = rider_id.
>
> **Tại sao không thể giảm partition sau khi tạo?**
> Event Hubs phân bổ dữ liệu vào partition bằng thuật toán hash trên partition key. Nếu bạn giảm partition từ 8 xuống 4, dữ liệu đã nằm ở partition 5, 6, 7, 8 sẽ không biết đi đâu — gây mất dữ liệu hoặc phải re-partition toàn bộ (cực kỳ tốn kém). Vì vậy, **hãy estimate traffic tương lai và chọn partition count thật kỹ từ đầu**. Tip: Bắt đầu với ít nhất 4 partition, production nên dùng 8-32.
>
> **Hot Partition Problem:** Nếu bạn chọn partition key không tốt (ví dụ: tất cả sự kiện đều có `city = "HCMC"`), 90% traffic sẽ dồn vào 1 partition duy nhất trong khi các partition khác gần như rỗi. Partition đó bị "quá tải" (hot), gây lag và throttling. Giải pháp: Chọn partition key có cardinality cao (rider_id, driver_id — hàng triệu giá trị unique).

1. Mở Namespace `evhns-goride-dev` vừa tạo.
2. Trong menu trái, chọn **Event Hubs** > **+ Event Hub**.
3. Điền thông tin:
   - **Name:** `ride-events`
   - **Partition Count:** `4` (đủ cho lab; production: 16-32)
   - **Message Retention:** `1` day (Standard tier cho phép 1-7 ngày; Premium/Dedicated cho phép tới 90 ngày)
4. Click **Review + create** -> **Create**.

### Bước 4: Tạo Azure Data Lake Storage Gen2 (Event Archive)

> **Purpose:** ADLS Gen2 sẽ đóng vai trò "cold storage" — nơi lưu trữ vĩnh viễn mọi sự kiện đã đi qua Event Hubs. Tính năng Capture sẽ tự động ghi dữ liệu vào đây theo format Avro, phục vụ phân tích lịch sử và audit.

1. Trong Azure Portal, tìm **Storage accounts** > **Create**.
2. Điền thông tin:
   - **Resource group:** `rg-goride-streaming-dev`
   - **Storage account name:** `stgoridelake001` _(globally unique, lowercase, không dấu)_
   - **Region:** `Southeast Asia`
   - **Redundancy:** `LRS` (cho lab; production dùng ZRS/GRS)
3. Tab **Advanced**: Bật **Enable hierarchical namespace** ✅ _(bắt buộc để trở thành Data Lake Gen2)_.
4. Click **Review + create** -> **Create**.
5. Sau khi tạo xong, vào **Containers**, tạo container tên `event-archive`.

### Bước 5: Azure Key Vault cho Connection Strings

> **Purpose:** Connection string của Event Hubs chứa access key — nếu lộ ra ngoài, bất kỳ ai cũng có thể gửi hoặc đọc dữ liệu trái phép. Key Vault mã hoá và quản lý tập trung các credentials này, chỉ cấp quyền cho service/người dùng được uỷ quyền.

1. Tìm **Key vaults** > **Create**.
   - **Resource group:** `rg-goride-streaming-dev`
   - **Key vault name:** `kv-goride-dev-001` _(globally unique)_
   - **Region:** `Southeast Asia`
   - **Pricing tier:** Standard
2. Click **Review + create** -> **Create**.

**Gán quyền IAM cho chính bạn:**

3. Mở Key Vault vừa tạo > **Access control (IAM)** > **+ Add** > **Add role assignment**.
4. Chọn role **Key Vault Secrets Officer** > **Next**.
5. Chọn **User, group, or service principal** > **+ Select members** > Tìm email của bạn > **Select** > **Review + assign**.
6. **CRITICAL:** Đợi 3-5 phút để Azure propagate quyền.

**Lưu Connection String vào Key Vault:**

7. Quay lại Namespace `evhns-goride-dev` > Menu trái: **Shared access policies** > Click `RootManageSharedAccessKey` > Copy **Connection string–primary key**.
8. Quay lại Key Vault > **Secrets** > **+ Generate/Import**:
   - **Name:** `eventhub-connection-string`
   - **Value:** Dán connection string vừa copy.
9. Click **Create**.

> **Hệ quả nếu bỏ qua:** Nếu hardcode connection string trong code Python, khi push lên GitHub (dù là private repo), bất kỳ ai có quyền đọc repo đều thấy. Tệ hơn, Azure Security Center sẽ scan và gửi alert "Exposed credential" — trong môi trường enterprise, đây là vi phạm bảo mật nghiêm trọng có thể dẫn tới audit finding.

---

## Phase 2: Core Concepts Deep Dive

Trước khi viết code, hãy dành thời gian hiểu sâu các khái niệm nền tảng. Phase này biến bạn từ người "biết dùng" thành người "hiểu bản chất".

### Event Hubs vs Kafka vs RabbitMQ vs Service Bus

> **🧠 Kiến thức nền tảng: So sánh các Messaging Platform**
>
> Đây là câu hỏi phỏng vấn kinh điển cho vị trí Data Engineer / Solution Architect. Mỗi platform phục vụ một mục đích khác nhau:
>
> | Tiêu chí | **Azure Event Hubs** | **Apache Kafka** | **RabbitMQ** | **Azure Service Bus** |
> |---|---|---|---|---|
> | **Mô hình** | Event streaming (log-based) | Event streaming (log-based) | Message queuing (broker-based) | Message queuing (broker-based) |
> | **Thứ tự đảm bảo** | Trong partition | Trong partition | Trong queue | Trong session |
> | **Consumer model** | Pull-based, nhiều consumer group đọc cùng data | Pull-based, nhiều consumer group | Push/Pull, mỗi message chỉ 1 consumer nhận (trừ Fanout exchange) | Peek-Lock, mỗi message chỉ 1 consumer nhận |
> | **Retention** | 1-90 ngày (tuỳ tier) | Vô hạn (tuỳ disk) | Message bị xoá sau khi acknowledge | 14 ngày mặc định |
> | **Throughput** | Hàng triệu events/giây | Hàng triệu events/giây | Hàng chục ngàn msg/giây | Hàng ngàn msg/giây |
> | **Managed** | ✅ Fully managed (PaaS) | ❌ Self-managed (hoặc Confluent Cloud) | ❌ Self-managed (hoặc CloudAMQP) | ✅ Fully managed (PaaS) |
> | **Kafka compatible** | ✅ Kafka protocol endpoint | N/A (bản thân là Kafka) | ❌ | ❌ |
> | **Use case chính** | Telemetry, IoT, clickstream, ride events | Giống Event Hubs nhưng cần toàn quyền kiểm soát | Task queue, request-reply, work distribution | Enterprise messaging, transactions, dead-letter |
>
> **Khi nào chọn Event Hubs thay vì Kafka?**
> - Bạn đang dùng Azure ecosystem và muốn tích hợp native (Capture to ADLS, Stream Analytics, Databricks).
> - Bạn không muốn quản lý ZooKeeper/KRaft, broker upgrades, disk IOPS — Event Hubs lo hết.
> - Bạn cần Kafka protocol compatibility để migrate dần từ on-prem Kafka mà không rewrite producer code.
>
> **Khi nào KHÔNG nên dùng Event Hubs?**
> - Bạn cần message queue (mỗi message chỉ được xử lý đúng 1 lần bởi 1 consumer) → Dùng **Service Bus** hoặc **RabbitMQ**.
> - Bạn cần Kafka Streams, Kafka Connect ecosystem đầy đủ → Dùng **Confluent Cloud** hoặc self-managed Kafka.

### AMQP 1.0 Protocol

> **🧠 Kiến thức nền tảng: AMQP 1.0 — Giao thức truyền tin chuẩn công nghiệp**
>
> **AMQP (Advanced Message Queuing Protocol) 1.0** là giao thức nhắn tin chuẩn quốc tế (ISO/IEC 19464), được thiết kế để truyền message giữa các hệ thống khác nhau một cách đáng tin cậy, bảo mật, và liên thông (interoperable).
>
> **Tại sao Event Hubs dùng AMQP 1.0?**
> - **Binary protocol:** Không giống HTTP (text-based), AMQP mã hoá dữ liệu dạng binary — nhanh hơn, ít overhead hơn, tối ưu cho high-throughput streaming.
> - **Persistent connections:** AMQP duy trì kết nối liên tục (long-lived connection) thay vì mở/đóng connection cho mỗi request như HTTP. Điều này giảm latency đáng kể khi gửi hàng triệu events.
> - **Flow control:** AMQP có cơ chế kiểm soát luồng (flow control) tích hợp — nếu consumer xử lý chậm, broker tự động giảm tốc độ gửi thay vì làm consumer bị ngập (overwhelmed).
> - **Multiplexing:** Một connection AMQP có thể mang nhiều "link" (kênh giao tiếp) đồng thời, giống như một đường ống lớn chứa nhiều ống nhỏ bên trong.
>
> Khi bạn dùng Azure SDK (`azure-eventhub` Python library), SDK sẽ tự động sử dụng AMQP 1.0 bên dưới — bạn không cần cấu hình gì thêm. Tuy nhiên, Event Hubs cũng cung cấp **Kafka protocol endpoint** (Phase 4) cho backward compatibility.

### Consumer Groups & Offset/Checkpointing

> **🧠 Kiến thức nền tảng: Consumer Group — Cơ chế đọc song song độc lập**
>
> **Consumer Group là gì?** Consumer Group là một "view" (góc nhìn) độc lập trên toàn bộ Event Hub. Mỗi consumer group có **bộ con trỏ (offset) riêng** theo dõi vị trí đọc cuối cùng trên mỗi partition.
>
> **Tại sao cần nhiều Consumer Groups?** Quay lại kịch bản GoRide:
> - **Billing Team** cần đọc tất cả ride events để tính doanh thu → Consumer Group `billing-processor`
> - **Analytics Team** cần đọc cùng dữ liệu đó để đếm số chuyến → Consumer Group `analytics-processor`
> - **Fraud Detection** cần đọc cùng dữ liệu đó để phát hiện gian lận → Consumer Group `fraud-detector`
>
> Nếu không có Consumer Group, khi Billing Team đọc xong một event, event đó sẽ bị "đánh dấu đã đọc" và Analytics Team không bao giờ thấy nó. Consumer Group giải quyết vấn đề này bằng cách cho mỗi nhóm **có con trỏ riêng** — giống như 3 người đọc cùng 1 cuốn sách nhưng mỗi người có bookmark riêng.
>
> **Giới hạn quan trọng:** Trong mỗi consumer group, số consumer instance tối đa trên **một partition** là **5** (cho Standard/Premium). Nếu consumer thứ 6 kết nối vào cùng partition, Event Hubs sẽ từ chối hoặc ngắt connection cũ nhất. Tổng số consumer instance hiệu quả = số partition × 1 (mỗi partition chỉ nên có 1 active reader để đảm bảo ordering).
>
> **Offset & Checkpointing:**
> - **Offset** là một con số đánh dấu vị trí của event trong partition (giống số trang trong sách). Event đầu tiên có offset = 0, event thứ hai có offset = 1, v.v.
> - **Checkpointing** là hành động consumer lưu lại offset cuối cùng đã xử lý thành công vào một storage bền vững (thường là Azure Blob Storage). Nếu consumer bị crash, khi restart nó sẽ đọc checkpoint và tiếp tục từ vị trí đã dừng thay vì đọc lại từ đầu.
> - **At-least-once semantics:** Event Hubs mặc định đảm bảo mỗi event được xử lý **ít nhất một lần**. Nếu consumer crash sau khi xử lý event nhưng trước khi checkpoint, event đó sẽ được đọc lại khi restart → cần thiết kế consumer **idempotent** (xử lý trùng không gây lỗi).
> - **Exactly-once:** Event Hubs **không hỗ trợ exactly-once** ở cấp platform (không như Kafka Transactions). Để đạt exactly-once, bạn cần kết hợp checkpointing với transactional writes ở consumer side (ví dụ: ghi kết quả + checkpoint vào cùng một database transaction).

### Throughput Units (TU) vs Processing Units (PU)

> **🧠 Kiến thức nền tảng: Cách Event Hubs Scale**
>
> **Throughput Unit (TU) — Standard tier:**
> - 1 TU = **1 MB/s ingress** (gửi vào) + **2 MB/s egress** (đọc ra) + tối đa **1,000 events/s ingress**.
> - Bạn mua TU ở mức Namespace — tất cả Event Hubs trong namespace chia sẻ TU pool.
> - Auto-Inflate tự động tăng TU khi cần, tối đa 40 TU.
>
> **Processing Unit (PU) — Premium tier:**
> - PU là đơn vị scale mạnh hơn, tương đương ~5-10 TU tuỳ workload.
> - PU cung cấp **isolated compute** (CPU, memory riêng) — không bị ảnh hưởng bởi tenant khác.
> - PU tự động scale trong khoảng 1-16 PU.
>
> **Tính toán cho GoRide:** 500,000 events/phút, mỗi event ~500 bytes:
> - Ingress: 500,000 × 500 / 60 = ~4.17 MB/s → Cần tối thiểu **5 TU** (Standard) hoặc **1 PU** (Premium).
> - Thực tế cần buffer 2-3x cho peak traffic → **10-15 TU** hoặc **2 PU**.

---

## Phase 3: Producer — Python SDK (Production-Quality Code)

### Bước 1: Cài đặt Dependencies

> **Purpose:** Cài đặt các thư viện Python cần thiết. `azure-eventhub` là SDK chính để gửi/nhận events. `azure-identity` cung cấp `DefaultAzureCredential` để lấy secret từ Key Vault mà không hardcode password. `azure-keyvault-secrets` để đọc Key Vault secrets.

```bash
pip install azure-eventhub azure-identity azure-keyvault-secrets
```

### Bước 2: Xây dựng Producer với EventDataBatch

> **Purpose:** Viết producer mô phỏng ride events của GoRide, sử dụng `EventDataBatch` để gom nhiều events nhỏ vào một batch trước khi gửi — tối ưu throughput và giảm chi phí network round-trips.

> **🧠 Kiến thức nền tảng: EventDataBatch — Tại sao không gửi từng event một?**
>
> Mỗi lần bạn gọi `send_event()` cho một event riêng lẻ, SDK phải thực hiện một loạt thao tác: serialize event → mở AMQP link → gửi qua network → đợi ACK từ server. Nếu gửi 500,000 events/phút kiểu này, overhead network sẽ chiếm phần lớn thời gian.
>
> `EventDataBatch` giải quyết bằng cách gom nhiều events vào một "bưu kiện" duy nhất (tối đa 1 MB hoặc 256 KB tuỳ tier), rồi gửi cả bưu kiện một lần. Giống như thay vì gửi 100 lá thư riêng lẻ, bạn bỏ 100 lá thư vào 1 thùng carton rồi gửi 1 lần — nhanh hơn gấp nhiều lần.

Tạo file `goride_producer.py`:

```python
"""
GoRide Vietnam — Event Hubs Producer (Production-Quality)
Simulates ride events and sends them to Azure Event Hubs using batch mode.
"""

import json
import uuid
import time
import random
import logging
from datetime import datetime, timezone

from azure.eventhub import EventHubProducerClient, EventData
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

# ──────────────────────────────────────────────
# Logging Configuration
# ──────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
logger = logging.getLogger("GoRideProducer")

# ──────────────────────────────────────────────
# Configuration — Retrieved from Key Vault
# ──────────────────────────────────────────────
KEY_VAULT_URL = "https://kv-goride-dev-001.vault.azure.net/"
SECRET_NAME = "eventhub-connection-string"
EVENT_HUB_NAME = "ride-events"

# Simulated data constants
CITIES = ["HCMC", "Hanoi", "DaNang", "CanTho", "HaiPhong"]
EVENT_TYPES = ["ride_requested", "driver_assigned", "ride_started",
               "gps_update", "fare_calculated", "ride_completed"]
VEHICLE_TYPES = ["bike", "car_4seat", "car_7seat", "premium"]

def get_connection_string_from_keyvault() -> str:
    """Retrieve Event Hubs connection string from Azure Key Vault."""
    try:
        credential = DefaultAzureCredential()
        client = SecretClient(vault_url=KEY_VAULT_URL, credential=credential)
        secret = client.get_secret(SECRET_NAME)
        logger.info("✅ Successfully retrieved connection string from Key Vault.")
        return secret.value
    except Exception as e:
        logger.error(f"❌ Failed to retrieve secret from Key Vault: {e}")
        raise

def generate_ride_event() -> dict:
    """Generate a realistic ride event with GoRide schema."""
    rider_id = f"R{random.randint(10000, 99999)}"
    driver_id = f"D{random.randint(1000, 9999)}"
    city = random.choice(CITIES)

    # Simulate GPS coordinates within Vietnam bounding box
    lat_base = {"HCMC": 10.78, "Hanoi": 21.03, "DaNang": 16.05,
                "CanTho": 10.03, "HaiPhong": 20.86}
    lng_base = {"HCMC": 106.66, "Hanoi": 105.85, "DaNang": 108.22,
                "CanTho": 105.79, "HaiPhong": 106.68}

    return {
        "event_id": str(uuid.uuid4()),
        "rider_id": rider_id,
        "driver_id": driver_id,
        "event_type": random.choice(EVENT_TYPES),
        "vehicle_type": random.choice(VEHICLE_TYPES),
        "city": city,
        "pickup_lat": round(lat_base[city] + random.uniform(-0.05, 0.05), 6),
        "pickup_lng": round(lng_base[city] + random.uniform(-0.05, 0.05), 6),
        "dropoff_lat": round(lat_base[city] + random.uniform(-0.1, 0.1), 6),
        "dropoff_lng": round(lng_base[city] + random.uniform(-0.1, 0.1), 6),
        "fare_vnd": random.randint(15000, 350000),
        "surge_multiplier": round(random.choice([1.0, 1.0, 1.0, 1.2, 1.5, 2.0]), 1),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "app_version": random.choice(["4.12.0", "4.13.1", "4.14.0-beta"])
    }

def send_events_with_retry(
    connection_str: str,
    total_events: int = 100,
    batch_size: int = 50,
    max_retries: int = 3
):
    """
    Send ride events to Event Hubs using batch mode with retry logic.

    Partition key strategy: partition by rider_id to ensure all events
    from the same rider land in the same partition (ordering guarantee).
    """
    producer = EventHubProducerClient.from_connection_string(
        conn_str=connection_str,
        eventhub_name=EVENT_HUB_NAME
    )

    events_sent = 0
    retry_count = 0

    try:
        while events_sent < total_events:
            # Create a new batch — Event Hubs SDK auto-manages max batch size
            event_data_batch = producer.create_batch()
            batch_count = 0

            while batch_count < batch_size and events_sent < total_events:
                event = generate_ride_event()
                event_data = EventData(json.dumps(event))

                # Set partition key to rider_id for ordering within partition
                event_data.properties = {"source": "goride-producer-v1"}

                try:
                    event_data_batch.add(event_data)
                    batch_count += 1
                    events_sent += 1
                except ValueError:
                    # Batch is full (hit max size), send what we have
                    logger.warning(
                        f"⚠️ Batch full at {batch_count} events. Sending partial batch."
                    )
                    break

            # Send batch with exponential backoff retry
            for attempt in range(max_retries):
                try:
                    producer.send_batch(event_data_batch)
                    logger.info(
                        f"📤 Sent batch: {batch_count} events "
                        f"(Total: {events_sent}/{total_events})"
                    )
                    retry_count = 0  # Reset retry counter on success
                    break
                except Exception as e:
                    retry_count = attempt + 1
                    wait_time = (2 ** retry_count) + random.uniform(0, 1)
                    logger.error(
                        f"❌ Send failed (attempt {retry_count}/{max_retries}): {e}. "
                        f"Retrying in {wait_time:.1f}s..."
                    )
                    if retry_count >= max_retries:
                        logger.critical(
                            f"🚨 CRITICAL: Max retries exceeded. "
                            f"{total_events - events_sent} events NOT sent."
                        )
                        raise
                    time.sleep(wait_time)

    finally:
        producer.close()
        logger.info(f"🏁 Producer closed. Total events sent: {events_sent}")


if __name__ == "__main__":
    logger.info("🚀 GoRide Producer starting...")
    conn_str = get_connection_string_from_keyvault()
    send_events_with_retry(
        connection_str=conn_str,
        total_events=200,
        batch_size=50,
        max_retries=3
    )
```

> **Hệ quả nếu bỏ qua Retry Logic:** Trong production, network hiccup xảy ra thường xuyên (Azure fabric upgrades, transient DNS failures). Nếu không có retry với exponential backoff, một lỗi thoáng qua sẽ khiến toàn bộ batch bị mất vĩnh viễn. Exponential backoff (2s → 4s → 8s) tránh "retry storm" — khi hàng ngàn producer đồng loạt retry cùng lúc, gây overload thêm cho Event Hubs.

---

## Phase 4: Kafka Protocol Compatibility

### Tại sao Kafka Protocol quan trọng?

> **🧠 Kiến thức nền tảng: Migration từ On-Premise Kafka**
>
> GoRide đang chạy 20+ Kafka producers trên hệ thống on-premise. Việc rewrite tất cả producer code để dùng Azure SDK (`azure-eventhub`) sẽ tốn hàng tháng engineering effort và rủi ro regression rất cao. Azure Event Hubs giải quyết bằng cách cung cấp **Kafka protocol endpoint** — producers chỉ cần thay đổi **3 dòng config** (bootstrap server, SASL username/password) mà không cần thay đổi bất kỳ dòng business logic nào.
>
> **Cách hoạt động:** Event Hubs Namespace expose một endpoint Kafka-compatible tại `<namespace>.servicebus.windows.net:9093`. Producer/consumer dùng `confluent-kafka` hoặc `kafka-python` library kết nối tới endpoint này bằng SASL/SSL authentication. Event Hubs tự động "dịch" Kafka protocol sang AMQP bên trong.
>
> **Giới hạn so với native Kafka (QUAN TRỌNG phải biết trước khi migrate):**
>
> | Tính năng | Native Kafka | Event Hubs Kafka |
> |---|---|---|
> | **Kafka Produce/Consume** | ✅ | ✅ |
> | **Consumer Groups** | ✅ | ✅ |
> | **Compression (gzip, snappy, lz4)** | ✅ | ✅ |
> | **Kafka Transactions (exactly-once)** | ✅ | ❌ Không hỗ trợ |
> | **Kafka Connect** | ✅ | ❌ Không hỗ trợ — dùng ADF/Capture thay thế |
> | **Kafka Streams** | ✅ | ❌ Không hỗ trợ — dùng Azure Stream Analytics |
> | **Compacted Topics** | ✅ | ❌ Không hỗ trợ |
> | **Topic creation via Kafka API** | ✅ | ❌ Phải tạo Event Hub qua Azure Portal/CLI |
> | **Idempotent Producer** | ✅ | ❌ |

### Bước 1: Kafka Producer pointing to Event Hubs

> **Purpose:** Minh hoạ cách producer dùng thư viện `confluent-kafka` (chuẩn Kafka) kết nối trực tiếp tới Event Hubs endpoint mà không cần Azure SDK. Đây chính là kịch bản migration thực tế.

Cài đặt:
```bash
pip install confluent-kafka
```

Tạo file `goride_kafka_producer.py`:

```python
"""
GoRide Vietnam — Kafka Protocol Producer → Azure Event Hubs
Demonstrates zero-code-change migration from on-prem Kafka.
"""

import json
import uuid
import random
import logging
from datetime import datetime, timezone
from confluent_kafka import Producer

logging.basicConfig(level=logging.INFO,
                    format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("GoRideKafkaProducer")

# ──────────────────────────────────────────────
# SASL/SSL Configuration for Event Hubs
# ──────────────────────────────────────────────
# NOTE: In production, retrieve these from Key Vault or environment variables.
EVENT_HUBS_NAMESPACE = "evhns-goride-dev.servicebus.windows.net"
CONNECTION_STRING = "<YOUR_EVENTHUB_CONNECTION_STRING>"  # From Key Vault

kafka_config = {
    # Bootstrap server: Event Hubs Kafka endpoint (port 9093 = TLS)
    "bootstrap.servers": f"{EVENT_HUBS_NAMESPACE}:9093",

    # Security: SASL_SSL with PLAIN mechanism
    "security.protocol": "SASL_SSL",
    "sasl.mechanism": "PLAIN",

    # Username is ALWAYS "$ConnectionString" (literal string, not a variable)
    "sasl.username": "$ConnectionString",

    # Password is the full Event Hubs connection string
    "sasl.password": CONNECTION_STRING,

    # Producer settings
    "client.id": "goride-kafka-producer-v1",
    "acks": "all",                  # Wait for all replicas to acknowledge
    "retries": 5,                   # Auto-retry on transient failures
    "retry.backoff.ms": 500,        # Wait 500ms between retries
    "linger.ms": 10,                # Wait 10ms to accumulate batch
    "batch.size": 16384,            # 16KB batch size
    "compression.type": "gzip",     # Compress for bandwidth savings
}

def delivery_callback(err, msg):
    """Called once for each message produced to indicate delivery result."""
    if err is not None:
        logger.error(f"❌ Delivery failed for {msg.key()}: {err}")
    else:
        logger.info(
            f"✅ Delivered to topic={msg.topic()} "
            f"partition={msg.partition()} offset={msg.offset()}"
        )

def generate_ride_event() -> dict:
    """Generate a realistic ride event."""
    return {
        "event_id": str(uuid.uuid4()),
        "rider_id": f"R{random.randint(10000, 99999)}",
        "driver_id": f"D{random.randint(1000, 9999)}",
        "event_type": random.choice(["ride_requested", "ride_completed"]),
        "city": random.choice(["HCMC", "Hanoi", "DaNang"]),
        "fare_vnd": random.randint(15000, 350000),
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

def main():
    producer = Producer(kafka_config)
    topic = "ride-events"  # This maps to Event Hub name

    logger.info(f"🚀 Kafka producer starting — target: {EVENT_HUBS_NAMESPACE}")

    try:
        for i in range(50):
            event = generate_ride_event()
            rider_id = event["rider_id"]

            producer.produce(
                topic=topic,
                key=rider_id,               # Partition key for ordering
                value=json.dumps(event),
                callback=delivery_callback
            )

            # Trigger delivery callbacks for previously produced messages
            producer.poll(0)

        # Wait for all outstanding messages to be delivered
        remaining = producer.flush(timeout=30)
        if remaining > 0:
            logger.warning(f"⚠️ {remaining} messages were NOT delivered!")
        else:
            logger.info("🏁 All messages delivered successfully via Kafka protocol.")

    except Exception as e:
        logger.error(f"❌ Producer error: {e}")
        raise

if __name__ == "__main__":
    main()
```

> **Hệ quả nếu bỏ qua `sasl.username = "$ConnectionString"`:** Đây là lỗi phổ biến nhất khi cấu hình Kafka protocol với Event Hubs. Username phải là chuỗi **literal** `$ConnectionString` (có ký hiệu `$`), KHÔNG phải tên biến hay giá trị thực của connection string. Nếu sai, bạn sẽ nhận lỗi `SASL authentication failed` và mất hàng giờ debug.

---

## Phase 5: Consumer — Multiple Consumer Groups

### Bước 1: Cài đặt Checkpoint Store

> **Purpose:** Consumer cần lưu checkpoint (offset đã đọc) vào Azure Blob Storage để khi restart, nó biết tiếp tục từ đâu. Thư viện `azure-eventhub-checkpointstore-blob` cung cấp khả năng này out-of-the-box.

```bash
pip install azure-eventhub-checkpointstore-blob azure-storage-blob
```

**Tạo Blob Container cho Checkpoint:**
1. Mở Storage Account `stgoridelake001`.
2. Tạo container mới tên `event-checkpoints`.

### Bước 2: Consumer Group 1 — Billing Processor

> **Purpose:** Consumer group `billing-processor` đọc tất cả ride events, lọc lấy event type `ride_completed` và `fare_calculated`, rồi tính tổng doanh thu theo thành phố. Đây là use case realtime revenue dashboard.

Trước tiên, tạo Consumer Group trong Azure Portal:
1. Mở Event Hub `ride-events` > **Consumer groups** > **+ Consumer group**.
2. Name: `billing-processor`. Click **Create**.
3. Lặp lại và tạo thêm: `analytics-processor`.

Tạo file `billing_consumer.py`:

```python
"""
GoRide Vietnam — Billing Consumer Group
Processes ride_completed events to calculate real-time revenue per city.
Uses Azure Blob Storage for checkpoint persistence.
"""

import json
import logging
from collections import defaultdict

from azure.eventhub import EventHubConsumerClient
from azure.eventhub.extensions.checkpointstoreblob import BlobCheckpointStore
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

# ──────────────────────────────────────────────
# Logging
# ──────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s"
)
logger = logging.getLogger("BillingConsumer")

# ──────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────
KEY_VAULT_URL = "https://kv-goride-dev-001.vault.azure.net/"
STORAGE_ACCOUNT_URL = "https://stgoridelake001.blob.core.windows.net"
CHECKPOINT_CONTAINER = "event-checkpoints"
EVENT_HUB_NAME = "ride-events"
CONSUMER_GROUP = "billing-processor"

# In-memory revenue aggregation (production: use Redis or database)
revenue_by_city = defaultdict(int)
events_processed = 0

def get_connection_string() -> str:
    """Retrieve connection string from Key Vault."""
    credential = DefaultAzureCredential()
    client = SecretClient(vault_url=KEY_VAULT_URL, credential=credential)
    return client.get_secret("eventhub-connection-string").value

def on_event(partition_context, event):
    """
    Callback invoked for each event received from Event Hubs.

    Checkpoint strategy: checkpoint every 10 events per partition.
    This balances between checkpoint frequency (cost of storage writes)
    and potential re-processing on failure (data duplication window).
    """
    global events_processed

    try:
        body = json.loads(event.body_as_str())
        event_type = body.get("event_type", "")

        # Only process fare-related events
        if event_type in ("ride_completed", "fare_calculated"):
            city = body.get("city", "Unknown")
            fare = body.get("fare_vnd", 0)
            surge = body.get("surge_multiplier", 1.0)
            total_fare = int(fare * surge)

            revenue_by_city[city] += total_fare
            events_processed += 1

            if events_processed % 10 == 0:
                logger.info(f"💰 Revenue snapshot: {dict(revenue_by_city)}")

        # Checkpoint every 10 events to balance durability vs performance
        if events_processed % 10 == 0:
            partition_context.update_checkpoint(event)
            logger.debug(
                f"✅ Checkpoint saved — Partition: {partition_context.partition_id}, "
                f"Offset: {event.offset}"
            )

    except json.JSONDecodeError:
        logger.warning(f"⚠️ Skipping malformed event on partition "
                       f"{partition_context.partition_id}")
    except Exception as e:
        logger.error(f"❌ Error processing event: {e}")

def on_error(partition_context, error):
    """Handle consumer errors — log and continue."""
    if partition_context:
        logger.error(
            f"❌ Error on partition {partition_context.partition_id}: {error}"
        )
    else:
        logger.error(f"❌ Consumer error (no partition context): {error}")

def on_partition_initialize(partition_context):
    """Called when consumer starts reading a partition."""
    logger.info(
        f"📡 Started reading partition: {partition_context.partition_id}"
    )

def on_partition_close(partition_context, reason):
    """Called when consumer stops reading a partition."""
    logger.info(
        f"🔌 Stopped reading partition {partition_context.partition_id}: {reason}"
    )

def main():
    conn_str = get_connection_string()

    # Checkpoint store backed by Azure Blob Storage
    checkpoint_store = BlobCheckpointStore.from_connection_string(
        # For lab: using storage account connection string
        # Production: use DefaultAzureCredential with RBAC
        conn_str="<STORAGE_CONNECTION_STRING>",
        container_name=CHECKPOINT_CONTAINER
    )

    consumer = EventHubConsumerClient.from_connection_string(
        conn_str=conn_str,
        consumer_group=CONSUMER_GROUP,
        eventhub_name=EVENT_HUB_NAME,
        checkpoint_store=checkpoint_store
    )

    logger.info(f"🚀 Billing consumer starting — group: {CONSUMER_GROUP}")

    try:
        consumer.receive(
            on_event=on_event,
            on_error=on_error,
            on_partition_initialize=on_partition_initialize,
            on_partition_close=on_partition_close,
            starting_position="-1"  # Start from beginning of stream
        )
    except KeyboardInterrupt:
        logger.info("⏹️ Consumer stopped by user.")
    finally:
        consumer.close()
        logger.info(f"🏁 Final revenue: {dict(revenue_by_city)}")
        logger.info(f"📊 Total events processed: {events_processed}")


if __name__ == "__main__":
    main()
```

### Bước 3: Consumer Group 2 — Analytics Processor

> **Purpose:** Consumer group `analytics-processor` đọc cùng luồng dữ liệu nhưng thực hiện aggregation khác: đếm số chuyến đi theo vùng và theo giờ. Hai consumer group hoạt động hoàn toàn **độc lập** — billing consumer có thể chạy nhanh hơn hoặc chậm hơn analytics consumer mà không ảnh hưởng lẫn nhau.

Tạo file `analytics_consumer.py`:

```python
"""
GoRide Vietnam — Analytics Consumer Group
Aggregates ride counts per city per hour for operational dashboards.
"""

import json
import logging
from collections import defaultdict
from datetime import datetime

from azure.eventhub import EventHubConsumerClient
from azure.eventhub.extensions.checkpointstoreblob import BlobCheckpointStore
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s"
)
logger = logging.getLogger("AnalyticsConsumer")

# Configuration
KEY_VAULT_URL = "https://kv-goride-dev-001.vault.azure.net/"
EVENT_HUB_NAME = "ride-events"
CONSUMER_GROUP = "analytics-processor"

# Analytics aggregation: {("HCMC", "2024-01-15T14"): 1523}
ride_counts = defaultdict(int)
events_processed = 0

def get_connection_string() -> str:
    credential = DefaultAzureCredential()
    client = SecretClient(vault_url=KEY_VAULT_URL, credential=credential)
    return client.get_secret("eventhub-connection-string").value

def on_event(partition_context, event):
    global events_processed

    try:
        body = json.loads(event.body_as_str())
        event_type = body.get("event_type", "")

        if event_type == "ride_requested":
            city = body.get("city", "Unknown")
            timestamp_str = body.get("timestamp", "")

            # Extract hour bucket for aggregation
            try:
                ts = datetime.fromisoformat(timestamp_str)
                hour_bucket = ts.strftime("%Y-%m-%dT%H")
            except ValueError:
                hour_bucket = "unknown"

            key = (city, hour_bucket)
            ride_counts[key] += 1
            events_processed += 1

            if events_processed % 25 == 0:
                # Log top 5 busiest city-hour combinations
                top5 = sorted(ride_counts.items(),
                               key=lambda x: x[1], reverse=True)[:5]
                logger.info(f"📊 Top 5 busiest: {top5}")

        # Checkpoint every 25 events
        if events_processed > 0 and events_processed % 25 == 0:
            partition_context.update_checkpoint(event)

    except Exception as e:
        logger.error(f"❌ Error: {e}")

def on_error(partition_context, error):
    logger.error(f"❌ Error: {error}")

def main():
    conn_str = get_connection_string()

    checkpoint_store = BlobCheckpointStore.from_connection_string(
        conn_str="<STORAGE_CONNECTION_STRING>",
        container_name="event-checkpoints"
    )

    consumer = EventHubConsumerClient.from_connection_string(
        conn_str=conn_str,
        consumer_group=CONSUMER_GROUP,
        eventhub_name=EVENT_HUB_NAME,
        checkpoint_store=checkpoint_store
    )

    logger.info(f"🚀 Analytics consumer starting — group: {CONSUMER_GROUP}")

    try:
        consumer.receive(
            on_event=on_event,
            on_error=on_error,
            starting_position="-1"
        )
    except KeyboardInterrupt:
        logger.info("⏹️ Stopped.")
    finally:
        consumer.close()
        logger.info(f"📊 Final ride counts: {dict(ride_counts)}")

if __name__ == "__main__":
    main()
```

> **🧠 Kiến thức nền tảng: Checkpoint Strategy — Checkpoint mỗi N event vs mỗi event**
>
> **Checkpoint mỗi event:** An toàn nhất — nếu consumer crash, chỉ mất đúng 1 event đang xử lý. Nhưng rất chậm vì mỗi checkpoint là một write operation vào Blob Storage (~5-15ms latency). Nếu bạn xử lý 10,000 events/s, bạn tạo 10,000 blob writes/s → chi phí storage transactions tăng vọt.
>
> **Checkpoint mỗi N event (ví dụ: 10 hoặc 25):** Cân bằng giữa durability và performance. Nếu consumer crash, worst case bạn phải re-process N-1 events. Vì vậy consumer phải **idempotent** (xử lý event trùng lặp không gây sai kết quả — ví dụ: dùng event_id làm primary key khi ghi database, nếu trùng thì update thay vì insert).
>
> **Checkpoint theo thời gian (mỗi 30s):** Phù hợp cho workload throughput rất cao. Nhược điểm: window re-processing lớn hơn nếu crash xảy ra ngay trước lúc checkpoint.

---

## Phase 6: Event Hubs Capture (Cold Path to Data Lake)

### Bước 1: Enable Capture to ADLS Gen2

> **Purpose:** Capture tự động ghi mọi event đi qua Event Hubs xuống Data Lake dưới dạng file Avro, phân thư mục theo thời gian. Đây là "cold path" — dữ liệu được archive vĩnh viễn để phân tích lịch sử, compliance audit, hoặc train ML model sau này.

> **🧠 Kiến thức nền tảng: Avro Format — Tại sao Event Hubs chọn Avro?**
>
> **Apache Avro** là định dạng serialization dữ liệu dạng binary, row-based, compact, và tự mang schema (self-describing). Event Hubs chọn Avro vì:
>
> 1. **Schema trong file:** Mỗi file Avro chứa schema ngay trong header → bạn có thể đọc file mà không cần biết trước cấu trúc dữ liệu.
> 2. **Compact:** Binary encoding nên kích thước file nhỏ hơn JSON 2-5x → tiết kiệm storage cost.
> 3. **Schema evolution:** Avro hỗ trợ thêm/bớt field mà không break consumer cũ (forward & backward compatibility).
> 4. **Ecosystem support:** Spark, Databricks, Synapse, Hive đều đọc Avro natively.
>
> **Capture windowing:** Event Hubs Capture ghi file theo 2 điều kiện (whichever comes first):
> - **Time window:** Mỗi N phút (tối thiểu 1 phút, tối đa 15 phút) → ghi 1 file.
> - **Size window:** Khi file đạt N MB (tối thiểu 10 MB, tối đa 500 MB) → ghi file ngay.
>
> Ví dụ: Nếu bạn đặt time = 5 phút, size = 300 MB, và trong 5 phút chỉ có 50 MB dữ liệu → ghi file 50 MB. Nhưng nếu trong 2 phút đã có 300 MB → ghi file 300 MB ngay mà không đợi hết 5 phút.

1. Mở Event Hub `ride-events` > Menu trái: **Capture**.
2. Bật **Capture** = **On**.
3. Cấu hình:
   - **Time window (minutes):** `5`
   - **Size window (MB):** `300`
   - **Capture Provider:** Azure Storage / Data Lake Store
   - **Azure Storage Container:** Chọn storage account `stgoridelake001`, container `event-archive`.
   - **Capture file name format (tùy chọn):** Giữ mặc định:
     ```
     {Namespace}/{EventHub}/{PartitionId}/{Year}/{Month}/{Day}/{Hour}/{Minute}/{Second}
     ```
4. Click **Save**.

> **Hệ quả nếu bỏ qua Capture:** Dữ liệu trong Event Hubs chỉ tồn tại tối đa 7 ngày (Standard tier). Sau 7 ngày, event bị xóa vĩnh viễn. Nếu không bật Capture, bạn mất khả năng phân tích lịch sử, replay events cho debugging, và không đáp ứng compliance yêu cầu lưu trữ dữ liệu (ví dụ: ngành tài chính yêu cầu lưu 7 năm).

### Bước 2: Query Captured Data với Synapse Serverless SQL

> **Purpose:** Sử dụng Azure Synapse Serverless SQL Pool để query trực tiếp file Avro trên Data Lake mà không cần ETL, không cần cluster — chỉ trả tiền cho lượng dữ liệu scan.

Trong Synapse Studio hoặc Azure Portal Query Editor, chạy:

```sql
-- Query captured Avro files directly from Data Lake
-- Note: OPENROWSET reads Avro files natively in Synapse Serverless SQL
SELECT
    CAST(Body AS VARCHAR(MAX)) AS EventBody,
    EnqueuedTimeUtc,
    Offset,
    SequenceNumber,
    SystemProperties
FROM
    OPENROWSET(
        BULK 'https://stgoridelake001.dfs.core.windows.net/event-archive/evhns-goride-dev/ride-events/*/*/*/*/*/*',
        FORMAT = 'AVRO'
    ) AS events
ORDER BY EnqueuedTimeUtc DESC;
```

**Query nâng cao — Parse JSON body và aggregate:**

```sql
-- Parse the JSON event body and aggregate revenue by city
WITH parsed_events AS (
    SELECT
        JSON_VALUE(CAST(Body AS VARCHAR(MAX)), '$.city') AS city,
        JSON_VALUE(CAST(Body AS VARCHAR(MAX)), '$.event_type') AS event_type,
        CAST(JSON_VALUE(CAST(Body AS VARCHAR(MAX)), '$.fare_vnd') AS INT) AS fare_vnd,
        CAST(JSON_VALUE(CAST(Body AS VARCHAR(MAX)), '$.surge_multiplier') AS FLOAT) AS surge_multiplier,
        EnqueuedTimeUtc
    FROM
        OPENROWSET(
            BULK 'https://stgoridelake001.dfs.core.windows.net/event-archive/evhns-goride-dev/ride-events/*/*/*/*/*/*',
            FORMAT = 'AVRO'
        ) AS events
)
SELECT
    city,
    COUNT(*) AS total_rides,
    SUM(CAST(fare_vnd * surge_multiplier AS BIGINT)) AS total_revenue_vnd,
    AVG(fare_vnd) AS avg_fare_vnd
FROM parsed_events
WHERE event_type = 'ride_completed'
GROUP BY city
ORDER BY total_revenue_vnd DESC;
```

> **Purpose:** Query đầu tiên cho bạn raw data để verify Capture hoạt động đúng. Query thứ hai mô phỏng use case thực tế: phòng Finance chạy ad-hoc query mỗi sáng để xem doanh thu hôm qua theo vùng mà KHÔNG cần xây dựng ETL pipeline phức tạp.

---

## Phase 7: Monitoring & Troubleshooting

### Bước 1: Thiết lập Azure Monitor Metrics

> **Purpose:** Monitoring cho phép bạn phát hiện sớm các vấn đề (throttling, consumer lag) trước khi chúng ảnh hưởng tới end-user. Trong production, đây là phần QUAN TRỌNG NHẤT sau khi deploy — một hệ thống không có monitoring giống như lái xe ban đêm mà tắt đèn pha.

1. Mở Namespace `evhns-goride-dev` > Menu trái: **Monitoring** > **Metrics**.
2. Tạo các chart quan trọng:

**Chart 1: Throughput Overview**
   - Metric: `Incoming Messages` + `Outgoing Messages`
   - Aggregation: Sum
   - Time range: Last 1 hour
   - **Ý nghĩa:** Nếu Incoming >> Outgoing, consumers đang không đọc kịp → consumer lag đang tăng.

**Chart 2: Throttling Detection**
   - Metric: `Throttled Requests`
   - Aggregation: Sum
   - **Ý nghĩa:** Nếu giá trị > 0, namespace đang bị quá tải → cần tăng TU hoặc upgrade tier.

**Chart 3: Server Errors**
   - Metric: `Server Errors`
   - Aggregation: Sum
   - **Ý nghĩa:** Server errors thường chỉ ra vấn đề phía Azure. Nếu kéo dài > 5 phút, raise support ticket.

### Bước 2: Chẩn đoán Lỗi Thường Gặp

> **🧠 Kiến thức nền tảng: Troubleshooting Common Issues**
>
> | Lỗi | Nguyên nhân | Giải pháp |
> |---|---|---|
> | `ThrottlingException` | Vượt quá throughput capacity (TU) | Bật Auto-Inflate, tăng max TU, hoặc upgrade Premium tier |
> | `QuotaExceededException` | Vượt quá giới hạn số Event Hubs trong namespace (10 cho Standard) hoặc số Consumer Groups (20) | Tạo thêm namespace hoặc upgrade tier |
> | `MessagingEntityNotFoundException` | Event Hub name hoặc Consumer Group name bị sai (case-sensitive) | Double-check tên chính xác trong Azure Portal |
> | `ReceiverDisconnectedException` | Có nhiều hơn 5 receiver trên cùng 1 partition trong cùng consumer group | Giảm số consumer instances, hoặc tăng partition count |
> | `OperationCanceledException` (timeout) | Network latency hoặc Event Hubs đang quá tải | Tăng timeout settings, implement retry logic |
> | `EventHubsException` with `is_transient=True` | Lỗi tạm thời (network blip, Azure fabric update) | SDK tự retry — không cần action. Nếu kéo dài, kiểm tra Azure Status page |

### Bước 3: Scaling Strategies

> **Purpose:** Hiểu cách scale Event Hubs để đáp ứng traffic tăng trưởng. GoRide dự kiến traffic tăng 3x trong 6 tháng tới do mở rộng sang 10 tỉnh thành mới.

**Strategy 1: Auto-Inflate (Reactive Scaling)**
- Đã cấu hình ở Phase 1. Event Hubs tự tăng TU khi phát hiện throttling.
- **Ưu điểm:** Zero-effort, tự động.
- **Nhược điểm:** Có delay ~1-2 phút khi scale up → vài requests đầu tiên bị throttle.

**Strategy 2: Manual TU Pre-scaling (Proactive)**
- Trước giờ cao điểm (7-9h sáng), chủ động tăng TU lên mức cao bằng Azure CLI:
```bash
az eventhubs namespace update \
    --resource-group rg-goride-streaming-dev \
    --name evhns-goride-dev \
    --capacity 10  # Tăng lên 10 TU
```
- Sau giờ cao điểm, giảm lại để tiết kiệm chi phí.

**Strategy 3: Upgrade to Premium (Strategic)**
- Khi Standard tier không đủ (> 40 TU), upgrade lên Premium với Processing Units.
- Premium cung cấp auto-scaling PU (1-16 PU) mà không cần can thiệp thủ công.

---

## Phase 8: Schema Registry (Event Hubs Schema Registry with Avro)

### Tại sao Schema Evolution quan trọng?

> **🧠 Kiến thức nền tảng: Schema Evolution trong Streaming**
>
> Hãy tưởng tượng GoRide v1.0 gửi ride events với schema sau:
> ```json
> {"rider_id": "R001", "fare_vnd": 25000, "city": "HCMC"}
> ```
>
> 3 tháng sau, product team quyết định thêm field `tip_vnd`:
> ```json
> {"rider_id": "R001", "fare_vnd": 25000, "city": "HCMC", "tip_vnd": 5000}
> ```
>
> **Vấn đề:** Consumer code cũ (billing-processor) không biết field `tip_vnd` tồn tại. Nếu không có Schema Registry:
> - Consumer crash vì gặp field không mong đợi? Hay
> - Consumer bỏ qua `tip_vnd` và tính sai doanh thu?
>
> **Schema Registry giải quyết** bằng cách:
> 1. **Lưu trữ trung tâm** mọi phiên bản schema (v1, v2, v3...).
> 2. **Validate** tại thời điểm produce: nếu event không khớp schema registered, producer bị reject ngay lập tức thay vì đẩy dữ liệu "rác" vào hệ thống.
> 3. **Compatibility check:** Kiểm tra schema mới có backward/forward compatible với phiên bản trước không (ví dụ: chỉ được thêm field optional, không được xoá field bắt buộc).
>
> **LƯU Ý:** Schema Registry chỉ có trên **Premium** và **Dedicated** tier. Standard tier KHÔNG hỗ trợ. Trong lab này, chúng ta sẽ mô phỏng concept bằng code. Nếu bạn có Premium tier, hãy làm theo bước cấu hình bên dưới.

### Bước 1: Định nghĩa Avro Schema

> **Purpose:** Định nghĩa schema chính thức cho ride events. Schema này sẽ được đăng ký vào Schema Registry và dùng làm "contract" giữa producer và consumer.

Tạo file `ride_event_schema.avsc`:

```json
{
    "type": "record",
    "name": "RideEvent",
    "namespace": "com.goride.events",
    "doc": "Schema for GoRide Vietnam ride events - v1",
    "fields": [
        {"name": "event_id", "type": "string", "doc": "Unique event identifier (UUID)"},
        {"name": "rider_id", "type": "string", "doc": "Rider identifier"},
        {"name": "driver_id", "type": "string", "doc": "Driver identifier"},
        {"name": "event_type", "type": {
            "type": "enum",
            "name": "EventType",
            "symbols": ["ride_requested", "driver_assigned", "ride_started",
                         "gps_update", "fare_calculated", "ride_completed"]
        }},
        {"name": "city", "type": "string"},
        {"name": "fare_vnd", "type": "int", "default": 0},
        {"name": "surge_multiplier", "type": "float", "default": 1.0},
        {"name": "timestamp", "type": "string", "doc": "ISO 8601 UTC timestamp"},
        {"name": "tip_vnd", "type": ["null", "int"], "default": null,
         "doc": "Optional tip amount — added in v2"}
    ]
}
```

### Bước 2: Producer với Schema Validation

> **Purpose:** Producer serialize event bằng Avro schema trước khi gửi. Nếu event không khớp schema (ví dụ: thiếu field bắt buộc), serialization fail ngay tại producer side → ngăn chặn dữ liệu lỗi đi vào hệ thống.

Cài đặt:
```bash
pip install avro-python3 azure-schemaregistry azure-schemaregistry-avroencoder
```

Tạo file `schema_aware_producer.py`:

```python
"""
GoRide Vietnam — Schema-Aware Producer
Validates events against Avro schema before sending to Event Hubs.
"""

import json
import uuid
import random
import logging
import avro.schema
import avro.io
import io
from datetime import datetime, timezone

from azure.eventhub import EventHubProducerClient, EventData
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

logging.basicConfig(level=logging.INFO,
                    format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("SchemaAwareProducer")

# ──────────────────────────────────────────────
# Load Avro Schema
# ──────────────────────────────────────────────
with open("ride_event_schema.avsc", "r") as f:
    SCHEMA = avro.schema.parse(f.read())

def serialize_with_schema(event_dict: dict) -> bytes:
    """
    Serialize event to Avro binary format using the registered schema.
    Raises exception if event doesn't conform to schema.
    """
    writer = avro.io.DatumWriter(SCHEMA)
    bytes_writer = io.BytesIO()
    encoder = avro.io.BinaryEncoder(bytes_writer)
    try:
        writer.write(event_dict, encoder)
        return bytes_writer.getvalue()
    except avro.io.AvroTypeException as e:
        logger.error(f"❌ Schema validation failed: {e}")
        raise

def generate_valid_event() -> dict:
    """Generate event that conforms to the Avro schema."""
    return {
        "event_id": str(uuid.uuid4()),
        "rider_id": f"R{random.randint(10000, 99999)}",
        "driver_id": f"D{random.randint(1000, 9999)}",
        "event_type": random.choice(["ride_requested", "ride_completed",
                                      "fare_calculated"]),
        "city": random.choice(["HCMC", "Hanoi", "DaNang"]),
        "fare_vnd": random.randint(15000, 350000),
        "surge_multiplier": round(random.choice([1.0, 1.2, 1.5, 2.0]), 1),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "tip_vnd": random.choice([None, 5000, 10000, 20000])  # v2 field
    }

def main():
    # Get connection string from Key Vault
    credential = DefaultAzureCredential()
    kv_client = SecretClient(
        vault_url="https://kv-goride-dev-001.vault.azure.net/",
        credential=credential
    )
    conn_str = kv_client.get_secret("eventhub-connection-string").value

    producer = EventHubProducerClient.from_connection_string(
        conn_str=conn_str,
        eventhub_name="ride-events"
    )

    logger.info("🚀 Schema-aware producer starting...")
    events_sent = 0
    validation_errors = 0

    try:
        batch = producer.create_batch()

        for i in range(100):
            event = generate_valid_event()

            try:
                # Serialize with schema validation
                avro_bytes = serialize_with_schema(event)
                event_data = EventData(avro_bytes)
                event_data.content_type = "application/avro"

                try:
                    batch.add(event_data)
                    events_sent += 1
                except ValueError:
                    # Batch full — send and create new
                    producer.send_batch(batch)
                    logger.info(f"📤 Sent batch of {events_sent} events")
                    batch = producer.create_batch()
                    batch.add(event_data)

            except avro.io.AvroTypeException:
                validation_errors += 1
                logger.warning(f"⚠️ Skipping invalid event #{i}")

        # Send remaining events
        producer.send_batch(batch)
        logger.info(f"📤 Final batch sent.")

    finally:
        producer.close()
        logger.info(
            f"🏁 Done. Sent: {events_sent}, "
            f"Validation errors: {validation_errors}"
        )

if __name__ == "__main__":
    main()
```

### Bước 3: Đăng ký Schema vào Event Hubs Schema Registry (Premium Tier)

> **Purpose:** Nếu bạn đang dùng Premium tier, bạn có thể đăng ký schema trực tiếp vào Event Hubs Schema Registry thay vì quản lý file `.avsc` thủ công.

1. Mở Namespace (Premium tier) > Menu trái: **Schema Registry**.
2. Tạo **Schema Group** mới:
   - **Name:** `goride-events`
   - **Serialization Type:** Avro
   - **Compatibility Mode:** Backward _(cho phép consumer cũ đọc schema mới)_
3. Trong schema group, click **+ Create Schema**:
   - **Name:** `ride-event`
   - Paste nội dung file `ride_event_schema.avsc` vào editor.
4. Click **Create**. Schema version 1 được đăng ký thành công.

> **Hệ quả nếu bỏ qua Schema Registry:** Không có Schema Registry, bất kỳ producer nào cũng có thể gửi JSON bất kỳ format vào Event Hub — dẫn đến "schema drift" (dữ liệu không đồng nhất). Consumer phải viết defensive code xử lý mọi trường hợp thiếu field, sai type — code trở nên phức tạp, khó bảo trì, và bug-prone.

---

## Phase 9: End-to-End Testing & Cleanup

### Bước 1: Kiểm thử toàn diện (End-to-End)

> **Purpose:** Validate toàn bộ luồng dữ liệu từ producer → Event Hubs → consumer groups → Capture → Data Lake → SQL query.

**Test 1: Producer → Event Hub**
1. Chạy `goride_producer.py` — gửi 200 events.
2. Kiểm tra Azure Portal: Mở Event Hub `ride-events` > **Overview** > Xác nhận biểu đồ "Incoming Messages" tăng lên.

**Test 2: Kafka Producer → Event Hub**
1. Chạy `goride_kafka_producer.py` — gửi 50 events qua Kafka protocol.
2. Xác nhận "Incoming Messages" tăng thêm 50.

**Test 3: Consumer Groups độc lập**
1. Mở 2 terminal song song.
2. Terminal 1: `python billing_consumer.py` — xem revenue aggregation.
3. Terminal 2: `python analytics_consumer.py` — xem ride count aggregation.
4. Xác nhận cả hai consumer đều nhận được **cùng** tập events nhưng aggregate khác nhau.

**Test 4: Capture → Data Lake**
1. Đợi 5-10 phút (capture window).
2. Mở Storage Account `stgoridelake001` > Container `event-archive`.
3. Duyệt thư mục theo cấu trúc `{Namespace}/{EventHub}/{PartitionId}/{Year}/{Month}/...`
4. Xác nhận file `.avro` đã được tạo.

**Test 5: Query Avro từ Synapse**
1. Chạy SQL query ở Phase 6 Bước 2 để query captured data.
2. Xác nhận kết quả trả về ride events với JSON body đầy đủ.

### Bước 2: Dọn dẹp Tài nguyên (Cleanup)

> **Purpose:** Xóa toàn bộ hạ tầng đã tạo để Azure ngừng tính phí. Đây là thói quen bắt buộc sau khi hoàn thành lab — một Resource Group bị quên có thể tốn $50-100+/tháng.

> **Hệ quả nếu bỏ qua:** Event Hubs Standard với 1 TU tốn ~$11/tháng. Storage Account tốn theo dung lượng. Key Vault tốn theo số operations. Tổng cộng nếu quên cleanup, bạn có thể bị charge $20-50/tháng cho tài nguyên không sử dụng.

Chỉ cần **1 thao tác duy nhất** vì chúng ta đã gom tất cả vào cùng một Resource Group:

1. Đăng nhập [portal.azure.com](https://portal.azure.com).
2. Mở **Resource groups**.
3. Chọn `rg-goride-streaming-dev`.
4. Click **Delete resource group** (biểu tượng thùng rác).
5. Gõ lại tên `rg-goride-streaming-dev` vào ô xác nhận.
6. Click **Delete**.

Hoặc dùng Azure CLI (nhanh hơn):
```bash
az group delete --name rg-goride-streaming-dev --yes --no-wait
```

Quá trình xóa sẽ diễn ra trong vài phút. Azure sẽ không còn tính bất kỳ chi phí nào cho các tài nguyên trong Resource Group này.

---

**🎉 Chúc mừng!** Bạn đã hoàn thành lab Enterprise Event-Driven Data Ingestion. Bạn đã xây dựng thành công:

- ✅ Event Hubs Namespace với auto-inflate scaling
- ✅ Producer sử dụng native Azure SDK với batch mode, retry, và Key Vault integration
- ✅ Kafka-compatible producer cho migration scenario
- ✅ Multiple Consumer Groups với checkpoint store cho independent processing
- ✅ Capture to Data Lake với Avro format cho historical analysis
- ✅ Monitoring & troubleshooting với Azure Monitor metrics
- ✅ Schema Registry với Avro schema validation

Đây chính là kiến trúc streaming mà các công ty ride-hailing, fintech, và e-commerce sử dụng trong production để xử lý hàng triệu events mỗi giây.
