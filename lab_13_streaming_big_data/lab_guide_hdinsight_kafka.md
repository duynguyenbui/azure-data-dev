# Hướng dẫn Lab 13: Deep Dive Apache Kafka trên Azure (Azure HDInsight Kafka)

> **Mức độ**: Advanced
> **Thời gian ước tính**: 3-4 giờ
> **Công nghệ**: Azure Virtual Network (VNet), Azure HDInsight Kafka, Apache Zookeeper, Python (confluent-kafka)

---

## 📖 Bối cảnh nghiệp vụ (Business Scenario)

Công ty thương mại điện tử **MecaTech** đang đối mặt với bài toán xử lý lượng lớn dữ liệu clickstream (lịch sử click chuột, xem sản phẩm của người dùng trên web) theo thời gian thực (real-time). 
Họ cần một hệ thống có khả năng:
1. Nhận hàng chục ngàn sự kiện (events) mỗi giây.
2. Lưu trữ an toàn, không mất mát dữ liệu (high durability).
3. Cho phép nhiều hệ thống khác nhau (Recommendation Engine, Dashboard Real-time, Data Lake) cùng đọc một luồng dữ liệu mà không ảnh hưởng lẫn nhau.

**Tại sao chọn Apache Kafka trên Azure (HDInsight) thay vì Event Hubs?**
Dù Event Hubs rất tốt và dễ dùng, MecaTech quyết định dùng **Apache Kafka thuần túy (Native Kafka) trên Azure HDInsight** vì:
- Họ muốn toàn quyền kiểm soát cấu hình Kafka (Kafka broker configs, custom partitioners, log compaction).
- Họ đang sử dụng hệ sinh thái mã nguồn mở (Kafka Connect, Kafka Streams) mà Event Hubs không hỗ trợ đầy đủ.
- HDInsight cung cấp một cluster Kafka thật sự, được Azure quản lý phần cứng và cài đặt, giúp giảm bớt gánh nặng DevOps so với tự cài đặt trên máy ảo (VM).

---

## 🧠 Phase 1: Hiểu sâu về Kiến trúc Kafka trên Azure HDInsight

Trước khi tạo tài nguyên, bạn CẦN hiểu rõ những gì mình sắp tạo ra. Một Kafka Cluster trên HDInsight không phải là một "hộp đen" (black box) như Event Hubs. Nó là một cụm máy chủ vật lý/ảo hóa gồm các thành phần sau:

### 1. Zookeeper Nodes (Bộ não điều phối)
- **Hoạt động**: Kafka không thể tự hoạt động một mình, nó cần Zookeeper. Zookeeper đóng vai trò như "người quản lý trạng thái". Nó theo dõi xem Broker nào đang sống, Broker nào đã chết, và Topic nào đang nằm ở đâu.
- **Tại sao cần**: Trong hệ thống phân tán, cần có một nơi đáng tin cậy để lưu trữ metadata. Zookeeper làm nhiệm vụ bầu ra "Leader" cho các partition để tránh xung đột dữ liệu. (Lưu ý: Các phiên bản Kafka mới nhất đang dần loại bỏ Zookeeper bằng KRaft, nhưng trên HDInsight mặc định vẫn dùng Zookeeper).

### 2. Kafka Broker Nodes (Các cỗ máy làm việc chính)
- **Hoạt động**: Broker chính là các máy chủ nhận, lưu trữ (trên ổ cứng) và phân phối dữ liệu (messages) cho consumer.
- **Tại sao cần**: Mỗi broker xử lý một phần dữ liệu. Khi bạn có 3 Brokers, tải trọng được chia đều. Nếu 1 Broker hỏng, dữ liệu vẫn an toàn trên 2 Broker còn lại (nhờ cơ chế Replication).

### 3. Azure Virtual Network (VNet)
- **Hoạt động**: Một mạng riêng ảo cô lập trên cloud.
- **Tại sao cần**: HDInsight Kafka không có IP Public (không đưa trực tiếp ra Internet) để đảm bảo bảo mật. Các ứng dụng muốn đẩy hoặc đọc dữ liệu từ Kafka **phải** nằm trong cùng VNet này hoặc được kết nối VPN/Peering vào VNet này.

### 4. Azure Storage (Managed Disks & Blob/ADLS Gen2)
- **Hoạt động**: 
  - **Managed Disks**: Ổ cứng gắn trực tiếp vào các Kafka Broker để lưu trữ message với độ trễ cực thấp (High IOPS).
  - **ADLS Gen2**: HDInsight dùng Data Lake/Blob để lưu trữ logs hệ thống và cấu hình cluster (không dùng để lưu Kafka messages).

