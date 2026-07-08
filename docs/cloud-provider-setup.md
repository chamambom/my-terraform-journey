---
title: Cloud Provider Setup
nav_order: 7
---

# Cloud Provider Setup — Azure & AWS with Terraform

This page covers the setup and bootstrapping of Terraform for both Azure and AWS, including remote backend configuration, credential management, and provisioning workflows.

---

## Terraform Fundamentals

### Core Concepts

| Concept | Description |
|---|---|
| **Providers** | Represent a cloud provider (AWS, Azure) or local provider |
| **Resources** | Invoked to create/update infrastructure locally or in the cloud |
| **State** | A representation of the infrastructure created/updated by Terraform |
| **Data Sources** | Read-only resources used to query existing infrastructure |

### Essential Commands

| Command | Purpose |
|---|---|
| `terraform init` | Initialise a working directory and download plugins |
| `terraform plan` | Generate and display an execution plan |
| `terraform apply` | Build or change infrastructure |
| `terraform output` | Read an output from the state file |
| `terraform destroy` | Destroy Terraform-managed infrastructure |

---

## Remote Backend State

When working solo, the `.tfstate` file lives on your local machine. This breaks down with teams — multiple versions of state cause drift and conflicts.

**The solution:** Store state in a centralised remote backend that everyone shares.

| Provider | Backend Type | Storage |
|---|---|---|
| Azure | `azurerm` | Azure Blob Storage |
| AWS | `s3` | S3 bucket + DynamoDB for locking |

### Setup Steps (both providers)

1. Create the storage resource (Storage Account or S3 bucket)
2. Configure `backend` block in your `main.tf` to point to the remote state

> ⚠️ The remote backend storage is **stateful** — it must persist through the lifecycle of your code. Don't use Terraform to create its own backend storage (chicken-and-egg problem). Use a bootstrap script instead.

---

## Azure Setup — Bootstrapping

This section is **bootstrapping** — the one-time setup you must do *before* Terraform can manage anything in your Azure tenant. It's a classic chicken-and-egg problem:

> Terraform needs a Service Principal, Storage Account, and Key Vault to run — but those resources don't exist yet. You can't use Terraform to create the identity that Terraform itself needs to authenticate. So we bootstrap with PowerShell first, then hand over to Terraform for everything else.

Once bootstrapping is complete, Terraform uses the Service Principal and remote backend for all subsequent infrastructure provisioning.

### What Gets Bootstrapped

| Resource | Purpose |
|---|---|
| Service Principal | Terraform's identity in Azure AD — used to authenticate all API calls |
| Storage Account + Container | Hosts the remote `.tfstate` file |
| Key Vault | Stores sensitive credentials (client secret, access keys) outside of code |
| Key Vault Access Policies | Grants the Service Principal and your admin user access to secrets |

### Step 1: Prerequisites

1. [Install the Azure PowerShell module](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps)
2. Log in to Azure: `Connect-AzAccount`

### Step 2: Run the Bootstrap Script

1. Open `azure-scripts/ConfigureAzureForSecureTerraformAccess.ps1`
2. Update the `$adminUserDisplayName` variable to match your Azure AD admin display name
3. Run the script

The script creates:

- A Service Principal for Terraform (with Contributor role)
- A Resource Group, Storage Account, and Storage Container for state
- A Key Vault with access policies
- Key Vault secrets:
  - `ARM_SUBSCRIPTION_ID`
  - `ARM_CLIENT_ID`
  - `ARM_CLIENT_SECRET`
  - `ARM_TENANT_ID`
  - `ARM_ACCESS_KEY`

### Step 3: Load Secrets into Environment Variables

Run `azure-scripts/LoadAzureTerraformSecretsToEnvVars.ps1` to inject Key Vault secrets into your current PowerShell session.

> ⚠️ This only applies to the current session. Re-run after opening a new terminal.

### Step 4: Install Terraform

