Serverless backend infrastructure for Phase 1: HTTP API Gateway → Lambda (ECR image) with dev/prd environments managed via Terraform modules.

1) Prepare environment variables  
   - Dev: `source dev.env`  
   - Prod: `source prd.env`

2) Initialize Terraform  
   ```bash
   terraform init
   ```

3) (Optional) Select or create a workspace  
   ```bash
   terraform workspace select dev || terraform workspace new dev
   ```

4) Plan changes  
   ```bash
   export $(grep -v '^#' dev.env | tr '\n' ' ') && terraform plan -var-file=dev.tfvars
   ```

5) Apply changes  
   ```bash
   export $(grep -v '^#' dev.env | tr '\n' ' ') && terraform apply -var-file=dev.tfvars
   ```

6) Destroy resources  
   ```bash
   export $(grep -v '^#' dev.env | tr '\n' ' ') && terraform destroy -var-file=dev.tfvars
   ```

- Replace `dev` with `prd` files when targeting production.