---

## 🛠️ Phase 2: Khởi tạo Hạ tầng (Infrastructure Setup)

### Bước 1: Tạo Resource Group
Gom tất cả tài nguyên vào một chỗ để dễ xóa khi lab kết thúc, tránh phát sinh chi phí.
1. Vào **Azure Portal** > **Resource groups** > **Create**.
2. **Subscription**: Chọn sub của bạn.
3. **Resource group**: `rg-kafka-lab-dev`
4. **Region**: `Southeast Asia` (hoặc vùng gần bạn).
5. Nhấn **Review + Create** > **Create**.

### Bước 2: Tạo Azure Virtual Network (VNet)
Bắt buộc phải có VNet để chứa cụm Kafka.
1. Tìm **Virtual Networks** > **Create**.
2. **Resource group**: `rg-kafka-lab-dev`
3. **Name**: `vnet-kafka-dev`
4. **Region**: `Southeast Asia`
5. Chuyển sang tab **IP Addresses**:
   - Mặc định sẽ có IPv4 space là `10.0.0.0/16`.
   - Bấm vào subnet `default`, đổi tên thành `snet-hdinsight`. Nhấn **Save**.
6. Nhấn **Review + create** > **Create**.

### Bước 3: Tạo Storage Account cho Cluster Log
HDInsight cần một nơi để lưu trữ log vận hành.
1. Tìm **Storage accounts** > **Create**.
2. **Resource group**: `rg-kafka-lab-dev`
3. **Storage account name**: `stkafkalablog001` (viết liền, chữ thường).
4. **Region**: `Southeast Asia`
5. **Redundancy**: `LRS`
6. Nhấn **Review + create** > **Create**.
*(Đợi tài nguyên tạo xong)*

### Bước 4: Tạo Cụm Azure HDInsight Kafka
Đây là bước cốt lõi. Chúng ta sẽ "thuê" các máy ảo của Azure và Azure sẽ tự động cài Kafka, Zookeeper lên đó.

1. Tìm **HDInsight clusters** > **Create**.
2. **Tab Basics**:
   - **Subscription**: Chọn sub của bạn.
   - **Resource group**: `rg-kafka-lab-dev`
   - **Cluster name**: `kafka-cluster-lab-001` (phải là duy nhất).
   - **Region**: `Southeast Asia`
   - **Cluster type**: Chọn **Kafka** (Rất quan trọng, HDInsight hỗ trợ nhiều loại như Spark, Hadoop, HBase. Ta chọn Kafka).
   - **Version**: Để mặc định (VD: Kafka 2.4).
   - **Cluster login username**: `admin`
   - **Cluster login password**: Nhập mật khẩu mạnh (VD: `KafkaLab@2026!`). Dùng để đăng nhập web UI (Ambari).
   - **Secure Shell (SSH) username**: `sshuser`
   - **SSH password**: `KafkaLab@2026!` (Hoặc dùng SSH Public Key). Dùng để SSH vào trong máy chủ Linux.
   - Nhấn **Next: Storage**.

3. **Tab Storage**:
   - **Primary storage type**: Chọn `Azure Storage`.
   - **Selection method**: `Select from list`.
   - **Primary storage account**: Chọn `stkafkalablog001` vừa tạo ở Bước 3.
   - **Container**: Để tự động sinh tên.
   - Nhấn **Next: Security + networking**.

4. **Tab Security + networking**:
   - **Virtual network**: Chọn `vnet-kafka-dev` đã tạo ở Bước 2.
   - **Subnet**: Chọn `snet-hdinsight`.
   - Nhấn **Next: Configuration + pricing**.

5. **Tab Configuration + pricing** (TỐI ƯU CHI PHÍ LAB):
   - Mặc định Azure cấu hình các node rất mạnh (và đắt tiền). Vì đây là Lab, ta cần giảm cấu hình xuống mức tối thiểu.
   - **Zookeeper nodes**: Sẽ cố định là 3 nodes (thường là máy nhỏ, A4 v2).
   - **Head nodes**: Sẽ cố định là 2 nodes (quản lý cluster).
   - **Worker nodes (Kafka Brokers)**: Mặc định là 4, hãy **chỉnh xuống 3 nodes** (Kafka yêu cầu tối thiểu 3 broker để chạy replication ổn định).
   - **Node size cho Worker**: Bấm vào để đổi sang kích thước nhỏ nhất có thể (VD: `Standard_E2_v3` hoặc `Standard_D2_v3`). 
   - **Disks per worker node**: `1` (Mỗi broker có 1 ổ đĩa Managed Disk 1TB để lưu dữ liệu).
   
