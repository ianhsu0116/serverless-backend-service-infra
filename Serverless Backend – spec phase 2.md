# Serverless Backend – Phase 2 (Private API with Cognito + JWT)

## 0. Goal & Scope

在 Phase 2 中，基於現有 Phase 1 架構新增 **Private Admin API**，僅限已登入且具備 `admin` 權限的使用者呼叫。

本階段目標：

- 新增一條 **Private API**：
  - `GET /admin/hello`
  - 經由 **API Gateway (HTTP API) + JWT Authorizer (Cognito)** → **Lambda (ECR Image: `helloworld-private`)**
- 建立 **Cognito User Pool + App Client + Hosted UI** 供 Admin 登入。
- API Gateway 使用 **JWT Authorizer** 驗證 Cognito 發出的 JWT。
- 保持：
  - 既有 **多環境 (dev, prd)** 設計
  - 既有 **Terraform 專案結構與 modules** 設計
  - 既有 **tags / 命名規則 / function naming** 設計
- 務必注意：
  - 僅使用 "最小改動" 完成目標，不要改動到任何"非必要"的程式碼

---

## 1. Existing Baseline (Phase 1 Recap)

已存在的重點資源 (供實作 Phase 2 時"參考"，不需重複建立)：

- **API Gateway (HTTP API)**  
  - `name = "${project_name}-${ENV}-http-api"`
  - Stage：`name = "$default"`, `auto_deploy = true`
  - Public 路由：
    - `GET /hello` → Lambda `helloworld-${ENV}`

- **Lambda (Container Image)**  
  - `helloworld-${ENV}`，image 來源：
    - `image_uri = "${ecr_repo_prefix}/lambda/helloworld:${image_tag}"`

- **Lambda IAM Role**  
  - `name = "${project_name}-${ENV}-lambda-execution"`
  - 已附掛 `AWSLambdaBasicExecutionRole` (CloudWatch Logs)

- **Terraform 專案結構**  
  - Root：
    - `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`
    - `dev.tfvars`, `prd.tfvars`
    - `dev.env`, `prd.env`
  - Modules：
    - `modules/lambda_functions/`
    - `modules/http_apis/`
  - Tags：
    - `project`, `environment`, `managed_by`, 加上 per-component `Component` 等

---

## 2. 新增 Private API 的整體架構

### 2.1 新增的元件

1. **Cognito User Pool (per environment)**
2. **Cognito User Pool Client (App Client)**
3. **Cognito Hosted UI Domain**
4. **(可選) Cognito User Group：`admin`**
5. **新的 Lambda Function：`helloworld-private-${ENV}`**
6. **API Gateway JWT Authorizer (HTTP API 用)**
7. **HTTP API Private Route：`GET /admin/hello`**

### 2.2 Request 流程摘要

1. Admin 透過 Cognito Hosted UI 登入，取得 JWT (ID Token 或 Access Token)。
2. Admin 前端呼叫：

   - `GET /admin/hello`  
   - Header：`Authorization: Bearer <Cognito JWT>`

3. API Gateway：
   - 使用 JWT Authorizer 驗證 JWT (iss / aud / exp / 簽章)。
   - 驗證成功後，將 request + JWT claims 傳給 Lambda。

4. Lambda `helloworld-private-${ENV}`：
   - 從 event 的 JWT claims 取得使用者資訊 (例如 email / groups)。
   - 回傳一個簡單 JSON，確認私有 API 工作正常。

---

## 3. Cognito 設計需求

### 3.1 Cognito User Pool

每個環境建立一個 User Pool：

- 命名：
  - `user_pool_name = "${project_name}-${ENV}-user-pool"`
- 基本需求：
  - 支援 email-based login (username 為 email)
  - 啟用標準安全設定 (暫不需客製 MFA)

### 3.2 App Client

每個 User Pool 建立一個 App Client：

- 命名：
  - `app_client_name = "${project_name}-${ENV}-admin-client"`
