
# Network Architecture Requirements Specification – Serverless Backend Service

## 1. Document Overview

### 1.1 Purpose

This document describes the **network architecture requirements** for the Serverless Backend Service currently implemented on AWS using API Gateway (HTTP API) and Lambda. The goal is to introduce a **dedicated VPC** and related networking components in a way that is:

- Secure and aligned with AWS best practices.
- Cost‑effective for a low‑to‑medium traffic serverless workload.
- Flexible enough to support future additions such as RDS, ElastiCache, or other private services.

This specification intentionally **does not contain any code**. It focuses on **what** needs to be built, not **how** to implement it in Terraform.

### 1.2 Scope

In scope:

- Design and requirements for a new dedicated VPC.
- Public and private subnets across multiple Availability Zones (2).
- Internet access via Internet Gateway for public subnets.
- Outbound internet access for private subnets via a NAT Gateway.
- Route tables, routing rules, and subnet associations.
- Security groups for Lambda functions.
- Integration requirements between the new VPC and existing Lambda functions.

Out of scope (for this phase):

- Detailed Terraform implementation.
- Database creation (RDS, Aurora, DynamoDB tables, etc.).
- Private connectivity to on‑prem or other VPCs (no Transit Gateway / VPC peering in this phase).
- WAF, CloudFront, and advanced security features (may be specified in a later phase).


## 2. Context and Current Architecture

### 2.1 Current Backend Architecture

The existing backend uses:

- **API Gateway HTTP API**
  - Example routes:
    - `GET /hello` (public, no auth)
    - `GET /admin/hello` (private, JWT auth via Cognito)
- **AWS Lambda**
  - Deployed as container images from ECR.
  - Currently **not attached to any customer-managed VPC** (running in AWS-managed networking).
- **Amazon Cognito**
  - User Pool and Admin app client for `/admin` APIs.

There is **no customer-managed VPC** defined in the current Terraform code. No RDS, ElastiCache, or other VPC-based resources are present yet.

### 2.2 Motivation for Introducing a VPC

While Lambda and HTTP API can run without a customer-managed VPC, there are reasons to introduce a dedicated VPC:

- Prepare for **future private resources** (e.g., RDS, ElastiCache) that must not be publicly accessible.
- Gain **consistent network control** (subnet layout, routing, security groups) under Infrastructure as Code.
- Avoid using the **default VPC** for production-grade workloads, in line with AWS best practices for isolation and least privilege.

This design should, however, remain **cost‑conscious** and avoid unnecessary complexity for the current scale.


## 3. High-Level Network Design

### 3.1 Design Goals

1. **Isolation**: Application resources should run in a dedicated VPC, not in the default VPC.
2. **Security**:
   - Lambda functions should run in **private subnets** (no direct inbound internet access).
   - Outbound internet access should be controlled via a **NAT Gateway**.
3. **Availability**:
   - Use **at least 2 Availability Zones** to avoid single‑AZ dependency.
4. **Cost Effectiveness**:
   - Start with a **single NAT Gateway** shared by private subnets (accepting a trade‑off between high availability and cost).
5. **Future-proofing**:
   - Subnet layout and VPC design should be able to accommodate future services (e.g., RDS in private subnets, S3/DynamoDB via VPC endpoints later).

### 3.2 Target Topology (Conceptual)

- One dedicated **VPC** with a `/16` CIDR (e.g., `10.0.0.0/16`).
- Two Availability Zones (e.g., `us-west-2a`, `us-west-2b`).
- For each AZ:
  - **Public subnet** (e.g., `/24`) for NAT Gateway and any future public-facing resources.
  - **Private subnet** (e.g., `/24`) for Lambda and any future private resources (RDS, etc.).
- **Internet Gateway (IGW)** attached to the VPC for ingress/egress from public subnets.
- **NAT Gateway** placed in one of the public subnets to provide outbound internet access for private subnets.
- **Route tables**:
  - Public route table: default route to IGW.
  - Private route table: default route to NAT Gateway.
- **Security groups** for Lambda:
  - Outbound open to the internet (for calling external APIs, AWS public endpoints).
  - Inbound initially closed (no direct incoming connections expected to Lambda).


## 4. Detailed Requirements

### 4.1 VPC

**Requirement VPC-1**: Create a dedicated VPC for the Serverless Backend Service.

- The VPC must have:
  - A configurable CIDR block (default: `10.0.0.0/16`).
  - DNS support and DNS hostnames enabled.