6. Nhấn **Review + create** > **Create**.
> ⚠️ **Chú ý cực kỳ quan trọng**: Việc tạo cluster HDInsight Kafka sẽ mất khoảng **15 - 25 phút** vì Azure phải cấp phát máy ảo vật lý, cài đặt hệ điều hành Linux, cài Zookeeper, cài Kafka và cấu hình mạng lưới (networking). Trong lúc chờ, hãy đọc tiếp Phase 3.

---

## 🔍 Phase 3: Khám phá Kafka Cluster & Zookeeper (Under the Hood)

Khi cluster đã tạo xong, chúng ta không có một giao diện kéo thả mượt mà để quản lý Topic như Event Hubs. Bản chất của HDInsight Kafka là **máy chủ Linux**. Chúng ta sẽ SSH trực tiếp vào máy chủ để điều khiển.

### Bước 1: SSH vào Head Node của Cluster
Để chạy các lệnh Kafka, ta phải đứng trên một máy tính nằm cùng mạng (VNet). May mắn là HDInsight cho phép ta SSH trực tiếp vào Head Node thông qua cổng bảo mật.

1. Vào cluster `kafka-cluster-lab-001` trên Azure Portal.
2. Tìm mục **SSH + Cluster login** (menu bên trái).
3. Bạn sẽ thấy lệnh SSH mẫu, ví dụ: 
   ```bash
   ssh sshuser@kafka-cluster-lab-001-ssh.azurehdinsight.net
   ```
4. Mở Terminal/Command Prompt trên máy tính của bạn và dán lệnh trên.
5. Nhập password `KafkaLab@2026!` đã tạo lúc nãy.
6. Bạn hiện đang đứng trong hệ điều hành Linux (Ubuntu) của Head Node!

### Bước 2: Lấy thông tin Zookeeper và Broker IP
Các công cụ dòng lệnh của Kafka yêu cầu bạn phải truyền địa chỉ của Zookeeper hoặc Broker. Môi trường HDInsight có sẵn công cụ để lấy cấu hình này.

Trong SSH terminal, chạy script sau để đặt biến môi trường:
*(HDInsight lưu cấu hình trong Ambari, script này dùng lệnh jq để lấy địa chỉ IP)*

```bash
# Cài đặt jq (công cụ xử lý JSON trên terminal)
sudo apt -y install jq

# Lấy Zookeeper Hosts
export KAFKAZKHOSTS=$(curl -sS -u admin:KafkaLab@2026! -G https://kafka-cluster-lab-001.azurehdinsight.net/api/v1/clusters/kafka-cluster-lab-001/services/ZOOKEEPER/components/ZOOKEEPER_SERVER | jq -r '["\(.host_components[].HostRoles.host_name):2181"] | join(",")' | cut -d',' -f1,2)

echo "Zookeeper IPs: $KAFKAZKHOSTS"

# Lấy Kafka Broker Hosts
export KAFKABROKERS=$(curl -sS -u admin:KafkaLab@2026! -G https://kafka-cluster-lab-001.azurehdinsight.net/api/v1/clusters/kafka-cluster-lab-001/services/KAFKA/components/KAFKA_BROKER | jq -r '["\(.host_components[].HostRoles.host_name):9092"] | join(",")' | cut -d',' -f1,2)

echo "Broker IPs: $KAFKABROKERS"
```
*(Lưu ý thay `KafkaLab@2026!` và `kafka-cluster-lab-001` bằng thông tin thật của bạn nếu bạn đặt tên khác).*

Kết quả trả về sẽ là các chuỗi dạng `zk0-kafka...:2181,zk1-kafka...:2181` và `wn0-kafka...:9092,wn1-kafka...:9092`.

---

## ⚙️ Phase 4: Quản lý Topic và Partitions (Thực hành Cốt lõi)

### 1. Tạo Topic đầu tiên: `clickstream_events`

> **🧠 Kiến thức**: 
> - **Partitions (--partitions 3)**: Topic được cắt làm 3 mảnh. Nếu ta có 3 Broker, mỗi Broker sẽ chứa 1 mảnh. Điều này cho phép đọc/ghi song song.
> - **Replication Factor (--replication-factor 2)**: Mỗi mảnh (partition) sẽ có 2 bản sao nằm ở 2 Broker khác nhau. Nếu Broker A cháy ổ cứng, dữ liệu vẫn còn trên Broker B. (Vì ta có 3 broker, ta có thể set replication cao nhất là 3).

