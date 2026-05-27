# Hướng dẫn Lab 10: Enterprise Identity & Access Governance: Microsoft Entra ID, OAuth 2.0 & Zero Trust for Data Platforms

Chào mừng bạn đến với bài Lab thực hành chuyên sâu về **Microsoft Entra ID** — hệ thống quản lý danh tính và quyền truy cập (Identity & Access Management - IAM) trung tâm của toàn bộ hệ sinh thái Azure. Đây không chỉ là một bài Lab step-by-step. Đây là **giáo trình kết hợp thực hành** — mỗi bước đều đi kèm giải thích kiến trúc sâu, so sánh các lựa chọn thiết kế, và hệ quả thực tế nếu bỏ qua.

---

## Kịch bản Nghiệp vụ (The Business Scenario)

Công ty Tài chính Công nghệ **FinSecure** đang chuyển dịch toàn bộ nền tảng dữ liệu on-premise lên Azure. Là một tổ chức tài chính chịu sự kiểm soát của MAS (Monetary Authority of Singapore) và NHNN (Việt Nam), yêu cầu bảo mật của họ cực kỳ khắt khe:

- **Không mật khẩu hardcode:** Tất cả các dịch vụ (ADF, Databricks) phải xác thực qua **Managed Identity** — không bao giờ dùng username/password trong code.
- **Least-Privilege RBAC:** Mỗi nhóm developer chỉ được cấp đúng quyền tối thiểu cần thiết thông qua **Entra ID Groups**.
- **Partner API Security:** Đối tác bên ngoài xác thực qua **OAuth 2.0 Client Credentials** — không có user login.
- **Zero Trust Audit:** Mọi lần truy cập được ghi nhận vào **Entra ID Audit Logs** và tập trung tại **Log Analytics Workspace**.

> **🧠 Kiến thức nền tảng — Zero Trust vs. Perimeter Security (VPN)**
>
> Mô hình bảo mật truyền thống hoạt động theo kiểu **"Castle and Moat"** (Lâu đài và Hào nước): Có một vành đai bảo vệ cứng (firewall, VPN). Mọi thứ bên trong được mặc định tin tưởng — nếu bạn vào được bên trong tường thành, bạn có thể làm mọi thứ.
>
> **Vấn đề:** Khi kẻ tấn công vượt qua được vành đai (ví dụ: chiếm VPN credentials của một nhân viên), toàn bộ hệ thống nội bộ bị phơi bày. Đây là cách hầu hết các vụ breach nghiêm trọng xảy ra — attacker di chuyển tự do *bên trong* mạng nội bộ trong nhiều tháng mà không bị phát hiện.
>
> **Zero Trust** thay thế hoàn toàn mô hình này bằng triết lý: **"Never Trust, Always Verify"** — không tin tưởng BẤT KỲ ai hay thiết bị nào, dù đang ở bên trong hay bên ngoài mạng, cho đến khi danh tính được xác minh rõ ràng với MFA, device compliance check, và location verification. Kể cả IT Admin cũng phải qua MFA khi truy cập production data.
>
> FinSecure áp dụng Zero Trust vì một lý do kinh doanh cụ thể: Sau sự cố năm 2023 khi một ngân hàng lớn bị hack qua stolen VPN credentials, MAS yêu cầu tất cả tổ chức tài chính phải loại bỏ mô hình "trust inside perimeter" trước năm 2025.

---

## Phase 1: Entra ID Tenant — Nền tảng của Mọi Danh tính

### Bước 1: Hiểu rõ Tenant vs. Subscription — Phân biệt căn bản nhất

> **Purpose:** Đây là sự nhầm lẫn phổ biến nhất với người mới. Bắt buộc phải hiểu rõ trước khi tiếp tục.
> **Security Implication:** Nhầm lẫn giữa Tenant và Subscription dẫn đến cấp quyền sai phạm vi — rò rỉ dữ liệu giữa các phòng ban hoặc giữa các môi trường (dev/prod).

> **🧠 Kiến thức nền tảng — Authentication (AuthN) vs. Authorization (AuthZ)**
>
> Trước khi hiểu Tenant vs. Subscription, cần nắm vững sự phân biệt then chốt này:
> - **Authentication (Xác thực — AuthN):** Trả lời câu hỏi "**Bạn là ai?**" — Kiểm tra danh tính. Ví dụ: Nhập username + password + MFA. Sau khi xác thực thành công, bạn nhận được một **Identity Token** chứng minh danh tính.
> - **Authorization (Ủy quyền — AuthZ):** Trả lời câu hỏi "**Bạn được làm gì?**" — Kiểm tra quyền hạn. Ví dụ: Sau khi biết bạn là Alice (AuthN), hệ thống kiểm tra Alice có quyền đọc bảng `gold.transactions` không (AuthZ).
>
> **🧠 Kiến thức nền tảng — Bản chất và Vai trò của Tenant ID**
>
> **Tenant (Thư mục)** là một instance độc lập của Microsoft Entra ID được cấp riêng cho doanh nghiệp của bạn.
> - **Tenant ID** là một mã định danh duy nhất toàn cầu (GUID - 128 bit) đại diện cho ranh giới doanh nghiệp đó.
> - **Ẩn dụ:** Nếu xem Azure là một **tòa nhà văn phòng khổng lồ**, thì mỗi công ty thuê một tầng riêng biệt. **Tenant ID** chính là **số tầng** được cấp riêng cho bạn. Không một ai ở tầng khác có thể tự ý bước vào văn phòng của bạn trừ khi được cấp thẻ khách (Guest access).
>
> **Tenant ID dùng để làm gì trong thực tế?**
> 1. **Định tuyến Xác thực (AuthN Routing):** Khi người dùng hoặc ứng dụng đối tác muốn đăng nhập, URL đăng nhập sẽ chứa Tenant ID để Microsoft biết cần hiển thị trang đăng nhập của riêng công ty bạn và áp dụng đúng các chính sách MFA/CA của bạn:
>    `https://login.microsoftonline.com/{tenant-id}/oauth2/v2.0/authorize`
> 2. **Xác thực Token (Token Validation):** Khi API của bạn nhận được một Access Token (JWT), backend sẽ kiểm tra trường Issuer (`iss`). Trường này bắt buộc phải chứa Tenant ID của bạn để đảm bảo token này do chính hệ thống của bạn phát hành, không phải từ một tổ chức lạ khác:
>    `"iss": "https://login.microsoftonline.com/{tenant-id}/v2.0"`
> 3. **Cấu hình Code & Tooling (IaC, SDK):** Khi viết code (như MSAL trong Python) hoặc chạy các công cụ tự động hóa hạ tầng (Terraform/Ansible), bạn phải khai báo Tenant ID trong biến môi trường để SDK biết cần xin cấp quyền truy cập vào danh bạ (directory) nào:
>    `export AZURE_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"`
>
> **Entra ID Tenant** chủ yếu xử lý **Authentication** — "Bạn là ai?" cho toàn tổ chức FinSecure.  
> **Azure RBAC** (gắn với Subscription) xử lý **Authorization** — "Bạn được làm gì với tài nguyên Azure?"
>
> Sơ đồ tư duy:
> ```
> Entra ID Tenant (finsecure.onmicrosoft.com)
> ├── Quản lý Danh tính (AuthN): Users, Groups, App Registrations
> ├── Tenant ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
> │
> └── Subscription "FinSecure-Production" (gắn với Tenant này)
>     ├── Resource Group: rg-data-platform-prod
>     ├── Quản lý Tài nguyên Azure (AuthZ via RBAC)
>     └── Resource Group: rg-networking-prod
> ```
> **Hệ quả nếu nhầm lẫn:** Một developer xin quyền "Contributor trên Subscription" — họ nghĩ chỉ được quyền ở một resource group. Thực ra họ vừa nhận quyền tạo/xóa MỌI tài nguyên trong toàn bộ Subscription — bao gồm production database chứa dữ liệu khách hàng.

