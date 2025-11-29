# Serverless Backend – Phase 1 開發需求書

## 0. 目標與範圍

本需求書目的是定義一套 **可擴充的 Serverless Backend 基礎架構**，目前先完成 **最小可行版本 (Phase 1)**：

- 建立一條 **Public API**：  
  - `GET /hello`  
  - 透過 **API Gateway (HTTP API)** → **Lambda (使用 ECR Container Image)** → 回傳 JSON
- 使用 **Terraform** 管理所有 AWS 資源。
- 專案需具備良好擴充性，未來可輕鬆新增：
  - 更多 Lambda Functions
  - 更多 API Gateway 路徑（Public & Private）
  - Cognito + JWT Authorizer（Private API）
  - DB (DynamoDB / Aurora v2)、IAM policies、Monitoring、Logging 等。

同時需支援 **多環境 (dev, prd)**，並透過：

- `dev.tfvars`, `prd.tfvars`
- `dev.env`, `prd.env`

來管理 Terraform 變數與部署環境。

---

## 1. 架構總覽 (Phase 1)

### 1.1 AWS 架構組件

Phase 1 要建置的實際資源：

- **API Gateway (HTTP API)**  
  - 協定：`HTTP`（不是 REST API）  
  - 路徑：`GET /hello`  
  - Stage：使用 `$default`，`auto_deploy = true`

- **AWS Lambda (Container Image)**  
  - 使用既有 ECR Image：
    - `302242949304.dkr.ecr.us-west-2.amazonaws.com/lambda/helloworld:g25efc506`
  - Node.js 實作（已打包在 image 中）
  - Lambda 以 `AWS_PROXY` 模式整合到 HTTP API
  - Lambda function name 要用環境 (ENV) 當結尾（例如 `helloworld-dev`）

注意，Terraform 端請不要把整串 image URI / function name 寫死在程式碼裡，而是透過以下變數組合：

- `ecr_repo_prefix`：例如 `302242949304.dkr.ecr.us-west-2.amazonaws.com`
- `image_tag`：例如 `g25efc506`
- `ENV`：例如 `dev`

Lambda 的 `image_uri` 組合為：  
`"${var.ecr_repo_prefix}/lambda/helloworld:${var.image_tag}"`

Lambda 的 `function_name` 組合為：  
`"helloworld-${var.ENV}"`

以上三個變數會在 `dev.tfvars` / `prd.tfvars` / `dev.env` / `prd.env` 中給值。  
**實際有哪些 Lambda functions（目前只有一個 helloworld，未來會新增更多）請在 `modules/lambda_functions` 裡用 locals 定義，不在 root module 直接硬寫多個 `aws_lambda_function`。**

- **AWS IAM Role**
  - 建立一個 Lambda execution role
  - 附加 `AWSLambdaBasicExecutionRole`（CloudWatch Logs）

- **CloudWatch Logs**
  - Lambda execution logs

> Phase 1 **不需要** Cognito、WAF、DB、SES 等，但 Terraform 架構需預留未來加入的空間。

---

## 2. API 行為規格

### 2.1 Public API：`GET /hello`

- **路徑**：`/hello`
- **方法**：`GET`
- **驗證**：不需要（Public）
- **回應格式**：`application/json`
- **成功回應範例 (HTTP 200)**：

```json
{
  "message": "hello world",
  "stage": "dev"
}
```
---

## 3. Terraform 專案結構與模組設計

### 3.1 專案結構
```
serverless-backend-service-infra/
├─ main.tf
├─ variables.tf
├─ outputs.tf
├─ dev.tfvars
├─ prd.tfvars
├─ dev.env
├─ prd.env
└─ modules/
   ├─ lambda_functions/
   │  ├─ main.tf
   │  ├─ variables.tf
   │  └─ outputs.tf
   └─ http_apis/
      ├─ main.tf
      ├─ variables.tf
      └─ outputs.tf
```

未來擴充時，可以在 modules/ 下新增：
- cognito/
- dynamodb/
- aurora/
- waf/
- monitoring/
等模組。

### 3.2 根目錄 Terraform 設定
需求重點：
- 使用 aws provider
- 使用 module：modules/lambda_functions、modules/http_apis。
- 透過 variables.tf + dev.tfvars / prd.tfvars 注入環境參數（專案名稱、region、ECR prefix、version、ENV 等）。
- root module 的責任是「組裝」：
  - 傳入共用設定（如 project_name, ENV, ecr_repo_prefix, version）。
  - 呼叫 module "lambda_functions" 與 module "http_apis"。
- 「有哪些 Lambda functions / APIs」的實際清單，放在各自的 module（modules/lambda_functions, modules/http_apis）中用 locals/for_each 定義，不在 root 的 main.tf 中展開一大堆 map。


### 3.3 模組實作設計重點

以下幾點務必注意：
- 在 modules/lambda_functions 以及 modules/http_apis 這兩個 folder 中，需要設計成可以簡單地添加更多 functions 和 APIs：
  - modules/lambda_functions：
    - 使用 locals 定義：
      - 一個共用的 lambda_defaults（例如 default timeout/memory/env）。
      - 一個 lambda_overrides map，列出本專案所有 Lambda（目前至少包含 helloworld 這一隻），每一隻可以 override defaults。
    - 使用 for_each + map 實際建立多個 aws_lambda_function 和對應 IAM Role。
    - 也就是：Lambda 的「清單 + 各自的客製配置」集中在 module 內部，不在 root module。
  - modules/http_apis：
    - 使用 locals 定義：
      - 一個包含所有 routes 的 routes map（例如目前 GET /hello，未來再加 /public/forms/inquiry、/admin/blog-posts 等）。
    - 使用 for_each + map 建立：
      - 單一 HTTP API (aws_apigatewayv2_api)。
      - 多個 integration / route / lambda permission（每條路徑對應一個既有的 Lambda）。
    - 同樣地，API 路徑的「清單與設定」集中在 module 內部，而不是在 root module 寫一堆 route 定義。
- 在每個 API 建立時指定的那一個 Lambda function ARN / name 不能寫死字串：
  - 需透過 modules/lambda_functions 的 outputs 取得（例如 lambda_function_names、lambda_arns 等），再被 modules/http_apis 使用。
  - root module 不應該直接拼接 Lambda ARN 字串。
- 請使用「最簡單」但維護性又高的方式撰寫：
  - 建議使用：
    - locals + map(object) + for_each + merge / coalesce 這種 pattern，
      - 避免過度抽象或過度 template 化的設計（不要 overdesign）。
  - 目標是：
    - 未來要新增一隻 Lambda 或一條 API，只需要在對應 module 的 locals 中 新增一筆 entry，而不需要新增新的 module block 或 resource block。
- 請先參考我目前在這個 folder 中已經建立好的檔案結構與命名方式後，再開始開發，確保命名 / 變數風格一致。

