# Hướng dẫn Lab 07: Enterprise Reliable Messaging & Microservices Integration: Azure Service Bus Queues, Topics & Dead-Letter Patterns

Chào mừng bạn đến với tài liệu Lab cấp doanh nghiệp về Azure Service Bus. Tài liệu này được biên soạn từng bước (step-by-step), bao gồm giải thích kiến trúc, cấu hình hạ tầng, viết mã nguồn Python production-ready, và các pattern thiết kế messaging được sử dụng trong hệ thống tài chính thực tế.

---

## Kịch bản Nghiệp vụ (The Business Scenario) & Kiến trúc Giải pháp

Nền tảng ngân hàng trực tuyến **VietPay** xử lý hơn **100,000+ giao dịch tài chính** mỗi ngày. Khi một khách hàng khởi tạo lệnh chuyển tiền, hệ thống phải thực hiện tuần tự 5 bước:

1. **Validate Transaction** — Kiểm tra số dư, giới hạn chuyển tiền, xác thực OTP.
2. **Debit Sender** — Trừ tiền tài khoản người gửi.
3. **Credit Receiver** — Cộng tiền tài khoản người nhận.
4. **Send Notification** — Gửi email/SMS xác nhận cho cả hai bên.
5. **Audit Logging** — Ghi nhận toàn bộ giao dịch vào hệ thống kiểm toán tuân thủ pháp luật.

**Vấn đề:** Nếu BẤT KỲ bước nào thất bại (ví dụ: dịch vụ SMS sập, database audit bị quá tải), tin nhắn giao dịch KHÔNG ĐƯỢC MẤT — nó phải được chuyển vào **Dead-Letter Queue** để nhân viên vận hành xử lý thủ công. Hệ thống áp dụng kiến trúc **Microservices**, mỗi bước là một service riêng biệt giao tiếp qua **Azure Service Bus**.

### Tại sao chọn Azure Service Bus?

> **🧠 Kiến thức nền tảng:** Trong thế giới doanh nghiệp, khi hai hệ thống cần giao tiếp với nhau, bạn KHÔNG BAO GIỜ để chúng gọi trực tiếp (synchronous HTTP call). Lý do: nếu hệ thống B đang bận hoặc sập, hệ thống A cũng sẽ bị treo theo (cascading failure). Thay vào đó, bạn đặt một **Message Broker** ở giữa — hệ thống A gửi tin nhắn vào broker, hệ thống B đọc tin nhắn khi nó sẵn sàng. Azure Service Bus chính là Message Broker cấp enterprise của Microsoft, được thiết kế cho các hệ thống tài chính yêu cầu **zero message loss** và **exactly-once processing**.

---

## Phase 1: Thiết lập Hạ tầng Enterprise & Bảo mật

### Bước 1: Tạo Resource Group

> **Purpose:** Gom nhóm toàn bộ tài nguyên (Service Bus, Key Vault, Functions...) vào chung một nơi để dễ dàng quản lý chi phí, phân quyền và xóa dự án khi không còn sử dụng mà không sợ sót rác hệ thống.