**Thực hành — Khám phá Entra ID Tenant:**
1. Đăng nhập [portal.azure.com](https://portal.azure.com).
2. Gõ **Microsoft Entra ID** trong search bar → chọn dịch vụ.
3. Màn hình Overview: Copy và lưu lại **Tenant ID** — chuỗi GUID dạng `xxxxxxxx-xxxx-...`. Bạn sẽ cần nó trong mọi OAuth configuration.
4. Chọn **Properties** ở menu trái để xem thêm chi tiết Tenant.

### Bước 2: Directory Roles — Phân quyền Quản trị Tenant

> **Purpose:** Hiểu phân cấp quyền quản trị trong Entra ID — ai có thể làm gì ở tầng Directory.
> **Security Implication:** Theo nguyên tắc Least Privilege, không bao giờ cấp **Global Administrator** khi chỉ cần vai trò hạn chế hơn. Đây là lỗi phổ biến nhất trong các tổ chức nhỏ — mọi người đều là Global Admin "cho tiện" — tạo ra attack surface khổng lồ.

| Directory Role | Quyền hạn | Ai cần tại FinSecure? |
|---------------|-----------|----------------------|
| **Global Administrator** | Toàn quyền Tenant | Chỉ 2 người, dùng emergency account |
| **User Administrator** | Tạo/quản lý Users & Groups | IT Helpdesk |
| **Application Administrator** | Tạo/quản lý App Registrations | DevOps/Security team |
| **Security Reader** | Xem Security reports, không chỉnh sửa | SOC Analyst |
| **Privileged Role Administrator** | Quản lý role assignments trong Entra ID | IAM team lead |

**Thực hành — Xem và gán Directory Role:**
1. Trong Entra ID → **Roles and administrators** → tìm **Application Administrator**.
2. Click vào role → xem danh sách members hiện tại.
3. Click **+ Add assignments** → thêm user cho team DevOps.

---

## Phase 2: Identity Hierarchy — Users, Groups & Dynamic Membership

> **🧠 Kiến thức nền tảng — Tại sao quản lý theo Groups thay vì Individual Users?**
>
> Hãy tưởng tượng FinSecure có 50 Data Engineers. Nếu cấp RBAC trực tiếp cho từng người:
> - Mỗi khi tuyển thêm 1 engineer mới → phải làm 15 role assignments thủ công trên 15 resources khác nhau.
> - Mỗi khi engineer nghỉ việc → phải tìm và xóa 15 assignments đó — rất dễ sót, tạo ra "orphaned access".
> - Không có cách nào audit nhanh: "Data Engineers hiện được quyền làm gì?" — phải kiểm tra từng resource một.
>
> Với **Group-based Access Control:**
> - Cấp RBAC 1 lần cho group `sg-finsecure-data-engineers` trên tất cả resources cần thiết.
> - Engineer mới → thêm vào group → tự động có đủ quyền.
> - Engineer nghỉ → xóa khỏi group → tất cả quyền mất ngay lập tức.
> - Audit đơn giản: kiểm tra assignments của group là biết toàn bộ quyền của bộ phận.
>
> **Hệ quả thực tế của việc không dùng Groups:** Năm 2022, một công ty fintech tại Singapore bị phạt $1.2M vì cựu nhân viên vẫn có quyền truy cập hệ thống 3 tháng sau khi nghỉ việc — IT quên xóa permissions cá nhân trên 7 systems khác nhau.

### Bước 1: Tạo một Security Group mô phỏng cho FinSecure Data Platform

> **Purpose:** Tạo một nhóm bảo mật duy nhất để đại diện cho toàn bộ đội ngũ kỹ sư và phân tích dữ liệu của FinSecure nhằm đơn giản hóa việc thực hành Lab.
> **Security Implication:** Trong thực tế, bạn nên tách biệt thành nhiều nhóm chuyên biệt. Tuy nhiên, để thử nghiệm các tính năng bảo mật như RBAC, Managed Identity và Conditional Access, chỉ cần duy nhất 1 nhóm làm mẫu là đủ.

1. Trong Entra ID → **Groups** → **+ New group**.
2. Cấu hình thông tin nhóm như sau:
   - **Group type:** Security
   - **Membership type:** Assigned
   - **Name:** `sg-finsecure-data-engineers`
   - **Description:** Simulated Data Group - Main team accessing Azure Data Platform
3. Click **Create** để hoàn thành tạo nhóm.

---

## Phase 3: App Registration — Đăng ký Ứng dụng và API

> **🧠 Kiến thức nền tảng — App Registration là gì và tại sao cần nó?**
>
> Hãy tưởng tượng bạn đang tổ chức một sự kiện VIP (hệ thống FinSecure). Để vào, khách phải xuất trình thẻ mời (Access Token). Nhưng ai phát hành thẻ mời? **Entra ID** — vai trò là Ban Tổ chức.
>
> Để Ban Tổ chức biết ứng dụng nào được phép yêu cầu phát hành thẻ mời, ứng dụng đó phải **đăng ký trước** — đây là App Registration. Khi đăng ký, ứng dụng khai báo:
> - Tên và danh tính (Client ID)
> - Loại ứng dụng (web app, mobile, service daemon)
> - Quyền nó cần (API Permissions — Scopes)
> - Nơi nhận thẻ mời (Redirect URI)
>
> **Tại sao không dùng API Key thay vì OAuth 2.0?**
> - **API Key:** Chỉ là một chuỗi string bí mật. Không biết *ai* đang dùng key đó. Key bị lộ → phải invalidate và thông báo cho tất cả consumers. Không có expiry tự động. Không có scopes (ai có key thì được làm MỌI THỨ).
> - **OAuth 2.0:** Token chứa danh tính đầy đủ (ai, từ đâu, được làm gì, hết hạn lúc nào). Hết hạn tự động sau 1 giờ. Scopes giới hạn quyền chính xác. Có audit trail đầy đủ. Có thể revoke theo real-time.
>
> **FinSecure chọn OAuth 2.0 vì:** MAS và PCI-DSS yêu cầu granular access control và audit trail cho mọi API call. API Key không đáp ứng được tiêu chí này.

### Bước 1: Tạo App Registration cho FinSecure Partner API

> **Purpose:** Tạo danh tính cho API backend. Đối tác bên ngoài xác thực với App Registration này.
> **Security Implication:** App Registration là "cổng vào" của ứng dụng. Cấu hình sai (redirect URI quá rộng, unnecessary permissions) là attack vector phổ biến trong các cuộc tấn công OAuth phishing.

1. Entra ID → **App registrations** → **+ New registration**.
2. Điền thông tin:
   - **Name:** `finsecure-partner-api`
   - **Supported account types:** `Accounts in this organizational directory only (Single tenant)`

> **🧠 Single-tenant vs. Multi-tenant — Chọn khi nào?**
>
> - **Single-tenant:** Chỉ users/services trong Tenant của FinSecure mới xác thực được. Phù hợp với internal API và partner API (partners được cấp account trong Tenant của FinSecure — guest accounts).
> - **Multi-tenant:** Users từ bất kỳ Entra ID Tenant nào trên thế giới đều có thể đăng nhập. Phù hợp với SaaS applications bán cho nhiều doanh nghiệp khác nhau (ví dụ: Microsoft Teams, Salesforce).
> - **Personal Microsoft accounts + org accounts:** Cho consumer apps như Xbox, Outlook.
>
> **FinSecure chọn Single-tenant** vì Partner API chỉ dành cho các đối tác đã có hợp đồng — không cần mở rộng ra toàn thế giới. Multi-tenant tăng attack surface không cần thiết.

3. **Redirect URI:** Để trống (Partner API dùng Client Credentials — không có browser redirect).
4. Click **Register** → ghi lại **Application (client) ID** và **Directory (tenant) ID**.

### Bước 2: Expose API — Định nghĩa Scopes

> **Purpose:** Scopes định nghĩa những "quyền" mà consumer có thể yêu cầu khi gọi API.
> **Security Implication:** Scopes là cơ chế Least Privilege quan trọng nhất của OAuth 2.0. Thiết kế scope tốt: `transactions.read` (chỉ đọc giao dịch) tốt hơn `data.all` (toàn quyền data). Granular scopes = blast radius nhỏ hơn khi một consumer bị compromise.

1. App Registration → **Expose an API** → **Add** bên cạnh **Application ID URI** → **Save**.
2. **+ Add a scope:**
   - **Scope name:** `data.read`
   - **Admin consent display name:** `Read FinSecure Financial Data`
   - **Admin consent description:** `Allows reading financial transaction data from FinSecure platform.`
   - Click **Add scope**.
3. Thêm scope thứ hai: `reports.generate` — tương tự.

### Bước 3: App Roles — Phân quyền trong Token

> **Purpose:** App Roles cho phép kiểm soát truy cập dựa trên vai trò trực tiếp trong JWT token — API không cần gọi database để kiểm tra quyền mỗi request.
> **Security Implication:** Roles trong token giúp API stateless và nhanh hơn. Nhưng nhớ: token valid 1 giờ — nếu revoke role, partner vẫn có quyền cho đến khi token hết hạn. Cần thiết kế token expiry phù hợp (15-30 phút cho sensitive APIs).

1. App Registration → **App roles** → **+ Create app role**:
   - **Display name:** `DataReader` | **Value:** `DataReader`
   - **Allowed member types:** Both (Users/Groups + Applications)
2. Tạo thêm role `ReportGenerator`.

### Bước 4: Client Secret — Mật khẩu của Ứng dụng

> **Purpose:** Client Secret là credential mà đối tác dùng để chứng minh danh tính khi xin token.
> **Security Implication:** Client Secrets phải được lưu trong **Azure Key Vault** — KHÔNG BAO GIỜ hardcode trong source code, config files, hay `.env` files được commit lên git. Đặt expiry 6-12 tháng và có rotation plan. KHÔNG dùng Client Secret cho workloads chạy trong Azure — dùng Managed Identity thay thế.

1. **Certificates & secrets** → **Client secrets** → **+ New client secret**.
2. **Description:** `partner-prod-secret-2024` | **Expires:** `6 months`.
3. Click **Add** → Copy **Value** ngay lập tức (chỉ hiện một lần duy nhất).
4. Lưu vào Azure Key Vault theo hướng dẫn Phase 6.

---

## Phase 4: Service Principal & Managed Identity — Không Bao Giờ Dùng Mật khẩu Trong Azure

> **🧠 Kiến thức nền tảng — Tại sao Managed Identity thay đổi hoàn toàn cách tiếp cận bảo mật?**
>
> Trước khi có Managed Identity, để Azure Data Factory kết nối với SQL Database, developer phải:
> 1. Tạo SQL user với username/password.
> 2. Lưu password vào ADF Linked Service (nơi mọi người có quyền xem ADF đều đọc được).
> 3. Mỗi 90 ngày rotate password theo chính sách bảo mật.
> 4. Nếu quên rotate → security audit phát hiện → incident report → phạt tiền.
>
> Với **Managed Identity**, Azure tự động:
> - Tạo một Service Principal ẩn trong Entra ID gắn với ADF.
> - Azure tự quản lý và rotate private key mỗi ngày (bạn không bao giờ thấy key này).
> - ADF tự động nhận token khi cần bằng cách gọi Azure Instance Metadata Service nội bộ.
> - Không có credential nào để lộ, không có gì để rotate thủ công, không có gì để hack.
>
> **So sánh trực quan:**
> ```
> Service Principal (cũ):  ADF --[client_id + secret]--> Entra ID --> Token --> SQL
> Managed Identity (mới):  ADF --[tôi là ADF, Azure xác nhận]--> Entra ID --> Token --> SQL
> ```
>
> Managed Identity hoạt động như thẻ nhân viên sinh trắc học được Azure tự động xác nhận — bạn không cần nhớ mật khẩu, không cần gia hạn, không thể làm giả.

### Bước 1: Phân biệt System-assigned vs. User-assigned Managed Identity

> **Purpose:** Chọn đúng loại Managed Identity cho từng use case.
> **Security Implication:** System-assigned MI tự xóa khi resource bị xóa — không để lại orphaned identities. User-assigned MI tồn tại độc lập — phải có decommission process rõ ràng.

| Tiêu chí | System-assigned MI | User-assigned MI |
|----------|-------------------|-----------------|
| **Vòng đời** | Gắn với resource — xóa resource thì MI tự xóa | Độc lập — phải xóa thủ công |
| **Chia sẻ** | Chỉ 1 resource dùng | Nhiều resources dùng chung |
| **Dùng khi** | 1 resource cần quyền riêng | Nhiều resources cần cùng quyền |
| **Ví dụ FinSecure** | ADF có quyền Key Vault riêng | 10 Azure Functions cùng đọc 1 Storage |

**Quy tắc FinSecure:** ADF và Databricks Access Connector dùng **System-assigned** (mỗi service có quyền riêng, tách biệt). 10 Azure Functions trong microservices layer dùng **User-assigned** (cùng quyền, quản lý 1 chỗ).

### Bước 2: Bật Managed Identity cho Azure Data Factory và Virtual Machine

> **Purpose:** Cấu hình Managed Identity để các tài nguyên (ADF hoặc Virtual Machine) tự động xác thực và truy cập Key Vault/Storage mà không cần mật khẩu tĩnh.
> **Security Implication:** Sau khi bật MI, loại bỏ hoàn toàn việc hardcode credentials. Đối với Virtual Machine, token chỉ có thể được lấy từ chính môi trường của VM thông qua IMDS, tránh việc rò rỉ secret ra bên ngoài.

#### **Lựa chọn A — Dành cho Azure Data Factory (ADF):**
1. Azure Portal → **Data Factory** của bạn → menu trái → **Settings** → **Identity**.
2. Tab **System assigned** → Status: **On** → **Save** → xác nhận.
3. Ghi lại **Object ID** xuất hiện — đây là ID của MI trong Entra ID.

#### **Lựa chọn B — Dành cho Virtual Machine (VM):**

##### **Bước B.1: Tạo Resource Group và Virtual Machine**
Để thực hành, chúng ta sẽ tạo một nhóm tài nguyên (Resource Group) tên là `rg-finsecure-data-dev` và một máy ảo (VM) Ubuntu tên là `vm-finsecure-data-dev`.

* **Cách 1: Sử dụng Azure CLI (Khuyên dùng - Nhanh nhất)**
  Mở terminal local của bạn hoặc Azure Cloud Shell và chạy các lệnh sau:
  ```bash
  # 1. Tạo Resource Group tại khu vực mong muốn (ví dụ: East US)
  az group create --name rg-finsecure-data-dev --location eastus

  # 2. Tạo VM Ubuntu 22.04 LTS (cấu hình B1s giá rẻ để học tập)
  az vm create \
    --resource-group rg-finsecure-data-dev \
    --name vm-finsecure-data-dev \
    --image Ubuntu2204 \
    --size Standard_B1s \
    --admin-username azureuser \
    --generate-ssh-keys
  ```
  *(Sau khi chạy, lệnh sẽ tự động sinh cặp SSH Key và lưu private key tại `~/.ssh/id_rsa` để bạn kết nối).*

* **Cách 2: Thực hiện trên Azure Portal**
  1. Gõ **Resource Groups** trên thanh tìm kiếm -> click **Create**:
     * **Subscription:** Chọn subscription của bạn.
     * **Resource group:** Nhập `rg-finsecure-data-dev`.
     * **Region:** Chọn `East US`.
     * Click **Review + create** -> **Create**.
  2. Gõ **Virtual machines** -> click **Create** -> **Azure virtual machine**:
     * **Resource group:** Chọn `rg-finsecure-data-dev`.
     * **Virtual machine name:** Nhập `vm-finsecure-data-dev`.
     * **Region:** Chọn `East US`.
     * **Image:** Chọn `Ubuntu Server 22.04 LTS - Gen2`.
     * **Size:** Chọn `Standard_B1s` (hoặc size nhỏ bất kỳ).
     * **Administrator account:** Chọn `SSH public key` -> Username: `azureuser`.
     * **Inbound port rules:** Chọn `Allow selected ports` -> Tích chọn `SSH (22)`.
     * Click **Review + create** -> **Create** (tải xuống private key khi được hỏi và lưu cẩn thận).

##### **Bước B.2: Bật Managed Identity cho Virtual Machine**
Sau khi VM đã ở trạng thái **Running** (Đang chạy):
* **Cách 1 (Azure Portal):** Vào **Virtual Machines** → Chọn `vm-finsecure-data-dev` → Menu trái chọn **Identity** (phần Security) → Tab **System assigned** → Status: **On** → **Save** → Xác nhận.
* **Cách 2 (Azure CLI):** Chạy lệnh sau:
  ```bash
  az vm identity assign -g rg-finsecure-data-dev -n vm-finsecure-data-dev
  ```

**Verify trong Entra ID:**
- Entra ID → **Enterprise applications** → Filter: **Managed Identities**.
- Tìm tên ADF hoặc VM của bạn — xác nhận MI đã được tạo thành công.

### Bước 3: Cấp Quyền cho Managed Identity trên Key Vault

> **Purpose:** Cấp quyền truy cập tối thiểu (Least Privilege) để ADF hoặc VM có thể đọc các secrets cần thiết.
> **Security Implication:** Chỉ cấp role **Key Vault Secrets User** (read-only) — không cấp **Key Vault Administrator** hoặc **Secrets Officer** (tạo/xóa/cập nhật) trừ khi thực sự cần thiết.

1. **Key Vault** → **Access control (IAM)** → **+ Add** → **Add role assignment**.
2. Role: **Key Vault Secrets User** → click **Next**.
3. **Assign access to:** Chọn **Managed identity**.
4. **+ Select members:**
   * Chọn Subscription chứa tài nguyên của bạn.
   * Chọn loại tài nguyên tương ứng (**Data Factory** hoặc **Virtual Machine**).
   * Chọn tên tài nguyên đã được bật MI ở Bước 2 → click **Select**.
5. Click **Review + assign** hai lần để hoàn tất.

### Bước 4: Thử nghiệm lấy Access Token từ bên trong Virtual Machine (IMDS)

> **Purpose:** Hiểu cơ chế hoạt động ngầm (under the hood) của Managed Identity trên VM thông qua Instance Metadata Service (IMDS).
> **Security Implication:** IMDS chạy ở IP link-local (`169.254.169.254`) chỉ truy cập được từ chính nội bộ VM. Điều này đảm bảo kẻ tấn công bên ngoài không thể lợi dụng để lấy cắp token trừ khi họ đã chiếm quyền điều khiển trực tiếp trên VM.

1. **SSH** vào bên trong Virtual Machine của bạn.
2. Chạy lệnh `curl` sau để gửi request xin Entra ID cấp Access Token cho dịch vụ Key Vault (`resource=https://vault.azure.net`):
   ```bash
   curl -H "Metadata: true" "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net"
   ```
3. Kết quả trả về sẽ là một JSON chứa `access_token` (JWT):
   ```json
   {
     "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIs...",
     "token_type": "Bearer",
     "expires_in": "86399",
     "resource": "https://vault.azure.net"
   }
   ```

---

## Phase 5: OAuth 2.0 Flows — Hiểu Sâu Cơ chế Xác thực

> **🧠 Kiến thức nền tảng — OAuth 2.0 hoạt động như thế nào "under the hood"?**
>
> OAuth 2.0 là framework cho phép một ứng dụng (Client) yêu cầu quyền truy cập tài nguyên thay mặt cho người dùng hoặc chính nó, mà không cần biết mật khẩu của người dùng. Các thành phần:
> - **Authorization Server (AS):** Entra ID — phát hành tokens.
> - **Resource Server (RS):** FinSecure Partner API — nhận và validate tokens.
> - **Client:** Ứng dụng của đối tác — yêu cầu tokens.
> - **Resource Owner:** Người dùng (trong Authorization Code flow) hoặc không có (trong Client Credentials flow).
>
> **Tại sao có nhiều "flows" (grant types)?**
> Bởi vì các tình huống khác nhau có nhu cầu khác nhau:
> - **Authorization Code + PKCE:** Người dùng thực sự đăng nhập qua browser → cần redirect → cần PKCE để bảo vệ khỏi authorization code interception attack.
> - **Client Credentials:** Service tự động gọi service, không có người dùng → không cần redirect → chỉ cần client_id + secret.
> - **Device Code:** Thiết bị không có browser (IoT, CLI tools) → người dùng đăng nhập trên thiết bị khác.
> - **Implicit (DEPRECATED):** Tokens trả thẳng về browser URL — không an toàn. KHÔNG BAO GIỜ dùng.
>
> **FinSecure dùng:**
> - **Authorization Code + PKCE** cho Internal Dashboard (user login).
> - **Client Credentials** cho Partner API (service-to-service).
> - **Managed Identity token flow** (built on Client Credentials) cho ADF, Databricks.

### Bước 1: Authorization Code Flow — User Login

> **Purpose:** Flow dành cho tình huống người dùng thực sự đăng nhập qua browser vào FinSecure Internal Dashboard.
> **Security Implication:** PKCE (Proof Key for Code Exchange) bảo vệ khỏi authorization code interception attack — kẻ tấn công sniff được auth code nhưng không có code_verifier nên không thể đổi lấy token.

```
[User] → Click "Login with Microsoft"
    ↓
[Browser] → GET https://login.microsoftonline.com/{tenant}/oauth2/v2.0/authorize
             ?client_id=<dashboard-app-id>
             &response_type=code
             &redirect_uri=https://dashboard.finsecure.com/callback
             &scope=openid profile email data.read
             &code_challenge=<SHA256-of-verifier>          ← PKCE protection
             &code_challenge_method=S256
             &state=<random-csrf-token>
    ↓
[Entra ID] → User nhập credentials + MFA
    ↓
[Entra ID] → Redirect: https://dashboard.finsecure.com/callback?code=<auth_code>&state=<state>
    ↓
[Backend] → Verify state (CSRF check) → POST /token với code + code_verifier
    ↓
[Entra ID] → { access_token, id_token, refresh_token, expires_in: 3600 }
    ↓
[Dashboard] → Dùng access_token gọi API, id_token hiển thị tên user
```

### Bước 2: Client Credentials Flow — Service-to-Service

> **Purpose:** Flow dành cho partner service gọi FinSecure API mà không có người dùng nào tham gia.
> **Security Implication:** Không có người dùng = không có consent screen = Admin phải cấp consent tập trung trước (admin consent). Scope phải kết thúc bằng `/.default` để yêu cầu tất cả permissions đã được admin approve.

```
[Partner Service] → POST https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token
                    grant_type=client_credentials
                    &client_id=<partner-client-id>
                    &client_secret=<partner-secret>
                    &scope=api://<finsecure-api-id>/.default
    ↓
[Entra ID] → Kiểm tra: Client hợp lệ? Secret đúng? Admin đã consent chưa?
    ↓
[Entra ID] → { access_token, expires_in: 3600, token_type: "Bearer" }
    ↓
[Partner] → GET https://api.finsecure.com/v1/data
            Authorization: Bearer <access_token>
    ↓
[FinSecure API] → Validate JWT (signature, expiry, audience, roles) → 200 OK + data
```

### Bước 3: Inspect JWT Token với jwt.ms

> **Purpose:** Hiểu cấu trúc bên trong Access Token — nơi chứa danh tính, quyền hạn, và thời hạn.
> **Security Implication:** JWT là **self-contained** — API không cần gọi Entra ID mỗi request để xác thực (chỉ verify chữ ký bằng public key từ JWKS endpoint). Điều này có nghĩa: token bị compromise vẫn valid đến khi hết hạn — **không thể revoke ngay lập tức**. Đây là trade-off giữa performance và revocation speed. Giải pháp: đặt expiry ngắn (15-30 phút cho sensitive APIs) hoặc dùng token introspection/revocation endpoint.

Dán Access Token vào [jwt.ms](https://jwt.ms). Payload điển hình:

```json
{
  "aud": "api://finsecure-partner-api-id",
  "iss": "https://login.microsoftonline.com/{tenant-id}/v2.0",
  "iat": 1716470400,
  "exp": 1716474000,
  "appid": "partner-client-id",
  "appidacr": "1",
  "roles": ["DataReader"],
  "tid": "{tenant-id}",
  "oid": "{object-id-of-service-principal}",
  "azp": "{authorized-party-client-id}"
}
```

**Giải thích claims quan trọng:** `aud` (Audience — API phải reject token không đúng audience), `iss` (Issuer — phải là đúng tenant để tránh cross-tenant attacks), `exp` (Unix timestamp hết hạn), `roles` (App Roles — API dùng để phân quyền), `tid` (Tenant ID — critical cho multi-tenant defense).

---

## Phase 6: RBAC at Scale — Phân quyền Tài nguyên Azure

> **🧠 Kiến thức nền tảng — Scope Hierarchy và Quyền Kế thừa**
>
> Azure RBAC hoạt động theo cấu trúc phân cấp 4 tầng. Quyền gán ở tầng cao hơn **tự động kế thừa** xuống mọi tầng con:
> ```
> Management Group (FinSecure-Root)     ← Gán đây = ảnh hưởng TẤT CẢ bên dưới
>   └── Subscription: finsecure-prod
>         └── Resource Group: rg-data-prod
>               └── Resource: stfinsecurelake001   ← Gán đây = hẹp nhất
> ```
>
> **Nguyên tắc vàng:** Luôn gán quyền ở **scope hẹp nhất có thể**. Nếu Data Analyst chỉ cần đọc 1 Storage Account — gán quyền trên Storage Account đó, không phải trên Resource Group (sẽ cho phép đọc mọi resource trong group).
>
> **Hệ quả của scope quá rộng:** Developer được cấp `Contributor` trên Subscription "để tiện" → họ có thể xóa database production, tạo VM mới, thay đổi network configuration. Đây là nguồn gốc của phần lớn incidents nội bộ.

### Bước 1: RBAC Assignments cho FinSecure Data Platform

> **Purpose:** Gán roles phù hợp cho từng group theo nguyên tắc Least Privilege.
> **Security Implication:** Audit RBAC assignments định kỳ mỗi quý. Nhân viên chuyển bộ phận, role assignments cũ không tự mất — phải có process review chủ động.

**Ma trận RBAC của FinSecure:**

| Group | Resource | Role | Phạm vi (Scope) |
|-------|----------|------|-----------------|
| `sg-data-engineers` | ADLS Gen2 | Storage Blob Data Contributor | Storage Account level |
| `sg-data-engineers` | ADF | Data Factory Contributor | Resource Group level |
| `sg-data-analysts` | ADLS Gen2 | Storage Blob Data Reader | Container `gold-analytics` only |
| `sg-data-scientists` | Azure ML | AzureML Data Scientist | ML Workspace level |
| `sg-external-partners` | (Không cấp trực tiếp Azure RBAC) | — | Chỉ qua API Management |

**Thực hành — Gán Reader cho Data Analysts trên Gold Container:**
```bash
# Gán Storage Blob Data Reader ở mức Container cụ thể (hẹp nhất có thể)
az role assignment create \
  --role "Storage Blob Data Reader" \
  --assignee-object-id <sg-data-analysts-group-object-id> \
  --assignee-principal-type Group \
  --scope "/subscriptions/{sub-id}/resourceGroups/rg-finsecure-data-dev\
/providers/Microsoft.Storage/storageAccounts/stfinsecurelake001\
/blobServices/default/containers/gold-analytics"
```

### Bước 2: Custom Role — Khi Built-in Roles Quá Rộng

> **Purpose:** Tạo custom role khi built-in roles không khớp chính xác với yêu cầu Least Privilege.
> **Security Implication:** Custom roles tăng overhead quản lý. Chỉ tạo khi thực sự cần thiết. Document rõ lý do tạo, ai phê duyệt, và review schedule.

```json
{
  "Name": "FinSecure Data Scientist Reader",
  "Description": "Read Gold layer data and view storage metadata. No write permissions.",
  "Actions": [
    "Microsoft.Storage/storageAccounts/read",
    "Microsoft.Storage/storageAccounts/blobServices/containers/read"
  ],
  "DataActions": [
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"
  ],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/{subscription-id}/resourceGroups/rg-finsecure-data-dev"
  ]
}
```

```bash
az role definition create --role-definition custom-role-ds-reader.json
```

---

## Phase 7: Conditional Access — Zero Trust Enforcement Layer

> **🧠 Kiến thức nền tảng — Tại sao Password + MFA chưa đủ? Cần Conditional Access?**
>
> Hãy xem xét tình huống: Alice (Data Engineer) bị hack laptop, attacker chiếm được Entra ID session cookie sau khi Alice đã đăng nhập và vượt qua MFA. Attacker dùng cookie này để truy cập Data Platform từ server ở Romania lúc 3 giờ sáng.
>
> Với **chỉ MFA:** Attacker vẫn vào được — vì session đã được thiết lập, MFA đã được vượt qua trước đó.
>
> Với **Conditional Access:** Policy phát hiện: truy cập từ Romania (không phải trusted location), lúc 3 giờ sáng (anomalous time), từ thiết bị không phải Intune-enrolled (không compliant). → **Block access + Alert SOC team**.
>
> Conditional Access là lớp bảo vệ thứ ba sau Password và MFA. Nó đánh giá **context** của mỗi authentication attempt — không chỉ "biết mật khẩu" mà còn "đúng người, đúng thiết bị, đúng nơi, đúng lúc". Đây là bản chất của Zero Trust.

### Bước 1: Policy — Bắt buộc MFA cho Data Platform

> **Purpose:** Mọi user trong Data Platform phải MFA, mọi lúc, bất kể đang ở đâu.
> **Security Implication:** Test policy ở **Report-only** mode trước khi bật để tránh tự lock-out. Luôn có ít nhất 1 "emergency access account" (break-glass account) được exempt khỏi Conditional Access.

1. Entra ID → **Security** → **Conditional Access** → **+ New policy**.
2. **Name:** `CA-FinSecure-DataPlatform-RequireMFA`
3. **Users:** Include `sg-finsecure-data-platform-all`.
4. **Target resources:** Chọn App `finsecure-partner-api` (+ Internal Dashboard app).
5. **Grant:** `Require multifactor authentication`.
6. **Enable policy:** `Report-only` → Test → Sau khi verify: `On`.

### Bước 2: Location-based Policy

> **Purpose:** Chặn hoặc tăng yêu cầu bảo mật cho truy cập từ địa lý không mong đợi.
> **Security Implication:** Location check dựa trên IP — có thể bypass bằng VPN hoặc proxy. Không dùng location làm yếu tố bảo mật DUY NHẤT. Kết hợp với MFA và device compliance để tạo defense in depth.

```
Tạo Named Location "FinSecure-TrustedOffices":
  - Vietnam office IPs: 203.162.x.x/24
  - Singapore office IPs: 103.28.x.x/24
  - Mark as: Trusted location

Policy "CA-FinSecure-BlockHighRiskLocations":
  - Users: sg-finsecure-data-engineers
  - Include: Any location
  - Exclude: FinSecure-TrustedOffices
  - Grant: Block access
```

### Bước 3: Device Compliance Policy

> **Purpose:** Chỉ thiết bị được quản lý bởi Intune (antivirus up-to-date, disk encrypted, OS patched) mới truy cập Data Platform.
> **Security Implication:** Device compliance tạo "dual verification" — cả người dùng lẫn thiết bị đều được verified. Ngay cả khi credentials bị đánh cắp và chạy trên máy ảo không compliant, access vẫn bị block.

```
Policy "CA-FinSecure-RequireCompliantDevice":
  - Users: sg-finsecure-data-engineers, sg-finsecure-data-scientists
  - Conditions: Filter for devices: device.isCompliant -eq True
  - Grant: Require device to be marked as compliant
```

---

## Phase 8: Audit & Monitoring — Không Một Lần Truy cập Nào Bị Bỏ Qua

### Bước 1: Tạo Log Analytics Workspace và Export Entra ID Logs

> **Purpose:** Xuất Entra ID logs sang Log Analytics để lưu trữ lâu dài và query với KQL.
> **Security Implication:** Entra ID logs mặc định chỉ lưu 30 ngày. Tuân thủ PCI-DSS yêu cầu lưu 12 tháng, ISO 27001 yêu cầu lưu 3 năm. Export logs là yêu cầu bắt buộc, không phải optional.

1. Tạo **Log Analytics workspace:** `law-finsecure-security-001` trong `rg-finsecure-security`.
2. Entra ID → **Monitoring** → **Diagnostic settings** → **+ Add diagnostic setting**.
3. **Name:** `ds-entra-to-law-finsecure`
4. Chọn: ✅ AuditLogs ✅ SignInLogs ✅ NonInteractiveUserSignInLogs ✅ ServicePrincipalSignInLogs ✅ RiskyUsers.
5. **Destination:** Send to Log Analytics workspace → chọn `law-finsecure-security-001`.
6. **Save**.

### Bước 2: KQL Security Queries

> **Purpose:** Viết queries để phát hiện threats và tạo security dashboards.
> **Security Implication:** Reactive monitoring (phân tích sau khi incident xảy ra) không đủ cho fintech. Cần **proactive detection** bằng scheduled KQL queries với alerts gửi về Microsoft Sentinel hoặc email của SOC team.

```kql
// Detect Brute Force — >10 failed logins trong 1 giờ từ cùng IP
SigninLogs
| where TimeGenerated > ago(1h)
| where ResultType != "0"
| summarize FailedAttempts = count() by IPAddress, bin(TimeGenerated, 1h)
| where FailedAttempts > 10
| project TimeGenerated, IPAddress, FailedAttempts
| order by FailedAttempts desc

// Service Principal activity — Managed Identities gọi gì?
AADServicePrincipalSignInLogs
| where TimeGenerated > ago(24h)
| project TimeGenerated, ServicePrincipalName, ResourceDisplayName, ResultType, IPAddress
| where ResultType != "0"  // Chỉ failures — thường là misconfiguration hoặc attack
| order by TimeGenerated desc

// Thay đổi Group Membership — Ai thêm ai vào group nào?
AuditLogs
| where TimeGenerated > ago(7d)
| where OperationName in ("Add member to group", "Remove member from group")
| extend TargetGroup = tostring(TargetResources[0].displayName)
| extend AffectedUser = tostring(TargetResources[1].userPrincipalName)
| extend ChangedBy = tostring(InitiatedBy.user.userPrincipalName)
| project TimeGenerated, OperationName, ChangedBy, AffectedUser, TargetGroup
| order by TimeGenerated desc

// Sign-ins từ quốc gia không mong đợi (chỉ successful logins)
SigninLogs
| where TimeGenerated > ago(24h)
| where ResultType == "0"
| where Location !in ("VN", "SG")
| project TimeGenerated, UserPrincipalName, Location, IPAddress, AppDisplayName
| order by TimeGenerated desc
```

---

## Phase 9: Python Code — OAuth 2.0 Client Credentials với MSAL

### Production-Quality Authentication Client

> **Purpose:** Code production-grade với MSAL xử lý token caching, refresh, retry và audit logging.
> **Security Implication:** Token caching tránh throttling từ Entra ID (rate limit: 200 token requests/minute). Credentials lấy từ Key Vault qua DefaultAzureCredential — dùng Managed Identity trong Azure, Azure CLI khi develop local — không hardcode gì cả.

```python
# finsecure_auth_client.py
"""
Production OAuth 2.0 Client Credentials client cho FinSecure Partner API.
Features: Key Vault credential injection, MSAL token caching,
          exponential backoff retry, structured audit logging.
"""

import logging
import time
import uuid
import json
from typing import Optional

import msal
import requests
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s"
)
logger = logging.getLogger("FinSecure.AuthClient")


class KeyVaultCredentialProvider:
    """Lấy credentials từ Azure Key Vault — không bao giờ hardcode."""

    def __init__(self, vault_url: str):
        # DefaultAzureCredential: Managed Identity trong Azure,
        # Azure CLI / VS Code khi develop local — zero config.
        credential = DefaultAzureCredential()
        self._client = SecretClient(vault_url=vault_url, credential=credential)
        self._cache: dict = {}

    def get_secret(self, name: str) -> str:
        if name not in self._cache:
            logger.info(f"Fetching secret '{name}' from Key Vault...")
            self._cache[name] = self._client.get_secret(name).value
        return self._cache[name]


class FinSecureAPIClient:
    """
    Client xác thực OAuth 2.0 Client Credentials với MSAL.
    Token được cache tự động — Entra ID chỉ bị gọi khi token hết hạn.
    """

    def __init__(
        self,
        tenant_id: str,
        key_vault_url: str,
        client_id_secret_name: str,
        client_secret_secret_name: str,
        api_scope: str,
        api_base_url: str,
        max_retries: int = 3,
    ):
        self.api_scope = api_scope
        self.api_base_url = api_base_url.rstrip("/")
        self.max_retries = max_retries

        kv = KeyVaultCredentialProvider(key_vault_url)
        client_id = kv.get_secret(client_id_secret_name)
        client_secret = kv.get_secret(client_secret_secret_name)

        # MSAL ConfidentialClientApplication: thread-safe, với built-in token cache.
        # Gọi acquire_token_silent() → trả cache hit nếu token còn hạn.
        # Gọi acquire_token_for_client() → fetch từ Entra ID nếu cache miss/expired.
        self._msal_app = msal.ConfidentialClientApplication(
            client_id=client_id,
            client_credential=client_secret,
            authority=f"https://login.microsoftonline.com/{tenant_id}",
        )
        logger.info(f"FinSecureAPIClient initialized. Scope: {api_scope}")

    def _get_token(self) -> str:
        # Thử cache trước — không tốn network call nếu token còn hợp lệ
        result = self._msal_app.acquire_token_silent(
            scopes=[self.api_scope], account=None
        )
        if not result:
            logger.info("Token cache miss — fetching from Entra ID...")
            result = self._msal_app.acquire_token_for_client(
                scopes=[self.api_scope]
            )
        if "error" in result:
            raise RuntimeError(
                f"Token error: {result['error']} — {result.get('error_description')}"
            )
        logger.info(f"Token valid. Expires in: {result.get('expires_in')}s")
        return result["access_token"]

    def _request(self, method: str, endpoint: str, **kwargs) -> requests.Response:
        """HTTP request với retry exponential backoff."""
        url = f"{self.api_base_url}/{endpoint.lstrip('/')}"
        for attempt in range(1, self.max_retries + 1):
            try:
                token = self._get_token()
                headers = {
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                    "X-Request-Id": str(uuid.uuid4()),
                }
                logger.info(f"[{attempt}/{self.max_retries}] {method.upper()} {url}")
                resp = requests.request(
                    method, url, headers=headers, timeout=30, **kwargs
                )
                # Retry on 429 (rate limit) và 5xx (server errors)
                if resp.status_code == 429 or resp.status_code >= 500:
                    wait = float(resp.headers.get("Retry-After", 2 ** (attempt - 1)))
                    if attempt < self.max_retries:
                        logger.warning(f"HTTP {resp.status_code}. Retrying in {wait}s...")
                        time.sleep(wait)
                        continue
                resp.raise_for_status()
                return resp
            except requests.ConnectionError as e:
                if attempt < self.max_retries:
                    time.sleep(2 ** (attempt - 1))
                else:
                    raise
        raise RuntimeError(f"Exhausted {self.max_retries} retries for {url}")

    def get_data(self, dataset: str, params: Optional[dict] = None) -> dict:
        return self._request("GET", f"/data/{dataset}", params=params or {}).json()

    def generate_report(self, report_type: str, date_from: str, date_to: str) -> dict:
        return self._request("POST", "/reports/generate", json={
            "report_type": report_type,
            "date_range": {"from": date_from, "to": date_to},
        }).json()


# ─── Demo Usage ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import os
    client = FinSecureAPIClient(
        tenant_id=os.environ["AZURE_TENANT_ID"],
        key_vault_url=os.environ["KEY_VAULT_URL"],
        client_id_secret_name="finsecure-partner-client-id",
        client_secret_secret_name="finsecure-partner-client-secret",
        api_scope="api://finsecure-partner-api-id/.default",
        api_base_url="https://api.finsecure.com/v1",
    )

    # Gọi 1: Token được fetch từ Entra ID
    data = client.get_data("transactions", params={"limit": 100})
    print(f"Transactions: {json.dumps(data, indent=2)}")

    # Gọi 2: Token lấy từ cache (Entra ID KHÔNG bị gọi lần 2)
    accounts = client.get_data("accounts")
    print(f"Accounts (cached token): {json.dumps(accounts, indent=2)}")

    # Gọi 3: Tạo report (cần App Role: ReportGenerator)
    report = client.generate_report("monthly_summary", "2024-01-01", "2024-01-31")
    print(f"Report: {json.dumps(report, indent=2)}")
```

---

## Phase 10: End-to-End Testing & Cleanup

### Bước 1: E2E Test Checklist

> **Purpose:** Validate toàn bộ kiến trúc Zero Trust từ đầu đến cuối trước khi go-live.
> **Security Implication:** Mỗi test PHẢI bao gồm cả negative test (unauthorized access bị từ chối đúng cách). Chỉ test happy path là không đủ — attacker sẽ test negative paths.

**Test 1 — Managed Identity (ADF → Key Vault):**
- ADF test connection đến SQL Database thành công mà không cần password trong config.
- Expected: ✅ Connection Succeeded.

**Test 2 — RBAC Least Privilege (Data Analyst chỉ đọc được, không xóa được):**
```bash
# Login tài khoản thuộc sg-data-analysts
az storage blob list --account-name stfinsecurelake001 \
  --container-name gold-analytics --auth-mode login
# Expected: ✅ SUCCESS — thấy danh sách files

az storage blob delete --account-name stfinsecurelake001 \
  --container-name gold-analytics --name report.parquet --auth-mode login
# Expected: ❌ AuthorizationPermissionMismatch — Least Privilege đang hoạt động!
```

**Test 3 — OAuth 2.0 Partner Auth:**
```bash
# Lấy valid token
TOKEN=$(curl -s -X POST \
  "https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token" \
  -d "grant_type=client_credentials&client_id=${PARTNER_CLIENT_ID}\
&client_secret=${PARTNER_SECRET}&scope=api://${API_ID}/.default" \
  | jq -r '.access_token')

curl -H "Authorization: Bearer $TOKEN" \
  "https://api.finsecure.com/v1/data/transactions"
# Expected: ✅ 200 OK với data

curl -H "Authorization: Bearer invalid_token_12345" \
  "https://api.finsecure.com/v1/data/transactions"
# Expected: ❌ 401 Unauthorized
```

**Test 4 — Conditional Access MFA:**
- Đăng nhập user thuộc `sg-finsecure-data-platform-all`.
- Expected: ✅ MFA prompt xuất hiện sau password.
- Verify: Entra ID → Sign-in Logs → CA policy status = "Success".

**Test 5 — Audit Trail trong Log Analytics:**
```kql
SigninLogs
| where TimeGenerated > ago(1h)
| where UserPrincipalName contains "finsecure"
| project TimeGenerated, UserPrincipalName, AppDisplayName,
          ResultType, ConditionalAccessStatus
// Expected: Thấy entries từ tất cả tests trên
```

### Bước 2: Production Readiness Checklist

> **Security Implication:** Một checklist hệ thống hóa ngăn "checklist blindness". Mỗi mục phải được verify độc lập, không chỉ "assume là đúng".

```
□ Không có Client Secret nào hardcode trong code, config, hay git history
□ Tất cả Client Secrets trong Key Vault với expiry date và rotation plan
□ ADF và Databricks dùng Managed Identity — không dùng Service Principal
□ RBAC được gán cho Groups — không gán trực tiếp cho Individual Users
□ Conditional Access policies đang ở chế độ "On" (không phải Report-only)
□ Entra ID logs đang chảy sang Log Analytics (verify bằng KQL query)
□ Log retention ≥ 365 ngày (tuân thủ PCI-DSS)
□ MFA enabled cho tất cả users truy cập Data Platform
□ Emergency "break-glass" account được tạo và exempt khỏi Conditional Access
□ Custom RBAC roles đã được review để tránh privilege escalation paths
□ App Registrations không có unnecessary API permissions (review "Granted permissions")
□ Dynamic Group rules được document và review bởi IAM team
□ RBAC review schedule hàng quý đã được đặt lịch (Access Review feature)
```

### Bước 3: Dọn dẹp Tài nguyên

> **Purpose:** Xóa tất cả tài nguyên sau Lab để ngừng phát sinh chi phí.
> **Security Implication:** "Zombie resources" — tài nguyên bị bỏ quên — là rủi ro bảo mật thực sự. App Registrations với valid secrets còn sống nhưng không ai theo dõi có thể bị khai thác bởi insider threats. Cleanup ngay sau khi không cần.

```bash
# Bước 1: Xóa Azure Resources
az group delete --name rg-finsecure-data-dev --yes --no-wait
az group delete --name rg-finsecure-security --yes --no-wait

# Bước 2: Xóa Entra ID Objects (phải làm thủ công — không bị kéo theo Resource Group)
az ad app delete --id <finsecure-partner-api-app-id>
az ad group delete --group sg-finsecure-data-engineers
az ad group delete --group sg-finsecure-data-analysts
az ad group delete --group sg-finsecure-data-scientists
az role definition delete --name "FinSecure Data Scientist Reader"

# Bước 3: Xóa Conditional Access Policies (qua Portal)
# Entra ID > Security > Conditional Access > Chọn từng policy CA-FinSecure-* > Delete
```

---

## Tóm tắt Kiến trúc Zero Trust Hoàn chỉnh của FinSecure

Sau khi hoàn thành 10 phases, FinSecure đã xây dựng một hệ thống bảo mật cấp enterprise theo mô hình Zero Trust:

```
             FinSecure Zero Trust Architecture — Full Picture
┌─────────────────────────────────────────────────────────────────┐
│                    ENTRA ID TENANT                              │
│                                                                 │
│  ┌──────────────────┐  ┌─────────────────┐  ┌───────────────┐  │
│  │  Users & Groups  │  │ App Registrations│  │Managed Identity│  │
│  │  (Dynamic Rules) │  │ (OAuth 2.0 Scopes│  │(ADF, ADB —   │  │
│  │  Nested Hierarchy│  │  App Roles, JWT) │  │ No Passwords) │  │
│  └────────┬─────────┘  └────────┬────────┘  └───────┬───────┘  │
│           │                     │                    │          │
│  ┌────────▼─────────────────────▼────────────────────▼────────┐ │
│  │              Conditional Access Policies                    │ │
│  │   MFA Required │ Trusted Locations │ Device Compliant Only  │ │
│  │           "Never Trust, Always Verify"                      │ │
│  └──────────────────────────┬──────────────────────────────────┘ │
└─────────────────────────────│──────────────────────────────────┘
                              │ Verified Identity + Context
          ┌───────────────────▼──────────────────────┐
          │               Azure RBAC                  │
          │  Least Privilege │ Group-based │ Scoped    │
          │  Custom Roles  │ Deny Assignments          │
          └──────────┬──────────────────┬─────────────┘
                     │                  │
         ┌───────────▼────────┐  ┌──────▼──────────────┐
         │   Data Platform    │  │    Azure Key Vault   │
         │   ADLS Gen2        │  │   (All Secrets —     │
         │   ADF + Databricks │  │    No Hardcoding)    │
         └────────────────────┘  └─────────────────────┘
                     │
         ┌───────────▼──────────────────────┐
         │       Log Analytics Workspace    │
         │  Sign-in Logs │ Audit Logs       │
         │  KQL Alerts │ Sentinel SIEM      │
         │  365-day Retention (PCI-DSS)     │
         └──────────────────────────────────┘
```

**Bạn đã xây dựng thành công:**
1. ✅ **Tenant & Identity Hierarchy** — Users, Dynamic Groups, nested structure
2. ✅ **App Registration** — OAuth 2.0 Scopes, App Roles, Single-tenant
3. ✅ **Managed Identity** — Zero-credential authentication cho ADF và Databricks
4. ✅ **OAuth 2.0 Flows** — Authorization Code (user login) + Client Credentials (service-to-service)
5. ✅ **RBAC at Scale** — Group-based, Least Privilege, Custom Roles
6. ✅ **Conditional Access** — MFA + Location + Device Compliance
7. ✅ **Audit & Monitoring** — KQL queries, Log Analytics, security alerts
8. ✅ **Production Python Code** — MSAL với token caching, retry, Key Vault integration

Đây không chỉ là một Lab kỹ thuật — đây là kiến trúc bảo mật thực tế mà các tổ chức tài chính lớn triển khai để tuân thủ PCI-DSS, ISO 27001, và Zero Trust mandates từ các cơ quan quản lý.
