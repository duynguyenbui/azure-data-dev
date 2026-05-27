# Hướng dẫn Lab 11: Enterprise Intelligent Search & RAG Pipeline: Azure AI Search + Azure OpenAI

Chào mừng bạn đến với Lab thực hành chuyên sâu về **Azure AI Search** và **Retrieval-Augmented Generation (RAG)**. Đây không phải là lab "chỉ làm theo bước" thông thường — tài liệu này được thiết kế như một **giáo trình kết hợp với lab thực hành**: bạn sẽ vừa biết *làm gì*, vừa thực sự *hiểu tại sao* và *điều gì xảy ra nếu làm khác đi*.

---

## Kịch bản Nghiệp vụ (The Business Scenario)

Công ty luật **LexCorp Vietnam** đang quản lý hơn **50.000 tài liệu pháp lý nội bộ** bao gồm: hợp đồng (contracts), hồ sơ vụ kiện (case files), và bản án tòa án (court rulings) — được lưu trữ hỗn hợp ở các định dạng PDF và DOCX trên Azure Blob Storage.

**Vấn đề cốt lõi trước khi có giải pháp:**
- Luật sư mất **2–4 giờ** để tìm kiếm thủ công các điều khoản liên quan trong hàng nghìn tài liệu.
- Tìm kiếm từ khóa (`CTRL+F` hoặc SQL `LIKE '%bồi thường%'`) bỏ sót tài liệu dùng từ ngữ khác nhưng nghĩa tương đồng ("compensation" vs "indemnification" vs "damages").
- PDF bị scan (ảnh chụp) hoàn toàn không thể tìm kiếm vì không có text.
- Không có khả năng tổng hợp nội dung từ nhiều tài liệu để trả lời một câu hỏi tổng quát.

**Giải pháp chúng ta sẽ xây dựng — theo thứ tự từ đơn giản đến phức tạp:**

| Thế hệ | Công nghệ | Khả năng | Vấn đề còn lại |
|--------|-----------|----------|----------------|
| Gen 1 | SQL `LIKE`, Full-text Search | Tìm từ khóa chính xác | Bỏ sót từ đồng nghĩa, PDF scan |
| Gen 2 | Azure AI Search + Skillsets | OCR + Entity Extraction + BM25 | Vẫn keyword-based, không hiểu ngữ nghĩa |
| Gen 3 | **Hybrid Search + Semantic Ranking** | Hiểu ngữ nghĩa, reranking bằng AI | Chỉ trả về đoạn text, không tổng hợp |
| **Gen 4** | **RAG Pipeline (AI Search + GPT-4o)** | **Tổng hợp câu trả lời + trích dẫn nguồn** | ✅ **Giải pháp mục tiêu** |

---

## Kiến trúc Tổng quan (Solution Architecture)

```
[50,000+ PDF/DOCX Documents]
       │
       ▼
[Azure Blob Storage]  ← Nguồn dữ liệu gốc
       │
       ▼ (Indexer kéo tài liệu về)
[Azure AI Search Indexer]
       │  "Document Cracking"
       ▼  (mở file, trích text)
[AI Enrichment Pipeline / Skillset]
  ├── OCR Skill          → Text từ ảnh PDF scan
  ├── Merge Skill        → Gộp text gốc + OCR text
  ├── Split Skill        → Chunking: chia đoạn 2000 ký tự
  ├── Key Phrase Skill   → Từ khóa pháp lý quan trọng
  ├── Entity Recognition → Tên Người / Tổ chức / Địa điểm
  ├── Embedding Skill    → Vector 1536D (text-embedding-ada-002)
  └── Custom Skill       → Phân loại điều khoản (Azure Function)
       │
       ▼
[Azure AI Search Index]
  ├── Inverted Index     → Full-text BM25 search (tiếng Việt)
  ├── HNSW Vector Index  → Approximate Nearest Neighbor search
  ├── Facet Indexes      → Bộ lọc: loại tài liệu, năm, tổ chức
  └── Semantic Config    → L2 Reranker configuration
       │
       ▼
[RAG Query Pipeline - Python]
  1. User query → text-embedding-ada-002 → vector
  2. Hybrid Search (BM25 + Vector) → top-50 candidates
  3. Semantic Reranker (L2) → top-5 most relevant chunks
  4. Build prompt (query + context chunks)
  5. GPT-4o → synthesized answer with citations
       │
       ▼
[LexCorp Lawyer Portal]
"Điều khoản bồi thường... dựa trên Hợp đồng HĐ-2023-045, Điều 8.2"
```

---

## Phase 1: Thiết lập Hạ tầng Enterprise

### Bước 1: Tạo Resource Group

> **Mục đích:** Resource Group là "thư mục" chứa toàn bộ tài nguyên Azure của dự án. Khi kết thúc Lab, chỉ cần xóa một Resource Group là toàn bộ tài nguyên con bị xóa theo — không bao giờ để lại "rác" tốn phí trên cloud.

