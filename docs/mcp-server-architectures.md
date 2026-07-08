# MCP Server Architectures

The Model Context Protocol (MCP) defines how AI assistants communicate with external tools. Different MCP servers use different transport and deployment architectures depending on their requirements.

## Transport Types

MCP supports three transport mechanisms:

| Transport | How It Works | Use Case |
|---|---|---|
| **stdio** | Server runs as a local process, communicates via stdin/stdout | Local tools, CLI wrappers |
| **HTTP (Streamable HTTP)** | Server runs remotely, client connects over HTTPS | Cloud-hosted services, SaaS integrations |
| **SSE (deprecated)** | Server-Sent Events over HTTP | Legacy — being replaced by Streamable HTTP |

The MCP spec (2025-11-25) standardised on **OAuth 2.1 + PKCE** for remote server authentication and **Streamable HTTP** as the modern remote transport, deprecating SSE.

---

## Architecture Patterns (From My Setup)

### 1. Remote HTTP with OAuth — Atlassian Rovo MCP Server

The Atlassian MCP server is a **cloud-hosted remote server**. Kiro CLI connects directly over HTTPS and handles OAuth 2.1 authentication via a browser flow.

```
┌─────────────┐       HTTPS        ┌──────────────────────────┐
│  Kiro CLI   │ ──────────────────► │  mcp.atlassian.com       │
│  (client)   │ ◄────────────────── │  /v1/mcp/authv2          │
└─────────────┘    JSON-RPC 2.0     └──────────────────────────┘
       │                                       │
       │ OAuth 2.1 browser flow                │ Jira / Confluence APIs
       ▼                                       ▼
  ┌──────────┐                          ┌─────────────┐
  │ Browser  │                          │ Atlassian   │
  │ (consent)│                          │ Cloud       │
  └──────────┘                          └─────────────┘
```

**Configuration:**
```json
{
  "atlassian-mcp-server": {
    "url": "https://mcp.atlassian.com/v1/mcp/authv2",
    "type": "http",
    "disabled": false
  }
}
```

**Characteristics:**
- No local process to manage
- OAuth handled by the client (Kiro CLI opens browser, stores token)
- Token refresh is automatic; re-auth via `/mcp auth <server>`
- Scopes are controlled server-side by Atlassian's consent screen

---

### 2. Local Process via Proxy — AWS MCP Server

The AWS MCP server uses a **local proxy process** that wraps a remote AWS-hosted MCP endpoint. The proxy handles AWS credential management (profiles, regions) and forwards requests.

```
┌─────────────┐     stdio      ┌─────────────────────┐     HTTPS     ┌─────────────────┐
│  Kiro CLI   │ ──────────────►│  mcp-proxy-for-aws  │ ─────────────►│  aws-mcp        │
│  (client)   │ ◄──────────────│  (local process)    │ ◄─────────────│  us-east-1      │
└─────────────┘                └─────────────────────┘               └─────────────────┘
                                        │
                                        │ Uses ~/.aws/credentials
                                        ▼
                                 ┌──────────────┐
                                 │ AWS Accounts │
                                 │ (STS assume) │
                                 └──────────────┘
```

**Configuration:**
```json
{
  "aws-mcp": {
    "command": "bash",
    "args": [
      "-lc",
      "uvx mcp-proxy-for-aws@1.6.2 https://aws-mcp.us-east-1.api.aws/mcp --region ap-southeast-2 --profile met-infra-management met-infra-network met-infra-sharedservices-prod"
    ],
    "env": {},
    "disabled": false
  }
}
```

**Characteristics:**
- Local proxy process communicates with Kiro via stdio
- Proxy authenticates to AWS using local credentials/profiles
- Supports multi-account/multi-region via multiple `--profile` arguments
- The proxy is installed/run via `uvx` (Python package runner)

---

### 3. Docker Container — Terraform MCP Server

The Terraform MCP server runs inside a **Docker container**, communicating via stdin/stdout piped through Docker's `-i` (interactive) flag.

```
┌─────────────┐     stdio      ┌──────────────────────────────────┐
│  Kiro CLI   │ ──────────────►│  docker run -i --rm              │
│  (client)   │ ◄──────────────│  hashicorp/terraform-mcp-server  │
└─────────────┘                └──────────────────────────────────┘
                                        │
                                        │ HTTPS (registry lookups)
                                        ▼
                                ┌────────────────────┐
                                │ Terraform Registry │
                                │ registry.terraform.io
                                └────────────────────┘
```

**Configuration:**
```json
{
  "terraform": {
    "command": "docker",
    "args": ["run", "-i", "--rm", "hashicorp/terraform-mcp-server"],
    "disabled": false
  }
}
```

**Characteristics:**
- Isolated environment — no local dependencies beyond Docker
- Ephemeral container (`--rm`) — clean state every session
- No authentication needed (public registry access)
- Good for tools with complex dependencies you don't want on your machine

---

### 4. Direct Local Process — uvx/npx Servers

Some MCP servers run as direct local processes using `uvx` (Python) or `npx` (Node.js) to fetch and run the latest version.

```
┌─────────────┐     stdio      ┌──────────────────────────────┐
│  Kiro CLI   │ ──────────────►│  uvx awslabs.cloudwatch-mcp  │
│  (client)   │ ◄──────────────│  (local Python process)      │
└─────────────┘                └──────────────────────────────┘
                                        │
                                        │ Uses AWS SDK + local creds
                                        ▼
                                ┌────────────────────┐
                                │ AWS CloudWatch API │
                                └────────────────────┘
```

**Configuration:**
```json
{
  "awslabs.cloudwatch-mcp-server": {
    "command": "bash",
    "args": ["-lc", "uvx awslabs.cloudwatch-mcp-server@latest"],
    "env": {
      "AWS_PROFILE": "met-infra-management",
      "AWS_REGION": "ap-southeast-2",
      "FASTMCP_LOG_LEVEL": "ERROR"
    },
    "disabled": true
  }
}
```

**Characteristics:**
- `uvx` / `npx` auto-installs the latest version on each run
- Environment variables passed directly to the process
- Uses local AWS credentials (profile + region)
- Simplest architecture — just a process with env vars

---

## Comparison

| Pattern | Example | Auth | Isolation | Setup Complexity |
|---|---|---|---|---|
| Remote HTTP + OAuth | Atlassian | OAuth 2.1 browser flow | Full (cloud-hosted) | Low |
| Local proxy → remote | AWS MCP | AWS credentials (local) | Medium (proxy process) | Medium |
| Docker container | Terraform | None (public API) | High (containerised) | Low |
| Direct local process | CloudWatch | AWS credentials (env) | Low (runs on host) | Lowest |

## When to Use What

- **Remote HTTP**: SaaS integrations where the vendor hosts the server (Atlassian, GitHub)
- **Proxy pattern**: When you need credential management or multi-account support
- **Docker**: Tools with complex dependencies or when you want isolation
- **Direct process**: Simple tools that just need env vars and local creds
