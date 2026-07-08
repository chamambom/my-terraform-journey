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

## Azure Setup

Secure **Azure** provisioning using Terraform with a [Remote Backend](https://www.terraform.io/docs/backends/types/azurerm.html) and [Key Vault](https://azure.microsoft.com/en-gb/services/key-vault/) for credential storage.

Terraform needs the Storage Account key to run `init`, `plan`, and `apply`. Rather than hardcoding it, we store it in Azure Key Vault.

### Step 1: Prerequisites

1. [Install the Azure PowerShell module](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps)
2. Log in to Azure: `Connect-AzAccount`

### Step 2: Configure Azure for Secure Terraform Access

1. Open `azure-scripts/ConfigureAzureForSecureTerraformAccess.ps1`
2. Update the `$adminUserDisplayName` variable to match your Azure AD admin display name
3. Run the script

The script creates:

- An Azure Service Principal for Terraform
- A Resource Group, Storage Account, and Storage Container
- A Key Vault with access policies
- Key Vault secrets for sensitive credentials:
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

## AWS Setup

### Step 1: Prerequisites

1. [Install the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
2. Authenticate via AWS SSO (using [Granted](https://docs.commonfate.io/granted/getting-started)) or access key + secret key

### Step 2: Configure AWS Provider

Use environment variables (recommended) or provider block configuration:

```hcl
provider "aws" {
  region = "us-west-2"
}
```

Set credentials via environment variables:

```bash
export AWS_ACCESS_KEY_ID="my-access-key"
export AWS_SECRET_ACCESS_KEY="my-secret-key"
export AWS_REGION="us-west-2"
```

> ⚠️ Never hardcode credentials in `.tf` files. Use environment variables, AWS SSO profiles, or a secrets manager.

---

## Code Examples

Browse the Terraform code in the repository:

| Provider | Code | Description |
|---|---|---|
| Azure | [AZURE-Terraform/](https://github.com/chamambom/my-terraform-journey/tree/main/AZURE-Terraform) | Hub-and-spoke, vWAN, utility snippets, Azure DevOps integration |
| AWS | [AWS-Terraform/](https://github.com/chamambom/my-terraform-journey/tree/main/AWS-Terraform) | ASG/LB patterns, remote backend examples |