1. Đăng nhập [portal.azure.com](https://portal.azure.com).
2. Tìm **Resource groups** > **Create**.
3. Điền thông tin:
   - **Subscription:** Chọn subscription của bạn.
   - **Resource group:** `rg-vietpay-messaging-dev`
   - **Region:** `Southeast Asia`.
4. Nhấn **Review + create** -> **Create**.

### Bước 2: Tạo Service Bus Namespace

> **Purpose:** Service Bus Namespace là container logic chứa toàn bộ Queues, Topics, và Subscriptions của bạn. Nó cung cấp một DNS endpoint duy nhất (ví dụ: `sb-vietpay.servicebus.windows.net`) và là đơn vị quản lý billing, access control, và networking.

1. Tìm **Service Bus** trong thanh tìm kiếm > **Create**.
2. Điền thông tin:
   - **Resource group:** `rg-vietpay-messaging-dev`
   - **Namespace name:** `sb-vietpay-dev-001` (phải unique toàn cầu, thêm initials nếu cần).
   - **Location:** `Southeast Asia`.
   - **Pricing tier:** Chọn **Standard** cho bài Lab này.

> **🧠 Kiến thức nền tảng: Basic vs Standard vs Premium — Chọn tier nào?**
>
> | Tính năng | Basic (~$0.05/1M ops) | Standard (~$10/month) | Premium (~$677/month) |
> |---|---|---|---|
> | **Queues** | ✅ | ✅ | ✅ |
> | **Topics & Subscriptions** | ❌ | ✅ | ✅ |
> | **Sessions (FIFO)** | ❌ | ✅ | ✅ |
> | **Dead-Letter Queue** | ✅ | ✅ | ✅ |
> | **Duplicate Detection** | ❌ | ✅ | ✅ |
> | **Transactions** | ❌ | ✅ | ✅ |
> | **Message size** | 256 KB | 256 KB | 100 MB |
> | **Dedicated resources** | ❌ Shared | ❌ Shared | ✅ Isolated |
> | **Virtual Network** | ❌ | ❌ | ✅ |
> | **Availability Zones** | ❌ | ❌ | ✅ |
>
> **Khi nào chọn Premium cho Production?** Trong hệ thống tài chính như VietPay, Premium là bắt buộc vì: (1) tài nguyên dedicated — không bị ảnh hưởng bởi "noisy neighbor" trên shared infrastructure; (2) hỗ trợ Virtual Network Integration — Service Bus nằm trong private network, không expose ra internet; (3) Availability Zones — đảm bảo 99.995% uptime khi một data center vật lý bị sập; (4) message size 100 MB — cần cho các payload lớn chứa tài liệu đính kèm.

> **Hệ quả nếu bỏ qua:** Nếu dùng Standard tier trong production cho hệ thống xử lý 100K giao dịch/ngày, bạn sẽ gặp hiện tượng **throttling** (bị giới hạn throughput) vào giờ cao điểm vì tài nguyên bị chia sẻ với các tenant khác trên cùng cluster của Microsoft. Giao dịch của khách hàng sẽ bị delay 5-30 giây thay vì mili-giây, gây trải nghiệm tồi tệ và mất khách.

3. Nhấn **Review + create** -> **Create**.
4. Đợi deploy xong, bấm **Go to resource**.

### Bước 3: Tạo Queue cho Point-to-Point Messaging

> **Purpose:** Queue là kênh giao tiếp 1-đối-1 (point-to-point). Mỗi message chỉ được nhận bởi MỘT consumer duy nhất. Trong VietPay, queue `transaction-processing` sẽ nhận các lệnh chuyển tiền và chỉ có đúng một Transaction Processor xử lý mỗi lệnh.

1. Trong Service Bus Namespace, menu trái chọn **Queues** > **+ Queue**.
2. Điền thông tin:
   - **Name:** `transaction-processing`
   - **Max delivery count:** `5` (Sau 5 lần thử nhận mà consumer không Complete, message tự động vào Dead-Letter Queue).
   - **Message time to live:** `1 day` (Message hết hạn sau 24h nếu không được xử lý).
   - **Lock duration:** `30 seconds` (Thời gian consumer giữ khóa message trong Peek-Lock mode).
   - **Enable dead-lettering on message expiration:** ✅ Bật (Message hết hạn sẽ vào DLQ thay vì biến mất).
   - **Enable duplicate detection:** ✅ Bật, **Duplicate detection history time window:** `10 minutes`.
3. Nhấn **Create**.

> **Hệ quả nếu bỏ qua:** Nếu không bật Dead-lettering on message expiration, các giao dịch chuyển tiền chưa xử lý kịp trong 24h sẽ bị XÓA VĨNH VIỄN. Tiền đã trừ tài khoản người gửi nhưng chưa cộng cho người nhận — gây mất tiền và kiện tụng pháp lý.

### Bước 4: Tạo Topic & Subscriptions cho Pub/Sub Messaging

> **Purpose:** Topic cho phép một message được broadcast tới NHIỀU subscriber cùng lúc (publish-subscribe pattern). Trong VietPay, khi một giao dịch thành công, sự kiện này cần đồng thời được gửi tới Notification Service, Audit Service, và Fraud Detection Service.

1. Trong Service Bus Namespace, menu trái chọn **Topics** > **+ Topic**.
2. Điền:
   - **Name:** `transaction-events`
   - **Enable duplicate detection:** ✅ Bật.
   - **Max size:** `1 GB`.
3. Nhấn **Create**.

**Tạo 3 Subscriptions:**

4. Mở Topic `transaction-events` vừa tạo > **Subscriptions** > **+ Subscription**.
   - Subscription 1: **Name:** `notification-service`, Max delivery count: `3`.
   - Subscription 2: **Name:** `audit-service`, Max delivery count: `10`.
   - Subscription 3: **Name:** `fraud-detection`, Max delivery count: `5`.

*(Chúng ta sẽ thêm SQL Filters cho mỗi subscription ở Phase 4.)*

### Bước 5: Lưu Connection String vào Key Vault

> **Purpose:** KHÔNG BAO GIỜ hardcode connection string trong code. Key Vault mã hóa và quản lý tập trung các credentials, cho phép rotate key mà không cần deploy lại ứng dụng.

1. Tạo Key Vault: Tìm **Key vaults** > **Create**.
   - **Resource group:** `rg-vietpay-messaging-dev`
   - **Name:** `kv-vietpay-dev-001` (globally unique).
   - **Region:** `Southeast Asia`.
   - **Pricing tier:** Standard.
   - Nhấn **Review + create** -> **Create**.

2. **Gán quyền cho bản thân:** Mở Key Vault > **Access control (IAM)** > **Add role assignment** > chọn **Key Vault Secrets Officer** > chọn user của bạn > **Review + assign**.

3. **Lấy Connection String từ Service Bus:** Mở Service Bus Namespace > **Settings** > **Shared access policies** > chọn **RootManageSharedAccessKey** > copy **Primary Connection String**.

4. **Tạo Secret trong Key Vault:** Mở Key Vault > **Secrets** > **+ Generate/Import**.
   - **Name:** `sb-connection-string`
   - **Value:** Dán connection string vừa copy.
   - Nhấn **Create**.

> **Hệ quả nếu bỏ qua:** Nếu hardcode connection string trong code và push lên GitHub, attacker có thể gửi hàng triệu message rác vào queue, làm tê liệt hệ thống messaging và tăng chi phí Azure lên hàng ngàn USD trong vài giờ.

---

## Phase 2: Kiến thức Nền tảng — Core Concepts Deep Dive

Trước khi viết code, bạn PHẢI hiểu rõ các khái niệm cốt lõi. Phase này là phần QUAN TRỌNG NHẤT của bài Lab.

### So sánh các Messaging Services trên Azure

> **🧠 Kiến thức nền tảng: Service Bus vs Event Hubs vs Queue Storage vs Kafka — Chọn cái nào?**
>
> Đây là câu hỏi phỏng vấn kinh điển và cũng là quyết định kiến trúc quan trọng nhất khi thiết kế hệ thống distributed:
>
> | Tiêu chí | **Service Bus** | **Event Hubs** | **Queue Storage** | **Kafka (HDInsight/Confluent)** |
> |---|---|---|---|---|
> | **Mô hình** | Message Broker | Event Streaming | Simple Queue | Event Streaming |
> | **Use case chính** | Enterprise messaging, transactions, workflows | Telemetry, IoT, log ingestion (millions events/sec) | Simple task queue, lightweight decoupling | Real-time analytics, high-throughput streaming |
> | **Delivery guarantee** | At-least-once, exactly-once (with sessions) | At-least-once | At-least-once | At-least-once (exactly-once with transactions) |
> | **Message ordering** | ✅ FIFO (with Sessions) | ✅ Per partition | ❌ No guarantee | ✅ Per partition |
> | **Dead-Letter Queue** | ✅ Built-in | ❌ No (DIY) | ❌ No (DIY with poison queue) | ❌ No (DIY) |
> | **Message size** | 256 KB – 100 MB | 1 MB (Standard), 20 MB (Premium) | 64 KB | Configurable (default 1 MB) |
> | **Throughput** | Thousands/sec | Millions/sec | Thousands/sec | Millions/sec |
> | **Retention** | Until consumed | 1-90 days (configurable) | 7 days max | Configurable (days/forever) |
> | **Cost** | Medium-High | Medium | Very Low | High (cluster-based) |
> | **Protocol** | AMQP 1.0, HTTP | AMQP 1.0, Kafka, HTTP | HTTP REST | Kafka protocol |
>
> **Quy tắc vàng:**
> - Chọn **Service Bus** khi bạn cần **reliable message delivery** với dead-lettering, sessions, transactions — ví dụ: xử lý đơn hàng, chuyển tiền, workflow approval.
> - Chọn **Event Hubs** khi bạn cần **ingest hàng triệu events/giây** — ví dụ: telemetry từ IoT devices, application logs, clickstream analytics.
> - Chọn **Queue Storage** khi bạn cần queue **đơn giản, siêu rẻ** cho các task background không quan trọng — ví dụ: generate thumbnails, send bulk emails.
> - Chọn **Kafka** khi bạn cần **event replay** (đọc lại event từ quá khứ) và đã có team vận hành Kafka — ví dụ: CDC (Change Data Capture), event sourcing.

### Message Broker Pattern vs Event Streaming Pattern

> **🧠 Kiến thức nền tảng:** Đây là hai triết lý kiến trúc hoàn toàn khác nhau:
>
> **Message Broker (Service Bus, RabbitMQ):** Message được **consumed** (tiêu thụ) rồi **xóa** khỏi queue. Giống như bưu điện — thư gửi đi, người nhận lấy thư, thư biến mất khỏi hòm thư. Broker chủ động **push** hoặc consumer chủ động **pull** message. Phù hợp cho **command** (làm gì đó) và **request-reply**.
>
> **Event Streaming (Event Hubs, Kafka):** Event được **append** vào log và **giữ lại** trong một khoảng thời gian (retention period). Nhiều consumer có thể đọc cùng event nhiều lần, mỗi consumer theo dõi vị trí đọc riêng (offset/checkpoint). Giống như nhật ký — bạn ghi sự kiện vào sổ, ai cũng có thể mở sổ đọc lại. Phù hợp cho **event notification** (điều gì đó đã xảy ra) và **analytics**.
>
> Trong VietPay, chúng ta chọn **Message Broker** vì mỗi lệnh chuyển tiền là một **command** cần được xử lý chính xác MỘT LẦN rồi xóa. Nếu dùng Event Streaming, một giao dịch chuyển tiền có thể bị xử lý lại khi consumer replay events — dẫn đến chuyển tiền hai lần!

### Queue vs Topic: Point-to-Point vs Publish-Subscribe

> **🧠 Kiến thức nền tảng:**
>
> **Queue (Hàng đợi):** Tin nhắn được gửi vào queue và chỉ có MỘT consumer nhận được tin nhắn đó. Nếu có 5 consumer cùng lắng nghe một queue, Service Bus sẽ phân phối tin nhắn kiểu round-robin — mỗi consumer nhận một tin nhắn khác nhau. Pattern này gọi là **Competing Consumers**, rất hữu ích để scale xử lý (thêm consumer = xử lý nhanh hơn). Ví dụ trong VietPay: queue `transaction-processing` có 10 consumer instances, mỗi instance xử lý các giao dịch khác nhau song song.
>
> **Topic + Subscription (Chủ đề + Đăng ký):** Tin nhắn được gửi vào topic và MỖI subscription nhận được MỘT BẢN SAO riêng. Nếu topic có 3 subscriptions, mỗi message sẽ được nhân bản thành 3 bản độc lập. Ví dụ trong VietPay: khi giao dịch thành công, event `TransactionCompleted` được gửi vào topic `transaction-events`. Subscription `notification-service` nhận bản sao để gửi SMS, `audit-service` nhận bản sao để ghi log, `fraud-detection` nhận bản sao để phân tích gian lận — tất cả diễn ra song song, không ảnh hưởng lẫn nhau.

### Message Lifecycle & Delivery Guarantees

> **🧠 Kiến thức nền tảng: Vòng đời của một Message**
>
> ```
> Producer → SEND → [Queue/Topic] → RECEIVE → Consumer
>                                         ↓
>                              ┌──────────┼──────────┐
>                              ↓          ↓          ↓
>                          COMPLETE    ABANDON    DEAD-LETTER
>                          (Xong!)   (Thử lại)  (Lỗi vĩnh viễn)
> ```
>
> - **Complete:** Consumer xử lý thành công, message bị xóa vĩnh viễn khỏi queue. Ví dụ: giao dịch chuyển tiền thành công.
> - **Abandon:** Consumer gặp lỗi tạm thời (transient error), message được trả lại queue để thử lại. Ví dụ: database timeout — thử lại sau 5 giây có thể thành công. Delivery count tăng lên 1.
> - **Dead-letter:** Consumer xác định message bị lỗi vĩnh viễn (permanent failure), chuyển vào Dead-Letter Queue. Ví dụ: JSON không hợp lệ, thiếu trường bắt buộc — thử lại bao nhiêu lần cũng sẽ lỗi.
>
> **Delivery Guarantees — Ba mức đảm bảo:**
>
> | Mức đảm bảo | Giải thích | Service Bus hỗ trợ? |
> |---|---|---|
> | **At-most-once** | Message có thể bị mất nhưng KHÔNG BAO GIỜ bị xử lý lại. Dùng **Receive-and-Delete** mode. | ✅ |
> | **At-least-once** | Message KHÔNG BAO GIỜ bị mất nhưng CÓ THỂ bị xử lý lại (duplicate). Dùng **Peek-Lock** mode. | ✅ (Default) |
> | **Exactly-once** | Message được xử lý CHÍNH XÁC MỘT LẦN. Dùng **Sessions** + **idempotent consumers**. | ✅ (With Sessions) |
>
> Trong hệ thống tài chính VietPay, chúng ta LUÔN dùng **at-least-once** (Peek-Lock) kết hợp với **idempotent processing** (kiểm tra `transaction_id` đã xử lý chưa trước khi thực thi) để đạt hiệu quả exactly-once.

### Peek-Lock vs Receive-and-Delete

> **🧠 Kiến thức nền tảng:**
>
> **Peek-Lock (Mặc định, khuyến nghị cho production):** Consumer "khóa" message trong một khoảng thời gian (lock duration). Message vẫn nằm trong queue nhưng invisible với các consumer khác. Nếu consumer Complete — message bị xóa. Nếu consumer crash mà chưa Complete — lock hết hạn, message tự động hiện lại trong queue cho consumer khác xử lý. **An toàn nhưng chậm hơn.**
>
> **Receive-and-Delete:** Message bị xóa ngay khi consumer nhận được, TRƯỚC KHI xử lý. Nếu consumer crash giữa chừng — message mất vĩnh viễn. **Nhanh nhưng nguy hiểm.** Chỉ dùng cho dữ liệu không quan trọng (telemetry, logs).
>
> **Ví dụ thực tế VietPay:** Giao dịch chuyển 500 triệu VND. Consumer nhận message (Peek-Lock), bắt đầu trừ tiền người gửi. Đúng lúc đó server bị restart. Với Peek-Lock: lock hết hạn sau 30 giây, message hiện lại, consumer khác xử lý tiếp — tiền không mất. Với Receive-and-Delete: message đã bị xóa, giao dịch biến mất — tiền bị trừ nhưng không ai cộng cho người nhận.

### Dead-Letter Queue (DLQ) — Hàng đợi Thư chết

> **🧠 Kiến thức nền tảng:**
>
> DLQ là một sub-queue đặc biệt gắn liền với mỗi queue/subscription. Nó chứa các message "không thể xử lý" để nhân viên vận hành review thủ công. DLQ có đường dẫn: `<queue-name>/$deadletterqueue`.
>
> **Khi nào message vào DLQ:**
> 1. **Auto dead-lettering (Max delivery count):** Consumer nhận message, gặp lỗi, Abandon. Service Bus trả message lại queue, tăng delivery count. Lặp lại cho đến khi delivery count = max delivery count (ví dụ: 5). Lần thứ 6, message tự động vào DLQ.
> 2. **Auto dead-lettering (Message expiration):** Message nằm trong queue quá thời gian TTL (Time to Live) mà không ai xử lý. Nếu bật "Dead-letter on expiration", message vào DLQ thay vì bị xóa.
> 3. **Manual dead-lettering:** Consumer chủ động gọi `receiver.dead_letter_message(message, reason="...", error_description="...")` khi phát hiện lỗi vĩnh viễn.
>
> **Trong VietPay:** Nếu một message chuyển tiền có JSON không hợp lệ (ví dụ: `amount` là chữ thay vì số), consumer sẽ manual dead-letter ngay lập tức thay vì để retry 5 lần vô ích. Nhân viên vận hành sẽ kiểm tra DLQ mỗi giờ, sửa lỗi, và re-submit message.

### Duplicate Detection & Sessions

> **🧠 Kiến thức nền tảng: Duplicate Detection**
>
> Service Bus sử dụng trường `MessageId` để phát hiện message trùng lặp trong một time window (ví dụ: 10 phút). Nếu producer gửi 2 message có cùng `MessageId` trong vòng 10 phút, message thứ 2 sẽ bị loại bỏ âm thầm (silently discarded). Tính năng này cực kỳ quan trọng khi network không ổn định — producer gửi message, không nhận được ACK, gửi lại lần nữa. Không có duplicate detection, giao dịch chuyển tiền sẽ bị thực hiện 2 lần.

> **🧠 Kiến thức nền tảng: Sessions — FIFO Ordering**
>
> Mặc định, Service Bus KHÔNG đảm bảo thứ tự message. Nếu producer gửi message A rồi B, consumer có thể nhận B trước A. Trong hệ thống tài chính, điều này là thảm họa: nếu "Credit Receiver" (B) chạy trước "Debit Sender" (A), người nhận nhận tiền từ hư không!
>
> **Sessions** giải quyết vấn đề này. Khi bật Session trên queue, mỗi message phải có `SessionId`. Tất cả message cùng `SessionId` sẽ được xử lý TUẦN TỰ (FIFO) bởi CÙNG MỘT consumer. Trong VietPay, `SessionId = transaction_id`, đảm bảo mọi bước của một giao dịch (validate → debit → credit → notify → audit) chạy đúng thứ tự.

---

## Phase 3: Queue — Producer & Consumer (Python)

### Bước 1: Cài đặt môi trường

> **Purpose:** Cài đặt Azure Service Bus SDK cho Python và thư viện Azure Identity để xác thực an toàn không dùng connection string trực tiếp trong code.

```bash
pip install azure-servicebus azure-identity azure-keyvault-secrets
```

### Bước 2: Producer — Gửi Transaction Messages

> **Purpose:** Mô phỏng hệ thống VietPay gửi các lệnh chuyển tiền vào queue `transaction-processing`. Mỗi message chứa đầy đủ thông tin giao dịch dưới dạng JSON, kèm theo các message properties (metadata) để consumer lọc và xử lý.

Tạo file `producer.py`:

```python
import json
import logging
import uuid
from datetime import datetime, timedelta, timezone
from azure.servicebus import ServiceBusClient, ServiceBusMessage
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

# === LOGGING CONFIGURATION ===
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
logger = logging.getLogger("vietpay.producer")

# === CONFIGURATION ===
KEY_VAULT_URL = "https://kv-vietpay-dev-001.vault.azure.net/"
SECRET_NAME = "sb-connection-string"
QUEUE_NAME = "transaction-processing"

def get_connection_string() -> str:
    """Retrieve Service Bus connection string from Key Vault securely."""
    try:
        credential = DefaultAzureCredential()
        kv_client = SecretClient(vault_url=KEY_VAULT_URL, credential=credential)
        secret = kv_client.get_secret(SECRET_NAME)
        logger.info("✅ Connection string retrieved from Key Vault successfully.")
        return secret.value
    except Exception as e:
        logger.error(f"❌ Failed to retrieve secret from Key Vault: {e}")
        raise

def create_transaction_message(
    sender_account: str,
    receiver_account: str,
    amount: float,
    currency: str = "VND"
) -> ServiceBusMessage:
    """Create a Service Bus message with realistic transaction payload."""
    transaction_id = str(uuid.uuid4())
    payload = {
        "transaction_id": transaction_id,
        "sender_account": sender_account,
        "receiver_account": receiver_account,
        "amount": amount,
        "currency": currency,
        "sender_country": "VN",
        "receiver_country": "VN",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "status": "PENDING"
    }

    message = ServiceBusMessage(
        body=json.dumps(payload, ensure_ascii=False),
        message_id=transaction_id,             # For duplicate detection
        subject="MoneyTransfer",               # Message label/type
        content_type="application/json",
        application_properties={
            "source_system": "vietpay-mobile-app",
            "priority": "high" if amount > 1_000_000 else "normal",
            "version": "1.0"
        }
    )
    return message

def send_batch_transactions():
    """Send a batch of simulated transaction messages to the queue."""
    conn_str = get_connection_string()

    transactions = [
        ("1001-SENDER-VN", "2002-RECEIVER-VN", 500_000),
        ("1003-SENDER-VN", "2004-RECEIVER-VN", 25_000_000),
        ("1005-SENDER-VN", "2006-RECEIVER-JP", 150_000_000),
        ("1007-SENDER-VN", "2008-RECEIVER-VN", 75_000),
        ("1009-SENDER-VN", "2010-RECEIVER-US", 2_500_000),
    ]

    with ServiceBusClient.from_connection_string(conn_str) as client:
        with client.get_queue_sender(queue_name=QUEUE_NAME) as sender:
            for sender_acc, receiver_acc, amount in transactions:
                msg = create_transaction_message(sender_acc, receiver_acc, amount)
                try:
                    sender.send_messages(msg)
                    tx_data = json.loads(str(msg))
                    logger.info(
                        f"📤 Sent transaction {tx_data['transaction_id'][:8]}... "
                        f"Amount: {amount:,.0f} VND"
                    )
                except Exception as e:
                    logger.error(f"❌ Failed to send message: {e}")
                    raise

    logger.info(f"✅ Successfully sent {len(transactions)} transactions to '{QUEUE_NAME}'.")

if __name__ == "__main__":
    send_batch_transactions()
```

### Bước 3: Consumer — Nhận & Xử lý Messages với Peek-Lock

> **Purpose:** Consumer đọc message từ queue, xử lý giao dịch, và quyết định Complete (thành công), Abandon (lỗi tạm thời), hoặc Dead-letter (lỗi vĩnh viễn). Đây là trung tâm xử lý chính của hệ thống.

Tạo file `consumer.py`:

```python
import json
import logging
from azure.servicebus import ServiceBusClient, ServiceBusReceiveMode
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

# === LOGGING CONFIGURATION ===
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
logger = logging.getLogger("vietpay.consumer")

# === CONFIGURATION ===
KEY_VAULT_URL = "https://kv-vietpay-dev-001.vault.azure.net/"
SECRET_NAME = "sb-connection-string"
QUEUE_NAME = "transaction-processing"

def get_connection_string() -> str:
    """Retrieve Service Bus connection string from Key Vault securely."""
    credential = DefaultAzureCredential()
    kv_client = SecretClient(vault_url=KEY_VAULT_URL, credential=credential)
    return kv_client.get_secret(SECRET_NAME).value

def validate_transaction(tx_data: dict) -> tuple[bool, str]:
    """
    Validate transaction data. Returns (is_valid, error_reason).
    In production, this would call the Account Service API.
    """
    required_fields = ["transaction_id", "sender_account", "receiver_account", "amount", "currency"]
    for field in required_fields:
        if field not in tx_data:
            return False, f"Missing required field: {field}"

    if not isinstance(tx_data["amount"], (int, float)):
        return False, f"Invalid amount type: {type(tx_data['amount']).__name__}"

    if tx_data["amount"] <= 0:
        return False, f"Invalid amount: {tx_data['amount']} (must be positive)"

    if tx_data["amount"] > 500_000_000:  # 500M VND limit
        return False, f"Amount exceeds daily limit: {tx_data['amount']:,.0f} VND"

    return True, ""

def process_transaction(tx_data: dict) -> bool:
    """
    Process the transaction (debit sender, credit receiver).
    Returns True if successful, raises exception on transient failure.
    In production, this would call the Core Banking API.
    """
    logger.info(
        f"  💰 Processing: {tx_data['sender_account']} → {tx_data['receiver_account']} "
        f"| Amount: {tx_data['amount']:,.0f} {tx_data['currency']}"
    )
    # Simulate processing logic here
    return True

def consume_transactions():
    """Main consumer loop with Peek-Lock, error handling, and dead-lettering."""
    conn_str = get_connection_string()

    with ServiceBusClient.from_connection_string(conn_str) as client:
        # PEEK_LOCK mode: message stays in queue until explicitly completed
        with client.get_queue_receiver(
            queue_name=QUEUE_NAME,
            receive_mode=ServiceBusReceiveMode.PEEK_LOCK,
            max_wait_time=30  # Wait up to 30 seconds for messages
        ) as receiver:

            logger.info(f"🔄 Listening on queue '{QUEUE_NAME}'...")

            for msg in receiver:
                tx_id_short = msg.message_id[:8] if msg.message_id else "unknown"
                logger.info(f"📥 Received message: {tx_id_short}... "
                            f"(Delivery count: {msg.delivery_count})")

                try:
                    # 1. Parse message body
                    tx_data = json.loads(str(msg))

                    # 2. Validate transaction
                    is_valid, error_reason = validate_transaction(tx_data)

                    if not is_valid:
                        # PERMANENT FAILURE → Dead-letter immediately
                        logger.warning(
                            f"  ⚠️ Validation failed for {tx_id_short}...: {error_reason}"
                        )
                        receiver.dead_letter_message(
                            msg,
                            reason="ValidationFailure",
                            error_description=error_reason
                        )
                        logger.info(f"  💀 Message {tx_id_short}... sent to Dead-Letter Queue.")
                        continue

                    # 3. Process transaction
                    process_transaction(tx_data)

                    # 4. SUCCESS → Complete the message (removes from queue)
                    receiver.complete_message(msg)
                    logger.info(f"  ✅ Transaction {tx_id_short}... completed successfully.")

                except json.JSONDecodeError as e:
                    # PERMANENT FAILURE → Invalid JSON, dead-letter
                    logger.error(f"  ❌ Invalid JSON in message {tx_id_short}...: {e}")
                    receiver.dead_letter_message(
                        msg,
                        reason="MalformedPayload",
                        error_description=f"JSON decode error: {str(e)}"
                    )

                except ConnectionError as e:
                    # TRANSIENT FAILURE → Abandon and retry later
                    logger.warning(
                        f"  🔁 Transient error for {tx_id_short}..., abandoning for retry: {e}"
                    )
                    receiver.abandon_message(msg)

                except Exception as e:
                    # UNKNOWN FAILURE → Abandon (let max_delivery_count handle it)
                    logger.error(f"  ❌ Unexpected error for {tx_id_short}...: {e}")
                    receiver.abandon_message(msg)

    logger.info("🛑 Consumer stopped.")

if __name__ == "__main__":
    consume_transactions()
```

> **Hệ quả nếu bỏ qua:** Nếu consumer không phân biệt giữa transient failure (Abandon) và permanent failure (Dead-letter), message lỗi JSON sẽ bị retry 5 lần vô ích trước khi tự động vào DLQ — lãng phí thời gian xử lý và delay các giao dịch hợp lệ đang xếp hàng phía sau.

---

## Phase 4: Topic & Subscriptions — Pub/Sub Pattern

### Bước 1: Thiết lập SQL Filters cho Subscriptions

> **Purpose:** Filters cho phép mỗi subscription chỉ nhận các message phù hợp, giảm tải xử lý và chi phí. Không có filter, mỗi subscription nhận TẤT CẢ message — lãng phí tài nguyên.

Mở Azure Portal > Service Bus Namespace > Topic `transaction-events` > từng Subscription:

**Subscription 1: `notification-service`** (chỉ nhận giao dịch giá trị cao > 1 triệu VND)
- Vào **Filters** > Xóa filter mặc định `$Default` (True filter) > Thêm **SQL Filter**:
```sql
amount > 1000000
```

**Subscription 2: `audit-service`** (nhận TẤT CẢ message — compliance requirement)
- Giữ nguyên filter mặc định `$Default` (Boolean True filter = nhận tất cả).

**Subscription 3: `fraud-detection`** (chỉ nhận giao dịch quốc tế)
- Xóa filter mặc định > Thêm **SQL Filter**:
```sql
sender_country <> receiver_country
```

> **🧠 Kiến thức nền tảng: Ba loại Filter trong Service Bus**
>
> 1. **Boolean Filter:** `TrueFilter` (nhận tất cả) hoặc `FalseFilter` (chặn tất cả). Mỗi subscription mặc định có `TrueFilter`.
> 2. **SQL Filter:** Biểu thức SQL-like trên application properties của message. Hỗ trợ `=`, `<>`, `>`, `<`, `LIKE`, `IN`, `AND`, `OR`, `NOT`, `IS NULL`, `IS NOT NULL`. Ví dụ: `priority = 'high' AND amount > 1000000`.
> 3. **Correlation Filter:** So khớp chính xác (exact match) trên system properties hoặc custom properties. Hiệu suất cao nhất vì sử dụng hash-match thay vì eval expression. Ví dụ: `CorrelationId = 'payment-batch-001'`.
>
> **Quy tắc chọn filter:** Dùng Correlation Filter khi có thể (hiệu suất tốt nhất). Dùng SQL Filter khi cần logic phức tạp. Tránh `TrueFilter` trừ khi subscription thực sự cần nhận mọi message.

### Bước 2: Publisher — Gửi Events lên Topic

> **Purpose:** Khi một giao dịch hoàn tất thành công trong queue `transaction-processing`, Transaction Service sẽ publish event `TransactionCompleted` lên topic `transaction-events` để các service khác xử lý song song.

Tạo file `publisher.py`:

```python
import json
import logging
import uuid
from datetime import datetime, timezone
from azure.servicebus import ServiceBusClient, ServiceBusMessage
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("vietpay.publisher")

KEY_VAULT_URL = "https://kv-vietpay-dev-001.vault.azure.net/"
SECRET_NAME = "sb-connection-string"
TOPIC_NAME = "transaction-events"

def get_connection_string() -> str:
    credential = DefaultAzureCredential()
    kv_client = SecretClient(vault_url=KEY_VAULT_URL, credential=credential)
    return kv_client.get_secret(SECRET_NAME).value

def publish_transaction_event(
    transaction_id: str,
    sender_account: str,
    receiver_account: str,
    amount: float,
    sender_country: str = "VN",
    receiver_country: str = "VN"
):
    """Publish a TransactionCompleted event to the topic."""
    conn_str = get_connection_string()

    event_payload = {
        "event_type": "TransactionCompleted",
        "transaction_id": transaction_id,
        "sender_account": sender_account,
        "receiver_account": receiver_account,
        "amount": amount,
        "currency": "VND",
        "sender_country": sender_country,
        "receiver_country": receiver_country,
        "completed_at": datetime.now(timezone.utc).isoformat()
    }

    message = ServiceBusMessage(
        body=json.dumps(event_payload, ensure_ascii=False),
        message_id=str(uuid.uuid4()),
        subject="TransactionCompleted",
        content_type="application/json",
        application_properties={
            "amount": amount,
            "sender_country": sender_country,
            "receiver_country": receiver_country,
            "event_type": "TransactionCompleted"
        }
    )

    with ServiceBusClient.from_connection_string(conn_str) as client:
        with client.get_topic_sender(topic_name=TOPIC_NAME) as sender:
            sender.send_messages(message)
            logger.info(
                f"📤 Published event: {transaction_id[:8]}... "
                f"Amount: {amount:,.0f} VND | "
                f"Route: {sender_country} → {receiver_country}"
            )

if __name__ == "__main__":
    # Simulate publishing events for completed transactions
    test_events = [
        ("tx-001", "1001-VN", "2002-VN", 500_000, "VN", "VN"),       # Low value, domestic
        ("tx-002", "1003-VN", "2004-VN", 25_000_000, "VN", "VN"),    # High value, domestic
        ("tx-003", "1005-VN", "2006-JP", 150_000_000, "VN", "JP"),   # High value, international
        ("tx-004", "1007-VN", "2008-VN", 75_000, "VN", "VN"),        # Low value, domestic
        ("tx-005", "1009-VN", "2010-US", 2_500_000, "VN", "US"),     # High value, international
    ]

    for tx_id, sender, receiver, amount, s_country, r_country in test_events:
        publish_transaction_event(tx_id, sender, receiver, amount, s_country, r_country)

    logger.info("✅ All events published successfully.")
    # Expected routing:
    #   notification-service: tx-002, tx-003, tx-005 (amount > 1M)
    #   audit-service: ALL 5 events
    #   fraud-detection: tx-003, tx-005 (sender_country != receiver_country)
```

### Bước 3: Subscribers — Nhận Events từ mỗi Subscription

> **Purpose:** Mỗi subscriber là một microservice độc lập, chỉ nhận và xử lý các event phù hợp với filter của subscription đó.

Tạo file `subscribers.py`:

```python
import json
import logging
from azure.servicebus import ServiceBusClient, ServiceBusReceiveMode
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("vietpay.subscriber")

KEY_VAULT_URL = "https://kv-vietpay-dev-001.vault.azure.net/"
SECRET_NAME = "sb-connection-string"
TOPIC_NAME = "transaction-events"

def get_connection_string() -> str:
    credential = DefaultAzureCredential()
    kv_client = SecretClient(vault_url=KEY_VAULT_URL, credential=credential)
    return kv_client.get_secret(SECRET_NAME).value

def consume_subscription(subscription_name: str, handler_name: str):
    """Generic subscriber that listens to a specific subscription."""
    conn_str = get_connection_string()

    with ServiceBusClient.from_connection_string(conn_str) as client:
        with client.get_subscription_receiver(
            topic_name=TOPIC_NAME,
            subscription_name=subscription_name,
            receive_mode=ServiceBusReceiveMode.PEEK_LOCK,
            max_wait_time=15
        ) as receiver:

            logger.info(f"🔄 [{handler_name}] Listening on subscription '{subscription_name}'...")

            for msg in receiver:
                try:
                    event = json.loads(str(msg))
                    tx_id = event.get("transaction_id", "N/A")[:8]

                    if handler_name == "NotificationService":
                        logger.info(
                            f"  📧 [{handler_name}] Sending HIGH-VALUE alert for "
                            f"tx {tx_id}... Amount: {event['amount']:,.0f} VND"
                        )
                    elif handler_name == "AuditService":
                        logger.info(
                            f"  📋 [{handler_name}] Logging audit record for tx {tx_id}..."
                        )
                    elif handler_name == "FraudDetection":
                        logger.info(
                            f"  🔍 [{handler_name}] Analyzing cross-border tx {tx_id}... "
                            f"Route: {event['sender_country']} → {event['receiver_country']}"
                        )

                    receiver.complete_message(msg)
                    logger.info(f"  ✅ [{handler_name}] Event {tx_id}... processed.")

                except Exception as e:
                    logger.error(f"  ❌ [{handler_name}] Error processing message: {e}")
                    receiver.abandon_message(msg)

    logger.info(f"🛑 [{handler_name}] Subscriber stopped.")

if __name__ == "__main__":
    import sys
    # Usage: python subscribers.py notification|audit|fraud
    service_map = {
        "notification": ("notification-service", "NotificationService"),
        "audit":        ("audit-service", "AuditService"),
        "fraud":        ("fraud-detection", "FraudDetection"),
    }

    if len(sys.argv) < 2 or sys.argv[1] not in service_map:
        print("Usage: python subscribers.py [notification|audit|fraud]")
        sys.exit(1)

    sub_name, handler = service_map[sys.argv[1]]
    consume_subscription(sub_name, handler)
```

---

## Phase 5: Dead-Letter Queue Processing

### Bước 1: Mô phỏng Poison Message

> **Purpose:** Hiểu cách message tự động vào DLQ khi vượt max delivery count, và cách consumer chủ động dead-letter message khi phát hiện lỗi vĩnh viễn.

Tạo file `poison_producer.py`:

```python
import json
import logging
from azure.servicebus import ServiceBusClient, ServiceBusMessage
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("vietpay.poison")

KEY_VAULT_URL = "https://kv-vietpay-dev-001.vault.azure.net/"
SECRET_NAME = "sb-connection-string"
QUEUE_NAME = "transaction-processing"

def get_connection_string() -> str:
    credential = DefaultAzureCredential()
    kv_client = SecretClient(vault_url=KEY_VAULT_URL, credential=credential)
    return kv_client.get_secret(SECRET_NAME).value

def send_poison_messages():
    """Send intentionally malformed messages to test DLQ handling."""
    conn_str = get_connection_string()

    poison_messages = [
        # 1. Invalid JSON
        ServiceBusMessage(
            body="THIS IS NOT VALID JSON {{{",
            message_id="poison-001-invalid-json",
            subject="MoneyTransfer",
            content_type="application/json"
        ),
        # 2. Missing required field (no 'amount')
        ServiceBusMessage(
            body=json.dumps({
                "transaction_id": "poison-002",
                "sender_account": "1001-VN",
                "receiver_account": "2002-VN",
                # "amount" is intentionally missing!
                "currency": "VND"
            }),
            message_id="poison-002-missing-field",
            subject="MoneyTransfer",
            content_type="application/json"
        ),
        # 3. Negative amount
        ServiceBusMessage(
            body=json.dumps({
                "transaction_id": "poison-003",
                "sender_account": "1001-VN",
                "receiver_account": "2002-VN",
                "amount": -500000,
                "currency": "VND"
            }),
            message_id="poison-003-negative-amount",
            subject="MoneyTransfer",
            content_type="application/json"
        ),
    ]

    with ServiceBusClient.from_connection_string(conn_str) as client:
        with client.get_queue_sender(queue_name=QUEUE_NAME) as sender:
            for msg in poison_messages:
                sender.send_messages(msg)
                logger.info(f"☠️ Sent poison message: {msg.message_id}")

    logger.info(f"✅ Sent {len(poison_messages)} poison messages to '{QUEUE_NAME}'.")
    logger.info("Now run consumer.py — these messages will be dead-lettered.")

if __name__ == "__main__":
    send_poison_messages()
```

### Bước 2: DLQ Processor — Đọc, Log, và Alert

> **Purpose:** Xây dựng service chuyên xử lý Dead-Letter Queue: đọc message lỗi, ghi log chi tiết nguyên nhân lỗi, gửi alert cho team vận hành, và cung cấp option resubmit message đã sửa.

Tạo file `dlq_processor.py`:

```python
import json
import logging
from datetime import datetime, timezone
from azure.servicebus import ServiceBusClient, ServiceBusReceiveMode

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("vietpay.dlq_processor")

QUEUE_NAME = "transaction-processing"

def get_connection_string() -> str:
    """In production, retrieve from Key Vault. Simplified for DLQ processing."""
    from azure.identity import DefaultAzureCredential
    from azure.keyvault.secrets import SecretClient
    KEY_VAULT_URL = "https://kv-vietpay-dev-001.vault.azure.net/"
    credential = DefaultAzureCredential()
    kv_client = SecretClient(vault_url=KEY_VAULT_URL, credential=credential)
    return kv_client.get_secret("sb-connection-string").value

def process_dead_letters():
    """Read, analyze, and alert on dead-lettered messages."""
    conn_str = get_connection_string()

    with ServiceBusClient.from_connection_string(conn_str) as client:
        # Access the DLQ sub-queue using the dedicated receiver
        with client.get_queue_receiver(
            queue_name=QUEUE_NAME,
            sub_queue="deadletter",   # <-- This targets the DLQ!
            receive_mode=ServiceBusReceiveMode.PEEK_LOCK,
            max_wait_time=10
        ) as dlq_receiver:

            logger.info(f"🔍 Scanning Dead-Letter Queue for '{QUEUE_NAME}'...")
            dlq_count = 0

            for msg in dlq_receiver:
                dlq_count += 1
                logger.info("=" * 60)
                logger.info(f"💀 DLQ Message #{dlq_count}")
                logger.info(f"   Message ID:          {msg.message_id}")
                logger.info(f"   Enqueued Time:       {msg.enqueued_time_utc}")
                logger.info(f"   Delivery Count:      {msg.delivery_count}")
                logger.info(f"   Dead-Letter Reason:  {msg.dead_letter_reason}")
                logger.info(f"   Error Description:   {msg.dead_letter_error_description}")

                # Attempt to parse body for debugging
                try:
                    body = json.loads(str(msg))
                    logger.info(f"   Body (parsed):       {json.dumps(body, indent=2)}")
                except (json.JSONDecodeError, Exception):
                    raw_body = str(msg)
                    logger.info(f"   Body (raw):          {raw_body[:200]}")

                # === ALERT LOGIC (in production, send to PagerDuty/Slack/Email) ===
                alert_payload = {
                    "severity": "HIGH",
                    "source": "VietPay DLQ Processor",
                    "message_id": msg.message_id,
                    "dead_letter_reason": msg.dead_letter_reason,
                    "timestamp": datetime.now(timezone.utc).isoformat()
                }
                logger.warning(f"   🚨 ALERT SENT: {json.dumps(alert_payload)}")

                # Complete to remove from DLQ after processing
                dlq_receiver.complete_message(msg)
                logger.info(f"   ✅ DLQ message {msg.message_id} processed and removed.")

            logger.info("=" * 60)
            if dlq_count == 0:
                logger.info("🎉 Dead-Letter Queue is empty — no issues found!")
            else:
                logger.info(f"📊 Processed {dlq_count} dead-lettered message(s).")

if __name__ == "__main__":
    process_dead_letters()
```

> **Hệ quả nếu bỏ qua:** Nếu không xây dựng DLQ processor, các giao dịch lỗi sẽ nằm vĩnh viễn trong DLQ mà không ai biết. Tiền đã trừ tài khoản khách hàng nhưng giao dịch không hoàn tất — dẫn đến khiếu nại, mất uy tín, và vi phạm quy định ngân hàng nhà nước.

---

## Phase 6: Sessions — Ordered Processing (FIFO)

### Tại sao thứ tự quan trọng trong Banking?

> **🧠 Kiến thức nền tảng:**
>
> Hãy tưởng tượng giao dịch chuyển 10 triệu VND từ tài khoản A sang B. Hệ thống tạo 2 message:
> - Message 1: "Trừ 10 triệu từ A" (Debit)
> - Message 2: "Cộng 10 triệu cho B" (Credit)
>
> Nếu KHÔNG có Sessions, consumer có thể nhận Message 2 trước Message 1. Kết quả: B nhận 10 triệu từ hư không (tiền chưa bị trừ từ A). Hoặc tệ hơn, nếu Message 1 và Message 2 được xử lý bởi 2 consumer khác nhau trên 2 server khác nhau, race condition có thể dẫn đến sai sót tài chính.
>
> **Sessions đảm bảo:** Tất cả message có cùng `SessionId` sẽ được gửi tới CÙNG MỘT consumer và xử lý TUẦN TỰ. Bằng cách đặt `SessionId = transaction_id`, mọi bước của giao dịch (debit → credit → notify) sẽ chạy đúng thứ tự trên cùng một consumer instance.

### Bước 1: Tạo Session-enabled Queue

> **Purpose:** Tạo queue riêng hỗ trợ Sessions để demo FIFO ordering. Sessions PHẢI được bật lúc tạo queue — không thể bật sau khi queue đã tồn tại.

1. Mở Service Bus Namespace > **Queues** > **+ Queue**.
2. Điền:
   - **Name:** `transaction-ordered`
   - **Enable sessions:** ✅ **Bật** (CRITICAL — không thể thay đổi sau khi tạo).
   - **Max delivery count:** `5`.
   - **Lock duration:** `60 seconds` (lâu hơn vì session processing cần thời gian).
3. Nhấn **Create**.

### Bước 2: Session Producer — Gửi Messages theo thứ tự

> **Purpose:** Gửi các bước xử lý giao dịch (validate → debit → credit → notify → audit) vào queue với cùng SessionId, đảm bảo chúng sẽ được xử lý tuần tự.

Tạo file `session_producer.py`:

```python
import json
import logging
import uuid
from datetime import datetime, timezone
from azure.servicebus import ServiceBusClient, ServiceBusMessage

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("vietpay.session_producer")

QUEUE_NAME = "transaction-ordered"

def get_connection_string() -> str:
    from azure.identity import DefaultAzureCredential
    from azure.keyvault.secrets import SecretClient
    credential = DefaultAzureCredential()
    kv_client = SecretClient(
        vault_url="https://kv-vietpay-dev-001.vault.azure.net/",
        credential=credential
    )
    return kv_client.get_secret("sb-connection-string").value

def send_ordered_transaction():
    """Send a multi-step transaction as ordered session messages."""
    conn_str = get_connection_string()
    transaction_id = str(uuid.uuid4())
    session_id = transaction_id  # All steps share the same session

    steps = [
        {"step": 1, "action": "VALIDATE",   "detail": "Check balance and OTP"},
        {"step": 2, "action": "DEBIT",       "detail": "Debit 10,000,000 VND from sender"},
        {"step": 3, "action": "CREDIT",      "detail": "Credit 10,000,000 VND to receiver"},
        {"step": 4, "action": "NOTIFY",      "detail": "Send SMS/Email confirmation"},
        {"step": 5, "action": "AUDIT_LOG",   "detail": "Record in compliance system"},
    ]

    with ServiceBusClient.from_connection_string(conn_str) as client:
        with client.get_queue_sender(queue_name=QUEUE_NAME) as sender:
            for step_data in steps:
                payload = {
                    "transaction_id": transaction_id,
                    "session_id": session_id,
                    **step_data,
                    "timestamp": datetime.now(timezone.utc).isoformat()
                }
                message = ServiceBusMessage(
                    body=json.dumps(payload),
                    session_id=session_id,   # <-- CRITICAL: Binds to session
                    message_id=f"{transaction_id}-step-{step_data['step']}",
                    subject=step_data["action"],
                    content_type="application/json"
                )
                sender.send_messages(message)
                logger.info(
                    f"📤 Step {step_data['step']}/5: {step_data['action']} "
                    f"(Session: {session_id[:8]}...)"
                )

    logger.info(f"✅ All 5 steps for transaction {transaction_id[:8]}... sent in order.")

if __name__ == "__main__":
    send_ordered_transaction()
```

### Bước 3: Session Consumer — Xử lý tuần tự theo Session

> **Purpose:** Consumer mở một session cụ thể và xử lý tất cả message trong session đó theo thứ tự FIFO. Khi session hoàn tất, consumer chuyển sang session tiếp theo.

Tạo file `session_consumer.py`:

```python
import json
import logging
from azure.servicebus import ServiceBusClient, ServiceBusReceiveMode

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("vietpay.session_consumer")

QUEUE_NAME = "transaction-ordered"

def get_connection_string() -> str:
    from azure.identity import DefaultAzureCredential
    from azure.keyvault.secrets import SecretClient
    credential = DefaultAzureCredential()
    kv_client = SecretClient(
        vault_url="https://kv-vietpay-dev-001.vault.azure.net/",
        credential=credential
    )
    return kv_client.get_secret("sb-connection-string").value

def consume_sessions():
    """Process messages in strict FIFO order per session."""
    conn_str = get_connection_string()

    with ServiceBusClient.from_connection_string(conn_str) as client:
        logger.info(f"🔄 Session consumer started on '{QUEUE_NAME}'...")

        while True:
            try:
                # Accept the NEXT AVAILABLE session (blocks until one is available)
                with client.get_queue_receiver(
                    queue_name=QUEUE_NAME,
                    receive_mode=ServiceBusReceiveMode.PEEK_LOCK,
                    session_id=None,      # None = accept any available session
                    max_wait_time=30
                ) as session_receiver:

                    session_id = session_receiver.session.session_id
                    logger.info(f"📂 Opened session: {session_id[:8]}...")

                    for msg in session_receiver:
                        try:
                            step_data = json.loads(str(msg))
                            logger.info(
                                f"  🔹 Step {step_data['step']}/5: "
                                f"{step_data['action']} — {step_data['detail']}"
                            )
                            # Simulate processing time
                            session_receiver.complete_message(msg)
                        except Exception as e:
                            logger.error(f"  ❌ Error processing step: {e}")
                            session_receiver.abandon_message(msg)

                    logger.info(f"📂 Session {session_id[:8]}... completed (all steps processed).")

            except StopIteration:
                logger.info("⏳ No more sessions available. Waiting...")
                break
            except Exception as e:
                if "no sessions available" in str(e).lower() or "timeout" in str(e).lower():
                    logger.info("⏳ No sessions available. Exiting.")
                    break
                logger.error(f"❌ Session error: {e}")
                break

    logger.info("🛑 Session consumer stopped.")

if __name__ == "__main__":
    consume_sessions()
```

---

## Phase 7: Advanced Patterns

### Pattern 1: Request-Reply (Correlation)

> **Purpose:** Trong kiến trúc microservices, đôi khi Service A gửi request và cần nhận response từ Service B. Request-Reply pattern sử dụng `ReplyTo` (queue trả lời) và `CorrelationId` (liên kết request-response) để thực hiện điều này qua messaging.

> **🧠 Kiến thức nền tảng:** Pattern này thay thế synchronous HTTP call bằng asynchronous messaging. Service A gửi request vào queue Q1 với `ReplyTo = "reply-queue"` và `CorrelationId = request_id`. Service B nhận request từ Q1, xử lý, gửi response vào `reply-queue` với cùng `CorrelationId`. Service A lắng nghe `reply-queue`, match `CorrelationId` để tìm đúng response. Lợi ích: Service A không bị block chờ response, và hệ thống có khả năng chịu lỗi cao hơn.

```python
# === REQUEST SIDE (Balance Check Service) ===
import uuid
from azure.servicebus import ServiceBusMessage

request_id = str(uuid.uuid4())
request_msg = ServiceBusMessage(
    body='{"account_id": "1001-VN", "action": "CHECK_BALANCE"}',
    message_id=request_id,
    reply_to="balance-reply-queue",          # Where to send the response
    correlation_id=request_id,               # Link request to response
    subject="BalanceCheckRequest",
    content_type="application/json"
)
# Send to request queue...

# === RESPONSE SIDE (Account Service) ===
# After processing the request:
response_msg = ServiceBusMessage(
    body='{"account_id": "1001-VN", "balance": 45000000, "currency": "VND"}',
    message_id=str(uuid.uuid4()),
    correlation_id=received_msg.correlation_id,  # Match with original request
    subject="BalanceCheckResponse",
    content_type="application/json"
)
# Send to the reply_to queue specified in the request...
```

### Pattern 2: Scheduled Messages (Gửi bây giờ, giao sau)

> **Purpose:** Cho phép gửi message ngay nhưng chỉ visible cho consumer tại thời điểm được chỉ định trong tương lai. Rất hữu ích cho payment reminders, scheduled reports, delayed notifications.

```python
from datetime import datetime, timedelta, timezone
from azure.servicebus import ServiceBusMessage

# Schedule a payment reminder for 24 hours from now
reminder_msg = ServiceBusMessage(
    body='{"type": "PAYMENT_REMINDER", "account": "1001-VN", "due_amount": 5000000}',
    message_id="reminder-001",
    subject="PaymentReminder"
)

scheduled_time = datetime.now(timezone.utc) + timedelta(hours=24)

with client.get_queue_sender(queue_name="transaction-processing") as sender:
    # Message will be invisible until scheduled_time
    sequence_number = sender.schedule_messages(reminder_msg, scheduled_time)
    print(f"⏰ Message scheduled for {scheduled_time}. Sequence: {sequence_number}")

    # Cancel the scheduled message if needed (e.g., customer paid early)
    # sender.cancel_scheduled_messages(sequence_number)
```

### Pattern 3: Message Deferral (Nhận nhưng xử lý sau)

> **Purpose:** Consumer nhận message nhưng chưa muốn xử lý ngay (ví dụ: đang chờ dependency). Message bị defer sẽ không visible cho consumer khác, chỉ có thể nhận lại bằng sequence number.

> **🧠 Kiến thức nền tảng:** Deferral khác với Abandon. Abandon trả message lại queue cho BẤT KỲ consumer nào nhận. Deferral "ghim" message — chỉ consumer biết sequence number mới lấy lại được. Ví dụ: nhận được step "Credit Receiver" nhưng step "Debit Sender" chưa hoàn tất → defer message, đợi debit xong rồi receive deferred message bằng sequence number.

```python
# Defer a message for later processing
sequence_number = msg.sequence_number
receiver.defer_message(msg)
print(f"⏸️ Message deferred. Sequence number: {sequence_number}")

# Later, receive the deferred message by its sequence number
deferred_msg = receiver.receive_deferred_messages(
    sequence_numbers=[sequence_number]
)
for d_msg in deferred_msg:
    # Process and complete
    receiver.complete_message(d_msg)
    print(f"▶️ Deferred message {d_msg.sequence_number} processed.")
```

### Pattern 4: Auto-forwarding (Queue Chaining)

> **Purpose:** Tự động chuyển tiếp message từ queue/subscription này sang queue khác mà không cần code trung gian. Hữu ích cho pipeline processing hoặc error routing.

Cấu hình trong Azure Portal:
1. Mở Subscription `audit-service` trong Topic `transaction-events`.
2. Trong **Properties**, tìm **Forward messages to:** và chọn queue đích (ví dụ: `audit-archive-queue`).
3. Mọi message đến subscription `audit-service` sẽ tự động copy sang `audit-archive-queue`.

> **Hệ quả nếu bỏ qua:** Nếu không sử dụng auto-forwarding cho audit archival, bạn phải viết consumer riêng chỉ để copy message từ subscription sang archive queue — thêm code, thêm compute cost, thêm failure point.

---

## Phase 8: Integration với Azure Functions

### Service Bus Trigger — Auto-scaling Consumers

> **Purpose:** Azure Functions tự động scale consumer instances dựa trên số message trong queue. Khi queue trống — 0 instances (chi phí = 0). Khi có 10,000 message — tự động scale lên hàng chục instances. Thay thế hoàn toàn traditional worker services chạy 24/7.

> **🧠 Kiến thức nền tảng:** Trước khi có Serverless, bạn phải chạy VM hoặc Container 24/7 để lắng nghe queue, ngay cả khi không có message nào. Với Azure Functions + Service Bus Trigger, bạn chỉ trả tiền khi có message cần xử lý. Function tự động wake up khi message đến, xử lý, rồi tự tắt. Pattern này gọi là **Event-driven Compute** — cực kỳ cost-effective cho workload không đều (burst traffic vào giờ cao điểm, gần bằng 0 vào ban đêm).

**1. Tạo Azure Function App:**

1. Tìm **Function App** > **Create**.
2. Điền:
   - **Resource group:** `rg-vietpay-messaging-dev`
   - **Function App name:** `func-vietpay-processor-001`
   - **Runtime stack:** Python 3.11.
   - **Region:** `Southeast Asia`.
   - **Plan type:** **Consumption (Serverless)** (pay-per-execution).
3. Nhấn **Review + create** -> **Create**.

**2. Tạo Function với Service Bus Queue Trigger:**

```python
# function_app.py
import azure.functions as func
import json
import logging

app = func.FunctionApp()

@app.service_bus_queue_trigger(
    arg_name="msg",
    queue_name="transaction-processing",
    connection="ServiceBusConnection"   # App Setting containing connection string
)
def process_transaction(msg: func.ServiceBusMessage):
    """
    Auto-triggered when a message arrives in the queue.
    Azure Functions handles Peek-Lock and Complete automatically:
    - If function returns successfully → message is Completed.
    - If function throws exception → message is Abandoned (retried).
    - After max_delivery_count retries → message goes to DLQ.
    """
    try:
        tx_data = json.loads(msg.get_body().decode("utf-8"))
        tx_id = tx_data.get("transaction_id", "N/A")

        logging.info(
            f"📥 Function triggered for tx: {tx_id[:8]}... "
            f"Amount: {tx_data.get('amount', 0):,.0f} VND"
        )

        # === BUSINESS LOGIC ===
        # Validate
        if tx_data.get("amount", 0) <= 0:
            raise ValueError(f"Invalid amount: {tx_data.get('amount')}")

        # Process (debit/credit calls to Core Banking API)
        logging.info(f"  💰 Processing transaction {tx_id[:8]}...")

        # If we reach here without exception, Function runtime auto-completes the message
        logging.info(f"  ✅ Transaction {tx_id[:8]}... processed successfully.")

    except Exception as e:
        logging.error(f"  ❌ Failed to process: {e}")
        # Re-raise to trigger Abandon → retry → eventually DLQ
        raise
```

**3. Tạo Function với Service Bus Topic Trigger:**

```python
@app.service_bus_topic_trigger(
    arg_name="msg",
    topic_name="transaction-events",
    subscription_name="notification-service",
    connection="ServiceBusConnection"
)
def send_notification(msg: func.ServiceBusMessage):
    """Auto-triggered for high-value transaction notifications."""
    event = json.loads(msg.get_body().decode("utf-8"))
    logging.info(
        f"📧 Sending notification for tx: {event['transaction_id'][:8]}... "
        f"Amount: {event['amount']:,.0f} VND"
    )
    # In production: call SendGrid/Twilio API here
```

> **Hệ quả nếu bỏ qua:** Nếu dùng traditional worker service (VM/Container chạy 24/7) thay vì Azure Functions, chi phí vận hành tăng 10-50x. Một VM B1s chạy 24/7 tốn ~$7/tháng ngay cả khi không xử lý gì. Azure Functions Consumption plan: $0 khi không có message.

---

## Phase 9: Monitoring & Troubleshooting

### Bước 1: Azure Monitor Metrics

> **Purpose:** Giám sát real-time số lượng message trong queue, DLQ, và scheduled messages để phát hiện sớm các vấn đề (message tích tụ, DLQ tăng đột biến).

Mở Service Bus Namespace > **Monitoring** > **Metrics**:

| Metric | Ý nghĩa | Ngưỡng cảnh báo |
|---|---|---|
| **Active Messages** | Số message đang chờ xử lý trong queue | > 10,000 = consumer quá chậm |
| **Dead-lettered Messages** | Số message trong DLQ | > 0 = CẦN KIỂM TRA NGAY |
| **Scheduled Messages** | Số message đã schedule cho tương lai | Thông tin, không cần alert |
| **Incoming Messages** | Tổng message nhận vào/phút | Baseline monitoring |
| **Outgoing Messages** | Tổng message hoàn tất/phút | Nên ≈ Incoming Messages |
| **Server Errors** | Lỗi phía Service Bus | > 0 = liên hệ Microsoft support |

**Thiết lập Alert:**
1. Trong **Metrics**, chọn metric `Dead-lettered Messages`.
2. Bấm **New alert rule**.
3. Condition: `Dead-lettered Messages > 0`.
4. Action Group: Email/SMS tới team vận hành.

### Bước 2: Service Bus Explorer (Built-in)

> **Purpose:** Tool tích hợp sẵn trong Azure Portal cho phép peek (xem mà không xóa), receive, send, và dead-letter message trực tiếp từ giao diện web. Cực kỳ hữu ích để debug.

1. Mở Queue `transaction-processing` > **Service Bus Explorer**.
2. Chọn tab **Peek** để xem message đang trong queue mà không ảnh hưởng delivery count.
3. Chọn tab **Receive** để nhận và complete/dead-letter message thủ công.
4. Chuyển sang **Dead-letter** sub-tab để inspect DLQ messages.

### Bước 3: Troubleshooting — Các Lỗi Thường Gặp

> **🧠 Kiến thức nền tảng: Common Issues & Solutions**
>
> | Lỗi | Nguyên nhân | Giải pháp |
> |---|---|---|
> | `MessageLockLostException` | Consumer xử lý message quá lâu, lock hết hạn (> lock duration) | Tăng lock duration (lên 5 phút) hoặc gọi `receiver.renew_message_lock(msg)` định kỳ |
> | `MessageNotFoundException` | Gọi Complete/Abandon trên message đã hết lock hoặc đã bị xử lý bởi consumer khác | Kiểm tra lock duration, xử lý exception gracefully |
> | `SessionCannotBeLockedException` | Session đang bị lock bởi consumer khác | Đợi session lock hết hạn hoặc dùng `session_id=None` để accept session bất kỳ |
> | `QuotaExceededException` | Queue đầy (đạt max size, ví dụ 1 GB) | Scale lên Premium tier hoặc tăng max size, đồng thời kiểm tra tại sao consumer không kịp xử lý |
> | `ServerBusyException` | Service Bus cluster quá tải (Standard tier) | Retry với exponential backoff, cân nhắc chuyển lên Premium tier |
>
> **Scaling với Premium Tier — Messaging Units:**
> Premium tier cho phép cấu hình **Messaging Units (MU)** — mỗi MU cung cấp tài nguyên compute và memory dedicated. 1 MU xử lý ~1,000 messages/giây. Nếu VietPay cần 5,000 msg/sec vào giờ cao điểm, cấu hình 8 MU (để có headroom). Premium hỗ trợ auto-scale MU từ 1 đến 16 dựa trên CPU usage.

---

## Phase 10: End-to-End Testing & Dọn dẹp Tài nguyên

### Kiểm thử Toàn diện (E2E Test)

> **Purpose:** Xác minh toàn bộ luồng messaging hoạt động đúng: từ producer gửi message, consumer xử lý, event publish lên topic, subscriber nhận event, poison message vào DLQ, và session ordering.

Thực hiện tuần tự:

1. **Test Queue (Point-to-Point):**
   ```bash
   python producer.py        # Gửi 5 giao dịch vào queue
   python consumer.py        # Xử lý 5 giao dịch — tất cả phải Complete
   ```
   ✅ Kiểm tra: Azure Portal > Queue `transaction-processing` > Active Messages = 0.

2. **Test Topic (Pub/Sub):**
   ```bash
   python publisher.py       # Publish 5 events lên topic
   python subscribers.py notification  # Nhận 3 events (amount > 1M)
   python subscribers.py audit         # Nhận 5 events (tất cả)
   python subscribers.py fraud         # Nhận 2 events (cross-border)
   ```
   ✅ Kiểm tra: Mỗi subscription active messages = 0.

3. **Test Dead-Letter Queue:**
   ```bash
   python poison_producer.py   # Gửi 3 poison messages
   python consumer.py          # Consumer dead-letter cả 3
   python dlq_processor.py     # DLQ processor đọc, log, alert
   ```
   ✅ Kiểm tra: DLQ messages = 0 sau khi processor chạy xong.

4. **Test Sessions (FIFO):**
   ```bash
   python session_producer.py  # Gửi 5 steps ordered
   python session_consumer.py  # Xử lý tuần tự: VALIDATE → DEBIT → CREDIT → NOTIFY → AUDIT
   ```
   ✅ Kiểm tra: Log output hiển thị steps 1→2→3→4→5 đúng thứ tự.

### Dọn dẹp Tài nguyên (Clean up)

> **Purpose:** Xóa toàn bộ hạ tầng đã tạo để hệ thống ngừng tính phí dịch vụ trên Azure. Đây là thói quen bắt buộc sau khi hoàn thành các bài Lab thực hành.

Chỉ cần một thao tác duy nhất vì chúng ta đã gom tất cả vào chung một Resource Group:

1. Đăng nhập [portal.azure.com](https://portal.azure.com).
2. Mở mục **Resource groups**.
3. Chọn `rg-vietpay-messaging-dev`.
4. Bấm nút **Delete resource group** ở menu trên cùng.
5. Gõ lại tên `rg-vietpay-messaging-dev` vào ô xác nhận và bấm **Delete**.

Quá trình xóa sẽ diễn ra trong vài phút và Azure sẽ không còn tính bất kỳ chi phí nào nữa.

> **Hệ quả nếu bỏ qua:** Service Bus Standard tier tính phí ~$10/tháng ngay cả khi không sử dụng. Nếu quên xóa và để chạy 12 tháng = $120 lãng phí. Premium tier: ~$677/tháng — quên xóa 1 tháng = mất gần $700.