Chạy lệnh sau trên terminal SSH:
```bash
/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --create \
  --replication-factor 2 \
  --partitions 3 \
  --topic clickstream_events \
  --zookeeper $KAFKAZKHOSTS
```

### 2. Xem chi tiết kiến trúc của Topic
Chạy lệnh describe để xem "nội soi" cách Kafka phân bổ dữ liệu:

```bash
/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --describe \
  --topic clickstream_events \
  --zookeeper $KAFKAZKHOSTS
```

**Cách đọc kết quả (Quan trọng):**
Bạn sẽ thấy một bảng tương tự như thế này:
```
Topic: clickstream_events   PartitionCount: 3   ReplicationFactor: 2   Configs:
    Topic: clickstream_events   Partition: 0    Leader: 2   Replicas: 2,1   Isr: 2,1
    Topic: clickstream_events   Partition: 1    Leader: 0   Replicas: 0,2   Isr: 0,2
    Topic: clickstream_events   Partition: 2    Leader: 1   Replicas: 1,0   Isr: 1,0
```
- **Partition: 0, 1, 2**: 3 phân vùng ta vừa tạo.
- **Leader: 2**: Mọi yêu cầu đọc/ghi dữ liệu vào Partition 0 bắt buộc phải giao tiếp với Broker mang ID số 2.
- **Replicas: 2, 1**: Dữ liệu của Partition 0 được lưu trên ổ cứng của Broker 2 và Broker 1.
- **Isr (In-Sync Replicas): 2, 1**: Hiện tại cả Broker 2 và 1 đều đang hoạt động tốt và chứa dữ liệu mới nhất (không ai bị chậm/lag).

### 3. Gửi dữ liệu giả lập thủ công (Producer)
Dùng công cụ console có sẵn để đóng vai trò như một ứng dụng đẩy dữ liệu vào.
```bash
/usr/hdp/current/kafka-broker/bin/kafka-console-producer.sh \
  --broker-list $KAFKABROKERS \
  --topic clickstream_events
```
Lúc này terminal sẽ đợi bạn gõ. Hãy gõ vài dòng:
```json
{"user_id": "U001", "action": "view", "item_id": "I999"}
{"user_id": "U002", "action": "add_to_cart", "item_id": "I888"}
```
*(Nhấn Ctrl+C để thoát)*

### 4. Đọc dữ liệu (Consumer)
Dùng công cụ console đóng vai trò Consumer đọc từ đầu (from-beginning).
```bash
/usr/hdp/current/kafka-broker/bin/kafka-console-consumer.sh \
  --bootstrap-server $KAFKABROKERS \
  --topic clickstream_events \
  --from-beginning
```
Bạn sẽ thấy 2 dòng JSON bạn vừa gõ hiện ra. Nhấn Ctrl+C để thoát.

---

## 🐍 Phase 5: Xây dựng Python Producer 

Trong thực tế, ta dùng code (Python/Java) để giao tiếp với Kafka.
Do Kafka nằm trong VNet riêng, bạn **không thể** chạy code Python từ laptop của mình để kết nối vào Kafka (trừ khi dùng VPN). 
Cách tốt nhất để thực hành là **cài Python ngay trên chính Head Node** mà bạn đang SSH, hoặc tạo một máy ảo (VM) khác nằm cùng VNet. Ở lab này, ta code ngay trên Head Node.

### Bước 1: Cài đặt thư viện
```bash
sudo apt -y install python3-pip
pip3 install confluent-kafka faker
```

### Bước 2: Viết script Producer gửi hàng loạt dữ liệu
Tạo file `producer.py` trên Head Node:
```bash
nano producer.py
```
Dán đoạn code sau vào (Lưu ý: Thay chuỗi `BOOTSTRAP_SERVERS` bằng kết quả của `$KAFKABROKERS` bạn đã lấy ở trên, dạng `wn0-kafka...:9092,wn1-kafka...:9092`):

