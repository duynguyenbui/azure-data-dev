# Hướng dẫn Lab 09: Enterprise Network Security for Azure Data Platforms: VNet, Private Endpoints & Network Isolation

Nếu bạn muốn hiểu cách các doanh nghiệp lớn — đặc biệt trong ngành y tế và tài chính — bảo vệ dữ liệu nhạy cảm trên Azure, đây là tài liệu Lab thực hành toàn diện nhất. Chúng ta sẽ xây dựng một kiến trúc mạng **Zero-Trust, production-grade** sử dụng **VNet, Private Endpoints, NSG, Azure Firewall và Azure Bastion** để hoàn toàn cô lập nền tảng dữ liệu khỏi Internet công cộng.

---

## Kịch bản Nghiệp vụ (The Business Scenario)

Công ty **MedData Vietnam** là một tập đoàn y tế đang số hóa hàng triệu hồ sơ bệnh nhân (Electronic Health Records — EHR). Họ vừa được kiểm toán và nhận cảnh báo nghiêm trọng: toàn bộ hạ tầng dữ liệu Azure (ADLS Gen2, Azure SQL, Azure Databricks, ADF) đang **tiếp xúc trực tiếp với Internet công cộng** thông qua Public Endpoints.

**Vi phạm Compliance đang tồn tại:**
- **HIPAA §164.312(e)** — Transmission Security: Dữ liệu bệnh nhân (ePHI) đang đi qua Internet không kiểm soát.
- **HIPAA §164.312(a)** — Access Control: Bất kỳ ai có IP address đều có thể thử brute-force SQL Server qua port 1433.
- **Nghị định 13/2023/NĐ-CP (Việt Nam):** Dữ liệu sức khỏe được phân loại "nhạy cảm" — vi phạm có thể bị phạt tới 5% doanh thu toàn cầu.

**Nhiệm vụ của bạn:** Thiết kế và triển khai kiến trúc mạng hoàn toàn khép kín (Network Isolation) để đảm bảo:
1. **Zero Public Endpoint:** Không có Public Endpoint nào tồn tại trên ADLS, SQL, Key Vault.
2. **Private Communication Only:** Mọi giao tiếp giữa các dịch vụ Azure phải đi qua Private IP trong backbone Azure.
3. **Compute Isolation:** Azure Databricks và ADF phải được triển khai trong VNet nội bộ.
4. **Controlled Management:** Quản trị viên chỉ kết nối máy chủ qua Azure Bastion.

---

## Kiến trúc Giải pháp (Solution Architecture)

