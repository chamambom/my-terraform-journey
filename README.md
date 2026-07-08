# My Terraform (AWS/Azure) best practices

##### This repository is inspired by Adam Rush's work, particularly the bootstrapping code required to set up "Azure resources for Terraform Use" (further details are provided below).

##### I've customized the bootstrapping code for my own use, refactored certain sections, incorporated Azure & AWS code snippets to reference, and eliminated deprecated code to align with the latest Terraform updates.

    Author:  Adam Rush
    Blog:    https://adamrushuk.github.io
    GitHub:  https://github.com/adamrushuk
    Twitter: @adamrushuk

---

## AI-Assisted Infrastructure as Code: New Ways of Working in Cloud Platform Engineering

This section documents how I've integrated AI tooling into my daily Cloud Platform Engineering workflow — using Model Context Protocol (MCP) servers, AI coding assistants, and automated code review to accelerate infrastructure-as-code development.

- [MCP Server Architectures](docs/mcp-server-architectures.md) — How different MCP servers are configured (stdio, Docker, HTTP remote, proxy)
- [Atlassian MCP Authentication](docs/atlassian-mcp-authentication.md) — How the Atlassian Rovo MCP Server uses OAuth 2.1
- [My MCP Configuration](docs/my-mcp-configuration.md) — How I globalise my MCP config and why

---

### Why This Matters

Infrastructure as Code (IaC) has always been about codifying cloud operations. AI assistants don't replace the engineer — they eliminate the repetitive parts: searching docs, writing boilerplate, cross-referencing resources, and catching configuration drift. The human still designs the system, makes the decisions, and owns the outcome.

### Tooling