```python
import json
import time
import random
from datetime import datetime
from confluent_kafka import Producer
from faker import Faker

fake = Faker()

# CẤU HÌNH QUAN TRỌNG: Lấy từ kết quả $KAFKABROKERS
BOOTSTRAP_SERVERS = "wn0-kafka-xxxxxx.xxxxx.bx.internal.cloudapp.net:9092,wn1-kafka-xxxxxx.xxxxx.bx.internal.cloudapp.net:9092"
TOPIC_NAME = "clickstream_events"

# Cấu hình Kafka Producer
conf = {
    'bootstrap.servers': BOOTSTRAP_SERVERS,
    'client.id': 'python-producer',
    # Lacks authentication because HDInsight Kafka inside VNet relies on network isolation by default
}
producer = Producer(conf)

def delivery_callback(err, msg):
    """Callback được gọi khi message gửi thành công hoặc thất bại"""
    if err:
        print(f"❌ Lỗi gửi message: {err}")
    else:
        print(f"✅ Gửi thành công tới Topic: {msg.topic()} | Partition: {msg.partition()} | Offset: {msg.offset()}")

def generate_event():
    return {
        "event_id": fake.uuid4(),
        "user_id": random.randint(1000, 9999),
        "url": fake.uri_path(),
        "action": random.choice(["view", "click", "add_to_cart", "checkout"]),
        "timestamp": datetime.utcnow().isoformat()
    }

if __name__ == '__main__':
    print(f"🚀 Bắt đầu gửi dữ liệu tới Kafka: {BOOTSTRAP_SERVERS}")
    try:
        for i in range(100):
            event = generate_event()
            # Serialize JSON thành chuỗi byte
            value_json = json.dumps(event).encode('utf-8')
            
            # Gửi vào Kafka. Dùng user_id làm Partition Key (để user giống nhau vào chung partition)
            producer.produce(
                topic=TOPIC_NAME,
                key=str(event["user_id"]).encode('utf-8'),
                value=value_json,
                callback=delivery_callback
            )
            
            # Flush liên tục cho Lab. Thực tế sẽ gom batch để tối ưu (linger.ms)
            producer.poll(0)
            time.sleep(0.5) # Gửi 2 event mỗi giây
            
        producer.flush()
        print("🏁 Hoàn tất!")
    except KeyboardInterrupt:
        print("Đã dừng.")
```
*(Nhấn Ctrl+O, Enter để lưu. Ctrl+X để thoát).*

### Bước 3: Chạy script
```bash
python3 producer.py
```
Bạn sẽ thấy log in ra liên tục các event được gửi vào các Partition 0, 1 hoặc 2. Nhờ có `key=user_id`, Kafka sẽ hash (băm) cái ID này để quyết định bỏ vào Partition nào, đảm bảo dữ liệu của 1 User luôn được xếp theo đúng thứ tự thời gian trên cùng 1 Partition.

---

## 🧹 Phase 6: Dọn dẹp tài nguyên (RẤT QUAN TRỌNG)

HDInsight cluster có chi phí **rất cao** so với các dịch vụ khác (vì nó duy trì hàng loạt máy ảo chạy 24/7). Khi học xong, bạn phải xóa nó đi NGAY LẬP TỨC.

1. Vào Azure Portal > **Resource groups**.
2. Bấm vào `rg-kafka-lab-dev`.
3. Chọn **Delete resource group** trên thanh menu.
4. Gõ chữ `rg-kafka-lab-dev` vào ô xác nhận và bấm **Delete**.
5. Thao tác này sẽ xóa sạch VNet, Storage và HDInsight Cluster, không còn sót lại bất kỳ chi phí ngầm nào.

---

## 💡 Tổng kết sự khác biệt then chốt (Event Hubs vs HDInsight Kafka)

Sau bài Lab này, bạn đã thấy "bên dưới" của Kafka là các **Broker, Zookeeper, ổ đĩa**. 
Khi bạn dùng **Azure Event Hubs**, Microsoft đã ẩn đi (abstract) hoàn toàn Zookeeper, Broker. Bạn không biết nó có bao nhiêu Broker, bạn không cần quan tâm ổ cứng, bạn chỉ quan tâm Throughput (MB/s). 

- **Chọn Event Hubs khi**: Bạn muốn tập trung viết code, xử lý data, không muốn nuôi đội ngũ quản trị server (Zero Ops). Hợp lý cho 80% công ty.
- **Chọn HDInsight Kafka khi**: Bạn cần cấu hình sâu vào system, cần log compaction, cần quota management, tích hợp với các tool mã nguồn mở cứng nhắc đòi hỏi native Kafka, hoặc hệ thống cũ (legacy) mang từ On-premise lên Cloud không muốn sửa đổi nhiều.