```
┌─────────────────────────────────────────────────────────────────────┐
│                        MedData Vietnam - Azure Tenant               │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │               Hub VNet (10.0.0.0/16)                        │   │
│  │  ┌─────────────────┐  ┌──────────────────┐                  │   │
│  │  │ AzureFirewall   │  │  BastionSubnet   │                  │   │
│  │  │ Subnet          │  │  (10.0.2.0/27)   │                  │   │
│  │  │ (10.0.1.0/26)   │  │  Azure Bastion   │                  │   │
│  │  │ Azure Firewall  │  └──────────────────┘                  │   │
│  │  └─────────────────┘                                        │   │
│  └──────────────────────────────────────────────────────────────┘   │
│              │                                                      │
│         VNet Peering (Non-transitive)                               │
│              │                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │               Spoke VNet (10.1.0.0/16)                      │   │
│  │  ┌─────────────────┐  ┌────────────────────────────────┐    │   │
│  │  │  DataSubnet     │  │  PrivateEndpointSubnet         │    │   │
│  │  │  (10.1.1.0/24)  │  │  (10.1.2.0/24)                │    │   │
│  │  │  ADB Workers    │  │  PE: ADLS, SQL, KV, ADF       │    │   │
│  │  └─────────────────┘  └────────────────────────────────┘    │   │
│  │  ┌──────────────────────────────────────────────────────┐   │   │
│  │  │  ManagementSubnet (10.1.3.0/24)                     │   │   │
│  │  │  Jump Servers, Admin Tools                          │   │   │
│  │  └──────────────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Thiết kế Mạng (Network Design & CIDR Planning)

> **Mục đích:** Trước khi tạo bất kỳ tài nguyên nào, chúng ta phải có một bản vẽ kiến trúc mạng rõ ràng. Một sai lầm trong phân chia CIDR có thể dẫn đến xung đột địa chỉ IP về sau, buộc phải làm lại từ đầu.

> **Compliance Relevance:** HIPAA yêu cầu Network Segmentation (phân đoạn mạng). Mỗi tier dữ liệu phải có subnet riêng biệt với chính sách bảo mật độc lập.

> **🧠 Kiến thức nền tảng — Tại sao cần Hub-and-Spoke? Không thể dùng 1 VNet duy nhất sao?**
>
> Đây là câu hỏi đầu tiên mà mọi kiến trúc sư Azure phải trả lời. Câu trả lời ngắn gọn: **có thể dùng một VNet**, nhưng đó là anti-pattern trong enterprise. Hãy nghĩ về nó như sau:
>
> Nếu bạn đặt Data Platform, Application tier và Dev/Test vào cùng một VNet, toàn bộ hệ thống chia sẻ một "hàng rào bảo mật" duy nhất. Khi một developer vô tình để lộ credentials trong môi trường Dev, kẻ tấn công có thể **lateral move** (di chuyển ngang) sang Production Database trong cùng VNet mà không gặp thêm bất kỳ rào cản nào.
>
> **Hub-and-Spoke** giải quyết vấn đề này bằng cách tạo các "security zones" độc lập:
> - **Hub VNet** là trung tâm điều phối — chứa các dịch vụ bảo mật dùng chung như Azure Firewall (kiểm tra và lọc mọi traffic), Azure Bastion (quản trị an toàn), VPN/ExpressRoute Gateway (kết nối on-premises).
> - **Spoke VNets** là các mạng riêng cho từng workload. Data Platform trong Spoke-Data không thể "nhìn thấy" Dev/Test trong Spoke-DevTest trừ khi được phép rõ ràng và đi qua Firewall.
>
> **So sánh với Mesh Topology:** Trong Mesh, mọi VNet có thể peer trực tiếp với nhau — không có điểm kiểm soát trung tâm. Với 10 VNets, bạn cần 45 peering connections và 45 bộ rules độc lập. Không thể maintain trong enterprise. Hub-and-Spoke chỉ cần N peerings (Hub-to-Spoke) và quản lý policy tập trung tại Hub.

### Bước 1.1: CIDR Planning — Bảng phân chia địa chỉ IP

| VNet / Subnet | CIDR Block | IP khả dụng | Mục đích |
|---|---|---|---|
| **Hub VNet** | `10.0.0.0/16` | 65,534 | Mạng trung tâm điều phối |
| ↳ AzureFirewallSubnet | `10.0.1.0/26` | 59 | Bắt buộc đúng tên cho Azure Firewall |
| ↳ AzureBastionSubnet | `10.0.2.0/27` | 27 | Bắt buộc đúng tên cho Bastion |
| **Spoke VNet (Data)** | `10.1.0.0/16` | 65,534 | Mạng workload Data Platform |
| ↳ DataSubnet | `10.1.1.0/24` | 251 | Azure Databricks Workers, ADF SHIR |
| ↳ PrivateEndpointSubnet | `10.1.2.0/24` | 251 | Private Endpoints (ADLS, SQL, KV) |
| ↳ ManagementSubnet | `10.1.3.0/24` | 251 | Jump servers, quản trị |

> **🧠 Kiến thức nền tảng — CIDR Notation và Subnet Sizing hoạt động như thế nào?**
>
> CIDR (Classless Inter-Domain Routing) là cách biểu diễn dải địa chỉ IP. Số sau dấu `/` (gọi là "prefix length") cho biết bao nhiêu bit đầu tiên là cố định (network portion), phần còn lại là host portion.
>
> - `/16` = 16 bits cố định → 16 bits còn lại cho hosts → 2^16 = 65,536 địa chỉ.
> - `/24` = 24 bits cố định → 8 bits cho hosts → 2^8 = 256 địa chỉ.
> - `/26` = 26 bits cố định → 6 bits cho hosts → 2^6 = 64 địa chỉ.
>
> **Tại sao Azure luôn "mất" 5 địa chỉ?** Azure dành riêng 5 địa chỉ đầu tiên và cuối của mỗi subnet:
> - `.0` = Network address (định danh subnet).
> - `.1` = Default gateway (Azure router).
> - `.2`, `.3` = Azure DNS servers.
> - `.255` = Broadcast address (cuối subnet).
> Vì vậy `/24` (256 IPs) chỉ còn 251 IPs dùng được thực sự.
>
> **Quy tắc vàng khi thiết kế:** Luôn chọn CIDR lớn hơn nhu cầu hiện tại ít nhất 2x. Azure không cho phép thay đổi CIDR của subnet đang có resources — bạn phải xóa resources, resize, rồi recreate. Rất tốn thời gian trong production.

### Bước 1.2: Subnet Segmentation Strategy

**DataSubnet (`10.1.1.0/24`) — Application Tier:**
Chứa Databricks cluster nodes, ADF SHIR. NSG chỉ cho phép traffic đến PrivateEndpointSubnet (port 443, 1433). Không nhận bất kỳ inbound traffic nào từ Internet.

**PrivateEndpointSubnet (`10.1.2.0/24`) — Data Tier:**
Chứa Network Interfaces (NIC) của các Private Endpoints. Đây là subnet nhạy cảm nhất — chỉ nhận từ DataSubnet và ManagementSubnet. Phải disable `PrivateEndpointNetworkPolicies` (sẽ giải thích ở Phase 4).

**ManagementSubnet (`10.1.3.0/24`) — Management Tier:**
Jump servers, monitoring agents. Truy cập chỉ qua Azure Bastion từ Hub. Mọi outbound đi qua Azure Firewall với full logging.

---

## Phase 2: Tạo VNet và VNet Peering

> **Mục đích:** Hiện thực hóa bản thiết kế mạng bằng cách tạo Hub VNet, Spoke VNet và kết nối chúng qua VNet Peering.

> **Compliance Relevance:** Tách biệt mạng vật lý (separate VNet) đảm bảo rằng kể cả khi một bộ phận bị xâm phạm, kẻ tấn công cũng không thể tự do truy cập toàn hệ thống.

### Bước 2.1: Tạo Resource Group

1. Đăng nhập [portal.azure.com](https://portal.azure.com).
2. Tìm **Resource groups** > **+ Create**.
3. **Resource group:** `rg-meddata-network-prod` | **Region:** `Southeast Asia`.
4. Nhấn **Review + create** -> **Create**.

### Bước 2.2: Tạo Hub VNet

1. Tìm **Virtual networks** > **+ Create**.
2. **Name:** `vnet-meddata-hub-prod` | **Region:** `Southeast Asia`.
3. **IP Addresses Tab:**
   - **IPv4 address space:** `10.0.0.0/16`
   - **Subnet 1 — AzureFirewallSubnet:** Starting `10.0.1.0`, Size `/26` *(tên BẮT BUỘC chính xác)*.
   - **Subnet 2 — AzureBastionSubnet:** Starting `10.0.2.0`, Size `/27` *(tên BẮT BUỘC chính xác)*.
4. Nhấn **Review + create** -> **Create**.

### Bước 2.3: Tạo Spoke VNet (Data Platform)

1. Tìm **Virtual networks** > **+ Create**.
2. **Name:** `vnet-meddata-spoke-data` | **Region:** `Southeast Asia`.
3. **IP Addresses Tab:** **IPv4 address space:** `10.1.0.0/16`.
   - **snet-data-workers:** `10.1.1.0/24`
   - **snet-private-endpoints:** `10.1.2.0/24`
   - **snet-management:** `10.1.3.0/24`
4. Nhấn **Review + create** -> **Create**.

### Bước 2.4: Thiết lập VNet Peering (Hai chiều)

> **🧠 Kiến thức nền tảng — VNet Peering hoạt động như thế nào? Tại sao "non-transitive"?**
>
> **VNet Peering** cho phép hai VNet kết nối trực tiếp qua backbone mạng nội bộ của Microsoft (không qua Internet, không mã hóa cần thiết vì đây là private network của Microsoft). Tốc độ cao, độ trễ thấp tương đương kết nối trong cùng một data center.
>
> **Non-transitive là gì?** Đây là một trong những hiểu lầm phổ biến nhất. Giả sử:
> - Hub peer với Spoke-Data
> - Hub peer với Spoke-App
> Thì Spoke-Data và Spoke-App **KHÔNG thể kết nối trực tiếp** dù cùng qua Hub. Traffic phải đi: Spoke-Data → Hub → Azure Firewall → Hub → Spoke-App. Firewall đóng vai trò router trung gian và kiểm tra từng packet.
>
> **Tại sao Microsoft thiết kế như vậy?** Để bắt buộc mọi cross-spoke traffic phải đi qua điểm kiểm soát trung tâm (Hub Firewall). Nếu peering là transitive, bạn không thể ngăn Spoke-Dev tự do chat với Spoke-Prod — điều này vi phạm nguyên tắc Least Privilege (tối thiểu quyền cần thiết).
>
> **Routing trong VNet Peering hoạt động thế nào?** Khi bạn tạo peering, Azure tự động cập nhật bảng routing (route table) của cả hai VNets để "biết đường" đến CIDR của nhau. Không cần cấu hình BGP thủ công cho basic peering. Tuy nhiên, khi dùng VPN Gateway hoặc ExpressRoute, BGP (Border Gateway Protocol) được sử dụng để propagate routes động — đây là lý do tại sao option "Allow gateway transit" trong peering settings quan trọng trong môi trường hybrid.

**Tạo Peering từ Hub sang Spoke:**

1. Mở `vnet-meddata-hub-prod` > **Peerings** > **+ Add**.
2. **Peering link name (Hub side):** `peer-hub-to-spoke-data`
3. **Remote virtual network name (Spoke side):** `peer-spoke-data-to-hub`
4. **Virtual network:** Chọn `vnet-meddata-spoke-data`
5. **Traffic to remote virtual network:** `Allow` | **Traffic forwarded from remote virtual network:** `Allow`
6. Nhấn **Add**. Azure tự động tạo peering ở cả hai đầu.

Kiểm tra: Mở cả hai VNets > **Peerings** > Status phải là **Connected**.

> **Troubleshooting — Peering Status "Disconnected":**
> Đợi 2-3 phút và refresh. Nếu vẫn Disconnected, xóa cả hai peerings và tạo lại — Azure đôi khi gặp race condition. Nguyên nhân khác: một trong hai VNet đang có subnet đang deploy resources.

---

## Phase 3: Network Security Groups (NSG) và Application Security Groups (ASG)

> **Mục đích:** NSG là "bức tường lửa phần mềm" gắn trực tiếp vào từng subnet. Chúng ta cấu hình NSG chi tiết để chỉ những luồng traffic được phép rõ ràng mới được thông qua.

> **Compliance Relevance:** HIPAA §164.312(a) "Access Control" — mọi truy cập vào dữ liệu bệnh nhân phải được kiểm soát. NSG với NSG Flow Logs đáp ứng yêu cầu này.

> **🧠 Kiến thức nền tảng — NSG vs Azure Firewall vs WAF: Khác nhau ở đâu? Dùng cái nào?**
>
> Đây là câu hỏi phỏng vấn điển hình cho vị trí Azure Security Engineer. Ba công cụ này thường bị nhầm lẫn vì đều "chặn traffic", nhưng hoạt động ở các tầng khác nhau:
>
> **NSG (Network Security Group):**
> - Hoạt động ở **Layer 4** (Transport Layer — TCP/UDP/ICMP).
> - Lọc traffic dựa trên: IP address, port number, protocol.
> - **Stateful:** Nếu allow outbound TCP port 443, Azure tự động allow inbound response — không cần tạo rule ngược.
> - Gắn vào **subnet** hoặc **NIC** (network interface của từng VM).
> - **Miễn phí** — không tính phí theo volume traffic.
> - **Giới hạn:** Không thể filter dựa trên domain name (FQDN), không inspect packet content, không có centralized logging sẵn.
>
> **Azure Firewall:**
> - Hoạt động ở **Layer 7** (Application Layer).
> - Có thể filter theo **FQDN** (ví dụ: allow `pypi.org`, deny `*.ru`).
> - **Threat Intelligence** — tự động block IPs/domains được biết là độc hại.
> - **Centralized:** Một Firewall phục vụ toàn bộ Hub, inspect mọi traffic cross-spoke.
> - **Tốn phí** (~$1.25/giờ) nhưng cần thiết cho enterprise compliance.
>
> **WAF (Web Application Firewall):**
> - Hoạt động ở **Layer 7**, chuyên cho **HTTP/HTTPS traffic**.
> - Bảo vệ web applications khỏi OWASP Top 10 (SQL Injection, XSS, etc.).
> - Gắn vào **Application Gateway** hoặc **Azure Front Door**.
> - Không liên quan đến network-level traffic giữa Azure services.
>
> **Kết luận cho MedData:** NSG cho micro-segmentation trong từng subnet. Azure Firewall cho centralized outbound control và logging. WAF nếu expose APIs ra ngoài (không cần trong bài lab này vì ta không expose gì ra Internet).

### Bước 3.1: Tạo Application Security Groups (ASG)

> **Định nghĩa:** **ASG** cho phép nhóm các VM theo chức năng logic thay vì IP address. Khi NSG rule dùng ASG, bạn chỉ cần gán VM mới vào đúng ASG — không cần sửa NSG rule. Giống như "tag" cho network resources.

Tạo 3 ASG trong `rg-meddata-network-prod`, Region `Southeast Asia`:
- `asg-databricks-workers` — nhóm Databricks nodes
- `asg-private-endpoints` — nhóm Private Endpoint NICs
- `asg-management-servers` — nhóm Jump servers

### Bước 3.2: Tạo NSG cho PrivateEndpointSubnet (Data Tier)

1. Tìm **Network security groups** > **+ Create**.
2. **Name:** `nsg-private-endpoints` | **Region:** `Southeast Asia`.
3. **Inbound security rules** > **+ Add**:

| Priority | Name | Source | Destination | Port | Action | Mục đích |
|---|---|---|---|---|---|---|
| 100 | Allow-DataSubnet | `10.1.1.0/24` | `10.1.2.0/24` | 443, 1433 | Allow | Databricks & ADF kết nối đến ADLS, SQL |
| 200 | Allow-Management | `10.1.3.0/24` | `10.1.2.0/24` | 443, 1433 | Allow | Admin quản trị |
| 4096 | Deny-All-Inbound | Any | Any | Any | Deny | Chặn mọi thứ còn lại |

4. **Outbound rules:** Allow response traffic về DataSubnet, Deny All còn lại.
5. Gắn NSG vào subnet: **Subnets** > **+ Associate** > `snet-private-endpoints`.

### Bước 3.3: Tạo NSG cho DataSubnet (Application Tier)

Tạo `nsg-data-workers` với:

**Inbound:**
- P100: Allow Hub traffic (10.0.0.0/16) — Bastion, Firewall quản lý.
- P200: Allow internal DataSubnet (10.1.1.0/24) — Databricks cluster-to-cluster.
- P4096: Deny All.

**Outbound:**
- P100: Allow đến PrivateEndpointSubnet (10.1.2.0/24) port 443, 1433.
- P200: Allow đến service tag `AzureMonitor` port 443.
- P300: Allow đến Firewall (10.0.1.0/26) — outbound Internet qua Firewall.
- P4096: Deny All — chặn direct Internet access.

Gắn `nsg-data-workers` vào `snet-data-workers`.

### Bước 3.4: Kích hoạt NSG Flow Logs

> **🧠 Kiến thức nền tảng — NSG Flow Logs là gì? Tại sao không thể thiếu trong môi trường regulated?**
>
> NSG Flow Logs ghi lại thông tin về **mọi** luồng TCP/UDP đi qua NSG: source IP, destination IP, source port, destination port, protocol, action (Allow/Deny), bytes transferred. Data được lưu vào Azure Storage dưới dạng JSON files.
>
> **Tại sao critical cho HIPAA?** HIPAA §164.312(b) "Audit Controls" yêu cầu "implement hardware, software, and/or procedural mechanisms that record and examine activity in information systems that contain or use ePHI." NSG Flow Logs là evidence cụ thể khi kiểm toán. Nếu có data breach, logs này cho phép forensics team truy vết xem ai đã kết nối đến database server lúc mấy giờ.
>
> **Version 2 vs Version 1:** Version 2 bổ sung thêm bytes và packets count vào mỗi flow record. Điều này cho phép phát hiện data exfiltration (ai đó copy lượng lớn dữ liệu) — nếu thấy outbound bytes từ PrivateEndpointSubnet tăng đột biến vào 2 giờ sáng, đó là dấu hiệu đáng ngờ.
>
> **Traffic Analytics** — lớp phân tích trên NSG Flow Logs: Azure tự động phân tích logs và tạo visual map về network flows, top talkers, potential threats. Hữu ích cho security operations center (SOC).

1. Tìm **Network Watcher** > **NSG flow logs** > **+ Create**.
2. Chọn NSG `nsg-private-endpoints`.
3. **Storage account:** Tạo Storage Account riêng cho logs.
4. **Retention:** 90 days (HIPAA production cần 6 năm — đây là lab).
5. **Flow Logs Version:** Version 2.
6. Bật **Traffic Analytics** với interval 10 minutes.
7. Nhấn **Review + create**. Lặp lại cho `nsg-data-workers`.

> **Troubleshooting — Flow Logs không xuất hiện sau 15 phút:**
> Kiểm tra: (1) Storage Account cùng Region với NSG? (2) Network Watcher đã kích hoạt cho Region đó chưa? Vào **Network Watcher** > **Overview** để xem.

---

## Phase 4: Private Endpoints — Hoàn toàn Tắt Public Access

> **Mục đích:** Tắt hoàn toàn Public Endpoint của ADLS Gen2, Azure SQL và Key Vault, sau đó tạo Private Endpoint cho từng dịch vụ để chúng chỉ có thể truy cập qua Private IP trong VNet.

> **Compliance Relevance:** HIPAA §164.312(e) "Transmission Security" — dữ liệu ePHI không được đi qua Internet công cộng dưới bất kỳ hình thức nào.

> **🧠 Kiến thức nền tảng — Private Endpoint vs Service Endpoint vs VNet Integration: Khác nhau ra sao?**
>
> Đây là 3 cơ chế khác nhau để "kéo" Azure PaaS services vào VNet của bạn. Sự khác biệt rất quan trọng:
>
> **Service Endpoints (Cũ, kém an toàn hơn):**
> - Traffic từ VNet đến service (ADLS, SQL) vẫn đi qua **Microsoft backbone** nhưng source IP là VNet IP của bạn.
> - Service **vẫn có Public IP** — bạn chỉ restrict firewall để chỉ cho phép traffic từ VNet của bạn.
> - **Vấn đề:** Dữ liệu vẫn ra khỏi VNet của bạn. Từ góc nhìn mạng, connection đi từ subnet của bạn → Microsoft backbone → Public IP của service. Không thể gọi là "fully private".
> - **Không đủ** cho HIPAA compliance ở hầu hết các healthcare organizations.
>
> **Private Endpoints (Mới, chuẩn enterprise):**
> - Tạo một **Network Interface (NIC)** với Private IP address nằm trong subnet của bạn, đại diện cho service (ADLS, SQL, etc.).
> - Traffic từ VNet đến service đi qua Private IP này → hoàn toàn **trong VNet của bạn**, không ra ngoài.
> - Service vẫn có Public IP nhưng bạn **disable hoàn toàn public access**.
> - DNS được override: `stdatalakemeddata001.dfs.core.windows.net` → resolve ra `10.1.2.5` (Private IP) thay vì Public IP.
> - **Chuẩn HIPAA, PCI-DSS, SOC 2.** Không có dữ liệu nào đi ra khỏi VNet.
>
> **VNet Integration (cho App Service / Functions):**
> - Dành riêng cho App Service và Azure Functions — cho phép chúng gọi ra các Private Endpoints trong VNet.
> - Khác với Private Endpoint: không tạo NIC trong VNet mà tạo "tunnel" từ App Service vào VNet.
>
> **Kết luận:** Với data services nhạy cảm (ADLS Gen2, Azure SQL), **luôn dùng Private Endpoint** trong môi trường regulated.

### Bước 4.1: Tạo các Dịch vụ Dữ liệu với Public Access Disabled ngay từ đầu

**Tạo ADLS Gen2:**
1. **Storage accounts** > **+ Create**.
2. **Name:** `stdatalakemeddata001` | **Region:** `Southeast Asia` | **Redundancy:** ZRS.
3. Tab **Advanced:** Bật **Enable hierarchical namespace** (bắt buộc cho ADLS Gen2).
4. Tab **Networking:** **Disable public access** *(CRITICAL)*.
5. Nhấn **Review + create** -> **Create**.

**Tạo Azure SQL Database:**
1. **SQL databases** > **+ Create**.
2. **Database name:** `sqldb-meddata-ehr` | **Server:** Tạo mới `sqlsrv-meddata-prod` (SQL auth, admin: `sqladmin`).
3. **Compute:** Basic tier (tiết kiệm chi phí lab).
4. Tab **Networking:** **No access** (không public endpoint nào).
5. Nhấn **Review + create** -> **Create**.

**Tạo Key Vault:**
1. **Key vaults** > **+ Create** | **Name:** `kv-meddata-prod-001`.
2. Tab **Networking:** **Disable public access**.
3. Nhấn **Review + create** -> **Create**.

### Bước 4.2: Disable Private Endpoint Network Policies trên Subnet

> **Tại sao bước này cần thiết?** Theo mặc định, Azure áp dụng NSG rules và route tables cho mọi NIC trong subnet — kể cả NIC của Private Endpoints. Nhưng Private Endpoints cần Azure routing engine "bypass" một số policy để DNS resolution và traffic forwarding hoạt động đúng. Nếu không disable, Private Endpoint tạo thành công nhưng connection sẽ fail một cách khó hiểu.

```bash
az network vnet subnet update \
  --name snet-private-endpoints \
  --resource-group rg-meddata-network-prod \
  --vnet-name vnet-meddata-spoke-data \
  --disable-private-endpoint-network-policies true