1. Đăng nhập [portal.azure.com](https://portal.azure.com).
2. Tìm **Resource groups** → **+ Create**.
3. Điền thông tin:
   - **Resource group:** `rg-lexcorp-search-001`
   - **Region:** `Southeast Asia` (hoặc `East US 2`).
4. Nhấn **Review + create** → **Create**.

### Bước 2: Tạo Azure Blob Storage (Kho Tài liệu)

> **Mục đích:** Blob Storage là nơi lưu trữ toàn bộ 50.000+ tài liệu gốc. Azure AI Search Indexer sẽ đọc trực tiếp từ đây để xử lý và index nội dung.

1. Tìm **Storage accounts** → **+ Create**.
2. Điền thông tin:
   - **Storage account name:** `stlexcorpdocs001` *(chỉ chữ thường và số)*
   - **Region:** Cùng region.
   - **Redundancy:** **LRS** (cho Lab). *(Production: GRS để Disaster Recovery).*
3. Nhấn **Review + create** → **Create**.

**Tạo Container lưu tài liệu:**
- Vào **Containers** → **+ Container**.
- **Name:** `legal-documents` | **Public access:** Private.
- Upload ít nhất 3–5 file PDF/DOCX pháp lý mẫu để Lab có dữ liệu thực tế.

### Bước 3: Chọn Tier cho Azure AI Search

> **🧠 Kiến thức nền tảng — Azure AI Search là gì và tại sao không dùng Elasticsearch hay SQL?**
>
> Trước khi tạo resource, bạn cần hiểu *tại sao chúng ta chọn Azure AI Search* thay vì các lựa chọn phổ biến khác:
>
> **SQL `LIKE` Query** (`WHERE content LIKE '%bồi thường%'`): Cách đơn giản nhất, nhưng hoàn toàn dựa trên khớp ký tự chính xác. Không tìm được "compensation" khi người dùng hỏi "bồi thường". Không thể tìm trong PDF. Không có ranking theo độ liên quan. Với 50.000 tài liệu, query sẽ scan toàn bộ bảng — cực kỳ chậm.
>
> **Elasticsearch / OpenSearch**: Là search engine mã nguồn mở rất mạnh, dùng inverted index và BM25 tương tự Azure AI Search. Tuy nhiên, để dùng trong Azure enterprise: phải tự quản lý cluster (scaling, patching, backup), không tích hợp native với Azure Active Directory, phải tự implement AI enrichment pipeline, vector search cần plugin riêng. Chi phí vận hành cao hơn nhiều khi tính cả DevOps.
>
> **Azure AI Search**: Managed service — Microsoft lo toàn bộ infrastructure. Tích hợp native với Azure Blob Storage, Azure OpenAI, Azure AI Services. Có sẵn: BM25, Vector Search (HNSW), Semantic Ranking (L2 reranker), AI Enrichment Skillsets, Managed Identity. Đây là lý do nó là lựa chọn mặc định cho RAG pipeline trên Azure.
>
> **Khi nào KHÔNG dùng Azure AI Search**: (1) Dữ liệu structured hoàn toàn trong SQL và chỉ cần exact match → dùng SQL. (2) Log analytics với volume PB/ngày → dùng Azure Data Explorer. (3) Cần full control infrastructure và team DevOps mạnh → Elasticsearch. (4) Dữ liệu vector thuần túy, không cần text search → Azure Cosmos DB for NoSQL với Vector Index.

> **Mục đích:** Việc chọn đúng tier ngay từ đầu rất quan trọng vì bạn **KHÔNG thể nâng/hạ tier sau khi đã tạo** — phải xóa và tạo lại toàn bộ index. Phân tích tier cho LexCorp:

| Tier | Index Size | Semantic Search | Vector Search | Chi phí/tháng | Khi nào chọn |
|------|-----------|-----------------|---------------|---------------|--------------|
| **Free** | 50MB | ❌ | ❌ | $0 | Prototype cá nhân |
| **Basic** | 2GB, 15 indexes | ✅ (1000 req/mo) | ✅ | ~$75 | **Lab này / Dev** |
| **Standard S1** | 25GB, 50 indexes | ✅ unlimited | ✅ | ~$250 | Production LexCorp |
| **Standard S2** | 100GB | ✅ | ✅ | ~$1,000 | Large law firm |
| **Storage Optimized L1** | 2TB | ✅ | ✅ | ~$2,900 | Archive compliance |

1. Tìm **AI Search** → **+ Create**.
2. Điền thông tin:
   - **Service name:** `srch-lexcorp-001` *(tên duy nhất toàn cầu)*
   - **Location:** Cùng region.
   - **Pricing tier:** **Basic** cho Lab, **Standard S1** cho Production.
3. Nhấn **Review + create** → **Create**.

### Bước 4: Tạo Azure AI Services Multi-Service Account

> **Mục đích:** Azure AI Services là "trung tâm AI" cung cấp các cognitive skills cho AI Enrichment Pipeline. Một tài khoản **Multi-Service** duy nhất cấp quyền truy cập tất cả API: OCR, Named Entity Recognition, Key Phrase Extraction, Language Detection — thay vì phải tạo từng dịch vụ riêng lẻ.

> **🧠 Kiến thức nền tảng — Nếu bỏ qua AI Enrichment Skillset thì sao?**
>
> Đây là câu hỏi quan trọng nhất để hiểu giá trị của Phase 4. Hãy tưởng tượng không có Skillset: Azure AI Search vẫn có thể index tài liệu, nhưng nó chỉ lưu raw text thuần túy. Với tài liệu pháp lý của LexCorp:
>
> - **PDF bị scan (ảnh)**: Hoàn toàn không extract được text → index rỗng → tài liệu như không tồn tại với search engine.
> - **Không có entity extraction**: Luật sư không thể lọc "Tìm tất cả hợp đồng có liên quan đến Công ty TNHH ABC" vì trường `entities_organizations` không tồn tại.
> - **Không có chunking**: Cả tài liệu 50 trang được coi là một đơn vị → khi search trả về kết quả, luật sư phải đọc toàn bộ 50 trang để tìm đoạn liên quan → RAG context sẽ vượt quá token limit của GPT-4o.
> - **Không có vector embedding**: Không có Vector Search → chỉ có keyword matching → bỏ sót 40-60% tài liệu liên quan theo nghiên cứu thực nghiệm.
>
> AI Enrichment Skillset là bước chuyển đổi từ "kho lưu trữ tài liệu thô" thành "tri thức có cấu trúc, có thể truy vấn thông minh".

1. Tìm **Azure AI services** → **+ Create** → Chọn **Azure AI services** (multi-service account).
2. Điền thông tin:
   - **Name:** `ais-lexcorp-001`
   - **Region:** **PHẢI cùng region với Azure AI Search** — yêu cầu bắt buộc.
   - **Pricing tier:** Standard S0.
3. Nhấn **Review + create** → **Create**.

---

## Phase 2: Bảo mật Enterprise (Security Layer)

### Bước 1: Azure Key Vault (Kho Khóa Bảo mật)

> **Mục đích:** Trong môi trường doanh nghiệp, tuyệt đối không hardcode API keys trong code hay config file. Key Vault là "két sắt số" lưu trữ mọi thông tin nhạy cảm một cách mã hóa — chỉ các dịch vụ được cấp quyền mới đọc được secrets này tại runtime.

> **Hệ quả nếu bỏ qua:** Nếu hardcode API key trong source code: (1) Key bị lộ khi commit lên Git repository (dù private repo cũng có rủi ro). (2) Khi xoay vòng (rotate) key, phải sửa code và redeploy toàn bộ ứng dụng. (3) Mọi developer đều nhìn thấy key trong code → vi phạm principle of least privilege. (4) Các tool tự động quét secret trong code (GitGuardian, TruffleHog) sẽ báo động. Đây là nguyên nhân của rất nhiều vụ data breach lớn.

1. Tìm **Key vaults** → **+ Create**.
   - **Key vault name:** `kv-lexcorp-001nbui`
   - **Pricing tier:** Standard.
2. Nhấn **Review + create** → **Create**.

**Cấp quyền để tạo Secrets:**
- Vào Key Vault → **Access control (IAM)** → **+ Add** → **Add role assignment**.
- Chọn role **Key Vault Secrets Officer** → Assign cho email của bạn.
- ⚠️ **Chờ 3–5 phút** để Azure propagate quyền.

**Thêm API Keys vào Key Vault:**
- Vào **Secrets** → **+ Generate/Import**.

| Secret Name | Value (lấy từ) |
|-------------|----------------|
| `azure-openai-api-key` | Azure OpenAI resource → Keys and Endpoint |
| `ai-services-key` | `ais-lexcorp-001` → Keys and Endpoint |
| `search-admin-key` | `srch-lexcorp-001` → Keys |

### Bước 2: Managed Identity — Zero-Trust Authentication

> **🧠 Kiến thức nền tảng — Managed Identity là gì và tại sao nó quan trọng hơn connection string?**
>
> Trong kiến trúc truyền thống, để AI Search kết nối với Blob Storage, bạn sẽ dùng một connection string dạng: `DefaultEndpointsProtocol=https;AccountName=stlexcorpdocs001;AccountKey=abc123xyz...`. Connection string này chứa secret key — nghĩa là bạn phải lưu nó ở đâu đó (config file, database, Key Vault). Vẫn còn một bí mật cần quản lý.
>
> **Managed Identity** giải quyết triệt để: Azure cấp cho AI Search service một "thẻ căn cước số" (Service Principal) được quản lý hoàn toàn bởi Azure Active Directory. Khi AI Search cần đọc file từ Blob Storage, nó trình thẻ căn cước này ra — Azure AD xác nhận danh tính và kiểm tra xem AI Search có được phép đọc Blob Storage không. **Không có password, không có secret, không có gì để lộ.**
>
> Đây là mô hình **Zero-Trust Security**: không tin tưởng bất kỳ kết nối nào mặc định, luôn xác thực danh tính. Tất cả các dịch vụ Azure lớn (Google Cloud, AWS cũng có khái niệm tương tự: Workload Identity, IAM Roles) đều đang dịch chuyển về mô hình này.

**Kích hoạt Managed Identity cho AI Search:**
- Vào `srch-lexcorp-001` → **Identity** → Tab **System assigned** → **Status: On** → **Save**.

**Cấp quyền đọc Blob cho AI Search:**
- Vào Storage Account `stlexcorpdocs001` → **Access Control (IAM)** → **+ Add** → **Add role assignment**.
- Role: **Storage Blob Data Reader** → **Managed identity** → Chọn `srch-lexcorp-001` → **Review + assign**.

### Bước 3: Private Endpoints — Kiến trúc Network Security Production

> **🧠 Kiến thức nền tảng — Tại sao Public Endpoints không đủ cho Production?**
>
> Khi chúng ta tạo Azure AI Search với Public Endpoint, service này có một địa chỉ Internet công khai (ví dụ: `srch-lexcorp-001.search.windows.net`). Điều này có nghĩa là về lý thuyết, bất kỳ máy tính nào trên Internet đều có thể "gõ cửa" vào service này (dù vẫn cần API key để vào được). Với dữ liệu pháp lý nhạy cảm của LexCorp, đây là rủi ro không chấp nhận được.
>
> **Private Endpoint** tạo ra một địa chỉ IP nội bộ (private IP) trong Virtual Network riêng của LexCorp cho mỗi Azure service. Traffic từ ứng dụng đến Azure AI Search, từ AI Search đến Blob Storage — tất cả đi qua mạng nội bộ Microsoft backbone, **không bao giờ chạm Internet public**. Kẻ tấn công bên ngoài không thể gõ cửa vào những địa chỉ IP nội bộ này.
>
> **Lý do không triển khai trong Lab**: Cấu hình Private Endpoint đòi hỏi: tạo Virtual Network (VNet), thiết lập DNS Private Zone, cấu hình DNS resolver, và có thể cần VPN Gateway — thêm ~20 bước phức tạp và tốn thêm ~$100/tháng. Lab này tập trung vào chức năng AI Search và RAG. Trong Production thực tế, Private Endpoints là yêu cầu bắt buộc.

**Kiến trúc Private Endpoint cho Production LexCorp (tham khảo):**
```
LexCorp Private VNet (10.0.0.0/16)
├── subnet-search    → Private Endpoint → srch-lexcorp-001 (IP: 10.0.1.4)
├── subnet-storage   → Private Endpoint → stlexcorpdocs001 (IP: 10.0.2.4)
└── subnet-openai    → Private Endpoint → oai-lexcorp-001 (IP: 10.0.3.4)
Tất cả traffic chạy qua Microsoft Backbone — không qua Internet
```

---

## Phase 3: Data Source & Chunking Strategy

### Bước 1: Kết nối Data Source với Managed Identity

> **Mục đích:** Data Source cho AI Search biết "dữ liệu nằm ở đâu và kết nối bằng cách nào". Dùng ResourceId (Managed Identity) thay vì AccountKey để đảm bảo zero-secret connection.

```bash
# Lấy Admin API Key từ: srch-lexcorp-001 → Keys → Primary admin key
curl -X POST "https://srch-lexcorp-001.search.windows.net/datasources?api-version=2024-07-01" \
  -H "Content-Type: application/json" \
  -H "api-key: YOUR_SEARCH_ADMIN_KEY" \
  -d '{
    "name": "lexcorp-blob-datasource",
    "type": "azureblob",
    "credentials": {
      "connectionString": "ResourceId=/subscriptions/YOUR_SUB_ID/resourceGroups/rg-lexcorp-search-001/providers/Microsoft.Storage/storageAccounts/stlexcorpdocs001;"
    },
    "container": { "name": "legal-documents" },
    "dataChangeDetectionPolicy": {
      "@odata.type": "#Microsoft.Azure.Search.HighWaterMarkChangeDetectionPolicy",
      "highWaterMarkColumnName": "metadata_storage_last_modified"
    }
  }'
```

### Bước 2: Document Cracking & Chunking Strategy

> **🧠 Kiến thức nền tảng — Tại sao Chunking là quyết định thiết kế quan trọng nhất trong RAG?**
>
> **Document Cracking** là quá trình AI Search "mở" file nhị phân (PDF, DOCX) và trích xuất raw text. Đây là bước tự động và không cần cấu hình nhiều. **Chunking** là bước phức tạp hơn nhiều và ảnh hưởng trực tiếp đến chất lượng RAG.
>
> Vấn đề cốt lõi: GPT-4o có context window ~128,000 tokens. Một tài liệu hợp đồng 50 trang có thể có ~25,000 tokens — một phần đã chiếm gần 20% context window. Nếu chúng ta search 5 tài liệu để đưa vào RAG context, 5 × 25,000 = 125,000 tokens → gần hết context, không còn chỗ cho system prompt và câu trả lời. Hơn nữa, với một tài liệu 50 trang, chỉ có 2 đoạn liên quan đến câu hỏi → đưa cả 50 trang vào là "nhiễu" (noise) → GPT-4o bị phân tâm và câu trả lời kém chính xác hơn.
>
> **Chunking giải quyết vấn đề này**: chia tài liệu thành nhiều đoạn nhỏ (chunks). Mỗi chunk được index và embed riêng biệt. Khi search, hệ thống chỉ trả về *đúng những chunks liên quan* thay vì toàn bộ tài liệu. RAG context gọn gàng, chính xác, hiệu quả hơn nhiều.
>
> **Overlap giữa các chunks**: Mỗi chunk có 10-15% nội dung chồng lấp với chunk kề bên. Lý do: nếu một điều khoản quan trọng nằm đúng ở ranh giới hai chunks, không có overlap sẽ bị cắt đứt giữa chừng → mất context → RAG không hiểu đầy đủ.

| Chiến lược | Kích thước chunk | Ưu điểm | Nhược điểm | Phù hợp với |
|------------|-----------------|---------|------------|------------|
| Fixed-size (token) | 512 tokens | Nhất quán, đơn giản | Cắt giữa câu/điều khoản | Tài liệu thuần văn bản đồng nhất |
| Sentence-based | 1-3 câu | Giữ nguyên nghĩa câu | Chunks không đều, context hẹp | Tài liệu dạng văn xuôi |
| **Paragraph/Section** | **1-2 đoạn văn** | **Giữ nguyên context pháp lý** | Chunks kích thước biến đổi | **✅ Hợp đồng, bản án LexCorp** |
| Hierarchical | Chương→Điều→Khoản | Preserve document structure | Phức tạp, cần parser tùy chỉnh | Bản án tòa có cấu trúc chặt |
| Semantic chunking | Theo boundary ngữ nghĩa | Tốt nhất về chất lượng | Chậm, tốn compute | Long-term production refinement |

> **Quyết định cho LexCorp**: **Paragraph-based với 2000 ký tự, overlap 200 ký tự** — giữ nguyên điều khoản pháp lý hoàn chỉnh, overlap đảm bảo không mất context ở ranh giới.

---

## Phase 4: AI Enrichment Skillset

> **🧠 Kiến thức nền tảng — Inverted Index và BM25 hoạt động như thế nào?**
>
> Để hiểu sức mạnh của Azure AI Search, bạn cần hiểu cơ chế nền tảng của nó — **Inverted Index**.
>
> Hãy tưởng tượng bạn có 3 tài liệu:
> - Doc1: "Bên A vi phạm điều khoản bảo mật"
> - Doc2: "Điều khoản bảo mật thông tin khách hàng"
> - Doc3: "Vi phạm hợp đồng gây thiệt hại cho bên B"
>
> Inverted Index đảo ngược chiều lưu trữ: thay vì "tài liệu nào chứa từ gì", nó lưu "từ nào xuất hiện trong tài liệu nào":
> ```
> "bảo mật" → [Doc1(lần 1), Doc2(lần 1)]
> "vi phạm" → [Doc1(lần 1), Doc3(lần 1)]
> "điều khoản" → [Doc1(lần 1), Doc2(lần 1)]
> ```
> Khi user search "bảo mật vi phạm", hệ thống tìm list của "bảo mật" và "vi phạm" → intersection → Doc1 có cả hai → trả về ngay lập tức mà không cần scan toàn bộ text. Đây là lý do search engines nhanh như vậy.
>
> **BM25** (Best Match 25) là thuật toán tính *relevance score* cho mỗi tài liệu: từ xuất hiện nhiều trong tài liệu ngắn được đánh giá cao hơn từ xuất hiện ít trong tài liệu dài. Đây là cải tiến so với TF-IDF cũ. BM25 rất mạnh cho keyword search nhưng không hiểu ngữ nghĩa — "bồi thường" và "compensation" là hai từ hoàn toàn khác với BM25.
>
> **Vector Search** giải quyết vấn đề này: thay vì lưu từ, lưu "ý nghĩa" của đoạn text dưới dạng vector số học 1536 chiều. Hai câu có nghĩa tương tự sẽ có vector gần nhau trong không gian 1536 chiều (cosine similarity cao). **HNSW** (Hierarchical Navigable Small World) là thuật toán index đặc biệt cho phép tìm kiếm approximate nearest neighbor với độ chính xác ~99% nhưng tốc độ cực nhanh — không cần so sánh với 50.000 vectors.

**Toàn bộ Skillset Definition:**

```json
{
  "name": "lexcorp-enrichment-skillset",
  "description": "AI Enrichment pipeline cho tài liệu pháp lý LexCorp Vietnam",
  "cognitiveServices": {
    "@odata.type": "#Microsoft.Azure.Search.CognitiveServicesByKey",
    "key": "YOUR_AI_SERVICES_KEY"
  },
  "skills": [
    {
      "name": "ocr-skill",
      "@odata.type": "#Microsoft.Skills.Vision.OcrSkill",
      "description": "OCR cho các PDF được scan (ảnh chụp, không phải digital PDF)",
      "context": "/document/normalized_images/*",
      "defaultLanguageCode": "vi",
      "detectOrientation": true,
      "inputs": [{ "name": "image", "source": "/document/normalized_images/*" }],
      "outputs": [{ "name": "text", "targetName": "ocr_text" }]
    },
    {
      "name": "merge-skill",
      "@odata.type": "#Microsoft.Skills.Text.MergeSkill",
      "description": "Gộp text gốc (digital PDF) với text từ OCR (scanned PDF)",
      "context": "/document",
      "inputs": [
        { "name": "text", "source": "/document/content" },
        { "name": "itemsToInsert", "source": "/document/normalized_images/*/ocr_text" },
        { "name": "offsets", "source": "/document/normalized_images/*/contentOffset" }
      ],
      "outputs": [{ "name": "mergedText", "targetName": "merged_content" }]
    },
    {
      "name": "split-skill",
      "@odata.type": "#Microsoft.Skills.Text.SplitSkill",
      "description": "Chunking: paragraph-based, 2000 ký tự, overlap 200",
      "context": "/document",
      "textSplitMode": "pages",
      "maximumPageLength": 2000,
      "pageOverlapLength": 200,
      "inputs": [{ "name": "text", "source": "/document/merged_content" }],
      "outputs": [{ "name": "textItems", "targetName": "chunks" }]
    },
    {
      "name": "keyphrase-skill",
      "@odata.type": "#Microsoft.Skills.Text.KeyPhraseExtractionSkill",
      "description": "Trích xuất các cụm từ khóa pháp lý quan trọng (tối đa 20/chunk)",
      "context": "/document/chunks/*",
      "defaultLanguageCode": "vi",
      "maxKeyPhraseCount": 20,
      "inputs": [{ "name": "text", "source": "/document/chunks/*" }],
      "outputs": [{ "name": "keyPhrases", "targetName": "key_phrases" }]
    },
    {
      "name": "entity-recognition-skill",
      "@odata.type": "#Microsoft.Skills.Text.V3.EntityRecognitionSkill",
      "description": "NER: tên Người, Tổ chức, Địa điểm, Ngày tháng từ văn bản pháp lý",
      "context": "/document/chunks/*",
      "categories": ["Person", "Organization", "Location", "DateTime"],
      "defaultLanguageCode": "vi",
      "minimumPrecision": 0.5,
      "inputs": [{ "name": "text", "source": "/document/chunks/*" }],
      "outputs": [
        { "name": "persons", "targetName": "entities_persons" },
        { "name": "organizations", "targetName": "entities_organizations" },
        { "name": "locations", "targetName": "entities_locations" }
      ]
    },
    {
      "name": "embedding-skill",
      "@odata.type": "#Microsoft.Skills.Text.AzureOpenAIEmbeddingSkill",
      "description": "Vector embedding 1536D cho hybrid search và semantic similarity",
      "context": "/document/chunks/*",
      "resourceUri": "https://YOUR_OPENAI_RESOURCE.openai.azure.com",
      "apiKey": "YOUR_OPENAI_API_KEY",
      "deploymentId": "text-embedding-ada-002",
      "modelName": "text-embedding-ada-002",
      "dimensions": 1536,
      "inputs": [{ "name": "text", "source": "/document/chunks/*" }],
      "outputs": [{ "name": "embedding", "targetName": "content_vector" }]
    },
    {
      "name": "custom-legal-clause-skill",
      "@odata.type": "#Microsoft.Skills.Custom.WebApiSkill",
      "description": "Custom skill: Azure Function phân loại điều khoản pháp lý đặc thù LexCorp",
      "context": "/document/chunks/*",
      "uri": "https://func-lexcorp-skills.azurewebsites.net/api/ExtractLegalClauses?code=YOUR_KEY",
      "httpMethod": "POST",
      "timeout": "PT30S",
      "batchSize": 10,
      "inputs": [{ "name": "text", "source": "/document/chunks/*" }],
      "outputs": [
        { "name": "clause_type", "targetName": "legal_clause_type" },
        { "name": "obligation_party", "targetName": "obligation_party" }
      ]
    }
  ]
}
```

### Chi tiết Custom Skill — Azure Function (Legal Clause Extractor)

> **Mục đích:** Azure AI Search cung cấp sẵn các cognitive skills thông thường (OCR, entity recognition). Nhưng nghiệp vụ đặc thù của LexCorp — nhận dạng *loại điều khoản pháp lý cụ thể* (phạt vi phạm, bảo mật, chấm dứt...) — cần Custom Skill. Cơ chế: AI Search gọi HTTP POST đến Azure Function, trả về JSON theo chuẩn định sẵn.

```python
# func-lexcorp-skills/ExtractLegalClauses/__init__.py
import azure.functions as func
import json, re

CLAUSE_PATTERNS = {
    "penalty": [r"phạt vi phạm", r"bồi thường thiệt hại", r"liquidated damages", r"breach"],
    "confidentiality": [r"bảo mật thông tin", r"thông tin mật", r"non-disclosure", r"NDA"],
    "termination": [r"chấm dứt hợp đồng", r"đơn phương chấm dứt", r"termination"],
    "payment": [r"thanh toán", r"phương thức thanh toán", r"payment terms"],
    "dispute": [r"giải quyết tranh chấp", r"trọng tài", r"arbitration", r"jurisdiction"]
}

def detect_clause_type(text: str) -> str:
    text_lower = text.lower()
    scores = {ct: sum(1 for p in patterns if re.search(p, text_lower))
              for ct, patterns in CLAUSE_PATTERNS.items()}
    scores = {k: v for k, v in scores.items() if v > 0}
    return max(scores, key=scores.get) if scores else "general"

def extract_obligation_party(text: str) -> str:
    has_a = bool(re.search(r"bên (a|thứ nhất|cung cấp|bán)", text, re.IGNORECASE))
    has_b = bool(re.search(r"bên (b|thứ hai|mua|nhận)", text, re.IGNORECASE))
    if has_a and has_b: return "both_parties"
    if has_a: return "party_a"
    if has_b: return "party_b"
    return "unspecified"

def main(req: func.HttpRequest) -> func.HttpResponse:
    try:
        records = req.get_json().get("values", [])
        results = []
        for record in records:
            text = record.get("data", {}).get("text", "")
            results.append({
                "recordId": record.get("recordId"),
                "data": {
                    "clause_type": detect_clause_type(text),
                    "obligation_party": extract_obligation_party(text)
                },
                "errors": [], "warnings": []
            })
        return func.HttpResponse(json.dumps({"values": results}),
                                 status_code=200, mimetype="application/json")
    except Exception as e:
        return func.HttpResponse(json.dumps({"error": str(e)}),
                                 status_code=500, mimetype="application/json")
```

---

## Phase 5: Thiết kế Schema Index

> **🧠 Kiến thức nền tảng — Tại sao Schema Design là quyết định không thể thay đổi?**
>
> Trong Azure AI Search, sau khi tạo index với một schema, bạn **không thể thay đổi kiểu dữ liệu của field đã tồn tại**. Ví dụ, nếu bạn tạo field `document_year` kiểu `Edm.String` nhưng sau đó muốn sort/filter theo năm → phải tạo lại index từ đầu và index lại toàn bộ 50.000 tài liệu (có thể mất nhiều giờ và chi phí AI Enrichment). Đây là lý do Schema Design cần tư duy kiến trúc kỹ lưỡng ngay từ đầu.
>
> Một số nguyên tắc vàng:
> - `filterable: true` → cho phép `$filter=document_year eq 2023` nhưng tốn thêm storage
> - `facetable: true` → UI có thể hiển thị dropdown "Lọc theo năm: [2021][2022][2023]"
> - `searchable: true` → field được đưa vào inverted index để full-text search
> - `retrievable: false` → field tồn tại nhưng không trả về trong response (tiết kiệm bandwidth) — áp dụng cho `content_vector` 1536 floats
> - `sortable: true` → cho phép `$orderby=document_year desc`

```json
{
  "name": "lexcorp-legal-index",
  "fields": [
    { "name": "id", "type": "Edm.String", "key": true, "filterable": true },
    { "name": "content", "type": "Edm.String", "searchable": true, "retrievable": true,
      "analyzer": "vi.microsoft" },
    { "name": "content_vector", "type": "Collection(Edm.Single)", "searchable": true,
      "retrievable": false, "dimensions": 1536, "vectorSearchProfile": "hnsw-profile" },
    { "name": "document_title", "type": "Edm.String", "searchable": true, "filterable": true,
      "retrievable": true, "analyzer": "vi.microsoft" },
    { "name": "document_type", "type": "Edm.String", "filterable": true, "facetable": true,
      "retrievable": true },
    { "name": "document_year", "type": "Edm.Int32", "filterable": true, "facetable": true,
      "sortable": true, "retrievable": true },
    { "name": "key_phrases", "type": "Collection(Edm.String)", "searchable": true,
      "retrievable": true },
    { "name": "entities_persons", "type": "Collection(Edm.String)", "searchable": true,
      "filterable": true, "facetable": true, "retrievable": true },
    { "name": "entities_organizations", "type": "Collection(Edm.String)", "searchable": true,
      "filterable": true, "facetable": true, "retrievable": true },
    { "name": "legal_clause_type", "type": "Edm.String", "filterable": true, "facetable": true,
      "retrievable": true },
    { "name": "obligation_party", "type": "Edm.String", "filterable": true, "retrievable": true },
    { "name": "metadata_storage_path", "type": "Edm.String", "retrievable": true }
  ],
  "vectorSearch": {
    "profiles": [{ "name": "hnsw-profile", "algorithm": "hnsw-config" }],
    "algorithms": [{
      "name": "hnsw-config", "kind": "hnsw",
      "hnswParameters": { "m": 4, "efConstruction": 400, "efSearch": 500, "metric": "cosine" }
    }]
  },
  "semantic": {
    "defaultConfiguration": "lexcorp-semantic-config",
    "configurations": [{
      "name": "lexcorp-semantic-config",
      "prioritizedFields": {
        "titleField": { "fieldName": "document_title" },
        "prioritizedContentFields": [{ "fieldName": "content" }],
        "prioritizedKeywordsFields": [
          { "fieldName": "key_phrases" }, { "fieldName": "legal_clause_type" }
        ]
      }
    }]
  }
}
```

> **Giải thích `vi.microsoft` Analyzer:** Đây là bộ phân tích ngôn ngữ tiếng Việt của Microsoft, xử lý đúng: tokenization theo từ (không phải ký tự), xử lý dấu thanh sắc/huyền/nặng/hỏi/ngã, stop words tiếng Việt. Nếu dùng `standard` analyzer (dành cho tiếng Anh), tìm kiếm "bảo mật" có thể không khớp đúng với "bảo" và "mật" là hai token riêng biệt.

---

## Phase 6: Semantic Configuration & Vector Search

> **🧠 Kiến thức nền tảng — Tại sao RAG tốt hơn Fine-tuning GPT?**
>
> Đây là câu hỏi kiến trúc quan trọng mà mọi AI Engineer cần hiểu rõ. Có hai cách để GPT "biết" về tài liệu của LexCorp:
>
> **Cách 1 — Fine-tuning**: Train lại model GPT với dữ liệu pháp lý của LexCorp. Ưu điểm: model "nhớ" thông tin sâu hơn. Nhược điểm: (a) Chi phí train cực kỳ đắt — hàng chục nghìn USD. (b) Khi tài liệu mới được thêm vào, phải train lại từ đầu. (c) Model có thể "quên" kiến thức cũ (catastrophic forgetting). (d) **Không thể trích dẫn nguồn** — model không biết nó "học" từ tài liệu nào → không có citations. (e) Với tài liệu pháp lý, không có citation nghĩa là câu trả lời không đáng tin cậy.
>
> **Cách 2 — RAG (Retrieval-Augmented Generation)**: Không train lại model. Thay vào đó, mỗi khi có câu hỏi: search tài liệu liên quan → đưa vào context của GPT → GPT trả lời *dựa trên context đó*. Ưu điểm: (a) Không cần train lại khi có tài liệu mới — chỉ cần index thêm. (b) Mỗi câu trả lời đều có citation cụ thể — luật sư có thể kiểm chứng ngay. (c) Chi phí thấp hơn fine-tuning nhiều lần. (d) GPT "thấy" tài liệu thực tế → ít hallucinate hơn. Nhược điểm: (a) Bị giới hạn bởi chất lượng search — nếu search không tìm được chunk đúng, GPT không có context để trả lời đúng. (b) Giới hạn context window của LLM.
>
> **Kết luận cho LexCorp**: RAG là lựa chọn tối ưu vì: (1) Tài liệu pháp lý cập nhật liên tục — RAG linh hoạt hơn. (2) Cần citations để đảm bảo tính pháp lý của câu trả lời. (3) Chi phí phù hợp với quy mô doanh nghiệp vừa và nhỏ.

**Tạo Azure OpenAI Resource:**
1. Tìm **Azure OpenAI** → **+ Create**.
   - **Region:** `East US` hoặc `Sweden Central` *(kiểm tra availability cho GPT-4o)*.
   - **Name:** `oai-lexcorp-001`
2. Deploy models:

| Model | Deployment Name | Mục đích |
|-------|----------------|----------|
| `text-embedding-ada-002` | `text-embedding-ada-002` | Vector embeddings 1536D |
| `gpt-4o` | `gpt-4o` | RAG Chat Completions |

**Cơ chế Hybrid Search — BM25 + Vector + Semantic Reranking:**

```
Query: "điều khoản bồi thường vi phạm hợp đồng thuê văn phòng"
          │
          ├─ Embed query → [0.12, -0.34, 0.78, ...] (1536 chiều)
          │
     ┌────┴────────────────────┐
     │                         │
  BM25 Search              Vector Search
  (inverted index)         (HNSW approximate)
  Top-50 by keywords       Top-50 by cosine similarity
     │                         │
     └────────┬────────────────┘
              │
     Reciprocal Rank Fusion (RRF)
     Hợp nhất và normalize scores
              │
     Top-50 merged candidates
              │
     Semantic L2 Reranker
     (đọc lại content thực sự)
              │
     Top-5 final results
     (Tài liệu liên quan nhất)
```

---

## Phase 7: Advanced Query Patterns

> **Mục đích:** Hiểu các dạng query khác nhau cho phép bạn chọn đúng phương pháp cho từng use case trong ứng dụng của LexCorp.

### Pattern 1: Full-Text Search với Filter & Highlight

```python
import requests

SEARCH_ENDPOINT = "https://srch-lexcorp-001.search.windows.net"
SEARCH_KEY = "YOUR_SEARCH_ADMIN_KEY"
INDEX_NAME = "lexcorp-legal-index"
API_VERSION = "2024-07-01"

def fulltext_search(query: str, doc_type: str = None, year: int = None):
    """BM25 keyword search với filter và highlight đoạn liên quan."""
    filter_parts = []
    if doc_type:
        filter_parts.append(f"document_type eq '{doc_type}'")
    if year:
        filter_parts.append(f"document_year eq {year}")

    payload = {
        "search": query,
        "queryType": "full",            # Lucene syntax: wildcard, proximity, boolean
        "searchMode": "all",
        "searchFields": "content,document_title,key_phrases",
        "select": "document_title,document_type,document_year,legal_clause_type,content",
        "highlight": "content",
        "highlightPreTag": "<em>",
        "highlightPostTag": "</em>",
        "top": 10, "count": True
    }
    if filter_parts:
        payload["filter"] = " and ".join(filter_parts)

    return requests.post(
        f"{SEARCH_ENDPOINT}/indexes/{INDEX_NAME}/docs/search?api-version={API_VERSION}",
        headers={"Content-Type": "application/json", "api-key": SEARCH_KEY},
        json=payload
    ).json()
```

### Pattern 2: Semantic Search (Natural Language)

```python
def semantic_search(natural_query: str, top_k: int = 5):
    """Ngôn ngữ tự nhiên với Semantic Ranking + Extractive Captions."""
    payload = {
        "search": natural_query,
        "queryType": "semantic",
        "semanticConfiguration": "lexcorp-semantic-config",
        "queryLanguage": "vi-VN",
        "captions": "extractive|highlight-true",
        "answers": "extractive|count-3",
        "select": "document_title,document_type,content,legal_clause_type",
        "top": top_k, "count": True
    }
    data = requests.post(
        f"{SEARCH_ENDPOINT}/indexes/{INDEX_NAME}/docs/search?api-version={API_VERSION}",
        headers={"Content-Type": "application/json", "api-key": SEARCH_KEY},
        json=payload
    ).json()

    for result in data.get("value", []):
        captions = result.get("@search.captions", [])
        caption = captions[0].get("highlights", "") if captions else ""
        print(f"[{result.get('@search.rerankerScore', 0):.3f}] {result.get('document_title')}")
        print(f"  → {caption}\n")
    return data
```

### Pattern 3: Faceted Search (Bộ lọc Động cho UI)

```python
def faceted_search(query: str):
    """Trả về kết quả + thống kê facet để UI render bộ lọc động."""
    payload = {
        "search": query,
        "facets": [
            "document_type,count:10",
            "legal_clause_type,count:10",
            "document_year,interval:1",
            "entities_organizations,count:10"
        ],
        "select": "document_title,document_type,document_year,legal_clause_type",
        "top": 10
    }
    data = requests.post(
        f"{SEARCH_ENDPOINT}/indexes/{INDEX_NAME}/docs/search?api-version={API_VERSION}",
        headers={"Content-Type": "application/json", "api-key": SEARCH_KEY},
        json=payload
    ).json()

    print("=== Bộ lọc gợi ý từ kết quả tìm kiếm ===")
    for facet_name, facet_values in data.get("@search.facets", {}).items():
        print(f"\n[{facet_name}]")
        for fv in facet_values:
            print(f"  {fv.get('value')}: {fv.get('count')} tài liệu")
    return data
```

---

## Phase 8: RAG Integration Pipeline (Production-Quality)

> **🧠 Kiến thức nền tảng — Giải phẫu một Production RAG System**
>
> Một RAG system ở mức production không chỉ là "search + LLM call". Có nhiều thành phần quan trọng hơn:
>
> **Query Preprocessing**: Đôi khi câu hỏi của user mơ hồ ("hợp đồng kia nói gì về phạt?"). Production RAG có thể dùng LLM để *rewrite* câu hỏi thành dạng rõ ràng hơn trước khi search.
>
> **Context Window Management**: Mỗi chunk đưa vào context chiếm tokens. Phải tính toán cẩn thận để tổng token (system prompt + context + user query + response) không vượt quá context limit. Code production cần `tiktoken` để đếm tokens chính xác.
>
> **Hallucination Prevention**: Dùng `temperature=0.1` (thấp) → model ít "sáng tạo" hơn, bám sát context hơn. System prompt phải rõ ràng: "Chỉ trả lời dựa trên tài liệu được cung cấp. Nếu không có thông tin, nói rõ."
>
> **Citation Generation**: Không chỉ trả lời mà còn phải nêu nguồn. Trong LexCorp, mỗi câu trả lời cần ghi rõ "Theo Hợp đồng HĐ-2023-045, Điều 8.2..." để luật sư có thể kiểm chứng trong hệ thống tài liệu gốc.
>
> **Observability**: Mọi query đều cần log: query text, search results, LLM response, token count, latency. Thiếu observability là lý do #1 khiến RAG systems thất bại ở production mà không ai biết tại sao.

```python
"""
lexcorp_rag_pipeline.py — Production RAG Pipeline cho LexCorp Vietnam
Tích hợp: Azure AI Search (Hybrid) + Azure OpenAI GPT-4o
"""

import os, time, logging
from typing import Optional
from dataclasses import dataclass
from openai import AzureOpenAI
import requests

# ─── Cấu hình (load từ env vars / Key Vault trong production) ───
SEARCH_ENDPOINT    = os.getenv("AZURE_SEARCH_ENDPOINT", "https://srch-lexcorp-001.search.windows.net")
SEARCH_KEY         = os.getenv("AZURE_SEARCH_KEY")
SEARCH_INDEX       = "lexcorp-legal-index"
SEARCH_API_VERSION = "2024-07-01"
OPENAI_ENDPOINT    = os.getenv("AZURE_OPENAI_ENDPOINT")
OPENAI_KEY         = os.getenv("AZURE_OPENAI_KEY")
EMBED_DEPLOYMENT   = "text-embedding-ada-002"
CHAT_DEPLOYMENT    = "gpt-4o"
OPENAI_API_VERSION = "2024-02-01"
MAX_RESULTS        = 5
RETRY_ATTEMPTS     = 3

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)


@dataclass
class SearchResult:
    doc_id: str; title: str; content: str; doc_type: str
    clause_type: str; reranker_score: float; storage_path: str


@dataclass
class RAGResponse:
    answer: str; sources: list; query: str; latency_ms: float; token_usage: dict


class LexCorpRAGPipeline:
    """
    Production RAG Pipeline theo 4 bước:
    1. Embed query → vector 1536D
    2. Hybrid Search (BM25 + Vector + Semantic Reranking)
    3. Build grounded prompt với context từ top-5 chunks
    4. GPT-4o synthesize answer với citation
    """

    def __init__(self):
        self.openai = AzureOpenAI(azure_endpoint=OPENAI_ENDPOINT,
                                  api_key=OPENAI_KEY,
                                  api_version=OPENAI_API_VERSION)
        self.headers = {"Content-Type": "application/json", "api-key": SEARCH_KEY}
        logger.info("LexCorp RAG Pipeline initialized.")

    def _embed(self, text: str) -> list[float]:
        """Tạo vector embedding với retry và exponential backoff."""
        for attempt in range(RETRY_ATTEMPTS):
            try:
                return self.openai.embeddings.create(
                    model=EMBED_DEPLOYMENT, input=text
                ).data[0].embedding
            except Exception as e:
                if attempt < RETRY_ATTEMPTS - 1:
                    time.sleep(2 ** attempt)
                else:
                    raise RuntimeError(f"Embedding failed: {e}")

    def _search(self, query: str, vector: list, doc_type: str = None,
                year: int = None, top_k: int = MAX_RESULTS) -> list[SearchResult]:
        """Hybrid Search: BM25 + Vector + Semantic Reranking với optional filters."""
        filters = []
        if doc_type: filters.append(f"document_type eq '{doc_type}'")
        if year:     filters.append(f"document_year eq {year}")

        payload = {
            "search": query,
            "queryType": "semantic",
            "semanticConfiguration": "lexcorp-semantic-config",
            "queryLanguage": "vi-VN",
            "captions": "extractive",
            "vectorQueries": [{
                "kind": "vector", "vector": vector,
                "fields": "content_vector", "k": top_k * 3
            }],
            "select": "id,document_title,content,document_type,legal_clause_type,metadata_storage_path",
            "top": top_k, "count": True
        }
        if filters: payload["filter"] = " and ".join(filters)

        for attempt in range(RETRY_ATTEMPTS):
            try:
                resp = requests.post(
                    f"{SEARCH_ENDPOINT}/indexes/{SEARCH_INDEX}/docs/search?api-version={SEARCH_API_VERSION}",
                    headers=self.headers, json=payload, timeout=30
                )
                resp.raise_for_status()
                return [
                    SearchResult(
                        doc_id=r.get("id", ""),
                        title=r.get("document_title", "Không có tiêu đề"),
                        content=r.get("content", ""),
                        doc_type=r.get("document_type", "unknown"),
                        clause_type=r.get("legal_clause_type", "general"),
                        reranker_score=r.get("@search.rerankerScore", 0.0),
                        storage_path=r.get("metadata_storage_path", "")
                    ) for r in resp.json().get("value", [])
                ]
            except Exception as e:
                if attempt < RETRY_ATTEMPTS - 1:
                    time.sleep(2 ** attempt)
                else:
                    logger.error(f"Search failed: {e}")
                    return []

    def _build_prompt(self, query: str, results: list[SearchResult]) -> list[dict]:
        """Xây dựng Grounded Prompt — AI chỉ được trả lời dựa trên context thực tế."""
        context = "\n\n".join([
            f"[Tài liệu {i}]\nTiêu đề: {r.title}\nLoại: {r.doc_type} | Điều khoản: {r.clause_type}\n"
            f"Độ liên quan: {r.reranker_score:.3f}\nNội dung:\n{r.content[:1500]}\n---"
            for i, r in enumerate(results, 1)
        ])

        system = """Bạn là LexCorp Legal AI Assistant — trợ lý pháp lý thông minh của LexCorp Vietnam.

NGUYÊN TẮC BẮT BUỘC:
- Trả lời DỰA TRÊN tài liệu trong CONTEXT. KHÔNG bịa ra thông tin pháp lý.
- Luôn trích dẫn nguồn cụ thể (tên tài liệu, điều khoản nếu có).
- Nếu không tìm thấy thông tin: "Tôi không tìm thấy thông tin này trong tài liệu hiện có."
- Ngôn ngữ: Tiếng Việt pháp lý chuyên nghiệp.

ĐỊNH DẠNG:
1. **Tóm tắt** (2-3 câu)
2. **Phân tích chi tiết** (dựa trên tài liệu cụ thể)
3. **Nguồn tham khảo** (danh sách tài liệu đã dùng)"""

        return [
            {"role": "system", "content": system},
            {"role": "user", "content": f"CONTEXT:\n{context}\n\nCÂU HỎI: {query}"}
        ]

    def _generate(self, messages: list) -> tuple[str, dict]:
        """Gọi GPT-4o với temperature thấp để đảm bảo consistency và ít hallucination."""
        for attempt in range(RETRY_ATTEMPTS):
            try:
                resp = self.openai.chat.completions.create(
                    model=CHAT_DEPLOYMENT, messages=messages,
                    max_tokens=2000, temperature=0.1, top_p=0.95
                )
                return resp.choices[0].message.content, {
                    "prompt_tokens": resp.usage.prompt_tokens,
                    "completion_tokens": resp.usage.completion_tokens,
                    "total_tokens": resp.usage.total_tokens
                }
            except Exception as e:
                if attempt < RETRY_ATTEMPTS - 1:
                    time.sleep(2 ** attempt)
                else:
                    raise RuntimeError(f"GPT-4o failed: {e}")

    def query(self, question: str, doc_type: str = None,
              year: int = None, top_k: int = MAX_RESULTS) -> RAGResponse:
        """Main RAG entry point: nhận câu hỏi → trả về câu trả lời có citation."""
        t0 = time.time()
        logger.info(f"RAG query: '{question[:80]}'")

        vector = self._embed(question)
        results = self._search(question, vector, doc_type, year, top_k)

        if not results:
            return RAGResponse(
                answer="Không tìm thấy tài liệu liên quan. Vui lòng thử từ khóa khác.",
                sources=[], query=question, latency_ms=(time.time()-t0)*1000, token_usage={}
            )

        messages = self._build_prompt(question, results)
        answer, tokens = self._generate(messages)
        latency = (time.time() - t0) * 1000
        logger.info(f"Completed in {latency:.0f}ms | Tokens: {tokens.get('total_tokens', 0)}")
        return RAGResponse(answer=answer, sources=results, query=question,
                           latency_ms=latency, token_usage=tokens)


# ─── Demo ───
if __name__ == "__main__":
    pipeline = LexCorpRAGPipeline()
    result = pipeline.query(
        "Điều khoản bồi thường thiệt hại khi vi phạm nghĩa vụ bảo mật thông tin là gì?",
        doc_type="contract", top_k=5
    )
    print(f"\n📋 CÂU TRẢ LỜI:\n{result.answer}")
    print(f"\n📚 NGUỒN ({len(result.sources)} tài liệu):")
    for i, s in enumerate(result.sources, 1):
        print(f"  {i}. [{s.reranker_score:.3f}] {s.title} ({s.doc_type})")
    print(f"\n⏱️ {result.latency_ms:.0f}ms | {result.token_usage.get('total_tokens', 0)} tokens")
```

---

## Phase 9: Kiểm thử Toàn diện (End-to-End Testing)

> **Mục đích:** E2E Testing xác nhận toàn bộ pipeline — từ tài liệu gốc trong Blob Storage đến câu trả lời RAG — hoạt động đúng, đủ nhanh, và xử lý gracefully các trường hợp biên.

### Test 1: Kiểm tra Indexer Status

```bash
curl -X GET \
  "https://srch-lexcorp-001.search.windows.net/indexers/lexcorp-blob-indexer/status?api-version=2024-07-01" \
  -H "api-key: YOUR_SEARCH_ADMIN_KEY" | python3 -m json.tool
# Mong đợi: "status": "success", "itemsFailed": 0
```

### Test 2: Search Quality với Golden Dataset

```python
def test_search_relevance():
    """Golden dataset test: câu hỏi chuẩn với đáp án đã biết để đo chất lượng search."""
    golden_cases = [
        {"query": "phạt vi phạm hợp đồng", "expected_clause": "penalty", "min_score": 1.5},
        {"query": "quyền chấm dứt hợp đồng của bên thuê", "expected_clause": "termination", "min_score": 1.5},
        {"query": "bảo mật thông tin khách hàng", "expected_clause": "confidentiality", "min_score": 1.5}
    ]
    pipeline = LexCorpRAGPipeline()
    passed = 0
    for tc in golden_cases:
        vector = pipeline._embed(tc["query"])
        results = pipeline._search(tc["query"], vector, top_k=3)
        if results:
            top = results[0]
            ok = top.reranker_score >= tc["min_score"] and top.clause_type == tc["expected_clause"]
            print(f"{'✅' if ok else '❌'} '{tc['query']}' → Score:{top.reranker_score:.3f}, Clause:{top.clause_type}")
            if ok: passed += 1
        else:
            print(f"❌ '{tc['query']}' → Không có kết quả")
    print(f"\nKết quả: {passed}/{len(golden_cases)} tests passed")

test_search_relevance()
```

### Test 3: RAG Pipeline End-to-End

```python
def test_rag_e2e():
    pipeline = LexCorpRAGPipeline()
    result = pipeline.query(
        "Quy trình yêu cầu bồi thường và thời hạn khiếu nại khi vi phạm điều khoản bảo mật?"
    )
    assert result.answer and len(result.answer) > 100, "❌ Câu trả lời quá ngắn hoặc rỗng"
    assert result.sources, "❌ Không có tài liệu nguồn"
    assert result.latency_ms < 15000, f"❌ Quá chậm: {result.latency_ms:.0f}ms"
    assert result.token_usage.get("total_tokens", 0) > 0, "❌ Thiếu token usage"
    print(f"✅ RAG E2E PASS — {result.latency_ms:.0f}ms | {result.token_usage.get('total_tokens')} tokens")
    print(f"📋 {result.answer[:300]}...")

test_rag_e2e()
```

### Test 4: Edge Cases & Resilience

```python
def test_edge_cases():
    """Kiểm tra khả năng xử lý các tình huống bất thường mà không crash."""
    pipeline = LexCorpRAGPipeline()
    edge_cases = [
        "Giá vàng hôm nay là bao nhiêu?",           # Out-of-domain
        "What are the confidentiality obligations?",  # Tiếng Anh
        "a" * 2000                                    # Query cực dài
    ]
    for q in edge_cases:
        try:
            result = pipeline.query(q[:200], top_k=3)
            print(f"✅ Handled gracefully: '{q[:50]}...' → {len(result.sources)} sources")
        except Exception as e:
            print(f"❌ Exception: '{q[:50]}...' → {e}")

test_edge_cases()
```

---

## Phase 10: Dọn dẹp Tài nguyên (Clean Up)

> **Mục đích:** Xóa toàn bộ tài nguyên Azure để ngừng tính phí. Với Azure AI Search Standard S1 + Azure OpenAI, chi phí có thể lên đến $250–$300/tháng nếu để chạy mà không sử dụng.

| Dịch vụ | Tier | Chi phí/tháng |
|---------|------|---------------|
| Azure AI Search | Basic | ~$75 |
| Azure OpenAI | Standard (theo token) | ~$10–$50 |
| Azure Blob Storage | LRS | ~$0.20 |
| Azure AI Services | Standard S0 | ~$1–$5 |
| Azure Key Vault + Functions | Standard | ~$0.05 |
| **TỔNG** | | **~$90–$130** |

**Xóa qua Portal (Đơn giản nhất):**
1. Đăng nhập [portal.azure.com](https://portal.azure.com).
2. Mở **Resource groups** → chọn `rg-lexcorp-search-001`.
3. Nhấn **Delete resource group** → gõ `rg-lexcorp-search-001` → **Delete**.

**Xóa bằng Azure CLI:**
```bash
az group delete --name rg-lexcorp-search-001 --yes --no-wait
az group list --query "[?name=='rg-lexcorp-search-001']"
# Kết quả mong đợi: [] (mảng rỗng = đã xóa thành công)
```

---

## Tổng kết & Hướng Phát triển Tiếp theo

Bạn đã hoàn thành xây dựng một **Enterprise Intelligent Search & RAG Pipeline** đầy đủ cho LexCorp Vietnam:

| Component | Công nghệ | Chức năng |
|-----------|-----------|-----------|
| Document Storage | Azure Blob Storage + Managed Identity | Lưu trữ 50K+ PDF/DOCX, kết nối zero-secret |
| Security | Key Vault + Managed Identity | Zero-Trust, không hardcode secrets |
| AI Enrichment | OCR + NER + Key Phrases + Custom Skill | Biến PDF thô thành dữ liệu có cấu trúc |
| Search Index | Azure AI Search (vi.microsoft analyzer) | BM25 + Vector + Semantic Reranking |
| Vector Embeddings | text-embedding-ada-002 (1536D, HNSW) | Tìm kiếm ngữ nghĩa xuyên ngôn ngữ |
| RAG Pipeline | Python + GPT-4o + Citation | Câu trả lời có trích dẫn nguồn pháp lý |

**Các hướng phát triển Production:**
- 🔒 Triển khai Private Endpoints để loại bỏ hoàn toàn Internet exposure.
- 📊 Tích hợp Application Insights: monitor latency P99, error rate, token cost/query.
- 🔄 Indexer Schedule chạy hàng đêm để tự động index tài liệu mới thêm vào.
- 🌐 Xây dựng Web UI (React + Next.js) với faceted search, chat interface, citation viewer.
- 📈 Đánh giá chất lượng RAG tự động: RAGAS framework (faithfulness, answer relevancy, context recall).
- 🛡️ Azure AI Content Safety để filter prompt injection và nội dung không phù hợp.
- 💰 Cost optimization: cache embedding vectors của các query phổ biến với Azure Redis Cache.