- The VPC must not be the default VPC.
- The VPC must be tagged with:
  - `Name = <project_name>-<environment>-vpc`
  - Common tags: project name, environment, and any existing tagging conventions.

### 4.2 Availability Zones

**Requirement AZ-1**: The network must use **at least 2 Availability Zones** in the target region.

- The exact AZ names should be derived dynamically from the region (e.g., the first two available AZs).
- All subnets (public and private) must be distributed evenly across these AZs.

### 4.3 Subnets

#### 4.3.1 Public Subnets

**Requirement SUBNET-PUB-1**: Create **one public subnet per selected AZ**.

- Each public subnet must:
  - Belong to the dedicated VPC.
  - Have a unique, non-overlapping CIDR block (e.g., `/24` each).
  - Be configured to **assign public IP addresses on launch** (for future resources that may require public IPs).
- Public subnets must be tagged to clearly indicate:
  - `Tier = public`
  - AZ index (e.g., `public-0`, `public-1`).

#### 4.3.2 Private Subnets

**Requirement SUBNET-PRIV-1**: Create **one private subnet per selected AZ**.

- Each private subnet must:
  - Belong to the dedicated VPC.
  - Have a unique, non-overlapping CIDR block, separate from public subnets (e.g., `/24` each).
  - **Not** automatically assign public IP addresses.
- Private subnets must be tagged to indicate:
  - `Tier = private`
  - AZ index (e.g., `private-0`, `private-1`).

#### 4.3.3 Subnet CIDR Layout

**Requirement SUBNET-CIDR-1**: The specific CIDR ranges must be:

- Configurable via variables.
- Non-overlapping within the VPC.
- Large enough to accommodate foreseeable growth in Lambda concurrency and future services.

A suggested default layout (for documentation only):

- VPC: `10.0.0.0/16`
- Public subnets:
  - `10.0.0.0/24` (AZ 1)
  - `10.0.1.0/24` (AZ 2)
- Private subnets:
  - `10.0.10.0/24` (AZ 1)
  - `10.0.11.0/24` (AZ 2)


### 4.4 Internet Gateway (IGW)

**Requirement IGW-1**: Attach an Internet Gateway to the new VPC.

- The IGW must be associated only with the dedicated VPC.
- It must be used as the target for `0.0.0.0/0` routes in the **public** route table.
- It must be tagged consistently with existing conventions.


### 4.5 NAT Gateway and Elastic IP

**Requirement NAT-1**: Provide outbound internet access for **private subnets** via a NAT Gateway.

- There must be **at least one NAT Gateway** created in one of the public subnets.
- The NAT Gateway must have:
  - An associated Elastic IP address.
- Both the NAT Gateway and its EIP must be tagged with the project’s common tags.

**Requirement NAT-2 (Cost Consideration)**: For cost effectiveness:

- Initially deploy **only one NAT Gateway**.
- All private subnets should use this NAT Gateway for outbound internet access, accepting the risk that if the NAT’s AZ fails, outbound access for private subnets may be temporarily unavailable.
- The design must allow adding a second NAT Gateway in another AZ at a later stage without refactoring the entire module.


### 4.6 Route Tables and Routes

#### 4.6.1 Public Route Table

**Requirement RT-PUB-1**: Create a route table for public subnets.

- Default route (`0.0.0.0/0`) must point to the Internet Gateway.
- All public subnets must be associated with this route table.

#### 4.6.2 Private Route Table

**Requirement RT-PRIV-1**: Create a route table for private subnets.

- Default route (`0.0.0.0/0`) must point to the NAT Gateway.
- All private subnets must be associated with this route table.
- There must be no direct route from private subnets to the Internet Gateway.


### 4.7 Security Groups

#### 4.7.1 Lambda Security Group

**Requirement SG-LAMBDA-1**: Create a dedicated security group for Lambda functions.

- The security group must be associated with the new VPC.
- Initial inbound rules:
  - No inbound access is required for Lambda (functions are invoked by AWS services, not via direct inbound traffic), so inbound traffic can be left as default deny.
- Outbound rules:
  - Allow outbound traffic to `0.0.0.0/0` on all ports/protocols.
  - This is required for:
    - Calling external APIs.
    - Accessing AWS public endpoints (e.g., S3, DynamoDB, Cognito, API Gateway, etc.).