```

Hoặc Portal: Mở subnet `snet-private-endpoints` > **Edit** > **Private endpoint network policies** > **Disabled** > **Save**.

### Bước 4.3: Tạo Private Endpoint cho ADLS Gen2

1. Mở `stdatalakemeddata001` > **Networking** > **Private endpoint connections** > **+ Private endpoint**.
2. **Name:** `pe-adls-meddata` | **Region:** `Southeast Asia`.
3. **Target sub-resource:** `dfs` *(cho ADLS Gen2 Data Lake — không chọn `blob`)*.
4. **Virtual network:** `vnet-meddata-spoke-data` | **Subnet:** `snet-private-endpoints`.
5. **DNS:** **Integrate with private DNS zone: Yes** → Azure tạo `privatelink.dfs.core.windows.net`.
6. Nhấn **Review + create** -> **Create**.

> **🧠 Kiến thức nền tảng — Tại sao DNS là thành phần CRITICAL nhất của Private Endpoints?**
>
> Đây là điểm mà hầu hết mọi người setup sai lần đầu. Hãy hiểu cơ chế hoạt động:
>
> **Không có Private DNS Zone (sai):**
> - Databricks gọi: `stdatalakemeddata001.dfs.core.windows.net`
> - DNS trả về: `52.154.70.101` (Public IP của Microsoft)
> - Databricks cố kết nối ra `52.154.70.101:443`
> - Azure từ chối vì ta đã disable public access
> - Kết quả: **Connection timeout — "cannot connect to ADLS"**
>
> **Có Private DNS Zone (đúng):**
> - Azure tạo Private DNS Zone `privatelink.dfs.core.windows.net`
> - Trong zone này có record: `stdatalakemeddata001.dfs.core.windows.net` → `10.1.2.5`
> - Private DNS Zone được **link với VNet** `vnet-meddata-spoke-data`
> - Khi Databricks (trong VNet) gọi DNS, Azure DNS resolver nhận câu hỏi → kiểm tra các Private DNS Zones linked với VNet → tìm thấy record → trả về `10.1.2.5`
> - Databricks kết nối đến `10.1.2.5:443` (Private IP trong VNet) → thành công!
>
> **Quan trọng:** Private DNS Zone chỉ hoạt động cho các resources **trong VNet**. Nếu bạn thử `nslookup` từ máy laptop cá nhân, bạn vẫn nhận được Public IP (hoặc NXDOMAIN vì public disabled). Đây là behavior đúng — chỉ resources trong VNet được phép kết nối.
>
> **Trong môi trường Hybrid (có on-premises):** DNS forwarding phức tạp hơn nhiều. DNS server on-premises phải forward queries cho `*.privatelink.dfs.core.windows.net` đến Azure DNS (168.63.129.16). Cần dùng **Azure Private DNS Resolver** trong VNet để làm cầu nối.

### Bước 4.4: Tạo Private Endpoint cho Azure SQL và Key Vault

**Azure SQL:**
1. Mở SQL Server `sqlsrv-meddata-prod` > **Networking** > **+ Private endpoint**.
2. **Name:** `pe-sql-meddata` | **Sub-resource:** `sqlServer`.
3. **VNet:** `vnet-meddata-spoke-data` | **Subnet:** `snet-private-endpoints`.
4. **DNS:** Integrate với `privatelink.database.windows.net`.

**Key Vault:**
1. Mở `kv-meddata-prod-001` > **Networking** > **+ Private endpoint**.
2. **Name:** `pe-kv-meddata` | **Sub-resource:** `vault`.
3. **VNet:** `vnet-meddata-spoke-data` | **Subnet:** `snet-private-endpoints`.
4. **DNS:** Integrate với `privatelink.vaultcore.azure.net`.

### Bước 4.5: Xác minh DNS Resolution từ trong VNet

Kết nối VM trong `snet-management` qua Bastion (sau khi hoàn thành Phase 8) và chạy:

```powershell
# Phải trả về IP trong dải 10.1.2.x (Private IP)
Resolve-DnsName stdatalakemeddata001.dfs.core.windows.net
Resolve-DnsName sqlsrv-meddata-prod.database.windows.net
Resolve-DnsName kv-meddata-prod-001.vault.azure.net
```

Nếu trả về Public IP → Private DNS Zone chưa được link với VNet. Kiểm tra: Private DNS Zone > **Virtual network links** > thêm link đến `vnet-meddata-spoke-data`.

---

## Phase 5: Azure Databricks VNet Injection

> **Mục đích:** Triển khai Databricks cluster nodes trực tiếp vào VNet của MedData Vietnam, thay vì VNet mặc định của Microsoft.

> **Compliance Relevance:** Nếu không dùng VNet Injection, Databricks cluster nodes nằm trong Microsoft-managed VNet — bạn không thể chứng minh data pipeline không đi qua Internet. Đây là yêu cầu bắt buộc cho HIPAA audit.

> **🧠 Kiến thức nền tảng — Tại sao Databricks mặc định KHÔNG ở trong VNet của bạn? Điều đó có nghĩa gì?**
>
> Khi bạn tạo một Azure Databricks Workspace mà không chọn VNet Injection, Microsoft tự động tạo một **Managed VNet** — một VNet riêng biệt do Microsoft quản lý, không hiển thị trong subscription của bạn. Databricks cluster nodes (VM) chạy trong VNet đó.
>
> **Vấn đề với Managed VNet cho MedData:**
> 1. Cluster nodes **không thể kết nối** đến Private Endpoints trong VNet của bạn (vì chúng ở VNet khác và không có peering).
> 2. Kết quả: Databricks buộc phải kết nối đến ADLS qua Public endpoint. Nhưng ta đã disable public access! → **Connection failed**.
> 3. Kể cả nếu bạn enable public access, traffic đi qua Internet — vi phạm HIPAA.
>
> **VNet Injection giải quyết bằng cách:** Đặt cluster nodes vào hai subnets trong VNet của bạn (Public Subnet và Private Subnet — xem note bên dưới về tên misleading này). Cluster nodes có Private IPs trong dải `10.1.x.x` và có thể kết nối trực tiếp đến Private Endpoints trong cùng VNet.
>
> **Secure Cluster Connectivity (No Public IP):** Tùy chọn quan trọng thứ hai. Khi bật, cluster VMs không được assign Public IP address. Communication với Databricks Control Plane (để nhận lệnh chạy notebooks) đi qua một NAT Gateway relay trong VNet của Databricks. Đây là cải tiến bảo mật lớn — không có VM nào có Public IP → không có attack surface từ Internet.

### Bước 5.1: Thêm Databricks Subnets vào Spoke VNet

Databricks cần **hai subnets riêng** với subnet delegation:

Mở `vnet-meddata-spoke-data` > **Subnets** > **+ Subnet**:

**ADB Container Subnet (đóng vai trò "Public" trong Databricks terminology):**
- **Name:** `snet-adb-public`
- **Address range:** `10.1.10.0/23` *(cần /23 minimum — 512 IPs cho cluster scaling)*
- **Subnet delegation:** `Microsoft.Databricks/workspaces`

**ADB Worker Subnet (đóng vai trò "Private" trong Databricks terminology):**
- **Name:** `snet-adb-private`
- **Address range:** `10.1.12.0/23`
- **Subnet delegation:** `Microsoft.Databricks/workspaces`

### Bước 5.2: Tạo NSG cho Databricks Subnets

Tạo `nsg-adb-databricks`. Databricks yêu cầu các rules bắt buộc:

**Inbound Rules:**

| Priority | Name | Source | Destination | Port | Action |
|---|---|---|---|---|---|
| 100 | AllowADBControlPlane | `AzureDatabricks` | `VirtualNetwork` | 22, 5557 | Allow |
| 110 | AllowWorkerInternal | `VirtualNetwork` | `VirtualNetwork` | Any | Allow |

**Outbound Rules:**

| Priority | Name | Destination | Port | Action |
|---|---|---|---|---|
| 100 | AllowADBControlPlane-Out | `AzureDatabricks` | 443 | Allow |
| 110 | AllowSQL | `Sql` | 3306 | Allow |
| 120 | AllowStorage | `Storage` | 443 | Allow |
| 130 | AllowEventHub | `EventHub` | 9093 | Allow |
| 200 | AllowWorkerInternal | `VirtualNetwork` | Any | Allow |

Gắn `nsg-adb-databricks` vào cả hai ADB subnets.

### Bước 5.3: Tạo Databricks Workspace với VNet Injection

1. **Azure Databricks** > **+ Create**.
2. **Workspace name:** `adb-meddata-healthcare` | **Pricing Tier: Premium** *(bắt buộc)*.
3. **Networking Tab:**
   - **Deploy in VNet:** Toggle **Yes**
   - **VNet:** `vnet-meddata-spoke-data`
   - **Public Subnet:** `snet-adb-public` | CIDR: `10.1.10.0/23`
   - **Private Subnet:** `snet-adb-private` | CIDR: `10.1.12.0/23`
4. **Advanced Tab:** **No Public IP:** **Enabled** *(Secure Cluster Connectivity)*.
5. Nhấn **Review + create** -> **Create**.

> **Troubleshooting — "Subnet delegation missing" khi tạo workspace:**
> Mở từng subnet > **Edit** > **Subnet delegation** > Chọn `Microsoft.Databricks/workspaces` > **Save**. Sau đó retry tạo workspace.

---

## Phase 6: ADF Managed Virtual Network và Managed Private Endpoints

> **Mục đích:** Azure Data Factory kết nối đến ADLS và SQL qua Private Endpoints thông qua cơ chế **Managed Virtual Network** riêng của ADF.

> **Compliance Relevance:** Khi ADF chạy trong Managed VNet, pipeline data movement không bao giờ đi qua Internet — đáp ứng HIPAA Transmission Security cho mọi data pipeline.

> **🧠 Kiến thức nền tảng — ADF Managed VNet vs Self-Hosted Integration Runtime: Chọn cái nào?**
>
> ADF cần một **Integration Runtime (IR)** để thực thi pipeline activities (copy data, run scripts). Có 3 loại IR:
>
> **Azure Integration Runtime (Default):**
> - Chạy trong Microsoft-managed infrastructure, không trong VNet của bạn.
> - Không thể kết nối đến Private Endpoints (vì ở VNet khác).
> - Chỉ dùng khi tất cả sources/sinks đều có Public Endpoint — không phù hợp với MedData.
>
> **Azure Integration Runtime trong Managed VNet:**
> - Microsoft tạo một VNet riêng cho ADF, nhưng bạn có thể tạo **Managed Private Endpoints** bên trong đó để kết nối đến ADLS, SQL.
> - Deployment đơn giản — không cần quản lý VM.
> - **Nhược điểm:** Chỉ kết nối được đến Azure PaaS services qua Managed Private Endpoints. Không thể kết nối đến on-premises hoặc services trong VNet của bạn một cách trực tiếp.
>
> **Self-Hosted Integration Runtime (SHIR):**
> - Bạn deploy một Windows Server VM (hoặc container) **trong VNet của bạn** (`snet-data-workers`).
> - VM này có thể kết nối đến Private Endpoints trong VNet và cả on-premises network.
> - **Dùng khi:** Có on-premises sources, cần network access đến services trong VNet khác, hoặc cần custom packages/drivers không có sẵn trong Azure IR.
> - **Nhược điểm:** Phải patch, monitor, và scale VM thủ công.
>
> **Kết luận cho MedData:** Dùng Managed VNet + Managed Private Endpoints cho Azure-to-Azure pipelines (ADLS, SQL). Deploy SHIR vào `snet-data-workers` cho các nguồn dữ liệu on-premises của bệnh viện.

### Bước 6.1: Tạo ADF với Managed Virtual Network

1. **Data factories** > **+ Create**.
2. **Name:** `adf-meddata-healthcare-prod` | **Region:** `Southeast Asia`.
3. **Networking Tab:** **Enable managed virtual network:** Toggle **Enabled** *(CRITICAL)*.
4. Nhấn **Review + create** -> **Create**.

### Bước 6.2: Tạo Managed Private Endpoints

1. Mở ADF > **Launch studio** > **Manage** > **Managed private endpoints** > **+ New**.

**Managed PE cho ADLS Gen2:**
- Type: **Azure Data Lake Storage Gen2**
- **Name:** `mpe-adls-meddata`
- **Storage account:** `stdatalakemeddata001` | **Sub-resource:** `dfs`

**Managed PE cho Azure SQL:**
- Type: **Azure SQL Database**
- **Name:** `mpe-sql-meddata`
- **Server:** `sqlsrv-meddata-prod` | **Sub-resource:** `sqlServer`

### Bước 6.3: Approve Private Endpoint Connections

Managed Private Endpoints tạo connection request ở trạng thái **Pending** tại resource. Bạn phải approve:

- `stdatalakemeddata001` > **Networking** > **Private endpoint connections** > Tìm connection Pending → **Approve**.
- `sqlsrv-meddata-prod` > **Networking** > **Private endpoint connections** → **Approve**.

> **Troubleshooting — "Connection refused" sau khi Approve:**
> ADF cần 3-5 phút propagate. Kiểm tra **Managed private endpoints** trong ADF Studio: cột **Approval state** phải là `Approved` (không còn `Pending`).

---

## Phase 7: Azure Firewall và NAT Gateway — Kiểm soát Outbound Traffic

> **Mục đích:** Kiểm soát và ghi nhật ký đầy đủ cho outbound traffic từ VNet ra Internet. Databricks cần tải Python packages — chúng ta phải whitelist các domains cụ thể và block mọi thứ còn lại.

> **Compliance Relevance:** HIPAA §164.312(b) "Audit Controls" — ghi nhật ký mọi hoạt động. Firewall logs mọi outbound connection, cung cấp audit trail đầy đủ về ai kết nối đến đâu.

### Bước 7.1: Tạo Azure Firewall

**Tạo Firewall Policy:**
1. **Firewall Policies** > **+ Create** | **Name:** `fwpol-meddata-prod` | **Tier:** Standard.

**Tạo Azure Firewall:**
1. **Firewalls** > **+ Create**.
2. **Name:** `fw-meddata-hub` | **VNet:** `vnet-meddata-hub-prod` | **Policy:** `fwpol-meddata-prod`.
3. **Public IP:** Tạo mới `pip-fw-meddata-hub`.
4. Nhấn **Review + create** -> **Create**. *(Mất 5-10 phút)*

### Bước 7.2: Cấu hình FQDN Application Rules

Mở `fwpol-meddata-prod` > **Application rules** > **+ Add a rule collection**:

- **Name:** `arc-databricks-outbound` | **Priority:** 200 | **Action:** Allow

| Rule | Source | FQDN | Mục đích |
|---|---|---|---|
| Allow-PyPI | `10.1.0.0/16` | `pypi.org`, `files.pythonhosted.org` | Python packages |
| Allow-Maven | `10.1.0.0/16` | `repo1.maven.org` | Spark/Scala deps |
| Allow-MS | `10.1.0.0/16` | `*.microsoft.com`, `*.windows.com` | System updates |

### Bước 7.3: Tạo Route Table (UDR) để Force Traffic qua Firewall

> **Tại sao cần UDR?** Mặc định, Azure routing cho phép traffic từ subnet đi thẳng ra Internet (default route: 0.0.0.0/0 → Internet). Ta phải override route này để buộc outbound traffic đi qua Azure Firewall trước.

1. **Route tables** > **+ Create** | **Name:** `rt-spoke-to-firewall`.
2. **Routes** > **+ Add:**
   - **Route name:** `route-all-to-firewall`
   - **Destination:** `0.0.0.0/0` | **Next hop type:** Virtual appliance
   - **Next hop address:** Private IP của Firewall (xem trong Firewall Overview, thường `10.0.1.4`).
3. Gắn route table: **Subnets** > **+ Associate** > `snet-data-workers`.

---

## Phase 8: DDoS Protection và Azure Bastion

> **Mục đích:** Bảo vệ khỏi DDoS attacks và cung cấp kết nối quản trị an toàn đến servers trong VNet.

> **Compliance Relevance:** HIPAA "Availability" — đảm bảo hệ thống luôn sẵn sàng. DDoS Protection ngăn gián đoạn dịch vụ. Bastion đáp ứng "Access Control" — mọi kết nối quản trị phải qua Azure AD authentication.

> **🧠 Kiến thức nền tảng — Tại sao cấm SSH/RDP trực tiếp ra Internet? Azure Bastion giải quyết vấn đề gì?**
>
> **Vấn đề với SSH/RDP trực tiếp:**
> Nếu bạn mở port 22 (SSH) hoặc 3389 (RDP) trên Public IP của server và đặt trên Internet, trong vòng vài phút bạn sẽ thấy trong server logs hàng ngàn failed login attempts từ các IPs khắp thế giới (automated brute-force bots). Đây là reality của Internet — bất kỳ Public IP nào cũng bị scan liên tục.
>
> **Các giải pháp truyền thống (kém hơn):**
> - **Jump Box/Bastion Host thủ công:** Một VM có Public IP, bạn SSH vào đó rồi SSH tiếp vào server backend. Vẫn expose một Public IP, vẫn cần patch VM liên tục, vẫn có attack surface.
> - **VPN:** Phức tạp setup, cần client software trên laptop admin, khó manage MFA.
>
> **Azure Bastion giải pháp:**
> - **Không có Public IP trên server** — server chỉ có Private IP.
> - Admin đăng nhập **Azure Portal** (được bảo vệ bởi Azure AD + MFA).
> - Trong Portal, click "Connect via Bastion" → trình duyệt mở session RDP/SSH qua HTTPS (port 443).
> - Connection được tunnel qua Bastion Service (có Public IP, được Microsoft manage và patch).
> - **Audit:** Mọi session qua Bastion được log trong Azure Monitor, tích hợp với Microsoft Sentinel.
> - **Zero client software** — chỉ cần Chrome/Edge.
>
> **Bastion Standard tier** (được dùng trong bài lab) thêm tính năng:
> - **Native client support:** Dùng được Windows Remote Desktop client hoặc OpenSSH — không chỉ browser.
> - **IP-based connection:** Kết nối VM qua Private IP mà không cần VM running (hữu ích cho troubleshooting).
> - **Session recording** (tùy chọn): Record toàn bộ session video cho compliance.

### Bước 8.1: Kích hoạt Azure DDoS Protection

1. **DDoS protection plans** > **+ Create** | **Name:** `ddos-meddata-plan`.
2. Gắn vào Hub VNet: `vnet-meddata-hub-prod` > **DDoS protection** > **Enable** > Chọn `ddos-meddata-plan`.

> **Lưu ý chi phí:** DDoS Standard ~$2,944/tháng. Bỏ qua trong lab cá nhân. Bắt buộc trong production healthcare.

### Bước 8.2: Triển khai Azure Bastion

1. **Bastions** > **+ Create**.
2. **Name:** `bastion-meddata-hub` | **Region:** `Southeast Asia` | **Tier:** Standard.
3. **VNet:** `vnet-meddata-hub-prod` → Azure tự chọn `AzureBastionSubnet`.
4. **Public IP:** Tạo mới `pip-bastion-meddata`.
5. Nhấn **Review + create** -> **Create**. *(Deploy mất 5-10 phút)*

**Kết nối VM qua Bastion:**
1. Tạo Windows Server VM trong `snet-management` — **không chọn Public IP** (None).
2. Mở VM > **Connect** > **Bastion** > Nhập credentials → Session mở trong browser.

> **Troubleshooting — Bastion connection timeout:**
> NSG trên `AzureBastionSubnet` phải cho phép inbound HTTPS (443) từ Internet và outbound đến VirtualNetwork. Xem Microsoft docs "NSG support in Azure Bastion" để biết full list required rules.

---

## Phase 9: Network Monitoring với Network Watcher

> **Mục đích:** Công cụ giám sát, chẩn đoán và gỡ lỗi network sau khi triển khai toàn bộ kiến trúc.

> **Compliance Relevance:** HIPAA §164.312(b) "Audit Controls" — ghi nhật ký và kiểm tra mọi hoạt động. Network Watcher Traffic Analytics cung cấp visibility đầy đủ về network flows.

### Bước 9.1: Kích hoạt Network Watcher

1. **Network Watcher** > **Overview** > Kiểm tra `Southeast Asia` status = **Enabled**.
2. Nếu Not Enabled: Click vào row đó và bật lên.

### Bước 9.2: Connection Troubleshooter

Kiểm tra xem VM trong VNet có kết nối được đến Private Endpoint không, và nếu không thì bị block ở đâu:

1. **Network Watcher** > **Connection troubleshoot**.
2. **Source:** VM trong `snet-management`.
3. **Destination:** Private IP của ADLS Private Endpoint (xem trong `pe-adls-meddata` > Network Interface > IP Configurations).
4. **Port:** 443 | **Protocol:** TCP > Nhấn **Check**.
5. Kết quả **Reachable** = thành công. **Unreachable** = hiển thị hop-by-hop path và node đang block.

### Bước 9.3: IP Flow Verify — Kiểm tra NSG Rule cụ thể

1. **Network Watcher** > **IP flow verify**.
2. **VM:** VM trong `snet-data-workers` | **Direction:** Outbound.
3. **Local IP:** `10.1.1.10` | **Local port:** 12345.
4. **Remote IP:** `10.1.2.5` (ADLS PE) | **Remote port:** 443 | **Protocol:** TCP.
5. Nhấn **Check** → Kết quả cho biết **Access allowed/denied** và **tên NSG rule cụ thể** đang áp dụng.

### Bước 9.4: Packet Capture — Forensics

> **Định nghĩa:** Packet Capture thu thập tất cả network packets đi qua một VM trong khoảng thời gian nhất định, lưu file `.pcap` để phân tích bằng Wireshark.

1. **Network Watcher** > **Packet capture** > **+ Add**.
2. **VM:** Chọn VM trong `snet-management`.
3. **Storage Account:** Chọn để lưu file `.cap`.
4. **Time limit:** 30 giây > **OK**.
5. Download file `.cap` và mở Wireshark để phân tích chi tiết.

### Bước 9.5: Traffic Analytics — Security Dashboard

1. **Network Watcher** > **Traffic Analytics**.
2. Chọn **Subscription** và **Log Analytics Workspace**.
3. Dashboard hiển thị: Malicious traffic, top protocols, top talkers, blocked flows.

> **Troubleshooting — Traffic Analytics không có data:**
> Cần NSG Flow Logs (Phase 3) VÀ Log Analytics Workspace. Tạo Workspace tại **Log Analytics workspaces** > **+ Create**. Data mất 60 phút để xuất hiện lần đầu.

**Firewall Log Query (Kusto):**
```kusto
AzureDiagnostics
| where Category == "AzureFirewallApplicationRule"
| where TimeGenerated > ago(1h)
| project TimeGenerated, SourceIP_s, FQDN_s, Action_s
| order by TimeGenerated desc
| take 50
```

---

## Phase 10: End-to-End Connectivity Test & Cleanup

> **Mục đích:** Xác nhận toàn bộ kiến trúc hoạt động đúng và không có Public Endpoint nào còn bị expose.

> **Compliance Relevance:** Mọi compliance framework đều yêu cầu periodic testing — không đủ chỉ configure, phải prove it works và prove public access is blocked.

### Bước 10.1: Verify Public Access Bị Chặn (từ ngoài VNet)

Từ máy laptop cá nhân (không trong VNet):

```bash
# Phải FAIL — connection timeout hoặc 403
curl --connect-timeout 10 "https://stdatalakemeddata001.dfs.core.windows.net/"

