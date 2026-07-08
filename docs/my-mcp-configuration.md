# My MCP Configuration

This documents how I configure MCP servers globally and the reasoning behind the approach.

## Global vs Workspace vs Agent Config

Kiro CLI loads MCP config from three locations (highest to lowest priority):

```
1. Agent Config       → mcpServers in agent JSON (per-agent override)
2. Workspace Config   → .kiro/settings/mcp.json (per-project)
3. Global Config      → ~/.kiro/settings/mcp.json (all projects)
```

I use **global config** (`~/.kiro/settings/mcp.json`) for all my MCP servers because:

- **Consistency** — Same tools available regardless of which project I'm working in
- **Single source of truth** — One file to update when adding/removing servers
- **No per-repo pollution** — Don't need to commit MCP config to every repo
- **Multi-account AWS** — My AWS profiles span the entire org, not a single project

## Why MCP Servers Aren't Expensive

A common misconception is that configuring many MCP servers bloats your AI context or costs money. In reality:

- **MCP servers only consume context when invoked** — Having 6 servers configured adds nothing until you call a tool
- **Tools are listed in the system prompt** — This is a small fixed cost (tool names + descriptions), typically a few hundred tokens
- **Server processes are lazy** — Some (like Docker-based Terraform) only start when first called
- **You can disable without removing** — `"disabled": true` keeps config around without loading

I run 6 MCP servers and only typically invoke 2-3 per session.

## My Current Configuration

```json
{
  "mcpServers": {
    "atlassian-mcp-server": {
      "url": "https://mcp.atlassian.com/v1/mcp/authv2",
      "type": "http",
      "disabled": false,
      "autoApprove": ["getConfluencePage", "search", "updateConfluencePage"]
    },
    "aws-mcp": {
      "command": "bash",
      "args": [
        "-lc",
        "uvx mcp-proxy-for-aws@1.6.2 https://aws-mcp.us-east-1.api.aws/mcp --region ap-southeast-2 --profile met-infra-management met-infra-network met-infra-sharedservices-prod"
      ],
      "env": {},
      "disabled": false
    },
    "terraform": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "hashicorp/terraform-mcp-server"],
      "disabled": false
    },
    "awslabs.cloudwatch-mcp-server": {
      "command": "bash",
      "args": ["-lc", "uvx awslabs.cloudwatch-mcp-server@latest"],
      "env": {
        "AWS_PROFILE": "met-infra-management",
        "AWS_REGION": "ap-southeast-2",
        "FASTMCP_LOG_LEVEL": "ERROR"
      },
      "disabled": true
    },
    "awslabs.cloudtrail-mcp-server": {
      "command": "bash",
      "args": ["-lc", "uvx awslabs.cloudtrail-mcp-server@latest"],
      "env": {
        "AWS_PROFILE": "met-infra-management",
        "AWS_REGION": "ap-southeast-2",
        "FASTMCP_LOG_LEVEL": "ERROR"
      },
      "disabled": true
    },
    "aws-knowledge-mcp-server": {
      "url": "https://knowledge-mcp.global.api.aws",
      "type": "http",
      "disabled": true
    }
  }
}
```

## Server Breakdown

| Server | Architecture | Purpose | Always Enabled? |
|---|---|---|---|
| Atlassian | Remote HTTP + OAuth | Jira/Confluence from terminal | ✅ Yes |
| AWS MCP | Proxy → remote | Multi-account AWS operations | ✅ Yes |
| Terraform | Docker container | Registry search, provider docs | ✅ Yes |
| CloudWatch | Local process (uvx) | Log/metric analysis | ❌ On-demand |
| CloudTrail | Local process (uvx) | Audit trail queries | ❌ On-demand |
| AWS Knowledge | Remote HTTP | AWS doc search | ❌ On-demand |

### Why Some Are Disabled

CloudWatch, CloudTrail, and AWS Knowledge servers are disabled by default because:
- They're only useful for specific troubleshooting sessions
- CloudWatch/CloudTrail have long startup times
- The AWS MCP server already covers most AWS operations
- I enable them when I need deep observability work

To enable temporarily during a session:
```
/mcp add awslabs.cloudwatch-mcp-server
```

Or edit the config and Kiro hot-reloads automatically.

## Design Decisions

### Why `bash -lc` wrapper?

```json
"command": "bash",
"args": ["-lc", "uvx mcp-proxy-for-aws@1.6.2 ..."]
```

The `-l` flag loads the login shell profile, which ensures:
- `PATH` includes Homebrew/Nix/asdf paths
- AWS credential helpers are available
- Any shell aliases or functions are loaded

Without this, `uvx` and other tools may not be found.

### Why `autoApprove`?

```json
"autoApprove": ["getConfluencePage", "search", "updateConfluencePage"]
```

By default, Kiro asks for confirmation before each tool call. For read-heavy operations (searching Jira, reading Confluence pages), this creates friction. `autoApprove` skips the confirmation for these safe operations.

I only auto-approve tools that are:
- Read-only (search, get)
- Low-risk write operations I'd always approve (updating a page I asked it to update)

I never auto-approve destructive or broad-scope operations.

### Why pin proxy version but use `@latest` for others?

```json
"uvx mcp-proxy-for-aws@1.6.2"    // pinned
"uvx awslabs.cloudwatch-mcp-server@latest"  // floating
```

- **AWS proxy** is pinned because it handles credential management — I don't want a breaking change mid-session
- **CloudWatch/CloudTrail** use `@latest` because they're disabled by default and I want the newest features when I do enable them

## Loading Priority in Practice

If I need to override a server for a specific project (e.g., different AWS region for a team's repo):

```
# .kiro/settings/mcp.json in the workspace
{
  "mcpServers": {
    "aws-mcp": {
      "command": "bash",
      "args": ["-lc", "uvx mcp-proxy-for-aws@1.6.2 https://aws-mcp.us-east-1.api.aws/mcp --region us-west-2 --profile different-profile"]
    }
  }
}
```

This workspace config overrides only the `aws-mcp` server — all other servers continue using the global config.
