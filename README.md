# My Terraform (AWS/Azure) best practices

##### This repository is inspired by Adam Rush's work, particularly the bootstrapping code required to set up "Azure resources for Terraform Use" (further details are provided below).

##### I've customized the bootstrapping code for my own use, refactored certain sections, incorporated Azure & AWS code snippets to reference, and eliminated deprecated code to align with the latest Terraform updates.

    Author:  Adam Rush
    Blog:    https://adamrushuk.github.io
    GitHub:  https://github.com/adamrushuk
    Twitter: @adamrushuk

This repository contains Terraform code snippets and notes on best practices that I often use when working with AWS or Azure.

##### Background:

This repository was initiated in 2021 during my tenure (2015-2022) at a Cloud Service Provider (CSP), where I led a team of Cloud Delivery engineers operating remotely across Southern Africa markets - SouthAfrica, DRC, Zimbabwe, Zambia, and Botswana. Our clientele comprised both "Managed cloud customers" and "Unmanaged cloud customers." 

> Managed cloud customers - customers who would allow the CSP to deploy Platform & Application landing zones for a customer then handover an already secure governed cloud for them to deploy their workloads on. 

> Unmanaged cloud customers - customers that prefer managing their own AWS/Azure environments. All they needed was Tenant or Subscription provisioning.

Tools used in the Continous Intergration/Deployment/Delivery (CI/CD):
- Terraform & Azure Repos for Azure deployments. 
- Terraform & GitHub actions for AWS environments.

> Terraform enables you to safely and predictably create, change, and improve infrastructure.

---

## AI-Assisted Infrastructure as Code: New Ways of Working in Cloud Platform Engineering

This section documents how I've integrated AI tooling into my daily Cloud Platform Engineering workflow — using Model Context Protocol (MCP) servers, AI coding assistants, and automated code review to accelerate infrastructure-as-code development.

- [MCP Server Architectures](docs/mcp-server-architectures.md) — Transport patterns: stdio, Docker, HTTP remote, proxy
- [Atlassian MCP Authentication](docs/atlassian-mcp-authentication.md) — OAuth 2.1 flow, scopes, troubleshooting
- [My MCP Configuration](docs/my-mcp-configuration.md) — Globalised config, design decisions, cost model
- [PR Workflow](docs/pr-workflow.md) — Feature branch strategy, CI checks, AI + human review

---

### Why This Matters

Infrastructure as Code (IaC) has always been about codifying cloud operations. AI assistants don't replace the engineer — they eliminate the repetitive parts: searching docs, writing boilerplate, cross-referencing resources, and catching configuration drift. The human still designs the system, makes the decisions, and owns the outcome.

### Tooling

| Tool | Purpose | Notes |
|---|---|---|
| [Terraform](https://www.terraform.io/) | Infrastructure as Code | Core IaC tool for all cloud provisioning |
| [Terramate](https://terramate.io/) | Stack orchestration | Manages multi-account, multi-region Terraform stacks |
| [Kiro CLI](https://kiro.dev) | AI coding assistant (terminal) | Primary tool for IaC authoring and AWS operations |
| [VS Code](https://code.visualstudio.com/) + Kiro IDE | Editor + AI assistant | Used interchangeably with Kiro CLI |
| [GitHub Copilot](https://github.com/features/copilot) | AI coding assistant | Used interchangeably with Kiro — functionally equivalent for IaC |
| [GitHub CLI (`gh`)](https://cli.github.com/) | Git workflow automation | PR creation, review requests, merge operations |
| [Granted](https://docs.commonfate.io/granted/getting-started) | AWS credential management | Multi-account SSO profile management |
| [Atlassian Rovo MCP Server](https://mcp.atlassian.com) | Jira + Confluence via MCP | Read/write tickets and docs from the terminal |
| [AWS MCP Server](https://github.com/awslabs/mcp) | AWS operations via MCP | Multi-account/region operations with credential proxy |
| [Terraform MCP Server](https://github.com/hashicorp/terraform-mcp-server) | Registry search + docs | Provider/module lookup, runs in Docker |
| [pre-commit](https://pre-commit.com/) | Git hooks | Format checks, linting, secret scanning before commit |
| [Gitleaks](https://github.com/gitleaks/gitleaks) | Secret scanning | Prevents credentials from being committed |
| [TFLint](https://github.com/terraform-linters/tflint) | Terraform linter | Catches errors and enforces conventions |

### Key Principles

1. **MCP servers are cheap** — they only consume context when you call them. Having 5+ configured costs nothing until you invoke a tool.
2. **Globalise your config** — shared MCP config at `~/.kiro/settings/mcp.json` means every workspace gets the same tools without per-project setup.
3. **AI is the junior engineer** — it writes the code, you review and approve. The mental model is pair programming where you're always the senior.
4. **Push to GitHub for review** — AI-generated code goes through the same PR process as hand-written code. No shortcuts on review.
5. **Terramate for orchestration** — stacks are organised by account/region/service. Terramate handles code generation, change detection, and deployment ordering.

---

## Cloud Provider Setup & Examples

For detailed Azure and AWS Terraform setup instructions (remote backends, credential management, provisioning), see:

- **[Cloud Provider Setup](docs/cloud-provider-setup.md)** — Azure Key Vault backend, AWS credentials, bootstrapping
- **[Azure Examples](AZURE-Terraform/)** — Hub-and-spoke, vWAN, utility snippets, Azure DevOps integration
- **[AWS Examples](AWS-Terraform/)** — ASG/LB patterns, remote backend
- **[Terraform Best Practices](README-TERRAFORM-BEST-PRACTICES.md)** — Compiled list of IaC principles