# Phải FAIL — SQL unreachable từ Internet
# (Thử kết nối SSMS từ máy local — không add firewall rule cho IP máy bạn)
```

### Bước 10.2: Verify DNS Resolution từ trong VNet

Kết nối VM qua Bastion > PowerShell:

```powershell
# Phải trả về Private IP (10.1.2.x) — không phải Public IP
Resolve-DnsName stdatalakemeddata001.dfs.core.windows.net
Resolve-DnsName sqlsrv-meddata-prod.database.windows.net
Resolve-DnsName kv-meddata-prod-001.vault.azure.net
```

### Bước 10.3: Test ADF Pipeline qua Managed Private Endpoint

1. Trong ADF Studio, tạo Copy Activity: SQL → ADLS.
2. **Integration Runtime:** AutoResolveIntegrationRuntime (Managed VNet).
3. Chạy **Debug** → Xác nhận Success = ADF kết nối qua Managed Private Endpoints.

### Bước 10.4: Test Databricks đọc ADLS qua Private Endpoint

Trong Databricks Notebook:

```python
# Test đọc từ ADLS Gen2 qua Private Endpoint
dbutils.fs.ls("abfss://bronze-raw@stdatalakemeddata001.dfs.core.windows.net/")
# Kết quả: Liệt kê files thành công = Private Endpoint hoạt động!

