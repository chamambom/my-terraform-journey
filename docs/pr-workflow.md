---
title: PR Workflow
nav_order: 5
parent: AI-Assisted IaC
---

# PR Workflow — Feature Branch Strategy with AI + Human Review

This documents the end-to-end workflow for developing and deploying infrastructure changes, from feature branch to production.

## Branching Strategy: Trunk-Based Development with Feature Branches

We use a **trunk-based development** model with short-lived feature branches:

```
main (trunk)
  │
  ├── feature/PLA-249-rename-accounts     ← short-lived branch
  ├── feature/PLA-250-onboard-datascience  ← short-lived branch
  └── fix/subnet-share-typo               ← hotfix branch
```

**Rules:**
- `main` is always deployable
- Feature branches are short-lived (ideally < 1 week)
- Branch names follow `feature/<ticket-id>-<description>` or `fix/<description>`
- No long-running develop/staging branches — PRs go directly to `main`
- Deployments are triggered from `main` after merge

## The Workflow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────────┐     ┌──────────────┐     ┌──────────┐
│ 1. Develop   │────►│ 2. Push to   │────►│ 3. CI Checks     │────►│ 4. Review    │────►│ 5. Merge │
│    locally   │     │    GitHub     │     │    (automated)   │     │    (AI+Human)│     │  & Deploy│
└──────────────┘     └──────────────┘     └──────────────────┘     └──────────────┘     └──────────┘
```

### Step 1: Develop Locally

- Create feature branch from `main`
- Write Terraform / Terramate code (often with Kiro CLI or VS Code + Copilot)
- Run local checks before committing:
  ```bash
  terramate fmt          # Format Terramate files
  terraform fmt -recursive  # Format Terraform files
  terraform validate     # Syntax validation
  tflint                 # Linting
  ```
- Pre-commit hooks catch issues automatically if installed

### Step 2: Push to GitHub

```bash
git checkout -b feature/PLA-249-rename-accounts
git add .
git commit -m "feat(accounts): rename FR AMPS to research-dev/uat/prod"
git push -u origin feature/PLA-249-rename-accounts
```

Create a PR using GitHub CLI:
```bash
gh pr create --title "Rename FR AMPS accounts" --body "Closes PLA-249"
```

### Step 3: CI Checks (Automated)

GitHub Actions run automatically on every PR:

| Check | What It Does | Blocks Merge? |
|---|---|---|
| **Terramate Format** | Ensures `.tm.hcl` files are formatted | ✅ Yes |
| **Terraform Format** | Ensures `.tf` files are formatted (`terraform fmt`) | ✅ Yes |
| **Terraform Lint** | TFLint catches errors and enforces conventions | ✅ Yes |
| **Secret Scanner** | Gitleaks prevents credentials in code | ✅ Yes |
| **Terraform Plan** | Generates plan for changed stacks (Terramate change detection) | ✅ Yes |

If any check fails, the PR cannot be merged.

### Step 4: Review (AI + Human)

**AI Review — GitHub Copilot:**
- Copilot automatically reviews the PR for:
  - Security issues (overly permissive IAM, public resources)
  - Best practice violations
  - Missing tags or naming inconsistencies
  - Potential state conflicts
- Copilot leaves inline comments on the PR

**Human Review — Peer:**
- A team member reviews for:
  - Architectural correctness (is this the right approach?)
  - Business logic (does this solve the actual problem?)
  - Blast radius (what could go wrong?)
  - Operational readiness (monitoring, rollback plan?)
- Minimum 1 approval required to merge

The combination works well — AI catches the mechanical issues (formatting, security patterns, missing fields) so the human reviewer can focus on design and intent.

### Step 5: Merge & Deploy

Once approved:
```bash
gh pr merge --squash
```

Deployment is triggered automatically from `main`:
- Terramate detects which stacks changed
- Terraform plan is generated for changed stacks
- Terraform apply runs against the target accounts
- Deployment uses assume-role via OIDC federation (no static credentials)

## Example: Full Cycle

```bash
# 1. Start work
git checkout -b feature/PLA-249-rename-accounts
# ... write code with Kiro CLI ...

# 2. Pre-commit checks pass locally
git add .
git commit -m "feat(accounts): rename FR AMPS to research-dev/uat/prod"
git push -u origin feature/PLA-249-rename-accounts

# 3. Create PR
gh pr create --title "Rename FR AMPS accounts" \
  --body "## Summary
Renames three AWS accounts in Organizations.

## What's changing
- 111111111111: old-name-research → research-dev
- 222222222222: old-name-pilot → research-uat
- 333333333333: old-name-production → research-prod

Closes PLA-249"

# 4. Wait for CI + reviews
gh pr checks
gh pr status

# 5. Merge after approval
gh pr merge --squash --delete-branch
```

## CI/CD Pipeline Architecture

```
┌────────────────────────────────────────────────────────────────┐
│  GitHub Actions                                                 │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  On PR:                           On merge to main:            │
│  ┌─────────────────────┐          ┌─────────────────────┐     │
│  │ terramate-fmt.yml   │          │ terraform-apply.yml │     │
│  │ terraform-fmt.yml   │          │                     │     │
│  │ tflint.yml          │          │ - Terramate detect  │     │
│  │ gitleaks.yml        │          │ - terraform plan    │     │
│  │ terraform-plan.yml  │          │ - terraform apply   │     │
│  └─────────────────────┘          └─────────────────────┘     │
│                                            │                    │
│                                            ▼                    │
│                                   ┌─────────────────┐          │
│                                   │ AWS Accounts    │          │
│                                   │ (via OIDC role) │          │
│                                   └─────────────────┘          │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

## Why This Works

- **Fast feedback** — CI catches 90% of issues before a human looks at it
- **AI + Human review** — Copilot handles the checklist, humans handle the judgment
- **Trunk-based** — No merge hell, no stale long-running branches
- **Terramate change detection** — Only plans/applies stacks that actually changed
- **OIDC federation** — No static AWS credentials in CI, short-lived tokens only