**Requirement SG-LAMBDA-2 (Future)**: The design must allow:

- Additional security groups to be created later for services such as RDS or ElastiCache.
- Inbound rules to be added from the Lambda security group to these services, implementing least-privilege access at network level.


## 5. Integration with Existing Backend Components

### 5.1 Lambda Functions

**Requirement LAMBDA-VPC-1**: All backend Lambda functions that require outbound internet access and/or private resource access must be configured to run inside the new VPC.

- Lambda functions must be configured to use:
  - Private subnet IDs from the new VPC.
  - The Lambda-specific security group created in this design.
- No Lambda function should be configured to use public subnets.

**Requirement LAMBDA-VPC-2**: Attaching Lambda functions to the VPC must not break their ability to:

- Call external APIs (through NAT Gateway).
- Call AWS public endpoints (S3, DynamoDB, Cognito, API Gateway, etc.).


### 5.2 API Gateway HTTP API

**Requirement APIGW-1**: The API Gateway HTTP API will remain:

- Publicly accessible on the internet.
- Not directly attached to the VPC (HTTP API is a managed public endpoint).

**Requirement APIGW-2**: Existing routes and integrations must continue to function after Lambda is moved into the VPC, provided that the Lambda VPC configuration is correct.

### 5.3 Cognito

**Requirement COGNITO-1**: Cognito User Pools, Hosted UI, and OAuth endpoints remain **public AWS-managed services** and are not part of the new VPC design.

- No VPC connectivity is required for Cognito at this stage.
- Lambda functions must still be able to call Cognito endpoints via outbound internet through the NAT Gateway if needed.


## 6. Non-Functional Requirements

### 6.1 Security

- No workloads in this project should run in the **default VPC**.
- Lambda functions must be isolated in private subnets.
- Outbound internet access from private subnets must be via a NAT Gateway, not via public IPs on private resources.
- The design must support adding additional security layers (e.g., VPC endpoints, security group rules, NACLs) without major redesign.

### 6.2 Availability

- Use at least **two Availability Zones** for subnets to reduce single‑AZ risk.
- Single NAT Gateway is acceptable for this phase for cost reasons, but the design must make it easy to add more NAT Gateways later if higher availability is required.

### 6.3 Cost

- Minimize ongoing cost by:
  - Using a single NAT Gateway initially.
  - Avoiding unnecessary resources (no ALB, no extra NATs, no Transit Gateway in this phase).
- Design must support incremental upgrades: additional NAT Gateways, VPC endpoints, etc., only when justified by scale or security needs.

### 6.4 Observability

- The network module should be compatible with existing logging and monitoring (CloudWatch for Lambda, API Gateway logs).
- No additional network-level logging (e.g., VPC Flow Logs) is required in this phase, but the VPC design must support enabling them in the future.


## 7. Migration and Rollout Considerations

### 7.1 Order of Implementation

1. **Create the new network module and VPC resources**:
   - VPC, subnets, IGW, NAT, route tables, security group.
2. **Update Lambda configuration** to use the private subnets and Lambda security group.
3. **Deploy changes** to a non‑production environment (e.g., `dev`) and verify:
   - Lambda can still process incoming API Gateway requests.
   - Lambda can reach required external services via outbound internet (through NAT).
4. After verification, **roll out to production environment** following the same steps.

### 7.2 Rollback Strategy

- If Lambda functions fail to start or lose internet access after the change:
  - Revert Lambda VPC configuration to the previous state (no VPC attachment).
  - Keep the VPC resources in place for further troubleshooting, or temporarily destroy them if necessary.
- Ensure that deployments are done incrementally (e.g., environment by environment) to reduce blast radius.


## 8. Acceptance Criteria

The implementation of this specification will be considered successful when:

1. A dedicated VPC exists with:
   - Correct CIDR range.
   - At least 2 public and 2 private subnets across 2 AZs.
   - An Internet Gateway attached.
   - A NAT Gateway deployed in a public subnet.
   - Public and private route tables configured with correct default routes.
2. Lambda security group exists and is used by backend Lambdas.
3. Backend Lambda functions run in private subnets and can:
   - Receive traffic via API Gateway HTTP API integrations.
   - Call external internet resources (via NAT Gateway) as needed.
4. No project workloads depend on the default VPC.
5. All changes are deployed and verified in at least one non‑production environment before production rollout.

## 9. Notes
Please keep the **minimum modification** of existing code