- 需求：
  - 啟用對應的 OAuth / Hosted UI 設定，使 Admin 可以透過瀏覽器登入並取得 JWT。
  - 回傳 ID Token / Access Token (JWT)。

### 3.3 Hosted UI Domain

為每個環境開啟 Hosted UI：

- Domain 命名 (示意，實際以 AWS 命名規則為準)：
  - `${project_name}-${ENV}-auth`
- Hosted UI 登入成功後會 redirect 回指定 callback URL（例如 admin SPA 網址，暫可先用 placeholder）。

### 3.4 User Group (Admin)

在 User Pool 中建立一個群組供授權使用：

- Group 名稱：
  - `admin`
- 後續：
  - Admin 使用者加入此 group。
  - JWT 中的 `cognito:groups` claim 會包含 `"admin"`。

---

## 4. JWT Authorizer 設計 (API Gateway HTTP API)

在既有的 HTTP API 上新增 **JWT Authorizer**：

### 4.1 Authorizer 行為需求

- 類型：JWT Authorizer (HTTP API)
- 對應的 HTTP API：
  - 已存在的 `${project_name}-${ENV}-http-api`
- 設定：
  - `identity_source`：
    - `"$request.header.Authorization"`
  - `issuer` (`iss`)：
    - Cognito User Pool 的 issuer URL  
      (格式類似：`https://cognito-idp.<region>.amazonaws.com/<user_pool_id>`)
  - `audience` (`aud`)：
    - App Client ID (Cognito Client)

### 4.2 Route 授權策略

- Public route：
  - `GET /hello`
  - `authorization_type = NONE`
- Private route：
  - `GET /admin/hello`
  - `authorization_type = JWT`
  - `authorizer_id = <上述 JWT Authorizer>`

---

## 5. Private Lambda Function 設計 – `helloworld-private`

### 5.1 命名與部署

- Function 名稱：
  - `helloworld-private-${ENV}`
- Image 來源：
  - ECR 路徑規則與 Phase 1 一致，只是 image 名稱換成 `helloworld-private`：
    - `image_uri = "${ecr_repo_prefix}/lambda/helloworld-private:${image_tag}"`
- 掛載的 IAM Role：
  - 與其他 Lambda 共用：
    - `role = "${project_name}-${ENV}-lambda-execution"` 對應的 ARN
  - 目前僅需 CloudWatch Logs（與 Phase 1 相同）。

### 5.2 環境變數需求

延續 Phase 1 pattern，`helloworld-private` 應具有：

- 共通環境變數：
  - `ENV = ${ENV}`
  - `STAGE = ${ENV}`（若已存在）
- Private function 可選的額外 env（目前最低需求可為空，預留可擴充空間）。

### 5.3 行為需求 (邏輯層，不需寫 code)

Lambda `helloworld-private` 在被 `GET /admin/hello` 呼叫時：

- 接收由 API Gateway HTTP API (payload v2) 傳入的 event。
- 可以從 event 中讀取 JWT claims，例如：
  - `sub` (使用者 ID)
  - `email`
  - `cognito:groups` (包含 `"admin"`)

- 回應格式 (200 OK) 範例：

  - 回傳 JSON（邏輯描述即可，實作細節由 Cursor 產生）：
    - `message`: 確認為 admin hello API
    - `user`: 使用者的 email 或 sub

---

## 6. HTTP API – Route 與授權需求

### 6.1 Route 定義

在現有 HTTP API 上新增一條 Private route：

- `method`: `GET`
- `path`: `/admin/hello`
- 對應 Lambda：
  - `helloworld-private-${ENV}`
- 授權要求：
  - `authorization_type = JWT`
  - 使用新的 Cognito JWT Authorizer。
  - 僅允許 JWT 驗證成功的 request 通過。

### 6.2 Route 設定模式

延續現有 `routes` map 設計：