Either [download Terraform](https://learn.hashicorp.com/terraform/getting-started/install.html) directly, or via Chocolatey:

```powershell
choco install terraform
```

### Step 5: Provision Infrastructure

Once bootstrapped, Terraform manages everything else:

1. Navigate to `azure-examples/remote-backend/`
2. Update `storage_account_name` in the `backend` block of `main.tf`
3. Run:

```bash
terraform init
terraform plan
terraform apply
```

### Cleanup

```bash
terraform destroy
```

> If starting a new PowerShell session, re-run `LoadAzureTerraformSecretsToEnvVars.ps1` first.

---

## AWS Setup — Bootstrapping & Authentication

Like Azure, AWS has its own chicken-and-egg problem: Terraform needs IAM credentials to provision infrastructure, but those credentials and roles need to be created first. The difference is that AWS offers more flexibility in how you authenticate — and **temporary credentials via IAM roles are strongly preferred** over long-lived access keys.

### Authentication Methods (Best → Worst)

| Method | Security | Use Case |
|---|---|---|
| **IAM Identity Center (SSO)** | ✅ Best | Teams using AWS Organizations. Short-lived tokens, no keys to rotate. |
| **IAM Roles + AssumeRole** | ✅ Strong | Cross-account access, CI/CD pipelines. Temporary credentials with configurable session duration. |
| **Environment variables** | ⚠️ Acceptable | Local dev with short-lived tokens from SSO or STS. |
| **Static access keys** | ❌ Avoid | Long-lived, no expiry, high blast radius if leaked. Legacy only. |

### Recommended: AWS SSO with Granted

For local development, use [Granted](https://docs.commonfate.io/granted/getting-started) to manage AWS SSO profiles. This gives you temporary credentials that auto-refresh:

```bash
# Assume a profile (opens browser for SSO login)
assume my-dev-account

# Terraform automatically picks up the session credentials
terraform plan
```

### Using IAM Roles (CI/CD and Cross-Account)

In CI/CD pipelines or multi-account setups, Terraform assumes an IAM role rather than using static keys:

```hcl
provider "aws" {
  region = "ap-southeast-2"

  assume_role {
    role_arn     = "arn:aws:iam::123456789012:role/TerraformDeployRole"
    session_name = "terraform-ci"
  }
}
```

The pipeline authenticates with a base identity (e.g., GitHub OIDC, instance profile) and then assumes the deployment role. This gives you:

- **Temporary credentials** — tokens expire after the session (default 1 hour)
- **Least privilege** — the role only has permissions needed for that account/workload
- **Auditability** — CloudTrail logs show which role was assumed by whom

### Bootstrap: What You Create Manually

Before Terraform can manage an AWS account, you need to create:

| Resource | Purpose |
|---|---|
| S3 bucket | Remote state storage |
| DynamoDB table | State locking (prevents concurrent applies) |
| IAM role/user | Terraform's identity for API access |
| OIDC provider (CI/CD) | Allows GitHub Actions / GitLab to assume roles without static keys |

> ⚠️ Like Azure, these bootstrap resources are created outside of Terraform (via CLI, CloudFormation, or ClickOps) because Terraform can't create the identity it needs to authenticate.

### Example: Environment Variables (local dev fallback)

If you must use environment variables:

```bash
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_REGION="ap-southeast-2"
```

> ⚠️ Never hardcode credentials in `.tf` files. Never commit access keys to source control. Prefer SSO or IAM role assumption for all workflows.

---

## Code Examples

Browse the Terraform code in the repository:

| Provider | Code | Description |
|---|---|---|
| Azure | [AZURE-Terraform/](https://github.com/chamambom/my-terraform-journey/tree/main/AZURE-Terraform) | Hub-and-spoke, vWAN, utility snippets, Azure DevOps integration |
| AWS | [AWS-Terraform/](https://github.com/chamambom/my-terraform-journey/tree/main/AWS-Terraform) | ASG/LB patterns, remote backend examples |
