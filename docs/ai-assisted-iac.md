---
title: AI-Assisted IaC
nav_order: 2
has_children: true
---

# AI-Assisted Infrastructure as Code

New ways of working in Cloud Platform Engineering — using Model Context Protocol (MCP) servers, AI coding assistants, and automated code review to accelerate infrastructure-as-code development.

## Why This Matters

Infrastructure as Code (IaC) has always been about codifying cloud operations. AI assistants don't replace the engineer — they eliminate the repetitive parts: searching docs, writing boilerplate, cross-referencing resources, and catching configuration drift. The human still designs the system, makes the decisions, and owns the outcome.

## Key Principles

1. **MCP servers are cheap** — they only consume context when you call them. Having 5+ configured costs nothing until you invoke a tool.
2. **Globalise your config** — shared MCP config at `~/.kiro/settings/mcp.json` means every workspace gets the same tools without per-project setup.
3. **AI is the junior engineer** — it writes the code, you review and approve. The mental model is pair programming where you're always the senior.
4. **Push to GitHub for review** — AI-generated code goes through the same PR process as hand-written code. No shortcuts on review.
5. **Terramate for orchestration** — stacks are organised by account/region/service. Terramate handles code generation, change detection, and deployment ordering.

## Pages

- [MCP Server Architectures](mcp-server-architectures.md) — Transport patterns and deployment models
- [Atlassian MCP Authentication](atlassian-mcp-authentication.md) — OAuth 2.1 flow and troubleshooting
- [My MCP Configuration](my-mcp-configuration.md) — Globalised config and design decisions
- [PR Workflow](pr-workflow.md) — Feature branch strategy, CI checks, AI + human review