- 每條 route 需包含：
  - `path`
  - `method`
  - `lambda_name`（邏輯名稱，如 `helloworld-private`）
  - `auth_type`：
    - Public：`NONE`
    - Private：`JWT`

HTTP API module 內部負責：

- 根據 `auth_type` 決定：
  - `authorization_type`
  - `authorizer_id` 是否設為 JWT Authorizer 或 `null`
- 根據 `lambda_name` 從 `lambda_functions` module output 取得對應 Lambda 的 `invoke_arn`。

---

## 7. Terraform 模組調整需求 (Infra 層面)

### 7.1 modules/cognito/ (新增)

新增一個 `modules/cognito/` 模組，負責：

- 建立：
  - Cognito User Pool
  - Cognito User Pool Client (admin 用)
  - Hosted UI Domain
  - `admin` Group
- 對外輸出：
  - `user_pool_id`
  - `user_pool_arn`
  - `user_pool_issuer_url`
  - `admin_app_client_id`

根目錄 `main.tf`：

- 新增 `module "cognito"`，傳入：
  - `project_name`
  - `environment`
  - `region` (若需要)
  - `common_tags`

---

### 7.2 modules/lambda_functions/ (擴充)

在 `lambda_overrides` 中新增一個 entry：

- 邏輯名稱：`helloworld-private`
- 自訂設定：
  - `timeout` 視需要設定（可與 public helloworld 一致或略高）
  - `env_vars` = {
      TEST_SECRET = "Test Secret Value - private"
    }

該 module 已負責：

- 組出 `function_name = "${name}-${environment}"`。
- 組出 `image_uri = "${ecr_repo_prefix}/lambda/${name}:${image_tag}"`。
- 將所有 function metadata 以 map 方式 output 給其他 modules 使用。

---

### 7.3 modules/http_apis/ (擴充)

在 HTTP API module 中：

1. 新增一個 JWT Authorizer：

   - 使用 `cognito` module 輸出的：
     - `issuer_url`
     - `admin_app_client_id`
   - identity source 固定為 `"$request.header.Authorization"`。

2. 擴充 `routes` map 的結構，加入 `auth_type` 欄位：

   - Public route (`/hello`) → `auth_type = "NONE"`
   - Private route (`/admin/hello`) → `auth_type = "JWT"`

3. `aws_apigatewayv2_route` 建立時：

   - 根據 `auth_type`：
     - 設定 `authorization_type`
     - 若為 `JWT`，設定 `authorizer_id = <JWT Authorizer>`；否則 `null`。

4. Lambda Permission (Invoke)：

   - 確保 Private route 的 `source_arn` 仍精準限制在：
     - 此 HTTP API 的 Endpoint
     - 對應的 Method + Path (含 `$default` stage)

---

## 8. 測試驗收項目

### 8.1 Cognito / Hosted UI 測試

- 建立一個測試 Admin 使用者，加入 `admin` 群組。
- 透過 Hosted UI 登入，確認可以取得 JWT (ID Token / Access Token)。

### 8.2 Private API 行為驗證

1. **未帶 Token 呼叫：**

   - `GET /admin/hello` 不帶 Authorization header。
   - 預期回應：
     - HTTP 401 或 403 (由 API Gateway 控制)
     - Lambda 不應被觸發。

2. **帶無效 Token 呼叫：**

   - 帶過期或錯誤的 JWT。
   - 預期回應：
     - HTTP 401 / 403
     - Lambda 不應被觸發。

3. **帶有效 Admin Token 呼叫：**

   - 登入 Admin 後取得 JWT，帶入：
     - `Authorization: Bearer <valid JWT>`
   - 呼叫 `GET /admin/hello`。
   - 預期：
     - HTTP 200
     - 回傳 JSON 內容包含：
       - `message` 表示為 admin hello API
       - `env` 為 `dev` 或 `prd`
       - `user` 為 JWT 中的 email 或 sub

---