| Tool | Purpose | Notes |
|---|---|---|
| [Kiro CLI](https://kiro.dev) | AI coding assistant (terminal) | Primary tool for IaC authoring, code review, and AWS operations |
| [GitHub Copilot](https://github.com/features/copilot) | AI coding assistant (IDE) | Used interchangeably with Kiro — functionally similar for IaC work |
| [Atlassian Rovo MCP Server](https://mcp.atlassian.com) | Jira + Confluence integration | Read/write tickets and docs from the terminal |
| [AWS MCP Server](https://github.com/awslabs/mcp) | AWS CLI + docs via MCP | Multi-account/region AWS operations with credential proxy |
| [Terraform MCP Server](https://github.com/hashicorp/terraform-mcp-server) | Terraform registry search + docs | Provider/module lookup, runs in Docker |
| GitHub PR reviews | Code review | Push to GitHub, review via PR process |

### Key Principles

1. **MCP servers are cheap** — they only consume context when you call them. Having 5+ configured costs nothing until you invoke a tool.
2. **Globalise your config** — shared MCP config at `~/.kiro/settings/mcp.json` means every workspace gets the same tools without per-project setup.
3. **AI is the junior engineer** — it writes the code, you review and approve. The mental model is pair programming where you're always the senior.
4. **Push to GitHub for review** — AI-generated code goes through the same PR process as hand-written code. No shortcuts on review.

This repository contains Terraform code snippets and notes on best practices that I often use when working with AWS or Azure.

##### Background:

This repository was initiated in 2021 during my tenure (2015-2022) at a Cloud Service Provider (CSP), where I led a team of Cloud Delivery engineers operating remotely across Southern Africa markets - SouthAfrica, DRC, Zimbabwe, Zambia, and Botswana. Our clientele comprised both "Managed cloud customers" and "Unmanaged cloud customers." 

> Managed cloud customers - customers who would allow the CSP to deploy Platform & Application landing zones for a customer then handover an already secure governed cloud for them to deploy their workloads on. 

> Unmanaged cloud customers - customers that prefer managing their own AWS/Azure environments. All they needed was Tenant or Subscription provisioning.

Tools used in the Continous Intergration/Deployment/Delivery (CI/CD):
- Terraform & Azure Repos for Azure deployments. 
- Terraform & GitHub actions for AWS environments.

> Terraform enables you to safely and predictably create, change, and improve infrastructure.

### Terraform Terminology

Remember these four bullet points!

    - Providers represent a cloud provider or a local provider
    - Resources can be invoked to create/update infrastructure locally or in the cloud
    - State is representation of the infrastructure created/updated by Terraform
    - Data Sources are “read-only” resources

There are 5 main commands within Terraform

    - Terraform Init:- Allows you to initialise a terraform working directory
    - Terraform Plan:- Generates an shows an execution plan
    - Terraform Apply:- Builds or changes infrastructure
    - Terraform Output:- Read an output from state file
    - Terraform Destroy:- Destroy Terraforms infrastructure

### Remote Backend State with Terraform and Azure blob and AWS S3 Storage

Developing Infrastructure code as a single developer result in the tfstate file being created and maintained on the local development computer.  This is fine for a team of one, but having multiple versions of a state file can become an issue as more people join the team. I will show how to use a remote backend state on Azure Storage to host shared state files. 

How do we address potential issues when working in a team to deploy infrastructure as code? We use a centralized state file that everyone has access to.

There are two steps to follow.  

> we need to create a storage account.
> we configure the main.tf to use the remote state location.

NB - I will not be using Terraform to create the storage account.  Terraform could be 
used, it will work the same.  The remote state is stateful, meaning the data needs to persist through the lifecycle of the code.  We can’t simply delete and recreate the storage account without removing the state file. Because of that, in this example i will use powershell.

Terraform needs rights to access the storage account when running the terraform init, plan, and apply commands.We will use the storage account key for this.  We could add the key to the main.tf file, but that would go against best practices of keeping security strings out of code. We will host the Storage Account key in Azure Key Vault. 

Test secure **Azure** provisioning using **Terraform**,
utilising a [Remote Backend](https://www.terraform.io/docs/backends/types/azurerm.html) and a
[Key Vault](https://azure.microsoft.com/en-gb/services/key-vault/) in Azure.

## Preparation

Before you can securely use Terraform with Azure, you will need to action the following steps:

### Install Azure Dependencies / Log in to Azure

1. [Install the Azure PowerShell module](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps).
1. Ensure you are logged in to Azure (eg. `Connect-AzAccount`)

### Configure Azure for Secure Terraform Access

1. Open `azure-scripts\ConfigureAzureForSecureTerraformAccess.ps1` and update the `$adminUserDisplayName` variable to
match your Admin User Display Name (eg. `Martin Chamambo`).
1. Run `azure-scripts\ConfigureAzureForSecureTerraformAccess.ps1`

The `ConfigureAzureForSecureTerraformAccess.ps1` script does the following:

1. Creates an Azure Service Principle for Terraform.
1. Creates a new Resource Group.
1. Creates a new Storage Account.
1. Creates a new Storage Container.
1. Creates a new Key Vault.
1. Configures Key Vault Access Policies.
1. Creates Key Vault Secrets for these sensitive Terraform login details:
     - ARM_SUBSCRIPTION_ID
     - ARM_CLIENT_ID
     - ARM_CLIENT_SECRET
     - ARM_TENANT_ID
     - ARM_ACCESS_KEY

### Load Azure Key Vault secrets into Terraform environment variables

Now that Azure has been configured for secure Terraform access, the Key Vault secrets need to be loaded into
environment variables, but only for the current PowerShell session.

1. Run `azure-scripts\LoadAzureTerraformSecretsToEnvVars.ps1`

### Install Terraform

Either [download Terraform and add to your path](https://learn.hashicorp.com/terraform/getting-started/install.html)
, or use the Chocolatey method below:

1. [Install Chocolatey](https://chocolatey.org/docs/installation)
1. Install Terraform: `choco install terraform`

## Provisioning

Now that Terraform is installed, the secure remote backend can be utilised whilst provisioning an Azure Resource Group and a Virtual Network:

1. Navigate to the `azure-examples\remote-backend\` folder.
1. Open `main.tf` and ensure you have updated the `storage_account_name` variable in the `backend` code block, to the new Storage Account Name created by the `ConfigureAzureForSecureTerraformAccess.ps1` script.
1. Initialise the Remote Backend and download plugins: `terraform init`
1. Create an execution plan (see planned changes): `terraform plan`
1. Apply the Terraform configuration: `terraform apply`
1. Enter `yes` to confirm the planned actions.

## Cleanup

You should now have a new Azure Resource Group (eg: `backend-test-rg`) with a Virtual Network (eg: `test-vnet`).
To cleanup these Azure resources, you can also use Terraform to destroy what it created.

1. If this is a new PowerShell session, you will have to run `scripts\LoadAzureTerraformSecretsToEnvVars.ps1` again
to reload the environment variables needed to Terraform to access Azure.
1. Navigate to the `azure-examples\remote-backend\` folder.
1. Remove the previously created Azure resources: `terraform destroy`
1. Enter `yes` to confirm the planned actions.


######################################################################################

### Configure AWS for Secure Terraform Access

## Preparation

Before you can securely use Terraform with AWS, you will need to action the following steps:

### Install AWS Dependencies / Log into AWS

1. [Install the AWS CLI module](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps).
1. Ensure you are logged in to AWS (eg. `using AWS access key and secret key`)

### Configure AWS for Secure Terraform Access

I mostly using the AWS secret and access environmental variables. I will adapt this part to incorporate AWS secrets manager 

    provider "aws" {
        region     = "us-west-2"
        access_key = "my-access-key"
        secret_key = "my-secret-key"
    }