# Test ghi
dbutils.fs.put(
    "abfss://bronze-raw@stdatalakemeddata001.dfs.core.windows.net/test_pe.txt",
    "MedData Vietnam - Private Endpoint Test PASSED!",
    overwrite=True
)
print("Write via Private Endpoint: SUCCESS")
```

---

## Phase 11: Dọn dẹp Tài nguyên (Cleanup)

> **Mục đích:** Xóa toàn bộ tài nguyên để Azure ngừng tính phí. Azure Firewall và DDoS Plan tính phí ngay cả khi không có traffic — phải xóa đầu tiên.

**Thứ tự xóa:**
1. **Databricks Workspace** — giải phóng VNet delegation.
2. **ADF** — giải phóng Managed Private Endpoints.
3. **Azure Firewall** — dịch vụ tốn phí nhất.
4. **Azure Bastion** + Public IPs.
5. **DDoS Protection Plan** (nếu đã tạo).
6. **Private Endpoints** cho ADLS, SQL, Key Vault.
7. **Toàn bộ Resource Group** — xóa mọi thứ còn lại:

```bash
az group delete \
  --name rg-meddata-network-prod \
  --yes \
  --no-wait
```

Hoặc Portal: **Resource groups** > `rg-meddata-network-prod` > **Delete resource group** > Gõ tên xác nhận > **Delete**.

> **Lưu ý:** Private DNS Zones đôi khi không bị xóa cùng Resource Group nếu đang linked với VNets ở RG khác. Kiểm tra **Private DNS zones** sau khi xóa và xóa thủ công nếu cần.

---

## Tổng kết Kiến trúc và Bài học Rút ra

Sau khi hoàn thành Lab, MedData Vietnam đã triển khai được kiến trúc mạng đáp ứng HIPAA:

| Lớp bảo mật | Thành phần | HIPAA Control |
|---|---|---|
| **Network Isolation** | Hub-and-Spoke VNet, VNet Peering | AC, SC |
| **Traffic Control** | NSG + Flow Logs, ASG logical grouping | AC, AU |
| **Data Privacy** | Private Endpoints: ADLS, SQL, Key Vault | SC, IA |
| **Compute Isolation** | Databricks VNet Injection + No Public IP | SC |
| **Pipeline Security** | ADF Managed VNet + Managed Private Endpoints | SC |
| **Outbound Control** | Azure Firewall + UDR + FQDN Rules | AC, AU |
| **DDoS Protection** | Azure DDoS Protection Standard | AU |
| **Secure Management** | Azure Bastion (no direct RDP/SSH to Internet) | AC, IA |
| **Monitoring** | Network Watcher, Traffic Analytics, Packet Capture | AU |

**5 Bài học quan trọng nhất:**

1. **Private Endpoint + Private DNS Zone phải đi cùng nhau** — thiếu DNS là toàn bộ connection fail với thông báo lỗi khó hiểu.
2. **Hub-and-Spoke với Azure Firewall** là bắt buộc cho multi-spoke architectures vì VNet Peering non-transitive.
3. **Databricks VNet Injection** yêu cầu subnet delegation và một bộ NSG rules đặc biệt của Databricks — không thể dùng NSG rules thông thường.
4. **NSG ≠ Azure Firewall** — NSG là Layer 4 (IP/Port), Firewall là Layer 7 (FQDN, threat intel). Cần cả hai.
5. **Zero-trust trong network = mọi thứ mặc định bị chặn** (Deny-All rule) và chỉ whitelist những gì thực sự cần thiết.

Chúc mừng! Bạn đã xây dựng thành công một kiến trúc mạng enterprise-grade, đáp ứng các yêu cầu compliance khắt khe nhất trong ngành y tế tại Việt Nam và quốc tế.
